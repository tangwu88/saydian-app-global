import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Session _session(String owner) => Session(
  accessToken: 'synthetic-$owner',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: owner,
  displayName: 'QA',
  accountKey: 'global:member:$owner',
);
HealthRecord _record({Map<String, num>? values}) => HealthRecord(
  id: 'synthetic-ecg',
  metric: HealthMetric.ecg,
  values: values ?? const {'meanHeartRate': 75, 'sampleFrequency': 250},
  unit: 'mV',
  measuredAt: DateTime.utc(2026, 10, 3),
  timezone: '+08:00',
  deviceId: 'synthetic-watch',
  firmwareVersion: 'qa',
  quality: 'unknown',
  source: MeasurementSource.wearable,
  rawVersion: 2,
  samples: List<num>.generate(3000, (i) => .6 * math.sin(i * .1)),
);
http.Response _ok(Object data) =>
    http.Response(jsonEncode({'code': 200, 'data': data}), 200);

Map<String, Object?> _receipt(http.Request request, HealthRecord original) {
  expect(
    request.url.toString(),
    'https://app.saydian.cn/global/api/saydian-app/v2/files/ecg',
  );
  expect(request.headers['authorization'], 'Bearer synthetic-a');
  final boundary = request.headers['content-type']!.split('boundary=').last;
  final body = latin1.decode(request.bodyBytes);
  final fileHeader = body.toLowerCase().indexOf(
    'content-type: application/gzip\r\n',
  );
  expect(fileHeader, greaterThanOrEqualTo(0));
  final start = body.indexOf('\r\n\r\n', fileHeader) + 4;
  final bytes = latin1.encode(
    body.substring(start, body.indexOf('\r\n--$boundary', start)),
  );
  expect(jsonDecode(utf8.decode(gzip.decode(bytes))), original.samples);
  final hash = sha256.convert(bytes).toString();
  expect(body, contains(hash));
  return {
    'uploadObjectKey': 'ecg/a/qa/file.bin.gz',
    'sha256': hash,
    'byteSize': bytes.length,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'receipt persistence failure prevents submitting the health record',
    () async {
      final record = _record();
      final store = _FailingReceiptStore();
      await store.upsert([record]);
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session('a'),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/capabilities')) {
            return _ok({'dailySummaryVersions': false});
          }
          expect(request.url.path.endsWith('/files/ecg'), isTrue);
          return _ok(_receipt(request, record));
        }),
      );
      await expectLater(
        HealthSyncService(store, api).synchronizeNow(),
        throwsStateError,
      );
      expect((await store.pending()).single.samples, record.samples);
      expect((await store.pending()).single.ecgArtifact, isNull);
    },
  );

  test(
    'complete waveform is lossless; durable receipt makes ACK-loss retry stable',
    () async {
      final original = _record();
      final store = MemoryHealthStore();
      await store.upsert([original]);
      var files = 0;
      var batches = 0;
      String? firstBody;
      String? firstKey;
      final vault = MemorySessionVault()..session = _session('a');
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/capabilities')) {
          return _ok({'dailySummaryVersions': false});
        }
        if (request.url.path.endsWith('/files/ecg')) {
          files++;
          return _ok(_receipt(request, original));
        }
        final pending = (await store.pending()).single;
        expect(pending.ecgArtifact, isNotNull);
        final row =
            ((jsonDecode(request.body) as Map)['records'] as List).single
                as Map;
        expect(row.containsKey('samples'), isFalse);
        expect(row['ecgArtifact'], pending.ecgArtifact!.toJson());
        expect(row['ecgArtifact']['sampleCount'], original.samples.length);
        expect(row['ecgArtifact']['sampleRateHz'], 250);
        batches++;
        if (batches == 1) {
          firstBody = request.body;
          firstKey = request.headers['idempotency-key'];
          throw http.ClientException('synthetic lost ACK');
        }
        expect(request.body, firstBody);
        expect(request.headers['idempotency-key'], firstKey);
        return _ok({
          'acceptedIds': [original.id],
          'rejected': [],
          'nextCursor': null,
        });
      });
      await expectLater(
        HealthSyncService(
          store,
          GlobalSaydianApiClient(vault, client: client),
        ).synchronizeNow(),
        throwsA(isA<ApiException>()),
      );
      final restored = HealthRecord.fromJson(
        jsonDecode((await store.pending()).single.encode())
            as Map<String, Object?>,
      );
      expect(restored.samples, original.samples);
      expect(restored.ecgArtifact, isNotNull);
      final restartedStore = MemoryHealthStore();
      await restartedStore.upsert([restored]);
      final outcome = await HealthSyncService(
        restartedStore,
        GlobalSaydianApiClient(vault, client: client),
      ).synchronizeNow();
      expect(outcome.uploaded, 1);
      expect(files, 1);
      expect(batches, 2);
      expect(await restartedStore.pending(), isEmpty);
    },
  );

  for (final failure in ['hash', 'size', 'server', 'account']) {
    test(
      'file $failure failure preserves complete pending record without a batch',
      () async {
        final record = _record();
        final store = MemoryHealthStore();
        await store.upsert([record]);
        final vault = MemorySessionVault()..session = _session('a');
        final api = GlobalSaydianApiClient(
          vault,
          client: MockClient((request) async {
            if (request.url.path.endsWith('/capabilities')) {
              return _ok({'dailySummaryVersions': false});
            }
            expect(request.url.path.endsWith('/files/ecg'), isTrue);
            final receipt = _receipt(request, record);
            if (failure == 'hash') receipt['sha256'] = 'wrong';
            if (failure == 'size') receipt['byteSize'] = 0;
            if (failure == 'account') vault.session = _session('b');
            if (failure == 'server') {
              return http.Response('{"message":"synthetic failure"}', 503);
            }
            return _ok(receipt);
          }),
        );
        if (failure == 'account') {
          await expectLater(
            HealthSyncService(store, api).synchronizeNow(),
            throwsA(isA<ApiException>()),
          );
        } else {
          expect(
            (await HealthSyncService(store, api).synchronizeNow()).hasPending,
            isTrue,
          );
        }
        expect((await store.pending()).single.samples, record.samples);
        expect((await store.pending()).single.ecgArtifact, isNull);
      },
    );
  }

  test(
    'missing manufacturer sample rate never invents a rate or uploads',
    () async {
      final record = _record(values: const {'meanHeartRate': 75});
      var requests = 0;
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session('a'),
        client: MockClient((_) async {
          requests++;
          throw StateError('must not send');
        }),
      );
      expect(await api.prepareHealthRecord(record), same(record));
      final result = await api.uploadHealthBatch(
        SyncBatch(cursor: null, records: [record]),
      );
      expect(result.acceptedIds, isEmpty);
      expect(result.rejected.keys, [record.id]);
      expect(requests, 0);
    },
  );

  test(
    'unconfirmed record ACK keeps the confirmed file receipt pending',
    () async {
      final record = _record();
      final store = MemoryHealthStore();
      await store.upsert([record]);
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session('a'),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/capabilities')) {
            return _ok({'dailySummaryVersions': false});
          }
          if (request.url.path.endsWith('/files/ecg')) {
            return _ok(_receipt(request, record));
          }
          return _ok({'acceptedIds': [], 'rejected': [], 'nextCursor': null});
        }),
      );
      expect(
        (await HealthSyncService(store, api).synchronizeNow()).hasPending,
        isTrue,
      );
      expect((await store.pending()).single.ecgArtifact, isNotNull);
    },
  );

  test(
    'unavailable waveform storage does not block ordinary record uploads',
    () async {
      final record = _record();
      final store = MemoryHealthStore();
      final ordinary = HealthRecord.fromJson({
        ...record.toJson(),
        'id': 'ordinary',
        'type': 'heart_rate',
        'values': {'value': 75},
        'samples': [],
      });
      await store.upsert([record, ordinary]);
      var fileAttempts = 0;
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session('a'),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/capabilities')) {
            return _ok({'dailySummaryVersions': false});
          }
          if (request.url.path.endsWith('/files/ecg')) {
            fileAttempts++;
            return http.Response('{}', 503);
          }
          final rows = (jsonDecode(request.body) as Map)['records'] as List;
          expect(rows.map((row) => row['id']), ['ordinary']);
          return _ok({
            'acceptedIds': ['ordinary'],
            'rejected': [],
            'nextCursor': null,
          });
        }),
      );
      final outcome = await HealthSyncService(store, api).synchronizeNow();
      expect(outcome.uploaded, 1);
      expect(outcome.hasPending, isTrue);
      expect(outcome.message, contains('file storage'));
      expect(fileAttempts, 1);
      expect((await store.pending()).single.id, record.id);
    },
  );

  test(
    'SQLite receipt survives reopen and stays isolated by owner and ACK',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('ecg-receipt-');
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
      var store = open();
      await store.initialize();
      await store.switchOwner('a');
      final record = _record().copyWith(
        ecgArtifact: const HealthEcgArtifact(
          sampleRateHz: 250,
          sampleCount: 3000,
          sha256: 'synthetic-hash',
          uploadObjectKey: 'ecg/a/file',
        ),
      );
      await store.upsert([_record()]);
      await store.savePreparedRecord(record);
      await store.close();
      store = open();
      await store.initialize();
      await store.switchOwner('a');
      expect(
        (await store.pending()).single.ecgArtifact!.toJson(),
        record.ecgArtifact!.toJson(),
      );
      expect((await store.pending()).single.samples, record.samples);
      await store.switchOwner('b');
      expect(await store.pending(), isEmpty);
      await expectLater(store.savePreparedRecord(record), throwsStateError);
      await store.switchOwner('a');
      await store.markSynced([record.id]);
      await expectLater(store.savePreparedRecord(record), throwsStateError);
      await store.close();
    },
  );
}

class _FailingReceiptStore extends MemoryHealthStore {
  @override
  Future<void> savePreparedRecord(HealthRecord record) async {
    throw StateError('synthetic persistence failure');
  }
}
