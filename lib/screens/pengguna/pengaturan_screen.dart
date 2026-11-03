import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  final FlutterTts _tts = FlutterTts();

  String _bahasa = 'id-ID';
  double _kecepatan = 0.5;
  int _intensitasGetaran = 2;

  bool _sedangMemuat = true;
  bool _sedangMenyimpan = false;

  @override
  void initState() {
    super.initState();
    _inisialisasi();
  }

  Future<void> _inisialisasi() async {
    try {
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      final voices = await _tts.getVoices;
      debugPrint('NETRA AVAILABLE VOICES: $voices');
      await _tts.awaitSpeakCompletion(true);

      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _bahasa = prefs.getString('netra_bahasa') ?? 'id-ID';
        _kecepatan = (prefs.getDouble('netra_kecepatan') ?? 0.5)
            .clamp(0.1, 1.0)
            .toDouble();
        _intensitasGetaran = (prefs.getInt('netra_intensitas_getaran') ?? 2)
            .clamp(1, 3);
        _sedangMemuat = false;
      });

      await _terapkanPengaturanSuara();
    } catch (e) {
      debugPrint('NETRA pengaturan: $e');
      if (mounted) {
        setState(() => _sedangMemuat = false);
      }
    }
  }

  Future<void> _terapkanPengaturanSuara() async {
    try {
      await _tts.setLanguage(_bahasa);
      await _tts.setSpeechRate(_kecepatan);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('NETRA TTS: $e');
    }
  }

  Future<void> _simpanPengaturan() async {
    setState(() => _sedangMenyimpan = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('netra_bahasa', _bahasa);
      await prefs.setDouble('netra_kecepatan', _kecepatan);
      await prefs.setInt('netra_intensitas_getaran', _intensitasGetaran);

      await _terapkanPengaturanSuara();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan berhasil disimpan.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan pengaturan: $e')));
    } finally {
      if (mounted) {
        setState(() => _sedangMenyimpan = false);
      }
    }
  }

  Future<void> _ujiSuara() async {
    try {
      await _terapkanPengaturanSuara();
      await _tts.stop();

      final teks = _bahasa == 'en-US'
          ? 'Nay-tra voice test. Voice settings are working.'
          : 'Tes suara NETRA. Pengaturan suara berhasil digunakan.';

      await _tts.speak(teks);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menjalankan tes suara: $e')),
      );
    }
  }

  Future<void> _ujiGetaran() async {
    try {
      final tersedia = await Vibration.hasVibrator();

      if (!tersedia) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perangkat tidak mendukung getaran.')),
        );
        return;
      }

      const durasi = <int, int>{1: 150, 2: 300, 3: 500};

      const amplitudo = <int, int>{1: 80, 2: 160, 3: 255};

      await Vibration.vibrate(
        duration: durasi[_intensitasGetaran] ?? 300,
        amplitude: amplitudo[_intensitasGetaran] ?? 160,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menjalankan tes getaran: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        toolbarHeight: 56,
        title: const Text(
          'Pengaturan Suara & Haptik',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFF7F8FA),
        foregroundColor: const Color(0xFF253047),
        elevation: 0,
      ),
      body: _sedangMemuat
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Column(
                  children: [
                    _bagian(
                      judul: 'Bahasa Suara',
                      deskripsi: 'Pilih bahasa suara NETRA.',
                      child: DropdownButtonFormField<String>(
                        initialValue: _bahasa,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'id-ID',
                            child: Text('Bahasa Indonesia'),
                          ),
                          DropdownMenuItem(
                            value: 'en-US',
                            child: Text('English'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _bahasa = value);
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    _bagian(
                      judul: 'Kecepatan Suara',
                      deskripsi: 'Atur kecepatan bicara NETRA.',
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Lambat'),
                              Text('${(_kecepatan * 100).round()}%'),
                              const Text('Cepat'),
                            ],
                          ),
                          Slider(
                            value: _kecepatan,
                            min: 0.1,
                            max: 1.0,
                            divisions: 9,
                            onChanged: (value) {
                              setState(() => _kecepatan = value);
                            },
                          ),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              onPressed: _ujiSuara,
                              icon: const Icon(
                                Icons.volume_up_outlined,
                                size: 19,
                              ),
                              label: const Text('Uji Suara'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _bagian(
                      judul: 'Intensitas Getaran',
                      deskripsi: 'Atur kekuatan getaran peringatan.',
                      child: Column(
                        children: [
                          RadioGroup<int>(
                            groupValue: _intensitasGetaran,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _intensitasGetaran = value);
                              }
                            },
                            child: Column(
                              children: [
                                _pilihanGetaran(1, 'Rendah'),
                                _pilihanGetaran(2, 'Sedang'),
                                _pilihanGetaran(3, 'Tinggi'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              onPressed: _ujiGetaran,
                              icon: const Icon(Icons.vibration, size: 19),
                              label: const Text('Uji Getaran'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _sedangMemuat || _sedangMenyimpan
                  ? null
                  : _simpanPengaturan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2455E8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _sedangMenyimpan
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _sedangMenyimpan ? 'Menyimpan...' : 'Simpan Pengaturan',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pilihanGetaran(int nilai, String label) {
    return RadioListTile<int>(
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: nilai,
    );
  }

  Widget _bagian({
    required String judul,
    required String deskripsi,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF253047),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            deskripsi,
            style: const TextStyle(fontSize: 12, color: Color(0xFF758195)),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
} // penutup fungsi _bagian
