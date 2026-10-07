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
        expect(find.byKey(const Key('ios-wellness-scope')), findsNothing);
        expect(find.text('Health library'), findsOneWidget);
        expect(find.text('Health alerts'), findsNothing);
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

  for (final language in const ['en', 'zh-Hans']) {
    testWidgets('public iOS live Health library reading in $language', (
      tester,
    ) async {
      final vault = MemorySessionVault();
      final api = GlobalSaydianApiClient(vault, locale: () => language);
      final controller = AppController(
        vault,
        api,
        MemoryHealthStore(),
        _NoHardware(),
        allowAutomaticWearableRestore: false,
      );
      addTearDown(controller.dispose);
      // Public content only: no phone vault, account, health store or hardware.
      final articles = await api.getGlobalArticles();
      await tester.pumpWidget(
        MaterialApp(
          locale: language == 'en'
              ? const Locale('en')
              : const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hans',
                ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildSaydianTheme(),
          home: ArticleCategoryPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 200),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 45),
      );
      expect(find.byKey(const Key('global-article-library')), findsOneWidget);
      final labels = AppLocalizations.of(
        tester.element(find.byType(GlobalArticleLibraryPage)),
      )!;
      if (language == 'en' && articles.isEmpty) {
        expect(
          find.text(labels.articlesEmpty).evaluate().isNotEmpty ||
              find
                  .text(labels.articleLanguageUnavailable)
                  .evaluate()
                  .isNotEmpty,
          isTrue,
        );
        expect(find.text('健康百科'), findsNothing);
      } else {
        expect(articles.isNotEmpty, isTrue);
        final article = articles.first;
        await tester.tap(
          find.byKey(ValueKey('global-article-${article['id']}')),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 200),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 45),
        );
        expect(find.byType(ArticleDetailPage), findsOneWidget);
        expect(find.text(labels.articleContentUnavailable), findsNothing);
        if (language == 'zh-Hans') {
          expect(find.textContaining('看懂睡眠报告'), findsOneWidget);
        }
      }
      expect(controller.healthRecords, isEmpty);
      expect(controller.connectedDevice, isNull);
      expect(tester.takeException(), isNull);
      debugPrint('IOS_LIBRARY_PUBLIC_QA: locale=$language reading=passed');
    });
  }
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
