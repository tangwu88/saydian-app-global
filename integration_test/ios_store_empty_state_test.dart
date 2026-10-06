import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';

/// Public-safe illustrations of the actual production page widgets before a
/// first sync. This test host does not read the phone's vault/database, claim a
/// successful login/watch connection, or manufacture health/capability values.
/// Keep separate from the authenticated real-watch acceptance suite.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('public iOS production UI empty-state screenshots', (
    tester,
  ) async {
    final vault = MemorySessionVault();
    final controller = AppController(
      vault,
      GlobalSaydianApiClient(vault),
      MemoryHealthStore(),
      _NoHardware(),
      allowAutomaticWearableRestore: false,
    );
    addTearDown(controller.dispose);
    final locale = GlobalLocaleController(
      initialLocale: const Locale('en'),
      store: _MemoryLocale(),
    );
    addTearDown(locale.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: GlobalLocaleScope(
          controller: locale,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildSaydianTheme(),
            home: AnimatedBuilder(
              animation: controller,
              builder: (_, _) => AppShell(controller: controller),
            ),
          ),
        ),
      ),
    );
    for (final page in const [
      (0, '01-activity-sleep-empty'),
      (1, '02-connect-watch'),
    ]) {
      controller.selectTab(page.$1);
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(controller.healthRecords, isEmpty);
      expect(controller.connectedDevice, isNull);
      expect(controller.memberProfile, isEmpty);
      expect(find.byKey(const Key('dashboard-ai-ask')), findsNothing);
      if (page.$1 == 0) {
        expect(find.byKey(const Key('ios-wellness-scope')), findsOneWidget);
      } else {
        expect(find.byType(AppBar), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        binding.reportData ??= <String, dynamic>{};
        final shots = binding.reportData!['screenshots'] ??= <dynamic>[];
        (shots as List<dynamic>).add(<String, dynamic>{
          'screenshotName': page.$2,
          'bytes': data!.buffer.asUint8List(),
        });
      } finally {
        image.dispose();
      }
    }
  });
}

class _NoHardware implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Public screenshots must not operate real hardware');
}

class _MemoryLocale implements GlobalLocaleStore {
  @override
  Future<String?> read() async => 'en';

  @override
  Future<void> write(String value) async {}
}
