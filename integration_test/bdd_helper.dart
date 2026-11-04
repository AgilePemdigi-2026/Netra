import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Menggulir ke [finder], lalu menekannya.
Future<void> tekan(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Membuang layar yang sedang dibuka agar kamera/TTS/mikrofon
/// dilepas sebelum test berikutnya.
Future<void> tutupLayar(WidgetTester tester, {int detik = 1}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration(seconds: detik));
}