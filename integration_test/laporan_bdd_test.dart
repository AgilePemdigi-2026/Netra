import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:netra_app/screens/pengguna/laporan_perjalanan_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BDD - Laporan Perjalanan', () {
    Future<void> bukaLaporan(
      WidgetTester tester, {
      required List<TemuanRintangan> temuan,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LaporanPerjalananScreen(temuan: temuan),
                        ),
                      );
                    },
                    child: const Text('Buka Laporan'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Buka Laporan'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    }

    final contohTemuan = [
      TemuanRintangan(
        jenis: 'Jalan Rusak',
        confidence: 0.95,
        waktu: DateTime(2026, 11, 18, 10, 0),
        latitude: -7.2575,
        longitude: 112.7521,
        namaJalan: 'Jalan Pemuda',
      ),
    ];

    testWidgets('BDD-LAP-01 - Menampilkan ringkasan temuan perjalanan', (
      tester,
    ) async {
      await bukaLaporan(tester, temuan: contohTemuan);

      expect(find.text('Laporan Perjalanan'), findsOneWidget);
      expect(find.text('1 Temuan Masalah'), findsOneWidget);
      expect(find.text('1. Jalan Rusak'), findsOneWidget);
      expect(find.textContaining('95,00%'), findsOneWidget);
      expect(find.text('Jalan Pemuda'), findsOneWidget);

      print('BDD-LAP-01 PASS');
    });

    testWidgets('BDD-LAP-02 - Menampilkan kondisi tanpa temuan', (
      tester,
    ) async {
      await bukaLaporan(tester, temuan: []);

      expect(find.text('Laporan Perjalanan'), findsOneWidget);
      expect(find.text('Kirim'), findsOneWidget);
      expect(find.text('Tidak'), findsWidgets);

      print('BDD-LAP-02 PASS');
    });

    testWidgets('BDD-LAP-03 - Membatalkan pengiriman laporan', (tester) async {
      await bukaLaporan(tester, temuan: contohTemuan);

      await tester.tap(find.text('Tidak'));
      await tester.pumpAndSettle();

      expect(find.text('Buka Laporan'), findsOneWidget);

      print('BDD-LAP-03 PASS');
    });

    testWidgets('BDD-LAP-04 - Mengirim laporan perjalanan', (tester) async {
      await bukaLaporan(tester, temuan: contohTemuan);

      await tester.tap(find.text('Kirim'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Berhasil Terkirim'), findsOneWidget);
      expect(find.text('Kembali ke Beranda'), findsOneWidget);

      print('BDD-LAP-04 PASS');
    });
  });
}
