import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';

// Synthetic public-controller/UI contracts only: no real watch operations,
// medical measurements, server writes or transport acceptance are implied.
void main() {
  setUpAll(() => initializeDateFormatting('zh_Hans'));
  setUp(() {
    const channel = MethodChannel(
      'dev.fluttercommunity.plus/connectivity_status',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  });

  for (final earlierSlot in [false, true]) {
    testWidgets(
      earlierSlot
          ? 'waiting dialog reopens and accepts an earlier sample with start proof'
          : 'waiting dialog reopens and accepts a second-resolution result',
      (tester) async {
        final fixture = await _host(tester);
        await _open(tester, HealthMetric.heartRate);
        final startedAt = fixture.controller.measurementStartedAt!;
        final sessionId = fixture.controller.measurementSessionId;
        expect(fixture.wearable.starts, 1);
        expect(find.textContaining('请在手表上结束测量'), findsOneWidget);

        await tester.tap(find.text('稍后查看'));
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsNothing);
        expect(
          fixture.controller.isMeasurementRunning(HealthMetric.heartRate),
          isTrue,
        );
        expect(fixture.wearable.stops, 0);

        await _open(tester, HealthMetric.heartRate);
        expect(fixture.wearable.starts, 1);
        expect(fixture.controller.measurementSessionId, sessionId);
        expect(fixture.controller.measurementStartedAt, startedAt);
        final sampleTime = earlierSlot
            ? startedAt.subtract(const Duration(minutes: 5))
            : DateTime.fromMillisecondsSinceEpoch(
                startedAt.millisecondsSinceEpoch ~/ 1000 * 1000,
                isUtc: true,
              );
        fixture.wearable.emitResult(
          measuredAt: sampleTime,
          measurementStartedAt: earlierSlot ? startedAt : null,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(_resultKey), findsOneWidget);
        expect(find.text('72 bpm'), findsOneWidget);
        expect(
          _withinDialog(find.byType(LinearProgressIndicator)),
          findsNothing,
        );
        expect(find.text('稍后查看'), findsNothing);
        expect(find.text('关闭'), findsOneWidget);
        expect(fixture.controller.measurementResult?.measuredAt, sampleTime);
        expect(fixture.controller.activeMeasurementMetric, isNull);
        expect(fixture.wearable.stops, 0);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsNothing);
        expect(fixture.wearable.starts, 1);
        expect(fixture.wearable.stops, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('system back preserves the nonstoppable waiting session', (
    tester,
  ) async {
    final fixture = await _host(tester);
    await _open(tester, HealthMetric.heartRate);
    final sessionId = fixture.controller.measurementSessionId;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialogKey), findsNothing);
    expect(fixture.wearable.stops, 0);
    expect(fixture.controller.activeMeasurementMetric, HealthMetric.heartRate);
    await _open(tester, HealthMetric.heartRate);
    expect(fixture.controller.measurementSessionId, sessionId);
    expect(fixture.wearable.starts, 1);
    expect(tester.takeException(), isNull);
    // The test has intentionally left a live waiting session. Retire it before
    // Flutter verifies that no timers remain after unmounting the widget tree.
    fixture.controller.confirmWatchMeasurementEnded(HealthMetric.heartRate);
  });

  testWidgets(
    'confirming the watch ended does not start or stop the hardware',
    (tester) async {
      final fixture = await _host(tester);
      await _open(tester, HealthMetric.heartRate);
      await tester.tap(find.text('已在手表结束'));
      await tester.pumpAndSettle();
      expect(find.byKey(_dialogKey), findsNothing);
      expect(fixture.controller.activeMeasurementMetric, isNull);
      expect(fixture.controller.measurementResult, isNull);
      expect(fixture.wearable.starts, 1);
      expect(fixture.wearable.stops, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disconnect replaces the waiting indicator with recovery guidance',
    (tester) async {
      final fixture = await _host(tester);
      await _open(tester, HealthMetric.heartRate);
      fixture.wearable.eventsController.add(
        const WearableEvent(
          type: 'disconnected',
          payload: {'deviceId': _DialogWearable.watchId},
        ),
      );
      await tester.pump();
      expect(find.byKey(_dialogKey), findsOneWidget);
      expect(find.textContaining('手表已断开连接'), findsOneWidget);
      expect(_withinDialog(find.byType(LinearProgressIndicator)), findsNothing);
      expect(find.byKey(_resultKey), findsNothing);
      expect(find.text('关闭'), findsOneWidget);
      expect(fixture.controller.activeMeasurementMetric, isNull);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.byKey(_dialogKey), findsNothing);
      expect(fixture.wearable.starts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('U19 pressure waits for explicit readiness before inflation', (
    tester,
  ) async {
    final fixture = await _host(tester, metric: HealthMetric.bloodPressure);
    final action = find.byKey(
      Key('health-measure-${HealthMetric.bloodPressure.wireName}'),
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const Key('u19-measurement-confirmation')),
      findsOneWidget,
    );
    expect(fixture.wearable.starts, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byKey(_dialogKey), findsNothing);
    expect(fixture.wearable.starts, 0);
    expect(fixture.controller.activeMeasurementMetric, isNull);
  });

  testWidgets('large-text pressure instructions scroll and can be dismissed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = await _host(
      tester,
      metric: HealthMetric.bloodPressure,
      textScale: 2,
    );
    await _open(tester, HealthMetric.bloodPressure);
    expect(_withinDialog(find.byType(SingleChildScrollView)), findsOneWidget);
    expect(find.textContaining('请在手表上结束测量'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final scrollable = _withinDialog(find.byType(Scrollable));
    expect(scrollable, findsOneWidget);
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(scrollable, const Offset(0, -160));
    await tester.pump();
    expect(position.pixels, greaterThan(0));
    await tester.ensureVisible(find.text('稍后查看'));
    await tester.tap(find.text('稍后查看'));
    await tester.pumpAndSettle();
    expect(find.byKey(_dialogKey), findsNothing);
    expect(fixture.wearable.starts, 1);
    expect(fixture.wearable.stops, 0);
    expect(tester.takeException(), isNull);
    fixture.controller.confirmWatchMeasurementEnded(HealthMetric.bloodPressure);
  });
}

const _dialogKey = Key('health-measurement-dialog');
const _resultKey = Key('health-measurement-result');

Finder _withinDialog(Finder matching) =>
    find.descendant(of: find.byKey(_dialogKey), matching: matching);

Future<void> _open(WidgetTester tester, HealthMetric metric) async {
  final action = find.byKey(Key('health-measure-${metric.wireName}'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  if (metric == HealthMetric.bloodPressure) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('u19-measurement-confirmation')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('开始测量'));
    await tester.tap(find.text('开始测量'));
  }
  // An indeterminate measurement indicator deliberately never settles.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byKey(_dialogKey), findsOneWidget);
}

Future<({AppController controller, _DialogWearable wearable})> _host(
  WidgetTester tester, {
  HealthMetric metric = HealthMetric.heartRate,
  double textScale = 1,
}) async {
  final wearable = _DialogWearable(metric);
  final controller = AppController(
    MemorySessionVault(),
    _DialogApi(),
    MemoryHealthStore(),
    wearable,
  );
  addTearDown(() async {
    controller.dispose();
    await wearable.eventsController.close();
  });
  await tester.runAsync(() async {
    await controller.initialize();
    expect(
      await controller.login('synthetic-owner', 'synthetic-password'),
      isTrue,
    );
    await controller.connectDevice(_DialogWearable.watch);
    for (var index = 0; index < 16; index++) {
      await Future<void>.delayed(Duration.zero);
    }
  });
  expect(controller.deviceState, DeviceConnectionState.ready);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSaydianTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: HealthHistoryPage(controller: controller, metric: metric),
    ),
  );
  await tester.pumpAndSettle();
  return (controller: controller, wearable: wearable);
}

class _DialogApi extends Fake implements SaydianApi {
  @override
  Future<Session> login(String username, String password) async => Session(
    accessToken: 'synthetic-only',
    refreshToken: 'synthetic-only',
    expiresAt: DateTime.utc(2030),
    memberId: username,
    displayName: 'Synthetic fixture',
  );
  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => const [];
  @override
  Future<Map<String, Object?>> getMemberProfile() async => const {};
  @override
  Future<Map<String, Object?>> getActivityGoals() async => const {};
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];
  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      const [];
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async =>
      BatchUploadResult(
        nextCursor: null,
        acceptedIds: batch.records.map((record) => record.id).toSet(),
        rejected: const {},
      );
}

class _DialogWearable extends Fake implements WearableBridge {
  _DialogWearable(this.metric);
  static const watchId = 'urion:SYNTHETIC-UI';
  static const watch = DeviceInfo(id: watchId, name: 'Synthetic watch');
  final HealthMetric metric;
  final eventsController = StreamController<WearableEvent>.broadcast();
  int starts = 0;
  int stops = 0;
  @override
  Stream<WearableEvent> get events => eventsController.stream;
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async => DeviceCapabilities(
    metrics: {metric},
    manualMetrics: {metric},
    stoppableManualMetrics: const {},
  );
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];
  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    starts++;
  }

  @override
  Future<void> stopMeasurement(HealthMetric metric) async {
    stops++;
  }

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];

  void emitResult({
    required DateTime measuredAt,
    DateTime? measurementStartedAt,
  }) => eventsController.add(
    WearableEvent(
      type: 'healthRecord',
      payload: {
        ...HealthRecord(
          id: 'synthetic-ui-result',
          metric: metric,
          values: const {'value': 72},
          unit: 'bpm',
          measuredAt: measuredAt,
          timezone: '+00:00',
          deviceId: watchId,
          firmwareVersion: 'synthetic',
          quality: 'device_reported',
          source: MeasurementSource.wearable,
          origin: MeasurementOrigin.appMeasurement,
          rawVersion: 1,
        ).toJson(),
        if (measurementStartedAt != null)
          'measurementStartedAt': measurementStartedAt.toIso8601String(),
      },
    ),
  );
}
