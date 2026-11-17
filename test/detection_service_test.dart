import 'package:flutter_test/flutter_test.dart';
import 'package:netra_app/services/detection_service.dart';

void main() {
  late DetectionService service;

  setUp(() {
    service = DetectionService();
  });

  ObjekTerdeteksi buatObjek(String nama, double confidence) {
    return ObjekTerdeteksi(
      namaObjek: nama,
      confidence: confidence,
      xMin: 0.1,
      yMin: 0.1,
      xMax: 0.5,
      yMax: 0.5,
    );
  }

  group('Pengujian DetectionService', () {
    test('Menyaring objek dengan confidence minimal 50%', () {
      final hasil = [
        buatObjek('person', 0.90),
        buatObjek('car', 0.40),
        buatObjek('motorcycle', 0.50),
      ];

      final hasilValid = service.filterDeteksi(hasil);

      expect(hasilValid.length, 2);
      expect(
        hasilValid.map((e) => e.namaObjek),
        containsAll(['person', 'motorcycle']),
      );
    });

    test('Menerjemahkan nama objek ke bahasa Indonesia', () {
      expect(service.namaObjekIndonesia('person'), 'Orang');
      expect(service.namaObjekIndonesia('car'), 'Mobil');
      expect(service.namaObjekIndonesia('motorcycle'), 'Motor');
    });

    test('Membuat pesan informasi deteksi', () {
      final objek = buatObjek('person', 0.90);

      final pesan = service.buatPesanDeteksi(objek);

      expect(pesan, 'Perhatian. Terdeteksi Orang di area kamera.');
    });

    test('Memilih objek dengan confidence tertinggi', () {
      final hasil = [
        buatObjek('person', 0.70),
        buatObjek('car', 0.95),
        buatObjek('motorcycle', 0.80),
      ];

      final objek = service.objekConfidenceTertinggi(hasil);

      expect(objek?.namaObjek, 'car');
      expect(objek?.confidence, 0.95);
    });

    test('Mengembalikan null jika tidak ada deteksi valid', () {
      final hasil = [buatObjek('person', 0.30), buatObjek('car', 0.40)];

      final objek = service.objekConfidenceTertinggi(hasil);

      expect(objek, isNull);
    });
  });
}
