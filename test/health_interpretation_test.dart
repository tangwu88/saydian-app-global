import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_interpretation.dart';
import 'package:saydian_app/domain/models.dart';

void main() {
  HealthRecord record(HealthMetric metric, Map<String, num> values) =>
      HealthRecord(
        id: 'test-${metric.name}',
        metric: metric,
        values: values,
        unit: metric == HealthMetric.bodyTemperature ? '℃' : '',
        measuredAt: DateTime.utc(2026, 8, 20),
        timezone: '+08:00',
        deviceId: 'veepoo:w9s',
        firmwareVersion: '00.20.01',
        quality: 'unknown',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      );

  test('high body temperature is never described as normal', () {
    final result = interpretHealthRecord(
      record(HealthMetric.bodyTemperature, const {'value': 40.5}),
    );

    expect(result.title, contains('偏高'));
    expect(result.detail, contains('医用体温计'));
  });

  test('ECG device flags produce a visible attention message', () {
    final result = interpretHealthRecord(
      record(HealthMetric.ecg, const {
        'meanHeartRate': 78,
        'deviceAbnormalFlags': 2,
      }),
    );

    expect(result.title, contains('需关注'));
    expect(result.detail, contains('不是医学诊断'));
  });

  test('US watch copy preserves caution without diagnosing a reading', () {
    final elevated = interpretHealthRecord(
      record(HealthMetric.bloodPressure, const {
        'systolic': 145,
        'diastolic': 91,
      }),
      english: true,
    );
    expect(elevated.title, 'Higher reading');
    expect(elevated.detail, contains('measure again'));

    final borderline = interpretHealthRecord(
      record(HealthMetric.bloodPressure, const {
        'systolic': 132,
        'diastolic': 84,
      }),
      english: true,
    );
    expect(borderline.title, 'Reading saved');
    expect(borderline.detail, isNot(contains('normal')));

    final oxygen = interpretHealthRecord(
      record(HealthMetric.bloodOxygen, const {'value': 94}),
      english: true,
    );
    expect(oxygen.title, 'Lower oxygen estimate');
    expect(oxygen.detail, contains('medical care'));
  });

  test('body and blood component fields have distinct labels and units', () {
    final body = record(HealthMetric.bodyComposition, const {'bmi': 22.6});
    final blood = record(HealthMetric.bloodComposition, const {
      'uricAcid': 320,
    });

    expect(healthValueLabel('bmi', body.metric), 'BMI');
    expect(healthValueLabel('bodyFatRate', body.metric), '体脂率');
    expect(healthValueUnit('bodyFatRate', body), '%');
    expect(healthValueLabel('uricAcid', blood.metric), '尿酸');
    expect(healthValueUnit('uricAcid', blood), 'μmol/L');
  });
}
