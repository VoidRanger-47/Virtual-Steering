import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VCtrlApp());
    // Just verify the app builds without throwing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
