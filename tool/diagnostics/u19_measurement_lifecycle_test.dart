import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

// AUDIT-ONLY diagnostic: run this file explicitly; it is intentionally outside
// test/ and does not join the default Flutter test suite.
// Baseline 2026-09-28: one control passes and four correct-behavior assertions
// fail, recording unresolved defects rather than making failures expected.
// Command: flutter test --no-pub tool/diagnostics/u19_measurement_lifecycle_test.dart
// Public-API diagnostic, adapted from app_controller_account_wearable_test.dart.
// All identities, sessions and health samples here are synthetic; no network,
// phone, watch, production storage or protocol writes are used.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    return nextHistory ?? const [];
  }

  @override
  Future<void> startMeasurement(HealthMetric metric) async {}
  @override
  Future<void> stopMeasurement(HealthMetric metric) async {
    stopCount++;
  }

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];
  void emitResult() => eventsController.add(
    WearableEvent(
      type: 'healthRecord',
      payload: HealthRecord(
        id: 'synthetic-result',
        metric: HealthMetric.heartRate,
        values: const {'value': 72},
        unit: 'bpm',
        measuredAt: DateTime.now().toUtc(),
        timezone: '+00:00',
        deviceId: watchId,
        firmwareVersion: 'synthetic',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      ).toJson(),
    ),
  );
}
