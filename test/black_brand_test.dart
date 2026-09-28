import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/brand_assets.dart';
import 'package:saydian_app/ui/feature_visibility.dart';

void main() {
  testWidgets('black brand lockup and app theme match the health identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: const Scaffold(body: Center(child: SaydianBrandLockup())),
      ),
    );
    expect(find.text('SAYDIAN'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.byType(SaydianBrandMark), findsOneWidget);
    expect(
      Theme.of(
        tester.element(find.byType(SaydianBrandLockup)),
      ).colorScheme.primary,
      SaydianColors.brandRed,
    );
    expect(showSaydianMall, isFalse);
  });
}
