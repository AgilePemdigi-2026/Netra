import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:netra_app/screens/pengguna/laporan_perjalanan_screen.dart';

import 'bdd_helper.dart';

List<TemuanRintangan> temuanContoh() => [
      TemuanRintangan(
        jenis: 'Jalan berlubang',
        confidence: 0.92,
        waktu: DateTime(2026, 11, 4, 10, 0),
        namaJalan: 'Jl. Airlangga',
        latitude: -7.27,
        longitude: 112.78,
      ),
      TemuanRintangan(
        jenis: 'Tangga',
        confidence: 0.71,
        waktu: DateTime(2026, 11, 4, 10, 5),
        namaJalan: 'Jl. Dharmawangsa',
      ),
    ];

/// Membuka Laporan Perjalanan dari halaman "Beranda Uji", sehingga
/// perilaku kembali ke halaman awal bisa diperiksa.
Future<void> bukaLaporan(
  WidgetTester tester,
  List<TemuanRintangan> temuan,
) async {
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Beranda Uji'),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LaporanPerjalananScreen(temuan: temuan),
                    ),
                  ),
                  child: const Text('Buka Laporan'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Buka Laporan'));
  await tungguTeks(tester, find.text('Laporan Perjalanan'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BDD - Laporan Perjalanan NETRA', () {
    testWidgets(
      'BDD-LAP-01: Laporan menampilkan temuan selama perjalanan',
      (WidgetTester tester) async {
        // GIVEN: Perjalanan selesai dengan 2 temuan
        await bukaLaporan(tester, temuanContoh());

        try {
          // THEN: Judul, daftar temuan, dan tombol tampil
          expect(
            find.text(
              'Apakah Anda ingin mengirim laporan ini ke Dinas Sosial Kota Surabaya?',
            ),
            findsOneWidget,
          );
          expect(find.text('2 Temuan Masalah'), findsOneWidget);
          expect(find.text('1. Jalan berlubang'), findsOneWidget);
          expect(find.text('2. Tangga'), findsOneWidget);
          expect(find.text('Akurasi 92,00%'), findsOneWidget);
          expect(find.text('Akurasi 71,00%'), findsOneWidget);
          expect(find.text('Jl. Airlangga'), findsOneWidget);
          expect(find.text('Jl. Dharmawangsa'), findsOneWidget);
          expect(find.text('Tidak'), findsOneWidget);

          // AND: Tombol Kirim aktif
          final tombolKirim = find.ancestor(
            of: find.text('Kirim'),
            matching: find.bySubtype<ElevatedButton>(),
          );
          expect(tester.widget<ElevatedButton>(tombolKirim).onPressed,
              isNotNull);

          debugPrint('BDD-LAP-01 PASS: Laporan dengan temuan tampil benar');
        } finally {
          await tutupLayar(tester);
        }
      },
    );

    testWidgets(
      'BDD-LAP-02: Laporan menampilkan keadaan tanpa temuan',
      (WidgetTester tester) async {
        // GIVEN: Perjalanan selesai tanpa temuan
        await bukaLaporan(tester, const []);

        try {
          // THEN: Pesan tanpa hambatan tampil dan Kirim nonaktif
          expect(find.text('Tidak Ditemukan Hambatan'), findsOneWidget);
          expect(find.textContaining('Temuan Masalah'), findsNothing);

          final tombolKirim = find.ancestor(
            of: find.text('Kirim'),
            matching: find.bySubtype<ElevatedButton>(),
          );
          expect(tester.widget<ElevatedButton>(tombolKirim).onPressed, isNull);

          debugPrint('BDD-LAP-02 PASS: Laporan tanpa temuan tampil benar');
        } finally {
          await tutupLayar(tester);
        }
      },
    );

    testWidgets(
      'BDD-LAP-03: Pengguna memilih Tidak dan kembali ke Beranda',
      (WidgetTester tester) async {
        // GIVEN: Laporan perjalanan tampil
        await bukaLaporan(tester, temuanContoh());

        try {
          // WHEN: Pengguna menekan Tidak
          await tekan(tester, find.text('Tidak'));

          // THEN: Kembali ke halaman awal
          await tungguTeks(tester, find.text('Beranda Uji'));
          expect(find.text('Laporan Perjalanan'), findsNothing);

          debugPrint('BDD-LAP-03 PASS: Kembali ke Beranda setelah Tidak');
        } finally {
          await tutupLayar(tester);
        }
      },
    );

    testWidgets(
      'BDD-LAP-04: Alur kirim menampilkan konfirmasi berhasil '
      '(pengiriman ke server belum diimplementasikan)',
      (WidgetTester tester) async {
        // GIVEN: Laporan dengan temuan tampil
        await bukaLaporan(tester, temuanContoh());

        try {
          // WHEN: Pengguna menekan Kirim
          await tekan(tester, find.text('Kirim'));

          // THEN: Dialog berhasil terkirim tampil.
          // Catatan: _kirim() saat ini masih placeholder (TODO), sehingga
          // test ini hanya membuktikan alur tampilan, bukan data terkirim.
          await tungguTeks(
            tester,
            find.text('Berhasil Terkirim'),
            maksDetik: 20,
          );
          expect(
            find.text(
              'Laporan temuan masalah berhasil dikirimkan ke Dinas Sosial Kota Surabaya.',
            ),
            findsOneWidget,
          );
          expect(find.text('Kembali ke Beranda'), findsOneWidget);

          // WHEN: Pengguna menekan Kembali ke Beranda
          await tester.tap(find.text('Kembali ke Beranda'));
          await tungguTeks(tester, find.text('Beranda Uji'));

          debugPrint('BDD-LAP-04 PASS: Alur kirim dan kembali berfungsi');
        } finally {
          await tutupLayar(tester);
        }
      },
    );
  });
}