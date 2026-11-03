import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Satu temuan hambatan yang terdeteksi selama perjalanan.
class TemuanRintangan {
  final String jenis;
  final double confidence; // 0.0 - 1.0
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

  /// Contoh: 0.7750 -> "77,50%"
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

  late String _statusSuara;

  bool get _adaTemuan => widget.temuan.isNotEmpty;

  String get _petunjukSuara => _adaTemuan
      ? '“Ya. Kirim ke Dinas Sosial.”'
      : 'Tidak. Kembali ke beranda.”';

  @override
  void initState() {
    super.initState();
    _statusSuara = _petunjukSuara;
    _mulai();
  }

  Future<void> _mulai() async {
    await _siapkanPengenalanSuara();
    await _bacakanLaporan();
  }

  // ---------------------------------------------------------------------------
  // SUARA
  // ---------------------------------------------------------------------------

  Future<void> _siapkanSuara() async {
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ttsSiap = true;
    } catch (e) {
      debugPrint('NETRA laporan TTS: $e');
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
              if (_statusSuara == 'Mendengarkan...') {
                _statusSuara = 'Tekan untuk mencoba lagi';
              }
            });
          }
        },
        onError: (error) {
          debugPrint('NETRA laporan speech: ${error.errorMsg}');
          if (!mounted) return;
          setState(() {
            _mendengarkan = false;
            _statusSuara = 'Suara belum dikenali. Coba lagi.';
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
    await _siapkanSuara();
    if (!mounted || !_ttsSiap) return;

    final teks = StringBuffer('Laporan perjalanan. ');

    if (_adaTemuan) {
      final total = widget.temuan.length;
      final batas = total > 5 ? 5 : total;

      teks.write('Ditemukan $total temuan masalah. ');
      for (var i = 0; i < batas; i++) {
        final t = widget.temuan[i];
        teks.write('${i + 1}. ${t.jenis}, di ${t.namaJalan}. ');
      }
      if (total > batas) {
        teks.write('Dan ${total - batas} temuan lainnya. ');
      }
      teks.write(
        'Apakah Anda ingin mengirim laporan ini ke Dinas Sosial Kota Surabaya? '
        'Ucapkan ya untuk mengirim, atau tidak untuk membatalkan.',
      );
    } else {
      teks.write(
        'Tidak ditemukan hambatan. Ucapkan tidak untuk kembali ke beranda.',
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

  Future<void> _tekanUntukBerbicara() async {
    if (_mengirim) return;

    if (!_speechSiap) {
      await _siapkanPengenalanSuara();
    }
    if (!mounted) return;

    if (!_speechSiap) {
      setState(() {
        _statusSuara =
            'Pengenalan suara tidak tersedia. Gunakan tombol di layar.';
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
      _statusSuara = 'Mendengarkan...';
    });

    await _speech.listen(
      localeId: 'id_ID',
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) async {
        if (!mounted) return;

        final kata = result.recognizedWords.toLowerCase().trim();
        if (kata.isEmpty) return;

        setState(() => _statusSuara = 'Terdengar: $kata');

        if (!result.finalResult) return;

        // "Batal" dicek lebih dulu agar "tidak mau kirim" tidak terbaca "kirim".
        final batal =
            kata.contains('batal') ||
            kata.contains('tidak') ||
            kata.contains('enggak') ||
            kata.contains('nggak') ||
            kata.contains('kembali');

        final kirim =
            kata.contains('kirim') ||
            kata == 'ya' ||
            kata == 'iya' ||
            kata.startsWith('ya ') ||
            kata.startsWith('iya ');

        if (batal) {
          await _batal();
        } else if (kirim) {
          if (_adaTemuan) {
            await _kirim();
          } else {
            setState(() {
              _mendengarkan = false;
              _statusSuara = 'Tidak ada laporan untuk dikirim';
            });
          }
        } else {
          setState(() {
            _mendengarkan = false;
            _statusSuara = _adaTemuan
                ? 'Ucapkan “Kirim” atau “Tidak”'
                : 'Ucapkan “Tidak”';
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
    // Kembali ke route paling awal (beranda).
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
        const SnackBar(content: Text('Laporan gagal dikirim. Coba lagi.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _mengirim = false);
    _tampilkanBerhasil();
  }

  Future<void> _tampilkanBerhasil() async {
    const pesan =
        'Laporan temuan masalah berhasil dikirimkan ke Dinas Sosial Kota Surabaya';

    // Tidak di-await: dialog tampil sambil suara dibacakan.
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
                'Berhasil Terkirim',
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
                    'Kembali ke Beranda',
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

    // Bacakan pesan sampai selesai, lalu otomatis kembali ke beranda.
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
                ? 'Apakah Anda ingin mengirim laporan ini ke Dinas Sosial Kota Surabaya?'
                : 'Tidak Ditemukan Hambatan',
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
          // HEADER JUMLAH TEMUAN
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
    // Akurasi tinggi (>= 90%) ditandai hijau.
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
          'Batal',
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
