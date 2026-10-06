import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/ios_wellness_policy.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_notification_service.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bootstrap.dart';

import 'ios_store_empty_state_test.dart' as empty_state;

/// Uses only the existing phone session and production bridge. No credentials,
/// sensor values, record IDs or health screenshots are emitted to the log.
class _ReceiptApi extends GlobalSaydianApiClient {
  _ReceiptApi(super.vault) : super(client: _ReceiptHttpClient());
  final accepted = <String>{};
  int rejected = 0;

  @override
  Future<bool> supportsDailySummaries() async {
    final supported = await super.supportsDailySummaries();
    debugPrint('IOS_WELLNESS_QA_CAPABILITY: dailySummaryVersions=$supported');
    return supported;
  }

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    expect(
      batch.records.every((r) => IosWellnessPolicy.metrics.contains(r.metric)),
      isTrue,
    );
    try {
      final result = await super.uploadHealthBatch(batch);
      accepted.addAll(result.acceptedIds);
      rejected += result.rejected.length;
      debugPrint(
        'IOS_WELLNESS_QA_UPLOAD: submitted=${batch.records.length} accepted=${result.acceptedIds.length} rejected=${result.rejected.length}',
      );
      return result;
    } on ApiException catch (error) {
      final code = '${error.code ?? 'none'}';
      final safeCode = RegExp(r'^[A-Za-z0-9_]{1,80}$').hasMatch(code)
          ? code
          : 'redacted';
      debugPrint(
        'IOS_WELLNESS_QA_UPLOAD_ERROR: status=${error.statusCode ?? 0} code=$safeCode',
      );
      rethrow;
    }
  }
}

