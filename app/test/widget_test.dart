import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vanij/core/theme/app_theme.dart';

void main() {
  testWidgets('VanijErrorBanner renders its message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VanijErrorBanner(message: 'Example error')),
      ),
    );
    expect(find.text('Example error'), findsOneWidget);
  });
}
