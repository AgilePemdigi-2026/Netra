import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:vibration/vibration.dart';

import '../../services/detection_service.dart';
import '../../services/location_service.dart';

class KameraScreen extends StatefulWidget {
  const KameraScreen({super.key});

  @override
  State<KameraScreen> createState() => _KameraScreenState();
}

class _KameraScreenState extends State<KameraScreen> {
  static const String _model = 'yolo26n';
  static const String _petunjukSuara =
      ' Tekan tombol mikrofon lalu ucapkan perintah.';

  // Tinggi area bawah saat perjalanan dijeda (tombol + panel suara).
  // 48 (Ya) + 10 + 46 (Tidak) + 10 + 58 (panel suara)
  static const double _tinggiAreaBawahJeda = 172;

  final DetectionService _deteksi = DetectionService();
  final LocationService _lokasiService = LocationService();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _voiceAktif = true;
  bool _getarAktif = true;
  bool _ttsSiap = false;
  bool _konfirmasiTerbuka = false; // true = perjalanan dijeda
  bool _mendengarkan = false;
  bool _speechSiap = false;
  String _statusSuara = _petunjukSuara;

  String _pesanNetra = 'Arahkan kamera ke lingkungan sekitar.';
  String _confidence = '';
  String _objekTerakhir = '';
  int _jumlahObjek = 0;
  int _totalRintangan = 0;

  String _namaJalan = 'Mencari lokasi...';
  String _detailLokasi = 'Menunggu sinyal GPS';
  String? _kesalahanLokasi;
  bool _mencariAlamat = false;

  Position? _posisiTerakhir;
  Position? _posisiAlamat;
  double _jarakMeter = 0;

  StreamSubscription<Position>? _langgananGPS;
  Timer? _timer;

  late final DateTime _mulaiPerjalanan;
  Duration _durasi = Duration.zero;

  DateTime _waktuUI = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _waktuSuara = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _waktuAlamat = DateTime.fromMillisecondsSinceEpoch(0);

  String _objekDiucapkan = '';

