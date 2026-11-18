import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

import 'riwayat_verifikasi_screen.dart';
import 'verifikasi_screen.dart';

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

    // Ambil tabel temuan terlebih dahulu tanpa embedded relation.
    // Ini menghindari kegagalan query akibat relasi PostgREST yang tidak
    // dikenali/ambigu dan memastikan kolom yang dipakai sesuai skema DB.
    final responTemuan = await client
        .from('temuan')
        .select(_kolomDasar)
        .order('waktu_temuan', ascending: false)
        .limit(_Db.batasTemuan)
        .timeout(const Duration(seconds: 15));

    final baris = List<Map<String, dynamic>>.from(responTemuan);
    if (baris.isEmpty) return <TemuanItem>[];

    // Ambil data deteksi secara terpisah agar daftar temuan tetap dapat
    // ditampilkan walaupun data deteksi tidak tersedia.
    final idDeteksi = baris
        .map((row) => row['id_deteksi'])
        .where((id) => id != null)
        .toSet()
        .toList();
    final dataDeteksi = <String, Map<String, dynamic>>{};

    if (idDeteksi.isNotEmpty) {
      try {
        final responDeteksi = await client
            .from('deteksi')
            .select('id_deteksi,akurasi_deteksi,tingkat_bahaya')
            .inFilter('id_deteksi', idDeteksi)
            .timeout(const Duration(seconds: 10));

        for (final row in responDeteksi) {
          dataDeteksi['${row['id_deteksi']}'] = Map<String, dynamic>.from(row);
        }
      } catch (e) {
        // Data deteksi bukan syarat untuk menampilkan temuan.
        debugPrint('Temuan: data deteksi tidak dapat dimuat: $e');
      }
    }

    // Ambil verifikasi hanya untuk ID temuan yang sedang ditampilkan.
    // Jika tabel verifikasi belum dapat dibaca, gunakan status di tabel temuan.
    final idTemuan = baris.map((row) => row['id_temuan']).toList();
    final statusVerifikasi = <String, String>{};

    try {
      final responVerifikasi = await client
          .from('verifikasi')
          .select('id_temuan,status,waktu_verifikasi')
          .inFilter('id_temuan', idTemuan)
          .order('waktu_verifikasi', ascending: false)
          .timeout(const Duration(seconds: 10));

      // Hasil sudah diurutkan terbaru lebih dulu. Simpan satu status per temuan.
      for (final row in responVerifikasi) {
        final id = '${row['id_temuan']}';
        final status = row['status']?.toString();
        if (status != null && !statusVerifikasi.containsKey(id)) {
          statusVerifikasi[id] = status;
        }
      }
    } catch (e) {
      debugPrint('Temuan: riwayat verifikasi tidak dapat dimuat: $e');
    }

    return baris.map((row) {
      final id = row['id_temuan'];
      final deteksi = dataDeteksi['${row['id_deteksi']}'];

      var akurasi = _keDouble(deteksi?['akurasi_deteksi']);
      if (akurasi != null && akurasi <= 1.0) {
        akurasi *= 100;
      }

      // Status di tabel verifikasi menjadi prioritas. Jika belum ada,
      // gunakan status_tindak_lanjut, lalu kolom status lama sebagai fallback.
      final status =
          statusVerifikasi['$id'] ??
          row['status_tindak_lanjut']?.toString() ??
          row['status']?.toString();

      return TemuanItem(
        id: int.tryParse('$id') ?? 0,
        jenis: _teks(row['jenis_permasalahan'], '-'),
        lokasi: _teks(row['lokasi_laporan'], '-'),
        dokumentasi: row['dokumentasi']?.toString(),
        deskripsi: row['deskripsi']?.toString(),
        waktu: DateTime.tryParse('${row['waktu_temuan'] ?? ''}'),
        akurasi: akurasi,
        tingkat: _kapital(deteksi?['tingkat_bahaya']?.toString()),
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
      final hasil = await _ambilDaftar().timeout(const Duration(seconds: 40));

      if (!mounted) return;

      setState(() {
        _semua = hasil;
        _memuat = false;
      });
    } catch (e) {
      debugPrint('Temuan: gagal memuat: $e');

      if (!mounted) return;

      setState(() {
        _galat = e is PostgrestException
            ? e.message
            : 'Data temuan belum bisa dimuat. Periksa koneksi internet.';
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
    // Sudah diverifikasi/ditolak -> halaman Riwayat Verifikasi.
    // Masih menunggu -> halaman Detail Temuan (untuk diverifikasi).
    final Widget halaman = temuan.sudahDiproses
        ? RiwayatVerifikasiScreen(idTemuanFokus: temuan.id)
        : _DetailTemuanSementara(temuan: temuan);

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => halaman));
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
// HALAMAN DETAIL TEMUAN
// =============================================================================

class _DetailTemuanSementara extends StatelessWidget {
  final TemuanItem temuan;

  const _DetailTemuanSementara({required this.temuan});

  static const Color _biru = Color(0xFF0B3FA8);
  static const Color _teks = Color(0xFF344054);
  static const Color _abu = Color(0xFF667085);
  static const Color _latar = Color(0xFFF3F4F6);

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

    return '${dua(t.day)} ${bulan[t.month - 1]} ${t.year}, '
        '${dua(t.hour)}:${dua(t.minute)}';
  }

  String _koordinat(double? nilai) {
    return nilai == null ? '-' : nilai.toStringAsFixed(6);
  }

  String? _urlFoto() {
    final dokumentasi = temuan.dokumentasi?.trim() ?? '';

    if (dokumentasi.isEmpty) return null;

    if (dokumentasi.startsWith('http://') ||
        dokumentasi.startsWith('https://')) {
      return dokumentasi;
    }

    try {
      return SupabaseService.client.storage
          .from(_Db.bucketDokumentasi)
          .getPublicUrl(dokumentasi);
    } catch (_) {
      return null;
    }
  }

  String _urlPeta() {
    final lat = temuan.latitude;
    final lon = temuan.longitude;

    if (lat == null || lon == null) return '';

    return Uri.https('staticmap.openstreetmap.de', '/staticmap.php', {
      'center': '$lat,$lon',
      'zoom': '15',
      'size': '600x300',
      'markers': '$lat,$lon,red-pushpin',
    }).toString();
  }

  Color _warnaStatus() {
    switch (temuan.status) {
      case StatusTemuan.menunggu:
        return const Color(0xFFFEF3C7);
      case StatusTemuan.terverifikasi:
        return const Color(0xFFDCFCE7);
      case StatusTemuan.ditolak:
        return const Color(0xFFFEE2E2);
    }
  }

  Color _warnaTeksStatus() {
    switch (temuan.status) {
      case StatusTemuan.menunggu:
        return const Color(0xFF92400E);
      case StatusTemuan.terverifikasi:
        return const Color(0xFF166534);
      case StatusTemuan.ditolak:
        return const Color(0xFF991B1B);
    }
  }

  String _labelStatus() {
    switch (temuan.status) {
      case StatusTemuan.menunggu:
        return 'Menunggu Verifikasi';
      case StatusTemuan.terverifikasi:
        return 'Terverifikasi';
      case StatusTemuan.ditolak:
        return 'Ditolak';
    }
  }

  @override
  Widget build(BuildContext context) {
    final foto = _urlFoto();

    return Scaffold(
      backgroundColor: _latar,

      // HEADER
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: _biru,
        elevation: 0,
        toolbarHeight: 48,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 21),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 14),
            const SizedBox(width: 5),
            Text(
              'Dinas Sosial Kota Surabaya',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475467),
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _kartuInformasi(),
                  const SizedBox(height: 9),
                  _kartuLokasi(),
                  const SizedBox(height: 9),
                  _kartuDokumentasi(foto),
                  const SizedBox(height: 9),
                  _kartuDeteksi(),
                ],
              ),
            ),
          ),

          // TOMBOL PROSES VERIFIKASI
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              color: _latar,
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: temuan.sudahDiproses
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VerifikasiScreen(temuan: temuan),
                            ),
                          );
                        },
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: Text(
                    temuan.sudahDiproses
                        ? 'Temuan Sudah Diproses'
                        : 'Proses Verifikasi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _biru,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KARTU INFORMASI TEMUAN
  // ============================================================
  Widget _kartuInformasi() {
    return _kartu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _teksKecil('ID Temuan'),
              const SizedBox(width: 5),
              Text(
                '#${temuan.id}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _biru,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: _warnaStatus(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 11,
                      color: _warnaTeksStatus(),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _labelStatus(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: _warnaTeksStatus(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _teksKecil('Jenis Permasalahan'),
          const SizedBox(height: 3),
          Text(
            temuan.jenis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 13, color: _biru),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    temuan.deskripsi?.trim().isNotEmpty == true
                        ? temuan.deskripsi!
                        : 'Deskripsi permasalahan tidak tersedia.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      height: 1.4,
                      color: _teks,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KARTU LOKASI LAPORAN
  // ============================================================
  Widget _kartuLokasi() {
    final urlPeta = _urlPeta();

    return _kartu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _judulBagian(Icons.location_on_outlined, 'Lokasi Laporan'),
          const SizedBox(height: 10),
          Text(
            temuan.lokasi,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: _teks,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '📍 Latitude : ${_koordinat(temuan.latitude)} | '
            'Longitude: ${_koordinat(temuan.longitude)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: _abu,
            ),
          ),
          const SizedBox(height: 9),

          // PETA LOKASI
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 112,
              width: double.infinity,
              child: urlPeta.isEmpty
                  ? _petaTidakTersedia()
                  : Image.network(
                      urlPeta,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return _petaTidakTersedia(pesan: 'Memuat peta...');
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return _petaTidakTersedia();
                      },
                    ),
            ),
          ),

          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.near_me, size: 12, color: _biru),
              const SizedBox(width: 4),
              Text(
                'Titik Penyeberangan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _teks,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _barisWaktu(
            Icons.access_time,
            'Waktu Temuan',
            _tanggalWib(temuan.waktu),
          ),
        ],
      ),
    );
  }

  Widget _petaTidakTersedia({String pesan = 'Peta tidak tersedia'}) {
    return Container(
      color: const Color(0xFFE8EDF1),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, color: _abu, size: 25),
          const SizedBox(height: 4),
          Text(
            pesan,
            style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _abu),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KARTU DOKUMENTASI LAPANGAN
  // ============================================================
  Widget _kartuDokumentasi(String? foto) {
    return _kartu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _judulBagian(Icons.photo_outlined, 'Dokumentasi Lapangan'),
              const Spacer(),
              Text(
                'ID: #${temuan.id}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: _abu,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: double.infinity,
              height: 125,
              child: foto == null
                  ? _dokumentasiKosong()
                  : Image.network(
                      foto,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _dokumentasiKosong();
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dokumentasiKosong() {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.hide_image_outlined,
            size: 28,
            color: Color(0xFF667085),
          ),
          const SizedBox(height: 8),
          Text(
            'Dokumentasi Tidak Tersedia',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _teks,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Laporan ini terekam via sistem telemetri AI '
            'tanpa lampiran tangkapan kamera eksternal.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8,
              height: 1.4,
              color: _abu,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KARTU DETEKSI TERKAIT
  // Nilai yang belum tersedia dari database ditampilkan sebagai '-'.
  // ============================================================
  Widget _kartuDeteksi() {
    final akurasi = temuan.akurasi == null
        ? '-'
        : '${temuan.akurasi!.toStringAsFixed(2).replaceAll('.', ',')}%';
    final tingkatBahaya = temuan.tingkat ?? '-';

    return _kartu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _judulBagian(Icons.remove_red_eye_outlined, 'Deteksi Terkait'),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _kotakDeteksi(
                  'Jenis Objek',
                  '-',
                  Icons.do_not_disturb_on,
                  const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _kotakDeteksi(
                  'Tingkat Bahaya',
                  tingkatBahaya,
                  Icons.warning_amber_rounded,
                  const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _kotakDeteksi(
                  'Akurasi Deteksi',
                  akurasi,
                  Icons.verified_rounded,
                  const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _kotakDeteksi(
                  'Waktu Deteksi',
                  '-',
                  Icons.access_time,
                  const Color(0xFF475467),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _barisWaktu(Icons.auto_awesome, 'Waktu Lengkap Deteksi', '-'),
        ],
      ),
    );
  }

  Widget _kotakDeteksi(String judul, String nilai, IconData ikon, Color warna) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: _abu,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(ikon, size: 12, color: warna),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  nilai,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _teks,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KOMPONEN BANTUAN
  // ============================================================
  Widget _kartu({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _judulBagian(IconData ikon, String judul) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 14, color: _biru),
        const SizedBox(width: 6),
        Text(
          judul,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF101828),
          ),
        ),
      ],
    );
  }

  Widget _teksKecil(String teks) {
    return Text(
      teks,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: _abu,
      ),
    );
  }

  Widget _barisWaktu(IconData ikon, String judul, String nilai) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(ikon, size: 12, color: _abu),
          const SizedBox(width: 5),
          Text(
            judul,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: _abu,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              nilai,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: _teks,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
