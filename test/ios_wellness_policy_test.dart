import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:saydian_app/domain/feature_models.dart';
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
import 'package:saydian_app/ui/health_trend_page.dart';
import 'package:saydian_app/ui/prototype_pages.dart';

HealthRecord _record(
  String id,
  HealthMetric metric, {
  Map<String, num>? values,
}) => HealthRecord(
  id: id,
  metric: metric,
  values: values ?? {'value': metric == HealthMetric.sleep ? 7 : 80},
  unit: metric.defaultUnit,
  measuredAt: DateTime.utc(2026, 10, 1),
  timezone: '+08:00',
  deviceId: 'synthetic-device',
  firmwareVersion: 'qa',
  quality: 'poor',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);

class _Api implements SaydianApi, HealthRecordPreparationApi {
  final List<HealthRecord> uploaded = [];
  final List<HealthRecord> prepared = [];
  bool acknowledge = true;
  @override
  Future<HealthRecord> prepareHealthRecord(HealthRecord record) async {
    prepared.add(record);
    return record;
  }

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    uploaded.addAll(batch.records);
    return BatchUploadResult(
      acceptedIds: acknowledge
          ? {...batch.records.map((record) => record.id), 'old-heart'}
          : {'old-heart'},
      rejected: const {},
      nextCursor: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call: ${invocation.memberName}');
}

class _Wearable implements WearableBridge {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected wearable call: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final page in ['detail', 'trend']) {
    testWidgets('daily $page caption has a date but no invented time', (
      tester,
    ) async {
      try {
        final day = page == 'detail' ? DateTime(2026, 9, 30) : DateTime.now();
        final record = _record('daily', HealthMetric.steps).copyWith(
          aggregation: HealthAggregation.dailySummary(
            DateFormat('yyyy-MM-dd').format(day),
          ),
        );
        final controller = AppController(
          MemorySessionVault(),
          _Api(),
          MemoryHealthStore(),
          _Wearable(),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: page == 'detail'
                ? HealthRecordDetailPage(controller: controller, record: record)
                : HealthTrendPage(
                    controller: controller,
                    metric: HealthMetric.steps,
                    recordLoader: (_, _) async => [record],
                  ),
          ),
        );
        await tester.pumpAndSettle();
        final dateLabel = find.text(DateFormat.yMMMd('en').format(day));
        if (page == 'trend') {
          await tester.scrollUntilVisible(
            dateLabel,
            300,
            scrollable: find.byType(Scrollable).first,
          );
        }
        expect(dateLabel, findsOneWidget);
        expect(find.textContaining('12:00 AM'), findsNothing);
        expect(find.textContaining('Oct 1, 2026'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  test(
    'future timestamps remain immutable for transport but are not displayed',
    () {
      final now = DateTime.utc(2026, 10, 7);
      final future = _record(
        'synthetic-future',
        HealthMetric.steps,
      ).copyWith(measuredAt: now.add(const Duration(minutes: 11)));
      final policy = IosWellnessPolicy.current;
      expect(policy.isDisplayable(future, now: now), isFalse);
      expect(policy.projectRecord(future)!.measuredAt, future.measuredAt);
      expect(policy.projectRecord(future)!.id, future.id);
      expect(
        const IosWellnessPolicy(enabled: false).isDisplayable(future, now: now),
        isTrue,
      );
    },
  );

  test('iOS scope is account-independent and Android retains all metrics', () {
    expect(IosWellnessPolicy.current.enabled, isTrue);
    expect(
      IosWellnessPolicy.blockedEB1Commands,
      containsAll([0x14, 0x16, 0x2c]),
    );
    expect(IosWellnessPolicy.blockedEB1Commands, isNot(contains(0x07)));
    for (final metric in HealthMetric.values) {
      expect(
        IosWellnessPolicy.current.allowsMetric(metric),
        IosWellnessPolicy.metrics.contains(metric),
      );
    }
    expect(
      IosWellnessPolicy.current.allowsWireMetric('unknown_sensor'),
      isFalse,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(IosWellnessPolicy.current.enabled, isFalse);
    for (final metric in HealthMetric.values) {
      final original = _record('android', metric);
      expect(
        identical(IosWellnessPolicy.current.projectRecord(original), original),
        isTrue,
      );
    }
  });

  test(
    'sleep projection strips score, physiology and waveform without modifying source',
    () {
      final original = _record(
        'sleep',
        HealthMetric.sleep,
        values: const {
          'hours': 7,
          'deepHours': 2,
          'lightHours': 5,
          'sleepScore': 90,
          'heartRate': 70,
          'apneaRisk': 1,
        },
      ).copyWith(samples: [1, 2, 3]);
      final projected = IosWellnessPolicy.current.projectRecord(original)!;
      expect(projected.values, {'hours': 7, 'deepHours': 2, 'lightHours': 5});
      expect(projected.samples, isEmpty);
      expect(projected.quality, 'unknown');
      expect(original.samples, [1, 2, 3]);
      expect(original.values['sleepScore'], 90);
      expect(original.quality, 'poor');
      expect(projected.id, original.id);
      expect(projected.measuredAt, original.measuredAt);
    },
  );

  test(
    'physiological history cannot enable measurements or device settings',
    () async {
      final store = MemoryHealthStore();
      final api = _Api();
      final controller = AppController(
        MemorySessionVault(),
        api,
        store,
        _Wearable(),
      );
      addTearDown(controller.dispose);
      controller.healthRecords = [
        _record('old-heart', HealthMetric.heartRate),
        _record('step', HealthMetric.steps),
      ];
      controller.capabilities = DeviceCapabilities(
        metrics: HealthMetric.values.toSet(),
        features: DeviceFeature.values.toSet(),
        integratedFeatures: DeviceFeature.values.toSet(),
      );
      expect(controller.healthRecords.map((r) => r.metric), [
        HealthMetric.steps,
      ]);
      expect(
        controller.latestByMetric.containsKey(HealthMetric.heartRate),
        isFalse,
      );
      expect(
        controller.shouldShowHealthMetric(HealthMetric.heartRate),
        isFalse,
      );
      expect(controller.canMeasureHealthMetric(HealthMetric.steps), isFalse);
      expect(
        await controller.startMeasurement(HealthMetric.heartRate),
        isFalse,
      );
      expect(
        await controller.sendAiMessage(app: 1, message: 'synthetic'),
        isFalse,
      );
      await controller.refreshAiMessages(app: 1);
      await controller.setAutoMeasureSetting('heartRate', true);
      await controller.setAutoMeasureInterval('heartRate', 30);
      await controller.setHeartRateWarning(120);
      expect(
        controller.availabilityFor(DeviceFeature.healthMonitoring).isReady,
        isFalse,
      );
      expect(
        await controller.globalCareRecords(
          'synthetic',
          'heart_rate',
          DateTime.utc(2026),
        ),
        isEmpty,
      );
      expect(
        await controller.loadHealthRecords(
          metric: HealthMetric.heartRate,
          start: DateTime.utc(2020),
          end: DateTime.utc(2030),
        ),
        isEmpty,
      );
      expect(api.uploaded, isEmpty);
    },
  );

  for (final acknowledge in [true, false]) {
    test(
      'queue filters before limit, retains originals and honors only own ACKs ($acknowledge)',
      () async {
        final store = MemoryHealthStore();
        final api = _Api()..acknowledge = acknowledge;
        final sleep = _record(
          'sleep',
          HealthMetric.sleep,
          values: {'value': 7, 'sleepScore': 90},
        );
        await store.upsert([
          _record('old-heart', HealthMetric.heartRate),
          for (var i = 0; i < 220; i++)
            _record('old-$i', HealthMetric.bloodOxygen),
          sleep,
        ]);
        final outcome = await HealthSyncService(store, api).synchronizeNow();
        expect(outcome.uploaded, acknowledge ? 1 : 0);
        expect(outcome.hasPending, !acknowledge);
        expect(api.uploaded.single.id, 'sleep');
        expect(api.uploaded.single.values, {'value': 7});
        expect(api.prepared.single.values, {'value': 7});
        expect(
          (await store.pending(limit: 400)).length,
          acknowledge ? 221 : 222,
        );
        expect(
          (await store.pending(limit: 400)).any((r) => r.id == 'old-heart'),
          isTrue,
        );
        final original = (await store.recent(
          limit: 400,
        )).firstWhere((r) => r.id == 'sleep');
        expect(original.values, sleep.values);
        expect(original.quality, 'poor');
        if (acknowledge) {
          await HealthSyncService(store, api).synchronizeNow();
          expect(api.uploaded, hasLength(1));
        }
      },
    );
  }

  test('iOS router blocks start and stop before selecting any SDK', () async {
    final bridge = RoutedWearableBridge(
      veepoo: _Wearable(),
      yucheng: _Wearable(),
    );
    for (final metric in HealthMetric.values) {
      await expectLater(
        bridge.startMeasurement(metric),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'IOS_WELLNESS_SCOPE',
          ),
        ),
      );
      await expectLater(
        bridge.stopMeasurement(metric),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'IOS_WELLNESS_SCOPE',
          ),
        ),
      );
    }
  });

  test(
    'direct care permissions contain only iOS activity and sleep metrics',
    () async {
      final vault = MemorySessionVault();
      await vault.writeSession(
        Session(
          accessToken: 'synthetic',
          refreshToken: '',
          expiresAt: DateTime.utc(2099),
          memberId: 'synthetic',
          displayName: 'QA',
        ),
      );
      final sent = <String>[];
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          sent.addAll(
            List<String>.from((jsonDecode(request.body) as Map)['metrics']),
          );
          return http.Response(jsonEncode({'code': 200, 'data': {}}), 200);
        }),
      );
      await api.globalShareCare('synthetic', {
        'heart_rate',
        'sleep',
        'steps',
        'unknown',
      });
      expect(sent, ['sleep', 'steps']);
    },
  );

  test(
    'global transport never sends AI, alerts, reports or ECG requests on iOS',
    () async {
      final vault = MemorySessionVault();
      await vault.writeSession(
        Session(
          accessToken: 'synthetic',
          refreshToken: '',
          expiresAt: DateTime.utc(2099),
          memberId: 'synthetic',
          displayName: 'QA',
        ),
      );
      var calls = 0;
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          calls++;
          return http.Response(jsonEncode({'code': 200, 'data': []}), 200);
        }),
      );
      await expectLater(
        api.sendAiMessage(app: 1, message: 'synthetic'),
        throwsA(isA<FeatureNotConfiguredException>()),
      );
      await expectLater(
        api.getAiMessages(app: 1),
        throwsA(isA<FeatureNotConfiguredException>()),
      );
      await expectLater(
        api.getHealthProfile(),
        throwsA(isA<FeatureNotConfiguredException>()),
      );
      await expectLater(
        api.getHealthWarningAlerts(),
        throwsA(isA<FeatureNotConfiguredException>()),
      );
      expect(calls, 0);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform home retains public education without scope banner',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          const prefix = '/global/api/saydian-app/v2/content';
          const categoryId = 'ec9a343b-254a-432b-9f5c-55f08045b1a1';
          const articleId = 'f097cc8b-0b4e-4780-a68c-c571b094320c';
          final requests = <http.Request>[];
          final vault = MemorySessionVault();
          final api = GlobalSaydianApiClient(
            vault,
            locale: () => 'en',
            client: MockClient((request) async {
              requests.add(request);
              final Object data = switch (request.url.path) {
                '$prefix/categories' => [
                  {'id': categoryId, 'name': 'Synthetic sleep education'},
                ],
                '$prefix/articles' => {
                  'items': [
                    {'id': articleId, 'title': 'Synthetic educational article'},
                  ],
                },
                '$prefix/articles/$articleId' => {
                  'id': articleId,
                  'title': 'Synthetic educational article',
                  'contentHtml': '<p>Synthetic public reading fixture.</p>',
                },
                _ => throw StateError('Unexpected route: ${request.url.path}'),
              };
              return http.Response(
                jsonEncode({'code': 200, 'data': data}),
                200,
              );
            }),
          );
          final controller = AppController(
            vault,
            api,
            MemoryHealthStore(),
            _Wearable(),
          );
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DashboardPage(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('ios-wellness-scope')), findsNothing);
          expect(find.text('Health library'), findsOneWidget);
          expect(
            find.text('Health alerts'),
            platform == TargetPlatform.iOS ? findsNothing : findsOneWidget,
          );
          expect(find.textContaining('Consult a doctor'), findsOneWidget);
          await tester.tap(find.text('Health library'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('global-article-library')),
            findsOneWidget,
          );
          await tester.tap(find.text('Synthetic sleep education'));
          await tester.pumpAndSettle();
          expect(requests.last.url.queryParameters['categoryId'], categoryId);
          await tester.tap(find.text('Synthetic educational article'));
          await tester.pumpAndSettle();
          expect(
            find.text('Synthetic public reading fixture.'),
            findsOneWidget,
          );
          expect(requests.last.url.path, '$prefix/articles/$articleId');
          expect(
            requests.every(
              (request) =>
                  request.method == 'GET' &&
                  request.body.isEmpty &&
                  !request.headers.containsKey('Authorization') &&
                  request.url.queryParameters['locale'] == 'en',
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  for (final route in ['dashboard', 'ai', 'detail', 'calibration']) {
    testWidgets('iOS $route does not expose clinical or AI controls', (
      tester,
    ) async {
      try {
        final controller = AppController(
          MemorySessionVault(),
          _Api(),
          MemoryHealthStore(),
          _Wearable(),
        );
        addTearDown(controller.dispose);
        controller.healthRecords = [_record('heart', HealthMetric.heartRate)];
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: switch (route) {
              'dashboard' => AppShell(controller: controller),
              'ai' => AiChatPage(controller: controller, app: 1),
              'calibration' => HealthCalibrationPage(
                controller: controller,
                metric: HealthMetric.bloodPressure,
              ),
              _ => HealthRecordDetailPage(
                controller: controller,
                record: _record('heart', HealthMetric.heartRate),
              ),
            },
          ),
        );
        await tester.pump();
        if (route == 'dashboard') {
          expect(find.byKey(const Key('dashboard-ai-assistant')), findsNothing);
          expect(find.text('Heart rate'), findsNothing);
        } else {
          expect(
            find.textContaining('supports activity and sleep only'),
            findsOneWidget,
          );
        }
        expect(find.byType(TextField), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
