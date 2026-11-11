import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

// =============================================================================
// KONFIGURASI DATABASE (sesuai ERD Supabase NETRA)
// =============================================================================
class _Db {
  // Tabel perjalanan: satu baris = satu sesi perjalanan pengguna.
  static const String tabelPerjalanan = 'perjalanan';
  static const String idPerjalanan = 'id_perjalanan';
  static const String waktuPerjalanan = 'waktu_mulai';
  static const String waktuSelesaiPerjalanan = 'waktu_selesai';
  static const String statusPerjalanan = 'status';

  // Tabel deteksi: satu baris = satu halangan yang ditemukan kamera AI.
  static const String tabelDeteksi = 'deteksi';
  static const String waktuDeteksi = 'waktu_deteksi';

  // Tabel temuan: satu baris = satu temuan yang dilaporkan ke Dinas Sosial.
  static const String tabelTemuan = 'temuan';
  static const String idTemuan = 'id_temuan';
  static const String waktuTemuan = 'waktu_temuan';
  static const String statusTemuan = 'status';

  // Tabel verifikasi: hasil verifikasi petugas untuk tiap temuan.
  static const String tabelVerifikasi = 'verifikasi';
  static const String idVerifikasi = 'id_verifikasi';
  static const String statusVerifikasi = 'status';
  static const String waktuVerifikasi = 'waktu_verifikasi';
}

// =============================================================================
// FILTER PERIODE
// =============================================================================
enum _Periode {
  hariIni('Hari Ini'),
  satuMinggu('Satu Minggu'),
  satuBulan('Satu Bulan'),
  semua('Semua Waktu');

  const _Periode(this.label);
  final String label;

  /// Batas awal waktu; null = tanpa batas.
  DateTime? get sejak {
    final n = DateTime.now();
    switch (this) {
      case _Periode.hariIni:
        return DateTime(n.year, n.month, n.day);
      case _Periode.satuMinggu:
        return n.subtract(const Duration(days: 7));
      case _Periode.satuBulan:
        return DateTime(n.year, n.month - 1, n.day);
      case _Periode.semua:
        return null;
    }
  }
}

enum _KategoriTemuan { menunggu, terverifikasi, ditolak }

class DashboardScreen extends StatefulWidget {
  /// Nama petugas dari proses login (opsional).
  final String? namaAdmin;

  const DashboardScreen({super.key, this.namaAdmin});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _kunciNamaAdmin = 'admin_nama';

  static const Color _biru = Color(0xFF1D4ED8);
  static const Color _latar = Color(0xFFF7F8FA);

  int _tab = 0;
  _Periode _periode = _Periode.satuBulan;

  bool _memuat = true;

  /// nama data -> pesan error singkat (untuk banner).
  final Map<String, String> _gagalMuat = {};

  // Metrik (null = belum tersedia / gagal dimuat)
  int? _totalPerjalanan;
  int? _perjalananSelesai;
  int? _deteksiAi;
  int? _totalTemuan;
  int? _menunggu;
  int? _terverifikasi;
  int? _ditolak;

  String? _namaAdmin;

