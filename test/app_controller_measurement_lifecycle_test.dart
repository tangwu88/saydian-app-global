import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

// Synthetic public-API regression for measurement sessions and refresh events.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    const channel = MethodChannel(
      'dev.fluttercommunity.plus/connectivity_status',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  });

  Future<({AppController controller, _Wearable wearable})> setup({
    bool stoppable = false,
  }) async {
    final wearable = _Wearable(stoppable: stoppable);
    final controller = AppController(
      MemorySessionVault(),
      _Api(),
      MemoryHealthStore(),
      wearable,
    );
    addTearDown(() async {
      controller.dispose();
      await wearable.eventsController.close();
    });
    await controller.initialize();
    expect(
      await controller.login('diagnostic-owner', 'synthetic-password'),
      isTrue,
    );
    await controller.connectDevice(_Wearable.watch);
    await _settle();
    expect(controller.connectedDevice?.id, _Wearable.watch.id);
    expect(controller.deviceState, DeviceConnectionState.ready);
    expect(controller.isDeviceSyncing, isFalse);
    return (controller: controller, wearable: wearable);
  }

  test('control: stoppable result releases the active measurement', () async {
    final fixture = await setup(stoppable: true);
    expect(
      await fixture.controller.startMeasurement(HealthMetric.heartRate),
      isTrue,
    );
    fixture.wearable.emitResult();
    await _settle();
    expect(
      fixture.controller.healthRecords.map((record) => record.id),
      contains('synthetic-result'),
    );
    expect(fixture.controller.activeMeasurementMetric, isNull);
    expect(fixture.wearable.stopCount, 1);
  });

  test(
    'nonstoppable result releases measurement without sending stop',
    () async {
      final fixture = await setup();
      expect(
        await fixture.controller.startMeasurement(HealthMetric.heartRate),
        isTrue,
      );
      fixture.wearable.emitResult();
      await _settle();
      expect(
        fixture.controller.healthRecords.map((record) => record.id),
        contains('synthetic-result'),
      );
      expect(
        fixture.controller.activeMeasurementMetric,
        isNull,
        reason: 'A confirmed result must finish the local measurement session.',
      );
      expect(
        fixture.wearable.stopCount,
        0,
        reason: 'The device declares that it has no App stop operation.',
      );
      expect(
        await fixture.controller.startMeasurement(HealthMetric.heartRate),
        isTrue,
      );
    },
  );

  test('native disconnection retires the active measurement', () async {
    final fixture = await setup(stoppable: true);
    expect(
      await fixture.controller.startMeasurement(HealthMetric.heartRate),
      isTrue,
    );
    fixture.wearable.eventsController.add(
      const WearableEvent(
        type: 'disconnected',
        payload: {'deviceId': _Wearable.watchId},
      ),
    );
    await _settle();
    expect(fixture.controller.connectedDevice, isNull);
    expect(fixture.controller.deviceState, DeviceConnectionState.disconnected);
    expect(
      fixture.controller.activeMeasurementMetric,
      isNull,
      reason:
          'A retired connection must not keep blocking a future measurement.',
    );
  });

  test('explicit disconnection retires the active measurement', () async {
    final fixture = await setup(stoppable: true);
    expect(
      await fixture.controller.startMeasurement(HealthMetric.heartRate),
      isTrue,
    );
    await fixture.controller.disconnectDevice();
    expect(fixture.controller.connectedDevice, isNull);
    expect(fixture.controller.deviceState, DeviceConnectionState.disconnected);
    expect(
      fixture.controller.activeMeasurementMetric,
      isNull,
      reason: 'The manual disconnect path must retire its measurement session.',
    );
  });

  test('data-ready during sync schedules a follow-up read', () async {
    final fixture = await setup();
    final initialReads = fixture.wearable.syncCount;
    final pending = Completer<List<HealthRecord>>();
    fixture.wearable.nextHistory = pending.future;
    final sync = fixture.controller.syncDeviceData();
    await _settle();
    expect(fixture.controller.isDeviceSyncing, isTrue);
    expect(fixture.wearable.syncCount, initialReads + 1);
    fixture.wearable.eventsController.add(
      const WearableEvent(type: 'healthDataReady', payload: {}),
    );
    await _settle();
    fixture.wearable.nextHistory = null;
    pending.complete(const []);
    expect(await sync, isTrue);
    await _settle();
    expect(
      fixture.wearable.syncCount,
      initialReads + 2,
      reason:
          'A change after the in-flight snapshot must receive one later read.',
    );
  });
  test(
    'notification bursts coalesce without looping during the follow-up',
    () async {
      final fixture = await setup();
      final initialReads = fixture.wearable.syncCount;
      final pending = Completer<List<HealthRecord>>();
      fixture.wearable.nextHistory = pending.future;
      final sync = fixture.controller.syncDeviceData();
      await _settle();
      for (var index = 0; index < 5; index++) {
        fixture.wearable.notifyDataReady();
      }
      await _settle();
      fixture.wearable.nextHistory = null;
      fixture.wearable.onSync = fixture.wearable.notifyDataReady;
      pending.complete(const []);
      await sync;
      await _settle();
      expect(fixture.wearable.syncCount, initialReads + 2);
      expect(fixture.controller.isDeviceSyncing, isFalse);
    },
  );

  test(
    'disconnect cancels an old pending refresh before reconnection',
    () async {
      final fixture = await setup();
      final pending = Completer<List<HealthRecord>>();
      fixture.wearable.nextHistory = pending.future;
      final sync = fixture.controller.syncDeviceData();
      await _settle();
      fixture.wearable.notifyDataReady();
      await _settle();
      await fixture.controller.disconnectDevice();
      fixture.wearable.nextHistory = null;
      await fixture.controller.connectDevice(_Wearable.watch);
      await _settle();
      final reads = fixture.wearable.syncCount;
      pending.complete(const []);
      expect(await sync, isFalse);
      await _settle();
      expect(fixture.wearable.syncCount, reads);
    },
  );

  test(
    'a watch change during the follow-up schedules another bounded read',
    () async {
      final fixture = await setup();
      final initialReads = fixture.wearable.syncCount;
      final first = Completer<List<HealthRecord>>();
      final second = Completer<List<HealthRecord>>();
      fixture.wearable.nextHistory = first.future;
      final sync = fixture.controller.syncDeviceData();
      await _settle();
      fixture.wearable.notifyDataReady();
      await _settle();
      fixture.wearable.nextHistory = second.future;
      first.complete(const []);
      await sync;
      await _settle();
      expect(fixture.wearable.syncCount, initialReads + 2);
      for (var index = 0; index < 4; index++) {
        fixture.wearable.notifyDataReady(source: 'watchNotification');
        fixture.wearable.notifyDataReady();
      }
      await _settle();
      fixture.wearable.nextHistory = null;
      second.complete(const []);
      await _settle();
      expect(fixture.wearable.syncCount, initialReads + 3);
      expect(fixture.controller.isDeviceSyncing, isFalse);
    },
  );

  test('another device data-ready notification is ignored', () async {
    final fixture = await setup();
    final reads = fixture.wearable.syncCount;
    fixture.wearable.eventsController.add(
      const WearableEvent(
        type: 'healthDataReady',
        payload: {'deviceId': 'urion:OTHER'},
      ),
    );
    await _settle();
    expect(fixture.wearable.syncCount, reads);
  });

  test('old history does not complete an active measurement', () async {
    final fixture = await setup();
    expect(
      await fixture.controller.startMeasurement(HealthMetric.heartRate),
      isTrue,
    );
    fixture.wearable.emitResult(
      measuredAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    );
    await _settle();
    expect(fixture.controller.activeMeasurementMetric, HealthMetric.heartRate);
    expect(fixture.controller.measurementResult, isNull);
    expect(fixture.wearable.stopCount, 0);
    expect(
      fixture.controller.healthRecords.single.origin,
      MeasurementOrigin.watchHistory,
    );
  });

  test(
    'confirmed indexed sample keeps its real time and finishes the session',
    () async {
      final fixture = await setup();
      expect(
        await fixture.controller.startMeasurement(HealthMetric.heartRate),
        isTrue,
      );
      final startedAt = fixture.controller.measurementStartedAt!;
      final sessionId = fixture.controller.measurementSessionId;
      final sampleTime = startedAt.subtract(const Duration(minutes: 5));
      fixture.wearable.emitResult(
        measuredAt: sampleTime,
        origin: MeasurementOrigin.appMeasurement,
        measurementStartedAt: startedAt,
      );
      await _settle();
      expect(fixture.controller.activeMeasurementMetric, isNull);
      expect(fixture.controller.measurementStartedAt, startedAt);
      expect(fixture.controller.measurementSessionId, sessionId);
      expect(fixture.controller.measurementResult?.measuredAt, sampleTime);
      expect(fixture.wearable.stopCount, 0);
    },
  );

  test('an old measurement proof cannot complete the new session', () async {
    final fixture = await setup();
    expect(
      await fixture.controller.startMeasurement(HealthMetric.heartRate),
      isTrue,
    );
    final startedAt = fixture.controller.measurementStartedAt!;
    fixture.wearable.emitResult(
      measuredAt: DateTime.now().toUtc(),
      origin: MeasurementOrigin.appMeasurement,
      measurementStartedAt: startedAt.subtract(const Duration(minutes: 1)),
    );
    await _settle();
    expect(fixture.controller.activeMeasurementMetric, HealthMetric.heartRate);
    expect(fixture.controller.measurementResult, isNull);
    expect(fixture.controller.healthRecords, isEmpty);
  });

  test(
    'late start failure after reconnection leaves the new measurement intact',
    () async {
      final fixture = await setup();
      final delayedStart = Completer<void>();
      fixture.wearable.startResult = delayedStart;
      final first = fixture.controller.startMeasurement(HealthMetric.heartRate);
      await _settle();
      await fixture.controller.disconnectDevice();
      fixture.wearable.startResult = null;
      await fixture.controller.connectDevice(_Wearable.watch);
      await _settle();
      expect(
        await fixture.controller.startMeasurement(HealthMetric.heartRate),
        isTrue,
      );
      delayedStart.completeError(StateError('synthetic old failure'));
      expect(await first, isFalse);
      expect(
        fixture.controller.activeMeasurementMetric,
        HealthMetric.heartRate,
      );
      expect(fixture.controller.measurementErrorMessage, isNull);
    },
  );

  test('switching watches clears the prior measurement state', () async {
    final fixture = await setup();
    expect(
      await fixture.controller.startMeasurement(HealthMetric.heartRate),
      isTrue,
    );
    await fixture.controller.connectDevice(
      const DeviceInfo(id: 'urion:SECOND', name: 'Synthetic second'),
    );
    await _settle();
    expect(fixture.controller.connectedDevice?.id, 'urion:SECOND');
    expect(fixture.controller.activeMeasurementMetric, isNull);
    expect(fixture.controller.measurementStartedAt, isNull);
    expect(fixture.controller.measurementResult, isNull);
    expect(
      await fixture.controller.startMeasurement(HealthMetric.heartRate),
      isTrue,
    );
  });
  test('account switch discards an old pending data-ready refresh', () async {
    final fixture = await setup();
    final pending = Completer<List<HealthRecord>>();
    fixture.wearable.nextHistory = pending.future;
    final sync = fixture.controller.syncDeviceData();
    await _settle();
    fixture.wearable.notifyDataReady();
    await _settle();
    expect(
      await fixture.controller.login(
        'diagnostic-new-owner',
        'synthetic-password',
      ),
      isTrue,
    );
    final reads = fixture.wearable.syncCount;
    fixture.wearable.nextHistory = null;
    pending.complete(const []);
    expect(await sync, isFalse);
    await _settle();
    expect(fixture.wearable.syncCount, reads);
    expect(fixture.controller.connectedDevice, isNull);
  });

  testWidgets('completed nonstoppable result cannot time out afterward', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(() => setup()))!;
    expect(
      await fixture.controller.startMeasurement(HealthMetric.heartRate),
      isTrue,
    );
    fixture.wearable.emitResult();
    await tester.pump();
    expect(fixture.controller.activeMeasurementMetric, isNull);
    await tester.pump(const Duration(seconds: 76));
    expect(fixture.controller.measurementErrorMessage, isNull);
    expect(fixture.wearable.stopCount, 0);
  });
}

