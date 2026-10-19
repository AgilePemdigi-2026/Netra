import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder: WAITING FOR IMPLEMENTATION',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Netra'))),
    );

    expect(find.text('Netra'), findsOneWidget);
  });
}