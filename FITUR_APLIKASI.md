# 🌿 Dokumentasi Fitur Aplikasi TrashQuest

Dokumen ini merangkum seluruh fitur, arsitektur modul, sensor perangkat keras, serta implementasi kecerdasan buatan (AI) yang ada di dalam codebase **TrashQuest**.

---

## 📑 Daftar Isi
1. [Arsitektur & Fondasi Sistem](#1-arsitektur--fondasi-sistem)
2. [Fitur Kecerdasan Buatan (AI Intelligence)](#2-fitur-kecerdasan-buatan-ai-intelligence)
3. [Gamifikasi & Mini-Games Interaktif](#3-gamifikasi--mini-games-interaktif)
4. [Eksplorasi Peta & Navigasi Kompas Lingkungan](#4-eksplorasi-peta--navigasi-kompas-lingkungan)
5. [Ekonomi Sirkular & Reward (Redeem XP)](#5-ekonomi-sirkular--reward-redeem-xp)
6. [Blockchain Eco-Ledger & Verifikasi Kriptografi](#6-blockchain-eco-ledger--verifikasi-kriptografi)
7. [Pusat Notifikasi & Real-Time Alert](#7-pusat-notifikasi--real-time-alert)
8. [Autentikasi & Keamanan Biometrik](#8-autentikasi--keamanan-biometrik)
9. [Utilitas Internasional (Mata Uang & Zona Waktu)](#9-utilitas-internasional-mata-uang--zona-waktu)
10. [Struktur Berkas & Modul](#10-struktur-berkas--modul)

---

## 1. Arsitektur & Fondasi Sistem
* **Framework:** Flutter (Dart SDK ^3.13) dengan desain Material 3 dan token desain terpusat (`AppColors`, `AppSpacing`, `AppTextStyles`).
* **Offline-First Storage (`SqliteService`):**
  * Seluruh data operasional disimpan lokal terlebih dahulu di SQLite (`trashquest_local.db`), mencakup riwayat scan, ensiklopedia sampah, direktori bank sampah, progress quest, sertifikat, transaksi reward, dan notifikasi.
* **Sinkronisasi Cloud (`SupabaseService` & `SyncService`):**
  * Sinkronisasi data lokal ke Supabase PostgreSQL saat perangkat terhubung internet.
  * Mendukung *Realtime Stream* untuk update data profil, poin XP, dan papan peringkat (*leaderboard*).
* **Sensor Fusion Hardware (`SensorService` & `CompassService`):**
  * Penggabungan data *Accelerometer* dan *Gyroscope* dengan algoritma *Low-Pass Filter* untuk kendali kemiringan (*tilt steering*).
  * Sensor *Magnetometer* untuk perhitungan arah mata angin (*bearing & heading*).

---

## 2. Fitur Kecerdasan Buatan (AI Intelligence)

### 📸 A. AI Multimodal Waste Scanner
* **Lokasi Berkas:** [`ScannerView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/scanner/scanner_view.dart), [`GeminiService`](file:///c:/TA_PM_Trashquesh/trashquest/lib/services/gemini_service.dart)
* **Mesin AI:**
  * **Jalur Utama:** **Groq Vision** (`qwen/qwen3.8-27b`) dengan waktu respons sangat cepat (~1.1 detik).
  * **Jalur Cadangan:** **Google Gemini** (`gemini-3.1-flash-lite` / `gemini-3.8-flash`) yang aktif otomatis jika ada kendala jaringan.
* **Fitur & Kemampuan:**
  * Pengambilan gambar via Kamera langsung atau Galeri HP dengan kompresi cerdas.
  * Animasi pemindai laser HUD bertema cyberpunk-eco.
  * Deteksi kategori: **Organik**, **Anorganik**, **Limbah B3**, dan **Residu**.
  * Rincian analisis terstruktur:
    1. **Nama Material Spesifik** (contoh: *Botol Plastik PET*, *Kardus Kemasan*, *Baterai Litium*).
    2. **Status Daur Ulang** (*Recyclable* / *Non-recyclable*).
    3. **Panduan Pembuangan Praktis** (*Disposal Advice* langkah demi langkah).
    4. **Fakta Ilmiah & Tips Penanganan** (*Scientific Notes*).
    5. **Ide Upcycling Kreatif** (Inspirasi kerajinan tangan / DIY guna ulang).
    6. **Estimasi Nilai Jual Bank Sampah** (Perkiraan harga per kg di Bank Sampah Indonesia).
    7. **Dampak Pengurangan Emisi Karbon** (Kalkulasi penghematan $CO_2$).
    8. **Waktu Penguraian Alami** (Estimasi durasi pembusukan jika dibuang ke alam).
  * Hadiah XP langsung + Selebrasi animasi konfeti.
  * Pintasan navigasi langsung ke Bank Sampah terdekat pada peta.

### 💬 B. TrashQuest AI Assistant (Chatbot Konsultasi)
* **Lokasi Berkas:** [`AiAssistantView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/ai_assistant/ai_assistant_view.dart), [`GeminiService`](file:///c:/TA_PM_Trashquesh/trashquest/lib/services/gemini_service.dart)
* **Mesin AI:**
  * **Groq LPU Engine** (`openai/gpt-oss-120b` / `qwen/qwen3.8-27b`) dengan kecepatan respon instan (~700ms).
  * **Fallback Google Gemini** untuk keandalan maksimal.
* **Fitur & Kemampuan:**
  * Percakapan dua arah dalam Bahasa Indonesia sehari-hari yang luwes, alami, dan ramah.
  * Khusus dibatasi seputar sains limbah, jenis dan pemilahan sampah, komposting, bank sampah, upcycling DIY barang bekas, dan pelestarian lingkungan (jika ditanyakan di luar konteks, AI secara sopan menolak dengan kata maaf).
  * *Suggestion Chips* (pertanyaan pemicu cepat saat percakapan baru).
  * Pengelolaan histori obrolan dan tombol *Reset Chat*.
  * Dialog konfigurasi API Key (memungkinkan pengguna memasukkan custom key dari Google AI Studio atau Groq).

---

## 3. Gamifikasi & Mini-Games Interaktif

TrashQuest memiliki 5 jenis mini-game yang dirancang untuk pembelajaran interaktif sekaligus hiburan:

### 🎮 1. Bio-Eater: Plastic Hunter (Sci-Fi Action)
* **Lokasi Berkas:** [`BioEaterGameView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/quest/bio_eater_game_view.dart)
* **Mekanika:**
  * Pemain mengendalikan mikroba pemakan mikroplastik di dunia mikro menggunakan simulasi fisika fluida amoeba.
  * Menelan partikel mikroplastik (*PET Shard, Nano Pellet, Synthetic Fiber*).
  * Menghindari racun berbahaya (*Acid Toxin, Spiked Metal, Virus Cluster*).
  * Ledakan pamungkas **Enzyme Supernova** saat energi penuh untuk membersihkan seluruh layar.
  * Power-ups: *Hyper Enzyme*, *Bio Shield*, dan *Magnet Vortex*.

### 🐕 2. Paw Toss: Anjing vs Kucing (Fisika Balistik)
* **Lokasi Berkas:** [`BackyardBattleScreen`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/quest/paw_toss_game.dart)
* **Mekanika:**
  * Mode lanskap (*landscape mode*) dengan pertempuran proyektil balistik turn-based melintasi pagar halaman.
  * Memperhitungkan kalkulasi sudut elevasi, daya lempar (*power meter*), dan pengaruh kecepatan angin (*wind vector*).
  * Variasi proyektil: *Classic Bone/Fish*, *Slipper* (sandal jepit), *Basketball* (memantul di tanah/pagar), dan *Heavy Splash* (balon air jumbo).
  * AI lawan cerdas dengan kalkulasi lintasan adaptif.

### 📱 3. Trash Sorter (Sensor Gerak HP)
* **Lokasi Berkas:** [`TrashSorterGameView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/quest/trash_sorter_game_view.dart)
* **Mekanika:**
  * Memanfaatkan sensor fisik perangkat (*Accelerometer + Gyroscope*) melalui [`SensorService`](file:///c:/TA_PM_Trashquesh/trashquest/lib/services/sensor_service.dart).
  * Miringkan ponsel ke kiri atau kanan untuk mengarahkan sampah yang jatuh ke tempat sampah yang sesuai (Organik, Anorganik, B3, Residu).
  * Sistem kombo streak poin dan peningkatan kecepatan jatuh bertahap.

### ⚔️ 4. Trash Ninja (Fast Swipe Slicing)
* **Lokasi Berkas:** [`TrashNinjaGameView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/quest/trash_ninja_game_view.dart)
* **Mekanika:**
  * Gerakan gestur gesek (*slash*) cepat layaknya ninja.
  * Membelah sampah organik dan anorganik untuk mengumpulkan poin dan kombo.
  * Menghindari sampah racun B3 agar nyawa tidak berkurang.
  * Efek partikel visual warna-warni sesuai kategori sampah.

### 🧠 5. Kuis Pilah Cerdas (Waste Quiz)
* **Lokasi Berkas:** [`WasteQuizView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/quest/waste_quiz_view.dart)
* **Mekanika:**
  * Pertanyaan pilihan ganda edukatif seputar pengelolaan limbah rumah tangga.
  * Penjelasan ilmiah mendalam setelah setiap jawaban dipilih.
  * Hadiah XP akumulatif untuk setiap jawaban yang benar.

### 🏆 6. Quest & Leaderboard Komunitas
* **Lokasi Berkas:** [`QuestView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/quest/quest_view.dart)
* **Fitur:**
  * Daftar Misi Harian & Tantangan Mingguan dengan target kuantitatif dan progress bar.
  * Klaim hadiah XP yang otomatis memicu notifikasi lokal.
  * Papan peringkat komunitas langsung (*Live Supabase Leaderboard*) dengan tier peringkat Emas, Perak, dan Perunggu.

---

## 4. Eksplorasi Peta & Navigasi Kompas Lingkungan

### 🗺️ A. Peta Interaktif Bank Sampah (Explore View)
* **Lokasi Berkas:** [`ExploreView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/map/explore_view.dart)
* **Teknologi:** OpenStreetMap / Leaflet via `flutter_map` dan `latlong2`.
* **Fitur:**
  * Pelacakan koordinat GPS terkini pengguna via [`LocationService`](file:///c:/TA_PM_Trashquesh/trashquest/lib/services/location_service.dart).
  * Marker interaktif lokasi Bank Sampah dan Pusat Daur Ulang resmi.
  * Filter jenis material yang diterima (Plastik, Kertas, Kardus, E-Waste, Logam).
  * Kolom pencarian teks berdasarkan nama bank sampah atau kelurahan/alamat.
  * Modal detail bank sampah: jam operasional, nomor kontak, jenis sampah yang diterima, dan kalkulasi jarak instan ($km$).

### 🧭 B. Kompas Navigasi Presisi (Compass View)
* **Lokasi Berkas:** [`CompassView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/compass/compass_view.dart), [`CompassService`](file:///c:/TA_PM_Trashquesh/trashquest/lib/services/compass_service.dart)
* **Fitur:**
  * Kompas digital berputar halus mengikuti sensor kompas/magnetometer fisik ponsel.
  * Menghitung sudut arah (*bearing*) secara matematis antara koordinat pengguna dan Bank Sampah tujuan.
  * Menampilkan jarak tersisa secara *real-time* dan memandu pengguna langsung ke lokasi fisik penyetoran sampah.

---

## 5. Ekonomi Sirkular & Reward (Redeem XP)

* **Lokasi Berkas:** [`RedeemView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/rewards/redeem_view.dart)
* **Konsep:** Mengubah kepedulian lingkungan dan keaktifan memilah sampah menjadi nilai ekonomi riil (*1 XP = Rp 1*).
* **Kategori Penukaran:**
  1. **E-Wallet & Saldo:** GoPay, DANA, OVO, dan ShopeePay.
  2. **Pulsa & Tagihan:** Pulsa Telkomsel, Pulsa Indosat, Token Listrik PLN (voucher 20 digit), dan Potongan Tagihan Air PDAM.
  3. **Kebutuhan Pokok (Sembako):** Beras Premium 5 Kg, Minyak Goreng 2L, Telur Ayam 1 Kg, Gula Pasir, Mie Instan 1 Dus, Detergen, dan Susu Kental Manis.
* **Fitur Tambahan:**
  * Dialog konfirmasi input nomor e-wallet / nomor HP.
  * Pembuatan kode voucher instan yang dapat disalin ke clipboard dengan 1 ketukan.
  * Riwayat transaksi offline di SQLite dan sinkronisasi ke cloud Supabase.
  * Pemicu notifikasi lokal otomatis saat penukaran berhasil.

---

## 6. Blockchain Eco-Ledger & Verifikasi Kriptografi

* **Lokasi Berkas:** [`BlockchainView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/blockchain/blockchain_view.dart)
* **Tujuan:** Menjamin keaslian sertifikat dan prestasi pelestarian lingkungan agar tidak dapat dimanipulasi atau dipalsukan (*tamper-proof*).
* **Fitur Kunci:**
  * **Kanonikal ID Sertifikat:** Format unik `TRQ-CERT-{CODE}-{USER_ID}`.
  * **Immutability Hash SHA-256:** Perhitungan hash kriptografi langsung dari metadata capaian, user ID, dan timestamp presisi.
  * **Live Cryptographic Verifier:** Input hash manual untuk memeriksa validitas sertifikat pada buku besar digital (*Eco-Ledger*).
  * Tampilan sertifikat digital siap pamer (*shareable digital credential*).

---

## 7. Pusat Notifikasi & Real-Time Alert

* **Lokasi Berkas:** [`NotificationService`](file:///c:/TA_PM_Trashquesh/trashquest/lib/services/notification_service.dart), [`NotificationModal`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/home/widgets/notification_modal.dart)
* **Teknologi:** `flutter_local_notifications` + Overlay dinamis kustom.
* **Fitur:**
  * **Notifikasi Sistem Baki HP:** Notifikasi melayang di status bar dengan ikon aplikasi, suara, dan getaran haptik.
  * **In-App Dynamic Island / Floating Banner:** Banner melayang di atas layar aplikasi dengan animasi halus saat aksi selesai di dalam aplikasi.
  * **Pusat Notifikasi Interaktif:**
    * Filter kategori: *Semua*, *Misi*, *Reward*, *Edukasi*, dan *Sistem*.
    * Penanda pesan dibaca / belum dibaca (*unread count badge*).
    * Opsi tandai semua telah dibaca (*Mark all as read*).
    * Simulator tes notifikasi *real-time* langsung di dalam aplikasi.

---

## 8. Autentikasi & Keamanan Biometrik

* **Lokasi Berkas:** [`AuthView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/auth/auth_view.dart), [`BiometricService`](file:///c:/TA_PM_Trashquesh/trashquest/lib/services/biometric_service.dart)
* **Fitur:**
  * Login dan Registrasi berbasis Supabase Auth (Email & Password).
  * Validasi form interaktif dengan efek glow fokus.
  * **Sensor Biometrik (Sidik Jari / Face Unlock):**
    * Integrasi `local_auth` untuk login cepat dan aman.
    * Tombol switch di halaman Profil untuk mengaktifkan atau menonaktifkan autentikasi biometrik.
    * Dukungan fallback graceful pada perangkat yang tidak memiliki hardware sensor biometrik.

---

## 9. Utilitas Internasional (Mata Uang & Zona Waktu)

### 💱 A. Konversi Mata Uang (`CurrencyView`)
* **Lokasi Berkas:** [`CurrencyView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/currency/currency_view.dart), [`CurrencyService`](file:///c:/TA_PM_Trashquesh/trashquest/lib/services/currency_service.dart)
* **Fitur:** Kalkulator pertukaran kurs mata uang internasional (**IDR, USD, SGD, EUR**) untuk estimasi valuasi perdagangan daur ulang lintas negara dan kredit karbon global.

### 🌐 B. Konversi Zona Waktu (`TimezoneView`)
* **Lokasi Berkas:** [`TimezoneView`](file:///c:/TA_PM_Trashquesh/trashquest/lib/features/timezone/timezone_view.dart), [`TimezoneService`](file:///c:/TA_PM_Trashquesh/trashquest/lib/services/timezone_service.dart)
* **Fitur:** Jam digital *real-time* multi-zona waktu (**WIB UTC+7, WITA UTC+8, WIT UTC+9, dan London BST/GMT**) dengan kalkulasi penyesuaian musim panas (*Daylight Saving Time / DST*) untuk sinkronisasi seminar dan kampanye lingkungan global.

---

## 10. Struktur Berkas & Modul

```text
lib/
├── app/
│   ├── app.dart                     # Entry flow (Splash -> Onboarding -> Auth -> Main)
│   ├── main_navigation_layout.dart  # Bottom navigation bar & dock FAB Scanner
│   └── theme/                       # Palet warna, tipografi, dan margin spacing
├── core/
│   └── widgets/                     # Komponen UI bersama (logo, badges, kartu XP, ambient)
├── data/
│   └── models/                      # Model data (UserProfile, WasteItem, WasteScan, Quests, dll)
├── features/
│   ├── ai_assistant/                # Antarmuka Chatbot AI pintar
│   ├── auth/                        # Halaman Login & Registrasi
│   ├── blockchain/                  # Eco-Ledger & Verifikator Hash SHA-256
│   ├── compass/                     # Kompas penunjuk arah Bank Sampah
│   ├── currency/                    # Kalkulator konversi mata uang
│   ├── encyclopedia/                # Detail materi & edukasi pemilahan sampah
│   ├── feedback/                    # Formulir ulasan dan penilaian pengguna
│   ├── home/                        # Dashboard utama, ringkasan dampak, & modal notifikasi
│   ├── map/                         # Peta interaktif sebaran Bank Sampah
│   ├── onboarding/                  # Pengenalan fitur aplikasi untuk pengguna baru
│   ├── profile/                     # Profil pengguna, pencapaian, dan pengaturan akun
│   ├── quest/                       # 5 Mini-games edukatif & papan peringkat (leaderboard)
│   ├── rewards/                     # Penukaran XP (e-wallet, pulsa, sembako) & voucher
│   ├── scanner/                     # Pemindai kamera AI Vision & riwayat scan
│   ├── splash/                      # Tampilan pembuka aplikasi
│   └── timezone/                    # Sinkronisasi jam & zona waktu dunia
├── services/                        # Service layer (AI, SQLite, Supabase, Biometrik, Sensor, Notifikasi)
└── main.dart                        # Titik masuk utama aplikasi (Initialization)
```