  @override
  void initState() {
    super.initState();
    _namaAdmin = widget.namaAdmin;
    _muatCacheNama();
    _muat();
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  Future<void> _muatCacheNama() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nama = prefs.getString(_kunciNamaAdmin);
      if (!mounted) return;
      if (nama != null && _namaAdmin == null) {
        setState(() => _namaAdmin = nama);
      }
    } catch (e) {
      debugPrint('Gagal membaca cache nama admin: $e');
    }
  }

  /// Menjalankan satu pengambilan data; bila gagal mengembalikan null
  /// dan mencatat pesan error, sehingga data lain tetap tampil.
  Future<T?> _aman<T>(String nama, Future<T> Function() aksi) async {
    try {
      return await aksi().timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Dashboard: gagal memuat "$nama": $e');
      final pesan = e is PostgrestException ? e.message : e.toString();
      _gagalMuat[nama] = pesan.length > 90
          ? '${pesan.substring(0, 90)}…'
          : pesan;
      return null;
    }
  }

  /// Mengambil baris-baris tabel (dipaginasi per 1000 baris).
  Future<List<Map<String, dynamic>>> _ambilBaris({
    required String tabel,
    required String kolom,
    required String kolomUrut,
    String? kolomWaktu,
    DateTime? sejak,
  }) async {
    const ukuran = 1000;
    final hasil = <Map<String, dynamic>>[];

    for (var halaman = 0; halaman < 50; halaman++) {
      var query = SupabaseService.client.from(tabel).select(kolom);

      if (sejak != null && kolomWaktu != null) {
        query = query.gte(kolomWaktu, sejak.toUtc().toIso8601String());
      }

      final data = await query
          .order(kolomUrut)
          .range(halaman * ukuran, (halaman + 1) * ukuran - 1);

      hasil.addAll(data);

      if (data.length < ukuran) break;
    }

    return hasil;
  }

  /// Menghitung jumlah baris di server (tanpa mengunduh semua data).
  Future<int> _hitungBaris(
    String tabel,
    String kolomWaktu,
    DateTime? sejak,
  ) async {
    var query = SupabaseService.client.from(tabel).select('*');

    if (sejak != null) {
      query = query.gte(kolomWaktu, sejak.toUtc().toIso8601String());
    }

    final respon = await query.limit(1).count(CountOption.exact);
    return respon.count;
  }

  Future<String?> _ambilNamaAdmin(String userId) async {
    final data = await SupabaseService.client
        .from('admin_dinsos')
        .select('nama')
        .eq('auth_user_id', userId)
        .maybeSingle();

    return data?['nama'] as String?;
  }

  String _normal(String? teks) =>
      (teks ?? '').toLowerCase().replaceAll('_', ' ').trim();

  /// Perjalanan dianggap selesai bila pengguna sudah menekan "akhiri"
  /// (waktu_selesai terisi) atau statusnya berarti selesai.
  bool _perjalananTuntas(Map<String, dynamic> baris) {
    if (baris[_Db.waktuSelesaiPerjalanan] != null) return true;

    final n = _normal('${baris[_Db.statusPerjalanan] ?? ''}');
    return n.contains('selesai') ||
        n.contains('complete') ||
        n.contains('finish') ||
        n.contains('tiba');
  }

  _KategoriTemuan _klasifikasi(String? status) {
    final n = _normal(status);

    if (n.contains('tolak') || n.contains('reject')) {
      return _KategoriTemuan.ditolak;
    }
    // "belum diverifikasi" mengandung kata "verifikasi", jadi dicek lebih dulu.
    if (n.contains('belum') ||
        n.contains('menunggu') ||
        n.contains('pending') ||
        n.contains('baru')) {
      return _KategoriTemuan.menunggu;
    }
    if (n.contains('verifikasi') ||
        n.contains('verified') ||
        n.contains('valid') ||
        n.contains('setuju') ||
        n.contains('terima') ||
        n.contains('approve') ||
        n.contains('accept')) {
      return _KategoriTemuan.terverifikasi;
    }
    return _KategoriTemuan.menunggu;
  }

  Future<void> _muat() async {
    if (!mounted) return;

    setState(() {
      _memuat = true;
      _gagalMuat.clear();
    });

    final sejak = _periode.sejak;
    final user = SupabaseService.client.auth.currentUser;

    final hasil = await Future.wait<Object?>([
      // 0: perjalanan
      _aman<List<Map<String, dynamic>>>(
        'perjalanan',
        () => _ambilBaris(
          tabel: _Db.tabelPerjalanan,
          kolom:
              '${_Db.idPerjalanan},${_Db.waktuSelesaiPerjalanan},${_Db.statusPerjalanan}',
          kolomUrut: _Db.idPerjalanan,
          kolomWaktu: _Db.waktuPerjalanan,
          sejak: sejak,
        ),
      ),
      // 1: deteksi (jumlah halangan yang ditemukan)
      _aman<int>(
        'deteksi',
        () => _hitungBaris(_Db.tabelDeteksi, _Db.waktuDeteksi, sejak),
      ),
      // 2: temuan
      _aman<List<Map<String, dynamic>>>(
        'temuan',
        () => _ambilBaris(
          tabel: _Db.tabelTemuan,
          kolom: '${_Db.idTemuan},${_Db.statusTemuan}',
          kolomUrut: _Db.idTemuan,
          kolomWaktu: _Db.waktuTemuan,
          sejak: sejak,
        ),
      ),
      // 3: verifikasi (hasil verifikasi petugas)
      _aman<List<Map<String, dynamic>>>(
        'verifikasi',
        () => _ambilBaris(
          tabel: _Db.tabelVerifikasi,
          kolom:
              '${_Db.idTemuan},${_Db.statusVerifikasi},${_Db.waktuVerifikasi}',
          kolomUrut: _Db.idVerifikasi,
        ),
      ),
      // 4: nama petugas
      if (user != null)
        _aman<String?>('nama petugas', () => _ambilNamaAdmin(user.id))
      else
        Future<Object?>.value(null),
    ]);

    final barisPerjalanan = hasil[0] as List<Map<String, dynamic>>?;
    final deteksi = hasil[1] as int?;
    final barisTemuan = hasil[2] as List<Map<String, dynamic>>?;
    final barisVerifikasi = hasil[3] as List<Map<String, dynamic>>?;
    final nama = hasil[4] as String?;

    if (nama != null) {
      SharedPreferences.getInstance()
          .then((p) => p.setString(_kunciNamaAdmin, nama))
          .catchError((Object e) {
            debugPrint('Gagal menyimpan cache nama admin: $e');
            return false;
          });
    }

    // Verifikasi terbaru untuk tiap temuan.
    final statusVerifikasiTerbaru = <String, String?>{};
    if (barisVerifikasi != null) {
      final waktuTerbaru = <String, DateTime>{};
      for (final v in barisVerifikasi) {
        final kunci = '${v[_Db.idTemuan]}';
        final waktu =
            DateTime.tryParse('${v[_Db.waktuVerifikasi] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final sebelumnya = waktuTerbaru[kunci];
        if (sebelumnya == null || waktu.isAfter(sebelumnya)) {
          waktuTerbaru[kunci] = waktu;
          statusVerifikasiTerbaru[kunci] = v[_Db.statusVerifikasi] as String?;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      if (nama != null) _namaAdmin = nama;

      _totalPerjalanan = barisPerjalanan?.length;
      _perjalananSelesai = barisPerjalanan?.where(_perjalananTuntas).length;

      _deteksiAi = deteksi;

      if (barisTemuan == null) {
        _totalTemuan = null;
        _menunggu = null;
        _terverifikasi = null;
        _ditolak = null;
      } else {
        _totalTemuan = barisTemuan.length;
        var m = 0;
        var v = 0;
        var d = 0;

        for (final t in barisTemuan) {
          // Hasil verifikasi petugas diutamakan; kalau belum ada,
          // pakai kolom status pada tabel temuan.
          final status =
              statusVerifikasiTerbaru['${t[_Db.idTemuan]}'] ??
              t[_Db.statusTemuan] as String?;

          switch (_klasifikasi(status)) {
            case _KategoriTemuan.menunggu:
              m++;
              break;
            case _KategoriTemuan.terverifikasi:
              v++;
              break;
            case _KategoriTemuan.ditolak:
              d++;
              break;
          }
        }

        _menunggu = m;
        _terverifikasi = v;
        _ditolak = d;
      }

      _memuat = false;
    });
  }

  Future<void> _logout() async {
    try {
      await SupabaseService.client.auth.signOut();

      // Hapus cache supaya petugas berikutnya tidak melihat nama lama.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kunciNamaAdmin);

      await SupabaseService.siapkanPengguna();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('Gagal logout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal keluar dari akun.')));
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        backgroundColor: _latar,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              if (_memuat && _tab == 0)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: _biru,
                  backgroundColor: Color(0xFFE2E8F0),
                )
              else
                const SizedBox(height: 2),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [_tabDashboard(), _tabTemuan(), _tabProfil()],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _navigasiBawah(),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Image.asset(
            'assets/images/dinsos.png',
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.account_balance,
              size: 20,
              color: Color(0xFF0A3277),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'Dinas Sosial Kota Surabaya',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0A3277),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB DASHBOARD
  // ---------------------------------------------------------------------------

  Widget _tabDashboard() {
    return RefreshIndicator(
      color: _biru,
      onRefresh: _muat,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _kartuSelamatDatang(),
            const SizedBox(height: 18),
            _barisJudulMetrik(),
            const SizedBox(height: 10),
            if (!_memuat && _gagalMuat.isNotEmpty) ...[
              _bannerGagal(),
              const SizedBox(height: 10),
            ],
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _kartuMetrik(
                      judul: 'Total Perjalanan',
                      nilai: _totalPerjalanan,
                      keterangan: 'Sesi navigasi warga',
                      ikon: Icons.alt_route_rounded,
                      warnaIkon: _biru,
                      latarIkon: const Color(0xFFE4EAFF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _kartuMetrik(
                      judul: 'Perjalanan Selesai',
                      nilai: _perjalananSelesai,
                      keterangan: 'Tiba dengan selamat',
                      ikon: Icons.check_circle_outline_rounded,
                      warnaIkon: _biru,
                      latarIkon: const Color(0xFFE4EAFF),
                      lingkaran: true,
                      warnaKeterangan: const Color(0xFF067647),
                      keteranganTebal: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _kartuMetrik(
                      judul: 'Deteksi AI',
                      nilai: _deteksiAi,
                      keterangan: 'Objek & halangan via kamera',
                      ikon: Icons.smart_toy_outlined,
                      warnaIkon: _biru,
                      latarIkon: const Color(0xFFE4EAFF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _kartuMetrik(
                      judul: 'Total Temuan',
                      nilai: _totalTemuan,
                      keterangan: 'Isu teridentifikasi',
                      ikon: Icons.warning_amber_rounded,
                      warnaIkon: const Color(0xFFDC2626),
                      latarIkon: const Color(0xFFFEE2E2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _kartuStatusTemuan(),
          ],
        ),
      ),
    );
  }

  Widget _kartuSelamatDatang() {
    final aktif = _gagalMuat.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF0F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E4EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCE4FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 13,
                  color: Color(0xFF1E3A8A),
                ),
                const SizedBox(width: 5),
                Text(
                  'Dashboard Utama',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Selamat Datang',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Petugas Dinas Sosial Kota Surabaya',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: aktif
                      ? const Color(0xFF067647)
                      : const Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                aktif
                    ? 'Sistem Pemantauan Aktif'
                    : 'Sebagian data gagal dimuat',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: aktif
                      ? const Color(0xFF067647)
                      : const Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barisJudulMetrik() {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFE4EAFF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.bar_chart_rounded, size: 16, color: _biru),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Metrik Operasional',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF101828),
            ),
          ),
        ),
        PopupMenuButton<_Periode>(
          tooltip: 'Pilih periode',
          initialValue: _periode,
          onSelected: (nilai) {
            if (nilai == _periode) return;
            setState(() => _periode = nilai);
            _muat();
          },
          itemBuilder: (context) => [
            for (final p in _Periode.values)
              PopupMenuItem<_Periode>(
                value: p,
                child: Text(
                  p.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: p == _periode
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text(
              _periode.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF101828),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bannerGagal() {
    final rincian = _gagalMuat.entries
        .map((e) => '• ${e.key}: ${e.value}')
        .join('\n');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, size: 18, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sebagian data gagal dimuat',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  rincian,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    height: 1.4,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _muat,
            child: Text(
              'Coba Lagi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _biru,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuMetrik({
    required String judul,
    required int? nilai,
    required String keterangan,
    required IconData ikon,
    required Color warnaIkon,
    required Color latarIkon,
    bool lingkaran = false,
    Color? warnaKeterangan,
    bool keteranganTebal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  judul,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: const Color(0xFF475467),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: latarIkon,
                  shape: lingkaran ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: lingkaran ? null : BorderRadius.circular(9),
                ),
                child: Icon(ikon, size: 17, color: warnaIkon),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nilai?.toString() ?? '–',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            keterangan,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              height: 1.3,
              fontWeight: keteranganTebal ? FontWeight.w700 : FontWeight.w500,
              color: warnaKeterangan ?? const Color(0xFF475467),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuStatusTemuan() {
    const warnaMenunggu = Color(0xFFF59E0B);
    const warnaVerifikasi = Color(0xFF22C55E);
    const warnaDitolak = Color(0xFFEF4444);

    final m = _menunggu ?? 0;
    final v = _terverifikasi ?? 0;
    final d = _ditolak ?? 0;

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
              const Icon(
                Icons.pie_chart_outline_rounded,
                size: 20,
                color: _biru,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Status Temuan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF101828),
                  ),
                ),
              ),
              Text(
                'Total ${_totalTemuan?.toString() ?? '–'} Kasus',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF344054),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _barisStatus(
            warnaTitik: warnaMenunggu,
            label: 'Menunggu Verifikasi',
            jumlah: _menunggu,
            ikon: Icons.assignment_outlined,
            warnaLencana: const Color(0xFFD97706),
            latarLencana: const Color(0xFFFEF3C7),
          ),
          const SizedBox(height: 8),
          _barisStatus(
            warnaTitik: warnaVerifikasi,
            label: 'Terverifikasi',
            jumlah: _terverifikasi,
            ikon: Icons.check_circle_outline_rounded,
            warnaLencana: const Color(0xFF16A34A),
            latarLencana: const Color(0xFFDCFCE7),
          ),
          const SizedBox(height: 8),
          _barisStatus(
            warnaTitik: warnaDitolak,
            label: 'Ditolak',
            jumlah: _ditolak,
            ikon: Icons.cancel_outlined,
            warnaLencana: const Color(0xFFDC2626),
            latarLencana: const Color(0xFFFEE2E2),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 9,
              child: (m + v + d) == 0
                  ? Container(color: const Color(0xFFE5E7EB))
                  : Row(
                      children: [
                        if (m > 0)
                          Expanded(
                            flex: m,
                            child: Container(color: warnaMenunggu),
                          ),
                        if (v > 0)
                          Expanded(
                            flex: v,
                            child: Container(color: warnaVerifikasi),
                          ),
                        if (d > 0)
                          Expanded(
                            flex: d,
                            child: Container(color: warnaDitolak),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisStatus({
    required Color warnaTitik,
    required String label,
    required int? jumlah,
    required IconData ikon,
    required Color warnaLencana,
    required Color latarLencana,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: warnaTitik,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1D2939),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: latarLencana,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ikon, size: 14, color: warnaLencana),
                const SizedBox(width: 4),
                Text(
                  jumlah?.toString() ?? '–',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: warnaLencana,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB TEMUAN & PROFIL
  // ---------------------------------------------------------------------------

  Widget _tabTemuan() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.construction_outlined,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(
              'Daftar Temuan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Halaman ini akan diimplementasi pada Sprint 3.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabProfil() {
    final email = SupabaseService.client.auth.currentUser?.email ?? '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE4EAFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 38,
                    color: _biru,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _namaAdmin ?? 'Petugas Dinas Sosial',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dinas Sosial Kota Surabaya',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0A3277),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'Keluar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
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
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGASI BAWAH
  // ---------------------------------------------------------------------------

  Widget _navigasiBawah() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _itemNav(
                indeks: 0,
                label: 'Dashboard',
                ikonAktif: Icons.bar_chart_rounded,
                ikonTidak: Icons.bar_chart_rounded,
              ),
              _itemNav(
                indeks: 1,
                label: 'Temuan',
                ikonAktif: Icons.location_on,
                ikonTidak: Icons.location_on_outlined,
              ),
              _itemNav(
                indeks: 2,
                label: 'Profil',
                ikonAktif: Icons.account_circle,
                ikonTidak: Icons.account_circle_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemNav({
    required int indeks,
    required String label,
    required IconData ikonAktif,
    required IconData ikonTidak,
  }) {
    final aktif = _tab == indeks;
    final warna = aktif ? _biru : const Color(0xFF1D2939);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = indeks),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(aktif ? ikonAktif : ikonTidak, size: 24, color: warna),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
                  color: warna,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
