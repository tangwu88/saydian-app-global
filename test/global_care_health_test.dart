import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/global_care.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

Session _session(String owner) => Session(
  accessToken: 'synthetic-$owner',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: owner,
  displayName: 'QA',
  accountKey: 'global:member:$owner',
);
http.Response _ok(Object data) =>
    http.Response(jsonEncode({'code': 200, 'data': data}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final days in [1, 7, 31]) {
    test(
      'shared $days-day range uses exact UTC bounds and global member route',
      () async {
        final start = DateTime(2026, 10, 1), end = DateTime(2026, 10, 1 + days);
        final api = GlobalSaydianApiClient(
          MemorySessionVault()..session = _session('a'),
          client: MockClient((r) async {
            expect(
              r.url.path,
              '/global/api/saydian-app/v2/care/relationships/relation/health',
            );
            expect(r.url.queryParameters, {
              'metric': 'blood_pressure',
              'from': start.toUtc().toIso8601String(),
              'to': end.toUtc().toIso8601String(),
            });
            expect(r.headers['authorization'], 'Bearer synthetic-a');
            return _ok([]);
          }),
        );
        expect(
          await api.globalCareRecordsRange(
            'relation',
            'blood_pressure',
            start,
            end,
          ),
          isEmpty,
        );
      },
    );
  }
  test(
    'summary preserves permission allowlist and actual latest records',
    () async {
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session('a'),
        client: MockClient((r) async {
          expect(
            r.url.path,
            '/global/api/saydian-app/v2/care/relationships/relation/summary',
          );
          return _ok({
            'metrics': ['heart_rate'],
            'records': [
              {
                'id': 'record',
                'metric': 'heart_rate',
                'values': {'heartRate': 73},
                'observedAt': '2026-10-03T12:00:00.000Z',
              },
            ],
          });
        }),
      );
      final result = await api.globalCareSummary('relation');
      expect(result['metrics'], ['heart_rate']);
      expect((result['records'] as List).single['id'], 'record');
    },
  );
  for (final summary in [true, false]) {
    test(
      'shared ${summary ? 'summary' : 'range'} discards response after account switch',
      () async {
        final vault = MemorySessionVault()..session = _session('a');
        final started = Completer<void>(),
            response = Completer<http.Response>();
        final api = GlobalSaydianApiClient(
          vault,
          client: MockClient((r) async {
            started.complete();
            return response.future;
          }),
        );
        final read = summary
            ? api.globalCareSummary('relation')
            : api.globalCareRecordsRange(
                'relation',
                'heart_rate',
                DateTime(2026),
                DateTime(2027),
              );
        await started.future;
        vault.session = _session('b');
        final rejected = expectLater(
          read,
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'owner guard',
              'SESSION_CHANGED',
            ),
          ),
        );
        response.complete(_ok(summary ? {'metrics': [], 'records': []} : []));
        await rejected;
      },
    );
  }
  test(
    'shared ECG mapping retains timing, rate and remote provenance without local receipts',
    () {
      final record = globalCareHealthRecord({
        'id': 'record',
        'metric': 'ecg',
        'observedAt': '2026-10-03T12:00:00Z',
        'timezoneOffsetMinutes': 480,
        'values': {'meanHeartRate': 73},
        'unit': 'mV',
        'ecgArtifact': {
          'sampleRateHz': 250,
          'sampleCount': 3000,
          'sha256': 'synthetic',
        },
      });
      expect(record.origin, MeasurementOrigin.remoteMember);
      expect(record.timezone, '+08:00');
      expect(record.values['sampleFrequency'], 250);
      expect(record.values['meanHeartRate'], 73);
      expect(record.samples, isEmpty);
      expect(record.ecgArtifact, isNull);
    },
  );
}
