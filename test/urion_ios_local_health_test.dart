import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/ios_wellness_policy.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/sync_service.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/services/wearable_routing.dart';
import 'package:saydian_app/ui/pages.dart';

HealthRecord record(HealthMetric metric, {String device = 'urion:synthetic'}) =>
    HealthRecord(
      id: 'synthetic-${metric.name}',
      metric: metric,
      values: metric == HealthMetric.bloodPressure
          ? const {'systolic': 120, 'diastolic': 80}
          : const {'value': 80},
      unit: metric.defaultUnit,
      measuredAt: DateTime.now().toUtc(),
      timezone: '+00:00',
      deviceId: device,
      firmwareVersion: 'synthetic',
      quality: 'unknown',
      source: MeasurementSource.wearable,
      rawVersion: 1,
    );

class _Api implements SaydianApi {
  final uploaded = <HealthRecord>[];
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    uploaded.addAll(batch.records);
    return BatchUploadResult(
      acceptedIds: batch.records.map((r) => r.id).toSet(),
      rejected: const {},
      nextCursor: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API: ${invocation.memberName}');
}

class _Wearable implements WearableBridge {
  _Wearable(this.device);
  final DeviceInfo device;
  final measurements = <HealthMetric>[];
  @override
  Stream<WearableEvent> get events => const Stream.empty();
  @override
  Future<List<DeviceInfo>> scanDevices() async => [device];
  @override
  Future<void> connect(
    String id, {
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(
        metrics: {HealthMetric.bloodPressure, HealthMetric.bloodGlucose},
        manualMetrics: {HealthMetric.bloodPressure, HealthMetric.bloodGlucose},
      );
  @override
  Future<void> startMeasurement(HealthMetric metric) async =>
      measurements.add(metric);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected SDK: ${invocation.memberName}');
}

class _Preference implements WearableTransportPreferenceStore {
  @override
  Future<WearableTransport?> read() async => null;
  @override
  Future<void> write(WearableTransport value) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('local Urion scope retains cloud and other device boundaries', () {
    final local = IosWellnessPolicy.forSdkSource(WearableSdkSource.urion);
    final pressure = record(HealthMetric.bloodPressure);
    expect(local.enabled, isTrue);
    expect(local.projectRecord(pressure)!.values, pressure.values);
    expect(
      local.projectRecord(
        record(HealthMetric.bloodPressure, device: 'qring:synthetic'),
      ),
      isNull,
    );
    expect(local.allowsMetric(HealthMetric.ecg), isFalse);
    expect(IosWellnessPolicy.current.projectRecord(pressure), isNull);
    expect(
      IosWellnessPolicy.forSdkSource(
        WearableSdkSource.coolwear,
      ).allowsMeasurement(HealthMetric.bloodPressure),
      isFalse,
    );
    expect(
      local
          .projectCapabilities(
            const DeviceCapabilities(
              metrics: {HealthMetric.bloodPressure},
              manualMetrics: {},
            ),
          )
          .supportsManualMeasurement(HealthMetric.bloodPressure),
      isFalse,
    );
  });

  test(
    'local sensor history remains local while activity receives ACK',
    () async {
      final store = MemoryHealthStore();
      final api = _Api();
      await store.initialize();
      await store.upsert([
        record(HealthMetric.bloodPressure),
        record(HealthMetric.steps),
      ]);
      final result = await HealthSyncService(store, api).synchronizeNow();
      expect(result.uploaded, 1);
      expect(api.uploaded.single.metric, HealthMetric.steps);
      expect((await store.pending()).single.metric, HealthMetric.bloodPressure);
      expect((await store.recent()).length, 2);
    },
  );

  test(
    'router uses confirmed Urion transport and refuses unimplemented metrics',
    () async {
      final urion = _Wearable(const DeviceInfo(id: 'synthetic', name: 'U19S'));
      final bridge = RoutedWearableBridge(
        veepoo: _Wearable(const DeviceInfo(id: 'other', name: 'Other')),
        yucheng: _Wearable(const DeviceInfo(id: 'other2', name: 'Other2')),
        urion: urion,
        preferenceStore: _Preference(),
      );
      addTearDown(bridge.dispose);
      await bridge.scanDevices();
      await bridge.connect(
        'urion:synthetic',
        profile: const WearableUserProfile(
          gender: 1,
          heightCm: 170,
          weightKg: 65,
          birthYear: 1990,
          age: 36,
          targetSteps: 6000,
        ),
      );
      final caps = await bridge.getCapabilities();
      expect(caps.supports(HealthMetric.bloodPressure), isTrue);
      expect(caps.supports(HealthMetric.bloodGlucose), isFalse);
      await bridge.startMeasurement(HealthMetric.bloodPressure);
      expect(urion.measurements, [HealthMetric.bloodPressure]);
      await expectLater(
        bridge.startMeasurement(HealthMetric.bloodGlucose),
        throwsA(isA<Exception>()),
      );
    },
  );

  testWidgets(
    'connected U19S shows supported sensors without home storage banner',
    (tester) async {
      try {
        final controller = AppController(
          MemorySessionVault(),
          _Api(),
          MemoryHealthStore(),
          _Wearable(const DeviceInfo(id: 'synthetic', name: 'U19S')),
        );
        addTearDown(controller.dispose);
        controller.connectedDevice = const DeviceInfo(
          id: 'urion:synthetic',
          name: 'U19S',
        );
        controller.capabilities = const DeviceCapabilities(
          metrics: {
            HealthMetric.steps,
            HealthMetric.bloodPressure,
            HealthMetric.heartRate,
          },
          manualMetrics: {HealthMetric.bloodPressure},
        );
        expect(
          controller.shouldShowHealthMetric(HealthMetric.bloodPressure),
          isTrue,
        );
        expect(
          controller.shouldShowHealthMetric(HealthMetric.bloodOxygen),
          isFalse,
        );
        expect(
          controller.canMeasureHealthMetric(HealthMetric.heartRate),
          isFalse,
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DashboardPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('urion-local-health-notice')),
          findsNothing,
        );
        expect(find.textContaining('stay on this phone'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Blood pressure'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Blood pressure'), findsOneWidget);
        expect(find.text('Health alerts'), findsNothing);
        expect(find.text('AI wellness assistant'), findsNothing);
        expect(
          controller.sharingPolicy.allowsMetric(HealthMetric.bloodPressure),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
