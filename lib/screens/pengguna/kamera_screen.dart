import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:vibration/vibration.dart';

import '../../services/detection_service.dart';
import '../../services/location_service.dart';
import 'laporan_perjalanan_screen.dart';

class KameraScreen extends StatefulWidget {
  const KameraScreen({super.key});

  @override
  State<KameraScreen> createState() => _KameraScreenState();
}

class _KameraScreenState extends State<KameraScreen> {
  static const String _model = 'yolo26n';

  static const double _tinggiAreaBawahJeda = 172;

  static const Map<String, String> _kelasRintanganIndonesia = {
    'pothole': 'Jalan berlubang',
    'damaged_sidewalk': 'Trotoar rusak',
    'open_manhole': 'Lubang drainase terbuka',
    'stairs': 'Tangga',
    'pole': 'Tiang',
  };

  static const Map<String, String> _kelasRintanganEnglish = {
    'pothole': 'Pothole',
    'damaged_sidewalk': 'Damaged sidewalk',
    'open_manhole': 'Open manhole',
    'stairs': 'Stairs',
    'pole': 'Pole',
  };

  static const Map<String, String> _objekEnglish = {
    'person': 'Person',
    'bicycle': 'Bicycle',
    'car': 'Car',
    'motorcycle': 'Motorcycle',
    'airplane': 'Airplane',
    'bus': 'Bus',
    'train': 'Train',
    'truck': 'Truck',
    'boat': 'Boat',
    'traffic light': 'Traffic light',
    'fire hydrant': 'Fire hydrant',
    'stop sign': 'Stop sign',
    'bench': 'Bench',
    'bird': 'Bird',
    'cat': 'Cat',
    'dog': 'Dog',
    'horse': 'Horse',
    'sheep': 'Sheep',
    'cow': 'Cow',
    'elephant': 'Elephant',
    'bear': 'Bear',
    'zebra': 'Zebra',
    'giraffe': 'Giraffe',
    'backpack': 'Backpack',
    'umbrella': 'Umbrella',
    'handbag': 'Handbag',
    'tie': 'Tie',
    'suitcase': 'Suitcase',
    'frisbee': 'Frisbee',
    'skis': 'Skis',
    'snowboard': 'Snowboard',
    'sports ball': 'Sports ball',
    'kite': 'Kite',
    'baseball bat': 'Baseball bat',
    'baseball glove': 'Baseball glove',
    'skateboard': 'Skateboard',
    'surfboard': 'Surfboard',
    'tennis racket': 'Tennis racket',
    'bottle': 'Bottle',
    'wine glass': 'Wine glass',
    'cup': 'Cup',
    'fork': 'Fork',
    'knife': 'Knife',
    'spoon': 'Spoon',
    'bowl': 'Bowl',
    'banana': 'Banana',
    'apple': 'Apple',
    'sandwich': 'Sandwich',
    'orange': 'Orange',
    'broccoli': 'Broccoli',
    'carrot': 'Carrot',
    'hot dog': 'Hot dog',
    'pizza': 'Pizza',
    'donut': 'Donut',
    'cake': 'Cake',
    'chair': 'Chair',
    'couch': 'Couch',
    'potted plant': 'Potted plant',
    'bed': 'Bed',
    'dining table': 'Dining table',
    'toilet': 'Toilet',
    'tv': 'Television',
    'laptop': 'Laptop',
    'mouse': 'Mouse',
    'remote': 'Remote control',
    'keyboard': 'Keyboard',
    'cell phone': 'Mobile phone',
    'microwave': 'Microwave',
    'oven': 'Oven',
    'toaster': 'Toaster',
    'sink': 'Sink',
    'refrigerator': 'Refrigerator',
    'book': 'Book',
    'clock': 'Clock',
    'vase': 'Vase',
    'scissors': 'Scissors',
    'teddy bear': 'Teddy bear',
    'hair drier': 'Hair dryer',
    'toothbrush': 'Toothbrush',
  };

  final DetectionService _deteksi = DetectionService();
  final LocationService _lokasiService = LocationService();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _voiceAktif = true;
  bool _getarAktif = true;
  bool _ttsSiap = false;
  bool _konfirmasiTerbuka = false;
  bool _sedangMengakhiri = false;
  bool _mendengarkan = false;
  bool _speechSiap = false;
  bool _pengaturanSiap = false;

  // Nilai harus sama dengan yang disimpan di Pengaturan.
  String _bahasa = 'id-ID';
  double _kecepatanSuara = 0.48;

  String get _bahasaSpeech => _bahasa == 'en-US' ? 'en_US' : 'id_ID';

  bool get _english => _bahasa == 'en-US';

