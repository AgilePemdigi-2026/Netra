
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FeedbackService {
  final FlutterTts _tts = FlutterTts();

  Future<void> initialize() async {
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Tunggu sampai pembacaan selesai.
    await _tts.awaitSpeakCompletion(true);

    try {
      final voices = await _tts.getVoices;

      if (voices is List) {
        final suaraIndonesia = voices.where((voice) {
          if (voice is! Map) return false;

          final locale = (voice['locale'] ??
                  voice['lang'] ??
                  '')
              .toString()
              .toLowerCase()
              .replaceAll('_', '-');

          return locale.startsWith('id');
        }).toList();

        debugPrint(
          'Jumlah suara Indonesia: ${suaraIndonesia.length}',
        );

        if (suaraIndonesia.isNotEmpty) {
          final voice = suaraIndonesia.first as Map;

          final name = voice['name']?.toString();
          final locale = (voice['locale'] ??
                  voice['lang'])
              ?.toString();

          if (name != null && locale != null) {
            await _tts.setVoice({
              'name': name,
              'locale': locale,
            });

            debugPrint('Suara NETRA dipilih: $name');
          }
        } else {
          debugPrint(
            'Voice Indonesia belum tersedia pada browser.',
          );
        }
      }
    } catch (e) {
      debugPrint('Gagal memeriksa voice: $e');
    }
  }

  Future<void> bicara(String teks) async {
    await _tts.stop();
    await _tts.speak(teks);
  }

  Future<void> panduanPenggunaan() async {
    const panduan = '''
Selamat datang di Netra.

Netra membantu Anda mengenali
lingkungan di sekitar selama perjalanan.

Untuk memulai perjalanan,
silakan tekan tombol Mulai Perjalanan.

Arahkan kamera ponsel ke depan.

Netra akan membantu mendeteksi
objek dan potensi hambatan
yang berada di sekitar Anda.

Jika terdapat hambatan,
Netra akan memberikan informasi
melalui suara dan getaran.

Setelah perjalanan selesai,
tekan tombol Akhiri Perjalanan.

Netra akan menampilkan
ringkasan temuan perjalanan Anda.

Anda juga dapat mengirimkan
laporan temuan kepada
Dinas Sosial Kota Surabaya.

Ingat, Netra adalah alat bantu informasi.

Tetap gunakan alat bantu mobilitas
dan berhati-hati selama perjalanan.

Terima kasih telah menggunakan Netra.
''';

    await bicara(panduan);
  }

  Future<void> berhenti() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