class _ReceiptHttpClient extends http.BaseClient {
  final _inner = http.Client();
  static const _safeCodes = {
    'invalid_id',
    'unsupported_metric',
    'invalid_time',
    'future_time',
    'invalid_timezone',
    'empty_values',
    'invalid_values',
    'invalid_source',
    'invalid_quality',
    'invalid_aggregation',
    'invalid_ecg_artifact',
    'record_conflict',
    'invalid_artifact',
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (request.url.path.endsWith('/health/capabilities')) {
      debugPrint(
        'IOS_WELLNESS_QA_CAPABILITY_HTTP: status=${response.statusCode}',
      );
    }
    if (!request.url.path.endsWith('/health/records/batch')) return response;
    final bytes = await response.stream.toBytes();
    final envelope = jsonDecode(utf8.decode(bytes));
    final data = envelope is Map ? envelope['data'] : null;
    final rejected = data is Map ? data['rejected'] : null;
    final counts = <String, int>{};
    if (rejected is List) {
      for (final row in rejected) {
        final code = row is Map ? row['code'] : null;
        final bucket = _safeCodes.contains(code)
            ? code as String
            : 'other_rejected';
        counts.update(bucket, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    debugPrint(
      'IOS_WELLNESS_QA_RECEIPT: status=${response.statusCode} reasons=$counts',
    );
    // Aggregate time diagnostics only: never log record timestamps or IDs.
    final dateHeader = response.headers['date'];
    if (counts.containsKey('future_time') &&
        dateHeader != null &&
        request is http.Request) {
      final serverNow = HttpDate.parse(dateHeader).toUtc();
      final phoneNow = DateTime.now().toUtc();
      final payload = jsonDecode(request.body) as Map;
      final futureIds = (rejected as List)
          .whereType<Map>()
          .where((row) => row['code'] == 'future_time')
          .map((row) => row['id'])
          .toSet();
      final buckets = <String, int>{};
      var futureToPhone = 0;
      var daily = 0;
      var legacyNoonMarkers = 0;
      for (final row in (payload['records'] as List).whereType<Map>()) {
        if (!futureIds.contains(row['id'])) continue;
        final observed = DateTime.parse(row['observedAt'] as String).toUtc();
        final lead = observed.difference(serverNow);
        final bucket = lead < const Duration(hours: 1)
            ? 'under_1h'
            : lead < const Duration(hours: 24)
            ? 'under_24h'
            : lead < const Duration(days: 7)
            ? 'under_7d'
            : 'over_7d';
        buckets.update(bucket, (value) => value + 1, ifAbsent: () => 1);
        if (observed.isAfter(phoneNow.add(const Duration(minutes: 10)))) {
          futureToPhone++;
        }
        if (row['aggregation'] != null) daily++;
        final offset = row['timezoneOffsetMinutes'];
        if (offset is int) {
          final local = observed.add(Duration(minutes: offset));
          if (row['aggregation'] == null &&
              {'steps', 'distance', 'calories'}.contains(row['metric']) &&
              local.hour == 12 &&
              local.minute == 0 &&
              local.second == 0) {
            legacyNoonMarkers++;
          }
        }
      }
      debugPrint(
        'IOS_WELLNESS_QA_TIME: phoneServerSkewMinutes=${phoneNow.difference(serverNow).inMinutes} futureLead=$buckets futureToPhone=$futureToPhone daily=$daily legacyNoonMarkers=$legacyNoonMarkers',
      );
    }
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: response.request,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
    );
  }

  @override
  void close() => _inner.close();
}

Future<void> _wait(bool Function() ready) async {
  final end = DateTime.now().add(const Duration(seconds: 120));
  while (!ready() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  expect(
    ready(),
    isTrue,
    reason: 'Real device/sync state did not become ready',
  );
}

String _fingerprint(List<HealthRecord> records) {
  final rows = records.map((r) => jsonEncode(r.toJson())).toList()..sort();
  return sha256.convert(utf8.encode(jsonEncode(rows))).toString();
}

Future<Set<String>> _cloudIds(SecureSessionVault vault, String owner) async {
  final client = http.Client();
  final ids = <String>{};
  try {
    for (final metric in IosWellnessPolicy.metrics) {
      String? cursor;
      final cursors = <String>{};
      var complete = false;
      for (var page = 0; page < 50; page++) {
        final session = await vault.readSession();
        expect(session?.accountKey == owner, isTrue, reason: 'Session changed');
        final uri =
            Uri.parse(
              'https://app.saydian.cn/global/api/saydian-app/v2/health/records',
            ).replace(
              queryParameters: {
                'metric': metric.wireName,
                'limit': '200',
                'before': ?cursor,
              },
            );
        final response = await client
            .get(
              uri,
              headers: {'Authorization': 'Bearer ${session!.accessToken}'},
            )
            .timeout(const Duration(seconds: 25));
        expect(
          response.statusCode,
          200,
          reason: 'Authenticated activity/sleep readback failed',
        );
        final data = (jsonDecode(response.body) as Map)['data'] as Map;
        for (final row in (data['items'] as List).cast<Map>()) {
          expect(
            row['metric'] == metric.wireName,
            isTrue,
            reason: 'Server ignored metric filter',
          );
          expect(
            ids.add(row['id'] as String),
            isTrue,
            reason: 'Duplicate server record ID',
          );
        }
        cursor = data['nextCursor'] as String?;
        if (cursor == null) {
          complete = true;
          break;
        }
        expect(cursors.add(cursor), isTrue, reason: 'Repeated server cursor');
      }
      expect(complete, isTrue, reason: 'Bounded readback incomplete');
    }
    return ids;
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iOS activity/sleep real watch, ACK, retry and preserved history', (
    tester,
  ) async {
    final vault = SecureSessionVault.global();
    final store = EncryptedHealthStore(vault, globalEdition: true);
    final api = _ReceiptApi(vault);
    final bridge = createProductionWearableBridge();
    final controller = AppController(
      vault,
      api,
      store,
      bridge,
      notificationService: JPushAppNotificationService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    debugPrint('IOS_WELLNESS_QA_PHASE: initialized');
    expect(controller.isIosWellnessEdition, isTrue);
    expect(
      controller.isAuthenticated,
      isTrue,
      reason: 'Existing phone sign-in required',
    );
    expect(await vault.readPrivacyConsentGranted(), isTrue);
    final owner = (await vault.readSession())!.accountKey;
    expect(
      await api.supportsDailySummaries(),
      isTrue,
      reason:
          'Authenticated capabilities with production token refresh required',
    );
    final oldRows = (await store.recent(
      limit: 10000,
    )).where((r) => !IosWellnessPolicy.metrics.contains(r.metric)).toList();
    final oldPending = (await store.pending(
      limit: 10000,
    )).where((r) => !IosWellnessPolicy.metrics.contains(r.metric)).toList();
    final original = _fingerprint(oldRows);
    final originalPending = _fingerprint(oldPending);
    // Diagnose the durable queue independently of Bluetooth restoration. A
    // missing nearby watch must not conceal an existing server rejection.
    debugPrint('IOS_WELLNESS_QA_PHASE: existing-queue-upload');
    await controller.synchronizeCloud();
    await tester.pumpWidget(SaydianApp(controller: controller));
    await tester.pump(const Duration(seconds: 2));
    await controller.restoreWearableConnection().timeout(
      const Duration(seconds: 90),
    );
    debugPrint('IOS_WELLNESS_QA_PHASE: connection-restored');
    await _wait(
      () => controller.connectedDevice != null && !controller.isDeviceSyncing,
    );
    expect(controller.capabilities!.metrics.isNotEmpty, isTrue);
    expect(
      controller.capabilities!.metrics.every(
        IosWellnessPolicy.metrics.contains,
      ),
      isTrue,
    );
    expect(controller.capabilities!.manualMetrics, isEmpty);
    expect(await controller.startMeasurement(HealthMetric.heartRate), isFalse);
    expect(
      await controller.sendAiMessage(app: 1, message: 'Not transmitted'),
      isFalse,
    );
    for (var retry = 0; retry < 2; retry++) {
      debugPrint('IOS_WELLNESS_QA_PHASE: sync-${retry + 1}');
      expect(await controller.syncDeviceData(), isTrue);
      await _wait(
        () => controller.cloudSyncState != CloudHealthSyncState.uploading,
      );
      await controller.synchronizeCloud();
      final pending = await store.pending(
        limit: 10000,
        allowedMetrics: IosWellnessPolicy.metrics,
      );
      debugPrint(
        'IOS_WELLNESS_QA_STATE: state=${controller.cloudSyncState.name} allowedPending=${pending.length} accepted=${api.accepted.length} rejected=${api.rejected}',
      );
      expect(controller.cloudSyncState, CloudHealthSyncState.complete);
      expect(
        await store.pending(
          limit: 1,
          allowedMetrics: IosWellnessPolicy.metrics,
        ),
        isEmpty,
      );
      expect(
        controller.healthRecords,
        isNotEmpty,
        reason: 'Actual activity/sleep samples required',
      );
      final cloud = await _cloudIds(vault, owner);
      expect(cloud.containsAll(api.accepted), isTrue);
      expect(
        cloud.containsAll(controller.healthRecords.map((r) => r.id)),
        isTrue,
        reason: 'Local allowed records missing on server',
      );
      expect(api.rejected, 0);
      expect(
        _fingerprint(
          (await store.recent(limit: 10000))
              .where((r) => !IosWellnessPolicy.metrics.contains(r.metric))
              .toList(),
        ),
        original,
      );
      expect(
        _fingerprint(
          (await store.pending(limit: 10000))
              .where((r) => !IosWellnessPolicy.metrics.contains(r.metric))
              .toList(),
        ),
        originalPending,
      );
      debugPrint(
        'IOS_WELLNESS_QA: retry=${retry + 1} accepted=${api.accepted.length} serverAllowed=${cloud.length} allowedPending=0 preservedHistory=true',
      );
    }
    expect(tester.takeException(), isNull);
  });
  empty_state.main();
}
