import 'dart:async';


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import '../../services/supabase_service.dart';


/// Nama bucket foto dokumentasi.
/// Samakan dengan `_Db.bucketDokumentasi` di daftar_temuan_screen.dart.
const String _bucketDokumentasi = 'dokumentasi-temuan';


/// Menghapus satu temuan yang sudah diverifikasi/ditolak.
///
/// Alur: dialog konfirmasi -> fungsi database `hapus_temuan` (menghapus temuan
/// beserta riwayat verifikasi dan tautan laporannya dalam satu transaksi)
/// -> foto di Storage ikut dihapus (jika bisa) -> pesan hasil.
///
/// [onMulai] dipanggil tepat setelah petugas menekan "Ya, Hapus", dipakai
/// untuk menampilkan indikator proses pada kartu.
///
/// Mengembalikan `true` bila temuan berhasil dihapus.
Future<bool> hapusTemuan({
  required BuildContext context,
  required int id,
  required String jenis,
  String? dokumentasi,
  VoidCallback? onMulai,
}) async {
  final yakin = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogHapusTemuan(id: id, jenis: jenis),
  );


  if (yakin != true || !context.mounted) return false;


  onMulai?.call();


  final messenger = ScaffoldMessenger.of(context);


  try {
    await SupabaseService.client
        .rpc('hapus_temuan', params: {'p_id_temuan': id})
        .timeout(const Duration(seconds: 20));
  } on PostgrestException catch (e) {
    debugPrint('Hapus temuan: ${e.code} ${e.message}');
    _tampilkanPesan(messenger, _pesanGalat(e), galat: true);
    return false;
  } catch (e) {
    debugPrint('Hapus temuan: $e');
    _tampilkanPesan(
      messenger,
      'Tidak dapat terhubung. Periksa koneksi internet lalu coba lagi.',
      galat: true,
    );
    return false;
  }


  // Foto tidak perlu ditunggu; kegagalannya tidak memengaruhi hasil.
  unawaited(_hapusFoto(dokumentasi));


  _tampilkanPesan(messenger, 'Temuan #$id berhasil dihapus.');
  return true;
}


String _pesanGalat(PostgrestException e) {
  final kode = e.code ?? '';


  if (kode == 'PGRST202' || e.message.contains('Could not find the function')) {
    return 'Fitur hapus belum aktif di database. '
        'Jalankan SQL fungsi hapus_temuan terlebih dahulu.';
  }
  if (kode == '42501') {
    return 'Akun ini tidak memiliki izin untuk menghapus temuan.';
  }
  if (kode == '23503') {
    return 'Temuan ini masih terhubung dengan data lain sehingga belum '
        'bisa dihapus.';
  }


  // Pesan dari fungsi database sudah berbahasa Indonesia.
  return 'Gagal menghapus temuan: ${e.message}';
}


void _tampilkanPesan(
  ScaffoldMessengerState messenger,
  String teks, {
  bool galat = false,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(teks),
        backgroundColor: galat ? const Color(0xFFB91C1C) : null,
      ),
    );
}


/// Menghapus file foto di Storage (best effort).
Future<void> _hapusFoto(String? dokumentasi) async {
  final dok = dokumentasi?.trim() ?? '';
  if (dok.isEmpty) return;


  var bucket = _bucketDokumentasi;
  var jalur = dok;


  if (dok.startsWith('http://') || dok.startsWith('https://')) {
    final cocok = RegExp(
      r'/storage/v1/object/(?:public|sign|authenticated)/([^/]+)/([^?]+)',
    ).firstMatch(dok);


    if (cocok == null) return;


    bucket = cocok.group(1)!;
    jalur = Uri.decodeComponent(cocok.group(2)!);
  } else {
    while (jalur.startsWith('/')) {
      jalur = jalur.substring(1);
    }
    final awalan = '$bucket/';
    if (jalur.startsWith(awalan)) {
      jalur = jalur.substring(awalan.length);
    }
  }


  try {
    await SupabaseService.client.storage.from(bucket).remove([jalur]);
  } catch (e) {
    debugPrint('Hapus temuan: foto "$bucket/$jalur" tidak ikut terhapus: $e');
  }
}


// =============================================================================
// DIALOG KONFIRMASI
// =============================================================================
class _DialogHapusTemuan extends StatelessWidget {
  final int id;
  final String jenis;


  const _DialogHapusTemuan({required this.id, required this.jenis});


  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 30,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Hapus Temuan?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$id  $jenis',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF101828),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Temuan beserta riwayat verifikasi dan foto dokumentasinya '
                'akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  height: 1.5,
                  color: const Color(0xFF475467),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8EAEE),
                          foregroundColor: const Color(0xFF1D2939),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          'Ya, Hapus',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB91C1C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



