import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'package:netra_app/screens/pengguna/kamera_screen.dart';

import 'bdd_helper.dart';

Future<void> bukaKamera(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: KameraScreen(),
    ),
  );

  await tungguTeks(tester, find.text('Perjalanan Aktif'));
}

/// Membuka KameraScreen, menjalankan [isi], lalu selalu menutup layar
/// agar kamera dilepas walaupun test gagal.
Future<void> denganKamera(
  WidgetTester tester,
  Future<void> Function() isi,
) async {
  await bukaKamera(tester);

  try {
    await isi();
  } finally {
    await tutupLayar(tester, detik: 2);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BDD - Kamera Deteksi NETRA', () {
    testWidgets(
      'BDD-KAM-01: Layar kamera deteksi tampil dalam keadaan aktif',
      (WidgetTester tester) async {
        await denganKamera(tester, () async {
          // GIVEN: Izin kamera dan lokasi sudah diberikan (lewat ADB)
          // WHEN: Pengguna membuka Kamera Deteksi
          // THEN: Tampilan kamera dan panel informasi muncul
          expect(find.byType(YOLOView), findsOneWidget);
          expect(find.text('Perjalanan Aktif'), findsOneWidget);
          expect(find.text('SUARA NETRA'), findsOneWidget);
          expect(find.text('Voice'), findsOneWidget);
          expect(find.text('Getar'), findsOneWidget);
          expect(find.text('LOKASI SEKARANG'), findsOneWidget);
          expect(find.text('Jarak Tempuh'), findsOneWidget);
          expect(find.text('Durasi Navigasi'), findsOneWidget);
          expect(find.text('Akhiri Perjalanan'), findsOneWidget);

          debugPrint('BDD-KAM-01 PASS: Layar Kamera Deteksi tampil aktif');
        });
      },
    );

    testWidgets(
      'BDD-KAM-02: Pengguna menonaktifkan dan mengaktifkan suara',
      (WidgetTester tester) async {
        await denganKamera(tester, () async {
          // GIVEN: Suara aktif
          expect(find.text('SUARA NETRA'), findsOneWidget);

          // WHEN: Pengguna menekan Voice
          await tekan(tester, find.text('Voice'));

          // THEN: Status berubah menjadi suara dinonaktifkan
          await tungguTeks(tester, find.text('SUARA DINONAKTIFKAN'));

          // WHEN: Ditekan lagi
          await tekan(tester, find.text('Voice'));

          // THEN: Suara aktif kembali
          await tungguTeks(tester, find.text('SUARA NETRA'));

          debugPrint('BDD-KAM-02 PASS: Toggle suara berfungsi');
        });
      },
    );
  });

  group('BDD - Selesai Perjalanan NETRA', () {
    testWidgets(
      'BDD-SEL-01: Sistem meminta konfirmasi untuk mengakhiri perjalanan',
      (WidgetTester tester) async {
        await denganKamera(tester, () async {
          // GIVEN: Perjalanan sedang aktif
          // WHEN: Pengguna menekan Akhiri Perjalanan
          await tekan(tester, find.text('Akhiri Perjalanan'));

          // THEN: Perjalanan dijeda dan konfirmasi tampil
          await tungguTeks(tester, find.text('Perjalanan Dijeda'));
          expect(find.text('Kamera Deteksi Dijeda'), findsOneWidget);
          expect(
            find.text('Apakah Anda ingin mengakhiri perjalanan?'),
            findsOneWidget,
          );
          expect(find.text('Ya, Akhiri'), findsOneWidget);
          expect(find.text('Tidak, Lanjutkan'), findsOneWidget);
          expect(find.text('Data Terkumpul'), findsOneWidget);
          expect(find.textContaining('Rintangan'), findsOneWidget);

          debugPrint('BDD-SEL-01 PASS: Konfirmasi akhiri perjalanan tampil');
        });
      },
    );

    testWidgets(
      'BDD-SEL-02: Pengguna membatalkan pengakhiran perjalanan',
      (WidgetTester tester) async {
        await denganKamera(tester, () async {
          // GIVEN: Konfirmasi akhiri perjalanan sedang tampil
          await tekan(tester, find.text('Akhiri Perjalanan'));
          await tungguTeks(tester, find.text('Perjalanan Dijeda'));

          // WHEN: Pengguna menekan Tidak, Lanjutkan
          await tekan(tester, find.text('Tidak, Lanjutkan'));

          // THEN: Perjalanan aktif kembali
          await tungguTeks(tester, find.text('Perjalanan Aktif'));
          expect(find.text('Perjalanan Dijeda'), findsNothing);
          expect(find.text('Akhiri Perjalanan'), findsOneWidget);

          debugPrint('BDD-SEL-02 PASS: Perjalanan dilanjutkan setelah batal');
        });
      },
    );

    testWidgets(
      'BDD-SEL-03: Pengguna mengonfirmasi pengakhiran perjalanan',
      (WidgetTester tester) async {
        await denganKamera(tester, () async {
          // GIVEN: Konfirmasi akhiri perjalanan sedang tampil
          await tekan(tester, find.text('Akhiri Perjalanan'));
          await tungguTeks(tester, find.text('Perjalanan Dijeda'));

          // WHEN: Pengguna menekan Ya, Akhiri
          await tekan(tester, find.text('Ya, Akhiri'));

          // THEN: Pengguna dibawa ke Laporan Perjalanan
          // (di aplikasi saat ini bukan ke Beranda seperti di BAB 3)
          await tungguTeks(
            tester,
            find.text('Laporan Perjalanan'),
            maksDetik: 20,
          );
          expect(find.text('Perjalanan Dijeda'), findsNothing);

          debugPrint('BDD-SEL-03 PASS: Perjalanan diakhiri, Laporan tampil');
        });
      },
    );
  });
}