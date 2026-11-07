import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/ios_wellness_policy.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/urion_pulse_record.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/urion_pulse_history.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

UrionPulseRecord _record(int day, {String device = 'urion:fixture'}) {
  final time = DateTime.utc(2026, 10, day, 8);
  return UrionPulseRecord(
    deviceId: device,
    rawTimestamp: time.millisecondsSinceEpoch ~/ 1000,
    bloodStasis: day % 10,
    qiBlood: 6,
    dampness: 2,
    measuredAt: time,
  );
}

class _Api extends Fake implements SaydianApi {}

class _Watch extends Fake implements WearableBridge {
  Map<String, Object?> value = {};
  Completer<Map<String, Object?>>? gate;
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      gate?.future ?? value;
}

AppController _controller(HealthStore store, _Watch watch) =>
    AppController(MemorySessionVault(), _Api(), store, watch)
      ..isBooting = false
      ..connectedDevice = const DeviceInfo(id: 'urion:fixture', name: 'U19S')
      ..deviceCapabilityState = DeviceCapabilityState.ready
      ..capabilities = const DeviceCapabilities(
        metrics: {},
        features: {
          DeviceFeature.healthAssessment,
          DeviceFeature.healthMonitoring,
        },
        integratedFeatures: {
          DeviceFeature.healthAssessment,
          DeviceFeature.healthMonitoring,
        },
      );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pulse history preserves zeros, source and raw time; rejects invalid scores',
    () {
      final r = _record(10);
      expect(
        UrionPulseRecord.tryParse(r.toMap(), deviceId: r.deviceId)!.bloodStasis,
        0,
      );
      for (final bad in [11, -1, double.nan, '3']) {
        expect(
          UrionPulseRecord.tryParse({
            ...r.toMap(),
            'qiBlood': bad,
          }, deviceId: r.deviceId),
          isNull,
        );
      }
      expect(
        UrionPulseRecord.tryParse(r.toMap(), deviceId: 'urion:other'),
        isNull,
      );
      final future = UrionPulseRecord.tryParse({
        ...r.toMap(),
        'measuredAt': '2099-01-01T00:00:00Z',
      }, deviceId: r.deviceId)!;
      expect(future.displayTime(), isNull);
      expect(
        future.rawTimestamp,
        r.rawTimestamp,
      ); // Never re-date to read time.
    },
  );

  test(
    'iOS monitoring/pulse allowed only on the Urion source; cloud scope unchanged',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final local = IosWellnessPolicy.forSdkSource(WearableSdkSource.urion);
      for (final feature in [
        DeviceFeature.healthMonitoring,
        DeviceFeature.healthAssessment,
      ]) {
        expect(local.allowsFeature(feature), isTrue);
        expect(IosWellnessPolicy.current.allowsFeature(feature), isFalse);
        expect(
          IosWellnessPolicy.forSdkSource(
            WearableSdkSource.qring,
          ).allowsFeature(feature),
          isFalse,
        );
      }
      expect(local.allowsFeature(DeviceFeature.healthReminders), isFalse);
      expect(local.allowsMetric(HealthMetric.ecg), isFalse);
      expect(IosWellnessPolicy.cloud.allowedMetrics, {
        ...IosWellnessPolicy.metrics,
        ...IosWellnessPolicy.urionLocalMetrics,
      });
    },
  );

  test(
    'controller saves a full history, deduplicates rereads and survives controller recreation',
    () async {
      final store = MemoryHealthStore();
      final watch = _Watch()
        ..value = {
          'pulseHistory': [
            _record(2).toMap(),
            _record(1).toMap(),
            _record(2).toMap(),
          ],
        };
      final c = _controller(store, watch);
      addTearDown(c.dispose);
      var value = await c.readDeviceFeature(DeviceFeature.healthAssessment);
      expect(value['pulseHistory'], hasLength(2));
      value = await c.readDeviceFeature(DeviceFeature.healthAssessment);
      expect(value['pulseHistory'], hasLength(2));
      watch.value = {'pulse': _record(3).toMap(), 'justMeasured': true};
      value = await c.readDeviceFeature(DeviceFeature.healthAssessment);
      expect(value['pulseHistory'], hasLength(3));
      expect((value['pulse'] as Map)['rawTimestamp'], _record(3).rawTimestamp);
      watch.value = {'pulse': null, 'pulseHistory': []};
      final reopened = _controller(store, watch);
      addTearDown(reopened.dispose);
      value = await reopened.readDeviceFeature(DeviceFeature.healthAssessment);
      expect(value['pulseHistory'], hasLength(3));
      expect(
        await store.pending(),
        isEmpty,
      ); // Pulse indices never enter cloud health payloads.
      reopened.connectedDevice = const DeviceInfo(
        id: 'urion:other',
        name: 'U19S',
      );
      expect(
        (await reopened.readDeviceFeature(
          DeviceFeature.healthAssessment,
        ))['pulseHistory'],
        isEmpty,
      );
    },
  );

  test(
    'late history after a target change does not enter either device cache',
    () async {
      final store = MemoryHealthStore();
      final gate = Completer<Map<String, Object?>>();
      final watch = _Watch()..gate = gate;
      final c = _controller(store, watch);
      addTearDown(c.dispose);
      final pending = c.readDeviceFeature(DeviceFeature.healthAssessment);
      c.connectedDevice = const DeviceInfo(id: 'urion:other', name: 'U19S');
      gate.complete({
        'pulseHistory': [_record(1).toMap()],
      });
      expect(await pending, isEmpty);
      expect(c.deviceFeatureData, isEmpty);
      expect(
        await store.readUrionPulseHistory(
          ownerId: 'anonymous',
          deviceId: 'urion:fixture',
        ),
        isEmpty,
      );
    },
  );

  test(
    'SQLite pulse metadata reopens, isolates owners/devices and never replaces original content',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('global-pulse-test-');
      addTearDown(() => dir.delete(recursive: true));
      EncryptedHealthStore open() => EncryptedHealthStore(
        MemorySessionVault(),
        databasePathProvider: () async => '${dir.path}/health.db',
        databaseOpener:
            (
              file, {
              required password,
              required version,
              onConfigure,
              onCreate,
              onUpgrade,
            }) => databaseFactoryFfi.openDatabase(
              file,
              options: OpenDatabaseOptions(
                version: version,
                onConfigure: onConfigure,
                onCreate: onCreate,
                onUpgrade: onUpgrade,
              ),
            ),
      );
      final a = open();
      await a.initialize();
      await a.saveUrionPulseHistory([
        _record(1),
        _record(1),
        _record(2),
        _record(3, device: 'urion:other'),
      ], ownerId: 'owner-a');
      await a.saveUrionPulseHistory([_record(4)], ownerId: 'owner-b');
      await a.close();
      final b = open();
      await b.initialize();
      addTearDown(b.close);
      var rows = await b.readUrionPulseHistory(
        ownerId: 'owner-a',
        deviceId: 'urion:fixture',
      );
      expect(rows.map((r) => r.rawTimestamp), [
        _record(2).rawTimestamp,
        _record(1).rawTimestamp,
      ]);
      expect(rows.last.toMap(), _record(1).toMap());
      rows = await b.readUrionPulseHistory(
        ownerId: 'owner-b',
        deviceId: 'urion:fixture',
      );
      expect(rows.single.toMap(), _record(4).toMap());
      expect(
        await b.readUrionPulseHistory(
          ownerId: 'anonymous',
          deviceId: 'urion:fixture',
        ),
        isEmpty,
      );
      expect(
        (await b.readUrionPulseHistory(
          ownerId: 'owner-a',
          deviceId: 'urion:other',
        )).length,
        1,
      );
      expect(await b.pending(), isEmpty);
    },
  );

  testWidgets(
    'pulse chart uses three exact dated series, filters and pages history',
    (tester) async {
      final records = [for (var i = 1; i <= 25; i++) _record(i)];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: UrionPulseHistory(records: records),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<LineChart>(
        find.byKey(const Key('u19-pulse-trend-chart')),
      );
      expect(chart.data.lineBarsData, hasLength(3));
      expect(chart.data.lineBarsData[0].spots, hasLength(25));
      expect(
        chart.data.lineBarsData[0].spots.first.x,
        _record(1).measuredAt.millisecondsSinceEpoch / 1000,
      );
      expect(chart.data.lineBarsData[0].spots.first.y, 1);
      expect(find.text('Saved readings (25)'), findsOneWidget);
      await tester.ensureVisible(find.text('Show more'));
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Show more'), findsNothing);
      await tester.ensureVisible(find.text('7 days'));
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      expect(find.text('No dated readings in this period.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['en', 'zh']) {
    testWidgets(
      'small screen large type pulse history $locale and one-sample state',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: UrionPulseHistory(records: [_record(1)]),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final chart = tester.widget<LineChart>(
          find.byKey(const Key('u19-pulse-trend-chart')),
        );
        expect(
          chart.data.lineBarsData.every((s) => s.spots.length == 1),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'iOS U19 monitoring entrance opens actual dynamic schedule without writes',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final watch = _Watch()
          ..value = {
            'dynamicBloodPressure': {
              'enabled': false,
              'startHour': 8,
              'dayIntervalMinutes': 60,
              'nightIntervalMinutes': 90,
            },
          };
        final c = _controller(MemoryHealthStore(), watch);
        addTearDown(c.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DeviceFeaturePage(
              controller: c,
              feature: DeviceFeature.healthMonitoring,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Scheduled blood pressure'), findsOneWidget);
        await tester.tap(find.text('Set schedule'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('u19-dynamic-pressure-editor')),
          findsOneWidget,
        );
        // _Watch has no write implementation: entering/editing cannot send a write.
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
