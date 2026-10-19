
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/feedback_service.dart';
import 'kamera_screen.dart';

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  final FeedbackService _feedback = FeedbackService();

  bool _panduanAktif = false;
  bool _suaraSiap = false;

  @override
  void initState() {
    super.initState();
    _inisialisasiSuara();
  }

  // INISIALISASI SUARA
  Future<void> _inisialisasiSuara() async {
    try {
      await _feedback.initialize();

      if (!mounted) return;

      setState(() {
        _suaraSiap = true;
      });
    } catch (e) {
      debugPrint('Gagal inisialisasi suara: $e');
    }
  }

  // PANDUAN PENGGUNAAN
  Future<void> _panduanPenggunaan() async {
    if (!_suaraSiap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fitur suara belum siap.'),
        ),
      );
      return;
    }

    if (_panduanAktif) {
      setState(() {
        _panduanAktif = false;
      });

      await _feedback.berhenti();
      return;
    }

    setState(() {
      _panduanAktif = true;
    });

    try {
      await _feedback.panduanPenggunaan();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memutar panduan: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _panduanAktif = false;
        });
      }
    }
  }

  // MEMBUKA HALAMAN KAMERA
  Future<void> _mulaiPerjalanan() async {
    // Hentikan panduan suara jika masih berjalan.
    try {
      await _feedback.berhenti();
    } catch (e) {
      debugPrint('Gagal menghentikan suara: $e');
    }

    if (!mounted) return;

    setState(() {
      _panduanAktif = false;
    });

    // Membuka halaman Kamera Deteksi.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const KameraScreen(),
      ),
    );
  }

  // FITUR YANG BELUM TERSEDIA
  void _fiturBelumTersedia(String namaFitur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$namaFitur akan dikembangkan pada tahap berikutnya.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        // ========================
                        // HEADER DINAS SOSIAL
                        // ========================
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/dinsos.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              errorBuilder: (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return const Icon(
                                  Icons.account_balance,
                                  color: Color(0xFF0A3277),
                                );
                              },
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: Text(
                                'Dinas Sosial Kota Surabaya',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0A3277),
                                ),
                              ),
                            ),

                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF0A3D91),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: 'Login Admin',
                                onPressed: () {
                                  _fiturBelumTersedia(
                                    'Login Admin',
                                  );
                                },
                                icon: const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // ========================
                        // LOGO TULISAN NETRA
                        // ========================
                        Image.asset(
                          'assets/images/icon_netra.png',
                          width: 200,
                          height: 70,
                          fit: BoxFit.contain,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return Text(
                              'NETRA',
                              style: GoogleFonts.poppins(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0A3277),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // ========================
                        // DESKRIPSI APLIKASI
                        // ========================
                        Text(
                          'Sistem Pelayanan Aksesibilitas\n'
                          'Publik Berbasis AI untuk\n'
                          'Disabilitas Netra di Surabaya',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                        ),

                        const SizedBox(height: 38),

                        // ========================
                        // LOGO MATA NETRA
                        // ========================
                        Container(
                          width: 190,
                          height: 190,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF1D4ED8,
                                ).withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo_netra.png',
                            fit: BoxFit.contain,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return const Icon(
                                Icons.visibility,
                                size: 110,
                                color: Color(0xFF1D4ED8),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 55),

                        // ========================
                        // TOMBOL MULAI PERJALANAN
                        // ========================
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _mulaiPerjalanan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF2455E8),
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.accessibility_new,
                                  size: 26,
                                ),

                                const SizedBox(width: 14),

                                Expanded(
                                  child: Text(
                                    'Mulai Perjalanan',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                                const Icon(
                                  Icons.arrow_forward_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ========================
                        // PANDUAN PENGGUNAAN
                        // ========================
                        _menuButton(
                          icon: _panduanAktif
                              ? Icons.stop_circle_outlined
                              : Icons.record_voice_over_outlined,
                          label: _panduanAktif
                              ? 'Hentikan Panduan'
                              : 'Panduan Penggunaan',
                          onPressed: _panduanPenggunaan,
                        ),

                        const SizedBox(height: 14),

                        // ========================
                        // PENGATURAN SUARA & HAPTIK
                        // ========================
                        _menuButton(
                          icon: Icons.settings_outlined,
                          label: 'Pengaturan Suara & Haptik',
                          onPressed: () {
                            _fiturBelumTersedia(
                              'Pengaturan Suara & Haptik',
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ========================
  // WIDGET TOMBOL MENU
  // ========================
  Widget _menuButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE9EDF3),
          foregroundColor: const Color(0xFF293241),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF64748B),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}
