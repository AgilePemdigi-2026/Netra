import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:netra_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pengujian Integrasi NETRA', () {
    testWidgets('Aplikasi NETRA berhasil dibuka', (WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(MaterialApp), findsOneWidget);

      print('PASS: Aplikasi NETRA berhasil dibuka');
    });
  });
}