  String get _petunjukSuara => _english
      ? 'Say “Yes, I have arrived” to end the journey.'
      : 'Ucapkan “Ya, aku sudah sampai” untuk mengakhiri perjalanan.';

  String _statusSuara = '';

  String _pesanNetra = 'Arahkan kamera ke lingkungan sekitar.';
  String _confidence = '';
  String _objekTerakhir = '';
  int _jumlahObjek = 0;

  int _totalRintangan = 0;
  final Map<String, DateTime> _waktuRintangan = {};
  final Map<String, Position> _posisiRintangan = {};
  final List<TemuanRintangan> _daftarTemuan = [];

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
    _statusSuara = _petunjukSuara;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        _durasi = DateTime.now().difference(_mulaiPerjalanan);
      });
    });

    _inisialisasi();
    _aktifkanGPS();
  }

  Future<void> _inisialisasi() async {
    await _muatPengaturanBahasa();

    if (!mounted) return;

    await _siapkanSuara();
    await _siapkanPengenalanSuara();
  }

  Future<void> _muatPengaturanBahasa() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bahasaTersimpan = prefs.getString('netra_bahasa') ?? 'id-ID';
      final kecepatanTersimpan =
          prefs.getDouble('netra_kecepatan') ?? 0.5;

      if (!mounted) return;

      setState(() {
        _bahasa = bahasaTersimpan == 'en-US' ? 'en-US' : 'id-ID';
        _kecepatanSuara = kecepatanTersimpan.clamp(0.1, 1.0);
        _statusSuara = _petunjukSuara;
        _pengaturanSiap = true;
      });
    } catch (e) {
      debugPrint('NETRA preferences: $e');
      _pengaturanSiap = true;
    }
  }

  Future<void> _siapkanSuara() async {
    try {
      await _tts.setLanguage(_bahasa);
      await _tts.setSpeechRate(_kecepatanSuara);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);

      if (mounted) {
        _ttsSiap = true;
      }
    } catch (e) {
      debugPrint('NETRA TTS: $e');
      _ttsSiap = false;
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
              _statusSuara = _english
                  ? 'Tap to try again'
                  : 'Tekan untuk mencoba lagi';
            });
          }
        },
        onError: (error) {
          debugPrint('NETRA speech: ${error.errorMsg}');

          if (mounted && _konfirmasiTerbuka) {
            setState(() {
              _mendengarkan = false;
              _statusSuara = _english
                  ? 'Voice not recognized. Please try again.'
                  : 'Suara belum dikenali. Coba lagi.';
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

    final akurasiLayak = posisi.accuracy.isFinite && posisi.accuracy <= 25;

    if (_posisiTerakhir != null && akurasiLayak) {
      final sebelumnya = _posisiTerakhir!;
      final jarak = _lokasiService.jarakMeter(sebelumnya, posisi);
      final selisihWaktu = posisi.timestamp.difference(sebelumnya.timestamp);
      final detik = selisihWaktu.inMilliseconds / 1000.0;

      if (sebelumnya.accuracy <= 25 &&
          jarak >= 5 &&
          detik > 0 &&
          (jarak / detik) <= 3.0) {
        _jarakMeter += jarak;
        _posisiTerakhir = posisi;
      } else if (jarak >= 5 &&
          detik > 0 &&
          (jarak / detik) <= 3.0) {
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

  String _namaObjek(String nama) {
    final kelas = nama.toLowerCase();

    if (_english) {
      return _kelasRintanganEnglish[kelas] ??
          _objekEnglish[kelas] ??
          nama;
    }

    return _kelasRintanganIndonesia[kelas] ??
        _namaIndonesia(nama);
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

    return tambahan[nama.toLowerCase()] ??
        _deteksi.namaObjekIndonesia(nama);
  }

  void _catatRintangan(
    String kelas,
    String label,
    double confidence,
  ) {
    final sekarang = DateTime.now();
    final posisi = _posisiTerakhir;

    final waktuLalu = _waktuRintangan[kelas];
    final posisiLalu = _posisiRintangan[kelas];

    if (waktuLalu != null) {
      if (sekarang.difference(waktuLalu).inSeconds < 10) return;

      if (posisi != null &&
          posisiLalu != null &&
          _lokasiService.jarakMeter(posisiLalu, posisi) < 5) {
        return;
      }
    }

    _waktuRintangan[kelas] = sekarang;
    if (posisi != null) _posisiRintangan[kelas] = posisi;

    String jalan = _namaJalan;

    if (jalan == 'Mencari lokasi...' ||
        jalan == 'Lokasi belum tersedia') {
      jalan = 'Lokasi tidak diketahui';
    } else if (jalan == 'Lokasi GPS ditemukan') {
      jalan = _detailLokasi;
    }

    _totalRintangan++;

    _daftarTemuan.add(
      TemuanRintangan(
        jenis: label,
        confidence: confidence,
        waktu: sekarang,
        namaJalan: jalan,
        latitude: posisi?.latitude,
        longitude: posisi?.longitude,
      ),
    );
  }

  void _prosesDeteksi(List<YOLOResult> results) {
    if (!mounted || _konfirmasiTerbuka) return;

    final sekarang = DateTime.now();

    final valid = results
        .where((hasil) => hasil.confidence >= 0.50)
        .toList();

    valid.sort(
      (a, b) => b.confidence.compareTo(a.confidence),
    );

    for (final hasil in valid) {
      final kelas = hasil.className.toLowerCase();

      final label = _kelasRintanganIndonesia[kelas];

      if (label != null) {
        _catatRintangan(
          kelas,
          _english ? _kelasRintanganEnglish[kelas]! : label,
          hasil.confidence,
        );
      }
    }

    if (valid.isNotEmpty && _voiceAktif && _ttsSiap) {
      final nama = _namaObjek(valid.first.className);

      final objekBerubah = nama != _objekDiucapkan;
      final jeda = objekBerubah ? 8 : 18;

      if (sekarang.difference(_waktuSuara).inSeconds >= jeda) {
        _waktuSuara = sekarang;
        _objekDiucapkan = nama;
        _ucapkanDeteksi(nama);
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
        _pesanNetra = _english
            ? 'No objects detected yet.'
            : 'Belum ada objek terdeteksi.';
      });
      return;
    }

    final utama = valid.first;
    final nama = _namaObjek(utama.className);

    setState(() {
      _objekTerakhir = nama;
      _confidence = '${(utama.confidence * 100).toStringAsFixed(1)}%';
      _jumlahObjek = valid.length;
      _pesanNetra = _english
          ? '$nama detected in the camera view.'
          : 'Terdeteksi $nama di area kamera.';
    });
  }

  Future<void> _ucapkanDeteksi(String nama) async {
    if (!_voiceAktif || !_ttsSiap || !mounted) return;

    try {
      await _tts.stop();

      if (!_voiceAktif || !mounted) return;

      final kalimat = _english
          ? 'NETRA detected $nama.'
          : 'NETRA mendeteksi $nama.';

      await _tts.speak(kalimat);

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

    return _english
        ? '${_jarakMeter.toStringAsFixed(0)} meters'
        : '${_jarakMeter.toStringAsFixed(0)} meter';
  }

  Future<void> _akhiriPerjalanan() async {
    if (_konfirmasiTerbuka) return;

    await _tts.stop();
    await _speech.stop();

    if (!mounted) return;

    setState(() {
      _konfirmasiTerbuka = true;
      _mendengarkan = false;
      _statusSuara = _petunjukSuara;
    });

    _ucapkanKonfirmasi();
  }

  Future<void> _ucapkanKonfirmasi() async {
    if (!_ttsSiap) return;

    try {
      await _tts.awaitSpeakCompletion(true);

      await _tts.speak(
        _english
            ? 'Would you like to end the journey? Please say yes or no.'
            : 'Apakah Anda ingin mengakhiri perjalanan? Ucapkan iya atau tidak.',
      );

      await _tts.awaitSpeakCompletion(false);

      if (!mounted || !_konfirmasiTerbuka || _mendengarkan) return;

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted && _konfirmasiTerbuka && !_mendengarkan) {
        _tekanUntukBerbicara();
      }
    } catch (e) {
      debugPrint('NETRA konfirmasi suara: $e');
    }
  }

  Future<void> _lanjutkanPerjalanan() async {
    await _tts.stop();
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
    if (_sedangMengakhiri) return;

    _sedangMengakhiri = true;

    await _speech.stop();

    _voiceAktif = false;
    await _tts.stop();

    _timer?.cancel();
    await _langgananGPS?.cancel();
    _langgananGPS = null;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LaporanPerjalananScreen(
          temuan: List<TemuanRintangan>.unmodifiable(_daftarTemuan),
        ),
      ),
    );
  }

  Future<void> _tekanUntukBerbicara() async {
    if (!_pengaturanSiap) {
      await _muatPengaturanBahasa();
    }

    if (!_speechSiap) {
      await _siapkanPengenalanSuara();
    }

    if (!mounted) return;

    if (!_speechSiap) {
      setState(() {
        _statusSuara = _english
            ? 'Speech recognition is unavailable. Use the buttons above.'
            : 'Pengenalan suara tidak tersedia. Gunakan tombol di atas.';
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
      _statusSuara = _english ? 'Listening...' : 'Mendengarkan...';
    });

    await _speech.listen(
      localeId: _bahasaSpeech,
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) async {
        if (!mounted || !_konfirmasiTerbuka) return;

        final kata = result.recognizedWords.toLowerCase().trim();

        if (kata.isEmpty) return;

        setState(() {
          _statusSuara = _english
              ? 'Heard: $kata'
              : 'Terdengar: $kata';
        });

        if (!result.finalResult) return;

        // Perintah penolakan diperiksa terlebih dahulu.
        final tidak = _english
            ? kata == 'no' ||
                kata.contains('no ') ||
                kata.contains('do not') ||
                kata.contains("don't") ||
                kata.contains('continue') ||
                kata.contains('keep going')
            : kata.contains('tidak') ||
                kata.contains('enggak') ||
                kata.contains('engga') ||
                kata.contains('nggak') ||
                kata.contains('lanjut');

        final iya = _english
            ? kata == 'yes' ||
                kata.startsWith('yes ') ||
                kata.contains('end the journey') ||
                kata.contains('finish the journey') ||
                kata.contains('i have arrived')
            : kata == 'iya' ||
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
            _statusSuara = _english
                ? 'Please say “Yes” or “No”.'
                : 'Ucapkan “Iya” atau “Tidak”.';
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
                              jeda
                                  ? (_english
                                      ? 'Journey Paused'
                                      : 'Perjalanan Dijeda')
                                  : (_english
                                      ? 'Journey Active'
                                      : 'Perjalanan Aktif'),
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
                        teks: _english ? 'Vibrate' : 'Getar',
                        aktif: _getarAktif,
                        ditekan: _ubahGetar,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
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
                                      _english
                                          ? 'Camera Detection Paused'
                                          : 'Kamera Deteksi Dijeda',
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
                                                ? (_english
                                                    ? 'NETRA VOICE'
                                                    : 'SUARA NETRA')
                                                : (_english
                                                    ? 'VOICE DISABLED'
                                                    : 'SUARA DINONAKTIFKAN'),
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
                                            ? (_english
                                                ? 'AI camera is active. Point it forward.'
                                                : 'Kamera AI aktif. Arahkan ke depan.')
                                            : (_english
                                                ? '$_jumlahObjek objects detected by AI.'
                                                : '$_jumlahObjek objek terdeteksi oleh AI.'),
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
                                    _english
                                        ? 'CURRENT LOCATION'
                                        : 'LOKASI SEKARANG',
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
                    Row(
                      children: [
                        Expanded(
                          child: _kartuStatistik(
                            ikon: Icons.route_outlined,
                            judul: _english ? 'Distance' : 'Jarak Tempuh',
                            nilai: _jarakTeks,
                            warna: const Color(0xFF526079),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _kartuStatistik(
                            ikon: Icons.timer_outlined,
                            judul: _english
                                ? 'Journey Duration'
                                : 'Durasi Navigasi',
                            nilai: _durasiTeks,
                            warna: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                        icon: const Icon(
                          Icons.stop_circle_outlined,
                          size: 19,
                        ),
                        label: Text(
                          _english ? 'End Journey' : 'Akhiri Perjalanan',
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
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
                  _english ? 'Voice Active' : 'Suara Aktif',
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
          Text(
            _english
                ? 'Would you like to end the journey?'
                : 'Apakah Anda ingin mengakhiri perjalanan?',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF14171F),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _english
                ? 'The system will summarize all accessibility obstacles detected during this journey for the Surabaya City Social Services report.'
                : 'Sistem akan merangkum seluruh temuan rintangan aksesibilitas yang terdeteksi selama perjalanan ini untuk laporan Dinas Sosial Kota Surabaya.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              height: 1.5,
              color: const Color(0xFF5F6675),
            ),
          ),
          const SizedBox(height: 16),
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
                        _english ? 'Collected Data' : 'Data Terkumpul',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14171F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _english
                            ? '$_totalRintangan Obstacles'
                            : '$_totalRintangan Rintangan',
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
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _selesaikanPerjalanan,
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              label: Text(
                _english ? 'Yes, End Journey' : 'Ya, Akhiri',
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
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _lanjutkanPerjalanan,
              icon: const Icon(Icons.play_arrow_outlined, size: 20),
              label: Text(
                _english ? 'No, Continue' : 'Tidak, Lanjutkan',
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
                              ? (_english
                                  ? 'LISTENING'
                                  : 'SEDANG MENDENGARKAN')
                              : (_english
                                  ? 'TAP TO SPEAK'
                                  : 'TEKAN UNTUK BERBICARA'),
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
              color: aktif
                  ? const Color(0xFF334155)
                  : const Color(0xFF94A3B8),
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