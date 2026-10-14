import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/ring_gesture_control_page.dart';

class _Api implements SaydianApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class _Ring implements WearableBridge {
  Map<String, bool> settings = {
    'heartRate': true,
    'hrv': false,
    'stress': true,
  };
  Map<String, Object?> gesture = {
    'supportedModes': [0, 1, 2, 4, 5],
    'confirmedMode': 5,
    'confirmationScope': 'device',
  };
  Completer<Map<String, bool>>? pendingRead;
  Completer<void>? pendingWrite;
  Completer<Map<String, Object?>>? pendingFeatureRead;
  StreamController<WearableEvent>? eventController;
  Object? disconnectFailure;
  Completer<void>? pendingDisconnect;
  int disconnects = 0;
  bool persistWrite = true;
  int writes = 0;
  List<Map<String, Object?>> gestureWrites = [];
  Map<DeviceFeature, Map<String, Object?>> featureValues = {};
  Object? featureReadFailure;
  @override
  Stream<WearableEvent> get events =>
      eventController?.stream ?? const Stream.empty();
  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async =>
      pendingRead?.future ?? Map.of(settings);
  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) async {
    writes++;
    await pendingWrite?.future;
    if (persistWrite) settings = {...settings, type: enabled};
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    await pendingDisconnect?.future;
    final failure = disconnectFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    if (featureReadFailure != null) throw featureReadFailure!;
    return pendingFeatureRead?.future ??
        Map.of(featureValues[feature] ?? gesture);
  }

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    gestureWrites.add(values);
    if (feature != DeviceFeature.gestureControl) return;
    gesture = {...gesture, 'confirmedMode': values['mode']};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

AppController _controller(
  _Ring ring, {
  String source = 'qring',
  Set<DeviceFeature> extraFeatures = const {},
}) =>
    AppController(
        MemorySessionVault(),
        _Api(),
        MemoryHealthStore(),
        ring,
        allowAutomaticWearableRestore: false,
      )
      ..connectedDevice = DeviceInfo(
        id: '$source:synthetic',
        name: source == 'qring' ? 'R21 fixture' : 'R7Pro fixture',
      )
      ..deviceCapabilityState = DeviceCapabilityState.ready
      ..capabilities = DeviceCapabilities(
        metrics: {HealthMetric.steps, HealthMetric.heartRate},
        manualMetrics: {HealthMetric.heartRate},
        features: {
          DeviceFeature.gestureControl,
          DeviceFeature.healthMonitoring,
          DeviceFeature.findWatch,
          ...extraFeatures,
        },
        integratedFeatures: {
          DeviceFeature.gestureControl,
          DeviceFeature.healthMonitoring,
          DeviceFeature.findWatch,
          ...extraFeatures,
        },
      );
