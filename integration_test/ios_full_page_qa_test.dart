import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/ios_wellness_policy.dart';
import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:saydian_app/services/app_controller.dart';

import 'ios_wellness_sync_qa_test.dart' as wellness_sync;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final captureKey = GlobalKey();

  testWidgets('iOS read-only full-page QA with real-device screenshots', (
    tester,
  ) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    await GlobalLocaleController.instance.load();
    final originalLocale = GlobalLocaleController.instance.locale;
    addTearDown(
      () => GlobalLocaleController.instance.setLocale(originalLocale),
    );
    expect(
      await GlobalLocaleController.instance.setLocale(const Locale('en')),
      isTrue,
    );
    await controller.initialize();
    expect(controller.isIosWellnessEdition, isTrue);
    expect(
      controller.isAuthenticated,
      isTrue,
      reason: 'Real sign-in required; no preview substitution',
    );
    await controller.restoreWearableConnection();

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: SaydianApp(controller: controller),
      ),
    );
    await _settle(tester);
    expect(find.byKey(const Key('ios-wellness-scope')), findsNothing);
    expect(find.text('Health library'), findsOneWidget);
    expect(find.text('Health alerts'), findsNothing);
    expect(find.byKey(const Key('dashboard-ai-ask')), findsNothing);
    expect(
      controller.healthRecords.every(
        (r) => IosWellnessPolicy.metrics.contains(r.metric),
      ),
      isTrue,
    );
    await _capture(tester, binding, captureKey, '01-home');

    final notificationButton = find.byIcon(Icons.notifications_none_rounded);
    if (notificationButton.evaluate().isNotEmpty) {
      await tester.tap(notificationButton.first);
      await _settle(tester);
      await _capture(tester, binding, captureKey, '02-notifications');
      await _pop(tester);
    }

    final featureEntries = find.descendant(
      of: find.byKey(const Key('dashboard-functions')),
      matching: find.byType(InkWell),
    );
    for (final entry in const [('remote-care', 0), ('health-library', 1)]) {
      if (featureEntries.evaluate().length <= entry.$2) continue;
      await tester.tap(featureEntries.at(entry.$2));
      await _settle(tester);
      expect(find.byType(NavigationBar), findsNothing, reason: entry.$1);
      await _capture(tester, binding, captureKey, entry.$1);
      await _pop(tester);
    }

    final aiAsk = find.byKey(const Key('dashboard-ai-ask'));
    if (aiAsk.evaluate().isNotEmpty) {
      await tester.tap(aiAsk);
      await _settle(tester);
      await _capture(tester, binding, captureKey, '05-ai-chat-empty');
      await _pop(tester);
    }

    final heartRate = find.byKey(const ValueKey('health-metric-heartRate'));
    if (heartRate.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        heartRate,
        280,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(heartRate);
      await _settle(tester);
      expect(
        find.byType(NavigationBar),
        findsNothing,
        reason: 'heart-rate detail',
      );
      await _capture(tester, binding, captureKey, '06-heart-rate-detail');
      for (final period in const [
        ['周', 'Week'],
        ['月', 'Month'],
        ['年', 'Year'],
      ]) {
        final option = _firstText(period);
        if (option.evaluate().isEmpty) continue;
        await tester.tap(option.first);
        await _settle(tester);
        await _capture(
          tester,
          binding,
          captureKey,
          '06-heart-rate-${period.last.toLowerCase()}',
        );
      }
      await _pop(tester);
    }

    for (final metric in const [
      ('steps', 'health-metric-steps'),
      ('distance', 'health-metric-distance'),
      ('calories', 'health-metric-calories'),
      ('sleep', 'health-metric-sleep'),
    ]) {
      final card = find.byKey(Key(metric.$2));
      if (card.evaluate().isEmpty) continue;
      await tester.scrollUntilVisible(
        card,
        280,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(card);
      await _settle(tester);
      expect(find.byType(NavigationBar), findsNothing, reason: metric.$1);
      await _capture(tester, binding, captureKey, '06-${metric.$1}-detail');
      await _pop(tester);
    }

    final allData = _firstText(['全部数据', 'All data']);
    if (allData.evaluate().isNotEmpty) {
      await _tapText(tester, allData.first);
      await _settle(tester);
      expect(
        find.byType(NavigationBar),
        findsNothing,
        reason: 'all health data',
      );
      await _capture(tester, binding, captureKey, '07-all-health-data');
      for (final row in const [
        ('steps', ['Steps', '步数']),
        ('distance', ['Distance', '距离']),
        ('calories', ['Calories', '热量']),
        ('sleep', ['Sleep', '睡眠']),
      ]) {
        final item = _firstText(row.$2);
        if (item.evaluate().isEmpty) continue;
        await _tapText(tester, item.first);
        await _settle(tester);
        expect(find.byType(NavigationBar), findsNothing, reason: row.$1);
        await _capture(tester, binding, captureKey, '07-history-${row.$1}');
        await _pop(tester);
      }
      await _pop(tester);
    }

    final sportPanel = find.byKey(const Key('health-sport-entries'));
    if (sportPanel.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        sportPanel,
        280,
        scrollable: find.byType(Scrollable).first,
      );
      await _capture(tester, binding, captureKey, '08-sports-entry');
      final records = _firstText(['运动记录', 'Workout records']);
      if (records.evaluate().isNotEmpty) {
        await _tapText(tester, records.first);
        await _settle(tester);
        expect(
          find.byType(NavigationBar),
          findsNothing,
          reason: 'sports records',
        );
        await _capture(tester, binding, captureKey, '08-sports-records');
        await _pop(tester);
      }
    }

    controller.selectTab(1);
    await _settle(tester);
    await _capture(tester, binding, captureKey, '09-device');
    final deviceAbout = _firstText(['关于设备', 'About this watch']);
    if (deviceAbout.evaluate().isNotEmpty) {
      await _tapText(tester, deviceAbout.first);
      await _settle(tester);
      expect(find.byType(NavigationBar), findsNothing, reason: 'device info');
      await _capture(tester, binding, captureKey, '09-device-info');
      await _pop(tester);
    }
    final search = _firstText([
      '开始搜索',
      'Start searching',
      '添加设备',
      'Add device',
    ]);
    if (search.evaluate().isNotEmpty) {
      await _tapText(tester, search.first);
      await _settle(tester);
      expect(find.byType(NavigationBar), findsNothing, reason: 'device search');
      await _capture(tester, binding, captureKey, '09-device-search');
      await _pop(tester);
    }
    for (final feature in const [
      ('display', 'Display'),
      ('watch-settings', 'Settings'),
      ('connection-help', 'Connection help'),
    ]) {
      final target = _firstText([feature.$2]);
      if (target.evaluate().isEmpty) continue;
      await _tapText(tester, target.first);
      await _settle(tester);
      expect(find.byType(NavigationBar), findsNothing, reason: feature.$1);
      await _capture(tester, binding, captureKey, '09-${feature.$1}');
      await _pop(tester);
    }

    controller.selectTab(2);
    await _settle(tester);
    await _capture(tester, binding, captureKey, '10-profile-services');

    final profileCard = find.byKey(const Key('my-page'));
    if (profileCard.evaluate().isNotEmpty) {
      final editIcon = find.byIcon(Icons.edit_outlined);
      if (editIcon.evaluate().isNotEmpty) {
        debugPrint('REAL_DEVICE_STEP: opening-profile-editor');
        await tester.tap(editIcon.first).timeout(const Duration(seconds: 20));
        await _settle(tester);
        await _capture(tester, binding, captureKey, '10-profile-edit');
        debugPrint('REAL_DEVICE_STEP: closing-profile-editor');
        await _pop(tester);
      }
    }

    final serviceEntries = <(String, List<String>)>[
      ('unit-settings', ['单位设置', 'Units']),
      ('account-settings', ['账号设置', 'Account settings']),
      ('permissions', ['权限管理', 'Permissions']),
      ('feedback', ['帮助与反馈', 'Help & feedback', 'Help and feedback']),
      ('customer-service', ['联系客服', 'Customer support']),
      ('about', ['关于我们', 'About SAYDIAN Health']),
    ];
    for (final entry in serviceEntries) {
      final target = _firstText(entry.$2);
      if (target.evaluate().isEmpty) continue;
      await _tapText(tester, target.first);
      await _settle(tester);
      expect(find.byType(NavigationBar), findsNothing, reason: entry.$1);
      await _capture(tester, binding, captureKey, '10-${entry.$1}');

      if (entry.$1 == 'about') {
        for (final legal in const [
          ('privacy', ['隐私政策', 'Privacy policy', 'Privacy Policy']),
          ('terms', ['用户协议', 'Terms of service', 'Terms of Service']),
        ]) {
          final link = _firstText(legal.$2);
          if (link.evaluate().isEmpty) continue;
          await _tapText(tester, link.first);
          await _settle(tester);
          expect(find.byType(NavigationBar), findsNothing, reason: legal.$1);
          await _capture(tester, binding, captureKey, '10-legal-${legal.$1}');
          await _pop(tester);
        }
      }
      await _pop(tester);
    }

    final unit = _firstText(['单位设置', 'Units']);
    if (unit.evaluate().isNotEmpty) {
      await _tapText(tester, unit.first);
      await _settle(tester);
      await _capture(tester, binding, captureKey, '10-unit-settings');
      await _pop(tester);
    }

    final language = find.byKey(const Key('settings-language'));
    if (language.evaluate().isNotEmpty) {
      await tester.ensureVisible(language);
      await tester.tap(language);
      await _settle(tester);
      await _capture(tester, binding, captureKey, '10-language-picker');
      final cancel = _firstText(['取消', 'Cancel']);
      if (cancel.evaluate().isNotEmpty) await tester.tap(cancel.first);
      await _settle(tester);
    }

    expect(tester.takeException(), isNull);
  });
  wellness_sync.main();
}

