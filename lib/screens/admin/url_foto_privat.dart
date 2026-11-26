import 'package:flutter/foundation.dart';

import '../../services/supabase_service.dart';

/// Pembuat URL sementara (signed URL) untuk foto dokumentasi temuan.
///
/// Bucket `dokumentasi-temuan` bersifat privat, sehingga foto hanya bisa
/// ditampilkan lewat signed URL (bukan getPublicUrl). Hasilnya disimpan di
/// cache selama 50 menit agar tidak membuat URL berulang-ulang.
class UrlFotoPrivat {
  UrlFotoPrivat._();

  /// Nama bucket foto dokumentasi.
  /// Samakan dengan `_bucketDokumentasi` di hapus_screen.dart.
  static const String bucket = 'dokumentasi-temuan';

  static final Map<String, Future<String?>> _cache = {};
  static final Map<String, DateTime> _dibuat = {};

  static Future<String?> ambil(String? dokumentasi) {
    final path = dokumentasi?.trim() ?? '';
    if (path.isEmpty) return Future<String?>.value(null);

    if (path.startsWith('https://') || path.startsWith('http://')) {
      return Future<String?>.value(path);
    }

    final sekarang = DateTime.now();
    final waktuCache = _dibuat[path];
    final urlTersimpan = _cache[path];
    if (waktuCache != null &&
        urlTersimpan != null &&
        sekarang.difference(waktuCache) < const Duration(minutes: 50)) {
      return urlTersimpan;
    }

    final future = SupabaseService.client.storage
        .from(bucket)
        .createSignedUrl(path, 3600)
        .then<String?>((url) => url)
        .catchError((Object error) {
          debugPrint('NETRA FOTO - Gagal membuat signed URL: $error');
          _cache.remove(path);
          _dibuat.remove(path);
          return null;
        });

    _cache[path] = future;
    _dibuat[path] = sekarang;
    return future;
  }
}