Widget _app(
  Widget child, {
  Locale locale = const Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hans',
  ),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final feature in [
    DeviceFeature.basicSettings,
    DeviceFeature.alarms,
    DeviceFeature.contacts,
    DeviceFeature.worldClock,
    DeviceFeature.notifications,
    DeviceFeature.weather,
    DeviceFeature.healthReminders,
    DeviceFeature.healthAssessment,
    DeviceFeature.photoWatchFace,
    DeviceFeature.watchFaces,
    DeviceFeature.healthMonitoring,
  ]) {
    testWidgets(
      'English ${feature.name} controls fit a small display without Chinese',
      (tester) async {
        debugDefaultTargetPlatformOverride = null;
        tester.view.physicalSize = const Size(320, 780);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final ring = _Ring()
          ..featureValues[feature] = {
            'snapshotRevision': 'fixture',
            'supported': true,
            'items': switch (feature) {
              DeviceFeature.healthReminders => [
                {
                  'id': 'sedentary',
                  'label': '久坐提醒',
                  'enabled': true,
                  'startMinutes': 480,
                  'endMinutes': 1080,
                  'intervalMinutes': 60,
                },
                {
                  'id': 'drinking',
                  'label': '喝水提醒',
                  'enabled': false,
                  'startMinutes': 480,
                  'endMinutes': 1080,
                  'intervalMinutes': 30,
                },
              ],
              DeviceFeature.healthAssessment => [
                {'id': 'stress', 'label': '压力评估', 'enabled': false},
              ],
              DeviceFeature.watchFaces => [
                {
                  'id': 'default:0',
                  'name': '内置表盘 1',
                  'status': '手表内置',
                  'type': 'default',
                  'index': 0,
                },
              ],
              DeviceFeature.worldClock => [
                {'id': 1, 'city': '纽约', 'utcOffsetMinutes': -300},
              ],
              DeviceFeature.alarms => [
                {
                  'id': 1,
                  'label': '闹钟',
                  'hour': 8,
                  'minute': 0,
                  'repeatDays': [1, 2, 3, 4, 5],
                  'enabled': false,
                },
              ],
              _ => <Map<String, Object?>>[],
            },
            'contacts': <Map<String, Object?>>[],
            'faces': <Map<String, Object?>>[],
            'useCelsius': true,
            'supportedLanguages': ['en', 'zh'],
            'locale': 'en',
            'stepGoal': 8000,
          };
        final controller = _controller(ring, extraFeatures: {feature});
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            DeviceFeaturePage(controller: controller, feature: feature),
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();
        final visible = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
            .join('\n');
        expect(
          RegExp(r'[\u3400-\u9fff]').hasMatch(visible),
          isFalse,
          reason: visible,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('basic CoolWear alarms do not offer unsupported name editing', (
    tester,
  ) async {
    final ring = _Ring()
      ..featureValues[DeviceFeature.alarms] = {
        'reminderStyle': 'device',
        'snapshotRevision': 'fixture',
        'supportsNames': false,
        'items': <Map<String, Object?>>[],
      };
    final controller = _controller(
      ring,
      source: 'coolwear',
      extraFeatures: {DeviceFeature.alarms},
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.alarms,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_alarm_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('例如：吃药、起床'), findsNothing);
    expect(ring.gestureWrites, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'unreadable message reminder requires an explicit choice without an off switch',
    (tester) async {
      final ring = _Ring()
        ..featureValues[DeviceFeature.notifications] = {
          'reminderStyle': 'connection',
          'systemNotificationAuthorized': true,
        };
      final controller = _controller(
        ring,
        source: 'coolwear',
        extraFeatures: {DeviceFeature.notifications},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          DeviceFeaturePage(
            controller: controller,
            feature: DeviceFeature.notifications,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('当前提醒状态未知'), findsOneWidget);
      expect(find.text('开启提醒'), findsOneWidget);
      expect(find.text('关闭提醒'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(ring.gestureWrites, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  test(
    'failed reminder refresh invalidates the old confirmed switch snapshot',
    () async {
      final ring = _Ring()
        ..featureValues[DeviceFeature.notifications] = {
          'enabled': true,
          'snapshotRevision': 'fixture',
        };
      final controller = _controller(
        ring,
        source: 'coolwear',
        extraFeatures: {DeviceFeature.notifications},
      );
      addTearDown(controller.dispose);
      await controller.readDeviceFeature(DeviceFeature.notifications);
      ring.featureReadFailure = PlatformException(code: 'REMINDER_RECONNECT');
      expect(
        await controller.readDeviceFeature(DeviceFeature.notifications),
        isEmpty,
      );
      expect(
        controller.deviceFeatureData.containsKey(DeviceFeature.notifications),
        isFalse,
      );
    },
  );
  testWidgets(
    'CoolWear reminder UI does not promise a display or invent an interval',
    (tester) async {
      final ring = _Ring()
        ..featureValues = {
          DeviceFeature.notifications: {
            'enabled': false,
            'reminderStyle': 'device',
            'snapshotRevision': 'fixture',
            'systemNotificationAuthorized': false,
          },
          DeviceFeature.healthReminders: {
            'reminderStyle': 'device',
            'snapshotRevision': 'fixture',
            'items': [
              {
                'id': 'sedentary',
                'label': '久坐提醒',
                'enabled': false,
                'startMinutes': 480,
                'endMinutes': 1440,
              },
            ],
          },
        };
      final controller = _controller(
        ring,
        source: 'coolwear',
        extraFeatures: {
          DeviceFeature.notifications,
          DeviceFeature.healthReminders,
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          DeviceFeaturePage(
            controller: controller,
            feature: DeviceFeature.notifications,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('消息提醒'), findsWidgets);
      expect(find.textContaining('振动或指示灯'), findsOneWidget);
      expect(find.textContaining('在设备显示'), findsNothing);
      await tester.pumpWidget(
        _app(
          DeviceFeaturePage(
            key: const ValueKey('status'),
            controller: controller,
            feature: DeviceFeature.healthReminders,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('状态提醒'), findsOneWidget);
      expect(find.text('08:00–24:00'), findsOneWidget);
      expect(find.textContaining('60 分钟'), findsNothing);
      await tester.tap(find.text('久坐提醒'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  test(
    'ring reminder ACK cannot replace confirmed settings with request data',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ring = _Ring()
        ..featureValues[DeviceFeature.notifications] = {
          'enabled': false,
          'snapshotRevision': 'fixture-original',
          'reminderStyle': 'device',
        };
      final controller = _controller(
        ring,
        source: 'coolwear',
        extraFeatures: {DeviceFeature.notifications},
      );
      addTearDown(controller.dispose);
      await controller.readDeviceFeature(DeviceFeature.notifications);
      expect(
        await controller.writeDeviceFeature(DeviceFeature.notifications, {
          'enabled': true,
          'snapshotRevision': 'fixture-original',
        }),
        isTrue,
      );
      expect(
        controller.deviceFeatureData[DeviceFeature.notifications]!['enabled'],
        isFalse,
      );
      expect(controller.capabilities!.manualMetrics, isEmpty);
    },
  );
  test('iOS status configuration stays closed for every device', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ring = _Ring();
    for (final source in ['coolwear', 'qring', 'veepoo']) {
      final controller = _controller(
        ring,
        source: source,
        extraFeatures: {
          DeviceFeature.healthReminders,
          DeviceFeature.healthAssessment,
        },
      );
      expect(
        controller.availabilityFor(DeviceFeature.healthReminders).isReady,
        isFalse,
      );
      expect(
        controller.availabilityFor(DeviceFeature.healthAssessment).isReady,
        isFalse,
      );
      controller.dispose();
    }
  });
  for (final source in ['coolwear', 'qring', 'veepoo']) {
    test('iOS $source cannot read or write physiological settings', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ring = _Ring();
      final controller = _controller(ring, source: source);
      addTearDown(controller.dispose);
      expect(
        controller.availabilityFor(DeviceFeature.healthMonitoring).isReady,
        isFalse,
      );
      expect(controller.capabilities!.metrics, {HealthMetric.steps});
      expect(controller.capabilities!.manualMetrics, isEmpty);
      await controller.refreshDeviceSettings();
      expect(controller.autoMeasureSettings, isEmpty);
      await controller.setAutoMeasureSetting('heartRate', true);
      expect(ring.writes, 0);
      expect(controller.heartRateWarningSupported, isFalse);
    });
  }
  test(
    'an ACK without matching readback never selects the requested switch',
    () async {
      final ring = _Ring()..persistWrite = false;
      final controller = _controller(ring);
      addTearDown(controller.dispose);
      await controller.refreshDeviceSettings();
      await controller.setAutoMeasureSetting('heartRate', false);
      expect(ring.writes, 1);
      expect(controller.autoMeasureSettings, isEmpty);
      expect(controller.errorMessage, contains('未确认'));
      expect(controller.isDeviceSettingsWriting, isFalse);
    },
  );
  test('switch saves serialize and use the actual readback', () async {
    final ring = _Ring()..pendingWrite = Completer<void>();
    final controller = _controller(ring);
    addTearDown(controller.dispose);
    await controller.refreshDeviceSettings();
    final saving = controller.setAutoMeasureSetting('heartRate', false);
    await controller.setAutoMeasureSetting('hrv', true);
    expect(ring.writes, 1);
    expect(controller.autoMeasureSettings['heartRate'], isTrue);
    ring.pendingWrite!.complete();
    await saving;
    expect(controller.autoMeasureSettings, {
      'heartRate': false,
      'hrv': false,
      'stress': true,
    });
    expect(controller.deviceSettingsStatus, contains('确认'));
  });
  test(
    'disconnect retires an in-flight settings read and clears snapshots',
    () async {
      final ring = _Ring()..pendingRead = Completer<Map<String, bool>>();
      final controller = _controller(ring);
      addTearDown(controller.dispose);
      final reading = controller.refreshDeviceSettings();
      await controller.disconnectDevice();
      ring.pendingRead!.complete({'heartRate': true});
      await reading;
      expect(controller.autoMeasureSettings, isEmpty);
      expect(controller.deviceSettingsBusy, isFalse);
    },
  );
  test('unsupported switch keys never reach hardware', () async {
    final ring = _Ring();
    final controller = _controller(ring);
    addTearDown(controller.dispose);
    await controller.refreshDeviceSettings();
    await controller.setAutoMeasureSetting('bloodGlucose', true);
    expect(ring.writes, 0);
  });
  test(
    'failed native disconnect keeps the target until a confirmed retry',
    () async {
      final ring = _Ring()
        ..disconnectFailure = PlatformException(code: 'RECOVERY_PENDING');
      final controller = _controller(ring);
      addTearDown(controller.dispose);
      await expectLater(
        controller.disconnectDevice(),
        throwsA(isA<PlatformException>()),
      );
      expect(controller.connectedDevice?.id, 'qring:synthetic');
      expect(
        controller.deviceCapabilityState,
        DeviceCapabilityState.unavailable,
      );
      expect(controller.deviceState, DeviceConnectionState.error);
      expect(controller.errorMessage, contains('连接尚未结束'));
      expect(controller.isDeviceDisconnecting, isFalse);
      expect(await controller.refreshDeviceCapabilities(), isFalse);
      expect(await controller.refreshConnectedDeviceDetails(), isFalse);
      ring.disconnectFailure = null;
      await controller.disconnectDevice();
      expect(ring.disconnects, 2);
      expect(controller.connectedDevice, isNull);
      expect(controller.errorMessage, isNull);
    },
  );
  test('repeated disconnect taps share one native cancellation', () async {
    final ring = _Ring()..pendingDisconnect = Completer<void>();
    final controller = _controller(ring);
    addTearDown(controller.dispose);
    final first = controller.disconnectDevice();
    final second = controller.disconnectDevice();
    expect(identical(first, second), isTrue);
    expect(controller.isDeviceDisconnecting, isTrue);
    ring.pendingDisconnect!.complete();
    await first;
    expect(ring.disconnects, 1);
    expect(controller.connectedDevice, isNull);
    expect(controller.isDeviceDisconnecting, isFalse);
  });
  test(
    'native disconnect clears a pending gesture read and its old state',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const connectivity = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(connectivity, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(connectivity, null));
      final events = StreamController<WearableEvent>(sync: true);
      final ring = _Ring()
        ..eventController = events
        ..pendingFeatureRead = Completer<Map<String, Object?>>();
      final controller = _controller(ring);
      addTearDown(() async {
        controller.dispose();
        await events.close();
      });
      await controller.initialize();
      controller.deviceFeatureData = {
        DeviceFeature.gestureControl: {'confirmedMode': 5},
      };
      final reading = controller.readDeviceFeature(
        DeviceFeature.gestureControl,
      );
      expect(controller.deviceFeatureBusy, {DeviceFeature.gestureControl});
      events.add(
        const WearableEvent(
          type: 'disconnected',
          payload: {'deviceId': 'qring:synthetic'},
        ),
      );
      expect(controller.connectedDevice, isNull);
      expect(controller.deviceFeatureBusy, isEmpty);
      expect(controller.deviceFeatureData, isEmpty);
      ring.pendingFeatureRead!.complete({'confirmedMode': 1});
      expect(await reading, isEmpty);
      expect(controller.deviceFeatureData, isEmpty);
      expect(controller.deviceFeatureBusy, isEmpty);
    },
  );
  testWidgets('ring settings appear together below device features', (
    tester,
  ) async {
    final controller = _controller(_Ring());
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(DevicePage(controller: controller)));
    await tester.pumpAndSettle();
    final features = find.text('设备功能');
    final gesture = find.text('手势控制');
    final monitoring = find.text('健康监测');
    expect(features, findsOneWidget);
    expect(gesture, findsOneWidget);
    expect(monitoring, findsOneWidget);
    expect(
      tester.getTopLeft(gesture).dy,
      greaterThan(tester.getTopLeft(features).dy),
    );
    expect(tester.getTopLeft(gesture).dy, tester.getTopLeft(monitoring).dy);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'QRing photo mode 5 sends its previous device mode and reads back',
    (tester) async {
      final ring = _Ring();
      final controller = _controller(ring);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(RingGestureControlPanel(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.text('拍照'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ring-gesture-mode-1')));
      await tester.pumpAndSettle();
      expect(ring.gestureWrites.single, {'mode': 1, 'expectedMode': 5});
      expect(find.text('手势模式已从设备确认'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'CoolWear unknown mode is not shown as off and photo uses mode 4',
    (tester) async {
      final ring = _Ring()
        ..gesture = {
          'supportedModes': [0, 1, 2, 3, 4, 5],
          'confirmationScope': 'connection',
        };
      final controller = _controller(ring, source: 'coolwear');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(RingGestureControlPanel(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.textContaining('当前模式未知'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ring-gesture-mode-4')));
      await tester.pumpAndSettle();
      expect(ring.gestureWrites.single, {'mode': 4});
      expect(find.text('设备已确认手势指令'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
