part of 'api_client.dart';

/// Canonical global health transport. Legacy minute/day aggregation must never
/// decide which individual global records can be removed from the pending queue.
mixin GlobalHealthApi on SaydianApiClient
    implements DailySummarySupportApi, HealthRecordPreparationApi {
  static const _healthRoot = '/api/saydian-app/v2/health';

  String? _globalRecordReason(HealthRecord record) {
    final quality = switch (record.quality) {
      'device_reported' || 'sdk' => 'unknown',
      final value => value,
    };
    if (record.origin == MeasurementOrigin.remoteMember) {
      return 'Shared records cannot be uploaded to your own health history.';
    }
    if (kIsWeb ||
        !const {
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform) ||
        _globalTimezoneOffset(record.timezone) == null ||
        record.id.isEmpty ||
        record.id.length > 160 ||
        record.values.isEmpty ||
        record.values.values.any((value) => !value.isFinite) ||
        !const {'unknown', 'valid', 'suspect', 'invalid'}.contains(quality)) {
      return 'This record needs complete source, time and quality information before syncing.';
    }
    return null;
  }

  ({int rate, List<int> bytes, String hash})? _globalEcgPayload(
    HealthRecord record,
  ) {
    final rate = record.values['sampleFrequency'];
    if (record.metric != HealthMetric.ecg ||
        record.rawVersion < 2 ||
        record.samples.isEmpty ||
        record.samples.length > 1000000 ||
        record.samples.any((value) => !value.isFinite) ||
        rate == null ||
        !rate.isFinite ||
        rate != rate.toInt() ||
        rate < 50 ||
        rate > 1000) {
      return null;
    }
    // Preserve every calibrated native sample, with no resampling or rounding.
    final bytes = gzip.encode(utf8.encode(jsonEncode(record.samples)));
    if (bytes.length > 25 * 1024 * 1024) return null;
    return (
      rate: rate.toInt(),
      bytes: bytes,
      hash: sha256.convert(bytes).toString(),
    );
  }

  bool _matchesEcgArtifact(
    HealthRecord record,
    ({int rate, List<int> bytes, String hash}) payload,
  ) {
    final artifact = record.ecgArtifact;
    return artifact != null &&
        artifact.sampleRateHz == payload.rate &&
        artifact.sampleCount == record.samples.length &&
        artifact.sha256 == payload.hash &&
        artifact.uploadObjectKey.startsWith('ecg/') &&
        !artifact.uploadObjectKey.contains('..');
  }

  @override
  Future<HealthRecord> prepareHealthRecord(HealthRecord record) async {
    if (record.samples.isEmpty || _globalRecordReason(record) != null) {
      return record;
    }
    final payload = _globalEcgPayload(record);
    if (payload == null || _matchesEcgArtifact(record, payload)) return record;
    final owner = _stableSessionAccountKey(await _requiredSession());
    final response = await _withAuthorizationRetry((session) async {
      if (_stableSessionAccountKey(session) != owner) {
        throw const ApiException(
          'Your account has changed. Please try again.',
          code: 'STALE_HEALTH_SESSION',
        );
      }
      final request =
          http.MultipartRequest('POST', _uri('/api/saydian-app/v2/files/ecg'))
            ..headers['Authorization'] = 'Bearer ${session.accessToken}'
            ..fields['sha256'] = payload.hash
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                payload.bytes,
                filename: 'ecg-samples.json.gz',
                contentType: http_parser.MediaType('application', 'gzip'),
              ),
            );
      return _sendMultipart(request);
    });
    final current = await _vault.readSession();
    if (current == null || _stableSessionAccountKey(current) != owner) {
      throw const ApiException(
        'Your account has changed. Please try again.',
        code: 'STALE_HEALTH_SESSION',
      );
    }
    if (response.statusCode == 503) {
      throw const ApiException(
        'Waveform file storage is temporarily unavailable. Your complete record remains saved on this device.',
        statusCode: 503,
        code: 'ECG_STORAGE_UNAVAILABLE',
      );
    }
    final data = _data(_decode(response));
    final key = data['uploadObjectKey'];
    if (data['sha256'] != payload.hash ||
        data['byteSize'] != payload.bytes.length ||
        key is! String ||
        !key.startsWith('ecg/') ||
        key.contains('..')) {
      throw const ApiException(
        'The waveform upload could not be confirmed. Your record remains on this device.',
        code: 'INVALID_ECG_ACK',
      );
    }
    return record.copyWith(
      ecgArtifact: HealthEcgArtifact(
        sampleRateHz: payload.rate,
        sampleCount: record.samples.length,
        sha256: payload.hash,
        uploadObjectKey: key,
      ),
    );
  }

  @override
  Future<bool> supportsDailySummaries() async {
    try {
      final owner = _stableSessionAccountKey(await _requiredSession());
      final response = await _globalHealthRequest(
        owner,
        'GET',
        '$_healthRoot/capabilities',
      );
      final data = _data(_decode(response));
      return data['dailySummaryVersions'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _globalHealthRequest(
    String owner,
    String method,
    String path, {
    Map<String, Object?>? body,
    String? idempotencyKey,
    Map<String, String>? query,
  }) async {
    final response = await _withAuthorizationRetry((session) async {
      if (_stableSessionAccountKey(session) != owner) {
        throw const ApiException(
          'Your account has changed. Please try again.',
          code: 'STALE_HEALTH_SESSION',
        );
      }
      final headers = <String, String>{
        'Authorization': 'Bearer ${session.accessToken}',
        if (body != null) 'Content-Type': 'application/json',
        'Idempotency-Key': ?idempotencyKey,
      };
      return _performRequest(
        () => method == 'GET'
            ? _client.get(_uri(path, query), headers: headers)
            : _client.post(
                _uri(path),
                headers: headers,
                body: jsonEncode(body),
              ),
      );
    });
    final current = await _vault.readSession();
    if (current == null || _stableSessionAccountKey(current) != owner) {
      throw const ApiException(
        'Your account has changed. Please try again.',
        code: 'STALE_HEALTH_SESSION',
      );
    }
    return response;
  }

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    if (batch.records.isEmpty) {
      return BatchUploadResult(
        acceptedIds: const {},
        rejected: const {},
        nextCursor: batch.cursor,
      );
    }
    if (batch.records.length > 200 ||
        batch.records.map((r) => r.id).toSet().length != batch.records.length) {
      throw const ApiException(
        'Unable to sync this batch. Please try again.',
        code: 'INVALID_HEALTH_BATCH',
      );
    }
    final owner = _stableSessionAccountKey(await _requiredSession());
    final rejected = <String, String>{};
    final records = <Map<String, Object?>>[];
    final platform = !kIsWeb
        ? switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            _ => null,
          }
        : null;
    for (final record in batch.records) {
      final offset = _globalTimezoneOffset(record.timezone);
      // These native labels describe provenance, not a validated health score.
      // Keep the original local record; never promote them to V2 `valid`.
      final quality = switch (record.quality) {
        'device_reported' || 'sdk' => 'unknown',
        final value => value,
      };
      String? reason = _globalRecordReason(record);
      if (reason == null && record.samples.isNotEmpty) {
        final payload = _globalEcgPayload(record);
        if (payload == null || !_matchesEcgArtifact(record, payload)) {
          reason =
              'This waveform needs its original sample rate and a confirmed upload before syncing.';
        }
      }
      if (reason != null) {
        rejected[record.id] = reason;
        continue;
      }
      records.add({
        'id': record.id,
        'metric': record.metric == HealthMetric.bodyTemperature
            ? 'temperature'
            : record.metric.wireName,
        'observedAt': record.measuredAt.toUtc().toIso8601String(),
        'timezoneOffsetMinutes': offset,
        'values': record.values,
        if (record.unit.isNotEmpty) 'unit': record.unit,
        'quality': quality,
        if (record.aggregation != null)
          'aggregation': record.aggregation!.toJson(),
        if (record.samples.isNotEmpty)
          'ecgArtifact': record.ecgArtifact!.toJson(),
        'source': {
          'platform': platform,
          if (record.deviceId.isNotEmpty) 'deviceId': record.deviceId,
          if (record.sourceModel.trim().isNotEmpty)
            'model': record.sourceModel.trim(),
          if (record.firmwareVersion.isNotEmpty)
            'firmware': record.firmwareVersion,
          'origin': record.origin.wireName,
          'measurementSource': record.source.name,
          'rawVersion': record.rawVersion,
        },
      });
    }
    if (records.isEmpty) {
      return BatchUploadResult(
        acceptedIds: const {},
        rejected: rejected,
        nextCursor: batch.cursor,
      );
    }
    final body = <String, Object?>{'cursor': batch.cursor, 'records': records};
    final requestIds = records.map((row) => row['id'] as String).toSet();
    final key =
        'global-health-${sha256.convert(utf8.encode(jsonEncode(body)))}';
    final data = _data(
      _decode(
        await _globalHealthRequest(
          owner,
          'POST',
          '$_healthRoot/records/batch',
          body: body,
          idempotencyKey: key,
        ),
      ),
    );
    final accepted = data['acceptedIds'];
    final failures = data['rejected'];
    final cursor = data['nextCursor'];
    if (accepted is! List ||
        failures is! List ||
        (cursor != null && cursor is! String)) {
      throw const ApiException(
        'The sync result could not be confirmed. Your records remain on this device.',
        code: 'INVALID_HEALTH_ACK',
      );
    }
    final acceptedIds = <String>{};
    final serverRejectedIds = <String>{};
    for (final id in accepted) {
      if (id is! String || !requestIds.contains(id) || !acceptedIds.add(id)) {
        throw const ApiException(
          'The sync result could not be confirmed.',
          code: 'INVALID_HEALTH_ACK',
        );
      }
    }
    for (final failure in failures) {
      if (failure is! Map ||
          failure['id'] is! String ||
          !requestIds.contains(failure['id']) ||
          acceptedIds.contains(failure['id']) ||
          !serverRejectedIds.add(failure['id'] as String)) {
        throw const ApiException(
          'The sync result could not be confirmed.',
          code: 'INVALID_HEALTH_ACK',
        );
      }
      rejected[failure['id'] as String] =
          'This record was not accepted. It remains saved on this device.';
    }
    for (final id
        in requestIds.difference(acceptedIds).difference(serverRejectedIds)) {
      rejected[id] = 'This record has not been confirmed as synced.';
    }
    return BatchUploadResult(
      acceptedIds: acceptedIds,
      rejected: rejected,
      nextCursor: cursor as String?,
    );
  }

  int? _globalTimezoneOffset(String timezone) {
    final value = timezone.trim();
    if (const {'Z', 'UTC', '+00:00', '-00:00'}.contains(value)) return 0;
    final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final hours = int.parse(match[2]!);
    final minutes = int.parse(match[3]!);
    if (minutes > 59 || hours > 14 || (hours == 14 && minutes != 0)) {
      return null;
    }
    return (hours * 60 + minutes) * (match[1] == '-' ? -1 : 1);
  }

  List<Map<String, Object?>> _globalHealthList(
    http.Response response, {
    bool items = false,
  }) {
    final data = _decode(response)['data'];
    final rows = items && data is Map ? data['items'] : data;
    if (rows is! List || rows.any((row) => row is! Map)) {
      throw const ApiException(
        'Unable to read health settings. Please try again.',
        code: 'INVALID_HEALTH_RESPONSE',
      );
    }
    return rows
        .cast<Map>()
        .map((row) => row.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  Map<String, Map<String, Object?>> _globalWarningRules(
    List<Map<String, Object?>> rows,
  ) {
    final rules = <String, Map<String, Object?>>{};
    for (final row in rows) {
      final metric = row['metric'];
      if (metric is! String ||
          rules.containsKey(metric) ||
          row['enabled'] is! bool ||
          row['shareWithCare'] is! bool) {
        throw const ApiException(
          'Unable to read health settings. Please try again.',
          code: 'INVALID_HEALTH_RESPONSE',
        );
      }
      for (final key in [
        'lowThreshold',
        'highThreshold',
        'secondaryHighThreshold',
      ]) {
        final value = row[key];
        if (value != null && (value is! num || !value.isFinite)) {
          throw const ApiException(
            'Unable to read health settings. Please try again.',
            code: 'INVALID_HEALTH_RESPONSE',
          );
        }
      }
      rules[metric] = row;
    }
    return rules;
  }

  HealthWarningSettings _globalWarningSettings(
    Map<String, Map<String, Object?>> rules,
  ) {
    final defaults = const HealthWarningSettings();
    final heart = rules['heart_rate'];
    final pressure = rules['blood_pressure'];
    final temperature = rules['temperature'];
    int threshold(Map<String, Object?>? rule, String key, int fallback) {
      final value = rule?[key];
      if (value == null) return fallback;
      if (value is! num || value != value.toInt()) {
        throw const ApiException(
          'Unable to read health settings.',
          code: 'INVALID_HEALTH_RESPONSE',
        );
      }
      return value.toInt();
    }

    return HealthWarningSettings(
      heartRateEnabled: heart?['enabled'] == true,
      heartRateUpper: threshold(
        heart,
        'highThreshold',
        defaults.heartRateUpper,
      ),
      bloodPressureEnabled: pressure?['enabled'] == true,
      systolicUpper: threshold(
        pressure,
        'highThreshold',
        defaults.systolicUpper,
      ),
      diastolicUpper: threshold(
        pressure,
        'secondaryHighThreshold',
        defaults.diastolicUpper,
      ),
      temperatureEnabled: temperature?['enabled'] == true,
      temperatureUpper:
          (temperature?['highThreshold'] as num?)?.toDouble() ??
          defaults.temperatureUpper,
    );
  }

  @override
  Future<HealthWarningSettings?> getHealthWarningSettings() async {
    final owner = _stableSessionAccountKey(await _requiredSession());
    return _globalWarningSettings(
      _globalWarningRules(
        _globalHealthList(
          await _globalHealthRequest(
            owner,
            'GET',
            '$_healthRoot/warning-rules',
          ),
        ),
      ),
    );
  }

  @override
  Future<void> saveHealthWarningSettings(HealthWarningSettings settings) async {
    final owner = _stableSessionAccountKey(await _requiredSession());
    final current = _globalWarningRules(
      _globalHealthList(
        await _globalHealthRequest(owner, 'GET', '$_healthRoot/warning-rules'),
      ),
    );
    Map<String, Object?> rule(
      String metric,
      bool enabled,
      num high, [
      num? secondary,
    ]) => {
      'metric': metric,
      'enabled': enabled,
      'highThreshold': high,
      'secondaryHighThreshold': secondary,
      'lowThreshold': current[metric]?['lowThreshold'],
      'shareWithCare': current[metric]?['shareWithCare'] == true,
    };
    final requested = [
      rule('heart_rate', settings.heartRateEnabled, settings.heartRateUpper),
      rule(
        'blood_pressure',
        settings.bloodPressureEnabled,
        settings.systolicUpper,
        settings.diastolicUpper,
      ),
      rule(
        'temperature',
        settings.temperatureEnabled,
        settings.temperatureUpper,
      ),
    ];
    _decode(
      await _globalHealthRequest(
        owner,
        'POST',
        '$_healthRoot/warning-rules',
        body: {'rules': requested},
      ),
    );
    final saved = _globalWarningRules(
      _globalHealthList(
        await _globalHealthRequest(owner, 'GET', '$_healthRoot/warning-rules'),
      ),
    );
    for (final expected in requested) {
      final actual = saved[expected['metric']];
      if (actual == null ||
          expected.entries.any((entry) => actual[entry.key] != entry.value)) {
        throw const ApiException(
          'Your changes could not be confirmed. Please reload and try again.',
          code: 'HEALTH_SETTINGS_UNCONFIRMED',
        );
      }
    }
  }

  @override
  Future<List<HealthWarningAlert>> getHealthWarningAlerts() async {
    final owner = _stableSessionAccountKey(await _requiredSession());
    final rows = _globalHealthList(
      await _globalHealthRequest(
        owner,
        'GET',
        '$_healthRoot/warnings',
        query: {'limit': '200'},
      ),
      items: true,
    );
    return rows.map((row) {
      final wire = row['metric'] == 'temperature'
          ? 'body_temperature'
          : row['metric'];
      final metric = HealthMetric.values
          .where((candidate) => candidate.wireName == wire)
          .firstOrNull;
      final id = row['eventId'];
      final time = row['observedAt'] is String
          ? DateTime.tryParse(row['observedAt'] as String)
          : null;
      if (id is! String || id.isEmpty || metric == null || time == null) {
        throw const ApiException(
          'Unable to read health reminders. Please try again.',
          code: 'INVALID_HEALTH_RESPONSE',
        );
      }
      return HealthWarningAlert(
        id: id,
        metric: metric,
        title: 'Health reminder',
        message: 'A reminder you set was triggered. Review your health record.',
        triggeredAt: time.toUtc(),
        origin: MeasurementOrigin.unknown,
      );
    }).toList();
  }
}
