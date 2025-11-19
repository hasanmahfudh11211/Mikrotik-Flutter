# Mikrotik-PPPoE-Monitor

Aplikasi monitoring user PPPoE Mikrotik berbasis Flutter dan REST API. Memudahkan monitoring, manajemen, dan analisis user PPPoE secara real-time. Dibuat untuk tugas akhir/skripsi dan kebutuhan monitoring jaringan.

---

## ✨ Fitur Utama
- **Monitoring User PPPoE**: Lihat daftar user aktif, status koneksi, profil, dan detail user secara real-time.
- **Manajemen User**: Tambah, edit, dan hapus user PPPoE langsung dari aplikasi.
- **Integrasi REST API**: Komunikasi dengan perangkat Mikrotik menggunakan REST API yang aman dan efisien.
- **Log & Statistik**: Tersedia log aktivitas dan statistik penggunaan untuk analisis jaringan.
- **UI Modern & Responsif**: Tampilan modern, mendukung dark mode, dan responsif di berbagai perangkat.
- **Notifikasi & Error Handling**: Penanganan error yang informatif dan notifikasi status aksi.
- **Manajemen Pembayaran**: Fitur billing untuk mencatat dan melacak pembayaran user.
- **Manajemen ODP**: Integrasi dengan Optical Distribution Point untuk pelacakan lokasi user.
- **Export Data**: Ekspor data user dan pembayaran ke format Excel dan PDF.
- **Auto Update System**: System update otomatis tanpa perlu membagikan APK secara manual.

---

## 🚀 Teknologi yang Digunakan
- **Flutter** (Dart)
- **Provider** (state management)
- **REST API** (komunikasi dengan Mikrotik)
- **Material Design**
- **HTTP Client** (untuk komunikasi dengan backend)
- **Image Picker** (untuk upload foto lokasi)
- **PDF Generator** (untuk export laporan)

---

## 🛠️ Cara Instalasi & Build

### Quick Start (15 menit)
Lihat **[QUICK_START.md](QUICK_START.md)** untuk panduan cepat setup aplikasi.

### Detailed Installation
1. **Clone repository ini:**
    ```bash
    git clone https://github.com/yahahahusein112/Mikrotik-PPPoE-Monitor.git
    cd Mikrotik-PPPoE-Monitor
    ```
2. **Setup Database:**
    ```bash
    mysql -u root -p < database_schema.sql
    ```
3. **Configure Backend:**
    ```bash
    cd api
    cp .env.example .env
    # Edit .env dengan database credentials Anda
    ```
4. **Install Flutter dependencies:**
    ```bash
    flutter pub get
    ```
5. **Jalankan aplikasi di emulator/device:**  
    ```bash
    flutter run
    ```
6. **Build APK release:**
    ```bash
    flutter build apk --release
    ```

