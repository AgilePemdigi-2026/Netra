import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

// =============================================================================
// KONFIGURASI
// =============================================================================
class _Db {
  /// Nama bucket Supabase Storage tempat foto dokumentasi disimpan.
  /// Dipakai kalau kolom `dokumentasi` berisi path, bukan URL lengkap.
  /// Samakan dengan nilai di daftar_temuan_screen.dart.
  static const String bucketDokumentasi = 'dokumentasi-temuan';

  /// Jumlah maksimum riwayat yang dimuat (terbaru lebih dulu).
  static const int batasRiwayat = 300;
}

// =============================================================================
// MODEL
// =============================================================================
enum _HasilVerifikasi { terverifikasi, ditolak }

class _RiwayatItem {
  final int idVerifikasi;
  final int idTemuan;
  final String jenis;
  final String lokasi;
  final String? dokumentasi;
  final String? jenisObjek;
  final double? latitude;
  final double? longitude;
  final String namaPetugas;
  final _HasilVerifikasi hasil;
  final DateTime? waktuVerifikasi;

  const _RiwayatItem({
    required this.idVerifikasi,
    required this.idTemuan,
    required this.jenis,
    required this.lokasi,
    required this.namaPetugas,
    required this.hasil,
    this.dokumentasi,
    this.jenisObjek,
    this.latitude,
    this.longitude,
    this.waktuVerifikasi,
  });

  bool get punyaPeta => latitude != null && longitude != null;

  /// "Sekitar Stasiun Gubeng, Surabaya" -> "Stasiun Gubeng"
  String get namaLokasi {
    var teks = lokasi.trim();
    if (teks.toLowerCase().startsWith('sekitar ')) {
      teks = teks.substring(8).trim();
    }
    final bagian = teks
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return bagian.isEmpty ? teks : bagian.first;
  }
}

// =============================================================================
// HALAMAN RIWAYAT VERIFIKASI
// =============================================================================
class RiwayatVerifikasiScreen extends StatefulWidget {
  /// Bila diisi, kartu temuan ini disorot dan halaman digulir ke sana.
  final int? idTemuanFokus;

  const RiwayatVerifikasiScreen({super.key, this.idTemuanFokus});

  @override
  State<RiwayatVerifikasiScreen> createState() =>
      _RiwayatVerifikasiScreenState();
}

class _RiwayatVerifikasiScreenState extends State<RiwayatVerifikasiScreen> {
  static const Color _biru = Color(0xFF1D4ED8);
  static const Color _biruTua = Color(0xFF0A3277);
  static const Color _latar = Color(0xFFF5F6FA);

  final ScrollController _kontrol = ScrollController();
  final GlobalKey _kunciFokus = GlobalKey();

  List<_RiwayatItem> _daftar = [];
  bool _memuat = false;
  bool _sudahGulir = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  List<List<T>> _bagi<T>(List<T> daftar, int ukuran) {
    final hasil = <List<T>>[];
    for (var i = 0; i < daftar.length; i += ukuran) {
      hasil.add(
        daftar.sublist(
          i,
          i + ukuran > daftar.length ? daftar.length : i + ukuran,
        ),
      );
    }
    return hasil;
  }

  /// Hanya keputusan petugas yang masuk riwayat; status lain diabaikan.
  _HasilVerifikasi? _klasifikasi(String? status) {
    final n = (status ?? '').toLowerCase().replaceAll('_', ' ').trim();

    if (n.contains('tolak') || n.contains('reject') || n.contains('tidak')) {
      return _HasilVerifikasi.ditolak;
    }
    if (n.contains('belum') ||
        n.contains('menunggu') ||
        n.contains('pending')) {
      return null;
    }
    if (n.contains('verifikasi') ||
        n.contains('verified') ||
        n.contains('valid') ||
        n.contains('setuju') ||
        n.contains('terima') ||
        n.contains('approve') ||
        n.contains('accept') ||
        n.contains('sah')) {
      return _HasilVerifikasi.terverifikasi;
    }
    return null;
  }