Finder _firstText(List<String> values) {
  for (final value in values) {
    final finder = find.text(value);
    if (finder.evaluate().isNotEmpty) return finder;
  }
  return find.byWidgetPredicate((_) => false);
}

Future<void> _tapText(WidgetTester tester, Finder text) async {
  await Scrollable.ensureVisible(tester.element(text), alignment: 0.4);
  // Scroll position changes require layout before a real-device hit test.
  await tester.pump();
  for (final type in const [TextButton, ListTile, InkWell]) {
    final action = find.ancestor(of: text, matching: find.byType(type));
    if (action.evaluate().isNotEmpty) {
      await tester.tap(action.first);
      return;
    }
  }
  await tester.tap(text);
}

Future<void> _settle(WidgetTester tester) async {
  // Real sync/progress indicators can legitimately animate indefinitely.
  // Wait for route transitions, not for every background animation to stop.
  // Page/state assertions and the independent sync test still must succeed.
  for (var frame = 0; frame < 15; frame++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(tester.takeException(), isNull);
}

Future<void> _capture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  GlobalKey key,
  String name,
) async {
  debugPrint('REAL_DEVICE_PAGE: $name');
  await tester.pump(const Duration(seconds: 2));
  final renderObject = key.currentContext!.findRenderObject();
  final boundary = renderObject! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    binding.reportData ??= <String, dynamic>{};
    final screenshots = binding.reportData!['screenshots'] ??= <dynamic>[];
    (screenshots as List<dynamic>).add(<String, dynamic>{
      'screenshotName': name,
      'bytes': bytes,
    });
  } finally {
    image.dispose();
  }
}

Future<void> _pop(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await _settle(tester);
}
