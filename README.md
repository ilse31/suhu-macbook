# Suhu Mac

Aplikasi native macOS di menu bar untuk memantau suhu CPU, beban CPU,
RAM, dan storage. Swift + SwiftUI/AppKit, tanpa dependensi eksternal.

## Jalankan

Butuh macOS 13+ dan Xcode / Command Line Tools dengan Swift 5.9+.

```sh
bash scripts/build-app.sh
open "dist/Suhu Mac.app"
```

Klik ikon termometer/angka suhu di menu bar untuk membuka panel.
Klik **Keluar** untuk menghentikan aplikasi. Aplikasi tidak tampil di Dock.
File `.app` dapat disalin ke `/Applications` secara manual.

## Jalankan otomatis saat login

Simpan aplikasi di `/Applications/Suhu Mac.app`, buka aplikasi dari lokasi itu,
lalu aktifkan **Jalankan saat login** pada panel menu bar. Matikan toggle yang
sama untuk menonaktifkannya. Pengaturan mengikuti status Login Items macOS;
bila perlu persetujuan, panel menyediakan tombol ke Pengaturan Sistem.

Menggunakan `SMAppService.mainApp` (macOS 13+), tanpa helper atau LaunchAgent
tambahan. Aplikasi tidak mengaktifkan ulang opsi yang sudah dimatikan pengguna.

Untuk instalasi/pemeriksaan dari terminal:

```sh
ditto "dist/Suhu Mac.app" "/Applications/Suhu Mac.app"
"/Applications/Suhu Mac.app/Contents/MacOS/SuhuMacbook" --enable-login
"/Applications/Suhu Mac.app/Contents/MacOS/SuhuMacbook" --login-status
```

`--disable-login` menonaktifkan startup. Kode keluar 2 berarti perlu izin di
System Settings → General → Login Items. Login ulang belum diperlukan untuk
membaca status registrasi, tetapi hanya login ulang yang membuktikan peluncuran
otomatis sesungguhnya.

Ikon aplikasi termometer tersedia di `Resources/AppIcon.png` dan `AppIcon.icns`.
Build merender ulang ikon dari `scripts/make-icon.swift`, termasuk ukuran kecil.

## Arti angka

- **Suhu CPU**: sensor CPU terpanas yang berhasil dibaca melalui AppleSMC.
  Ini suhu internal CPU, bukan suhu permukaan casing atau suhu ruangan.
  Peta sensor tersedia untuk M1/M2 dan Intel; perangkat lain menampilkan
  `—°C` bila sensor belum didukung. Dukungan nyata perlu diuji per perangkat.
- **CPU**: persentase waktu aktif seluruh core antara dua sampel Mach,
  dinormalisasi ke 0–100%. Sampel pertama belum memiliki interval.
- **RAM**: memori aktif + tidak aktif + spekulatif + wired + compressed,
  dikurangi purgeable dan cache file. Tersedia = total fisik − terpakai;
  angka dapat sedikit berbeda dari Activity Monitor karena waktu sampling.
  Status tekanan RAM dibaca dari macOS, bukan disimpulkan dari persentase RAM.
- **Storage**: kapasitas file system tempat folder home berada. Pada APFS,
  ruang dapat dipakai bersama volume lain dan snapshot. Ini bukan pemeriksaan
  kesehatan SSD/SMART. Ruang purgeable dapat membuat angka Finder berbeda.
- **Normal/Hangat/Panas/Kritis**: status termal dari macOS, bukan batas suhu
  buatan aplikasi. Sensor gagal tidak diubah menjadi nol atau angka perkiraan.

Sampling setiap 2 detik pada antrean background dengan prioritas utility.
Tidak mengirim data, menyimpan riwayat, mengubah kipas, atau meminta sudo.
Startup saat login hanya diubah melalui pengaturan atau perintah eksplisit.

## Verifikasi

```sh
swift test
swift run SuhuMacbook --diagnose
```

Diagnostik mencetak satu snapshot JSON dari reader yang sama dengan aplikasi,
termasuk key sensor untuk memeriksa sumber suhu. Tidak membuka UI.

Build lokal memakai ad-hoc signing; belum Developer ID/notarized untuk distribusi.
AppleSMC merupakan antarmuka privat dan bisa berubah setelah pembaruan macOS.

## Referensi protokol

Implementasi reader lokal hanya mengirim perintah baca. Layout ABI dan pemetaan
sensor diverifikasi melalui sumber upstream:

- [Stats: SMC ABI](https://github.com/exelban/stats/blob/master/SMC/smc.swift)
- [Stats: identitas sensor M1/M2](https://github.com/exelban/stats/blob/master/Modules/Sensors/values.swift)
- [go-smc: protokol baca dan tipe data](https://github.com/caseymrm/go-smc)

Tidak ada kode kendali kipas atau dependensi runtime dari proyek tersebut.
