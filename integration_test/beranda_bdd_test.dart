import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:netra_app/screens/pengguna/beranda_screen.dart';

import 'bdd_helper.dart';

Future<void> bukaBeranda(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(debugShowCheckedModeBanner: false, home: BerandaScreen()),
  );

  await tungguTeks(tester, find.text('Mulai Perjalanan'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BDD - Beranda Pengguna NETRA', () {
    testWidgets('BDD-BER-01: Menampilkan halaman beranda NETRA', (
      WidgetTester tester,
    ) async {
      // GIVEN: Pengguna membuka aplikasi NETRA
      await bukaBeranda(tester);

      // WHEN: Halaman beranda berhasil ditampilkan
      // THEN: Informasi utama beranda tersedia

      expect(find.text('Dinas Sosial Kota Surabaya'), findsOneWidget);

      expect(find.text('Mulai Perjalanan'), findsOneWidget);

      expect(find.text('Panduan Penggunaan'), findsOneWidget);

      expect(find.text('Pengaturan Suara & Haptik'), findsOneWidget);

      expect(find.byTooltip('Login Admin'), findsOneWidget);

      expect(
        find.textContaining('Sistem Pelayanan Aksesibilitas'),
        findsOneWidget,
      );

      debugPrint('BDD-BER-01 PASS: Halaman beranda tampil');

      await tutupLayar(tester);
    });

    testWidgets('BDD-BER-02: Membuka halaman pengaturan suara dan haptik', (
      WidgetTester tester,
    ) async {
      // GIVEN: Pengguna berada di halaman beranda
      await bukaBeranda(tester);

      // WHEN: Pengguna memilih menu pengaturan
      await tekan(tester, find.text('Pengaturan Suara & Haptik'));

      // THEN: Halaman pengaturan ditampilkan
      await tungguTeks(tester, find.text('Pengaturan Suara & Haptik'));

      expect(find.text('Bahasa Suara'), findsOneWidget);

      expect(find.text('Bahasa Indonesia'), findsOneWidget);

      expect(find.text('Uji Suara'), findsOneWidget);

      expect(find.text('Uji Getaran'), findsOneWidget);

      expect(find.text('Simpan Pengaturan'), findsOneWidget);

      debugPrint('BDD-BER-02 PASS: Halaman pengaturan berhasil dibuka');

      await tutupLayar(tester);
    });

    testWidgets('BDD-BER-03: Membuka halaman login admin', (
      WidgetTester tester,
    ) async {
      // GIVEN: Pengguna berada di halaman beranda
      await bukaBeranda(tester);

      // WHEN: Pengguna menekan tombol Login Admin
      await tekan(tester, find.byTooltip('Login Admin'));

      // THEN: Halaman login admin ditampilkan
      await tungguTeks(tester, find.byTooltip('Kembali'));

      expect(find.byTooltip('Kembali'), findsOneWidget);

      expect(find.text('Dinas Sosial Kota Surabaya'), findsOneWidget);

      debugPrint('BDD-BER-03 PASS: Halaman login admin berhasil dibuka');

      await tutupLayar(tester);
    });

    testWidgets('BDD-BER-04: Kembali dari login admin ke halaman beranda', (
      WidgetTester tester,
    ) async {
      // GIVEN: Pengguna membuka halaman login admin
      await bukaBeranda(tester);

      await tekan(tester, find.byTooltip('Login Admin'));

      await tungguTeks(tester, find.byTooltip('Kembali'));

      // WHEN: Pengguna menekan tombol kembali
      await tekan(tester, find.byTooltip('Kembali'));

      // THEN: Pengguna kembali ke halaman beranda
      await tungguTeks(tester, find.text('Mulai Perjalanan'));

      expect(find.text('Mulai Perjalanan'), findsOneWidget);

      expect(find.text('Pengaturan Suara & Haptik'), findsOneWidget);

      debugPrint('BDD-BER-04 PASS: Berhasil kembali ke beranda');

      await tutupLayar(tester);
    });
  });
}