  Future<List<_RiwayatItem>> _ambilRiwayat() async {
    final client = SupabaseService.client;

    // 1. Catatan verifikasi, terbaru lebih dulu.
    final verifikasi = await client
        .from('verifikasi')
        .select('id_verifikasi,id_temuan,id_admin,status,waktu_verifikasi')
        .order('waktu_verifikasi', ascending: false)
        .range(0, _Db.batasRiwayat - 1);

    final idTemuan = verifikasi
        .map((v) => v['id_temuan'])
        .whereType<Object>()
        .toSet()
        .toList();

    // 2. Data temuan yang diverifikasi.
    final temuanPeta = <String, Map<String, dynamic>>{};
    for (final potongan in _bagi<Object>(idTemuan, 100)) {
      final data = await client
          .from('temuan')
          .select(
            'id_temuan,jenis_permasalahan,lokasi_laporan,latitude,longitude,'
            'dokumentasi,id_deteksi',
          )
          .inFilter('id_temuan', potongan);

      for (final t in data) {
        temuanPeta['${t['id_temuan']}'] = t;
      }
    }

    // 3. Jenis objek hasil deteksi AI (untuk keterangan pada foto).
    final deteksiPeta = <String, String?>{};
    try {
      final idDeteksi = temuanPeta.values
          .map((t) => t['id_deteksi'])
          .whereType<Object>()
          .toSet()
          .toList();

      for (final potongan in _bagi<Object>(idDeteksi, 100)) {
        final data = await client
            .from('deteksi')
            .select('id_deteksi,jenis_objek')
            .inFilter('id_deteksi', potongan);

        for (final d in data) {
          deteksiPeta['${d['id_deteksi']}'] = d['jenis_objek'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Riwayat: gagal mengambil deteksi: $e');
    }

    // 4. Nama petugas verifikator.
    final adminPeta = <String, String>{};
    try {
      final data = await client.from('admin_dinsos').select('id_admin,nama');
      for (final a in data) {
        adminPeta['${a['id_admin']}'] = '${a['nama'] ?? ''}'.trim();
      }
    } catch (e) {
      debugPrint('Riwayat: gagal mengambil nama petugas: $e');
    }

    final hasil = <_RiwayatItem>[];

    for (final v in verifikasi) {
      final keputusan = _klasifikasi(v['status'] as String?);
      if (keputusan == null) continue;

      final kunciTemuan = '${v['id_temuan']}';
      final t = temuanPeta[kunciTemuan];

      final nama = adminPeta['${v['id_admin']}'];

      hasil.add(
        _RiwayatItem(
          idVerifikasi: int.tryParse('${v['id_verifikasi']}') ?? 0,
          idTemuan: int.tryParse(kunciTemuan) ?? 0,
          jenis: _teks(t?['jenis_permasalahan'], 'Temuan #$kunciTemuan'),
          lokasi: _teks(t?['lokasi_laporan'], '-'),
          dokumentasi: t?['dokumentasi'] as String?,
          jenisObjek: deteksiPeta['${t?['id_deteksi']}'],
          latitude: _keDouble(t?['latitude']),
          longitude: _keDouble(t?['longitude']),
          namaPetugas: (nama == null || nama.isEmpty) ? 'Petugas Dinsos' : nama,
          hasil: keputusan,
          waktuVerifikasi: DateTime.tryParse('${v['waktu_verifikasi'] ?? ''}'),
        ),
      );
    }

    return hasil;
  }

  Future<void> _muat() async {
    if (_memuat) return;

    setState(() {
      _memuat = true;
      _galat = null;
    });

    try {
      final hasil = await _ambilRiwayat().timeout(const Duration(seconds: 25));
      if (!mounted) return;
      setState(() {
        _daftar = hasil;
        _memuat = false;
      });
      _gulirKeFokus();
    } catch (e) {
      debugPrint('Riwayat: gagal memuat: $e');
      if (!mounted) return;
      setState(() {
        _galat = e is PostgrestException
            ? e.message
            : 'Riwayat verifikasi belum bisa dimuat. Periksa koneksi internet.';
        _memuat = false;
      });
    }
  }

  /// Menggulir ke kartu temuan yang dipilih dari halaman Daftar Temuan.
  void _gulirKeFokus() {
    final id = widget.idTemuanFokus;
    if (id == null || _sudahGulir) return;

    final indeks = _daftar.indexWhere((e) => e.idTemuan == id);
    if (indeks <= 0) return;

    _sudahGulir = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_kontrol.hasClients) return;

      final perkiraan = (indeks * 430.0).clamp(
        0.0,
        _kontrol.position.maxScrollExtent,
      );
      _kontrol.jumpTo(perkiraan.toDouble());

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final konteks = _kunciFokus.currentContext;
        if (konteks != null) {
          Scrollable.ensureVisible(
            konteks,
            duration: const Duration(milliseconds: 300),
            alignment: 0.05,
          );
        }
      });
    });
  }

  // ---------------------------------------------------------------------------
  // BANTUAN
  // ---------------------------------------------------------------------------

  static double? _keDouble(dynamic nilai) {
    if (nilai == null) return null;
    if (nilai is num) return nilai.toDouble();
    return double.tryParse('$nilai');
  }

  static String _teks(dynamic nilai, String cadangan) {
    final teks = nilai?.toString().trim() ?? '';
    return teks.isEmpty ? cadangan : teks;
  }

  static String _tanggalWib(DateTime? waktu) {
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

  /// Mengubah isi kolom `dokumentasi` menjadi URL foto.
  static String? _urlFoto(String? dokumentasi) {
    final teks = dokumentasi?.trim() ?? '';
    if (teks.isEmpty) return null;

    if (teks.startsWith('http://') || teks.startsWith('https://')) {
      return teks;
    }

    try {
      return SupabaseService.client.storage
          .from(_Db.bucketDokumentasi)
          .getPublicUrl(teks);
    } catch (e) {
      debugPrint('Riwayat: gagal membuat URL foto: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Kartu pertama yang cocok dengan temuan fokus diberi kunci & sorotan.
    final indeksFokus = widget.idTemuanFokus == null
        ? -1
        : _daftar.indexWhere((e) => e.idTemuan == widget.idTemuanFokus);

    return Scaffold(
      backgroundColor: _latar,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            if (_memuat)
              const LinearProgressIndicator(
                minHeight: 2,
                color: _biru,
                backgroundColor: Color(0xFFE2E8F0),
              )
            else
              const SizedBox(height: 2),
            if (_galat != null) _bannerGalat(),
            Expanded(
              child: RefreshIndicator(
                color: _biru,
                onRefresh: _muat,
                child: ListView.builder(
                  controller: _kontrol,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: _daftar.length,
                  itemBuilder: (context, indeks) {
                    final item = _daftar[indeks];
                    final fokus = indeks == indeksFokus;

                    return Padding(
                      padding: EdgeInsets.only(top: indeks == 0 ? 0 : 16),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Garis linimasa di antara dua kartu.
                          if (indeks > 0)
                            Positioned(
                              left: 20,
                              top: -16,
                              width: 2,
                              height: 16,
                              child: Container(color: const Color(0xFFD0D5DD)),
                            ),
                          _KartuRiwayat(
                            key: fokus ? _kunciFokus : null,
                            item: item,
                            urlFoto: _urlFoto(item.dokumentasi),
                            tanggal: _tanggalWib(item.waktuVerifikasi),
                            disorot: fokus,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
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
                const Icon(Icons.account_balance, size: 20, color: _biruTua),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Dinas Sosial Kota Surabaya',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _biruTua,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 26,
              color: _biruTua,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerGalat() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _galat ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                height: 1.4,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
          TextButton(
            onPressed: _memuat ? null : _muat,
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
}

// =============================================================================
// KARTU RIWAYAT
// =============================================================================
class _KartuRiwayat extends StatelessWidget {
  final _RiwayatItem item;
  final String? urlFoto;
  final String tanggal;
  final bool disorot;

  const _KartuRiwayat({
    super.key,
    required this.item,
    required this.urlFoto,
    required this.tanggal,
    required this.disorot,
  });

  static const double _tinggiMedia = 104;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: disorot ? const Color(0xFF1D4ED8) : const Color(0xFFEDEFF3),
          width: disorot ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barisPetugas(),
          const SizedBox(height: 14),
          _kotakTemuan(),
          const SizedBox(height: 10),
          _media(),
          const SizedBox(height: 14),
          _barisLokasi(),
          const SizedBox(height: 12),
          _barisWaktu(),
        ],
      ),
    );
  }

  Widget _barisPetugas() {
    return Row(
      children: [
        const Icon(Icons.badge, size: 22, color: Color(0xFF0A3277)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Petugas Verifikator',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475467),
                ),
              ),
              Text(
                item.namaPetugas,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF475467),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _lencanaHasil(),
      ],
    );
  }

  Widget _lencanaHasil() {
    final diterima = item.hasil == _HasilVerifikasi.terverifikasi;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: diterima ? const Color(0xFF0B6B2E) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            diterima ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 17,
            color: diterima ? Colors.white : const Color(0xFFB91C1C),
          ),
          const SizedBox(width: 5),
          Text(
            diterima ? 'Terverifikasi' : 'Ditolak',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: diterima ? Colors.white : const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotakTemuan() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ID Temuan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '#${item.idTemuan} ${item.jenis}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF101828),
            ),
          ),
        ],
      ),
    );
  }

  // --- Foto bukti + peta -----------------------------------------------------

  Widget _media() {
    final punyaFoto = urlFoto != null;

    // Ada koordinat: foto dan peta berdampingan.
    if (item.punyaPeta) {
      return SizedBox(
        height: _tinggiMedia,
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: punyaFoto
                    ? _fotoDenganLabel(BoxFit.cover)
                    : _penggantiFoto(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _PetaMini(
                  latitude: item.latitude!,
                  longitude: item.longitude!,
                  label: item.namaLokasi,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Tanpa koordinat: satu foto utuh di atas latar abu-abu.
    return SizedBox(
      height: _tinggiMedia,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: punyaFoto ? _fotoDenganLabel(BoxFit.contain) : _penggantiFoto(),
      ),
    );
  }

  Widget _fotoDenganLabel(BoxFit fit) {
    final adaJenis = (item.jenisObjek ?? '').trim().isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFFECEEF2)),
        Image.network(
          urlFoto!,
          fit: fit,
          loadingBuilder: (context, child, progres) {
            if (progres == null) return child;
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _penggantiFoto(keterangan: 'Foto tidak dapat dimuat'),
        ),
        Positioned(
          left: 6,
          bottom: 6,
          right: 6,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: _lencanaLabel(
              ikon: adaJenis
                  ? Icons.image_outlined
                  : Icons.photo_camera_outlined,
              teks: adaJenis ? item.jenisObjek!.trim() : 'Bukti AI',
            ),
          ),
        ),
      ],
    );
  }

  Widget _penggantiFoto({String keterangan = 'Tidak ada foto'}) {
    return Container(
      color: const Color(0xFFECEEF2),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: 26,
            color: Color(0xFF98A2B3),
          ),
          const SizedBox(height: 3),
          Text(
            keterangan,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisLokasi() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.location_on_outlined,
            size: 21,
            color: Color(0xFF475467),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.lokasi,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1D2939),
            ),
          ),
        ),
      ],
    );
  }

  Widget _barisWaktu() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.schedule_rounded,
            size: 21,
            color: Color(0xFF475467),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 76,
          child: Text(
            'Waktu\nVerifikasi:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475467),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tanggal,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF101828),
            ),
          ),
        ),
      ],
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
// =============================================================================
class _PetaMini extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String label;

  const _PetaMini({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  static const int _zoom = 16;
  static const String _userAgent = 'NETRA/1.0 (Dinas Sosial Kota Surabaya)';

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

        // Ambil blok 2x2 ubin agar titik selalu bisa berada di tengah kotak.
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
            // Penanda lokasi temuan.
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
                  ikon: Icons.near_me_outlined,
                  warnaIkon: const Color(0xFF4ADE80),
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
