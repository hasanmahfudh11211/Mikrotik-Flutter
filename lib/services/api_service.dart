import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class ApiService {
  static String _baseUrlCache = 'https://bedagung.space/api';
  static String get baseUrl => _baseUrlCache;
  static Future<void> refreshBaseUrlFromStorage() async {
    _baseUrlCache = await ConfigService.getBaseUrl();
  }
  static Future<String> _getBaseUrl() async {
    final url = await ConfigService.getBaseUrl();
    _baseUrlCache = url;
    return url;
  }
  
  // Cache for storing fetched data
  static Map<String, dynamic> _cache = {};
  static Map<String, DateTime> _cacheTimestamps = {};

  // Unified JSON decoder with HTML detection and better errors
  static dynamic _decodeJsonOrThrow(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final body = response.body;
    final isHtml = contentType.contains('text/html') ||
        RegExp(r'<!DOCTYPE|<html', caseSensitive: false).hasMatch(body);
    if (isHtml) {
      throw Exception('Server mengembalikan HTML, bukan JSON. Periksa konfigurasi API.');
    }
    try {
      return json.decode(body);
    } on FormatException {
      throw Exception('Format data tidak valid. Periksa konfigurasi API.');
    }
  }

  static Exception _friendlyException(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid argument(s): No host specified in URI') || msg.contains('FormatException: Invalid empty scheme')) {
      return Exception('Base URL tidak valid. Buka Setting > API Configuration dan isi alamat lengkap, contoh: https://domain.com/api');
    }
    if (msg.contains('SocketException')) {
      return Exception('Tidak dapat terhubung ke server. Periksa koneksi internet atau Base URL.');
    }
    if (msg.contains('TimeoutException')) {
      return Exception('Koneksi ke server timeout. Silakan coba lagi.');
    }
    return Exception('Error: ${msg.replaceFirst('Exception: ', '')}');
  }

  static Future<Map<String, dynamic>> getAllUsers() async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/get_all_users.php'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // Save single user
  static Future<Map<String, dynamic>> saveUser({
    required String username,
    required String password,
    required String profile,
    String? wa,
    String? maps,
    String? foto,
    String? tanggalDibuat,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/save_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
          'profile': profile,
          'wa': wa,
          'maps': maps,
          'foto': foto,
          'tanggal_dibuat': tanggalDibuat,
        }),
      );
      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        // invalidate related caches after successful mutation
        _cache.remove('all_users_with_payments');
        _cacheTimestamps.remove('all_users_with_payments');
        return decoded;
      } else {
        throw Exception('Failed to save user');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // Update user data tambahan
  static Future<Map<String, dynamic>> updateUserData({
    required String username,
    String? wa,
    String? maps,
    String? foto,
    int? odpId,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/update_data_tambahan.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'wa': wa ?? '',
          'maps': maps ?? '',
          if (foto != null) 'foto': foto,
          'odp_id': odpId,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (result['success'] == true) {
          // invalidate related caches after successful mutation
          _cache.remove('all_users_with_payments');
          _cacheTimestamps.remove('all_users_with_payments');
          return result;
        } else {
          if (result['error'] == 'DEBUG_MODE') {
            throw Exception(json.encode(result['debug_data']));
          }
          throw Exception(result['message'] ?? 'Gagal mengupdate data dari server');
        }
      } else {
        // Coba decode body untuk mendapatkan pesan error dari PHP
        String errorMessage = 'Gagal mengupdate data: ${response.statusCode}';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody['error'] != null) {
            errorMessage = 'Error dari server: ${errorBody['error']}';
          }
        } catch (_) {
          // Gagal decode, gunakan response body mentah jika ada
          if (response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  // Export multiple users
  static Future<Map<String, dynamic>> exportUsers(List<Map<String, dynamic>> users) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/export_ppp.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(users),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to export users');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }

  static Future<bool> deleteUser(String username) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/delete_user.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username}),
    );
    if (response.statusCode == 200) {
      final data = _decodeJsonOrThrow(response) as Map<String, dynamic>;
      if (data['success'] == true) {
        // invalidate related caches after successful mutation
        _cache.remove('all_users_with_payments');
        _cacheTimestamps.remove('all_users_with_payments');
        return true;
      }
      throw Exception(data['error'] ?? 'Gagal menghapus user');
    } else {
      throw Exception('Gagal menghapus user: ${response.statusCode}');
    }
  }
  
  // New method to fetch all users with payments
  static Future<List<Map<String, dynamic>>> fetchAllUsersWithPayments() async {
    try {
      // Check cache first
      final cacheKey = 'all_users_with_payments';
      if (_cache.containsKey(cacheKey) && 
          _cacheTimestamps.containsKey(cacheKey) &&
          DateTime.now().difference(_cacheTimestamps[cacheKey]!).inMinutes < 5) {
        return List<Map<String, dynamic>>.from(_cache[cacheKey]);
      }
      
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/get_all_users_with_payments.php'),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Koneksi timeout. Silakan coba lagi.'),
      );
      
      if (response.statusCode == 200) {
        final data = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          // Proper type conversion to avoid casting errors
          final List<dynamic> rawData = data['data'] as List<dynamic>;
          final List<Map<String, dynamic>> convertedData = rawData
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          
          // Cache the result
          _cache[cacheKey] = convertedData;
          _cacheTimestamps[cacheKey] = DateTime.now();
          
          return convertedData;
        } else {
          throw Exception(data['message'] ?? 'Gagal memuat data tagihan');
        }
      } else {
        throw Exception('Server error (${response.statusCode}). Silakan coba lagi.');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }
  
  // New method to fetch payment summary
  static Future<List<Map<String, dynamic>>> fetchPaymentSummary() async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/get_payment_summary.php'),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Koneksi timeout. Silakan coba lagi.'),
      );
      
      // Check for redirect responses
      if (response.statusCode == 302 || response.statusCode == 301) {
        throw Exception('API memerlukan autentikasi. Silakan hubungi administrator.');
      }
      
      if (response.statusCode == 200) {
        final data = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (data['success'] == true) {
          final List<dynamic> rawList = data['data'] as List<dynamic>;
          // Normalize types to avoid runtime type errors on UI
          return rawList.map((item) {
            final itemMap = Map<String, dynamic>.from(item as Map);
            final month = int.tryParse(itemMap['month'].toString()) ?? (itemMap['month'] is int ? itemMap['month'] as int : 0);
            final year = int.tryParse(itemMap['year'].toString()) ?? (itemMap['year'] is int ? itemMap['year'] as int : 0);
            final totalNum = double.tryParse(itemMap['total'].toString());
            final total = totalNum ?? (itemMap['total'] is num ? (itemMap['total'] as num).toDouble() : 0.0);
            final count = int.tryParse(itemMap['count'].toString()) ?? (itemMap['count'] is int ? itemMap['count'] as int : 0);
            return {
              'month': month,
              'year': year,
              'total': total,
              'count': count,
            };
          }).toList();
        } else {
          throw Exception(data['error'] ?? 'Gagal memuat ringkasan pembayaran');
        }
      } else {
        throw Exception('Server error (${response.statusCode}). Silakan coba lagi.');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }
  
  // New method to fetch all payments for a specific month and year
  static Future<List<Map<String, dynamic>>> fetchAllPaymentsForMonthYear(int month, int year) async {
    try {
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/get_all_payments_for_month_year.php').replace(
        queryParameters: {
          'month': month.toString(),
          'year': year.toString(),
        },
      );
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Koneksi timeout. Silakan coba lagi.'),
      );
      
      // Check for redirect responses
      if (response.statusCode == 302 || response.statusCode == 301) {
        throw Exception('API memerlukan autentikasi. Silakan hubungi administrator.');
      }
      
      if (response.statusCode == 200) {
        final data = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        if (data['success'] == true) {
          final List<dynamic> rawData = data['data'] as List<dynamic>;
          final raw = rawData.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          
          // Normalize for detail screen
          return raw.map((p) {
            final amountNum = double.tryParse(p['amount'].toString());
            return {
              ...p,
              'amount': amountNum ?? (p['amount'] is num ? (p['amount'] as num).toDouble() : 0.0),
              'username': (p['username'] ?? p['user_id'] ?? '-').toString(),
              'method': (p['method'] ?? '-').toString(),
              'payment_date': (p['payment_date'] ?? '-').toString(),
              'note': (p['note'] ?? '').toString(),
            };
          }).toList();
        } else {
          throw Exception(data['error'] ?? 'Gagal memuat detail pembayaran');
        }
      } else {
        throw Exception('Server error (${response.statusCode}). Silakan coba lagi.');
      }
    } catch (e) {
      throw _friendlyException(e);
    }
  }
  
  // New method to clear cache
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }
}