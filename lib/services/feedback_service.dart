
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackService {
  final FlutterTts _tts = FlutterTts();

  String _currentLanguage = 'id-ID';
  double _speechRate = 0.48;

  bool get isEnglish => _currentLanguage == 'en-US';

  Future<void> initialize() async {
    await _loadSettings();
    await _configureTts();
  }

  // Membaca pengaturan terbaru dari halaman Settings.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLanguage = prefs.getString('netra_bahasa') ?? 'id-ID';

    _currentLanguage =
        savedLanguage == 'en-US' ? 'en-US' : 'id-ID';

    _speechRate = (prefs.getDouble('netra_kecepatan') ?? 0.48)
        .clamp(0.1, 1.0)
        .toDouble();

    debugPrint('NETRA language: $_currentLanguage');
    debugPrint('NETRA speech rate: $_speechRate');
  }

  // Mengatur bahasa dan suara TTS.
  Future<void> _configureTts() async {
    await _tts.setLanguage(_currentLanguage);
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    try {
      final voices = await _tts.getVoices;

      if (voices is List) {
        final matchingVoices = voices.where((voice) {
          if (voice is! Map) return false;

          final locale = (voice['locale'] ?? voice['lang'] ?? '')
              .toString()
              .toLowerCase()
              .replaceAll('_', '-');

          return _currentLanguage == 'en-US'
              ? locale.startsWith('en')
              : locale.startsWith('id');
        }).toList();

        debugPrint(
          'NETRA available voices: ${matchingVoices.length}',
        );

        if (matchingVoices.isNotEmpty) {
          final voice = matchingVoices.first as Map;

          final name = voice['name']?.toString();
          final locale = (voice['locale'] ?? voice['lang'])
              ?.toString();

          if (name != null && locale != null) {
            await _tts.setVoice({
              'name': name,
              'locale': locale,
            });

            debugPrint('NETRA selected voice: $name');
          }
        }
      }
    } catch (e) {
      debugPrint('NETRA voice selection error: $e');
    }
  }

  Future<void> bicara(String teks) async {
    await _tts.stop();
    await _tts.setLanguage(_currentLanguage);
    await _tts.setSpeechRate(_speechRate);
    await _tts.speak(teks);
  }

  // Panduan penggunaan bilingual.
  Future<void> panduanPenggunaan() async {
    // Selalu ambil pengaturan terbaru sebelum berbicara.
    await _loadSettings();
    await _configureTts();

    final String panduan;

    if (isEnglish) {
      panduan = '''
Welcome to Netra.

Netra helps you recognize
your surroundings while travelling.

To start your journey,
please press the Start Journey button.

Point your phone camera forward.

Netra will help detect objects
and potential obstacles
around you.

When an obstacle is detected,
Netra will provide information
through voice guidance and vibration.

When you finish your journey,
press the End Journey button.

Netra will display
a summary of your journey findings.

You can also submit
your findings to the
Surabaya City Social Services Department.

Remember, Netra is an assistive information tool.

Continue using your mobility aids
and stay cautious during your journey.

Thank you for using Netra.
''';
    } else {
      panduan = '''
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
    }

    await bicara(panduan);
  }

  Future<void> berhenti() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
