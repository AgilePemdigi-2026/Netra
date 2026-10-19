
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
}
