import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/ios_wellness_policy.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/sync_service.dart';

Session session(String owner) => Session(
  accessToken: 'synthetic-$owner',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: owner,
  displayName: 'Synthetic',
  accountKey: 'global:member:$owner',
);

HealthRecord sensor(HealthMetric metric, {String device = 'urion:fixture'}) =>
    HealthRecord(
      id: 'synthetic-${metric.name}',
      metric: metric,
      values: switch (metric) {
        HealthMetric.bloodPressure => const {'systolic': 120, 'diastolic': 80},
        HealthMetric.bloodOxygen => const {'value': 98},
        _ => const {'value': 72},
      },
      unit: metric.defaultUnit,
      measuredAt: DateTime.utc(2026, 11, 4, 3),
      timezone: '+08:00',
      deviceId: device,
      firmwareVersion: 'synthetic',
      sourceModel: 'synthetic',
      quality: 'unknown',
      source: MeasurementSource.wearable,
      origin: MeasurementOrigin.appMeasurement,
      rawVersion: 1,
    );

http.Response ok(Object data) =>
    http.Response(jsonEncode({'code': 200, 'data': data}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final device in ['urion:fixture', 'qring:fixture', 'coolwear:fixture']) {
    test(
      'iOS saved sensor upload preserves origin and values: $device',
      () async {
        final originals = [
          for (final metric in IosWellnessPolicy.urionLocalMetrics)
            sensor(metric, device: device),
        ];
        final store = MemoryHealthStore();
        await store.switchOwner('a');
        await store.upsert(originals);
        final uploaded = <Map>[];
        final api = GlobalSaydianApiClient(
          MemorySessionVault()..session = session('a'),
          client: MockClient((request) async {
            expect(request.url.origin, 'https://app.saydian.com');
            if (request.url.path.endsWith('/health/capabilities')) {
              return ok({'dailySummaryVersions': true});
            }
            expect(request.method, 'POST');
            expect(
              request.url.path,
              '/global/api/saydian-app/v2/health/records/batch',
            );
            final rows = ((jsonDecode(request.body) as Map)['records'] as List)
                .cast<Map>();
            uploaded.addAll(rows);
            for (final row in rows) {
              final original = originals.singleWhere((r) => r.id == row['id']);
              expect(row['values'], original.values);
              expect(row['observedAt'], original.measuredAt.toIso8601String());
              expect(row['timezoneOffsetMinutes'], 480);
              expect(row['unit'], original.unit);
              expect(row['source']['platform'], 'ios');
              expect(row['source']['deviceId'], device);
              expect(row['source']['origin'], 'app_measurement');
            }
            return ok({
              'acceptedIds': rows.map((r) => r['id']).toList(),
              'rejected': [],
              'nextCursor': null,
            });
          }),
        );
        final service = HealthSyncService(store, api);
        expect((await service.synchronizeNow()).uploaded, 3);
        expect(await store.pending(), isEmpty);
        expect(await store.recent(), hasLength(3));
        expect((await service.synchronizeNow()).uploaded, 0);
        expect(uploaded, hasLength(3));
      },
    );
  }

  for (final failure in ['partial', 'foreign-ack', 'network']) {
    test('iOS $failure preserves unconfirmed rows for retry', () async {
      final store = MemoryHealthStore();
      final rows = [
        for (final m in IosWellnessPolicy.urionLocalMetrics) sensor(m),
      ];
      await store.upsert(rows);
      var retry = false;
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = session('a'),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/capabilities')) return ok({});
          final ids = ((jsonDecode(request.body) as Map)['records'] as List)
              .map((r) => (r as Map)['id'])
              .toList();
          if (!retry && failure == 'network') {
            throw http.ClientException('offline');
          }
          return ok({
            'acceptedIds': retry
                ? ids
                : failure == 'partial'
                ? [rows.first.id]
                : ['another-account-record'],
            'rejected': [],
            'nextCursor': null,
          });
        }),
      );
      final service = HealthSyncService(store, api);
      if (failure == 'partial') {
        final first = await service.synchronizeNow();
        expect(first.hasPending, isTrue);
        expect(first.uploaded, 1);
      } else {
        await expectLater(
          service.synchronizeNow(),
          throwsA(isA<ApiException>()),
        );
      }
      expect(await store.pending(), hasLength(failure == 'partial' ? 2 : 3));
      retry = true;
      expect(
        (await service.synchronizeNow()).uploaded,
        failure == 'partial' ? 2 : 3,
      );
      expect(await store.pending(), isEmpty);
      expect(await store.recent(), hasLength(3));
    });
  }

  test('shared physiology cannot become own cloud history', () async {
    var requests = 0;
    final api = GlobalSaydianApiClient(
      MemorySessionVault()..session = session('a'),
      client: MockClient((_) async {
        requests++;
        return ok({});
      }),
    );
    final shared = sensor(
      HealthMetric.heartRate,
    ).copyWith(origin: MeasurementOrigin.remoteMember);
    final result = await api.uploadHealthBatch(
      SyncBatch(cursor: null, records: [shared]),
    );
    expect(result.acceptedIds, isEmpty);
    expect(result.rejected.keys, contains(shared.id));
    expect(requests, 0);
  });

  test('new cloud scope does not grant acquisition or care permissions', () {
    for (final m in IosWellnessPolicy.urionLocalMetrics) {
      expect(IosWellnessPolicy.cloud.allowsMetric(m), isTrue);
      expect(IosWellnessPolicy.current.allowsMetric(m), isFalse);
      expect(IosWellnessPolicy.cloud.allowsMeasurement(m), isFalse);
    }
    expect(IosWellnessPolicy.cloud.allowsMetric(HealthMetric.ecg), isFalse);
    expect(IosWellnessPolicy.cloud.allowsWireMetric('unknown_sensor'), isFalse);
  });

  test(
    'account replacement during sensor ACK cannot consume old queue',
    () async {
      final store = MemoryHealthStore();
      await store.switchOwner('a');
      final row = sensor(HealthMetric.bloodPressure);
      await store.upsert([row]);
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final vault = MemorySessionVault()..session = session('a');
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/capabilities')) return ok({});
          started.complete();
          return response.future;
        }),
      );
      var current = true;
      final sync = HealthSyncService(
        store,
        api,
      ).synchronizeNow(isCurrent: () => current);
      await started.future;
      current = false;
      await vault.writeSession(session('b'));
      await store.switchOwner('b');
      final staleSession = expectLater(sync, throwsA(isA<ApiException>()));
      response.complete(
        ok({
          'acceptedIds': [row.id],
          'rejected': [],
          'nextCursor': null,
        }),
      );
      await staleSession;
      expect(await store.pending(), isEmpty);
      await store.switchOwner('a');
      expect((await store.pending()).single.id, row.id);
    },
  );
}
