import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<int> siapkanPengguna() async {

    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }

    final uid = client.auth.currentUser!.id;

    final pengguna = await client
        .from('pengguna')
        .select('id_pengguna')
        .eq('auth_user_id', uid)
        .maybeSingle();

    if (pengguna != null) {
      final id = pengguna['id_pengguna'] as int;
      await _pastikanPengaturan(id);
      return id;
    }

    final penggunaBaru = await client
        .from('pengguna')
        .insert({'auth_user_id': uid})
        .select('id_pengguna')
        .single();

    final id = penggunaBaru['id_pengguna'] as int;

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

  // ==========================================
  // STATISTIK & DATA TEMUAN (Feature 8.b)
  // ==========================================

  /// Ambil statistik temuan: total, terverifikasi, belum diverkezi.
  static Future<Map<String, int>> hitungStatistikTemuan() async {
    // Menggunakan .select() biasa lalu menghitung length dari hasilnya.
    // Untuk tabel besar, pastikan indeks di Supabase (status, waktu) untuk performa.
    final totalRespon = await client.from('temuan').select('id');
    final verifiedRespon = await client
        .from('temuan')
        .select('id')
        .eq('status', 'terverifikasi');
    final unverifiedRespon = await client
        .from('temuan')
        .select('id')
        .eq('status', 'belum_diverifikasi');

    int total = 0, terverifikasi = 0, belumDiverifikasi = 0;

    // Ekstraksi length dari list yang dikembalikan
    if (totalRespon is List) {
      total = totalRespon.length;
    }
    if (verifiedRespon is List) {
      terverifikasi = verifiedRespon.length;
    }
    if (unverifiedRespon is List) {
      belumDiverifikasi = unverifiedRespon.length;
    }

    return {
      'total': total,
      'terverifikasi': terverifikasi,
      'belum_diverifikasi': belumDiverifikasi,
    };
  }

  /// Ambil daftar temuan terbaru (default 5 data).
  static Future<List<Map<String, dynamic>>> ambilTemuanTerbaru({
    int limit = 5,
  }) async {
    final respon = await client
        .from('temuan')
        .select('id, jenis, status, waktu, lokasi')
        .order('waktu', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(respon);
  }

  /// Ambil semua temuan (untuk daftar lengkap admin).
  static Future<List<Map<String, dynamic>>> ambilSemuaTemuan() async {
    final respon = await client
        .from('temuan')
        .select('id, jenis, status, waktu, lokasi, latitude, longitude')
        .order('waktu', ascending: false);

    return List<Map<String, dynamic>>.from(respon);
  }
}