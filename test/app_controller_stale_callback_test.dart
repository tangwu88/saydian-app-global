import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

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
    HealthStore? store,
    _Api? api,
    Duration wearableAutoSyncInterval = const Duration(minutes: 30),
  }) async {
    final wearable = _Wearable();
    final controller = AppController(
      MemorySessionVault(),
      api ?? _Api(),
      store ?? MemoryHealthStore(),
      wearable,
      wearableAutoSyncInterval: wearableAutoSyncInterval,
    );
    addTearDown(() async {
      controller.dispose();
      await wearable.eventsController.close();
    });
    await controller.initialize();
    expect(
      await controller.login('synthetic-first', 'synthetic-password'),
      isTrue,
    );
    await controller.connectDevice(_Wearable.first);
    await _settle();
    expect(controller.deviceState, DeviceConnectionState.ready);
    return (controller: controller, wearable: wearable);
  }

  for (final sameDevice in [false, true]) {
    test(
      'old null details cannot retire ${sameDevice ? 'same-ID reconnect' : 'another watch'} measurement',
      () async {
        final fixture = await setup();
        final details = Completer<DeviceInfo?>();
        fixture.wearable.details = details.future;
        final refresh = fixture.controller.refreshConnectedDeviceDetails();
        await _settle();
        final target = sameDevice ? _Wearable.first : _Wearable.second;
        await fixture.controller.connectDevice(target);
        await _settle();
        expect(
          await fixture.controller.startMeasurement(HealthMetric.heartRate),
          isTrue,
        );
        final measurementSession = fixture.controller.measurementSessionId;
        details.complete(null);
        expect(await refresh, isFalse);
        expect(fixture.controller.connectedDevice?.id, target.id);
        expect(
          fixture.controller.activeMeasurementMetric,
          HealthMetric.heartRate,
        );
        expect(fixture.controller.measurementSessionId, measurementSession);
        expect(fixture.controller.measurementErrorMessage, isNull);
        expect(fixture.controller.errorMessage, isNull);
      },
    );
  }

  for (final platformError in [false, true]) {
    test(
      'old ${platformError ? 'platform' : 'generic'} details error stays in its session',
      () async {
        final fixture = await setup();
        final details = Completer<DeviceInfo?>();
        fixture.wearable.details = details.future;
        final refresh = fixture.controller.refreshConnectedDeviceDetails();
        await _settle();
        await fixture.controller.connectDevice(_Wearable.second);
        await _settle();
        fixture.controller.errorMessage = 'Current session notice';
        details.completeError(
          platformError
              ? PlatformException(code: 'SYNTHETIC_OLD_DETAILS')
              : StateError('Synthetic old details failure'),
        );
        expect(await refresh, isFalse);
        expect(fixture.controller.connectedDevice?.id, _Wearable.second.id);
        expect(fixture.controller.errorMessage, 'Current session notice');
      },
    );
  }

  test('old successful details cannot overwrite a same-ID reconnect', () async {
    final fixture = await setup();
    final details = Completer<DeviceInfo?>();
    fixture.wearable.details = details.future;
    final refresh = fixture.controller.refreshConnectedDeviceDetails();
    await _settle();
    await fixture.controller.connectDevice(_Wearable.first);
    await _settle();
    details.complete(
      const DeviceInfo(
        id: _Wearable.firstId,
        name: 'Synthetic old connection',
        firmwareVersion: 'stale-firmware',
      ),
    );
    expect(await refresh, isFalse);
    expect(
      fixture.controller.connectedDevice?.firmwareVersion,
      isNot('stale-firmware'),
    );
  });

  test('old account details cannot clear a new account connection', () async {
    final fixture = await setup();
    final details = Completer<DeviceInfo?>();
    fixture.wearable.details = details.future;
    final refresh = fixture.controller.refreshConnectedDeviceDetails();
    await _settle();
    expect(
      await fixture.controller.login('synthetic-second', 'synthetic-password'),
      isTrue,
    );
    await fixture.controller.connectDevice(_Wearable.first);
    await _settle();
    details.complete(null);
    expect(await refresh, isFalse);
    expect(fixture.controller.connectedDevice?.id, _Wearable.firstId);
    expect(fixture.controller.errorMessage, isNull);
  });

  test('current null details still clears the current measurement', () async {
    final fixture = await setup();
    expect(
      await fixture.controller.startMeasurement(HealthMetric.heartRate),
      isTrue,
    );
    fixture.wearable.details = Future<DeviceInfo?>.value();
    expect(await fixture.controller.refreshConnectedDeviceDetails(), isFalse);
    expect(fixture.controller.connectedDevice, isNull);
    expect(fixture.controller.activeMeasurementMetric, isNull);
    expect(fixture.controller.errorMessage, contains('断开'));
  });

  test(
    'old account persistence failure cannot overwrite a new account notice',
    () async {
      final store = _DelayedStore();
      final fixture = await setup(store: store);
      fixture.wearable.emitResult();
      await _settle();
      expect(store.writes, 1);
      expect(
        await fixture.controller.login(
          'synthetic-second',
          'synthetic-password',
        ),
        isTrue,
      );
      fixture.controller.errorMessage = 'Current account notice';
      store.result.completeError(
        StateError('Synthetic old persistence failure'),
      );
      await _settle();
      expect(fixture.controller.errorMessage, 'Current account notice');
      expect(fixture.controller.healthRecords, isEmpty);
    },
  );

  test(
    'current account persistence failure still reports unsaved data',
    () async {
      final store = _DelayedStore();
      final fixture = await setup(store: store);
      fixture.wearable.emitResult();
      await _settle();
      expect(store.writes, 1);
      store.result.completeError(
        StateError('Synthetic current persistence failure'),
      );
      await _settle();
      expect(fixture.controller.errorMessage, contains('暂时无法保存到本机'));
    },
  );

  test(
    'cloud state distinguishes no records, uploading and confirmed upload',
    () async {
      final store = MemoryHealthStore();
      final api = _ControlledUploadApi();
      final fixture = await setup(store: store, api: api);
      await fixture.controller.synchronizeCloud();
      expect(fixture.controller.cloudSyncState, CloudHealthSyncState.idle);
      await store.upsert([_record()]);
      final result = Completer<BatchUploadResult>();
      api.upload = (_) => result.future;
      final sync = fixture.controller.synchronizeCloud();
      await _settle();
      expect(fixture.controller.cloudSyncState, CloudHealthSyncState.uploading);
      expect(fixture.controller.cloudSyncUploadedCount, 0);
      result.complete(
        const BatchUploadResult(
          nextCursor: null,
          acceptedIds: {'synthetic-late-save'},
          rejected: {},
        ),
      );
      await sync;
      expect(fixture.controller.cloudSyncState, CloudHealthSyncState.complete);
      expect(fixture.controller.cloudSyncUploadedCount, 1);
      expect(
        await fixture.controller.login(
          'synthetic-second',
          'synthetic-password',
        ),
        isTrue,
      );
      expect(fixture.controller.cloudSyncState, CloudHealthSyncState.idle);
      expect(fixture.controller.cloudSyncUploadedCount, 0);
    },
  );

  test(
    'already ACKed records keep a confirmed state on repeated sync',
    () async {
      final api = _Api();
      final fixture = await setup(api: api);
      fixture.wearable.emitResult();
      await _waitFor(() => api.uploadedIds.contains('synthetic-late-save'));
      await _waitFor(
        () =>
            fixture.controller.cloudSyncState == CloudHealthSyncState.complete,
      );
      expect(fixture.controller.healthRecords, isNotEmpty);
      final uploadCount = api.uploadedIds.length;

      await fixture.controller.syncDeviceData();
      await fixture.controller.synchronizeCloud();
      await _waitFor(
        () =>
            fixture.controller.cloudSyncState != CloudHealthSyncState.uploading,
      );
      expect(api.uploadedIds.length, uploadCount);
      expect(fixture.controller.cloudSyncUploadedCount, 0);
      expect(fixture.controller.cloudSyncState, CloudHealthSyncState.complete);
      expect(fixture.controller.cloudSyncStatus, '数据已同步，无待上传记录');
    },
  );

  test(
    'connected watch retries pending records every 30 minutes without reuploading ACKed IDs',
    () async {
      final store = MemoryHealthStore();
      final api = _Api();
      final fixture = await setup(
        store: store,
        api: api,
        wearableAutoSyncInterval: const Duration(milliseconds: 50),
      );
      final initialReads = fixture.wearable.syncCount;
      await store.upsert([_record()]);
      await _waitFor(() => fixture.wearable.syncCount >= initialReads + 1);
      await _waitFor(() => api.uploadedIds.contains('synthetic-late-save'));
      expect(fixture.wearable.syncCount, initialReads + 1);
      expect(api.uploadedIds, ['synthetic-late-save']);
      expect(await store.pending(), isEmpty);

      await _waitFor(() => fixture.wearable.syncCount >= initialReads + 2);
      expect(fixture.wearable.syncCount, initialReads + 2);
      expect(api.uploadedIds, ['synthetic-late-save']);
      expect(await store.pending(), isEmpty);

      fixture.controller.setAppForeground(false);
      final backgroundReads = fixture.wearable.syncCount;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(fixture.wearable.syncCount, backgroundReads);

      fixture.controller.setAppForeground(true);
      await _waitFor(() => fixture.wearable.syncCount >= backgroundReads + 1);

      await fixture.controller.disconnectDevice();
      final disconnectedReads = fixture.wearable.syncCount;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(fixture.wearable.syncCount, disconnectedReads);
    },
  );

  test(
    'connected watch retries pending cloud uploads even when history read fails',
    () async {
      final store = MemoryHealthStore();
      final api = _Api();
      final fixture = await setup(
        store: store,
        api: api,
        wearableAutoSyncInterval: const Duration(milliseconds: 50),
      );
      fixture.wearable.syncError = StateError('Synthetic history failure');
      final initialReads = fixture.wearable.syncCount;
      await store.upsert([_record()]);

      await _waitFor(() => api.uploadedIds.contains('synthetic-late-save'));

      expect(fixture.wearable.syncCount, greaterThan(initialReads));
      expect(api.uploadedIds, ['synthetic-late-save']);
      expect(await store.pending(), isEmpty);
    },
  );

  test(
    'unacknowledged records and upload failures retain pending state',
    () async {
      final store = MemoryHealthStore();
      final api = _ControlledUploadApi();
      final fixture = await setup(store: store, api: api);
      await store.upsert([_record()]);
      api.upload = (_) async => const BatchUploadResult(
        nextCursor: null,
        acceptedIds: {},
        rejected: {},
      );
      await fixture.controller.synchronizeCloud();
      expect(fixture.controller.cloudSyncState, CloudHealthSyncState.pending);
      expect(fixture.controller.cloudSyncUploadedCount, 0);
      expect(await store.pending(), hasLength(1));
      api.upload = (_) async => throw StateError('Synthetic upload failure');
      await fixture.controller.synchronizeCloud();
      expect(fixture.controller.cloudSyncState, CloudHealthSyncState.pending);
      expect(await store.pending(), hasLength(1));
    },
  );

  test('held daily summaries are pending rather than cloud complete', () async {
    final store = MemoryHealthStore();
    final fixture = await setup(store: store);
    await store.upsert([_record(daily: true)]);
    await fixture.controller.synchronizeCloud();
    expect(fixture.controller.cloudSyncState, CloudHealthSyncState.pending);
    expect(fixture.controller.cloudSyncUploadedCount, 0);
    expect(await store.pending(), hasLength(1));
  });

  test('signed-out cloud request reports local-only state', () async {
    final controller = AppController(
      MemorySessionVault(),
      _Api(),
      MemoryHealthStore(),
      _Wearable(),
    );
    addTearDown(controller.dispose);
    await controller.synchronizeCloud();
    expect(controller.cloudSyncState, CloudHealthSyncState.localOnly);
    expect(controller.cloudSyncUploadedCount, 0);
  });
}