  @override
  void initState() {
    super.initState();

    _mulaiPerjalanan = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        _durasi = DateTime.now().difference(_mulaiPerjalanan);
      });
    });

    _siapkanSuara();
    _siapkanPengenalanSuara();
    _aktifkanGPS();
  }

  Future<void> _siapkanSuara() async {
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);

      if (mounted) _ttsSiap = true;
    } catch (e) {
      debugPrint('NETRA TTS: $e');
    }
  }

  Future<void> _siapkanPengenalanSuara() async {
    try {
      _speechSiap = await _speech.initialize(
        onStatus: (status) {
          if (!mounted || !_konfirmasiTerbuka) return;
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
          debugPrint('NETRA speech: ${error.errorMsg}');
          if (mounted && _konfirmasiTerbuka) {
            setState(() {
              _mendengarkan = false;
              _statusSuara = 'Suara belum dikenali. Coba lagi.';
            });
          }
        },
      );
    } catch (e) {
      debugPrint('NETRA speech init: $e');
      _speechSiap = false;
    }
  }

  Future<void> _aktifkanGPS() async {
    await _langgananGPS?.cancel();
    _langgananGPS = null;

    if (!mounted) return;

    setState(() {
      _kesalahanLokasi = null;
      _namaJalan = 'Mencari lokasi...';
      _detailLokasi = 'Menunggu sinyal GPS';
    });

    try {
      await _lokasiService.mintaIzinLokasi();

      final posisi = await _lokasiService.posisiSekarang();

      if (!mounted) return;

      _terimaPosisi(posisi);

      _langgananGPS = _lokasiService.pantauPosisi().listen(
        _terimaPosisi,
        onError: (Object error) {
          if (!mounted) return;

          setState(() {
            _kesalahanLokasi = error.toString();
            _detailLokasi = 'Pemantauan GPS terganggu';
          });
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _namaJalan = 'Lokasi belum tersedia';
        _detailLokasi = 'Ketuk kartu untuk mencoba kembali';
        _kesalahanLokasi = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _terimaPosisi(Position posisi) {
    if (!mounted) return;

    // Penyaringan sederhana agar GPS yang meleset
    // tidak langsung dihitung sebagai jarak berjalan.
    final akurasiLayak = posisi.accuracy.isFinite && posisi.accuracy <= 25;

    if (_posisiTerakhir != null && akurasiLayak) {
      final sebelumnya = _posisiTerakhir!;

      final jarak = _lokasiService.jarakMeter(sebelumnya, posisi);

      final selisihWaktu = posisi.timestamp.difference(sebelumnya.timestamp);
      final detik = selisihWaktu.inMilliseconds / 1000.0;

      // Hanya menghitung gerakan yang cukup besar,
      // masuk akal untuk berjalan, dan GPS cukup akurat.
      if (sebelumnya.accuracy <= 25 &&
          jarak >= 5 &&
          detik > 0 &&
          (jarak / detik) <= 3.0) {
        _jarakMeter += jarak;
        _posisiTerakhir = posisi;
      } else if (jarak < 5) {
        // Abaikan pergeseran kecil GPS.
      } else if (jarak >= 5 && detik > 0 && (jarak / detik) <= 3.0) {
        _posisiTerakhir = posisi;
      }
    } else if (_posisiTerakhir == null && akurasiLayak) {
      _posisiTerakhir = posisi;
    }

    final koordinat =
        '${posisi.latitude.toStringAsFixed(5)}, '
        '${posisi.longitude.toStringAsFixed(5)}';

    setState(() {
      _kesalahanLokasi = null;

      if (_namaJalan == 'Mencari lokasi...' ||
          _namaJalan == 'Lokasi belum tersedia') {
        _namaJalan = 'Lokasi GPS ditemukan';
        _detailLokasi = koordinat;
      }
    });

    _perbaruiAlamat(posisi);
  }

  Future<void> _perbaruiAlamat(Position posisi) async {
    if (_mencariAlamat || !mounted) return;

    final sekarang = DateTime.now();

    if (_posisiAlamat != null) {
      final perpindahan = _lokasiService.jarakMeter(_posisiAlamat!, posisi);

      if (perpindahan < 40) return;

      if (sekarang.difference(_waktuAlamat).inSeconds < 45) {
        return;
      }
    }

    _mencariAlamat = true;
    _waktuAlamat = sekarang;

    try {
      final alamat = await _lokasiService.cariAlamat(posisi);

      if (!mounted) return;

      setState(() {
        _namaJalan = alamat.namaJalan;
        _detailLokasi = alamat.detailAlamat.isNotEmpty
            ? alamat.detailAlamat
            : 'Lokasi GPS aktif';
        _posisiAlamat = posisi;
      });
    } catch (e) {
      debugPrint('NETRA geocoding: $e');

      // Koordinat tetap ditampilkan jika alamat gagal.
      if (mounted && _posisiAlamat == null) {
        setState(() {
          _namaJalan = 'Lokasi GPS ditemukan';
          _detailLokasi =
              '${posisi.latitude.toStringAsFixed(5)}, '
              '${posisi.longitude.toStringAsFixed(5)}';
        });
      }
    } finally {
      _mencariAlamat = false;
    }
  }

  String _namaIndonesia(String nama) {
    const tambahan = <String, String>{
      'laptop': 'Laptop',
      'cell phone': 'Telepon genggam',
      'backpack': 'Tas punggung',
      'handbag': 'Tas',
      'bottle': 'Botol',
      'dining table': 'Meja',
      'tv': 'Televisi',
      'potted plant': 'Tanaman',
    };

    return tambahan[nama.toLowerCase()] ?? _deteksi.namaObjekIndonesia(nama);
  }

  void _prosesDeteksi(List<YOLOResult> results) {
    // Saat perjalanan dijeda, abaikan seluruh hasil YOLO.
    if (!mounted || _konfirmasiTerbuka) return;

    final sekarang = DateTime.now();

    final valid = results.where((hasil) => hasil.confidence >= 0.50).toList();

    valid.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Setiap temuan baru dihitung sebagai 1 rintangan (dengan jeda waktu),
    // suara tidak diulang terus pada setiap frame.
    if (valid.isNotEmpty) {
      final nama = _namaIndonesia(valid.first.className);

      final objekBerubah = nama != _objekDiucapkan;
      final jeda = objekBerubah ? 8 : 18;

      if (sekarang.difference(_waktuSuara).inSeconds >= jeda) {
        _waktuSuara = sekarang;
        _objekDiucapkan = nama;
        _totalRintangan++;

        if (_voiceAktif && _ttsSiap) {
          _ucapkanDeteksi(nama);
        }
      }
    }

    if (sekarang.difference(_waktuUI).inMilliseconds < 400) {
      return;
    }

    _waktuUI = sekarang;

    if (valid.isEmpty) {
      setState(() {
        _objekTerakhir = '';
        _confidence = '';
        _jumlahObjek = 0;
        _pesanNetra = 'Belum ada objek terdeteksi.';
      });
      return;
    }

    final utama = valid.first;
    final nama = _namaIndonesia(utama.className);

    setState(() {
      _objekTerakhir = nama;
      _confidence = '${(utama.confidence * 100).toStringAsFixed(1)}%';
      _jumlahObjek = valid.length;
      _pesanNetra = 'Terdeteksi $nama di area kamera.';
    });
  }

  Future<void> _ucapkanDeteksi(String nama) async {
    if (!_voiceAktif || !_ttsSiap || !mounted) return;

    try {
      await _tts.stop();

      if (!_voiceAktif || !mounted) return;

      await _tts.speak('NETRA mendeteksi $nama.');

      if (_getarAktif && mounted) {
        if (await Vibration.hasVibrator() == true) {
          if (mounted && _getarAktif) {
            await Vibration.vibrate(duration: 100);
          }
        }
      }
    } catch (e) {
      debugPrint('NETRA feedback: $e');
    }
  }

  Future<void> _ubahVoice() async {
    setState(() {
      _voiceAktif = !_voiceAktif;
    });

    if (!_voiceAktif) {
      await _tts.stop();
    } else {
      _waktuSuara = DateTime.now();
    }
  }

  void _ubahGetar() {
    setState(() {
      _getarAktif = !_getarAktif;
    });
  }

  String get _durasiTeks {
    final jam = _durasi.inHours;
    final menit = _durasi.inMinutes.remainder(60);
    final detik = _durasi.inSeconds.remainder(60);

    if (jam > 0) {
      return '${jam.toString().padLeft(2, '0')}:'
          '${menit.toString().padLeft(2, '0')}:'
          '${detik.toString().padLeft(2, '0')}';
    }

    return '${menit.toString().padLeft(2, '0')}:'
        '${detik.toString().padLeft(2, '0')}';
  }

  String get _jarakTeks {
    if (_jarakMeter >= 1000) {
      return '${(_jarakMeter / 1000).toStringAsFixed(2)} km';
    }

    return '${_jarakMeter.toStringAsFixed(0)} meter';
  }

  // ---------------------------------------------------------------------------
  // ALUR JEDA / KONFIRMASI AKHIRI PERJALANAN
  // ---------------------------------------------------------------------------

  Future<void> _akhiriPerjalanan() async {
    if (_konfirmasiTerbuka) return;

    // Jeda: hentikan suara dan bekukan hasil deteksi.
    await _tts.stop();
    await _speech.stop();
    if (!mounted) return;

    setState(() {
      _konfirmasiTerbuka = true;
      _mendengarkan = false;
      _statusSuara = _petunjukSuara;
    });
  }

  Future<void> _lanjutkanPerjalanan() async {
    await _speech.stop();
    if (!mounted) return;

    setState(() {
      _konfirmasiTerbuka = false;
      _mendengarkan = false;
      _statusSuara = _petunjukSuara;
    });

    _waktuSuara = DateTime.now();
  }

  Future<void> _selesaikanPerjalanan() async {
    await _speech.stop();

    // TODO: nanti ganti Navigator.pop dengan halaman Ringkasan Temuan Aksesibilitas.
    _voiceAktif = false;
    await _tts.stop();
    _timer?.cancel();
    await _langgananGPS?.cancel();
    _langgananGPS = null;

    if (!mounted) return;
    Navigator.of(context).pop(); // Untuk sekarang kembali ke beranda.
  }

  Future<void> _tekanUntukBerbicara() async {
    if (!_speechSiap) {
      await _siapkanPengenalanSuara();
    }

    if (!mounted) return;

    if (!_speechSiap) {
      setState(() {
        _statusSuara =
            'Pengenalan suara tidak tersedia. Gunakan tombol di atas.';
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

    setState(() {
      _mendengarkan = true;
      _statusSuara = 'Mendengarkan...';
    });

    await _speech.listen(
      localeId: 'id_ID',
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) async {
        if (!mounted || !_konfirmasiTerbuka) return;

        final kata = result.recognizedWords.toLowerCase().trim();
        if (kata.isEmpty) return;

        setState(() => _statusSuara = 'Terdengar: $kata');

        if (!result.finalResult) return;

        // "Tidak" dicek lebih dulu supaya kalimat seperti
        // "tidak mau mengakhiri" tidak terbaca sebagai "iya".
        final tidak =
            kata.contains('tidak') ||
            kata.contains('enggak') ||
            kata.contains('engga') ||
            kata.contains('nggak') ||
            kata.contains('lanjut');

        final iya =
            kata == 'iya' ||
            kata == 'ya' ||
            kata.startsWith('iya ') ||
            kata.startsWith('ya ') ||
            kata.contains('sudah sampai') ||
            kata.contains('akhiri') ||
            kata.contains('mengakhiri');

        if (tidak) {
          await _lanjutkanPerjalanan();
        } else if (iya) {
          await _selesaikanPerjalanan();
        } else {
          setState(() {
            _mendengarkan = false;
            _statusSuara = 'Ucapkan “Iya” atau “Tidak”';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _langgananGPS?.cancel();
    _speech.stop();
    _voiceAktif = false;
    _tts.stop();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final jeda = _konfirmasiTerbuka;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  // STATUS DAN PENGATURAN
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 9,
                              color: jeda
                                  ? const Color(0xFFC9161D)
                                  : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              jeda ? 'Perjalanan Dijeda' : 'Perjalanan Aktif',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _chipToggle(
                        icon: _voiceAktif
                            ? Icons.volume_up_outlined
                            : Icons.volume_off_outlined,
                        teks: 'Voice',
                        aktif: _voiceAktif,
                        ditekan: _ubahVoice,
                      ),
                      const SizedBox(width: 6),
                      _chipToggle(
                        icon: Icons.vibration,
                        teks: 'Getar',
                        aktif: _getarAktif,
                        ditekan: _ubahGetar,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // KAMERA YOLO
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: YOLOView(
                              modelPath: _model,
                              onResult: _prosesDeteksi,
                            ),
                          ),

                          if (jeda) ...[
                            // LAPISAN GELAP SAAT DIJEDA
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.45),
                                ),
                              ),
                            ),

                            // PIL "KAMERA DETEKSI DIJEDA"
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xE6292D32),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFC9161D),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.pause,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      'Kamera Deteksi Dijeda',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            // BANNER SUARA
                            Positioned(
                              left: 10,
                              right: 10,
                              top: 10,
                              child: Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: const Color(0xE6292D32),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.record_voice_over_outlined,
                                      color: Color(0xFF4ADE80),
                                      size: 17,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _voiceAktif
                                                ? 'SUARA NETRA'
                                                : 'SUARA DINONAKTIFKAN',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF4ADE80),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _pesanNetra,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (_confidence.isNotEmpty)
                                            Text(
                                              '$_objekTerakhir • $_confidence',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white70,
                                                fontSize: 10,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // INFORMASI KAMERA
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xD9292D32),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.videocam_outlined,
                                      color: Color(0xFF4ADE80),
                                      size: 17,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _jumlahObjek == 0
                                            ? 'Kamera AI aktif. Arahkan ke depan.'
                                            : '$_jumlahObjek objek terdeteksi oleh AI.',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (!jeda) ...[
                    const SizedBox(height: 10),

                    // KARTU LOKASI ASLI
                    InkWell(
                      onTap: () {
                        if (_kesalahanLokasi != null) {
                          _aktifkanGPS();
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9EDFF),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFF4269ED),
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LOKASI SEKARANG',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: const Color(0xFF8290A5),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _namaJalan,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF253047),
                                    ),
                                  ),
                                  Text(
                                    _kesalahanLokasi ?? _detailLokasi,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: _kesalahanLokasi == null
                                          ? const Color(0xFF758195)
                                          : const Color(0xFFC9161D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_kesalahanLokasi != null)
                              const Icon(
                                Icons.refresh,
                                color: Color(0xFF4269ED),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 9),

                    // JARAK DAN DURASI
                    Row(
                      children: [
                        Expanded(
                          child: _kartuStatistik(
                            ikon: Icons.route_outlined,
                            judul: 'Jarak Tempuh',
                            nilai: _jarakTeks,
                            warna: const Color(0xFF526079),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _kartuStatistik(
                            ikon: Icons.timer_outlined,
                            judul: 'Durasi Navigasi',
                            nilai: _durasiTeks,
                            warna: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // AKHIRI PERJALANAN
                    SizedBox(
                      width: double.infinity,
                      height: 51,
                      child: ElevatedButton.icon(
                        onPressed: _akhiriPerjalanan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC9161D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.stop_circle_outlined, size: 19),
                        label: Text(
                          'Akhiri Perjalanan',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    _areaBawahJeda(),
                ],
              ),
            ),

            // KARTU KONFIRMASI (melayang di atas kamera, tepat di atas tombol)
            if (jeda)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SingleChildScrollView(
                          reverse: true,
                          child: _kartuKonfirmasi(),
                        ),
                      ),
                    ),
                    const SizedBox(height: _tinggiAreaBawahJeda + 27),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KOMPONEN KONFIRMASI
  // ---------------------------------------------------------------------------

  Widget _kartuKonfirmasi() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // IKON TANDA TANYA
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD9D9),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFC9161D),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '?',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // CHIP SUARA AKTIF
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
                  size: 12,
                  color: Color(0xFF2149B8),
                ),
                const SizedBox(width: 5),
                Text(
                  'Suara Aktif',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF2149B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // JUDUL
          Text(
            'Apakah Anda ingin mengakhiri perjalanan?',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF14171F),
            ),
          ),

          const SizedBox(height: 10),

          // DESKRIPSI
          Text(
            'Sistem akan merangkum seluruh temuan rintangan aksesibilitas yang terdeteksi selama perjalanan ini untuk laporan Dinas Sosial Kota Surabaya.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              height: 1.5,
              color: const Color(0xFF5F6675),
            ),
          ),

          const SizedBox(height: 16),

          // DATA TERKUMPUL
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF244CC5),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Terkumpul',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14171F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_totalRintangan Rintangan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: const Color(0xFF5F6675),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaBawahJeda() {
    return SizedBox(
      height: _tinggiAreaBawahJeda + 27,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // YA, AKHIRI
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _selesaikanPerjalanan,
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              label: Text(
                'Ya, Akhiri',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4BDB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // TIDAK, LANJUTKAN
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _lanjutkanPerjalanan,
              icon: const Icon(Icons.play_arrow_outlined, size: 20),
              label: Text(
                'Tidak, Lanjutkan',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE9EBF0),
                foregroundColor: const Color(0xFF1B2230),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // PANEL TEKAN UNTUK BERBICARA
          GestureDetector(
            onTap: _tekanUntukBerbicara,
            child: Container(
              width: double.infinity,
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E24),
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
                            color: const Color(0xFF9DB7FF),
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
                            fontSize: 10.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KOMPONEN UMUM
  // ---------------------------------------------------------------------------

  Widget _chipToggle({
    required IconData icon,
    required String teks,
    required bool aktif,
    required VoidCallback ditekan,
  }) {
    return InkWell(
      onTap: ditekan,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? Colors.white : const Color(0xFFE7EAF0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: aktif ? const Color(0xFF334155) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Text(
              teks,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: aktif
                    ? const Color(0xFF334155)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuStatistik({
    required IconData ikon,
    required String judul,
    required String nilai,
    required Color warna,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: warna.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(ikon, size: 15, color: warna),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: const Color(0xFF788399),
                  ),
                ),
                Text(
                  nilai,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF263144),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
