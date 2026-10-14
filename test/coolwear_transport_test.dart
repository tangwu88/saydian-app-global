import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/coolwear_wearable_bridge.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cc.saidian.ring/commands');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('missing native integration cannot claim LUCKRING support', () async {
    await expectLater(
      CoolWearWearableBridge().scanDevices(),
      throwsA(isA<WearableSdkNotConfigured>()),
    );
  });

  test(
    'raw Bluetooth link without resolved capabilities fails closed',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'resolved': false,
          'metrics': ['steps'],
        },
      );
      await expectLater(
        CoolWearWearableBridge().getCapabilities(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'CAPABILITIES_UNAVAILABLE',
          ),
        ),
      );
    },
  );

  for (final envelope in [false, true]) {
    test(
      '${envelope ? 'iOS' : 'Android'} history preserves actual device data',
      () async {
        final records = [
          {
            'id': 'fixture-record',
            'type': 'steps',
            'values': {'value': 123},
            'unit': 'steps',
            'measuredAt': '2026-10-11T08:00:00Z',
            'timezone': '+08:00',
            'deviceId': 'coolwear:fixture-uuid',
            'quality': 'device_reported',
            'source': 'wearable',
            'origin': 'watch_history',
            'rawVersion': 2,
          },
        ];
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'syncHealthData');
          return envelope
              ? {
                  'records': records,
                  'statuses': {'steps': 'complete'},
                }
              : records;
        });
        final result = await CoolWearWearableBridge().syncHealthData();
        expect(result.single.metric, HealthMetric.steps);
        expect(result.single.values, {'value': 123});
        expect(result.single.deviceId, 'coolwear:fixture-uuid');
        expect(result.single.measuredAt, DateTime.utc(2026, 10, 11, 8));
        expect(result.single.origin, MeasurementOrigin.watchHistory);
      },
    );
  }

  test('invalid history shape cannot become a successful empty sync', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'records': 'invalid'},
    );
    await expectLater(
      CoolWearWearableBridge().syncHealthData(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'COOLWEAR_INVALID_HISTORY_RESPONSE',
        ),
      ),
    );
  });
  test(
    'device reminder capabilities and settings reach their exact channel',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getCapabilities') {
          return {
            'resolved': true,
            'features': [
              'call_reminder',
              'notifications',
              'health_reminders',
              'alarms',
            ],
            'integratedFeatures': [
              'call_reminder',
              'notifications',
              'health_reminders',
              'alarms',
            ],
          };
        }
        if (call.method == 'readDeviceFeature') {
          return {'enabled': false, 'snapshotRevision': 'fixture'};
        }
        return null;
      });
      final bridge = CoolWearWearableBridge();
      final capabilities = await bridge.getCapabilities();
      expect(capabilities.features, contains(DeviceFeature.callReminder));
      for (final feature in [
        DeviceFeature.callReminder,
        DeviceFeature.notifications,
        DeviceFeature.healthReminders,
        DeviceFeature.alarms,
      ]) {
        await bridge.readDeviceFeature(feature);
        await bridge.writeDeviceFeature(feature, {
          'enabled': true,
          'snapshotRevision': 'fixture',
        });
        expect(calls[calls.length - 2].arguments, {
          'feature': feature.wireName,
        });
        expect(calls.last.arguments, {
          'feature': feature.wireName,
          'values': {'enabled': true, 'snapshotRevision': 'fixture'},
        });
      }
    },
  );
}
