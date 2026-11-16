import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

// =============================================================================
// KONFIGURASI DATABASE (sesuai ERD Supabase NETRA)
// =============================================================================
class _Db {
  /// Nama bucket Supabase Storage tempat foto dokumentasi disimpan.
  /// Dipakai kalau kolom `dokumentasi` berisi path, bukan URL lengkap.
  static const String bucketDokumentasi = 'dokumentasi';

  /// Jumlah maksimum temuan yang dimuat sekaligus (terbaru lebih dulu).
  static const int batasTemuan = 1000;
}

// =============================================================================
// MODEL
// =============================================================================
enum StatusTemuan { menunggu, terverifikasi, ditolak }

class TemuanItem {
  final int id;
  final String jenis;
  final String lokasi;
  final String? dokumentasi;
  final String? deskripsi;
  final DateTime? waktu;
  final double? akurasi; // dalam persen (0-100)
  final String? tingkat;
  final double? latitude;
  final double? longitude;
  final StatusTemuan status;

  const TemuanItem({
    required this.id,
    required this.jenis,
    required this.lokasi,
    required this.status,
    this.dokumentasi,
    this.deskripsi,
    this.waktu,
    this.akurasi,
    this.tingkat,
    this.latitude,
    this.longitude,
  });

  /// "Sekitar Stasiun Gubeng, Jl. Stasiun Gubeng, Surabaya"
  /// -> "Stasiun Gubeng, Surabaya"
  String get lokasiSingkat {
    var teks = lokasi.trim();
    if (teks.toLowerCase().startsWith('sekitar ')) {
      teks = teks.substring(8).trim();
    }
    final bagian = teks
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (bagian.length >= 2) return '${bagian.first}, ${bagian.last}';
    return teks;
  }

  /// Sudah diproses petugas (terverifikasi atau ditolak).
  bool get sudahDiproses => status != StatusTemuan.menunggu;
}

enum _Filter { semua, menunggu, terverifikasi, ditolak }

// =============================================================================
// TAB TEMUAN AKSESIBILITAS
// =============================================================================
class TemuanAksesibilitasTab extends StatefulWidget {
  /// true bila tab ini sedang dibuka. Data baru dimuat saat tab dibuka,
  /// dan dimuat ulang setiap kali tab dibuka kembali.
  final bool aktif;

  const TemuanAksesibilitasTab({super.key, this.aktif = true});

  @override
  State<TemuanAksesibilitasTab> createState() => _TemuanAksesibilitasTabState();
}

class _TemuanAksesibilitasTabState extends State<TemuanAksesibilitasTab> {
  static const Color _biruTua = Color(0xFF0B3FA8);
  static const Color _biru = Color(0xFF1D4ED8);

  static const Color _warnaMenunggu = Color(0xFFF59E0B);
  static const Color _warnaVerifikasi = Color(0xFF16A34A);
  static const Color _warnaDitolak = Color(0xFFDC2626);

  final TextEditingController _pencarian = TextEditingController();

  List<TemuanItem> _semua = [];
  _Filter _filter = _Filter.semua;

