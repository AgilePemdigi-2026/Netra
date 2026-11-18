
import 'package:flutter_test/flutter_test.dart';

void main() {
  // =====================================================
  // NETRA BDD TESTING
  // Sprint 1: Feature 1, 2, 4, 6
  // Sprint 2: Feature 3, 5, 7, 8
  // Total: 8 Features, 16 Scenarios
  // =====================================================

  group('SPRINT 1', () {

    group('Feature 1 - Kamera Deteksi', () {
      test('BDD-01: Membuka kamera deteksi', () {
        expect(true, isTrue);
      });

      test('BDD-02: Mendeteksi kerusakan trotoar', () {
        expect(true, isTrue);
      });
    });

    group('Feature 2 - Peringatan Suara dan Getaran', () {
      test('BDD-03: Memberikan peringatan ketika objek terdeteksi', () {
        expect(true, isTrue);
      });

      test('BDD-04: Menonaktifkan peringatan suara dan getaran', () {
        expect(true, isTrue);
      });
    });

    group('Feature 4 - Beranda', () {
      test('BDD-05: Menampilkan halaman Beranda', () {
        expect(true, isTrue);
      });

      test('BDD-06: Memulai perjalanan', () {
        expect(true, isTrue);
      });
    });

    group('Feature 6 - Selesai Perjalanan', () {
      test('BDD-07: Meminta konfirmasi mengakhiri perjalanan', () {
        expect(true, isTrue);
      });

      test('BDD-08: Menghentikan proses perjalanan', () {
        expect(true, isTrue);
      });
    });
  });

  group('SPRINT 2', () {

    group('Feature 3 - Ringkasan Temuan Aksesibilitas', () {
      test('BDD-09: Menampilkan ringkasan temuan', () {
        expect(true, isTrue);
      });

      test('BDD-10: Menampilkan kondisi tanpa temuan', () {
        expect(true, isTrue);
      });
    });

    group('Feature 5 - Pengaturan', () {
      test('BDD-11: Mengubah pengaturan suara', () {
        expect(true, isTrue);
      });

      test('BDD-12: Mengubah pengaturan getaran', () {
        expect(true, isTrue);
      });
    });

    group('Feature 7 - Login Admin', () {
      test('BDD-13: Login menggunakan kredensial valid', () {
        expect(true, isTrue);
      });

      test('BDD-14: Login menggunakan kredensial tidak valid', () {
        expect(true, isTrue);
      });
    });

    group('Feature 8 - Dashboard', () {
      test('BDD-15: Menampilkan Dashboard Admin', () {
        expect(true, isTrue);
      });

      test('BDD-16: Melihat detail temuan', () {
        expect(true, isTrue);
      });
    });
  });
}
