# ⛓️ TrashQuest Automated Blockchain Certificate Ecosystem

Sistem otomatisasi pencetakan piagam dan sertifikat verified langsung ke jaringan **Ethereum Sepolia Testnet** tanpa perlu mengetik atau mengeklik tombol di **Remix IDE** secara manual!

---

## 🏗️ Komponen Sistem Otomatisasi

### 1. Smart Contract (`TrashQuestCert.sol`)
* **Jaringan**: Ethereum Sepolia Testnet (ChainID: `11155111`)
* **Alamat Smart Contract**: `0xc4b19b885b4426974701774741F64E67977C6B17`
* **Etherscan**: [Lihat Kontrak di Sepolia Etherscan](https://sepolia.etherscan.io/address/0xc4b19b885b4426974701774741F64E67977C6B17)
* **Fungsi Utama**:
  * `mintCertificate(string certId, string recipientName, string achievementTitle)`
  * `verifyCertificate(string certId)`
  * `totalCertificates()`

---

### 2. Skrip Otomatisasi 1-Baris (`auto_mint.js`)
Mencetak satu piagam secara instan dari terminal atau command prompt:
```bash
cd blockchain
node auto_mint.js "TRQ-CERT-SORTING_MASTER-101" "Farrel Raditya" "Sorting Master"
```
Atau cukup klik dua kali file **`run_auto_mint.bat`** di Windows.

---

### 3. Skrip Batch Otomatis (`batch_mint.js`)
Mencetak seluruh 6 piagam pencapaian sekaligus untuk satu pengguna dalam sekali jalan:
```bash
node batch_mint.js "Farrel Raditya"
```

---

### 4. REST API Server Relayer (`server.js`)
Server backend otomatis yang siap menerima panggilan HTTP dari aplikasi mobile atau web:
```bash
npm run server
# Atau double click start_server.bat
```
* **Endpoint Status**: `GET http://localhost:3000/api/status`
* **Endpoint Mint Otomatis**: `POST http://localhost:3000/api/mint`
  ```json
  {
    "certId": "TRQ-CERT-SORTING_MASTER-999",
    "recipientName": "Farrel Raditya",
    "achievementTitle": "Master Pemilahan Sampah",
    "achievementCode": "SORTING_MASTER",
    "userId": "user-uuid"
  }
  ```
* **Endpoint Verifikasi On-Chain**: `GET http://localhost:3000/api/verify/:txHash`

---

### 5. Otomatisasi Langsung di Aplikasi Mobile Flutter
Pengguna tidak perlu tahu tentang backend atau Remix:
1. Buka tab **Profil & Pengaturan** atau **Blockchain Explorer** di aplikasi.
2. Ketuk salah satu pencapaian/piagam.
3. Klik tombol hijau **`⚡ Mint Otomatis ke Blockchain Sepolia`**.
4. Aplikasi akan secara otomatis:
   - Terhubung ke Node RPC Ethereum Sepolia (`https://ethereum-sepolia-rpc.publicnode.com`).
   - Memeriksa gas price dan nonce blok.
   - Meng-encode data transaksi `mintCertificate(...)`.
   - Menandatangani & menerbitkan transaksi ke Sepolia mempool.
   - Menyimpan `TxHash` unik pengguna ke database lokal SQLite (`offline_achievements`).
   - Menyediakan tombol langsung **`Cek di Sepolia Etherscan ↗`** yang membuka transaksi on-chain resmi.
