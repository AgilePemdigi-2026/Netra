
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import service Supabase
import 'services/supabase_service.dart';

// Import halaman Beranda NETRA
import 'screens/pengguna/beranda_screen.dart';

// Konfigurasi Supabase dari env.json
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Validasi konfigurasi Supabase
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw Exception(
      'SUPABASE_URL atau SUPABASE_KEY belum terbaca dari env.json',
    );
  }

  final uri = Uri.tryParse(supabaseUrl);

  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.host == 'localhost') {
    throw Exception(
      'SUPABASE_URL tidak valid. Periksa Project URL di env.json',
    );
  }

  debugPrint('Supabase host: ${uri.host}');
  debugPrint('Supabase key tersedia: ${supabaseKey.isNotEmpty}');

  // Inisialisasi Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const NetraApp());
}

// ========================================
// APLIKASI UTAMA NETRA
// ========================================

class NetraApp extends StatelessWidget {
  const NetraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NETRA',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
        ),
        scaffoldBackgroundColor: Colors.white,
      ),

      // Menyiapkan pengguna sebelum membuka Beranda
      home: const NetraStartup(),
    );
  }
}

// ========================================
// INISIALISASI PENGGUNA NETRA
// ========================================

class NetraStartup extends StatefulWidget {
  const NetraStartup({super.key});

  @override
  State<NetraStartup> createState() => _NetraStartupState();
}

class _NetraStartupState extends State<NetraStartup> {
  late Future<int> _futurePengguna;

  @override
  void initState() {
    super.initState();

    // Menyiapkan pengguna anonim di Supabase
    _futurePengguna = SupabaseService.siapkanPengguna();
  }

  // Mencoba kembali jika gagal
  void _cobaLagi() {
    setState(() {
      _futurePengguna = SupabaseService.siapkanPengguna();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _futurePengguna,
      builder: (context, snapshot) {

        // Saat proses koneksi berlangsung
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF1D4ED8),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Menyiapkan NETRA...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Jika terjadi error
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal menyiapkan NETRA',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _cobaLagi,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Jika berhasil, langsung buka Beranda
        return const BerandaScreen();
      },
    );
  }
}
