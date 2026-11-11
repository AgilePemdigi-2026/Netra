
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import service Supabase
import 'services/supabase_service.dart';

// Import halaman Beranda NETRA
import 'screens/pengguna/beranda_screen.dart';

// Import halaman Dashboard Admin (untuk testing UI tanpa login)
import 'screens/admin/dashboard_screen.dart';

// ========================================
// KONFIGURASI SUPABASE (dari env.json atau environment variable)
// ========================================

bool supabaseDikonfigurasi = false;

Future<Map<String, String>> _bacaEnvJson() async {
  if (kIsWeb) return {};

  final file = io.File('env.json');
  if (!await file.exists()) return {};

  final contents = await file.readAsString();
  final data = jsonDecode(contents) as Map<String, dynamic>;
  return {
    'SUPABASE_URL': (data['SUPABASE_URL'] ?? '').toString(),
    'SUPABASE_KEY': (data['SUPABASE_KEY'] ?? '').toString(),
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Coba baca dari env.json terlebih dahulu
  final envData = await _bacaEnvJson();

  // 2. Fallback ke environment variable (--dart-define atau terminal)
  final rawUrl = envData['SUPABASE_URL']?.toString() ??
      const String.fromEnvironment('SUPABASE_URL');
  final rawKey = envData['SUPABASE_KEY']?.toString() ??
      const String.fromEnvironment('SUPABASE_KEY');

  final supabaseUrl = rawUrl.isNotEmpty ? rawUrl : '';
  final supabaseKey = rawKey.isNotEmpty ? rawKey : '';

  supabaseDikonfigurasi =
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  if (supabaseDikonfigurasi) {
    final uri = Uri.tryParse(supabaseUrl);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host == 'localhost') {
      runApp(const _NetraConfigError(
        pesan: 'SUPABASE_URL tidak valid. Periksa file env.json atau environment variable.',
      ));
      return;
    }

    debugPrint('Supabase host: ${uri.host}');
    debugPrint('Supabase key tersedia: ${supabaseKey.isNotEmpty}');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  } else {
    debugPrint(
      'PERINGATAN: SUPABASE_URL / SUPABASE_KEY belum di-set. '
      'Aplikasi akan berjalan dalam mode demo (tanpa Supabase).',
    );
  }

  runApp(const NetraApp());
}

// ========================================
// LAYAR KONFIGURASI ERROR (Jika Supabase tidak valid)
// ========================================

class _NetraConfigError extends StatelessWidget {
  final String pesan;

  const _NetraConfigError({required this.pesan});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
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
                  'Konfigurasi Supabase belum lengkap',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  pesan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    if (!kIsWeb) io.exit(0);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Keluar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

    // Jika Supabase tidak dikonfigurasi, langsung buka Beranda (mode demo)
    if (!supabaseDikonfigurasi) {
      _futurePengguna = Future.value(0);
    } else {
      // Menyiapkan pengguna anonim di Supabase
      _futurePengguna = SupabaseService.siapkanPengguna();
    }
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
