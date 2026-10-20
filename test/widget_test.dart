import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:housing_mobile/main.dart';

void main() {
  testWidgets('App starts and renders the dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const HousingMobileApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
