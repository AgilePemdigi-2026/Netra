
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:netra_app/screens/pengguna/beranda_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BDD - Beranda NETRA', () {
    testWidgets(
      'BDD-01: Pengguna berhasil membuka Beranda NETRA',
      (WidgetTester tester) async {
        // GIVEN: Aplikasi membuka halaman Beranda
        await tester.pumpWidget(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BerandaScreen(),
          ),
        );

        await tester.pump(const Duration(seconds: 2));

        // THEN: Elemen utama Beranda harus tampil
        expect(find.text('Dinas Sosial Kota Surabaya'), findsOneWidget);
        expect(find.text('Mulai Perjalanan'), findsOneWidget);
        expect(find.text('Panduan Penggunaan'), findsOneWidget);
        expect(find.text('Pengaturan Suara & Haptik'), findsOneWidget);

        debugPrint('BDD-01 PASS: Beranda NETRA berhasil ditampilkan');
      },
    );

    testWidgets(
      'BDD-02: Tombol navigasi utama tersedia',
      (WidgetTester tester) async {
        // GIVEN: Pengguna berada di halaman Beranda
        await tester.pumpWidget(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BerandaScreen(),
          ),
        );

        await tester.pump(const Duration(seconds: 2));

        // WHEN: Sistem memeriksa menu navigasi
        final mulaiPerjalanan = find.text('Mulai Perjalanan');
        final loginAdmin = find.byTooltip('Login Admin');
        final pengaturan = find.text('Pengaturan Suara & Haptik');

        // THEN: Ketiga menu harus tersedia
        expect(mulaiPerjalanan, findsOneWidget);
        expect(loginAdmin, findsOneWidget);
        expect(pengaturan, findsOneWidget);

        debugPrint('BDD-02 PASS: Menu navigasi utama tersedia');
      },
    );
  });
}
