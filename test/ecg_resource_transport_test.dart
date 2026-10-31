import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  Session session() => Session(
    accessToken: 'synthetic',
    refreshToken: '',
    expiresAt: DateTime.utc(2099),
    memberId: 'synthetic-a',
    displayName: 'Synthetic',
    accountKey: 'global:member:synthetic-a',
  );
  HealthRecord record() => HealthRecord(
    id: 'synthetic-ecg',
    metric: HealthMetric.ecg,
    values: const {'sampleFrequency': 250},
    unit: 'mV',
    measuredAt: DateTime.utc(2026, 10, 1),
    timezone: '+00:00',
    deviceId: 'synthetic',
    firmwareVersion: 'test',
    quality: 'unknown',
    source: MeasurementSource.wearable,
    rawVersion: 2,
  );

  test(
    'AUD-06 declared oversize is cancelled before reading response body',
    () async {
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = session(),
        client: MockClient.streaming((request, _) async {
          expect(request, isA<http.AbortableRequest>());
          expect(request.followRedirects, isFalse);
          return http.StreamedResponse(
            body.stream,
            200,
            contentLength: 25 * 1024 * 1024 + 1,
          );
        }),
      );
      await expectLater(
        api.loadEcgWaveform(record()),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'INVALID_ECG_ACK'),
        ),
      );
      expect(cancelled, isTrue);
      await body.close();
    },
  );

  test(
    'AUD-06 corrupt gzip becomes a safe API error despite matching hash',
    () async {
      final bytes = utf8.encode('synthetic-invalid-gzip');
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = session(),
        client: MockClient(
          (_) async => http.Response.bytes(
            bytes,
            200,
            headers: {
              'x-content-sha256': sha256.convert(bytes).toString(),
              'x-ecg-sample-rate': '250',
              'x-ecg-sample-count': '1',
            },
          ),
        ),
      );
      await expectLater(
        api.loadEcgWaveform(record()),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'INVALID_ECG_ACK'),
        ),
      );
    },
  );

  test('AUD-06 error bodies have a separate small cap', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    final api = GlobalSaydianApiClient(
      MemorySessionVault()..session = session(),
      client: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          body.stream,
          500,
          contentLength: 256 * 1024 + 1,
        ),
      ),
    );
    await expectLater(
      api.loadEcgWaveform(record()),
      throwsA(isA<ApiException>()),
    );
    expect(cancelled, isTrue);
    await body.close();
  });
}
