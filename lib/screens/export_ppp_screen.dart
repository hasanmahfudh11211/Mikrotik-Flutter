import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';
import '../widgets/gradient_container.dart';
import '../widgets/custom_snackbar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../providers/router_session_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show Directory, File, Platform;
import '../data/user_db_helper.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';


class ExportPPPScreen extends StatefulWidget {
  const ExportPPPScreen({Key? key}) : super(key: key);

  @override
  State<ExportPPPScreen> createState() => _ExportPPPScreenState();
}

class _ExportPPPScreenState extends State<ExportPPPScreen> {
  bool _isLoading = false;
  String? _error;
  int _totalUsers = 0;
  int _successCount = 0;
  int _failedCount = 0;
  List<Map<String, dynamic>> _failedUsers = [];
  String _currentProcess = '';

  Future<bool> saveUserToServer(Map<String, dynamic> userData) async {
    final url = Uri.parse('${ApiService.baseUrl}/save_user.php');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userData),
    );
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return result['success'] == true;
    } else {
      return false;
    }
  }

  Future<void> _exportUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'export';
    });

    try {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      
      // Get all PPP secrets from Mikrotik
      final secrets = await provider.service.getPPPSecret();
      setState(() => _totalUsers = secrets.length);

      // Process each user
      for (var secret in secrets) {
        try {
          final userData = {
            'username': secret['name'],
            'password': secret['password'],
            'profile': secret['profile'],
            'wa': '',
            'foto': '',
            'maps': '',
            'tanggal_dibuat': DateTime.now().toIso8601String(),
          };

          final success = await saveUserToServer(userData);
          
          if (success) {
            setState(() => _successCount++);
          } else {
            setState(() {
              _failedCount++;
              _failedUsers.add({
                'username': secret['name'],
                'error': 'Gagal menyimpan ke database',
              });
            });
          }
        } catch (e) {
          setState(() {
            _failedCount++;
            _failedUsers.add({
              'username': secret['name'],
              'error': e.toString(),
            });
          });
        }
      }

      if (!mounted) return;

      if (_failedCount == 0) {
        CustomSnackbar.show(
          context: context,
          message: 'Ekspor berhasil',
          additionalInfo: 'Berhasil mengekspor $_totalUsers user ke database',
          isSuccess: true,
        );
        Navigator.of(context).pop(true); // Return success
      } else {
        CustomSnackbar.show(
          context: context,
          message: 'Ekspor selesai dengan beberapa error',
          additionalInfo: '$_successCount berhasil, $_failedCount gagal',
          isSuccess: false,
        );
      }

    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      CustomSnackbar.show(
        context: context,
        message: 'Gagal mengekspor data',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Fungsi baru: ekspor massal ke database via API
  Future<void> _exportUsersToApi() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'export';
    });
    try {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      final secrets = await provider.service.getPPPSecret();
      setState(() => _totalUsers = secrets.length);
      // Siapkan data untuk API
      final users = secrets.map((secret) => {
        'username': secret['name'],
        'password': secret['password'],
        'profile': secret['profile'],
      }).toList();
      final result = await ApiService.exportUsers(List<Map<String, dynamic>>.from(users));
      if (result['success'] == true) {
        setState(() {
          _successCount = result['success_count'] ?? 0;
          _failedCount = result['failed_count'] ?? 0;
          _failedUsers = List<Map<String, dynamic>>.from(result['failed_users'] ?? []);
        });
        CustomSnackbar.show(
          context: context,
          message: 'Ekspor selesai',
          additionalInfo: 'Berhasil: $_successCount, Gagal: $_failedCount',
          isSuccess: _failedCount == 0,
        );
      } else {
        setState(() {
          _error = result['error'] ?? 'Gagal ekspor ke database';
        });
        CustomSnackbar.show(
          context: context,
          message: 'Ekspor gagal',
          additionalInfo: _error ?? '',
          isSuccess: false,
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      CustomSnackbar.show(
        context: context,
        message: 'Ekspor gagal',
        additionalInfo: _error ?? '',
        isSuccess: false,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Unified sync: ambil PPP dari Mikrotik, lalu upsert ke DB (insert/update), termasuk router_id
  Future<void> _unifiedSyncToDb() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'sync';
    });
    try {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      final secrets = await provider.service.getPPPSecret();
      _totalUsers = secrets.length;

      // Normalisasi data minimal untuk sinkron
      final normalized = secrets
          .map((s) => {
                'name': s['name']?.toString() ?? '',
                'password': s['password']?.toString() ?? '',
                'profile': s['profile']?.toString() ?? '',
              })
          .where((u) => (u['name'] as String).isNotEmpty)
          .toList();

      // Ambil routerId aktif
      final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId == null || routerId.isEmpty) {
        throw Exception('Router belum login');
      }

      // Kirim per-batch agar aman
      const int batchSize = 50;
      int added = 0;
      int updated = 0;
      for (int i = 0; i < normalized.length; i += batchSize) {
        final batch = normalized.sublist(i, i + batchSize > normalized.length ? normalized.length : i + batchSize);
        try {
          // Debug batch info
          // ignore: avoid_print
          print('[SYNC] Batch ${(i ~/ batchSize) + 1}/${(normalized.length / batchSize).ceil()} size=${batch.length}');
          final res = await ApiService.syncPPPUsers(
            routerId: routerId,
            pppUsers: List<Map<String, dynamic>>.from(batch),
            prune: i == 0, // hanya batch pertama yang memicu prune
          );
          added += (res['added'] ?? 0) as int;
          updated += (res['updated'] ?? 0) as int;
        } catch (e) {
          // ignore: avoid_print
          print('[SYNC][ERROR] Batch ${(i ~/ batchSize) + 1} failed: $e');
          rethrow;
        }
      }

      if (!mounted) return;
      _successCount = added + updated;
      CustomSnackbar.show(
        context: context,
        message: 'Sinkronisasi selesai',
        additionalInfo: 'Ditambahkan: $added, Diperbarui: $updated',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      _error = e.toString();
      CustomSnackbar.show(
        context: context,
        message: 'Sinkronisasi gagal',
        additionalInfo: _error ?? '',
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Ekspor User PPP',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                margin: const EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Ekspor',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Fitur ini akan mengekspor semua user PPP dari Mikrotik ke database. Data yang akan diekspor:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Icon(Icons.person, size: 18),
                          SizedBox(width: 6),
                          Text('Username'),
                        ],
                      ),
                      const Row(
                        children: [
                          Icon(Icons.lock, size: 18),
                          SizedBox(width: 6),
                          Text('Password'),
                        ],
                      ),
                      const Row(
                        children: [
                          Icon(Icons.category, size: 18),
                          SizedBox(width: 6),
                          Text('Profile'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Data tambahan (WA, Maps, Foto) bisa diisi nanti melalui halaman edit user.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.sync_alt),
                label: const Text('Sinkronkan & Perbarui Semua User ke Database'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _unifiedSyncToDb,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_download),
                label: const Text('Backup Database'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _backupDatabase,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                icon: const Icon(Icons.file_upload),
                label: const Text('Import dari File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _importFromFile,
              ),
              const SizedBox(height: 24),
              // Tombol sinkron khusus dihapus karena sudah digabung di atas
              const SizedBox(height: 18),

              // Progress Card
              if (_isLoading || _totalUsers > 0)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          Column(
                            children: [
                              const Center(
                                child: CircularProgressIndicator(),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _currentProcess == 'backup' 
                                  ? 'Mohon tunggu, sedang membackup database...'
                                  : 'Mohon tunggu, sedang mengekspor data ke database...',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        else ...[
                          Center(
                            child: Column(
                              children: [
                          _buildProgressItem(
                            'Total User',
                            _totalUsers.toString(),
                            Colors.blue,
                          ),
                          _buildProgressItem(
                            'Berhasil',
                            _successCount.toString(),
                            Colors.green,
                          ),
                          _buildProgressItem(
                            'Gagal',
                            _failedCount.toString(),
                            Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Failed Users List
              if (_failedUsers.isNotEmpty) ...[
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daftar User Gagal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _failedUsers.length,
                          itemBuilder: (context, index) {
                            final user = _failedUsers[index];
                            return ListTile(
                              leading: const Icon(Icons.error, color: Colors.red),
                              title: Text(user['username']),
                              subtitle: Text(
                                user['error'],
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Error message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _importFromFile() {
    CustomSnackbar.show(
      context: context,
      message: 'Fitur import dari file belum diimplementasikan',
      isSuccess: false,
    );
  }

  void _importFromServer() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'import';
    });

    try {
      // 1. Fetch data from server
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/get_all_users.php'),
      );

      if (response.statusCode != 200) {
        throw Exception('Gagal mengambil data dari server: ${response.statusCode}');
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      if (result['success'] != true) {
        throw Exception('Gagal mengambil data: ${result['error']}');
      }

      final List<dynamic> serverUsers = result['users'];
      setState(() => _totalUsers = serverUsers.length);

      // 2. Clear existing data in SQLite
      await UserDbHelper().clearAll();

      // 3. Insert each user to SQLite
      for (var userData in serverUsers) {
        try {
          // Convert server data format to local database format
          final user = {
            'username': userData['username'],
            'password': userData['password'],
            'profile': userData['profile'],
            'wa': userData['wa'],
            'foto': userData['foto'],
            'maps': userData['maps'],
            'tanggal_dibuat': userData['tanggal_dibuat'],
          };

          await UserDbHelper().insertUser(user);
          setState(() => _successCount++);
        } catch (e) {
          setState(() {
            _failedCount++;
            _failedUsers.add({
              'username': userData['username'],
              'error': e.toString(),
            });
          });
        }
      }

      if (!mounted) return;

      if (_failedCount == 0) {
        CustomSnackbar.show(
          context: context,
          message: 'Import berhasil',
          additionalInfo: 'Berhasil mengimport $_totalUsers user ke database lokal',
          isSuccess: true,
        );
      } else {
    CustomSnackbar.show(
      context: context,
          message: 'Import selesai dengan beberapa error',
          additionalInfo: '$_successCount berhasil, $_failedCount gagal',
      isSuccess: false,
    );
  }

    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      CustomSnackbar.show(
        context: context,
        message: 'Gagal mengimport data',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _exportToSql() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Show confirmation dialog first
      if (!mounted) return;
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Izin Penyimpanan'),
          content: const Text(
            'Aplikasi memerlukan izin untuk menyimpan file backup di penyimpanan.\n\n'
            'File akan disimpan di folder Download dengan format:\n'
            'backup-userspppoe-[tanggal]-[waktu].sql'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('LANJUTKAN'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Request storage permissions
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // Show settings dialog if permission is denied
          if (!mounted) return;
          final openSettings = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Izin Ditolak'),
              content: const Text(
                'Untuk menyimpan file, aplikasi memerlukan izin penyimpanan.\n\n'
                'Silakan:\n'
                '1. Buka Pengaturan\n'
                '2. Pilih "Izinkan pengelolaan semua file"\n'
                '3. Aktifkan untuk aplikasi PPPoE'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('TUTUP'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('BUKA PENGATURAN'),
                ),
              ],
            ),
          );

          if (openSettings == true) {
            await openAppSettings();
          }
          throw Exception('Izin penyimpanan diperlukan untuk mengekspor database');
        }
      }

      // 3. Get external storage directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('Tidak dapat mengakses penyimpanan eksternal');
      }

      // Navigate up to get to the Download folder
      String downloadPath = externalDir.path;
      List<String> paths = downloadPath.split("/");
      int androidIndex = paths.indexOf("Android");
      if (androidIndex != -1) {
        paths = paths.sublist(0, androidIndex);
        downloadPath = paths.join("/") + "/Download";
      }
      
      // 4. Create filename with current date
      final now = DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy').format(now);
      final timeStr = DateFormat('HHmm').format(now);
      final fileName = 'backup-userspppoe-$dateStr-$timeStr.sql';
      final targetPath = path.join(downloadPath, fileName);
      
      // 5. Ensure download directory exists
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // 6. Get all users from local database (SQLite)
      final users = await UserDbHelper().getAllUsers();

      // 7. Generate SQL dump content
      final StringBuffer sqlContent = StringBuffer();
      
      // Write SQL header
      sqlContent.writeln('-- MySQL dump for PPPoE Users');
      sqlContent.writeln('-- Generated on ${DateTime.now().toIso8601String()}');
      sqlContent.writeln('');
      sqlContent.writeln('SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";');
      sqlContent.writeln('START TRANSACTION;');
      sqlContent.writeln('SET time_zone = "+00:00";');
      sqlContent.writeln('');
      sqlContent.writeln('/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;');
      sqlContent.writeln('/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;');
      sqlContent.writeln('/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;');
      sqlContent.writeln('/*!40101 SET NAMES utf8mb4 */;');
      sqlContent.writeln('');
      
      // Create table structure
      sqlContent.writeln('--');
      sqlContent.writeln('-- Database: `pppoe_monitor`');
      sqlContent.writeln('--');
      sqlContent.writeln('');
      sqlContent.writeln('-- --------------------------------------------------------');
      sqlContent.writeln('');
      sqlContent.writeln('--');
      sqlContent.writeln('-- Table structure for table `users`');
      sqlContent.writeln('--');
      sqlContent.writeln('');
      sqlContent.writeln('CREATE TABLE IF NOT EXISTS `users` (');
      sqlContent.writeln('  `id` int NOT NULL AUTO_INCREMENT,');
      sqlContent.writeln('  `username` varchar(100) DEFAULT NULL,');
      sqlContent.writeln('  `password` varchar(100) DEFAULT NULL,');
      sqlContent.writeln('  `profile` varchar(100) DEFAULT NULL,');
      sqlContent.writeln('  `wa` varchar(20) DEFAULT NULL,');
      sqlContent.writeln('  `foto` varchar(255) DEFAULT NULL,');
      sqlContent.writeln('  `maps` varchar(255) DEFAULT NULL,');
      sqlContent.writeln('  `tanggal_dibuat` datetime DEFAULT NULL,');
      sqlContent.writeln('  PRIMARY KEY (`id`)');
      sqlContent.writeln(') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;');
      sqlContent.writeln('');

      // Insert data
      if (users.isNotEmpty) {
        sqlContent.writeln('--');
        sqlContent.writeln('-- Dumping data for table `users`');
        sqlContent.writeln('--');
        sqlContent.writeln('');
        sqlContent.writeln('INSERT INTO `users` (`username`, `password`, `profile`, `wa`, `foto`, `maps`, `tanggal_dibuat`) VALUES');
        
        for (var i = 0; i < users.length; i++) {
          final user = users[i];
          final username = _escapeSqlString(user['username']);
          final password = _escapeSqlString(user['password']);
          final profile = _escapeSqlString(user['profile']);
          final wa = user['wa'] != null ? "'${_escapeSqlString(user['wa'])}'" : 'NULL';
          final foto = user['foto'] != null ? "'${_escapeSqlString(user['foto'])}'" : 'NULL';
          final maps = user['maps'] != null ? "'${_escapeSqlString(user['maps'])}'" : 'NULL';
          final tanggalDibuat = user['tanggal_dibuat'] != null ? "'${user['tanggal_dibuat']}'" : 'NULL';

          sqlContent.write("('$username', '$password', '$profile', $wa, $foto, $maps, $tanggalDibuat)");
          if (i < users.length - 1) {
            sqlContent.writeln(',');
          } else {
            sqlContent.writeln(';');
          }
        }
      }

      // Write SQL footer
      sqlContent.writeln('');
      sqlContent.writeln('COMMIT;');
      sqlContent.writeln('');
      sqlContent.writeln('/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;');
      sqlContent.writeln('/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;');
      sqlContent.writeln('/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;');

      // 8. Write SQL content to file
      final file = File(targetPath);
      await file.writeAsString(sqlContent.toString());

      if (!mounted) return;
      
      CustomSnackbar.show(
        context: context,
        message: 'Ekspor berhasil',
        additionalInfo: 'File tersimpan di folder Download:\n$fileName',
        isSuccess: true,
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      CustomSnackbar.show(
        context: context,
        message: 'Gagal mengekspor data',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _escapeSqlString(String str) {
    if (str == null) return 'NULL';
    return str.replaceAll("'", "''")
              .replaceAll("\\", "\\\\")
              .replaceAll("\r", "\\r")
              .replaceAll("\n", "\\n")
              .replaceAll("\t", "\\t");
  }

  Future<void> _backupDatabase() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'backup';
    });

    try {
      // 1. Show confirmation dialog first
      if (!mounted) return;
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Backup Database'),
          content: const Text(
            'Proses backup akan:\n\n'
            '1. Mengambil data terbaru dari server\n'
            '2. Menyimpan ke database lokal\n'
            '3. Membuat file backup (.sql) di folder Download\n\n'
            'Lanjutkan proses backup?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('LANJUTKAN'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;

      // 2. Request storage permissions first
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // Show settings dialog if permission is denied
          if (!mounted) return;
          final openSettings = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Izin Penyimpanan'),
              content: const Text(
                'Untuk menyimpan file backup, aplikasi memerlukan izin penyimpanan.\n\n'
                'Silakan:\n'
                '1. Buka Pengaturan\n'
                '2. Pilih "Izinkan pengelolaan semua file"\n'
                '3. Aktifkan untuk aplikasi PPPoE'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('TUTUP'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('BUKA PENGATURAN'),
                ),
              ],
            ),
          );

          if (openSettings == true) {
            await openAppSettings();
          }
          throw Exception('Izin penyimpanan diperlukan untuk backup database');
        }
      }

      // 2. Import from server
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/get_all_users.php'),
      );

      if (response.statusCode != 200) {
        throw Exception('Gagal mengambil data dari server: ${response.statusCode}');
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      if (result['success'] != true) {
        throw Exception('Gagal mengambil data: ${result['error']}');
      }

      final List<dynamic> serverUsers = result['users'];
      setState(() => _totalUsers = serverUsers.length);

      // 3. Clear existing data in SQLite
      await UserDbHelper().clearAll();

      // 4. Insert each user to SQLite
      for (var userData in serverUsers) {
        try {
          final user = {
            'username': userData['username'],
            'password': userData['password'],
            'profile': userData['profile'],
            'wa': userData['wa'],
            'foto': userData['foto'],
            'maps': userData['maps'],
            'tanggal_dibuat': userData['tanggal_dibuat'],
          };

          await UserDbHelper().insertUser(user);
          setState(() => _successCount++);
        } catch (e) {
          setState(() {
            _failedCount++;
            _failedUsers.add({
              'username': userData['username'],
              'error': e.toString(),
            });
          });
        }
      }

      // 5. Get external storage directory for SQL backup
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('Tidak dapat mengakses penyimpanan eksternal');
      }

      // Navigate up to get to the Download folder
      String downloadPath = externalDir.path;
      List<String> paths = downloadPath.split("/");
      int androidIndex = paths.indexOf("Android");
      if (androidIndex != -1) {
        paths = paths.sublist(0, androidIndex);
        downloadPath = paths.join("/") + "/Download";
      }
      
      // 6. Create filename with current date
      final now = DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy').format(now);
      final timeStr = DateFormat('HHmm').format(now);
      final fileName = 'backup-userspppoe-$dateStr-$timeStr.sql';
      final targetPath = path.join(downloadPath, fileName);
      
      // 7. Ensure download directory exists
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // 8. Generate SQL dump content
      final StringBuffer sqlContent = StringBuffer();
      
      // Write SQL header
      sqlContent.writeln('-- MySQL dump for PPPoE Users');
      sqlContent.writeln('-- Generated on ${DateTime.now().toIso8601String()}');
      sqlContent.writeln('');
      sqlContent.writeln('SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";');
      sqlContent.writeln('START TRANSACTION;');
      sqlContent.writeln('SET time_zone = "+00:00";');
      sqlContent.writeln('');
      sqlContent.writeln('/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;');
      sqlContent.writeln('/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;');
      sqlContent.writeln('/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;');
      sqlContent.writeln('/*!40101 SET NAMES utf8mb4 */;');
      sqlContent.writeln('');
      
      // Create table structure
      sqlContent.writeln('--');
      sqlContent.writeln('-- Database: `pppoe_monitor`');
      sqlContent.writeln('--');
      sqlContent.writeln('');
      sqlContent.writeln('-- --------------------------------------------------------');
      sqlContent.writeln('');
      sqlContent.writeln('--');
      sqlContent.writeln('-- Table structure for table `users`');
      sqlContent.writeln('--');
      sqlContent.writeln('');
      sqlContent.writeln('CREATE TABLE IF NOT EXISTS `users` (');
      sqlContent.writeln('  `id` int NOT NULL AUTO_INCREMENT,');
      sqlContent.writeln('  `username` varchar(100) DEFAULT NULL,');
      sqlContent.writeln('  `password` varchar(100) DEFAULT NULL,');
      sqlContent.writeln('  `profile` varchar(100) DEFAULT NULL,');
      sqlContent.writeln('  `wa` varchar(20) DEFAULT NULL,');
      sqlContent.writeln('  `foto` varchar(255) DEFAULT NULL,');
      sqlContent.writeln('  `maps` varchar(255) DEFAULT NULL,');
      sqlContent.writeln('  `tanggal_dibuat` datetime DEFAULT NULL,');
      sqlContent.writeln('  PRIMARY KEY (`id`)');
      sqlContent.writeln(') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;');
      sqlContent.writeln('');

      // Get users from local database
      final users = await UserDbHelper().getAllUsers();

      // Insert data
      if (users.isNotEmpty) {
        sqlContent.writeln('--');
        sqlContent.writeln('-- Dumping data for table `users`');
        sqlContent.writeln('--');
        sqlContent.writeln('');
        sqlContent.writeln('INSERT INTO `users` (`username`, `password`, `profile`, `wa`, `foto`, `maps`, `tanggal_dibuat`) VALUES');
        
        for (var i = 0; i < users.length; i++) {
          final user = users[i];
          final username = _escapeSqlString(user['username']);
          final password = _escapeSqlString(user['password']);
          final profile = _escapeSqlString(user['profile']);
          final wa = user['wa'] != null ? "'${_escapeSqlString(user['wa'])}'" : 'NULL';
          final foto = user['foto'] != null ? "'${_escapeSqlString(user['foto'])}'" : 'NULL';
          final maps = user['maps'] != null ? "'${_escapeSqlString(user['maps'])}'" : 'NULL';
          final tanggalDibuat = user['tanggal_dibuat'] != null ? "'${user['tanggal_dibuat']}'" : 'NULL';

          sqlContent.write("('$username', '$password', '$profile', $wa, $foto, $maps, $tanggalDibuat)");
          if (i < users.length - 1) {
            sqlContent.writeln(',');
          } else {
            sqlContent.writeln(';');
          }
        }
      }

      // Write SQL footer
      sqlContent.writeln('');
      sqlContent.writeln('COMMIT;');
      sqlContent.writeln('');
      sqlContent.writeln('/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;');
      sqlContent.writeln('/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;');
      sqlContent.writeln('/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;');

      // 9. Write SQL content to file
      final file = File(targetPath);
      await file.writeAsString(sqlContent.toString());

      if (!mounted) return;
      
      CustomSnackbar.show(
        context: context,
        message: 'Backup berhasil',
        additionalInfo: 'Data tersinkron: $_successCount user\nFile backup: $fileName',
        isSuccess: true,
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    CustomSnackbar.show(
      context: context,
        message: 'Backup gagal',
        additionalInfo: e.toString(),
      isSuccess: false,
    );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncPPPtoDB() async {
    setState(() { _isLoading = true; });
    try {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      final pppUsers = await provider.service.getPPPSecret();
      // Kirim ke API sync_ppp_to_db.php
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/sync_ppp_to_db.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ppp_users': pppUsers}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        CustomSnackbar.show(
          context: context,
          message: 'Sinkronisasi selesai',
          additionalInfo: '${data['added']} user baru ditambahkan ke database',
          isSuccess: true,
        );
      } else {
        CustomSnackbar.show(
          context: context,
          message: 'Sinkronisasi gagal',
          additionalInfo: data['error'] ?? '',
          isSuccess: false,
        );
      }
    } catch (e) {
      CustomSnackbar.show(
        context: context,
        message: 'Sinkronisasi gagal',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }
} 