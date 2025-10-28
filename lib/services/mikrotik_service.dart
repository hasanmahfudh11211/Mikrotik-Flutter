import 'dart:convert';
import 'package:http/http.dart' as http;

class MikrotikService {
  String? ip;
  String? port;
  String? username;
  String? password;

  MikrotikService({this.ip, this.port, this.username, this.password});

  String get baseUrl => 'http://$ip:$port/rest';

  Map<String, String> get _headers => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$username:$password'))}',
        'Content-Type': 'application/json',
      };

  String _formatErrorMessage(String message) {
    // Remove technical details and format for user display
    message = message.replaceAll('Exception: ', '');
    message = message.replaceAll('ClientException with ', '');
    message = message.replaceAll('SocketException: ', '');
    
    // Clean up specific error messages
    if (message.contains('Connection refused')) {
      return 'Koneksi ke router gagal karena:\n\n'
          '• Port ${port ?? ""} tidak dapat diakses\n'
          '• API service Mikrotik mungkin tidak aktif\n'
          '• Firewall mungkin memblokir koneksi\n\n'
          'Solusi:\n'
          '1. Periksa apakah port yang dimasukkan benar\n'
          '2. Pastikan service API Mikrotik sudah diaktifkan\n'
          '3. Periksa pengaturan firewall router';
    }
    
    return message;
  }

  Future<Map<String, dynamic>> getIdentity() async {
    try {
    final response = await http.get(
      Uri.parse('$baseUrl/system/identity'),
      headers: _headers,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
            'Koneksi timeout (10 detik)\n\n'
            'Kemungkinan penyebab:\n'
            '• Router tidak menyala\n'
            '• IP Address salah\n'
            '• Jaringan tidak stabil\n\n'
            'Solusi:\n'
            '1. Periksa router dan koneksi jaringan\n'
            '2. Pastikan IP benar: ${ip ?? ""}\n'
            '3. Coba hubungkan kembali'
          );
        },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'Login Gagal\n\n'
          'Username atau password salah\n\n'
          'Solusi:\n'
          '1. Periksa kembali username\n'
          '2. Periksa kembali password\n'
          '3. Pastikan huruf besar/kecil sudah benar'
        );
      } else if (response.statusCode == 404) {
        throw Exception(
          'Router Tidak Ditemukan\n\n'
          'Kemungkinan penyebab:\n'
          '• IP Address salah\n'
          '• Port salah\n'
          '• Router tidak terjangkau\n\n'
          'Detail:\n'
          '• IP: ${ip ?? ""}\n'
          '• Port: ${port ?? ""}\n\n'
          'Solusi:\n'
          '1. Periksa IP Address router\n'
          '2. Periksa nomor port\n'
          '3. Pastikan router dan perangkat dalam jaringan yang sama'
        );
      } else {
        final errorBody = response.body.toLowerCase();
        if (errorBody.contains('cannot resolve')) {
          throw Exception(
            'IP Address Tidak Valid\n\n'
            'IP Address yang dimasukkan (${ip ?? ""}) tidak dapat ditemukan\n\n'
            'Solusi:\n'
            '1. Periksa IP Address router\n'
            '2. Pastikan format IP Address benar\n'
            '3. Pastikan router dan perangkat dalam jaringan yang sama'
          );
        } else if (errorBody.contains('connection refused')) {
          throw Exception(
            'Koneksi Ditolak\n\n'
            'Router menolak koneksi pada port ${port ?? ""}\n\n'
            'Kemungkinan penyebab:\n'
            '• Port yang dimasukkan salah\n'
            '• API service Mikrotik tidak aktif\n'
            '• Firewall memblokir koneksi\n\n'
            'Solusi:\n'
            '1. Periksa nomor port\n'
            '2. Aktifkan API service di router\n'
            '3. Periksa pengaturan firewall'
          );
        } else if (errorBody.contains('timeout')) {
          throw Exception(
            'Koneksi Timeout\n\n'
            'Router tidak merespon dalam waktu yang ditentukan\n\n'
            'Kemungkinan penyebab:\n'
            '• Router tidak menyala\n'
            '• Jaringan tidak stabil\n'
            '• Firewall memblokir koneksi\n\n'
            'Solusi:\n'
            '1. Periksa kondisi router\n'
            '2. Periksa koneksi jaringan\n'
            '3. Coba restart router'
          );
    } else {
          throw Exception(
            'Gagal Terhubung ke Router\n\n'
            'Detail error:\n'
            '${_formatErrorMessage(response.body)}\n\n'
            'Solusi:\n'
            '1. Periksa semua pengaturan koneksi\n'
            '2. Pastikan router menyala dan terhubung\n'
            '3. Coba restart aplikasi'
          );
        }
      }
    } catch (e) {
      if (e is Exception) {
        final message = e.toString();
        if (message.contains('SocketException') || 
            message.contains('Connection refused')) {
          throw Exception(
            'Koneksi Gagal\n\n'
            'Tidak dapat terhubung ke router pada:\n'
            '• IP: ${ip ?? ""}\n'
            '• Port: ${port ?? ""}\n\n'
            'Kemungkinan penyebab:\n'
            '• Router tidak menyala\n'
            '• IP Address atau Port salah\n'
            '• API service tidak aktif\n'
            '• Firewall memblokir koneksi\n\n'
            'Solusi:\n'
            '1. Periksa apakah router menyala\n'
            '2. Pastikan IP dan Port benar\n'
            '3. Aktifkan API service di router\n'
            '4. Periksa pengaturan firewall'
          );
        } else if (message.contains('HandshakeException')) {
          throw Exception(
            'Koneksi Tidak Aman\n\n'
            'Terjadi masalah keamanan koneksi\n\n'
            'Kemungkinan penyebab:\n'
            '• Menggunakan HTTPS pada port HTTP\n'
            '• Port yang dimasukkan salah\n'
            '• Masalah sertifikat SSL\n\n'
            'Solusi:\n'
            '1. Gunakan protokol HTTP\n'
            '2. Periksa nomor port\n'
            '3. Periksa pengaturan SSL di router'
          );
        }
        throw Exception(_formatErrorMessage(message));
      }
      throw Exception(
        'Error Tidak Dikenal\n\n'
        'Terjadi kesalahan yang tidak terduga\n\n'
        'Detail:\n'
        '${_formatErrorMessage(e.toString())}\n\n'
        'Solusi:\n'
        '1. Coba login kembali\n'
        '2. Periksa semua pengaturan\n'
        '3. Restart aplikasi jika masih bermasalah'
      );
    }
  }

  Future<Map<String, dynamic>> getResource() async {
    final response = await http.get(
      Uri.parse('$baseUrl/system/resource'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch resource: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getPPPActive() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ppp/active'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to fetch PPP active: ${response.body}');
    }
  }

  Future<void> disconnectSession(String sessionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ppp/active/remove'),
      headers: _headers,
      body: jsonEncode({
        'session-id': sessionId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to disconnect session: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getPPPSecret() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ppp/secret'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to fetch PPP secret: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getLog() async {
    final response = await http.get(
      Uri.parse('$baseUrl/log'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to fetch log: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getInterface() async {
    final response = await http.get(
      Uri.parse('$baseUrl/interface'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to fetch interface: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getPPPProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ppp/profile'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to fetch PPP profile: ${response.body}');
    }
  }

  Future<void> addPPPSecret(Map<String, String> data) async {
    if (data['name'] == null || data['name']!.isEmpty) {
      throw Exception('Username tidak boleh kosong');
    }
    if (data['password'] == null || data['password']!.isEmpty) {
      throw Exception('Password tidak boleh kosong');
    }
    if (data['profile'] == null || data['profile']!.isEmpty) {
      throw Exception('Profile harus dipilih');
    }

    // Check for existing username
    final existingSecrets = await getPPPSecret();
    final usernameExists = existingSecrets.any((secret) => 
      secret['name']?.toString().toLowerCase() == data['name']?.toLowerCase()
    );

    if (usernameExists) {
      throw Exception('Username "${data['name']}" sudah digunakan. Silakan gunakan username lain.');
    }

    final url = Uri.parse('$baseUrl/ppp/secret/add');
    final requestBody = {
      'name': data['name'],
      'password': data['password'],
      'profile': data['profile'],
      'service': data['service'] ?? 'pppoe',
      'disabled': 'no'
    };

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorBody = response.body;
        if (errorBody.contains('already have')) {
          throw Exception('Username sudah digunakan');
        } else if (errorBody.contains('invalid profile')) {
          throw Exception('Profile tidak valid');
        } else {
          throw Exception('Gagal menambahkan user: ${response.body}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<void> updatePPPSecret(String name, Map<String, String> data) async {
    if (data['name'] != null && data['name']!.isEmpty) {
      throw Exception('Username tidak boleh kosong');
    }
    if (data['password'] != null && data['password']!.isEmpty) {
      throw Exception('Password tidak boleh kosong');
    }
    if (data['profile'] != null && data['profile']!.isEmpty) {
      throw Exception('Profile harus dipilih');
    }

    // Check if username is being changed and if it already exists
    if (data['name'] != null && data['name'] != name) {
      final existingSecrets = await getPPPSecret();
      final usernameExists = existingSecrets.any((secret) => 
        secret['name']?.toString().toLowerCase() == data['name']?.toLowerCase()
      );

      if (usernameExists) {
        throw Exception('Username "${data['name']}" sudah digunakan. Silakan gunakan username lain.');
      }
    }

    // Get the secret's .id first
    final secrets = await getPPPSecret();
    final secret = secrets.firstWhere(
      (s) => s['name'] == name,
      orElse: () => throw Exception('User tidak ditemukan'),
    );
    
    final id = secret['.id'];
    if (id == null) throw Exception('User ID tidak ditemukan');

    final url = Uri.parse('$baseUrl/ppp/secret/set');
    final requestBody = {
      '.id': id,
      'name': data['name'] ?? name,
      'password': data['password'] ?? secret['password'],
      'profile': data['profile'] ?? secret['profile'],
      'service': 'pppoe',
      'disabled': 'no'
    };

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode != 200) {
        final errorBody = response.body.toLowerCase();
        if (errorBody.contains('invalid profile')) {
          throw Exception('Profile tidak valid');
        } else if (errorBody.contains('no such item')) {
          throw Exception('User tidak ditemukan');
        } else if (errorBody.contains('already have')) {
          throw Exception('Username sudah digunakan');
        } else {
          throw Exception('Gagal mengubah user: ${response.body}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<void> deletePPPSecret(String id) async {
    try {
      // First, get the secret to make sure we have the correct ID
      final secrets = await getPPPSecret();
      final secret = secrets.firstWhere(
        (s) => s['.id'] == id,
        orElse: () => throw Exception('User tidak ditemukan'),
      );

      final response = await http.post(
        Uri.parse('$baseUrl/ppp/secret/remove'),
        headers: _headers,
        body: jsonEncode({
          '.id': secret['.id'],
        }),
      );
      
      if (response.statusCode != 200) {
        final errorBody = response.body.toLowerCase();
        if (errorBody.contains('no such item')) {
          throw Exception('User tidak ditemukan');
        } else {
          throw Exception('Gagal menghapus user: ${response.body}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getTraffic(String interfaceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/interface/$interfaceId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        // Calculate rates by comparing values over time
        await Future.delayed(const Duration(seconds: 1)); // Wait 1 second
        final secondResponse = await http.get(
          Uri.parse('$baseUrl/interface/$interfaceId'),
          headers: _headers,
        );
        if (secondResponse.statusCode == 200) {
          final secondData = jsonDecode(secondResponse.body);
          if (secondData is Map<String, dynamic>) {
            // Calculate TX/RX rates
            final txByteDiff = int.parse(secondData['tx-byte'] ?? '0') - int.parse(data['tx-byte'] ?? '0');
            final rxByteDiff = int.parse(secondData['rx-byte'] ?? '0') - int.parse(data['rx-byte'] ?? '0');
            final txPacketDiff = int.parse(secondData['tx-packet'] ?? '0') - int.parse(data['tx-packet'] ?? '0');
            final rxPacketDiff = int.parse(secondData['rx-packet'] ?? '0') - int.parse(data['rx-packet'] ?? '0');

            return {
              'tx-rate': (txByteDiff * 8 / 1000000), // Convert to Mbps
              'rx-rate': (rxByteDiff * 8 / 1000000), // Convert to Mbps
              'tx-packet-rate': txPacketDiff,
              'rx-packet-rate': rxPacketDiff,
              'total-tx-byte': data['tx-byte'],
              'total-rx-byte': data['rx-byte'],
              'total-tx-packet': data['tx-packet'],
              'total-rx-packet': data['rx-packet'],
              'tx-drop': data['tx-drop'],
              'rx-drop': data['rx-drop'],
              'tx-error': data['tx-error'],
              'rx-error': data['rx-error'],
            };
          }
        }
      }
      throw Exception('Invalid response format');
    } else {
      throw Exception('Failed to fetch traffic data: ${response.body}');
    }
  }
}