HealthRecord _record({bool daily = false}) => HealthRecord(
  id: 'synthetic-late-save',
  metric: daily ? HealthMetric.steps : HealthMetric.heartRate,
  values: daily ? const {'value': 1000} : const {'value': 72},
  unit: daily ? 'steps' : 'bpm',
  measuredAt: DateTime.now().toUtc(),
  timezone: '+00:00',
  deviceId: _Wearable.firstId,
  firmwareVersion: 'synthetic',
  quality: 'device_reported',
  source: MeasurementSource.wearable,
  rawVersion: 1,
  aggregation: daily
      ? const HealthAggregation.dailySummary('2026-09-28')
      : null,
);

class _ControlledUploadApi extends _Api {
  Future<BatchUploadResult> Function(SyncBatch)? upload;
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) =>
      upload?.call(batch) ?? super.uploadHealthBatch(batch);
}

Future<void> _settle() async {
  for (var index = 0; index < 16; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'Expected asynchronous sync was not run');
}

class _DelayedStore extends MemoryHealthStore {
  final result = Completer<void>();
  int writes = 0;
  @override
  Future<void> upsertImmediate(HealthRecord record) {
    writes++;
    return result.future;
  }
}

class _Api extends Fake implements SaydianApi {
  final uploadedIds = <String>[];

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
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    uploadedIds.addAll(batch.records.map((record) => record.id));
    return BatchUploadResult(
      nextCursor: null,
      acceptedIds: batch.records.map((record) => record.id).toSet(),
      rejected: const {},
    );
  }
}

