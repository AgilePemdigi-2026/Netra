import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

// =============================================================================
// TAB PROFIL ADMIN
// =============================================================================
class ProfilAdminTab extends StatefulWidget {
  /// Nama petugas (dari tabel admin_dinsos).
  final String? namaAdmin;

  /// Dipanggil setelah petugas mengonfirmasi keluar dari akun.
  /// Proses sign out dan perpindahan ke halaman Login dilakukan oleh pemanggil.
  final Future<void> Function() onKeluar;

  const ProfilAdminTab({super.key, this.namaAdmin, required this.onKeluar});

  @override
  State<ProfilAdminTab> createState() => _ProfilAdminTabState();
}

class _ProfilAdminTabState extends State<ProfilAdminTab> {
  /// Lambang yang tampil di kartu identitas.
  /// Sesuaikan dengan nama file lambang di folder assets kamu.
  static const String _asetLambang = 'assets/images/dpu.png';

  static const String _labelPeran = 'Admin Dinas PU Bina Marga';
  static const String _hakOtoritas = 'Verifikator Temuan Masalah';

  static const Color _biru = Color(0xFF1D4ED8);
  static const Color _biruTua = Color(0xFF0A3277);

  bool _tersalin = false;
  bool _sedangKeluar = false;

  /// Username = bagian email sebelum tanda "@".
  String get _username {
    final email = SupabaseService.client.auth.currentUser?.email ?? '';
    if (email.isEmpty) return '-';
    return email.split('@').first;
  }

  String get _nama {
    final nama = widget.namaAdmin?.trim() ?? '';
    return nama.isEmpty ? 'Petugas Dinas PU Bina Marga' : nama;
  }

  // ---------------------------------------------------------------------------
  // AKSI
  // ---------------------------------------------------------------------------

  Future<void> _salinUsername() async {
    final nilai = _username;
    if (nilai == '-') return;

    await Clipboard.setData(ClipboardData(text: nilai));
    if (!mounted) return;

    setState(() => _tersalin = true);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Username disalin'),
          duration: Duration(milliseconds: 1500),
        ),
      );

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _tersalin = false);
  }

  Future<void> _bukaUbahPassword() async {
    final berhasil = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UbahPasswordSheet(),
    );

    if (berhasil == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Kata sandi berhasil diperbarui.')),
        );
    }
  }

  Future<void> _konfirmasiKeluar() async {
    if (_sedangKeluar) return;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Keluar dari akun?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Anda perlu masuk kembali untuk membuka dashboard petugas.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            height: 1.5,
            color: const Color(0xFF475467),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF344054),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: Text(
              'Keluar',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (yakin != true || !mounted) return;

    setState(() => _sedangKeluar = true);
    try {
      await widget.onKeluar();
    } finally {
      if (mounted) setState(() => _sedangKeluar = false);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, kendala) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: kendala.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _kartuIdentitas(),
                  const SizedBox(height: 14),
                  _kartuKredensial(),
                  const Spacer(),
                  const SizedBox(height: 16),
                  _tileUbahPassword(),
                  const SizedBox(height: 10),
                  _tombolKeluar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kartuIdentitas() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _dekorasiKartu(),
      child: Row(
        children: [
          _lambang(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 15,
                      color: _biruTua,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _labelPeran,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _biruTua,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _nama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF101828),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lambang() {
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              _asetLambang,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EAFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance,
                  size: 34,
                  color: _biruTua,
                ),
              ),
            ),
          ),
          Positioned(
            right: -5,
            bottom: -5,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _biru,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuKredensial() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _dekorasiKartu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFECEEF2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.vpn_key_outlined,
                  size: 18,
                  color: Color(0xFF1D2939),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kredensial & Otoritas',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF101828),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF86F5A0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF067647),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Aktif',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B3B1E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Username Akun',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF344054),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.courierPrime(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF101828),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Salin username',
                child: InkWell(
                  onTap: _salinUsername,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEEF2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _tersalin
                          ? Icons.check_rounded
                          : Icons.content_copy_rounded,
                      size: 20,
                      color: _tersalin
                          ? const Color(0xFF067647)
                          : const Color(0xFF344054),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          Text(
            'Hak Otoritas Petugas',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF344054),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 19, color: _biru),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _hakOtoritas,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF101828),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tileUbahPassword() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _bukaUbahPassword,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDEFF3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.password_rounded, size: 24, color: _biruTua),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubah Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Perbarui kata sandi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF344054),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Color(0xFF344054),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tombolKeluar() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _sedangKeluar ? null : _konfirmasiKeluar,
        icon: _sedangKeluar
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 20),
        label: Text(
          'Keluar dari Akun',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB91C1C),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB91C1C),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  BoxDecoration _dekorasiKartu() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEDEFF3)),
    );
  }
}

// =============================================================================
// FORM UBAH PASSWORD (BOTTOM SHEET)
// =============================================================================
class _UbahPasswordSheet extends StatefulWidget {
  const _UbahPasswordSheet();

