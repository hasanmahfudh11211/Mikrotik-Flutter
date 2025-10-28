# 🔧 Instruksi Memperbaiki API Billing Backend

## 📋 Ringkasan Masalah

Aplikasi Flutter telah diperbaiki untuk menangani error dengan lebih baik. Namun, masih ada masalah di backend API yang perlu diperbaiki di server hosting `bedagung.space`.

## ❌ Error yang Terdeteksi

### 1. **Redirect Loop Error**
```
ClientException: Redirect loop detected, uri=admin.php?id=login
```

**Endpoint yang bermasalah:**
- `http://bedagung.space/api/get_payment_summary.php`
- `http://bedagung.space/api/get_all_payments_for_month_year.php`

**Penyebab:**
Server melakukan redirect ke halaman login (`admin.php?id=login`) saat mengakses API endpoint. Ini biasanya terjadi karena:
- Ada session/authentication requirement di hosting
- File `.htaccess` yang memaksa authentication
- Server firewall/WAF yang block request dari mobile app

## ✅ Solusi yang Sudah Diterapkan di Flutter App

### 1. **Type Casting Fix** ✔️
```dart
// Sebelum (Error)
return data['data'] as List<Map<String, dynamic>>;

// Sesudah (Fixed)
final List<dynamic> rawData = data['data'] as List<dynamic>;
final List<Map<String, dynamic>> convertedData = rawData
    .map((item) => Map<String, dynamic>.from(item as Map))
    .toList();
```

### 2. **Timeout Handling** ✔️
```dart
final response = await http.get(
  Uri.parse('$baseUrl/get_payment_summary.php'),
  headers: {'Accept': 'application/json'},
).timeout(
  const Duration(seconds: 15),
  onTimeout: () => throw Exception('Koneksi timeout. Silakan coba lagi.'),
);
```

### 3. **Redirect Detection** ✔️
```dart
// Check for redirect responses
if (response.statusCode == 302 || response.statusCode == 301) {
  throw Exception('API memerlukan autentikasi. Silakan hubungi administrator.');
}

// Check if response is HTML (redirect page) instead of JSON
if (response.body.trim().startsWith('<')) {
  throw Exception('Server mengembalikan halaman HTML bukan data JSON.');
}
```

### 4. **Better Error Messages** ✔️
```dart
if (e.toString().contains('SocketException')) {
  throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet.');
} else if (e.toString().contains('TimeoutException')) {
  throw Exception('Koneksi timeout. Silakan coba lagi.');
} else if (e.toString().contains('FormatException')) {
  throw Exception('Format data tidak valid. Periksa konfigurasi API.');
}
```

## 🛠️ Langkah Perbaikan di Backend Server

### **Opsi 1: Disable Authentication untuk API (Recommended)**

Jika API tidak memerlukan authentication:

1. Login ke cPanel hosting `bedagung.space`
2. Buka File Manager → folder `api/`
3. Cek file `.htaccess` di folder `api/`
4. Tambahkan rule untuk bypass authentication:

```apache
# .htaccess di folder api/
<FilesMatch "\.(php)$">
    # Allow API access without authentication
    Allow from all
    Satisfy Any
</FilesMatch>

# Atau disable authentication sepenuhnya
AuthType None
Require all granted
```

### **Opsi 2: Tambahkan API Key Authentication**

Jika perlu security:

1. Edit file API untuk cek API key:

**File: `api/get_payment_summary.php`** (tambahkan di line 17)
```php
<?php
// ... (existing headers) ...

// Simple API Key Authentication
$api_key = isset($_SERVER['HTTP_X_API_KEY']) ? $_SERVER['HTTP_X_API_KEY'] : '';
if ($api_key !== 'YOUR_SECRET_API_KEY_HERE') {
    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Unauthorized']);
    exit();
}

// ... (rest of code) ...
```

Lalu di Flutter app, tambahkan header:
```dart
headers: {
  'Accept': 'application/json',
  'X-API-KEY': 'YOUR_SECRET_API_KEY_HERE',
},
```

### **Opsi 3: Cek Server Configuration**

Jika server punya WAF (Web Application Firewall):

1. Login ke cPanel → **ModSecurity** atau **Firewall**
2. Whitelist IP ranges untuk mobile app access
3. Atau disable ModSecurity untuk folder `/api/`

## 📊 Testing API Endpoints

### **Cara Test Manual:**

**1. Via Browser:**
```
http://bedagung.space/api/get_payment_summary.php
```
Harusnya return JSON, bukan redirect ke admin.php

**2. Via cURL:**
```bash
curl -v http://bedagung.space/api/get_payment_summary.php
```
Cek apakah ada HTTP redirect (301/302)

**3. Via Postman:**
- Method: GET
- URL: `http://bedagung.space/api/get_payment_summary.php`
- Headers: `Accept: application/json`
- Expected Response:
```json
{
  "success": true,
  "data": [
    {
      "month": 10,
      "year": 2025,
      "total": 1500000,
      "count": 30
    }
  ]
}
```

## 🔍 Debug Checklist

- [ ] File PHP bisa diakses langsung via browser (tanpa redirect)
- [ ] Response adalah JSON (bukan HTML)
- [ ] Tidak ada HTTP 301/302 redirect
- [ ] Database connection berhasil
- [ ] Tabel `payments` exist di database
- [ ] Kolom `payment_month` dan `payment_year` exist di tabel

## 📝 Database Schema Required

Pastikan tabel database sudah benar:

```sql
CREATE TABLE IF NOT EXISTS `payments` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,
  `username` VARCHAR(255),
  `amount` DECIMAL(10,2) NOT NULL,
  `payment_date` DATE NOT NULL,
  `payment_month` INT NOT NULL,
  `payment_year` INT NOT NULL,
  `method` VARCHAR(50) DEFAULT 'Cash',
  `note` TEXT,
  `created_by` VARCHAR(255),
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 📞 Kontak Support

Jika masih bermasalah, hubungi:
- **Server Admin**: Periksa server logs di cPanel → Error Logs
- **Developer**: Cek aplikasi Flutter sudah bisa menampilkan error dengan jelas

## ✅ Status Perbaikan

| Component | Status | Keterangan |
|-----------|--------|------------|
| Flutter App Type Casting | ✅ Fixed | Sudah diperbaiki |
| Flutter Error Handling | ✅ Fixed | Sudah lebih user-friendly |
| Flutter Timeout Handler | ✅ Fixed | Timeout 15 detik |
| Backend API Access | ⚠️ Pending | Perlu cek di server |
| Database Schema | ⚠️ Unknown | Perlu verifikasi |

---

**Last Updated:** 23 Oktober 2025  
**Version:** 1.0