class _Wearable extends Fake
    implements WearableBridge, WearableDeviceDetailsBridge {
  static const firstId = 'urion:SYNTHETIC-FIRST';
  static const first = DeviceInfo(id: firstId, name: 'Synthetic first');
  static const second = DeviceInfo(
    id: 'urion:SYNTHETIC-SECOND',
    name: 'Synthetic second',
  );
  final eventsController = StreamController<WearableEvent>.broadcast();
  int syncCount = 0;
  Object? syncError;
  Future<DeviceInfo?>? details;
  @override
  Stream<WearableEvent> get events => eventsController.stream;
  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async {
    final pending = details;
    return pending != null ? await pending : first;
  }

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
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(
        metrics: {HealthMetric.heartRate},
        manualMetrics: {HealthMetric.heartRate},
        stoppableManualMetrics: {},
      );
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    syncCount++;
    final error = syncError;
    if (error != null) throw error;
    return const [];
  }

  @override
  Future<void> startMeasurement(HealthMetric metric) async {}
  @override
  Future<void> stopMeasurement(HealthMetric metric) async {}
  @override
  Future<List<SportRecord>> readSportRecords() async => const [];

  void emitResult() => eventsController.add(
    WearableEvent(
      type: 'healthRecord',
      payload: HealthRecord(
        id: 'synthetic-late-save',
        metric: HealthMetric.heartRate,
        values: const {'value': 72},
        unit: 'bpm',
        measuredAt: DateTime.now().toUtc(),
        timezone: '+00:00',
        deviceId: firstId,
        firmwareVersion: 'synthetic',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      ).toJson(),
    ),
  );
}
