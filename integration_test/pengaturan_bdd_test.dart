import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:netra_app/screens/pengguna/pengaturan_screen.dart';

// ============================================================
// HELPER
// ============================================================

/// Menunggu sampai [finder] muncul (maksimal [maksDetik] detik).
Future<void> tungguTeks(
  WidgetTester tester,
  Finder finder, {
  int maksDetik = 15,
}) async {
  final batas = maksDetik * 4;

  for (var i = 0; i < batas; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }

  fail('Elemen $finder tidak muncul dalam $maksDetik detik.');
}

/// Membuka PengaturanScreen dengan SharedPreferences awal tertentu.
Future<void> bukaPengaturan(
  WidgetTester tester, {
  Map<String, Object> awal = const {},
}) async {
  SharedPreferences.setMockInitialValues(awal);

  await tester.pumpWidget(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PengaturanScreen(),
    ),
  );

  await tungguTeks(tester, find.text('Bahasa Suara'));
}

/// Menggulir layar sampai [finder] terlihat.
Future<void> geserKe(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Memilih bahasa lewat dropdown.
Future<void> pilihBahasa(WidgetTester tester, String nama) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pump(const Duration(milliseconds: 600));

  await tester.tap(find.text(nama).last);
  await tester.pump(const Duration(milliseconds: 600));
}

/// Menekan tombol Simpan dan menunggu snackbar berhasil.
Future<void> tekanSimpan(WidgetTester tester) async {
  await tester.tap(find.text('Simpan Pengaturan'));
  await tungguTeks(tester, find.text('Pengaturan berhasil disimpan.'));
}

