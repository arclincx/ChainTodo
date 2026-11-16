# ChainTodo — Aplikasi To-Do List Berbasis Blockchain (Flutter & Sepolia)

Aplikasi mobile Flutter untuk membaca dan menulis daftar tugas secara *on-chain* pada jaringan uji **Ethereum Sepolia** menggunakan paket `web3dart` tanpa server maupun database lokal.

---

## 1. Informasi Smart Contract & Link Etherscan

* **Jaringan:** Ethereum Sepolia Testnet (`Chain ID: 11155111`)
* **Alamat Kontrak:** `0x...` *(ganti dengan alamat kontrak Sepolia Anda)*
* **Link Sepolia Etherscan:** `https://sepolia.etherscan.io/address/0x...` *(ganti dengan link kontrak terverifikasi Anda)*
* **Berkas Kontrak:** `ChainTodo.sol`

---

## 2. Versi Paket (`pubspec.yaml`)

Sesuaikan nomor versi di bawah ini dengan isi `pubspec.yaml` proyek Anda:

* **Flutter SDK:** `>=3.x.x` (Stable)
* **Solidity:** `^0.8.20`
* **Dependensi Utama:**
  * `web3dart: ^3.0.0`
  * `http: ^1.2.0`
  * `flutter_dotenv: ^5.1.0`

---

## 3. Cara Menjalankan Aplikasi

### Prasyarat
* Flutter SDK terpasang (`flutter doctor` siap digunakan).
* Endpoint RPC Sepolia (misalnya `https://ethereum-sepolia-rpc.publicnode.com` atau URL RPC Alchemy/Infura).
* Wallet khusus testnet dengan saldo Sepolia ETH gratis dari faucet.

### Langkah-Langkah
1. **Clone repositori dan masuk ke direktori proyek:**
   ```bash
   git clone <url-repositori-anda>
   cd <nama-folder-proyek>
   ```

2. **Buat dan isi berkas konfigurasi `.env` di root proyek:**
   ```env
   RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
   CHAIN_ID=11155111
   CONTRACT_ADDRESS=0xAlamatKontrakSepoliaAnda
   PRIVATE_KEY=0xPrivateKeyWalletTestnetAnda
   ```
   *(Catatan: Berkas `.env` diabaikan oleh `.gitignore` sehingga private key tidak ikut terunggah ke repositori.)*

3. **Unduh dependensi Flutter:**
   ```bash
   flutter pub get
   ```

4. **Jalankan aplikasi:**
   ```bash
   # Perangkat Android / Emulator
   flutter run

   # Atau Windows Desktop
   flutter run -d windows
   ```

5. **Build file `.apk` (Release):**
   ```bash
   flutter build apk --release
   ```
   Berkas hasil build berada di `build/app/outputs/flutter-apk/app-release.apk`.

---

## Referensi & Atribusi

* Kerangka smart contract `ChainTodo.sol` diadaptasi dari panduan tugas mata kuliah *Pemrograman Mobile 2* (Politeknik Negeri Samarinda).
* Rujukan pengembangan Dart/Ethereum: *Build a Blockchain dApp with Flutter and Dart on Ethereum* (Ethereum.org).
* Bantuan AI digunakan selama proses pengembangan untuk penyesuaian integrasi `web3dart` dan penyusunan dokumentasi.