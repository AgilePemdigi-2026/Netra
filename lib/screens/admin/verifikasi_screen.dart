import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import 'daftar_temuan_screen.dart'; // TemuanItem
import 'url_foto_privat.dart';

// =============================================================================
// KONFIGURASI
// =============================================================================
class _Db {
  /// Nilai kolom `status` yang disimpan ke tabel `verifikasi` dan `temuan`.
  static const String statusDiterima = 'terverifikasi';
  static const String statusDitolak = 'ditolak';

  /// Isi kolom `catatan` pada tabel `verifikasi`.
  static const String catatanDiterima =
      'Temuan dinilai layak untuk tindak lanjut';
  static const String catatanDitolak =
      'Temuan dinilai tidak memerlukan tindak lanjut';
}

enum _Keputusan { diterima, ditolak }

class _GalatVerifikasi implements Exception {
  final String pesan;
  const _GalatVerifikasi(this.pesan);
}

// =============================================================================
// BANTUAN
// =============================================================================
const Color _biruTua = Color(0xFF0B3FA8);
const Color _biruLogo = Color(0xFF0A3277);
const Color _hijauTua = Color(0xFF0B5D1E);
const Color _merah = Color(0xFFB91C1C);
const Color _latarHalaman = Color(0xFFF5F6FA);

String _tanggalWib(DateTime? waktu) {
  if (waktu == null) return '-';

  const bulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  final t = waktu.toUtc().add(const Duration(hours: 7));
  String dua(int n) => n.toString().padLeft(2, '0');

  return '${t.day} ${bulan[t.month - 1]} ${t.year}, '
      '${dua(t.hour)}:${dua(t.minute)} WIB';
}

/// "Sekitar Stasiun Gubeng, Jl. Stasiun Gubeng, Surabaya"
/// -> utama: "Sekitar Stasiun Gubeng", sisa: "Jl. Stasiun Gubeng, Surabaya"
({String utama, String sisa}) _pisahLokasi(String lokasi) {
  final bagian = lokasi
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  if (bagian.isEmpty) {
    final teks = lokasi.trim();
    return (utama: teks.isEmpty ? '-' : teks, sisa: '');
  }

  return (utama: bagian.first, sisa: bagian.skip(1).join(', '));
}

// =============================================================================
// HALAMAN VERIFIKASI TEMUAN
// =============================================================================
class VerifikasiScreen extends StatefulWidget {
  final TemuanItem temuan;

  const VerifikasiScreen({super.key, required this.temuan});

  @override
  State<VerifikasiScreen> createState() => _VerifikasiScreenState();
}

class _VerifikasiScreenState extends State<VerifikasiScreen> {
  /// Keputusan yang sedang diproses (null = tidak ada proses berjalan).
  _Keputusan? _memproses;
  String? _galat;

  /// URL sementara foto (bucket privat), dibuat sekali per halaman.
  late final Future<String?> _foto = UrlFotoPrivat.ambil(
    widget.temuan.dokumentasi,
  );

  // ---------------------------------------------------------------------------
  // PROSES
  // ---------------------------------------------------------------------------