// ============================================================
// BDD PENGATURAN
// ============================================================

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BDD - Pengaturan NETRA', () {
    testWidgets(
      'BDD-PGT-01: Halaman pengaturan ditampilkan dengan benar',
      (WidgetTester tester) async {
        // GIVEN: Pengguna membuka halaman Pengaturan
        await bukaPengaturan(tester);

        // THEN: Semua bagian pengaturan tampil
        expect(find.text('Pengaturan Suara & Haptik'), findsOneWidget);
        expect(find.text('Bahasa Suara'), findsOneWidget);
        expect(find.text('Kecepatan Suara'), findsOneWidget);
        expect(find.text('Intensitas Getaran'), findsOneWidget);
        expect(find.text('Uji Suara'), findsOneWidget);
        expect(find.text('Uji Getaran'), findsOneWidget);
        expect(find.text('Rendah'), findsOneWidget);
        expect(find.text('Sedang'), findsOneWidget);
        expect(find.text('Tinggi'), findsOneWidget);
        expect(find.text('Simpan Pengaturan'), findsOneWidget);

        debugPrint('BDD-PGT-01 PASS: Halaman Pengaturan tampil lengkap');
      },
    );

    testWidgets(
      'BDD-PGT-02: Nilai bawaan tampil ketika belum ada pengaturan tersimpan',
      (WidgetTester tester) async {
        // GIVEN: Belum ada pengaturan yang tersimpan
        await bukaPengaturan(tester);

        // THEN: Bahasa Indonesia dan kecepatan 50% menjadi nilai awal
        expect(find.text('Bahasa Indonesia'), findsWidgets);
        expect(find.text('50%'), findsOneWidget);

        debugPrint('BDD-PGT-02 PASS: Nilai bawaan Pengaturan sesuai');
      },
    );

    testWidgets(
      'BDD-PGT-03: Mengubah bahasa suara menjadi English',
      (WidgetTester tester) async {
        // GIVEN: Bahasa saat ini Bahasa Indonesia
        await bukaPengaturan(tester);

        // WHEN: Pengguna memilih English
        await pilihBahasa(tester, 'English');

        // THEN: Pilihan bahasa berubah menjadi English
        expect(find.text('English'), findsWidgets);

        debugPrint('BDD-PGT-03 PASS: Bahasa berhasil diubah ke English');
      },
    );

    testWidgets(
      'BDD-PGT-04: Menaikkan kecepatan suara',
      (WidgetTester tester) async {
        // GIVEN: Kecepatan suara 50%
        await bukaPengaturan(tester);
        await geserKe(tester, find.byType(Slider));
        expect(find.text('50%'), findsOneWidget);

        // WHEN: Pengguna menggeser slider ke kanan
        await tester.drag(find.byType(Slider), const Offset(800, 0));
        await tester.pump(const Duration(milliseconds: 300));

        // THEN: Kecepatan naik dan tampilan diperbarui
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('50%'), findsNothing);

        debugPrint('BDD-PGT-04 PASS: Kecepatan suara naik ke 100%');
      },
    );

    testWidgets(
      'BDD-PGT-05: Menurunkan kecepatan suara',
      (WidgetTester tester) async {
        // GIVEN: Kecepatan suara 50%
        await bukaPengaturan(tester);
        await geserKe(tester, find.byType(Slider));
        expect(find.text('50%'), findsOneWidget);

        // WHEN: Pengguna menggeser slider ke kiri
        await tester.drag(find.byType(Slider), const Offset(-800, 0));
        await tester.pump(const Duration(milliseconds: 300));

        // THEN: Kecepatan turun dan tampilan diperbarui
        expect(find.text('10%'), findsOneWidget);
        expect(find.text('50%'), findsNothing);

        debugPrint('BDD-PGT-05 PASS: Kecepatan suara turun ke 10%');
      },
    );

    testWidgets(
      'BDD-PGT-06: Menyimpan pengaturan',
      (WidgetTester tester) async {
        // GIVEN: Pengguna berada di Pengaturan dan mengubah tiga pengaturan
        await bukaPengaturan(tester);

        await pilihBahasa(tester, 'English');

        await geserKe(tester, find.byType(Slider));
        await tester.drag(find.byType(Slider), const Offset(800, 0));
        await tester.pump(const Duration(milliseconds: 300));

        await geserKe(tester, find.text('Tinggi'));
        await tester.tap(find.text('Tinggi'));
        await tester.pump(const Duration(milliseconds: 300));

        // WHEN: Pengguna menekan Simpan Pengaturan
        await tekanSimpan(tester);

        // THEN: Snackbar berhasil muncul dan nilai tersimpan
        expect(find.text('Pengaturan berhasil disimpan.'), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('netra_bahasa'), 'en-US');
        expect(prefs.getDouble('netra_kecepatan'), closeTo(1.0, 0.001));
        expect(prefs.getInt('netra_intensitas_getaran'), 3);

        // AND: Pengguna tetap berada di halaman Pengaturan
        expect(find.text('Pengaturan Suara & Haptik'), findsOneWidget);

        debugPrint('BDD-PGT-06 PASS: Pengaturan berhasil disimpan');
      },
    );

    testWidgets(
      'BDD-PGT-07: Pengaturan tersimpan dimuat saat halaman dibuka',
      (WidgetTester tester) async {
        // GIVEN: Pengaturan sebelumnya sudah tersimpan
        await bukaPengaturan(
          tester,
          awal: {
            'netra_bahasa': 'en-US',
            'netra_kecepatan': 0.8,
            'netra_intensitas_getaran': 3,
          },
        );

        // THEN: Halaman menampilkan nilai yang tersimpan
        expect(find.text('English'), findsWidgets);
        expect(find.text('80%'), findsOneWidget);

        debugPrint('BDD-PGT-07 PASS: Pengaturan tersimpan dimuat kembali');
      },
    );

    testWidgets(
      'BDD-PGT-08: Kembali tanpa menyimpan tidak mengubah pengaturan',
      (WidgetTester tester) async {
        // GIVEN: Pengguna membuka Pengaturan dari halaman sebelumnya
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PengaturanScreen(),
                      ),
                    ),
                    child: const Text('Buka Pengaturan'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Pengaturan'));
        await tungguTeks(tester, find.text('Bahasa Suara'));

        // AND: Pengguna mengubah bahasa tanpa menyimpan
        await pilihBahasa(tester, 'English');

        // WHEN: Pengguna menekan tombol kembali
        await tester.pageBack();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        // THEN: Kembali ke halaman sebelumnya dan tidak ada yang tersimpan
        expect(find.text('Buka Pengaturan'), findsOneWidget);
        expect(find.text('Pengaturan Suara & Haptik'), findsNothing);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('netra_bahasa'), isNull);

        debugPrint('BDD-PGT-08 PASS: Perubahan tidak tersimpan saat kembali');
      },
    );

    testWidgets(
      'BDD-PGT-09: Tombol Uji Suara dan Uji Getaran berjalan tanpa error',
      (WidgetTester tester) async {
        // GIVEN: Pengguna berada di halaman Pengaturan
        await bukaPengaturan(tester);

        // WHEN: Pengguna menekan Uji Suara dan Uji Getaran
        await geserKe(tester, find.text('Uji Suara'));
        await tester.tap(find.text('Uji Suara'));
        await tester.pump(const Duration(seconds: 2));

        await geserKe(tester, find.text('Uji Getaran'));
        await tester.tap(find.text('Uji Getaran'));
        await tester.pump(const Duration(seconds: 1));

        // THEN: Tidak ada pesan gagal.
        // Catatan: ini hanya membuktikan tidak ada error. Suara yang
        // benar-benar terdengar dan getaran yang benar-benar terasa
        // tetap diuji manual di HP.
        expect(find.textContaining('Gagal'), findsNothing);

        debugPrint('BDD-PGT-09 PASS: Uji Suara/Getaran berjalan tanpa error');
      },
    );
  });
}