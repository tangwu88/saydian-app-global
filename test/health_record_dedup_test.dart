import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_record_dedup.dart';
import 'package:saydian_app/domain/models.dart';

void main() {
  test('same watch metric and second keeps the richer record', () {
    final measuredAt = DateTime.utc(2026, 8, 28, 8, 30, 15, 120);
    final result = deduplicateHealthRecords([
      _record('first', measuredAt, const {'value': 78}, quality: 'poor'),
      _record(
        'richer',
        measuredAt.add(const Duration(milliseconds: 600)),
        const {'value': 78, 'confidence': 95},
        quality: 'good',
      ),
    ]);

    expect(result, hasLength(1));
    expect(result.single.id, 'richer');
  });

  test('different devices and different seconds remain separate', () {
    final measuredAt = DateTime.utc(2026, 8, 28, 8, 30, 15);
    final result = deduplicateHealthRecords([
      _record('watch-a', measuredAt, const {'value': 78}),
      _record('watch-b', measuredAt, const {'value': 78}, deviceId: 'W9S-B'),
      _record('next-second', measuredAt.add(const Duration(seconds: 1)), const {
        'value': 79,
      }),
    ]);

    expect(result, hasLength(3));
  });

  test(
    'daily revisions show only the latest observed total per watch and day',
    () {
      final first = DateTime.utc(2026, 9, 28, 1);
      HealthRecord daily(
        String id,
        int value,
        DateTime observedAt,
        String device,
      ) => HealthRecord(
        id: id,
        metric: HealthMetric.steps,
        values: {'value': value},
        unit: '步',
        measuredAt: observedAt,
        timezone: '+08:00',
        deviceId: device,
        firmwareVersion: 'test',
        quality: 'valid',
        source: MeasurementSource.wearable,
        rawVersion: 1,
        aggregation: const HealthAggregation.dailySummary('2026-09-28'),
      );

      final result = deduplicateHealthRecords([
        daily('old', 1000, first, 'urion:a'),
        daily('new', 2000, first.add(const Duration(minutes: 5)), 'urion:a'),
        daily('retry', 2000, first.add(const Duration(minutes: 5)), 'urion:a'),
        daily('other-watch', 500, first, 'urion:b'),
      ]);
      expect(result, hasLength(2));
      expect(
        result
            .where((record) => record.deviceId == 'urion:a')
            .single
            .values['value'],
        2000,
      );
    },
  );
}

HealthRecord _record(
  String id,
  DateTime measuredAt,
  Map<String, num> values, {
  String quality = 'device_reported',
  String deviceId = 'W9S-A',
}) => HealthRecord(
  id: id,
  metric: HealthMetric.heartRate,
  values: values,
  unit: 'bpm',
  measuredAt: measuredAt,
  timezone: '+08:00',
  deviceId: deviceId,
  firmwareVersion: 'test',
  quality: quality,
  source: MeasurementSource.wearable,
  rawVersion: 1,
);