  Future<void> _proses(_Keputusan keputusan) async {
    if (_memproses != null) return;

    setState(() {
      _memproses = keputusan;
      _galat = null;
    });

    try {
      final hasil = await _simpanKeputusan(
        keputusan,
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      // Ganti halaman ini dengan halaman hasil (tidak bisa kembali ke sini).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HasilVerifikasiScreen(
            temuan: widget.temuan,
            diterima: keputusan == _Keputusan.diterima,
            namaPetugas: hasil.namaPetugas,
            waktu: hasil.waktu,
            catatan: hasil.catatan,
          ),
        ),
      );
    } on _GalatVerifikasi catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = e.pesan;
        _memproses = null;
      });
    } on PostgrestException catch (e) {
      debugPrint('Verifikasi: ${e.code} ${e.message}');
      if (!mounted) return;
      setState(() {
        _galat = e.code == '42501'
            ? 'Akun ini belum memiliki izin untuk memverifikasi temuan. '
                  'Hubungi administrator sistem.'
            : 'Gagal menyimpan verifikasi: ${e.message}';
        _memproses = null;
      });
    } catch (e) {
      debugPrint('Verifikasi: $e');
      if (!mounted) return;
      setState(() {
        _galat =
            'Tidak dapat terhubung. Periksa koneksi internet lalu coba lagi.';
        _memproses = null;
      });
    }
  }

  Future<({String namaPetugas, DateTime waktu, String catatan})>
  _simpanKeputusan(_Keputusan keputusan) async {
    final client = SupabaseService.client;
    final user = client.auth.currentUser;

    if (user == null) {
      throw const _GalatVerifikasi(
        'Sesi login berakhir. Silakan masuk kembali.',
      );
    }

    // 1. Identitas petugas yang sedang login.
    final admin = await client
        .from('admin_dinsos')
        .select('id_admin,nama')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (admin == null) {
      throw const _GalatVerifikasi(
        'Akun ini tidak terdaftar sebagai petugas Dinas PU Bina Marga.',
      );
    }

    // 2. Pastikan temuan belum diproses petugas lain.
    final sudahAda = await client
        .from('verifikasi')
        .select('id_verifikasi')
        .eq('id_temuan', widget.temuan.id)
        .limit(1);

    if (sudahAda.isNotEmpty) {
      throw const _GalatVerifikasi(
        'Temuan ini sudah diproses oleh petugas lain. '
        'Kembali ke Daftar Temuan lalu muat ulang.',
      );
    }

    final diterima = keputusan == _Keputusan.diterima;
    final status = diterima ? _Db.statusDiterima : _Db.statusDitolak;
    final catatan = diterima ? _Db.catatanDiterima : _Db.catatanDitolak;
    final waktu = DateTime.now().toUtc();

    // 3. Catat keputusan di tabel verifikasi.
    final baris = await client
        .from('verifikasi')
        .insert({
          'id_temuan': widget.temuan.id,
          'id_admin': admin['id_admin'],
          'status': status,
          'catatan': catatan,
          'waktu_verifikasi': waktu.toIso8601String(),
        })
        .select()
        .single();

    // 4. Samakan status pada tabel temuan (tidak fatal bila gagal,
    //    karena dashboard memakai hasil verifikasi terbaru).
    try {
      await client
          .from('temuan')
          .update({'status': status})
          .eq('id_temuan', widget.temuan.id);
    } catch (e) {
      debugPrint('Verifikasi: gagal memperbarui status temuan: $e');
    }

    final nama = '${admin['nama'] ?? ''}'.trim();

    return (
      namaPetugas: nama.isEmpty ? 'Petugas Dinas PU Bina Marga' : nama,
      waktu: DateTime.tryParse('${baris['waktu_verifikasi'] ?? ''}') ?? waktu,
      catatan: catatan,
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sibuk = _memproses != null;

    return PopScope(
      canPop: !sibuk,
      child: Scaffold(
        backgroundColor: _latarHalaman,
        body: SafeArea(
          child: Column(
            children: [
              _HeaderHalaman(
                onKembali: sibuk
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _judulHalaman(),
                      const SizedBox(height: 14),
                      _kartuFoto(),
                      const SizedBox(height: 10),
                      _kartuLokasi(),
                      const SizedBox(height: 14),
                      if (_galat != null) ...[
                        _bannerGalat(),
                        const SizedBox(height: 14),
                      ],
                      _KartuOpsi(
                        warnaBar: _hijauTua,
                        ikon: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 26,
                            color: Color(0xFF0B3B1E),
                          ),
                        ),
                        label: 'OPSI VERIFIKASI',
                        warnaLabel: _hijauTua,
                        judul: 'Validasi Temuan Lapangan',
                        deskripsi:
                            'Apakah Anda yakin temuan ini valid?\n'
                            'Temuan ini akan ditindaklanjuti.',
                        teksTombol: 'Konfirmasi Verifikasi',
                        ikonTombol: Icons.check_circle_outline_rounded,
                        warnaTombol: _hijauTua,
                        sedangProses: _memproses == _Keputusan.diterima,
                        nonaktif: sibuk,
                        onTekan: () => _proses(_Keputusan.diterima),
                      ),
                      const SizedBox(height: 14),
                      _KartuOpsi(
                        warnaBar: _merah,
                        ikon: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cancel_outlined,
                            size: 26,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        label: 'OPSI PEMBATALAN',
                        warnaLabel: _merah,
                        judul: 'Tolak Temuan',
                        deskripsi:
                            'Apakah Anda yakin temuan ini tidak memerlukan '
                            'tindakan lebih lanjut?',
                        teksTombol: 'Konfirmasi Penolakan',
                        ikonTombol: Icons.block_rounded,
                        warnaTombol: _merah,
                        sedangProses: _memproses == _Keputusan.ditolak,
                        nonaktif: sibuk,
                        onTekan: () => _proses(_Keputusan.ditolak),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _judulHalaman() {
    return Row(
      children: [
        const Icon(Icons.location_on, size: 24, color: _biruTua),
        const SizedBox(width: 8),
        Text(
          'Verifikasi Temuan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF101828),
          ),
        ),
      ],
    );
  }

  Widget _kartuFoto() {
    Widget penggantiFoto() => Container(
      color: const Color(0xFF475467),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 40,
        color: Colors.white54,
      ),
    );

    Widget memuatFoto() => Container(
      color: const Color(0xFF475467),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 1.85,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<String?>(
              future: _foto,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return memuatFoto();
                }
                final url = snapshot.data;
                if (url == null || url.isEmpty) return penggantiFoto();

                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progres) {
                    if (progres == null) return child;
                    return memuatFoto();
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Verifikasi: foto gagal ditampilkan: $error');
                    return penggantiFoto();
                  },
                );
              },
            ),
            // Gradasi gelap agar teks di atas foto terbaca.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x00000000),
                    Color(0xCC000000),
                  ],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.tag_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Temuan #${widget.temuan.id}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kategori Hambatan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.temuan.jenis,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuLokasi() {
    final lokasi = _pisahLokasi(widget.temuan.lokasi);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFE4EAFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Titik Lokasi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  lokasi.utama,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF101828),
                  ),
                ),
                if (lokasi.sisa.isNotEmpty)
                  Text(
                    lokasi.sisa,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: const Color(0xFF667085),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerGalat() {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 18, color: _merah),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _galat ?? '',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  height: 1.4,
                  color: _merah,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// KARTU OPSI (VERIFIKASI / PENOLAKAN)
// =============================================================================
class _KartuOpsi extends StatelessWidget {
  final Color warnaBar;
  final Widget ikon;
  final String label;
  final Color warnaLabel;
  final String judul;
  final String deskripsi;
  final String teksTombol;
  final IconData ikonTombol;
  final Color warnaTombol;
  final bool sedangProses;
  final bool nonaktif;
  final VoidCallback onTekan;

  const _KartuOpsi({
    required this.warnaBar,
    required this.ikon,
    required this.label,
    required this.warnaLabel,
    required this.judul,
    required this.deskripsi,
    required this.teksTombol,
    required this.ikonTombol,
    required this.warnaTombol,
    required this.sedangProses,
    required this.nonaktif,
    required this.onTekan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 6, color: warnaBar),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ikon,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w800,
                                color: warnaLabel,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              judul,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF101828),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    deskripsi,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      height: 1.55,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: nonaktif ? null : onTekan,
                      icon: sedangProses
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(ikonTombol, size: 19),
                      label: Text(
                        sedangProses ? 'Menyimpan...' : teksTombol,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: warnaTombol,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: sedangProses
                            ? warnaTombol
                            : warnaTombol.withValues(alpha: 0.45),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HALAMAN HASIL VERIFIKASI
// =============================================================================
class HasilVerifikasiScreen extends StatelessWidget {
  final TemuanItem temuan;
  final bool diterima;
  final String namaPetugas;
  final DateTime waktu;
  final String catatan;

  const HasilVerifikasiScreen({
    super.key,
    required this.temuan,
    required this.diterima,
    required this.namaPetugas,
    required this.waktu,
    required this.catatan,
  });

  /// Kembali ke Daftar Temuan: tutup halaman hasil dan halaman detail temuan.
  void _kembaliKeDaftar(BuildContext context) {
    var sisa = 2;
    Navigator.of(context).popUntil((_) => sisa-- <= 0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _kembaliKeDaftar(context);
      },
      child: Scaffold(
        backgroundColor: _latarHalaman,
        body: SafeArea(
          child: Column(
            children: [
              _HeaderHalaman(onKembali: () => _kembaliKeDaftar(context)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _IkonHasil(diterima: diterima)),
                      const SizedBox(height: 14),
                      Text(
                        diterima
                            ? 'Temuan Berhasil Diverifikasi'
                            : 'Temuan Berhasil Ditolak',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 21,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _kartuData(),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => _kembaliKeDaftar(context),
                          icon: const Icon(Icons.list_alt_rounded, size: 20),
                          label: Text(
                            'Kembali ke Daftar Temuan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _biruTua,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
      ),
    );
  }

  Widget _kartuData() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 20, color: _biruTua),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Data Verifikasi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF101828),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EAFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ID: #${temuan.id}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _media(),
          const SizedBox(height: 10),
          _BarisInfo(
            ikon: Icons.warning_amber_rounded,
            label: 'Permasalahan',
            nilai: temuan.jenis,
          ),
          const SizedBox(height: 8),
          _BarisInfo(
            ikon: Icons.location_on_outlined,
            label: 'Lokasi',
            nilai: temuan.lokasi,
          ),
          const SizedBox(height: 8),
          _BarisInfo(
            ikon: Icons.badge_outlined,
            label: 'Petugas Verifikator',
            nilai: namaPetugas,
          ),
          const SizedBox(height: 8),
          _BarisInfo(
            ikon: Icons.schedule_rounded,
            label: 'Waktu Verifikasi',
            nilai: _tanggalWib(waktu),
          ),
          const SizedBox(height: 8),
          _BarisInfo(
            ikon: Icons.chat_outlined,
            label: 'Catatan Verifikasi',
            nilai: catatan,
          ),
        ],
      ),
    );
  }

  Widget _media() {
    final urlFoto = UrlFotoPrivat.ambil(temuan.dokumentasi);
    final punyaPeta = temuan.latitude != null && temuan.longitude != null;

    Widget kosong() => Container(
      color: const Color(0xFFECEEF2),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 26,
        color: Color(0xFF98A2B3),
      ),
    );

    Widget foto() => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<String?>(
            future: urlFoto,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Container(
                  color: const Color(0xFFECEEF2),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final url = snapshot.data;
              if (url == null || url.isEmpty) return kosong();

              return Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => kosong(),
              );
            },
          ),
          Positioned(
            left: 6,
            bottom: 6,
            right: 6,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: _lencanaLabel(
                ikon: Icons.photo_camera_outlined,
                teks: 'Foto Laporan',
              ),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: 104,
      child: Row(
        children: [
          Expanded(child: foto()),
          if (punyaPeta) ...[
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PetaMini(
                  latitude: temuan.latitude!,
                  longitude: temuan.longitude!,
                  label: 'Peta Lokasi',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// KOMPONEN BERSAMA
// =============================================================================
class _HeaderHalaman extends StatelessWidget {
  final VoidCallback? onKembali;

  const _HeaderHalaman({required this.onKembali});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Row(
        children: [
          Image.asset(
            'assets/images/dinsos.png',
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.account_balance, size: 20, color: _biruLogo),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Dinas PU Bina Marga',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _biruLogo,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Kembali',
            onPressed: onKembali,
            icon: const Icon(Icons.arrow_back_rounded, size: 26),
            color: _biruLogo,
            disabledColor: const Color(0xFF98A2B3),
          ),
        ],
      ),
    );
  }
}

/// Lingkaran besar penanda hasil (hijau = diterima, merah = ditolak).
class _IkonHasil extends StatelessWidget {
  final bool diterima;

  const _IkonHasil({required this.diterima});

  @override
  Widget build(BuildContext context) {
    final halo = diterima ? const Color(0xFF86EFAC) : const Color(0xFFFECACA);
    final inti = diterima ? _hijauTua : _merah;

    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: halo.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(color: inti, shape: BoxShape.circle),
                child: Icon(
                  diterima ? Icons.check_rounded : Icons.close_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 4,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: inti, width: 1.5),
              ),
              child: Icon(
                diterima ? Icons.verified_rounded : Icons.block_rounded,
                size: 14,
                color: inti,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisInfo extends StatelessWidget {
  final IconData ikon;
  final String label;
  final String nilai;

  const _BarisInfo({
    required this.ikon,
    required this.label,
    required this.nilai,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 14, color: const Color(0xFF475467)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475467),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            nilai,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF101828),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _lencanaLabel({
  required IconData ikon,
  required String teks,
  Color warnaIkon = Colors.white,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 13, color: warnaIkon),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            teks,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

// =============================================================================
// PETA MINI (ubin OpenStreetMap, tanpa paket tambahan)
// Dibuat publik agar bisa dipakai ulang di daftar_temuan_screen.dart.
// =============================================================================
class PetaMini extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String label;

  const PetaMini({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  static const int _zoom = 16;
  static const String _userAgent = 'NETRA/1.0 (Dinas PU Bina Marga)';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, kendala) {
        final lebar = kendala.maxWidth;
        final tinggi = kendala.maxHeight;

        // Koordinat -> posisi ubin (proyeksi Web Mercator).
        final n = 1 << _zoom;
        final xf = (longitude + 180) / 360 * n;
        final rad = latitude * math.pi / 180;
        final yf =
            (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * n;

        final tx = xf.floor();
        final ty = yf.floor();
        final px = (xf - tx) * 256;
        final py = (yf - ty) * 256;

        // Blok 2x2 ubin agar titik selalu bisa berada di tengah kotak.
        final x0 = px < 128 ? tx - 1 : tx;
        final y0 = py < 128 ? ty - 1 : ty;

        final titikX = (tx - x0) * 256 + px;
        final titikY = (ty - y0) * 256 + py;

        final geserX = lebar / 2 - titikX;
        final geserY = tinggi / 2 - titikY;

        return Stack(
          children: [
            Container(color: const Color(0xFFE5E3DF)),
            Positioned(
              left: geserX,
              top: geserY,
              width: 512,
              height: 512,
              child: Stack(
                children: [
                  for (var i = 0; i < 2; i++)
                    for (var j = 0; j < 2; j++)
                      Positioned(
                        left: i * 256.0,
                        top: j * 256.0,
                        width: 256,
                        height: 256,
                        child: Image.network(
                          'https://tile.openstreetmap.org/$_zoom/${x0 + i}/${y0 + j}.png',
                          headers: const {'User-Agent': _userAgent},
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                ],
              ),
            ),
            Center(
              child: Transform.translate(
                offset: const Offset(0, -11),
                child: const Icon(
                  Icons.location_on,
                  size: 26,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
            // Atribusi wajib OpenStreetMap.
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '© OpenStreetMap',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 7.5,
                    color: const Color(0xFF344054),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 6,
              right: 6,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: _lencanaLabel(
                  ikon: Icons.location_on_outlined,
                  teks: label,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
