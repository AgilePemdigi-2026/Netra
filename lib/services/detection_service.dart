
import 'package:flutter/foundation.dart';

// ==========================================
// MODEL HASIL DETEKSI OBJEK NETRA
// ==========================================

class ObjekTerdeteksi {
  final String namaObjek;
  final double confidence;

  // Koordinat bounding box hasil model AI.
  // Nilai dinormalisasi dari 0.0 sampai 1.0.
  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;

  const ObjekTerdeteksi({
    required this.namaObjek,
    required this.confidence,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  // Confidence ditampilkan dalam persen.
  String get confidencePersen {
    return '${(confidence * 100).toStringAsFixed(1)}%';
  }
}

// ==========================================
// SERVICE PENGOLAHAN DETEKSI NETRA
// ==========================================

class DetectionService {
  // Batas minimal confidence model.
  static const double minimumConfidence = 0.50;

  // Memfilter hasil deteksi berdasarkan confidence.
  List<ObjekTerdeteksi> filterDeteksi(
    List<ObjekTerdeteksi> hasil,
  ) {
    return hasil.where((objek) {
      return objek.confidence >= minimumConfidence;
    }).toList();
  }

  // Membuat deskripsi objek dalam bahasa Indonesia.
  String namaObjekIndonesia(String nama) {
    final namaLower = nama.toLowerCase();

    const terjemahan = {
      'person': 'Orang',
      'car': 'Mobil',
      'motorcycle': 'Motor',
      'bicycle': 'Sepeda',
      'bus': 'Bus',
      'truck': 'Truk',
      'chair': 'Kursi',
      'bench': 'Bangku',
      'dog': 'Anjing',
      'cat': 'Kucing',
      'traffic light': 'Lampu Lalu Lintas',
      'stop sign': 'Rambu Berhenti',
    };

    return terjemahan[namaLower] ?? nama;
  }

  // Membuat kalimat informasi suara.
  String buatPesanDeteksi(ObjekTerdeteksi objek) {
    final nama = namaObjekIndonesia(objek.namaObjek);

    return 'Perhatian. Terdeteksi $nama '
        'di area kamera.';
  }

  // Memilih objek dengan confidence tertinggi.
  ObjekTerdeteksi? objekConfidenceTertinggi(
    List<ObjekTerdeteksi> hasil,
  ) {
    final objekValid = filterDeteksi(hasil);

    if (objekValid.isEmpty) {
      return null;
    }

    objekValid.sort(
      (a, b) => b.confidence.compareTo(a.confidence),
    );

    return objekValid.first;
  }

  // Menampilkan informasi debugging.
  void tampilkanHasil(List<ObjekTerdeteksi> hasil) {
    for (final objek in filterDeteksi(hasil)) {
      debugPrint(
        'NETRA mendeteksi: '
        '${namaObjekIndonesia(objek.namaObjek)} '
        '| Confidence: ${objek.confidencePersen}',
      );
    }
  }
}
