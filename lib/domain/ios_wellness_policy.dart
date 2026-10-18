import 'package:flutter/foundation.dart';

import 'feature_models.dart';
import 'models.dart';

/// iOS cloud scope stays activity/sleep. Verified Urion devices can additionally
/// expose local sensor records, independently of account or build mode.
/// Projections are views/transport payloads; never rewrite historical storage.
class IosWellnessPolicy {
  const IosWellnessPolicy({
    required this.enabled,
    this.urionLocalDevice = false,
  });

  static IosWellnessPolicy get current => IosWellnessPolicy(
    enabled: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
  );

  final bool enabled;
  final bool urionLocalDevice;
  static IosWellnessPolicy forSdkSource(WearableSdkSource? source) =>
      IosWellnessPolicy(
        enabled: current.enabled,
        urionLocalDevice: source == WearableSdkSource.urion,
      );
  static const urionLocalMetrics = {
    HealthMetric.bloodPressure,
    HealthMetric.heartRate,
    HealthMetric.bloodOxygen,
  };
  static const urionLocalCommands = {0x14, 0x15, 0x2d, 0x32, 0x38, 0x39};
  bool get hasLocalDeviceMetrics => enabled && urionLocalDevice;
  bool allowsMeasurement(HealthMetric metric) =>
      !enabled || (urionLocalDevice && urionLocalMetrics.contains(metric));
  static const blockedEB1Commands = {
    0x14,
    0x15,
    0x16,
    0x2c,
    0x2d,
    0x32,
    0x34,
    0x35,
    0x36,
    0x38,
    0x39,
    0x3a,
  };
  static const metrics = {
    HealthMetric.steps,
    HealthMetric.distance,
    HealthMetric.calories,
    HealthMetric.sleep,
  };
  Set<HealthMetric>? get allowedMetrics =>
      enabled ? {...metrics, if (urionLocalDevice) ...urionLocalMetrics} : null;
  bool allowsMetric(HealthMetric metric) =>
      !enabled || allowedMetrics!.contains(metric);
  bool allowsWireMetric(String wire) =>
      !enabled || allowedMetrics!.any((metric) => metric.wireName == wire);
  bool isDisplayable(HealthRecord record, {DateTime? now}) =>
      !enabled ||
      (allowsMetric(record.metric) &&
          !record.measuredAt.isAfter(
            (now ?? DateTime.now()).toUtc().add(const Duration(minutes: 10)),
          ));
  bool allowsFeature(DeviceFeature feature) =>
      !enabled ||
      !const {
        DeviceFeature.healthMonitoring,
        DeviceFeature.healthAssessment,
        DeviceFeature.healthReminders,
      }.contains(feature);

  Map<String, num> projectValues(HealthMetric metric, Map<String, num> values) {
    if (!enabled) return values;
    const sleepKeys = {
      'value',
      'hours',
      'deepHours',
      'lightHours',
      'remHours',
      'awakeMinutes',
      'wakeCount',
    };
    final keys = metric == HealthMetric.sleep
        ? sleepKeys
        : metric == HealthMetric.bloodPressure && urionLocalDevice
        ? const {'systolic', 'diastolic'}
        : const {'value'};
    return Map.unmodifiable({
      for (final entry in values.entries)
        if (allowsMetric(metric) && keys.contains(entry.key))
          entry.key: entry.value,
    });
  }

  HealthRecord? projectRecord(HealthRecord record) {
    if (!enabled) return record;
    if (!allowsMetric(record.metric)) return null;
    if (urionLocalMetrics.contains(record.metric) &&
        (WearableSdkSource.fromDeviceId(record.deviceId) !=
                WearableSdkSource.urion ||
            record.origin == MeasurementOrigin.remoteMember)) {
      return null;
    }
    return HealthRecord(
      id: record.id,
      metric: record.metric,
      values: projectValues(record.metric, record.values),
      unit: record.unit,
      measuredAt: record.measuredAt,
      timezone: record.timezone,
      deviceId: record.deviceId,
      firmwareVersion: record.firmwareVersion,
      quality: 'unknown',
      source: record.source,
      origin: record.origin,
      rawVersion: record.rawVersion,
      aggregation: record.aggregation,
      sourceModel: record.sourceModel,
      sleepTimeline:
          record.metric == HealthMetric.sleep && record.sleepTimeline != null
          ? projectSleepTimeline(record.sleepTimeline!)
          : null,
    );
  }

