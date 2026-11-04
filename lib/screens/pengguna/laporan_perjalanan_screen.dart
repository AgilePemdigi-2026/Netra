
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Satu temuan hambatan yang terdeteksi selama perjalanan.
class TemuanRintangan {
  final String jenis;
  final double confidence;
  final DateTime waktu;
  final double? latitude;
  final double? longitude;
  final String namaJalan;

  const TemuanRintangan({
    required this.jenis,
    required this.confidence,
    required this.waktu,
    required this.namaJalan,
    this.latitude,
    this.longitude,
  });

  String get akurasiTeks =>
      '${(confidence * 100).toStringAsFixed(2).replaceAll('.', ',')}%';
}

class LaporanPerjalananScreen extends StatefulWidget {
  final List<TemuanRintangan> temuan;

  const LaporanPerjalananScreen({super.key, required this.temuan});

  @override
  State<LaporanPerjalananScreen> createState() =>
      _LaporanPerjalananScreenState();
}

class _LaporanPerjalananScreenState extends State<LaporanPerjalananScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _ttsSiap = false;
  bool _speechSiap = false;
  bool _mendengarkan = false;
  bool _mengirim = false;

  String _bahasa = 'id-ID';
  late String _statusSuara;

  bool get _bahasaInggris => _bahasa == 'en-US';
  bool get _adaTemuan => widget.temuan.isNotEmpty;

  String get _petunjukSuara {
    if (_bahasaInggris) {
      return _adaTemuan
          ? '“Yes, send the report.”'
          : 'Say “No” to return to the home page.';
    }

    return _adaTemuan
        ? '“Ya. Kirim laporan.”'
        : 'Ucapkan “Tidak” untuk kembali ke beranda.';
  }

  String _teks(String indonesia, String inggris) =>
      _bahasaInggris ? inggris : indonesia;

  @override
  void initState() {
    super.initState();
    _statusSuara = _petunjukSuara;
    _mulai();
  }

  Future<void> _mulai() async {
    // Ambil bahasa yang sudah disimpan dari halaman Pengaturan.
    final prefs = await SharedPreferences.getInstance();
    _bahasa = prefs.getString('netra_bahasa') ?? 'id-ID';

    if (!mounted) return;

    setState(() {
      _statusSuara = _petunjukSuara;
    });

    await _siapkanSuara();
    await _siapkanPengenalanSuara();
    await _bacakanLaporan();
  }

  // ---------------------------------------------------------------------------
  // SUARA
  // ---------------------------------------------------------------------------

  Future<void> _siapkanSuara() async {
    try {
      await _tts.setLanguage(_bahasa);
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ttsSiap = true;
    } catch (e) {
      debugPrint('NETRA laporan TTS: $e');
      _ttsSiap = false;
    }
  }

  Future<void> _siapkanPengenalanSuara() async {
    try {
      _speechSiap = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          if (status == 'notListening' && _mendengarkan) {
            setState(() {
              _mendengarkan = false;
              if (_statusSuara == 'Mendengarkan...' ||
                  _statusSuara == 'Listening...') {
                _statusSuara = _teks(
                  'Tekan untuk mencoba lagi',
                  'Tap to try again',
                );
              }
            });
          }
        },
        onError: (error) {
          debugPrint('NETRA laporan speech: ${error.errorMsg}');
          if (!mounted) return;

          setState(() {
            _mendengarkan = false;
            _statusSuara = _teks(
              'Suara belum dikenali. Coba lagi.',
              'Voice not recognized. Please try again.',
            );
          });
        },
      );
    } catch (e) {
      debugPrint('NETRA laporan speech init: $e');
      _speechSiap = false;
    }
  }

  /// Membacakan ringkasan laporan, lalu otomatis menyalakan mikrofon.
  Future<void> _bacakanLaporan() async {
    if (!mounted || !_ttsSiap) return;

    final teks = StringBuffer(
      _teks('Laporan perjalanan. ', 'Trip report. '),
    );

    if (_adaTemuan) {
      final total = widget.temuan.length;
      final batas = total > 5 ? 5 : total;

      teks.write(
        _bahasaInggris
            ? '$total accessibility obstacles were found. '
            : 'Ditemukan $total temuan masalah. ',
      );

      for (var i = 0; i < batas; i++) {
        final t = widget.temuan[i];

        teks.write(
          _bahasaInggris
              ? '${i + 1}. ${_jenisInggris(t.jenis)}, at ${t.namaJalan}. '
              : '${i + 1}. ${t.jenis}, di ${t.namaJalan}. ',
        );
      }

      if (total > batas) {
        teks.write(
          _bahasaInggris
              ? 'And ${total - batas} more findings. '
              : 'Dan ${total - batas} temuan lainnya. ',
        );
      }

      teks.write(
        _teks(
          'Apakah Anda ingin mengirim laporan ini ke Dinas Sosial Kota Surabaya? '
          'Ucapkan ya untuk mengirim, atau tidak untuk kembali ke beranda.',
          'Would you like to send this report to the Surabaya Social Services Office? '
          'Say yes to send, or no to return to the home page.',
        ),
      );
    } else {
      teks.write(
        _teks(
          'Tidak ditemukan hambatan. Ucapkan tidak untuk kembali ke beranda.',
          'No obstacles were found. Say no to return to the home page.',
        ),
      );
    }

    try {
      await _tts.speak(teks.toString());
    } catch (e) {
      debugPrint('NETRA laporan bacakan: $e');
    }

    if (!mounted || _mendengarkan || _mengirim) return;

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted && !_mendengarkan && !_mengirim) {
      _tekanUntukBerbicara();
    }
  }

  String _jenisInggris(String jenis) {
    const terjemahan = <String, String>{
      'Jalan berlubang': 'Pothole',
      'Trotoar rusak': 'Damaged sidewalk',
      'Lubang drainase terbuka': 'Open manhole',
      'Tangga': 'Stairs',
      'Tiang': 'Pole',
    };

    return terjemahan[jenis] ?? jenis;
  }

  Future<void> _tekanUntukBerbicara() async {
    if (_mengirim) return;

    if (!_speechSiap) {
      await _siapkanPengenalanSuara();
    }

    if (!mounted) return;

    if (!_speechSiap) {
      setState(() {
        _statusSuara = _teks(
          'Pengenalan suara tidak tersedia. Gunakan tombol di layar.',
          'Speech recognition is unavailable. Please use the buttons on screen.',
        );
      });
      return;
    }

    if (_mendengarkan) {
      await _speech.stop();
      if (!mounted) return;

      setState(() {
        _mendengarkan = false;
        _statusSuara = _petunjukSuara;
      });
      return;
    }

    await _tts.stop();
    if (!mounted) return;

    setState(() {
      _mendengarkan = true;
      _statusSuara = _teks('Mendengarkan...', 'Listening...');
    });

    await _speech.listen(
      localeId: _bahasaInggris ? 'en_US' : 'id_ID',
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) async {
        if (!mounted) return;

        final kata = result.recognizedWords.toLowerCase().trim();
        if (kata.isEmpty) return;

        setState(() => _statusSuara = '${_teks('Terdengar', 'Heard')}: $kata');

        if (!result.finalResult) return;

        // Perintah negatif dicek lebih dahulu.
        // Contoh: "tidak mau kirim" tidak boleh dianggap sebagai perintah kirim.
        final tidak = _bahasaInggris
            ? kata == 'no' ||
                kata.startsWith('no ') ||
                kata.contains('do not') ||
                kata.contains("don't") ||
                kata.contains('cancel') ||
                kata.contains('go back') ||
                kata.contains('return')
            : kata.contains('tidak') ||
                kata.contains('enggak') ||
                kata.contains('engga') ||
                kata.contains('nggak') ||
                kata.contains('batal') ||
                kata.contains('kembali');

        final iya = _bahasaInggris
            ? kata == 'yes' ||
                kata == 'yeah' ||
                kata == 'yep' ||
                kata.startsWith('yes ') ||
                kata.contains('send')
            : kata == 'ya' ||
                kata == 'iya' ||
                kata.startsWith('ya ') ||
                kata.startsWith('iya ') ||
                kata.contains('kirim');

        if (tidak) {
          await _batal();
        } else if (iya) {
          if (_adaTemuan) {
            await _kirim();
          } else {
            setState(() {
              _mendengarkan = false;
              _statusSuara = _teks(
                'Tidak ada laporan untuk dikirim',
                'There is no report to send',
              );
            });
          }
        } else {
          setState(() {
            _mendengarkan = false;
            _statusSuara = _adaTemuan
                ? _teks(
                    'Ucapkan “Kirim” atau “Tidak”',
                    'Say “Send” or “No”',
                  )
                : _teks(
                    'Ucapkan “Tidak”',
                    'Say “No”',
                  );
          });
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // AKSI
  // ---------------------------------------------------------------------------

  void _kembaliKeBeranda() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _batal() async {
    if (_mengirim) return;

    await _speech.stop();
    await _tts.stop();
    _kembaliKeBeranda();
  }

  Future<void> _kirim() async {
    if (!_adaTemuan || _mengirim) return;

    await _speech.stop();
    await _tts.stop();
    if (!mounted) return;

    setState(() {
      _mengirim = true;
      _mendengarkan = false;
    });

    try {
      // TODO: kirim widget.temuan ke server / Firebase / API Dinas Sosial.
      await Future.delayed(const Duration(milliseconds: 900));
    } catch (e) {
      debugPrint('NETRA kirim laporan: $e');
      if (!mounted) return;

      setState(() => _mengirim = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _teks(
              'Laporan gagal dikirim. Coba lagi.',
              'Failed to send the report. Please try again.',
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() => _mengirim = false);
    _tampilkanBerhasil();
  }

  Future<void> _tampilkanBerhasil() async {
    final pesan = _teks(
      'Laporan temuan masalah berhasil dikirimkan ke Dinas Sosial Kota Surabaya',
      'The obstacle report has been successfully sent to the Surabaya Social Services Office',
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFD9F7E3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _teks('Berhasil Terkirim', 'Successfully Sent'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF14171F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$pesan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.5,
                  color: const Color(0xFF5F6675),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4BDB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _teks('Kembali ke Beranda', 'Back to Home'),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      if (_ttsSiap) {
        await _tts.speak('$pesan.');
      } else {
        await Future.delayed(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('NETRA laporan berhasil: $e');
    }

    await Future.delayed(const Duration(milliseconds: 1200));
    _kembaliKeBeranda();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            children: [
              _kartuJudul(),
              const SizedBox(height: 10),
              Expanded(
                child: _adaTemuan
                    ? SingleChildScrollView(child: _kartuTemuan())
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              _tombolKirim(),
              const SizedBox(height: 8),
              _tombolBatal(),
              const SizedBox(height: 8),
              _panelSuara(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kartuJudul() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE4E9FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.record_voice_over,
                  size: 13,
                  color: Color(0xFF2149B8),
                ),
                const SizedBox(width: 5),
                Text(
                  'Suara Aktif',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF2149B8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Laporan Perjalanan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF383D4A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _adaTemuan
                ? _teks(
                    'Apakah Anda ingin mengirim laporan ini ke Dinas Sosial Kota Surabaya?',
                    'Would you like to send this report to the Surabaya Social Services Office?',
                  )
                : _teks(
                    'Tidak Ditemukan Hambatan',
                    'No Obstacles Found',
                  ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3E4350),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuTemuan() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.checklist_rounded,
                  size: 20,
                  color: Color(0xFF2149B8),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.temuan.length} Temuan Masalah',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2B303B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < widget.temuan.length; i++) ...[
            _itemTemuan(i + 1, widget.temuan[i]),
            if (i != widget.temuan.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _itemTemuan(int nomor, TemuanRintangan t) {
    final tinggi = t.confidence >= 0.90;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD32F2F),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$nomor. ${t.jenis}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2B303B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tinggi
                      ? const Color(0xFF86F5A0)
                      : const Color(0xFFE1E4EA),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Akurasi ${t.akurasiTeks}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: tinggi
                        ? const Color(0xFF0B3B1E)
                        : const Color(0xFF2B303B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    t.namaJalan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF5F6675),
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

  Widget _tombolKirim() {
    final aktif = _adaTemuan && !_mengirim;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: aktif ? _kirim : null,
        icon: _mengirim
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_outlined, size: 18),
        label: Text(
          _mengirim ? 'Mengirim...' : 'Kirim',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1F4BDB),
          foregroundColor: Colors.white,
          disabledBackgroundColor: _mengirim
              ? const Color(0xFF1F4BDB)
              : const Color(0xFFC9CED9),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _tombolBatal() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: _mengirim ? null : _batal,
        icon: const Icon(Icons.close, size: 18),
        label: Text(
          'Tidak',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8EAEE),
          foregroundColor: const Color(0xFF2B303B),
          disabledBackgroundColor: const Color(0xFFE8EAEE),
          disabledForegroundColor: const Color(0xFF9AA1AF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _panelSuara() {
    return GestureDetector(
      onTap: _tekanUntukBerbicara,
      child: Container(
        width: double.infinity,
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3036),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF2450D8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _mendengarkan ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mendengarkan
                        ? 'SEDANG MENDENGARKAN'
                        : 'TEKAN UNTUK BERBICARA',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFA9BCFF),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusSuara,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.3,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
