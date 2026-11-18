import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // =========================================================
  // PENGGUNA DAN PENGATURAN
  // =========================================================

  static Future<int> siapkanPengguna() async {
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }

    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Sesi pengguna Supabase tidak tersedia.');
    }

    final pengguna = await client
        .from('pengguna')
        .select('id_pengguna')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (pengguna != null) {
      final id = (pengguna['id_pengguna'] as num).toInt();
      await _pastikanPengaturan(id);
      return id;
    }

    final penggunaBaru = await client
        .from('pengguna')
        .insert({'auth_user_id': user.id})
        .select('id_pengguna')
        .single();

    final id = (penggunaBaru['id_pengguna'] as num).toInt();
    await _pastikanPengaturan(id);
    return id;
  }

  static Future<void> _pastikanPengaturan(int idPengguna) async {
    final pengaturan = await client
        .from('pengaturan')
        .select('id_pengaturan')
        .eq('id_pengguna', idPengguna)
        .maybeSingle();

    if (pengaturan == null) {
      await client.from('pengaturan').insert({
        'id_pengguna': idPengguna,
        'bahasa': 'id',
        'kecepatan_bicara': 'Sedang',
        'getaran': true,
        'getaran_bahaya': true,
      });
    }
  }

  // =========================================================
  // TEMUAN - SESUAI STRUKTUR TABEL SUPABASE NETRA
  // =========================================================

  /// Mengambil semua temuan dengan nama kolom asli database.
  static Future<List<Map<String, dynamic>>> ambilSemuaTemuan({
    int limit = 1000,
  }) async {
    final data = await client
        .from('temuan')
        .select(
          'id_temuan,id_perjalanan,id_deteksi,jenis_permasalahan,'
          'lokasi_laporan,latitude,longitude,dokumentasi,deskripsi,'
          'status_tindak_lanjut,waktu_temuan,status,waktu',
        )
        .order('waktu_temuan', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Mengambil temuan terbaru untuk dashboard.
  static Future<List<Map<String, dynamic>>> ambilTemuanTerbaru({
    int limit = 5,
  }) async {
    final data = await client
        .from('temuan')
        .select(
          'id_temuan,jenis_permasalahan,status_tindak_lanjut,'
          'waktu_temuan,lokasi_laporan',
        )
        .order('waktu_temuan', ascending: false)
        .limit(limit);

    // Sertakan alias lama agar pemanggil dashboard yang masih menggunakan
    // key id/jenis/status/waktu/lokasi tidak langsung rusak.
    return data
        .map(
          (row) => <String, dynamic>{
            ...row,
            'id': row['id_temuan'],
            'jenis': row['jenis_permasalahan'],
            'status': row['status_tindak_lanjut'],
            'waktu': row['waktu_temuan'],
            'lokasi': row['lokasi_laporan'],
          },
        )
        .toList();
  }

  /// Statistik berdasarkan status_tindak_lanjut yang valid di database:
  /// menunggu_verifikasi, terverifikasi, dan ditolak.
  static Future<Map<String, int>> hitungStatistikTemuan() async {
    final data = await client
        .from('temuan')
        .select('id_temuan,status_tindak_lanjut');

    var terverifikasi = 0;
    var menunggu = 0;
    var ditolak = 0;

    for (final row in data) {
      final status = (row['status_tindak_lanjut'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      switch (status) {
        case 'terverifikasi':
          terverifikasi++;
          break;
        case 'ditolak':
          ditolak++;
          break;
        case 'menunggu_verifikasi':
          menunggu++;
          break;
        default:
          // Status kosong/tidak dikenal dihitung sebagai belum diproses,
          // agar tidak menghilangkan temuan dari total daftar.
          menunggu++;
      }
    }

    return {
      'total': data.length,
      'terverifikasi': terverifikasi,
      'belum_diverifikasi': menunggu,
      'menunggu_verifikasi': menunggu,
      'ditolak': ditolak,
    };
  }

  /// Mengambil satu temuan berdasarkan primary key id_temuan.
  static Future<Map<String, dynamic>> ambilDetailTemuan(int idTemuan) async {
    final data = await client
        .from('temuan')
        .select(
          'id_temuan,id_perjalanan,id_deteksi,jenis_permasalahan,'
          'lokasi_laporan,latitude,longitude,dokumentasi,deskripsi,'
          'status_tindak_lanjut,waktu_temuan,status,waktu',
        )
        .eq('id_temuan', idTemuan)
        .single();

    return Map<String, dynamic>.from(data);
  }

  /// Mengambil riwayat verifikasi untuk satu temuan.
  static Future<List<Map<String, dynamic>>> ambilVerifikasi(
    int idTemuan,
  ) async {
    final data = await client
        .from('verifikasi')
        .select(
          'id_verifikasi,id_temuan,id_admin,status,catatan,waktu_verifikasi',
        )
        .eq('id_temuan', idTemuan)
        .order('waktu_verifikasi', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }
}
