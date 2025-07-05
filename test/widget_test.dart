// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:led_control_app/main.dart';

void main() {
  testWidgets('LED Control App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LedControlApp());

    // Verify that the app title is displayed.
    expect(find.text('LED Control'), findsOneWidget);

    // Verify that LED buttons are present.
    expect(find.text('LED 1'), findsOneWidget);
    expect(find.text('LED 2'), findsOneWidget);
    expect(find.text('LED 3'), findsOneWidget);
    expect(find.text('LED 4'), findsOneWidget);
  });
}