  bool _memuat = false;
  bool _sudahMuat = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    if (widget.aktif) _muat();
  }

  @override
  void didUpdateWidget(covariant TemuanAksesibilitasTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Muat saat pertama kali dibuka, dan segarkan setiap tab dibuka lagi.
    if (widget.aktif && !oldWidget.aktif) {
      _muat();
    }
  }

  @override
  void dispose() {
    _pencarian.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  static const String _kolomDasar =
      'id_temuan,jenis_permasalahan,lokasi_laporan,latitude,longitude,'
      'dokumentasi,deskripsi,status_tindak_lanjut,waktu_temuan,status,'
      'id_deteksi';

  Future<List<TemuanItem>> _ambilDaftar() async {
    final client = SupabaseService.client;

    // 1. Temuan beserta data deteksinya (akurasi & tingkat bahaya).
    List<Map<String, dynamic>> baris;
    try {
      baris = await client
          .from('temuan')
          .select('$_kolomDasar,deteksi(akurasi_deteksi,tingkat_bahaya)')
          .order('waktu_temuan', ascending: false)
          .range(0, _Db.batasTemuan - 1);
    } catch (e) {
      // Bila relasi ke tabel deteksi tidak terbaca, ambil temuan saja.
      debugPrint('Temuan: gagal mengambil relasi deteksi: $e');
      baris = await client
          .from('temuan')
          .select(_kolomDasar)
          .order('waktu_temuan', ascending: false)
          .range(0, _Db.batasTemuan - 1);
    }

    // 2. Hasil verifikasi petugas (diambil yang terbaru untuk tiap temuan).
    final statusVerifikasi = <String, String?>{};
    try {
      final verifikasi = await client
          .from('verifikasi')
          .select('id_temuan,status,waktu_verifikasi');

      final waktuTerbaru = <String, DateTime>{};
      for (final v in verifikasi) {
        final kunci = '${v['id_temuan']}';
        final waktu =
            DateTime.tryParse('${v['waktu_verifikasi'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final sebelumnya = waktuTerbaru[kunci];
        if (sebelumnya == null || waktu.isAfter(sebelumnya)) {
          waktuTerbaru[kunci] = waktu;
          statusVerifikasi[kunci] = v['status'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Temuan: gagal mengambil verifikasi: $e');
    }

    return baris.map((row) {
      final deteksiMentah = row['deteksi'];
      final deteksi = deteksiMentah is List
          ? (deteksiMentah.isNotEmpty ? deteksiMentah.first : null)
          : deteksiMentah;
      final dataDeteksi = deteksi is Map ? deteksi : const {};

      var akurasi = _keDouble(dataDeteksi['akurasi_deteksi']);
      if (akurasi != null && akurasi <= 1.0) akurasi = akurasi * 100;

      final status =
          statusVerifikasi['${row['id_temuan']}'] ?? row['status'] as String?;

      return TemuanItem(
        id: int.tryParse('${row['id_temuan']}') ?? 0,
        jenis: _teks(row['jenis_permasalahan'], '-'),
        lokasi: _teks(row['lokasi_laporan'], '-'),
        dokumentasi: row['dokumentasi'] as String?,
        deskripsi: row['deskripsi'] as String?,
        waktu: DateTime.tryParse('${row['waktu_temuan'] ?? ''}'),
        akurasi: akurasi,
        tingkat: _kapital(dataDeteksi['tingkat_bahaya'] as String?),
        latitude: _keDouble(row['latitude']),
        longitude: _keDouble(row['longitude']),
        status: _klasifikasi(status),
      );
    }).toList();
  }

  Future<void> _muat() async {
    if (_memuat) return;

    setState(() {
      _memuat = true;
      _galat = null;
    });

    try {
      final hasil = await _ambilDaftar().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _semua = hasil;
        _sudahMuat = true;
        _memuat = false;
      });
    } catch (e) {
      debugPrint('Temuan: gagal memuat: $e');
      if (!mounted) return;
      setState(() {
        _galat = e is PostgrestException
            ? e.message
            : 'Data temuan belum bisa dimuat. Periksa koneksi internet.';
        _sudahMuat = true;
        _memuat = false;
      });
    }
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

  static String? _kapital(String? teks) {
    final t = teks?.trim() ?? '';
    if (t.isEmpty) return null;
    return t[0].toUpperCase() + t.substring(1).toLowerCase();
  }

  static StatusTemuan _klasifikasi(String? status) {
    final n = (status ?? '').toLowerCase().replaceAll('_', ' ').trim();

    if (n.contains('tolak') || n.contains('reject')) {
      return StatusTemuan.ditolak;
    }
    // "belum diverifikasi" mengandung kata "verifikasi", jadi dicek lebih dulu.
    if (n.contains('belum') ||
        n.contains('menunggu') ||
        n.contains('pending') ||
        n.contains('baru')) {
      return StatusTemuan.menunggu;
    }
    if (n.contains('verifikasi') ||
        n.contains('verified') ||
        n.contains('valid') ||
        n.contains('setuju') ||
        n.contains('terima') ||
        n.contains('approve') ||
        n.contains('accept')) {
      return StatusTemuan.terverifikasi;
    }
    return StatusTemuan.menunggu;
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

  static String _persen(double nilai) =>
      '${nilai.toStringAsFixed(2).replaceAll('.', ',')}%';

  /// Mengubah isi kolom `dokumentasi` menjadi URL foto.
  /// Bisa berupa URL lengkap, atau path di Supabase Storage.
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
      debugPrint('Temuan: gagal membuat URL foto: $e');
      return null;
    }
  }

  List<TemuanItem> get _tersaring {
    final kata = _pencarian.text.trim().toLowerCase();

    return _semua.where((t) {
      final cocokFilter = switch (_filter) {
        _Filter.semua => true,
        _Filter.menunggu => t.status == StatusTemuan.menunggu,
        _Filter.terverifikasi => t.status == StatusTemuan.terverifikasi,
        _Filter.ditolak => t.status == StatusTemuan.ditolak,
      };
      if (!cocokFilter) return false;

      if (kata.isEmpty) return true;

      return t.jenis.toLowerCase().contains(kata) ||
          t.lokasi.toLowerCase().contains(kata) ||
          (t.deskripsi ?? '').toLowerCase().contains(kata) ||
          t.id.toString() == kata;
    }).toList();
  }

  int _jumlah(StatusTemuan status) =>
      _semua.where((t) => t.status == status).length;

  void _bukaDetail(TemuanItem temuan) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _DetailTemuanSementara(temuan: temuan)),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final daftar = _tersaring;

    return Column(
      children: [
        _barisJudul(),
        _kolomPencarian(),
        _barisFilter(),
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
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: daftar.length,
              itemBuilder: (context, indeks) {
                final temuan = daftar[indeks];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _KartuTemuan(
                    temuan: temuan,
                    urlFoto: _urlFoto(temuan.dokumentasi),
                    tanggal: _tanggalWib(temuan.waktu),
                    akurasi: temuan.akurasi == null
                        ? null
                        : _persen(temuan.akurasi!),
                    onTekan: () => _bukaDetail(temuan),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _barisJudul() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 24, color: _biruTua),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Temuan Aksesibilitas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF101828),
              ),
            ),
          ),
          InkWell(
            onTap: _memuat ? null : _muat,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE4EAFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _memuat
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _biru,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 20, color: _biru),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kolomPencarian() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _pencarian,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Cari temuan',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: const Color(0xFF667085),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 22,
            color: Color(0xFF667085),
          ),
          suffixIcon: _pencarian.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _pencarian.clear();
                    setState(() {});
                  },
                ),
          filled: true,
          fillColor: const Color(0xFFECEEF2),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _barisFilter() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chipFilter(
            filter: _Filter.semua,
            label: 'Semua (${_semua.length})',
            ikon: Icons.list_alt_rounded,
          ),
          const SizedBox(width: 8),
          _chipFilter(
            filter: _Filter.menunggu,
            label: 'Menunggu Verifikasi (${_jumlah(StatusTemuan.menunggu)})',
            warnaTitik: _warnaMenunggu,
          ),
          const SizedBox(width: 8),
          _chipFilter(
            filter: _Filter.terverifikasi,
            label: 'Terverifikasi (${_jumlah(StatusTemuan.terverifikasi)})',
            warnaTitik: _warnaVerifikasi,
          ),
          const SizedBox(width: 8),
          _chipFilter(
            filter: _Filter.ditolak,
            label: 'Ditolak (${_jumlah(StatusTemuan.ditolak)})',
            warnaTitik: _warnaDitolak,
          ),
        ],
      ),
    );
  }

  Widget _chipFilter({
    required _Filter filter,
    required String label,
    IconData? ikon,
    Color? warnaTitik,
  }) {
    final aktif = _filter == filter;
    final warnaTeks = aktif ? Colors.white : const Color(0xFF1D2939);

    return InkWell(
      onTap: () => setState(() => _filter = filter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: aktif ? _biruTua : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: aktif ? _biruTua : const Color(0xFFE2E4EA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ikon != null) ...[
              Icon(ikon, size: 16, color: warnaTeks),
              const SizedBox(width: 6),
            ],
            if (warnaTitik != null) ...[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: warnaTitik,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: warnaTeks,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerGalat() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
// KARTU TEMUAN
// =============================================================================
class _KartuTemuan extends StatelessWidget {
  final TemuanItem temuan;
  final String? urlFoto;
  final String tanggal;
  final String? akurasi;
  final VoidCallback onTekan;

  const _KartuTemuan({
    required this.temuan,
    required this.urlFoto,
    required this.tanggal,
    required this.akurasi,
    required this.onTekan,
  });

  static const Color _biruTua = Color(0xFF0B3FA8);

  Color get _warnaStatus {
    switch (temuan.status) {
      case StatusTemuan.menunggu:
        return const Color(0xFFF59E0B);
      case StatusTemuan.terverifikasi:
        return const Color(0xFF16A34A);
      case StatusTemuan.ditolak:
        return const Color(0xFFDC2626);
    }
  }

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
            // Garis warna status di bagian atas kartu.
            Container(height: 5, color: _warnaStatus),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECEEF2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ID Temuan: ${temuan.id}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF344054),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _lencanaStatus(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    temuan.jenis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _foto(),
                  const SizedBox(height: 10),
                  _kotakInfo(),
                  const SizedBox(height: 12),
                  _tombol(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lencanaStatus() {
    late final Color latar;
    late final Color teks;
    late final Color ikonWarna;
    late final IconData ikon;
    late final String label;

    switch (temuan.status) {
      case StatusTemuan.menunggu:
        latar = const Color(0xFFFEF3C7);
        teks = const Color(0xFF92400E);
        ikonWarna = const Color(0xFFD97706);
        ikon = Icons.hourglass_top_rounded;
        label = 'Menunggu Verifikasi';
        break;
      case StatusTemuan.terverifikasi:
        latar = const Color(0xFFDCFCE7);
        teks = const Color(0xFF166534);
        ikonWarna = const Color(0xFF16A34A);
        ikon = Icons.check_circle_rounded;
        label = 'Terverifikasi';
        break;
      case StatusTemuan.ditolak:
        latar = const Color(0xFFFEE2E2);
        teks = const Color(0xFF991B1B);
        ikonWarna = const Color(0xFFDC2626);
        ikon = Icons.cancel_rounded;
        label = 'Ditolak';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: ikonWarna),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: teks,
            ),
          ),
        ],
      ),
    );
  }

  Widget _foto() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1.8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (urlFoto == null)
              _penggantiFoto('Tidak ada foto')
            else
              Image.network(
                urlFoto!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progres) {
                  if (progres == null) return child;
                  return Container(
                    color: const Color(0xFFECEEF2),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    _penggantiFoto('Foto tidak dapat dimuat'),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          temuan.lokasiSingkat,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _penggantiFoto(String keterangan) {
    return Container(
      color: const Color(0xFFECEEF2),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: 30,
            color: Color(0xFF98A2B3),
          ),
          const SizedBox(height: 4),
          Text(
            keterangan,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotakInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Color(0xFF475467),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  temuan.lokasi,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: Color(0xFF475467),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tanggal,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: const Color(0xFF475467),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 15,
                color: Color(0xFF1D4ED8),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF1D2939),
                    ),
                    children: [
                      const TextSpan(
                        text: 'Akurasi Deteksi: ',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(
                        text: akurasi ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              if (temuan.tingkat != null) _lencanaTingkat(temuan.tingkat!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lencanaTingkat(String tingkat) {
    late final Color latar;
    late final Color teks;

    switch (tingkat.toLowerCase()) {
      case 'tinggi':
        latar = const Color(0xFF86F5A0);
        teks = const Color(0xFF0B3B1E);
        break;
      case 'sedang':
        latar = const Color(0xFFFDE68A);
        teks = const Color(0xFF78350F);
        break;
      default:
        latar = const Color(0xFFE1E4EA);
        teks = const Color(0xFF344054);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Tingkat: $tingkat',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: teks,
        ),
      ),
    );
  }

  Widget _tombol() {
    final diproses = temuan.sudahDiproses;

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onTekan,
        icon: Icon(
          diproses ? Icons.open_in_new_rounded : Icons.fact_check_outlined,
          size: 18,
        ),
        label: Text(
          diproses ? 'Tinjau Riwayat Verifikasi' : 'Lihat Detail',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: diproses ? const Color(0xFFE8EAEE) : _biruTua,
          foregroundColor: diproses ? const Color(0xFF1D4ED8) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

// =============================================================================
// HALAMAN DETAIL (SEMENTARA)
// Akan diganti dengan halaman Detail Temuan + verifikasi pada langkah berikutnya.
// =============================================================================
class _DetailTemuanSementara extends StatelessWidget {
  final TemuanItem temuan;

  const _DetailTemuanSementara({required this.temuan});

  @override
  Widget build(BuildContext context) {
    final judul = temuan.sudahDiproses ? 'Riwayat Verifikasi' : 'Detail Temuan';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        title: Text(
          judul,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
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
                'ID Temuan: ${temuan.id}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                temuan.jenis,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF475467),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Halaman ini akan dibuat pada langkah berikutnya.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