  @override
  State<_UbahPasswordSheet> createState() => _UbahPasswordSheetState();
}

class _UbahPasswordSheetState extends State<_UbahPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _konfirmasi = TextEditingController();

  bool _tampilLama = false;
  bool _tampilBaru = false;
  bool _tampilKonfirmasi = false;

  bool _menyimpan = false;
  String? _galat;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;

    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = SupabaseService.client.auth.currentUser?.email;
    if (email == null) {
      setState(() {
        _galat = 'Sesi login tidak ditemukan. Silakan masuk kembali.';
      });
      return;
    }

    setState(() {
      _menyimpan = true;
      _galat = null;
    });

    try {
      // 1. Pastikan kata sandi lama benar.
      await SupabaseService.client.auth
          .signInWithPassword(email: email, password: _lama.text)
          .timeout(const Duration(seconds: 15));

      // 2. Ganti dengan kata sandi baru.
      await SupabaseService.client.auth
          .updateUser(UserAttributes(password: _baru.text))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      final pesan = e.message.toLowerCase();

      setState(() {
        if (pesan.contains('invalid login credentials')) {
          _galat = 'Kata sandi lama salah.';
        } else if (pesan.contains('different')) {
          _galat = 'Kata sandi baru harus berbeda dari kata sandi lama.';
        } else if (pesan.contains('weak') ||
            pesan.contains('should be at least')) {
          _galat = 'Kata sandi baru terlalu lemah. Gunakan yang lebih kuat.';
        } else {
          _galat = 'Gagal memperbarui kata sandi: ${e.message}';
        }
      });
    } catch (e) {
      debugPrint('Ubah password: $e');
      if (!mounted) return;
      setState(() {
        _galat =
            'Tidak dapat terhubung. Periksa koneksi internet lalu coba lagi.';
      });
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5DD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ubah Password',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Masukkan kata sandi lama, lalu buat kata sandi baru.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      height: 1.4,
                      color: const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _kolom(
                    label: 'Kata Sandi Lama',
                    hint: 'Masukkan kata sandi lama',
                    controller: _lama,
                    tampil: _tampilLama,
                    ubahTampil: () =>
                        setState(() => _tampilLama = !_tampilLama),
                    validator: (nilai) {
                      if (nilai == null || nilai.isEmpty) {
                        return 'Kata sandi lama wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _kolom(
                    label: 'Kata Sandi Baru',
                    hint: 'Minimal 8 karakter',
                    controller: _baru,
                    tampil: _tampilBaru,
                    ubahTampil: () =>
                        setState(() => _tampilBaru = !_tampilBaru),
                    validator: (nilai) {
                      if (nilai == null || nilai.isEmpty) {
                        return 'Kata sandi baru wajib diisi.';
                      }
                      if (nilai.length < 8) {
                        return 'Kata sandi baru minimal 8 karakter.';
                      }
                      if (nilai == _lama.text) {
                        return 'Kata sandi baru harus berbeda dari yang lama.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _kolom(
                    label: 'Konfirmasi Kata Sandi Baru',
                    hint: 'Ulangi kata sandi baru',
                    controller: _konfirmasi,
                    tampil: _tampilKonfirmasi,
                    ubahTampil: () =>
                        setState(() => _tampilKonfirmasi = !_tampilKonfirmasi),
                    aksi: TextInputAction.done,
                    kirim: _simpan,
                    validator: (nilai) {
                      if (nilai == null || nilai.isEmpty) {
                        return 'Konfirmasi kata sandi wajib diisi.';
                      }
                      if (nilai != _baru.text) {
                        return 'Konfirmasi tidak sama dengan kata sandi baru.';
                      }
                      return null;
                    },
                  ),
                  if (_galat != null) ...[
                    const SizedBox(height: 14),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _galat!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _menyimpan ? null : _simpan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F4BDB),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF93A9F0),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _menyimpan
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Simpan Kata Sandi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: _menyimpan
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF344054),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kolom({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool tampil,
    required VoidCallback ubahTampil,
    required String? Function(String?) validator,
    TextInputAction aksi = TextInputAction.next,
    VoidCallback? kirim,
  }) {
    OutlineInputBorder garis(Color warna, double lebar) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: warna, width: lebar),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0A3277),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !tampil,
          enabled: !_menyimpan,
          textInputAction: aksi,
          onFieldSubmitted: (_) => kirim?.call(),
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            suffixIcon: IconButton(
              tooltip: tampil
                  ? 'Sembunyikan kata sandi'
                  : 'Tampilkan kata sandi',
              onPressed: ubahTampil,
              icon: Icon(
                tampil
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF64748B),
              ),
            ),
            border: garis(Colors.transparent, 0),
            enabledBorder: garis(Colors.transparent, 0),
            focusedBorder: garis(const Color(0xFF2455E8), 1.5),
            errorBorder: garis(const Color(0xFFB91C1C), 1),
            focusedErrorBorder: garis(const Color(0xFFB91C1C), 1.5),
          ),
        ),
      ],
    );
  }
}
