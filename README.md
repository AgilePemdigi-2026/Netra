# NETRA

### Sistem Pelayanan Aksesibilitas Publik Berbasis AI untuk Disabilitas Netra di Surabaya

**NETRA** adalah sistem berbasis Artificial Intelligence (AI) yang dirancang untuk mendukung mobilitas dan aksesibilitas penyandang tunanetra melalui deteksi objek secara real-time, peringatan suara dan getaran, serta pencatatan temuan aksesibilitas lingkungan.

**Pembangunan Perangkat Lunak (Praktikum) - Kelompok 06 Kelas I3**

---

## Tentang NETRA

NETRA hadir sebagai solusi teknologi yang bertujuan membantu penyandang tunanetra memperoleh informasi mengenai kondisi lingkungan di sekitar mereka.

Dengan memanfaatkan kamera perangkat dan teknologi *Computer Vision*, NETRA dirancang untuk mengenali objek serta potensi hambatan selama perjalanan. Informasi deteksi kemudian disampaikan melalui suara dan getaran sebagai bentuk umpan balik yang lebih aksesibel.

Selain aplikasi bagi pengguna, NETRA juga mencakup sistem administrator untuk mendukung pengelolaan dan verifikasi temuan aksesibilitas.

### Tujuan Pengembangan

- Membantu pengguna tunanetra mengenali objek dan hambatan di sekitarnya.
- Memberikan informasi lingkungan melalui peringatan suara dan getaran.
- Mendukung identifikasi potensi kerusakan jalan atau trotoar.
- Mencatat informasi temuan aksesibilitas selama perjalanan.
- Mendukung pengelolaan dan verifikasi temuan melalui sistem administrator.

---

## Navigasi

- [Tentang NETRA](#tentang-netra)
- [Fitur Sistem](#fitur-sistem)
- [Alur Kerja](#alur-kerja)
- [Teknologi](#teknologi)
- [Metode Pengembangan](#metode-pengembangan)
- [Pengujian](#pengujian)
- [Tim Pengembang](#tim-pengembang)
- [Dokumentasi](#dokumentasi)


---

## Fitur Sistem

NETRA memiliki 12 fitur utama yang terbagi menjadi dua bagian.

### Aplikasi Pengguna

| Fitur | Deskripsi |
|---|---|
| Beranda | Halaman utama untuk mengakses fitur aplikasi. |
| Kamera Deteksi | Mendeteksi objek serta potensi hambatan menggunakan AI. |
| Peringatan Suara & Getaran | Memberikan informasi hasil deteksi kepada pengguna. |
| Selesai Perjalanan | Mengakhiri sesi perjalanan pengguna. |
| Ringkasan Temuan Aksesibilitas | Menampilkan informasi temuan selama perjalanan. |
| Pengaturan | Mengelola preferensi penggunaan aplikasi. |

### Sistem Administrator

| Fitur | Deskripsi |
|---|---|
| Login | Autentikasi administrator. |
| Dashboard | Ringkasan informasi temuan aksesibilitas. |
| Daftar Temuan | Pengelolaan daftar temuan yang tercatat. |
| Detail Temuan | Menampilkan informasi lengkap suatu temuan. |
| Verifikasi Temuan | Memeriksa dan memperbarui status verifikasi temuan. |
| Logout | Mengakhiri sesi administrator. |

---

## Alur Kerja

### Alur Pengguna

1. Pengguna membuka aplikasi melalui halaman Beranda.
2. Pengguna memulai perjalanan dan mengaktifkan kamera deteksi.
3. Sistem memproses gambar menggunakan teknologi deteksi objek.
4. Sistem memberikan umpan balik suara atau getaran berdasarkan hasil deteksi.
5. Pengguna mengakhiri sesi melalui fitur Selesai Perjalanan.
6. Sistem menyediakan Ringkasan Temuan Aksesibilitas sesuai data yang tercatat.

### Alur Administrator (Dinas Sosial)

1. Administrator melakukan Login.
2. Sistem menampilkan Dashboard Admin.
3. Administrator mengakses Daftar Temuan.
4. Administrator membuka Detail Temuan untuk melakukan pemeriksaan.
5. Administrator melakukan Verifikasi Temuan.
6. Status temuan diperbarui sesuai hasil verifikasi.
7. Administrator dapat mengakhiri sesi melalui Logout.

*Alur di atas merupakan rancangan fungsional yang menjadi acuan pengembangan sistem.*

---

## Teknologi

| Teknologi | Fungsi |
|---|---|
| Flutter | Pengembangan aplikasi mobile |
| Dart | Bahasa pemrograman Flutter |
| Python | Pengembangan dan evaluasi model AI |
| YOLO | Deteksi objek berbasis Computer Vision |
| Supabase | Layanan backend dan pengelolaan data |
| GitHub | Version control dan kolaborasi pengembangan |

---

## Metode Pengembangan

Pengembangan NETRA menerapkan pendekatan **Agile Scrum** melalui tiga sprint.

| Sprint | Periode | Fokus Pengembangan | Story Points |
|---|---|---|---:|
| Sprint 1 | Minggu 9–10 | Beranda, Kamera Deteksi, Peringatan Suara & Getaran, Selesai Perjalanan | 11 |
| Sprint 2 | Minggu 11–12 | Ringkasan Temuan Aksesibilitas, Pengaturan, Login, Dashboard | 10 |
| Sprint 3 | Minggu 13–14 | Daftar Temuan, Detail Temuan, Verifikasi Temuan, Logout | 9 |
| **Total** | | **12 fitur** | **30** |

Pelaksanaan sprint mencakup perencanaan, implementasi, integrasi, pengujian, dan evaluasi secara berkala.

---

## Pengujian

NETRA menerapkan pendekatan pengujian untuk memastikan kesesuaian fungsi sistem terhadap kebutuhan yang telah ditentukan.

- **Behavior-Driven Development (BDD):** Pengujian berbasis skenario Given–When–Then.
- **Functional Testing:** Memastikan setiap fitur berfungsi sesuai kebutuhan.
- **Integration Testing:** Memeriksa komunikasi dan integrasi antarkomponen.
- **AI Model Evaluation:** Mengevaluasi kemampuan model deteksi menggunakan metrik seperti Precision, Recall, dan mAP.

Pengujian dilakukan secara bertahap mengikuti perkembangan implementasi sistem.

---

## Tim Pengembang

**Pembangunan Perangkat Lunak (Praktikum) - Kelompok 06 Kelas I3**

NETRA dikembangkan oleh tim beranggotakan empat mahasiswa dengan pembagian tanggung jawab sebagai berikut.

| No. | Nama | NIM | Peran |
|---|---|---|---|
| 1 | Rehat Reisa Tanzil | 187241030 | Project Manager |
| 2 | Mohammad Nafi Ainur Riskiyanto | 187241084 | Developer |
| 3 | Arsiandita Vienna Pramita | 187241095 | Developer |
| 4 | Prithvy Adelya Zolla Vega | 187241099 | Developer |

Seluruh anggota berkolaborasi dalam perencanaan, implementasi, pengujian, dan dokumentasi proyek sesuai pembagian pekerjaan masing-masing sprint.

---

## Dokumentasi

- [GitHub Repository](https://github.com/AgilePemdigi-2026/Netra)
- [GitHub Issues](https://github.com/AgilePemdigi-2026/Netra/issues)
- [AI Training History](ai/TRAINING_HISTORY.md)


---

### NETRA
*Teknologi untuk Mendukung Mobilitas dan Aksesibilitas yang Lebih Inklusif.*
