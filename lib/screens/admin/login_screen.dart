import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _sembunyikanSandi = true;
  bool _sedangMasuk = false;
  String? _pesanError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ========================
  // KEMBALIKAN SESI PENGGUNA
  // ========================
  // Setelah signOut, aplikasi perlu sesi anonim lagi agar
  // fitur pengguna (perjalanan, pengaturan) tetap berjalan.
  Future<void> _kembalikanSesiPengguna() async {
    try {
      await SupabaseService.client.auth.signOut();
      await SupabaseService.siapkanPengguna();
    } catch (e) {
      debugPrint('Gagal memulihkan sesi pengguna: $e');
    }
  }

  // ========================
  // PROSES LOGIN ADMIN
  // ========================
  Future<void> _masuk() async {
    if (_sedangMasuk) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sedangMasuk = true;
      _pesanError = null;
    });

    try {
      // 1. Login lewat Supabase Auth
      final respon = await SupabaseService.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = respon.user;
      if (user == null) {
        throw const AuthException('Login gagal.');
      }

      // 2. Pastikan akun ini terdaftar di tabel admin_dinsos
      final admin = await SupabaseService.client
          .from('admin_dinsos')
          .select('id_admin, nama')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (admin == null) {
        await _kembalikanSesiPengguna();

        if (!mounted) return;
        setState(() {
          _pesanError =
              'Akun ini tidak terdaftar sebagai petugas Dinas Sosial.';
        });
        return;
      }

      if (!mounted) return;

      final namaAdmin = (admin['nama'] as String?) ?? 'Petugas Dinsos';

      // 3. Buka dashboard asli.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final pesan = e.message.toLowerCase();
      setState(() {
        _pesanError = pesan.contains('invalid login credentials')
            ? 'Email atau kata sandi salah.'
            : 'Gagal masuk: ${e.message}';
      });
    } on PostgrestException catch (e) {
      debugPrint('Gagal membaca admin_dinsos: ${e.message}');
      await _kembalikanSesiPengguna();

      if (!mounted) return;
      setState(() {
        _pesanError =
            'Gagal memverifikasi akun petugas. Coba lagi atau hubungi administrator.';
      });
    } catch (e) {
      debugPrint('Error login: $e');
      await _kembalikanSesiPengguna();

      if (!mounted) return;
      setState(() {
        _pesanError =
            'Tidak dapat terhubung. Periksa koneksi internet lalu coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sedangMasuk = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
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
                          errorBuilder: (context, error, stackTrace) {
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
                        IconButton(
                          tooltip: 'Kembali',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF0A3277),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ========================
                    // LOGO TULISAN NETRA
                    // ========================
                    Image.asset(
                      'assets/images/icon_netra.png',
                      width: 200,
                      height: 70,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
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

                    const SizedBox(height: 24),

                    // ========================
                    // LOGO MATA NETRA
                    // ========================
                    Container(
                      width: 150,
                      height: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8)
                                .withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo_netra.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.visibility,
                            size: 90,
                            color: Color(0xFF1D4ED8),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ========================
                    // FORM LOGIN
                    // ========================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ----- EMAIL -----
                            _label(Icons.person_outline, 'Email'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              enabled: !_sedangMasuk,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: _inputDecoration(
                                'Masukkan email petugas',
                              ),
                              validator: (value) {
                                final teks = value?.trim() ?? '';
                                if (teks.isEmpty) {
                                  return 'Email wajib diisi.';
                                }
                                if (!teks.contains('@') ||
                                    !teks.contains('.')) {
                                  return 'Format email tidak valid.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Gunakan email akun petugas Dinas Sosial.',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ----- KATA SANDI -----
                            _label(Icons.lock_outline, 'Kata Sandi'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _sembunyikanSandi,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              enabled: !_sedangMasuk,
                              onFieldSubmitted: (_) => _masuk(),
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: _inputDecoration(
                                'Masukkan kata sandi',
                              ).copyWith(
                                suffixIcon: IconButton(
                                  tooltip: _sembunyikanSandi
                                      ? 'Tampilkan kata sandi'
                                      : 'Sembunyikan kata sandi',
                                  onPressed: () {
                                    setState(() {
                                      _sembunyikanSandi =
                                          !_sembunyikanSandi;
                                    });
                                  },
                                  icon: Icon(
                                    _sembunyikanSandi
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Kata sandi wajib diisi.';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // ----- PESAN ERROR -----
                            if (_pesanError != null) ...[
                              Semantics(
                                liveRegion: true,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _pesanError!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ----- TOMBOL MASUK -----
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _sedangMasuk ? null : _masuk,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2455E8),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFF93A9F0),
                                  disabledForegroundColor: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _sedangMasuk
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.login_rounded),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Masuk',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========================
  // WIDGET BANTUAN
  // ========================
  Widget _label(IconData icon, String teks) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0A3277)),
        const SizedBox(width: 6),
        Text(
          teks,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0A3277),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: const Color(0xFF94A3B8),
      ),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2455E8), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
      ),
    );
  }
}