Future<void> _settle() async {
  for (var index = 0; index < 16; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Api extends Fake implements SaydianApi {
  @override
  Future<Session> login(String username, String password) async => Session(
    accessToken: 'synthetic-only',
    refreshToken: 'synthetic-only',
    expiresAt: DateTime.utc(2030),
    memberId: username,
    displayName: 'Diagnostic',
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
  @override
  Future<void> logout() async {}
}

class _Wearable extends Fake implements WearableBridge {
  _Wearable({required this.stoppable});
  static const watchId = 'urion:DIAGNOSTIC';
  static const watch = DeviceInfo(id: watchId, name: 'Synthetic watch');
  final bool stoppable;
  final eventsController = StreamController<WearableEvent>.broadcast();
  int syncCount = 0;
  int stopCount = 0;
  Future<List<HealthRecord>>? nextHistory;
  Completer<void>? startResult;
  void Function()? onSync;
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
    metrics: const {HealthMetric.heartRate},
    manualMetrics: const {HealthMetric.heartRate},
    stoppableManualMetrics: stoppable
        ? const {HealthMetric.heartRate}
        : const {},
  );
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    syncCount++;
    onSync?.call();
    return nextHistory ?? const [];
  }

  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    await startResult?.future;
  }

  @override
  Future<void> stopMeasurement(HealthMetric metric) async {
    stopCount++;
  }

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];
  void notifyDataReady({String? source}) => eventsController.add(
    WearableEvent(
      type: 'healthDataReady',
      payload: {'deviceId': watchId, 'source': ?source},
    ),
  );
  void emitResult({
    DateTime? measuredAt,
    MeasurementOrigin? origin,
    DateTime? measurementStartedAt,
  }) => eventsController.add(
    WearableEvent(
      type: 'healthRecord',
      payload: {
        ...HealthRecord(
          id: 'synthetic-result',
          metric: HealthMetric.heartRate,
          values: const {'value': 72},
          unit: 'bpm',
          measuredAt: measuredAt ?? DateTime.now().toUtc(),
          timezone: '+00:00',
          deviceId: watchId,
          firmwareVersion: 'synthetic',
          quality: 'device_reported',
          source: MeasurementSource.wearable,
          origin: origin,
          rawVersion: 1,
        ).toJson(),
        if (measurementStartedAt != null)
          'measurementStartedAt': measurementStartedAt.toIso8601String(),
      },
    ),
  );
}