  List<HealthRecord> projectRecords(Iterable<HealthRecord> records) => records
      .map(projectRecord)
      .whereType<HealthRecord>()
      .toList(growable: false);

  DeviceCapabilities projectCapabilities(DeviceCapabilities capabilities) {
    if (!enabled) return capabilities;
    return DeviceCapabilities(
      metrics: capabilities.metrics.where(allowsMetric).toSet(),
      manualMetrics: (capabilities.manualMetrics ?? const <HealthMetric>{})
          .where(allowsMeasurement)
          .toSet(),
      stoppableManualMetrics: const {},
      sportModes: capabilities.sportModes,
      features: capabilities.features.where(allowsFeature).toSet(),
      integratedFeatures: capabilities.integratedFeatures
          .where(allowsFeature)
          .toSet(),
      supportsSportPause: capabilities.supportsSportPause,
      supportsBackgroundSync: capabilities.supportsBackgroundSync,
      supportsWatchFaces: capabilities.supportsWatchFaces,
      supportsOta: capabilities.supportsOta,
    );
  }

  Map<String, Object?> projectSleepTimeline(Map<String, Object?> timeline) {
    if (!enabled) return timeline;
    Map<String, Object?> keep(Map source, Set<String> keys) => {
      for (final key in keys)
        if (source.containsKey(key)) key: source[key],
    };
    final result = keep(timeline, {
      'deviceId',
      'sdkDate',
      'recordDate',
      'timezone',
      'source',
      'readAt',
      'revision',
      'sessions',
      'rawSummary',
    });
    if (timeline['rawSummary'] case final Map summary) {
      result['rawSummary'] = keep(summary, {
        'totalSeconds',
        'deepSeconds',
        'lightSeconds',
        'awakeSeconds',
        'remSeconds',
        'napSeconds',
        'reportedTotalMinutes',
        'wakeCount',
      });
    }
    if (timeline['sessions'] case final List sessions) {
      result['sessions'] = [
        for (final session in sessions)
          if (session is Map)
            {
              ...keep(session, {'id', 'kind', 'startAt', 'endAt'}),
              'segments': session['segments'] is List
                  ? [
                      for (final segment in session['segments'] as List)
                        if (segment is Map)
                          keep(segment, {'stage', 'startAt', 'endAt'})
                        else
                          segment,
                    ]
                  : session['segments'],
            }
          else
            session,
      ];
    }
    return Map.unmodifiable(result);
  }

  SportRecord projectSport(SportRecord record) {
    if (!enabled) return record;
    return SportRecord(
      id: record.id,
      mode: record.mode,
      startedAt: record.startedAt,
      durationSeconds: record.durationSeconds,
      distanceKm: record.distanceKm,
      calories: record.calories,
      steps: record.steps,
      routePoints: record.routePoints,
    );
  }

  Map<String, num> projectSportValues(Map<String, num> values) {
    if (!enabled) return values;
    const keys = {
      'durationSeconds',
      'distanceKm',
      'distanceMeters',
      'calories',
      'caloriesCal',
      'steps',
      'speed',
      'pace',
    };
    return Map.unmodifiable({
      for (final entry in values.entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    });
  }

  /// Global care rows use a different envelope; whitelist before decoding.
  Map<String, Object?>? projectCareRow(Map<String, Object?> row) {
    if (!enabled) return row;
    final wire = '${row['metric'] ?? ''}';
    if (!allowsWireMetric(wire)) return null;
    final metric = HealthMetric.fromWire(wire);
    final raw = row['values'];
    return {
      for (final key in const [
        'id',
        'metric',
        'unit',
        'observedAt',
        'timezoneOffsetMinutes',
        'aggregation',
      ])
        if (row.containsKey(key)) key: row[key],
      'values': projectValues(metric, {
        if (raw is Map)
          for (final entry in raw.entries)
            if (entry.value is num) '${entry.key}': entry.value as num,
      }),
    };
  }
}
