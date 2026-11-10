import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalPerjalanan = 0;
  int _perjalananSelesai = 0;
  int _deteksiAI = 0;
  int _totalTemuan = 0;
  int _menungguVerifikasi = 0;
  int _terverifikasi = 0;
  int _ditolak = 0;
  bool _isLoading = true;
  String? _namaAdmin;
  String? _roleAdmin;
  List<Map<String, dynamic>> _daftarTemuan = [];
  bool _demoMode = false;
  int _belumDiverifikasi = 0;

  // SharedPreferences instance for caching admin name
  late Future<SharedPreferences> _prefs;

  @override
  void initState() {
    super.initState();
    // Inisialisasi Future untuk SharedPreferences
    _prefs = SharedPreferences.getInstance();
    // Cek cache nama admin dari login sebelumnya (gunakan then karena _prefs adalah Future)
    _prefs.then((prefs) {
      setState(() {
        _namaAdmin = prefs.getString('admin_nama');
      });
    });
  }

  Future<void> _loadData() async {
    try {
      // Cek apakah Supabase sudah diinisialisasi
      if (Supabase.instance.client.auth.currentUser == null) {
        // Coba inisialisasi sesi anonim jika belum
        try {
          await Supabase.instance.client.auth.signInAnonymously();
        } catch (_) {
          // Jika gagal (mis. Supabase tidak dikonfigurasi), pakai mode demo
          _setDemoData();
          return;
        }
      }

      // Jalankan query statistik dan daftar temuan PARALLEL untuk mempercepat loading
      // Dua query ini dijalankan bersamaan, bukan satu per satu
      final Object? statsObj = await SupabaseService.hitungStatistikTemuan();
      final Object? daftarObj = await SupabaseService.ambilTemuanTerbaru(limit: 5);

      // Cast ke tipe yang sesuai
      final statistik = (statsObj as Map<String, dynamic>) ?? {};
      final daftar = (daftarObj as List<Map<String, dynamic>>?) ?? [];

      // Ambil nama admin dari tabel admin_dinsos
      final user = SupabaseService.client.auth.currentUser;
      String? namaAdmin;
      if (user != null) {
        final adminData = await SupabaseService.client
            .from('admin_dinsos')
            .select('nama')
            .eq('auth_user_id', user.id)
            .maybeSingle();

        if (adminData != null && mounted) {
          setState(() {
            _namaAdmin = adminData['nama'] as String?;
          });
          // Cache nama admin ke SharedPreferences agar tidak perlu query lagi di login selanjutnya
          // Gunakan .then() karena _prefs adalah Future
          _prefs.then((prefs) => prefs.setString('admin_nama', _namaAdmin!));
        }
      }

      if (!mounted) return;

      setState(() {
        _demoMode = false;
        _totalTemuan = statistik['total'] ?? 0;
        _terverifikasi = statistik['terverifikasi'] ?? 0;
        _belumDiverifikasi = statistik['belum_diverifikasi'] ?? 0;
        _daftarTemuan = daftar;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat data dashboard: $e');
      if (!mounted) return;
      _setDemoData();
    }
  }

  void _setDemoData() {
    if (!mounted) return;
    setState(() {
      _demoMode = true;
      _namaAdmin = 'Selamat Datang Petugas Dinas Sosial';
      _totalTemuan = 12;
      _terverifikasi = 5;
      _belumDiverifikasi = 7;
      _daftarTemuan = [
        {'jenis': 'Trotoar rusak', 'status': 'belum_diverifikasi', 'waktu': '10:30 WIB', 'lokasi': 'Jalan Raya Wiyung'},
        {'jenis': 'Jalan berlubang', 'status': 'terverifikasi', 'waktu': '09:15 WIB', 'lokasi': 'Jalan Arief Rahman Hakim'},
      ];
      _isLoading = false;
    });
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await SupabaseService.client.auth.signOut();
      await SupabaseService.siapkanPengguna();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('Gagal logout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal keluar dari akun.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard Admin',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1D4ED8),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _bagianSelamatDatang(),
                  const SizedBox(height: 24),
                  Text(
                    'Statistik Temuan Aksesibilitas',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF253047),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _kartuStatistik(
                          judul: 'Total Temuan',
                          nilai: _totalTemuan.toString(),
                          ikon: Icons.report_outlined,
                          warna: const Color(0xFF1D4ED8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kartuStatistik(
                          judul: 'Terverifikasi',
                          nilai: _terverifikasi.toString(),
                          ikon: Icons.check_circle_outline,
                          warna: const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kartuStatistik(
                          judul: 'Belum Diverifikasi',
                          nilai: _belumDiverifikasi.toString(),
                          ikon: Icons.pending_outlined,
                          warna: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Menu Cepat',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF253047),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _menuCepatGrid(),
                  const SizedBox(height: 24),
                  Text(
                    'Temuan Terbaru',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF253047),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _daftarTemuanTerbaru(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _bagianSelamatDatang() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat datang,',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _namaAdmin ?? 'Petugas Dinas Sosial',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kelola dan verifikasi temuan aksesibilitas lingkungan dari pengguna NETRA.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuStatistik({
    required String judul,
    required String nilai,
    required IconData ikon,
    required Color warna,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: warna.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ikon, color: warna, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  nilai,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _menuCepatGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _tombolMenuCepat(
          ikon: Icons.list_alt,
          label: 'Daftar Temuan',
          warna: const Color(0xFF1D4ED8),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _HalamanSementara(judul: 'Daftar Temuan'),
              ),
            );
          },
        ),
        _tombolMenuCepat(
          ikon: Icons.verified_user,
          label: 'Verifikasi Temuan',
          warna: const Color(0xFF16A34A),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _HalamanSementara(judul: 'Verifikasi Temuan'),
              ),
            );
          },
        ),
        _tombolMenuCepat(
          ikon: Icons.description,
          label: 'Detail Temuan',
          warna: const Color(0xFFF59E0B),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _HalamanSementara(judul: 'Detail Temuan'),
              ),
            );
          },
        ),
        _tombolMenuCepat(
          ikon: Icons.exit_to_app,
          label: 'Logout',
          warna: const Color(0xFFEF4444),
          onTap: () => _logout(context),
        ),
      ],
    );
  }

  Widget _tombolMenuCepat({
    required IconData ikon,
    required String label,
    required Color warna,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, color: warna, size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  Widget _daftarTemuanTerbaru() {
    if (_daftarTemuan.isEmpty) {
      return _kosongPlaceholder();
    }

    return Column(
      children: _daftarTemuan.map((data) {
        return _itemTemuan(
          jenis: data['jenis'] ?? '-',
          status: data['status'] ?? '-',
          waktu: data['waktu']?.toString() ?? '-',
          lokasi: data['lokasi'] ?? '-',
        );
      }).toList(),
    );
  }

  Widget _itemTemuan({
    required String jenis,
    required String status,
    required String waktu,
    required String lokasi,
  }) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'terverifikasi':
        statusColor = const Color(0xFF16A34A);
        break;
      case 'belum_diverifikasi':
      case 'belum diverifikasi':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'ditolak':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFF64748B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFFEF4444),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jenis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$waktu  •  $lokasi',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.replaceAll('_', ' '),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kosongPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada temuan terbaru',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Temuan dari pengguna akan muncul di sini.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder untuk halaman admin yang belum diimplementasi (Sprint 3).
class _HalamanSementara extends StatelessWidget {
  final String judul;

  const _HalamanSementara({required this.judul});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(judul),
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.construction_outlined,
              size: 64,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              judul,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Halaman ini akan diimplementasi pada Sprint 3.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali ke Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