📖 **Untuk deployment ke production, baca [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**

---

## ⚙️ Konfigurasi Mikrotik
- Pastikan perangkat Mikrotik sudah mengaktifkan REST API.
- Masukkan IP, port, username, dan password Mikrotik pada aplikasi saat login.

---

## 🔧 Kompatibilitas & Persyaratan Mikrotik

Aplikasi ini menggunakan **Mikrotik REST API** sebagai jalur komunikasi antara aplikasi Flutter dan perangkat Mikrotik. Perlu diketahui bahwa REST API **hanya tersedia pada RouterOS versi 7.9 ke atas**. Versi yang lebih lama **tidak mendukung** komunikasi REST dan akan menyebabkan kegagalan koneksi.

> **Versi minimum RouterOS yang didukung:** `7.9`  
> **Port default REST API:** `80` (atau sesuai pengaturan WebFig)  
> **Protokol komunikasi:** `HTTP/HTTPS` (disarankan menggunakan HTTPS untuk keamanan)

### Langkah Aktivasi REST API:
1. Masuk ke Mikrotik via Winbox/WebFig/Terminal.
2. Buka menu **IP > Services**, pastikan `www` (port 80) atau `www-ssl` (port 443) aktif.
3. Gunakan user dengan hak akses **full**.

📚 Dokumentasi resmi REST API Mikrotik:  
👉 [https://help.mikrotik.com/docs/display/ROS/REST+API](https://help.mikrotik.com/docs/display/ROS/REST+API)

---

## 📚 Dokumentasi

Project ini dilengkapi dengan dokumentasi lengkap:

| Dokumen | Deskripsi |
|---------|-----------|
| **[README.md](README.md)** | Overview & fitur aplikasi (file ini) |
| **[QUICK_START.md](QUICK_START.md)** | Panduan cepat mulai dalam 15 menit |
| **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** | Panduan lengkap deployment ke production |
| **[SECURITY_NOTES.md](SECURITY_NOTES.md)** | Security issues & best practices |
| **[PERBAIKAN_SUMMARY.md](PERBAIKAN_SUMMARY.md)** | Summary perbaikan yang sudah dilakukan |
| **[AUTO_UPDATE_SETUP_GUIDE.md](AUTO_UPDATE_SETUP_GUIDE.md)** | Panduan setup auto update system |
| **[DEPLOYMENT_AUTO_UPDATE.md](DEPLOYMENT_AUTO_UPDATE.md)** | Quick guide deployment auto update |
| **[database_schema.sql](database_schema.sql)** | Database schema & structure |
| **[API_BILLING_FIX_INSTRUCTIONS.md](API_BILLING_FIX_INSTRUCTIONS.md)** | Instruksi fix API billing issues |

### 🚀 Mulai Cepat
1. Baru pertama kali? → Baca **[QUICK_START.md](QUICK_START.md)**
2. Mau deploy production? → Baca **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**
3. Perlu info security? → Baca **[SECURITY_NOTES.md](SECURITY_NOTES.md)**

---

## 📄 Lisensi
Proyek ini menggunakan lisensi **GPL-3.0**. Silakan lihat file `LICENSE` untuk detail.

---

## 👤 Pengembang
- **Nama:** Hasan Mahfudh / Husein Braithweittt / YAHAHAHUSEINNN
- **Email:** hasanmahfudh112@gmail.com / yahahahusein112@gmail.com
- **Instagram:** [https://www.instagram.com/hasan.mhfdz](https://www.instagram.com/hasan.mhfdz)

---

## 📷 Screenshot

### Halaman Login
<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/login.jpg" width="300" alt="Halaman Login"/>
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/login2.jpg" width="300" alt="Koneksi Tersimpan"/>
</p>
<p align="center"><i>Tampilan untuk memasukkan kredensial Mikrotik dan daftar koneksi yang tersimpan.</i></p>

### Halaman Dashboard
<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/dashboard.jpg" width="300" alt="Dashboard Light Mode"/>
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/dashboard-dark.jpg" width="300" alt="Dashboard Dark Mode"/>
</p>
<p align="center"><i>Dashboard utama yang menampilkan ringkasan informasi, dengan dukungan tema terang dan gelap.</i></p>

### Halaman Tambah User
<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/tambah-user.jpg" width="300" alt="Tambah User"/>
</p>
<p align="center"><i>Formulir untuk menambahkan user PPPoE baru ke perangkat Mikrotik.</i></p>

### Halaman System Resource
<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/system-resource.jpg" width="300" alt="System Resource"/>
</p>
<p align="center"><i>Monitor penggunaan CPU, memori, dan uptime perangkat Mikrotik secara real-time.</i></p>

### Halaman Traffic
<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/traffic-online.jpg" width="300" alt="Traffic Online"/>
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/traffic-offline.jpg" width="300" alt="Traffic Offline"/>
</p>
<p align="center"><i>Grafik lalu lintas jaringan untuk user yang sedang online dan riwayat traffic user.</i></p>

### Halaman User PPP
<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/user-ppp.jpg" width="300" alt="User PPP"/>
</p>
<p align="center"><i>Menampilkan daftar semua user PPPoE yang terdaftar di perangkat.</i></p>

### Halaman Log
<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/log.jpg" width="300" alt="Log"/>
</p>
<p align="center"><i>Catatan log aktivitas yang terjadi pada sistem Mikrotik untuk keperluan audit.</i></p>

### Halaman Billing
<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/billing.jpg" width="300" alt="Billing"/>
</p>
<p align="center"><i>Manajemen pembayaran user dengan fitur filter berdasarkan bulan.</i></p>

### Halaman Ringkasan Pembayaran
<p align="center">
  <img src="https://raw.githubusercontent.com/hasanmahfudh11211/Monitoring-PPPoE-Mikrotik-Flutter/main/screenshot/payment-summary.jpg" width="300" alt="Payment Summary"/>
</p>
<p align="center"><i>Ringkasan pembayaran per bulan dengan kemampuan export ke Excel dan PDF.</i></p>

---

## 📢 Kontribusi
Kontribusi, saran, dan pull request sangat diterima!

---

## 📌 Catatan
- Aplikasi ini dikembangkan untuk kebutuhan tugas akhir/skripsi serta sebagai referensi pengembangan sistem monitoring berbasis Mikrotik.
- Komunikasi dengan Mikrotik **menggunakan REST API**, sehingga hanya kompatibel dengan **RouterOS versi 7.9 ke atas**.  
  Untuk versi lebih rendah, aplikasi **tidak dapat digunakan** karena tidak tersedianya endpoint REST.
- Jika Anda ingin mengembangkan aplikasi serupa namun untuk ROS versi lama, Anda dapat mempertimbangkan untuk menggunakan **API berbasis socket**.