import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/app_update_gate_scope.dart';
import 'package:saydian_app/ui/prototype_pages.dart';

void main() {
  test('feature availability always has plain user copy', () {
    expect(
      const FeatureAvailability(FeatureAvailabilityStatus.needsDevice).message,
      '连接手表后使用',
    );
    expect(
      const FeatureAvailability(
        FeatureAvailabilityStatus.needsPermission,
      ).message,
      '允许相关权限后使用',
    );
    expect(
      const FeatureAvailability(
        FeatureAvailabilityStatus.unsupportedDevice,
      ).message,
      '当前手表不支持此功能',
    );
    expect(
      const FeatureAvailability(
        FeatureAvailabilityStatus.serviceUnavailable,
      ).message,
      '请在手表上操作',
    );
  });

  test('device capabilities map health and device features independently', () {
    final capabilities = DeviceCapabilities.fromMap(const {
      'metrics': ['heart_rate', 'blood_glucose'],
      'features': ['find_watch', 'screen_display', 'contacts'],
      'integratedFeatures': ['find_watch', 'screen_display'],
    });
    expect(capabilities.supports(HealthMetric.heartRate), isTrue);
    expect(capabilities.supports(HealthMetric.bloodGlucose), isTrue);
    expect(capabilities.supportsFeature(DeviceFeature.contacts), isTrue);
    expect(
      capabilities.integratedFeatures,
      containsAll([DeviceFeature.findWatch, DeviceFeature.screenDisplay]),
    );
  });

  testWidgets('disconnected device page shows only connection guidance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicePage(controller: controller)),
      ),
    );

    expect(find.text('添加智能设备'), findsOneWidget);
    expect(find.text('连接说明'), findsOneWidget);
    expect(find.text('表盘中心'), findsNothing);
    expect(find.text('查找手表'), findsNothing);
    expect(find.text('联系人'), findsNothing);
    expect(find.text('健康提醒'), findsNothing);
    expect(find.text('屏幕显示'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'device page shows only hardware and app capability intersection',
    (tester) async {
      final controller = _controller()
        ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'Test Watch')
        ..deviceCapabilityState = DeviceCapabilityState.ready
        ..capabilities = const DeviceCapabilities(
          metrics: {HealthMetric.heartRate},
          features: {
            DeviceFeature.findWatch,
            DeviceFeature.camera,
            DeviceFeature.weather,
          },
          integratedFeatures: {DeviceFeature.findWatch, DeviceFeature.weather},
        );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DevicePage(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.deviceCapabilityState, DeviceCapabilityState.ready);
      expect(
        controller.visibleDeviceFeatures,
        contains(DeviceFeature.findWatch),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();

      expect(find.text('查找手表'), findsOneWidget);
      expect(find.text('天气'), findsOneWidget);
      expect(find.text('点击进入'), findsNothing);
      expect(find.text('相机遥控'), findsNothing);
      expect(find.text('表盘与个性化'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'connected and about-device pages hide technical routing labels',
    (tester) async {
      final controller = _controller()
        ..connectedDevice = const DeviceInfo(
          id: 'veepoo:watch-1',
          name: 'SD-Watch-W9S',
          model: 'W9S',
        );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DevicePage(controller: controller)),
        ),
      );
      await tester.pump();
      expect(find.text('Vep'), findsNothing);
      expect(find.text('Yuc'), findsNothing);
      expect(find.textContaining('MAC ·'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(home: DeviceInfoPage(controller: controller)),
      );
      await tester.pump();
      expect(find.text('连接状态'), findsOneWidget);
      expect(find.text('已连接'), findsOneWidget);
      expect(find.textContaining('设备服务'), findsNothing);
    },
  );

  testWidgets('US watch details use English battery and connection labels', (
    tester,
  ) async {
    final controller = _controller()
      ..connectedDevice = DeviceInfo(
        id: 'urion:watch-1',
        name: 'U19S',
        battery: DeviceBatteryInfo(
          value: 3,
          scale: 4,
          isPercent: false,
          chargeState: DeviceBatteryChargeState.normal,
          updatedAt: DateTime.utc(2026, 9, 28, 12),
        ),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeviceInfoPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('not charging'), findsOneWidget);
    expect(find.textContaining('Updated '), findsOneWidget);
    expect(find.text('Device ID'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Watch battery 3 of 4 bars, not charging',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('device sync gives a clear completion message', (tester) async {
    final controller =
        AppController(
            MemorySessionVault(),
            _CoverageApi(),
            MemoryHealthStore(),
            _FeatureWearable(),
          )
          ..isBooting = false
          ..connectedDevice = const DeviceInfo(
            id: 'veepoo:watch-1',
            name: 'Test Watch',
          )
          ..deviceCapabilityState = DeviceCapabilityState.ready
          ..capabilities = const DeviceCapabilities(
            metrics: {HealthMetric.heartRate},
            features: {DeviceFeature.findWatch},
            integratedFeatures: {DeviceFeature.findWatch},
          );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DevicePage(controller: controller)),
      ),
    );
    await tester.tap(find.text('Sync watch'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Watch readings received. Online backup is checked separately.',
      ),
      findsOneWidget,
    );
    expect(find.text('Data synced'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'device capability loading and failure never reveal guessed features',
    (tester) async {
      final controller = _controller()
        ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'Test Watch')
        ..deviceCapabilityState = DeviceCapabilityState.loading;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: controller,
            builder: (_, _) =>
                Scaffold(body: DevicePage(controller: controller)),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('device-capabilities-loading')),
        findsOneWidget,
      );
      expect(find.text('查找手表'), findsNothing);

      controller.deviceCapabilityState = DeviceCapabilityState.unavailable;
      controller.notifyListeners();
      await tester.pump();
      expect(
        find.byKey(const Key('device-capabilities-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('device-capabilities-retry')),
        findsOneWidget,
      );
      expect(find.text('查找手表'), findsNothing);
    },
  );

  testWidgets(
    'late native capability update refreshes visible device features',
    (tester) async {
      final wearable = _EventCoverageWearable();
      final controller = AppController(
        MemorySessionVault(),
        _CoverageApi(),
        MemoryHealthStore(),
        wearable,
      );
      await controller.initialize();
      addTearDown(() async {
        controller.dispose();
        await wearable.close();
      });
      await controller.connectDevice(
        const DeviceInfo(id: 'watch-1', name: 'Test Watch'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: controller,
            builder: (_, _) =>
                Scaffold(body: DevicePage(controller: controller)),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('device-capabilities-unavailable')),
        findsOneWidget,
      );

      wearable.emit(
        WearableEvent(
          type: 'capabilitiesUpdated',
          payload: const DeviceCapabilities(
            metrics: {HealthMetric.heartRate},
            features: {DeviceFeature.findWatch, DeviceFeature.camera},
            integratedFeatures: {DeviceFeature.findWatch},
          ).toJson(),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.deviceCapabilityState, DeviceCapabilityState.ready);
      expect(
        controller.visibleDeviceFeatures,
        contains(DeviceFeature.findWatch),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();

      expect(find.text('查找手表'), findsOneWidget);
      expect(find.text('相机遥控'), findsNothing);
      expect(
        find.byKey(const Key('device-capabilities-unavailable')),
        findsNothing,
      );
      controller.setAppForeground(false);
    },
  );

  testWidgets('app-only device gaps direct the user to the watch', (
    tester,
  ) async {
    final controller = _controller()
      ..connectedDevice = const DeviceInfo(
        id: 'watch-only-1',
        name: 'Test Watch',
      )
      ..capabilities = const DeviceCapabilities(
        metrics: {},
        features: {DeviceFeature.phoneCalls},
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.phoneCalls,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('请在手表上操作'), findsOneWidget);
    expect(find.text('当前手表不支持此功能'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected device feature pages render real controls', (
    tester,
  ) async {
    final wearable = _FeatureWearable();
    final controller = AppController(
      MemorySessionVault(),
      _CoverageApi(),
      MemoryHealthStore(),
      wearable,
    )..isBooting = false;
    addTearDown(controller.dispose);
    await controller.connectDevice(
      const DeviceInfo(id: 'veepoo:WATCH:01', name: 'Test Watch', model: 'JL'),
    );
    expect(controller.connectedDevice?.sdkSource, WearableSdkSource.veepoo);

    final cases = <DeviceFeature, String>{
      DeviceFeature.watchFaces: '系统表盘 1',
      DeviceFeature.photoWatchFace: '点击选择照片',
      DeviceFeature.notifications: '还需允许手机通知权限',
      DeviceFeature.alarms: '添加闹钟',
      DeviceFeature.contacts: '添加联系人',
      DeviceFeature.weather: '更新当前位置天气',
      DeviceFeature.worldClock: '添加城市',
      DeviceFeature.healthReminders: '久坐提醒',
      DeviceFeature.healthAssessment: '压力评估',
    };
    for (final entry in cases.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceFeaturePage(
            controller: controller,
            feature: entry.key,
            key: ValueKey(entry.key),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key.name);
      expect(find.textContaining('设备服务'), findsNothing);
      if (entry.key == DeviceFeature.notifications) {
        expect(find.text('微信'), findsOneWidget);
        expect(find.text('短信'), findsOneWidget);
        expect(find.text('钉钉'), findsNothing);
        expect(find.text('企业微信'), findsNothing);
        expect(find.text('当前手表不支持此项'), findsNothing);
      }
      if (entry.key == DeviceFeature.watchFaces) {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == '系统表盘 1预览暂不可用',
          ),
          findsOneWidget,
        );
      }
    }
    controller.setAppForeground(false);
  });

  for (final interval in [15, 180]) {
    testWidgets(
      'health reminder editor accepts $interval minute device value',
      (tester) async {
        final wearable = _FeatureWearable(healthReminderInterval: interval);
        final controller = AppController(
          MemorySessionVault(),
          _CoverageApi(),
          MemoryHealthStore(),
          wearable,
        )..isBooting = false;
        addTearDown(controller.dispose);
        await controller.connectDevice(
          const DeviceInfo(
            id: 'veepoo:WATCH:01',
            name: 'Test Watch',
            model: 'JL',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DeviceFeaturePage(
              controller: controller,
              feature: DeviceFeature.healthReminders,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('久坐提醒'));
        await tester.pumpAndSettle();

        expect(find.text('$interval 分钟'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        controller.setAppForeground(false);
      },
    );
  }

  testWidgets('feature page defers device reads until after its first frame', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _CoverageApi(),
      MemoryHealthStore(),
      _FeatureWearable(),
    )..isBooting = false;
    addTearDown(controller.dispose);
    await controller.connectDevice(
      const DeviceInfo(id: 'yucheng:WATCH:01', name: 'Test Watch', model: 'JL'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, _) => DeviceFeaturePage(
            controller: controller,
            feature: DeviceFeature.screenDisplay,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    controller.setAppForeground(false);
  });

  testWidgets('US watch display settings use readable labels and local time', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _CoverageApi(),
      MemoryHealthStore(),
      _UsScreenWearable(),
    )..isBooting = false;
    addTearDown(controller.dispose);
    await controller.connectDevice(
      const DeviceInfo(id: 'urion:watch-1', name: 'U19S'),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.screenDisplay,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Brightness'), findsOneWidget);
    expect(find.textContaining('Raise-to-wake sensitivity'), findsOneWidget);
    expect(find.textContaining('8:00 AM'), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.setAppForeground(false);
  });

  for (final source in ['yucheng', 'urion']) {
    testWidgets('$source find watch is one-shot and never sends a fake stop', (
      tester,
    ) async {
      final wearable = _FeatureWearable();
      final controller = AppController(
        MemorySessionVault(),
        _CoverageApi(),
        MemoryHealthStore(),
        wearable,
      )..isBooting = false;
      addTearDown(controller.dispose);
      await controller.connectDevice(
        DeviceInfo(id: '$source:WATCH:01', name: 'Test watch', model: 'test'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceFeaturePage(
            controller: controller,
            feature: DeviceFeature.findWatch,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Find my watch'));
      await tester.pump();

      expect(wearable.findActionStates, [true]);
      expect(find.widgetWithText(FilledButton, 'Finding…'), findsOneWidget);
      expect(find.text('Stop finding'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Finding…'));
      await tester.pump();
      expect(wearable.findActionStates, [true]);

      await tester.pump(const Duration(seconds: 6));
      expect(
        find.widgetWithText(FilledButton, 'Find my watch'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      controller.setAppForeground(false);
    });
  }

  testWidgets('U19 scheduled inflation and pulse need explicit confirmation', (
    tester,
  ) async {
    final wearable = _U19FeatureWearable();
    final controller = AppController(
      MemorySessionVault(),
      _CoverageApi(),
      MemoryHealthStore(),
      wearable,
    )..isBooting = false;
    addTearDown(controller.dispose);
    await controller.connectDevice(
      const DeviceInfo(id: 'urion:synthetic-watch', name: 'U19', model: 'U19'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.healthMonitoring,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scheduled blood pressure'), findsWidgets);
    await tester.tap(find.text('Set schedule'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('u19-dynamic-pressure-editor')),
      findsOneWidget,
    );
    expect(wearable.writes, isEmpty);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(wearable.writes, isEmpty);
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(wearable.writes, hasLength(1));
    expect(wearable.writes.single.$1, DeviceFeature.healthMonitoring);
    expect(
      (wearable.writes.single.$2['dynamicBloodPressure'] as Map)['enabled'],
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.healthAssessment,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('u19-pulse-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('u19-pulse-start')));
    await tester.pumpAndSettle();
    expect(wearable.writes, hasLength(1));
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('u19-pulse-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('u19-pulse-start')));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(wearable.writes, hasLength(2));
    expect(wearable.writes.last.$1, DeviceFeature.healthAssessment);
    expect(wearable.writes.last.$2, {'operation': 'start'});
    expect(find.byKey(const Key('u19-pulse-ended-on-watch')), findsOneWidget);
    await tester.tap(find.byKey(const Key('u19-pulse-ended-on-watch')));
    await tester.pumpAndSettle();
    expect(wearable.writes, hasLength(2));
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(wearable.writes, hasLength(3));
    expect(wearable.writes.last.$2, {'operation': 'watchEnded'});
    controller.setAppForeground(false);
  });

  testWidgets('Veepoo find watch retains start and stop actions', (
    tester,
  ) async {
    final wearable = _FeatureWearable();
    final controller = AppController(
      MemorySessionVault(),
      _CoverageApi(),
      MemoryHealthStore(),
      wearable,
    )..isBooting = false;
    addTearDown(controller.dispose);
    await controller.connectDevice(
      const DeviceInfo(id: 'veepoo:WATCH:01', name: 'ET488', model: 'JL'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.findWatch,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Find my watch'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stop finding'));
    await tester.pump();

    expect(wearable.findActionStates, [true, false]);
    expect(find.widgetWithText(FilledButton, 'Find my watch'), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.setAppForeground(false);
  });

  testWidgets('password recovery validates input without claiming success', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: PasswordRecoveryPage(controller: controller)),
    );
    await tester.enterText(
      find.byKey(const Key('password-recovery-mobile')),
      '123',
    );
    await tester.tap(find.byKey(const Key('password-recovery-submit')));
    await tester.pump();
    expect(find.text('请输入正确的中国大陆手机号'), findsOneWidget);
  });

  testWidgets('about, contact and feedback pages follow the prototype flow', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AboutSaydianPage(
          controller: controller,
          packageInfoLoader: () async => PackageInfo(
            appName: '赛电健康',
            packageName: 'com.saydian.app',
            version: '0.1.12',
            buildNumber: '14',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('V0.1.12 (14)'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(
            find.ancestor(
              of: find.text('检查更新'),
              matching: find.byType(ListTile),
            ),
          )
          .onTap,
      isNotNull,
    );

    await tester.pumpWidget(const MaterialApp(home: CustomerServicePage()));
    await tester.pumpAndSettle();
    expect(find.text('4006386738'), findsOneWidget);
    expect(find.text('公众号'), findsOneWidget);
    expect(find.text('赛电'), findsOneWidget);
    expect(find.text('添加客服'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FeedbackPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('意见反馈'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('常见问题'), findsOneWidget);
  });

  testWidgets('US about and feedback pages have concise English copy', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _CoverageGlobalApi(),
      MemoryHealthStore(),
      _CoverageWearable(),
    )..isBooting = false;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AboutSaydianPage(
          controller: controller,
          packageInfoLoader: () async => PackageInfo(
            appName: 'SAYDIAN Health',
            packageName: 'cn.saydian.app.global',
            version: '0.1.23',
            buildNumber: '1007',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Everyday wellness insights from your watch.'),
      findsOneWidget,
    );
    expect(find.text('SAYDIAN Health'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FeedbackPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Feedback'), findsOneWidget);
    expect(find.text('Feature suggestion'), findsOneWidget);
    expect(find.text('Shop order'), findsNothing);
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Common questions'), findsOneWidget);
    expect(find.text('How do I connect my watch?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('关于我们手动检查统一交给根级更新门禁', (tester) async {
    final controller = _controller();
    final updateGate = AppUpdateGateController();
    var checks = 0;
    Future<void> checkNow() async => checks++;
    updateGate.attach(checkNow);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AboutSaydianPage(
          controller: controller,
          updateGateController: updateGate,
          packageInfoLoader: () async => PackageInfo(
            appName: '赛电健康',
            packageName: 'cc.saidian.app',
            version: '0.1.19',
            buildNumber: '19',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final updateTile = find.widgetWithText(ListTile, '检查更新');
    await tester.ensureVisible(updateTile);
    await tester.pumpAndSettle();
    await tester.tap(updateTile);
    await tester.pumpAndSettle();

    expect(checks, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('关于我们忽略服务端短占位词', (tester) async {
    final controller = AppController(
      MemorySessionVault(),
      _ShortAboutApi(),
      MemoryHealthStore(),
      _CoverageWearable(),
    )..isBooting = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AboutSaydianPage(
          controller: controller,
          packageInfoLoader: () async => PackageInfo(
            appName: '赛电健康',
            packageName: 'cc.saidian.app',
            version: '0.1.19',
            buildNumber: '23',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('手动阀'), findsNothing);
    expect(
      find.text('Everyday wellness insights from your watch.'),
      findsOneWidget,
    );
  });

  test('release UI source does not contain developer-facing copy', () {
    final source = [
      'lib/app.dart',
      'lib/ui/pages.dart',
      'lib/ui/shop_pages.dart',
      'lib/ui/prototype_pages.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    for (final banned in [
      'BLE',
      '接口未配置',
      '错误码',
      '指令队列',
      '本地预览',
      '内测版',
      '真机验证',
      'openid',
    ]) {
      expect(source, isNot(contains(banned)), reason: 'UI contains $banned');
    }
  });
}

AppController _controller() => AppController(
  MemorySessionVault(),
  _CoverageApi(),
  MemoryHealthStore(),
  _CoverageWearable(),
)..isBooting = false;

class _CoverageApi extends Fake implements SaydianApi {
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];

  @override
  Future<Map<String, Object?>> getSingleArticle(int id) async => {
    'id': id,
    'title': switch (id) {
      2 => '用户协议',
      3 => '隐私政策',
      _ => '关于赛电',
    },
    'content': '<p>赛电健康服务说明</p>',
  };
}

class _CoverageGlobalApi extends _CoverageApi implements GlobalAccountApi {}

class _ShortAboutApi extends _CoverageApi {
  @override
  Future<Map<String, Object?>> getSingleArticle(int id) async => {
    'id': id,
    'title': '关于赛电',
    'content': '<p>手动阀</p>',
  };
}

class _CoverageWearable extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}

class _FeatureWearable extends Fake implements WearableBridge {
  _FeatureWearable({this.healthReminderInterval = 60});

  final int healthReminderInterval;
  final List<bool> findActionStates = [];

  @override
  Stream<WearableEvent> get events => const Stream.empty();

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}

  @override
  Future<DeviceCapabilities> getCapabilities() async => DeviceCapabilities(
    metrics: const {HealthMetric.heartRate},
    features: DeviceFeature.values.toSet(),
    integratedFeatures: DeviceFeature.values.toSet(),
  );

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      switch (feature) {
        DeviceFeature.watchFaces => {
          'items': [
            {
              'id': '/system/1',
              'name': '系统表盘 1',
              'type': 'system',
              'index': 0,
              'isCurrent': true,
            },
          ],
        },
        DeviceFeature.photoWatchFace => const {},
        DeviceFeature.notifications => {
          'notificationAccess': false,
          'supportedKeys': ['wechat', 'sms'],
          'wechat': true,
          'sms': true,
        },
        DeviceFeature.alarms => {'items': <Object?>[]},
        DeviceFeature.contacts => {'items': <Object?>[]},
        DeviceFeature.weather => {'enabled': true, 'useCelsius': true},
        DeviceFeature.worldClock => {'items': <Object?>[]},
        DeviceFeature.healthReminders => {
          'items': [
            {
              'id': 'sedentary',
              'label': '久坐提醒',
              'enabled': true,
              'startMinutes': 480,
              'endMinutes': 1320,
              'intervalMinutes': healthReminderInterval,
            },
          ],
        },
        DeviceFeature.healthAssessment => {
          'items': [
            {'id': 6, 'label': '压力评估', 'enabled': true},
          ],
        },
        _ => const {},
      };

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {}

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {
    if (feature == DeviceFeature.findWatch) {
      findActionStates.add(enabled);
    }
  }
}

class _UsScreenWearable extends _FeatureWearable {
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    if (feature == DeviceFeature.screenDisplay) {
      return {
        'brightness': 4,
        'maximumBrightness': 5,
        'automaticBrightness': false,
        'brightnessSupported': true,
        'durationSeconds': 15,
        'minimumDurationSeconds': 5,
        'maximumDurationSeconds': 30,
        'raiseToWakeEnabled': true,
        'raiseToWakeSupported': true,
        'raiseToWakeCustomTimeSupported': true,
        'raiseToWakeStartMinutes': 480,
        'raiseToWakeEndMinutes': 1320,
        'raiseToWakeSensitivity': 5,
      };
    }
    return super.readDeviceFeature(feature);
  }
}

class _U19FeatureWearable extends _FeatureWearable {
  final List<(DeviceFeature, Map<String, Object?>)> writes = [];

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      switch (feature) {
        DeviceFeature.healthMonitoring => {
          'heartRate': true,
          'bloodOxygen': false,
          'dynamicBloodPressure': {
            'enabled': false,
            'startHour': 8,
            'dayIntervalMinutes': 60,
            'nightIntervalMinutes': 60,
          },
        },
        DeviceFeature.healthAssessment => {'pulse': null},
        _ => super.readDeviceFeature(feature),
      };

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    writes.add((feature, values));
  }
}

class _EventCoverageWearable extends Fake implements WearableBridge {
  final _events = StreamController<WearableEvent>.broadcast();

  @override
  Stream<WearableEvent> get events => _events.stream;

  void emit(WearableEvent event) => _events.add(event);

  Future<void> close() => _events.close();

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}

  @override
  Future<DeviceCapabilities> getCapabilities() async => throw PlatformException(
    code: 'CAPABILITIES_UNAVAILABLE',
    message: '暂时无法读取此手表的功能',
  );

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];
}
