import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/wearable_bootstrap.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  test(
    'production bridge routes W8 to Yucheng and VP watch to Veepoo',
    () async {
      final veepoo = _FakeBridge(const [
        DeviceInfo(id: 'VP-01', name: 'VP-100'),
      ]);
      final yucheng = _FakeBridge(const [
        DeviceInfo(id: 'YC-01', name: 'W8 Pro'),
      ]);
      final urion = _FakeBridge(const [
        DeviceInfo(id: 'UR-01', name: 'U19S'),
      ]);
      final bridge = createProductionWearableBridge(
        veepoo: veepoo,
        yucheng: yucheng,
        urion: urion,
      );
      final devices = await bridge.scanDevices();
      await bridge.connect(
        devices.singleWhere((d) => d.name == 'W8 Pro').id,
        profile: _profile,
      );
      expect(yucheng.connectCalls, ['YC-01']);
      expect(veepoo.connectCalls, isEmpty);
      await bridge.disconnect();
      await bridge.connect(
        devices.singleWhere((d) => d.name == 'U19S').id,
        profile: _profile,
      );
      expect(urion.connectCalls, ['UR-01']);
    },
  );
}

const _profile = WearableUserProfile(
  gender: 1,
  heightCm: 175,
  weightKg: 70,
  birthYear: 1996,
  age: 30,
  targetSteps: 10000,
);

class _FakeBridge implements WearableBridge {
  _FakeBridge(this.devices);
  final List<DeviceInfo> devices;
  final List<String> connectCalls = [];
  @override
  Stream<WearableEvent> get events => const Stream.empty();
  @override
  Future<List<DeviceInfo>> scanDevices() async => devices;
  @override
  Future<void> stopScan() async {}
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connectCalls.add(deviceId);
  }

  @override
  Future<void> disconnect() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(metrics: {});
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => [];
  @override
  Future<void> startMeasurement(HealthMetric metric) async {}
  @override
  Future<void> stopMeasurement(HealthMetric metric) async {}
  @override
  Future<void> startSport(SportMode mode) async {}
  @override
  Future<void> stopSport() async {}
  @override
  Future<List<SportRecord>> readSportRecords() async => [];
  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async => {};
  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) async {}
  @override
  Future<int?> readHeartRateWarning() async => null;
  @override
  Future<void> setHeartRateWarning(int value) async {}
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      {};
  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {}
  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {}
}
