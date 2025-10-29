import 'package:flutter/material.dart';
import '../widgets/gradient_container.dart';
import '../services/api_service.dart';
import 'edit_data_tambahan_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({Key? key}) : super(key: key);

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortOption = 'Username (A-Z)';
  final List<String> _sortOptions = [
    'Username (A-Z)',
    'Username (Z-A)',
    'Profile (A-Z)',
    'Profile (Z-A)',
    'ODP (A-Z)',
    'ODP (Z-A)',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsersFromApi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fungsi baru: load users dari API PHP
  Future<void> _loadUsersFromApi() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getAllUsers();
      if (!mounted) return;
      if (data['success'] == true) {
        // Ambil secrets dari Mikrotik
        final provider = Provider.of<MikrotikProvider>(context, listen: false);
        final secrets = await provider.service.getPPPSecret();
        if (!mounted) return;
        final secretUsernames = secrets.map((s) => s['name']).toSet();
        final filtered = List<Map<String, dynamic>>.from(data['users'])
            .where((u) => secretUsernames.contains(u['username']))
            .toList();
        if (mounted) {
          setState(() {
            _users = filtered;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = data['error'] ?? 'Gagal memuat data dari API';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat data: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _showSortDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Urutkan Berdasarkan',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.grey.shade700 : null),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _sortOptions.length,
              itemBuilder: (context, index) {
                final option = _sortOptions[index];
                final isSelected = option == _sortOption;
                return ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected 
                        ? (isDark ? Colors.blue.shade300 : Theme.of(context).primaryColor) 
                        : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  trailing: isSelected 
                    ? Icon(Icons.check, color: isDark ? Colors.blue.shade300 : Theme.of(context).primaryColor) 
                    : null,
                  onTap: () {
                    setState(() {
                      _sortOption = option;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredUsers {
    List<Map<String, dynamic>> users = _users;
    if (_searchQuery.isNotEmpty) {
      users = users.where((user) {
        final username = user['username'].toString().toLowerCase();
        final profile = user['profile'].toString().toLowerCase();
        final wa = user['wa']?.toString().toLowerCase() ?? '';
        final odpName = user['odp_name']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return username.contains(query) ||
            profile.contains(query) ||
            wa.contains(query) ||
            odpName.contains(query);
      }).toList();
    }
    // Sorting
    users.sort((a, b) {
      switch (_sortOption) {
        case 'Username (A-Z)':
          return a['username'].toString().compareTo(b['username'].toString());
        case 'Username (Z-A)':
          return b['username'].toString().compareTo(a['username'].toString());
        case 'Profile (A-Z)':
          return a['profile'].toString().compareTo(b['profile'].toString());
        case 'Profile (Z-A)':
          return b['profile'].toString().compareTo(a['profile'].toString());
        case 'ODP (A-Z)':
          final aOdp = a['odp_name']?.toString() ?? '';
          final bOdp = b['odp_name']?.toString() ?? '';
          if (aOdp.isEmpty) return 1;
          if (bOdp.isEmpty) return -1;
          return aOdp.compareTo(bOdp);
        case 'ODP (Z-A)':
          final aOdp = a['odp_name']?.toString() ?? '';
          final bOdp = b['odp_name']?.toString() ?? '';
          if (aOdp.isEmpty) return 1;
          if (bOdp.isEmpty) return -1;
          return bOdp.compareTo(aOdp);
        default:
          return 0;
      }
    });
    return users;
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus User', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87
          )
        ),
        content: Text(
          'Yakin ingin menghapus user "${user['username']}"?',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark ? Colors.blue.shade300 : Colors.blue
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        // Asumsikan ApiService punya deleteUser
        await ApiService.deleteUser(user['username']);
        if (mounted) {
          setState(() {
            _users.removeWhere((u) => u['username'] == user['username']);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User berhasil dihapus'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus user: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showUserDetailSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade600 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                      child: Icon(Icons.person, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 38),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['username'] ?? '-',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          ),
                          Text(
                            user['profile'] ?? '-',
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600], fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (user['foto'] != null && user['foto'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Builder(
                      builder: (context) {
                        String fotoUrl = user['foto'];
                        if (!fotoUrl.startsWith('http')) {
                          fotoUrl = '${ApiService.baseUrl}/' + fotoUrl;
                        }
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              barrierDismissible: true,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: EdgeInsets.all(10),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      child: Container(
                                        color: Colors.black.withValues(alpha: 0.8),
                                        child: Center(
                                          child: InteractiveViewer(
                                            child: Image.network(
                                              fotoUrl,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image, color: Colors.white, size: 80),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                        onPressed: () => Navigator.of(context).pop(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              fotoUrl,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 180,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black45 : Colors.black12,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  child: Column(
                    children: [
                      _infoRow(Icons.person_outline, 'Username', user['username'] ?? '-'),
                      _buildDivider(),
                      _infoRow(Icons.lock_outline, 'Password', user['password'] ?? '-', isPassword: true),
                      _buildDivider(),
                      _infoRow(Icons.category, 'Profile', user['profile'] ?? '-'),
                      if (user['odp_name'] != null && user['odp_name'].isNotEmpty) ...[
                        _buildDivider(),
                        _infoRow(Icons.call_split, 'ODP', user['odp_name']),
                      ],
                      if (user['wa']?.isNotEmpty ?? false) ...[
                        _buildDivider(),
                        _infoRow(null, 'WA', user['wa'] ?? '-', isWA: true),
                      ],
                      if (user['maps']?.isNotEmpty ?? false) ...[
                        _buildDivider(),
                        _infoRow(null, 'Maps', user['maps'] ?? '-', isMaps: true),
                      ],
                      if (user['tanggal_dibuat']?.isNotEmpty ?? false) ...[
                        _buildDivider(),
                        _infoRow(Icons.calendar_today, 'Tanggal dibuat',
                          user['tanggal_dibuat'] != null
                            ? (() {
                                try {
                                  return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(DateTime.tryParse(user['tanggal_dibuat']) ?? DateTime.now());
                                } catch (_) {
                                  return user['tanggal_dibuat'];
                                }
                              })()
                            : '-',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditDataTambahanScreen(
                                  username: user['username'],
                                  currentData: {
                                    'wa': user['wa'] ?? '',
                                    'maps': user['maps'] ?? '',
                                    'foto': user['foto'] ?? '',
                                    'odp_id': user['odp_id'],
                                  },
                                ),
                              ),
                            ).then((value) {
                              if (value == true) _loadUsersFromApi();
                            });
                          },
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Edit Data Tambahan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.blue.shade700 : Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _deleteUser(user),
                          icon: const Icon(Icons.delete),
                          label: const Text('Hapus'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tambahkan fungsi dialog popup di tengah
  Future<void> _showCopyOpenDialog({
    required BuildContext context,
    required String title,
    required String value,
    required String openLabel,
    required VoidCallback onOpen,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text(
            title, 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87
            )
          )
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
              ),
              child: SelectableText(
                value,
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue.shade700 : Colors.blue.shade800,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Disalin ke clipboard!'), backgroundColor: Colors.green),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue.shade700 : Colors.blue.shade800,
                      foregroundColor: Colors.white,
                    ),
                    icon: title == 'Nomor WhatsApp'
                        ? Image.asset('assets/WhatsApp.svg.png', width: 24, height: 24)
                        : title == 'Link Maps'
                            ? Image.asset('assets/pngimg.com - google_maps_pin_PNG26.png', width: 24, height: 24)
                            : const Icon(Icons.open_in_new),
                    label: Text(openLabel),
                    onPressed: () {
                      Navigator.pop(context);
                      onOpen();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tambahkan fungsi _infoRow untuk tampilan modern
  Widget _infoRow(IconData? icon, String label, String value, {bool isPassword = false, bool isWA = false, bool isMaps = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget? leadingIcon;
    if (isWA) {
      leadingIcon = Image.asset('assets/WhatsApp.svg.png', width: 22, height: 22);
    } else if (isMaps) {
      leadingIcon = Image.asset('assets/pngimg.com - google_maps_pin_PNG26.png', width: 22, height: 22);
    } else if (icon != null) {
      leadingIcon = Icon(icon, color: isDark ? Colors.blue.shade300 : Colors.blueAccent, size: 22);
    }

    Widget valueWidget;
    if (isPassword) {
      final ValueNotifier<bool> obscure = ValueNotifier<bool>(true);
      valueWidget = ValueListenableBuilder<bool>(
        valueListenable: obscure,
        builder: (context, isObscure, _) => Row(
          children: [
            Expanded(
              child: Text(
                isObscure ? '••••••••' : value,
                style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black54),
                overflow: TextOverflow.visible,
                maxLines: null,
              ),
            ),
            InkWell(
              onTap: () => obscure.value = !isObscure,
              child: Icon(
                isObscure ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      );
    } else {
      valueWidget = Text(
        value,
        style: TextStyle(
          fontSize: 15,
          color: isWA || isMaps 
            ? (isDark ? Colors.blue.shade300 : Colors.blue) 
            : (isDark ? Colors.white70 : Colors.black87),
          decoration: isWA || isMaps ? TextDecoration.underline : TextDecoration.none,
        ),
        overflow: TextOverflow.visible,
        maxLines: null,
      );
    }

    // Kembalikan popup salin & buka untuk WA dan Maps
    if ((isWA && value.isNotEmpty) || (isMaps && value.isNotEmpty)) {
      valueWidget = InkWell(
        onTap: () async {
          if (isWA) {
            _showCopyOpenDialog(
              context: context,
              title: 'Nomor WhatsApp',
              value: value,
              openLabel: 'Buka',
              onOpen: () async {
                String waNumber = value.replaceAll(RegExp(r'[^0-9]'), '');
                if (waNumber.startsWith('0')) {
                  waNumber = '62' + waNumber.substring(1);
                }
                final uri = Uri.parse('whatsapp://send?phone=$waNumber');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tidak dapat membuka WhatsApp.')),
                  );
                }
              },
            );
          } else if (isMaps) {
            _showCopyOpenDialog(
              context: context,
              title: 'Link Maps',
              value: value,
              openLabel: 'Buka',
              onOpen: () async {
                String mapsUrl = value;
                if (!value.startsWith('http') && !value.startsWith('geo:')) {
                  mapsUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(value)}';
                }
                final uri = Uri.parse(mapsUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tidak dapat membuka link: $value')),
                  );
                }
              },
            );
          }
        },
        child: valueWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            leadingIcon,
            const SizedBox(width: 10),
          ],
          Text('${label}:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(width: 8),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Semua User',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadUsersFromApi,
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Urutkan/Sort',
              onPressed: _showSortDialog,
            ),
          ],
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Card(
                color: Theme.of(context).cardColor,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari user...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Theme.of(context).iconTheme.color,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
            // User List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadUsersFromApi,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red, fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadUsersFromApi,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('COBA LAGI'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredUsers.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tidak ada user yang ditemukan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _filteredUsers.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  return GestureDetector(
                                    onTap: () => _showUserDetailSheet(user),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeInOut,
                                      child: Card(
                                        elevation: 1,
                                        margin: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200, width: 1),
                                        ),
                                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                                                child: Icon(Icons.person, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 22),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      user['username'],
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Profile: ${user['profile']}',
                                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                                                    ),
                                                    if (user['odp_name']?.isNotEmpty ?? false)
                                                      Row(
                                                        children: [
                                                          Icon(Icons.call_split, size: 16, color: isDark ? Colors.blue.shade300 : Colors.blue.shade800),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'ODP: ${user['odp_name']}',
                                                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                                                            overflow: TextOverflow.visible,
                                                            maxLines: null,
                                                          ),
                                                        ],
                                                      ),
                                                    if (user['wa']?.isNotEmpty ?? false)
                                                      Row(
                                                        children: [
                                                          Image.asset('assets/WhatsApp.svg.png', width: 16, height: 16),
                                                          const SizedBox(width: 4),
                                                          Text('WA: ${user['wa']}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black)),
                                                        ],
                                                      ),
                                                    if (user['maps']?.isNotEmpty ?? false)
                                                      Row(
                                                        children: [
                                                          Image.asset('assets/pngimg.com - google_maps_pin_PNG26.png', width: 16, height: 16),
                                                          const SizedBox(width: 4),
                                                          Flexible(
                                                            child: Text(
                                                              'Maps: ${user['maps']}',
                                                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ),
            // Footer jumlah user
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Total User: ${_filteredUsers.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}