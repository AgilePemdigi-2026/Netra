import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:netra_app/screens/admin/dashboard_screen.dart';

import 'bdd_helper.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_KEY');
const _emailAdmin = String.fromEnvironment('TEST_ADMIN_EMAIL');
const _passwordAdmin = String.fromEnvironment('TEST_ADMIN_PASSWORD');

Future<void> loginAdmin() async {
  final client = Supabase.instance.client;

  if (client.auth.currentUser == null) {
    await client.auth.signInWithPassword(
      email: _emailAdmin,
      password: _passwordAdmin,
    );
  }
}

Future<void> bukaDashboard(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DashboardScreen(),
    ),
  );

  await tungguTeks(tester, find.text('Dashboard Utama'));
}

Future<void> bukaTabTemuan(WidgetTester tester) async {
  await bukaDashboard(tester);

  await tekan(tester, find.text('Temuan').last);

  await tungguTeks(tester, find.text('Temuan Aksesibilitas'));
}

Future<void> bukaDetailTemuan(WidgetTester tester) async {
  await bukaTabTemuan(tester);

  // Tunggu kartu temuan yang benar-benar dimuat dari Supabase.
  final tombolDetail = find.text('Lihat Detail');
  await tungguTeks(tester, tombolDetail);

  expect(
    tombolDetail,
    findsWidgets,
    reason:
        'Tombol Lihat Detail tidak ditemukan. '
        'Pastikan terdapat temuan yang menunggu verifikasi.',
  );

  await tekan(tester, tombolDetail.first);

  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (_supabaseUrl.isEmpty ||
        _supabaseKey.isEmpty ||
        _emailAdmin.isEmpty ||
        _passwordAdmin.isEmpty) {
      throw Exception('Konfigurasi Supabase atau akun admin belum lengkap.');
    }

    await inisialisasiSupabaseSekali(
      url: _supabaseUrl,
      publishableKey: _supabaseKey,
    );

    await loginAdmin();
  });

  group('BDD - Dashboard Admin NETRA', () {
    // ==========================================
    // USER STORY I: MELIHAT DASHBOARD UTAMA
    // ==========================================

    testWidgets('BDD-ADM-I-01: Admin dapat melihat halaman Dashboard Utama', (
      WidgetTester tester,
    ) async {
      await bukaDashboard(tester);

      expect(find.text('Dashboard Utama'), findsOneWidget);

      expect(find.text('Selamat Datang'), findsOneWidget);

      expect(find.text('Petugas Dinas Sosial Kota Surabaya'), findsOneWidget);

      expect(find.text('Metrik Operasional'), findsOneWidget);

      expect(find.text('Total Perjalanan'), findsOneWidget);
      expect(find.text('Perjalanan Selesai'), findsOneWidget);
      expect(find.text('Deteksi AI'), findsOneWidget);
      expect(find.text('Total Temuan'), findsOneWidget);

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Temuan'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);

      debugPrint('BDD-ADM-I-01 PASS: Dashboard Utama berhasil ditampilkan');
    });

    testWidgets('BDD-ADM-I-02: Admin dapat memilih periode dashboard', (
      WidgetTester tester,
    ) async {
      await bukaDashboard(tester);

      await tekan(tester, find.byTooltip('Pilih periode'));

      expect(find.text('Hari Ini'), findsWidgets);
      expect(find.text('Satu Minggu'), findsWidgets);
      expect(find.text('Satu Bulan'), findsWidgets);
      expect(find.text('Semua Waktu'), findsWidgets);

      await tekan(tester, find.text('Hari Ini').last);

      expect(find.text('Metrik Operasional'), findsOneWidget);

      debugPrint('BDD-ADM-I-02 PASS: Filter periode berhasil dipilih');
    });

    testWidgets('BDD-ADM-I-03: Admin dapat membuka tab Temuan', (
      WidgetTester tester,
    ) async {
      await bukaTabTemuan(tester);

      expect(find.text('Temuan Aksesibilitas'), findsOneWidget);

      expect(find.text('Cari temuan'), findsOneWidget);

      debugPrint('BDD-ADM-I-03 PASS: Tab Temuan berhasil dibuka');
    });

    // ==========================================
    // USER STORY J: MELIHAT DETAIL TEMUAN
    // ==========================================

    testWidgets('BDD-ADM-J-01: Admin dapat melihat detail temuan', (
      WidgetTester tester,
    ) async {
      // GIVEN: Admin membuka daftar temuan
      await bukaTabTemuan(tester);

      // THEN: Minimal satu temuan yang menunggu verifikasi ditampilkan.
      final tombolDetail = find.text('Lihat Detail');
      await tungguTeks(tester, tombolDetail);
      expect(tombolDetail, findsWidgets);

      // WHEN: Admin memilih Lihat Detail
      await tekan(tester, tombolDetail.first);

      await tester.pumpAndSettle();

      // THEN: Informasi detail temuan ditampilkan
      expect(find.text('Jenis Permasalahan'), findsOneWidget);

      expect(find.text('Lokasi Laporan'), findsOneWidget);

      expect(find.text('Dokumentasi Lapangan'), findsOneWidget);

      expect(find.text('Deteksi Terkait'), findsOneWidget);

      expect(find.text('Proses Verifikasi'), findsOneWidget);

      debugPrint('BDD-ADM-J-01 PASS: Detail temuan berhasil ditampilkan');
    });

    // ==========================================
    // USER STORY K: AKSI PROSES VERIFIKASI
    // ==========================================

    testWidgets('BDD-ADM-K-01: Admin dapat menekan tombol Proses Verifikasi', (
      WidgetTester tester,
    ) async {
      // GIVEN: Admin membuka detail temuan
      await bukaDetailTemuan(tester);

      expect(find.text('Proses Verifikasi'), findsOneWidget);

      // WHEN: Admin menekan tombol Proses Verifikasi
      await tekan(tester, find.text('Proses Verifikasi'));

      await tester.pumpAndSettle();

      // THEN: Halaman verifikasi yang sesungguhnya ditampilkan.
      expect(find.text('Verifikasi Temuan'), findsOneWidget);
      expect(find.text('Validasi Temuan Lapangan'), findsOneWidget);
      expect(find.text('Konfirmasi Verifikasi'), findsOneWidget);
      expect(find.text('Tolak Temuan'), findsOneWidget);
      expect(find.text('Konfirmasi Penolakan'), findsOneWidget);

      debugPrint(
        'BDD-ADM-K-01 PASS: Halaman verifikasi berhasil dibuka',
      );
    });
  });
}
