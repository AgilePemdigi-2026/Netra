
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LokasiNetra {
  final String namaJalan;
  final String detailAlamat;

  const LokasiNetra({
    required this.namaJalan,
    required this.detailAlamat,
  });
}

class LocationService {
  final Geocoding _geocoding = Geocoding();

  Future<bool> mintaIzinLokasi() async {
    final layananAktif =
        await Geolocator.isLocationServiceEnabled();

    if (!layananAktif) {
      throw Exception(
        'GPS HP belum aktif. Nyalakan Lokasi di pengaturan HP.',
      );
    }

    var izin = await Geolocator.checkPermission();

    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }

    if (izin == LocationPermission.denied) {
      throw Exception('Izin lokasi belum diberikan.');
    }

    if (izin == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi diblokir. Aktifkan melalui pengaturan aplikasi NETRA.',
      );
    }

    return true;
  }

  Future<Position> posisiSekarang() async {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Stream<Position> pantauPosisi() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }

  Future<LokasiNetra> cariAlamat(Position posisi) async {
    final daftar = await _geocoding.placemarkFromCoordinates(
      posisi.latitude,
      posisi.longitude,
      locale: const Locale('id', 'ID'),
    );

    if (daftar.isEmpty) {
      throw Exception('Alamat belum ditemukan.');
    }

    final tempat = daftar.first;

    final jalan = [
      tempat.street,
      tempat.thoroughfare,
    ].whereType<String>().firstWhere(
      (teks) => teks.trim().isNotEmpty,
      orElse: () => 'Nama jalan belum tersedia',
    );

    final detail = [
      tempat.subLocality,
      tempat.locality,
      tempat.subAdministrativeArea,
      tempat.administrativeArea,
    ].whereType<String>()
        .where((teks) => teks.trim().isNotEmpty)
        .toSet()
        .join(', ');

    return LokasiNetra(
      namaJalan: jalan,
      detailAlamat: detail,
    );
  }

  double jarakMeter(Position awal, Position akhir) {
    return Geolocator.distanceBetween(
      awal.latitude,
      awal.longitude,
      akhir.latitude,
      akhir.longitude,
    );
  }

  Future<void> bukaPengaturanAplikasi() async {
    await Geolocator.openAppSettings();
  }

  Future<void> bukaPengaturanLokasi() async {
    await Geolocator.openLocationSettings();
  }
}
