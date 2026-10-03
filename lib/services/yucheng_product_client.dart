import 'dart:async';

import 'package:flutter/services.dart';
import 'package:yc_product_plugin/yc_product_plugin.dart' as yc;

abstract final class YuchengHealthDataType {
  static const step = 0;
  static const sleep = 1;
  static const heartRate = 2;
  static const bloodPressure = 3;
  static const combined = 4;
  static const invasive = 5;
  static const sportHistory = 6;
}

abstract final class YuchengMeasurementType {
  static const heartRate = 0;
  static const bloodPressure = 1;
  static const bloodOxygen = 2;
  static const bodyTemperature = 4;
  static const bloodGlucose = 5;
}

abstract final class YuchengSportState {
  static const stop = 0;
  static const start = 1;
  static const pause = 2;
  static const resume = 3;
}

class YuchengOperationResult<T> {
  const YuchengOperationResult(this.status, this.data);
  final int status;
  final T? data;
}

class YuchengDeviceBasicInfo {
  const YuchengDeviceBasicInfo({
    required this.batteryPercent,
    required this.batteryStatus,
    required this.firmwareVersion,
  });

  /// Vendor values: 0 normal, 1 low, 2 charging, 3 full.
  final int batteryStatus;
  final int batteryPercent;
  final String firmwareVersion;
}

abstract interface class YuchengProductClient {
  Stream<Map<String, Object?>> get events;
  Future<void> initialize({
    required bool reconnectEnabled,
    required bool logEnabled,
  });
  Future<List<Map<String, Object?>>> scan();
  Future<void> stopScan();
  Future<bool> connect(String identifier);
  Future<bool> connectSaved({
    required String identifier,
    required String name,
    String? hardwareAddress,
  });
  Future<void> disconnect();
  Future<YuchengOperationResult<String>> model();
  Future<YuchengOperationResult<String>> firmware();
  Future<YuchengOperationResult<String>> macAddress();
  Future<YuchengOperationResult<YuchengDeviceBasicInfo>> basicInfo();
  Future<Map<String, Object?>> capabilities();
  Future<YuchengOperationResult<void>> syncTime();
  Future<YuchengOperationResult<void>> setUserProfile({
    required int height,
    required int weight,
    required int age,
    required int gender,
  });
  Future<YuchengOperationResult<void>> setStepGoal(int steps);
  Future<YuchengOperationResult<List<Map<String, Object?>>>> health(int type);
  Future<YuchengOperationResult<void>> measure({
    required bool enabled,
    required int type,
  });
  Future<YuchengOperationResult<void>> sport({
    required int state,
    required int type,
  });
  Future<YuchengOperationResult<void>> setHealthMonitoring(bool enabled);
  Future<YuchengOperationResult<void>> setHeartRateAlarm(int value);
  Future<YuchengOperationResult<void>> findDevice();
  Future<YuchengOperationResult<void>> camera(bool enabled);
  Future<YuchengOperationResult<List<Map<String, Object?>>>> watchFaces();
  Future<YuchengOperationResult<void>> changeWatchFace(int dialId);
}

abstract interface class YuchengEcgClient {
  Future<YuchengOperationResult<int>> ecgSampleRate();
  Future<YuchengOperationResult<void>> startEcg();
  Future<YuchengOperationResult<void>> stopEcg();
  Future<YuchengOperationResult<Map<String, num>>> ecgResult();
}

class PluginYuchengProductClient
    implements YuchengProductClient, YuchengEcgClient {
  PluginYuchengProductClient({yc.YcProductPlugin? plugin})
    : _plugin = plugin ?? yc.YcProductPlugin();
  final yc.YcProductPlugin _plugin;
  final _events = StreamController<Map<String, Object?>>.broadcast();
  final Map<String, yc.BluetoothDevice> _scanned = {};
  static const _nativeEvents = EventChannel(
    'ycaviation.com/yc_product_plugin_event_channel',
  );
  StreamSubscription<Object?>? _nativeEventSubscription;

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Future<void> initialize({
    required bool reconnectEnabled,
    required bool logEnabled,
  }) async {
    await _plugin.initPlugin(
      isReconnectEnable: reconnectEnabled,
      isLogEnable: logEnabled,
    );
    // Avoid the upstream Dart listener: on Android it automatically calls
    // getDeviceFeature before ReadWriteOK has settled. The native failure path
    // returns a self-referencing map and crashes StandardMessageCodec.
    await _nativeEventSubscription?.cancel();
    _nativeEventSubscription = _nativeEvents.receiveBroadcastStream().listen((
      event,
    ) {
      if (event is Map) {
        _events.add(event.map((key, value) => MapEntry('$key', value)));
      }
    }, onError: _events.addError);
    // On iOS the SDK creates CBCentralManager asynchronously. Starting a scan
    // while its state is still unknown is silently ignored by the vendor SDK.
    // Wait briefly for Bluetooth to become usable before the first scan.
    for (var attempt = 0; attempt < 30; attempt += 1) {
      final state = await _plugin.getBluetoothState();
      if (state == yc.BluetoothState.on ||
          state == yc.BluetoothState.connected) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Future<List<Map<String, Object?>>> scan() async {
    final devices =
        await _plugin.scanDevice(time: 8) ?? const <yc.BluetoothDevice>[];
    _scanned
      ..clear()
      ..addEntries(devices.map((d) => MapEntry(d.deviceIdentifier, d)));
    return devices
        .map(
          (d) => <String, Object?>{
            'identifier': d.deviceIdentifier,
            'name': d.name,
            'rssi': d.rssiValue,
            'hardwareAddress': d.macAddress.trim().isEmpty
                ? null
                : d.macAddress,
            'firmwareVersion': d.firmwareVersion == 0
                ? null
                : '${d.firmwareVersion}',
          },
        )
        .toList();
  }

  @override
  Future<void> stopScan() => _plugin.stopScanDevice();

  @override
  Future<bool> connect(String identifier) async {
    final device = _scanned[identifier];
    if (device == null) return false;
    // A failed/aborted YCBT attempt can leave Android's GATT layer in a
    // background-connection state. A new connectBleDevice call is then
    // ignored and never invokes its callback. Clear only the SDK connection
    // (preserving the system bond) before every explicit user connection.
    try {
      await _plugin.disconnectDevice().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Continue: the native disconnect call is best-effort and may not return.
    }
    for (var attempt = 0; attempt < 10; attempt += 1) {
      final state = await _plugin.getBluetoothState();
      if (state != yc.BluetoothState.connected) break;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final connected = await _plugin.connectDevice(device) == true;
    if (connected) _plugin.connectedDevice = device;
    return connected;
  }

  @override
  Future<bool> connectSaved({
    required String identifier,
    required String name,
    String? hardwareAddress,
  }) async {
    // The Android plugin resolves a connection only from its native scan list;
    // constructing a Dart BluetoothDevice does not populate that list and leaves
    // connectDevice waiting forever. Scan, then select only the exact persisted
    // identifier or hardware address so a same-model watch is never guessed.
    await scan();
    final savedIdentifier = _normalizedDeviceKey(identifier);
    final savedHardwareAddress = _normalizedDeviceKey(hardwareAddress ?? '');
    yc.BluetoothDevice? matched;
    for (final device in _scanned.values) {
      final identifierMatches =
          _normalizedDeviceKey(device.deviceIdentifier) == savedIdentifier;
      final hardwareMatches =
          savedHardwareAddress.isNotEmpty &&
          _normalizedDeviceKey(device.macAddress) == savedHardwareAddress;
      if (identifierMatches || hardwareMatches) {
        matched = device;
        break;
      }
    }
    if (matched == null) return false;
    return connect(matched.deviceIdentifier);
  }

  static String _normalizedDeviceKey(String value) =>
      value.trim().toUpperCase();

  @override
  Future<void> disconnect() async {
    await _plugin.disconnectDevice();
  }

  @override
  Future<YuchengOperationResult<String>> model() async {
    final r = await _plugin.queryDeviceModel();
    return YuchengOperationResult(r?.statusCode ?? 1, r?.data);
  }

  @override
  Future<YuchengOperationResult<String>> firmware() async {
    final r = await _plugin.queryDeviceBasicInfo();
    return YuchengOperationResult(r?.statusCode ?? 1, r?.data.firmwareVersion);
  }

  @override
  Future<YuchengOperationResult<String>> macAddress() async {
    final r = await _plugin.queryDeviceMacAddress();
    return YuchengOperationResult(r?.statusCode ?? 1, r?.data);
  }

  @override
  Future<YuchengOperationResult<YuchengDeviceBasicInfo>> basicInfo() async {
    final r = await _plugin.queryDeviceBasicInfo();
    final data = r?.data;
    return YuchengOperationResult(
      r?.statusCode ?? 1,
      data == null
          ? null
          : YuchengDeviceBasicInfo(
              batteryPercent: data.batteryPower,
              batteryStatus: data.batteryStatus.index,
              firmwareVersion: data.firmwareVersion,
            ),
    );
  }

  @override
  Future<Map<String, Object?>> capabilities() async {
    final f = await _plugin.getDeviceFeature();
    if (f == null) return const {};
    return {
      'isSupportStep': f.isSupportStep,
      'isSupportSleep': f.isSupportSleep,
      'isSupportHeartRate': f.isSupportHeartRate,
      'isSupportBloodPressure': f.isSupportBloodPressure,
      'isSupportBloodOxygen': f.isSupportBloodOxygen,
      'isSupportTemperature': f.isSupportTemperature,
      'isSupportBloodGlucose': f.isSupportBloodGlucose,
      'isSupportHRV': f.isSupportHRV,
      'isSupportRealTimeECG': f.isSupportRealTimeECG,
      'isSupportHistoricalECG': f.isSupportHistoricalECG,
      'isSupportECGDiagnosis': f.isSupportECGDiagnosis,
      'isSupportStartHeartRateMeasurement':
          f.isSupportStartHeartRateMeasurement,
      'isSupportStartBloodPressureMeasurement':
          f.isSupportStartBloodPressureMeasurement,
      'isSupportStartBloodOxygenMeasurement':
          f.isSupportStartBloodOxygenMeasurement,
      'isSupportStartBodyTemperatureMeasurement':
          f.isSupportStartBodyTemperatureMeasurement,
      'isSupportStartBloodGlucoseMeasurement':
          f.isSupportStartBloodGlucoseMeasurement,
      'isSupportSport': f.isSupportSport,
      'isSupportOutdoorRunning': f.isSupportOutdoorRunning,
      'isSupportOutdoorWalking': f.isSupportOutdoorWalking,
      'isSupportRiding': f.isSupportRiding,
      'isSupportOnFoot': f.isSupportOnFoot,
      'isSupportMountaineering': f.isSupportMountaineering,
      'isSupportSportPause': f.isSupportSportPause,
      'isSupportFindDevice': f.isSupportFindDevice,
      'isSupportCamera':
          f.isSupportManualPhotographing || f.isSupportShakePhotographing,
      'isSupportCall': f.isSupportCall,
      'isSupportAddressBook': f.isSupportAddressBook,
      'isSupportAlarm': f.isSupportAlarm,
      'isSupportWeather': f.isSupportTodayWeather,
      'isSupportHealthMonitoring': f.isSupportHeartRate,
      'isSupportScreen': f.isSupportWristBrightScreen,
      'isSupportWatchFace': f.isSupportWatchFace,
      'isSupportOta': f.isSupportOta,
    };
  }

  static const _nativeMethods = MethodChannel(
    'ycaviation.com/yc_product_plugin_method_channel',
  );

  @override
  Future<YuchengOperationResult<int>> ecgSampleRate() async {
    try {
      // The pinned Android plugin already exposes the vendor query, but its
      // Dart facade omits it. Type 1 is ECG; never change device sampling.
      final response = await _nativeMethods.invokeMapMethod<String, Object?>(
        'appQuerySampleRate',
        1,
      );
      final data = response?['data'];
      final type = data is Map ? data['type'] : null;
      final raw = data is Map
          ? data['sampleRate'] ?? data['samplingRate']
          : null;
      final reported = raw is num ? raw : num.tryParse('$raw');
      // The pinned Android SDK's ECG pipeline initializes initHeart at 250 Hz.
      // Real W8 firmware returns {type: 1, sampleRate: 25000} for that stream.
      // Accept this verified encoding only; do not rescale arbitrary values.
      final rate = type == 1 && reported == 25000 ? 250 : reported;
      final status = (response?['code'] as num?)?.toInt() ?? 1;
      return YuchengOperationResult(
        status,
        status == 0 &&
                (type == null || type == 1) &&
                rate != null &&
                rate.isFinite &&
                rate == rate.toInt() &&
                rate >= 50 &&
                rate <= 1000
            ? rate.toInt()
            : null,
      );
    } on MissingPluginException {
      return const YuchengOperationResult(2, null);
    }
  }

  @override
  Future<YuchengOperationResult<void>> startEcg() async =>
      _r(await _plugin.startECGMeasurement());
  @override
  Future<YuchengOperationResult<void>> stopEcg() async =>
      _r(await _plugin.stopECGMeasurement());
  @override
  Future<YuchengOperationResult<Map<String, num>>> ecgResult() async {
    final response = await _plugin.getECGResult();
    final result = response?.data;
    return YuchengOperationResult(
      response?.statusCode ?? 1,
      result == null
          ? null
          : {
              if (result.hearRate > 0) 'meanHeartRate': result.hearRate,
              'qrsType': result.qrsType,
              'afFlag': result.afFlag ? 1 : 0,
              if (result.hrvNorm != null) 'hrv': result.hrvNorm!,
              if (result.respiratoryRate != null)
                'respiratoryRate': result.respiratoryRate!,
            },
    );
  }

  YuchengOperationResult<T> _r<T>(yc.PluginResponse<T>? r) =>
      YuchengOperationResult(r?.statusCode ?? 1, r?.data);

  @override
  Future<YuchengOperationResult<void>> syncTime() async =>
      _r(await _plugin.setDeviceSyncPhoneTime());
  @override
  Future<YuchengOperationResult<void>> setUserProfile({
    required int height,
    required int weight,
    required int age,
    required int gender,
  }) async => _r(
    await _plugin.setDeviceUserInfo(
      height,
      weight,
      age,
      gender == 2 ? yc.DeviceUserGender.female : yc.DeviceUserGender.male,
    ),
  );
  @override
  Future<YuchengOperationResult<void>> setStepGoal(int steps) async =>
      _r(await _plugin.setDeviceStepGoal(steps));
  @override
  Future<YuchengOperationResult<List<Map<String, Object?>>>> health(
    int type,
  ) async {
    final r = await _plugin.queryDeviceHealthData(type);
    final rows = (r?.data ?? const [])
        .map((v) => _healthRow(v))
        .whereType<Map<String, Object?>>()
        .toList();
    return YuchengOperationResult(r?.statusCode ?? 1, rows);
  }

  Map<String, Object?>? _healthRow(Object? value) {
    if (value is yc.StepDataInfo) {
      return {
        'startTimeStamp': value.startTimeStamp,
        'step': value.step,
        'distance': value.distance,
        'calories': value.calories,
      };
    }
    if (value is yc.SleepDataInfo) {
      return {
        'startTimeStamp': value.startTimeStamp,
        'deepSleepSeconds': value.deepSleepSeconds,
        'lightSleepSeconds': value.lightSleepSeconds,
        'remSleepSeconds': value.remSleepSeconds,
      };
    }
    if (value is yc.HeartRateDataInfo) {
      return {
        'startTimeStamp': value.startTimeStamp,
        'heartRate': value.heartRate,
      };
    }
    if (value is yc.BloodPressureDataInfo) {
      return {
        'startTimeStamp': value.startTimeStamp,
        'systolicBloodPressure': value.systolicBloodPressure,
        'diastolicBloodPressure': value.diastolicBloodPressure,
      };
    }
    if (value is yc.CombinedDataDataInfo) {
      return {
        'startTimeStamp': value.startTimeStamp,
        'bloodOxygen': value.bloodOxygen,
        'bloodGlucose': value.bloodGlucose,
        'temperature': value.temperature,
        'hrv': value.hrv,
      };
    }
    if (value is yc.SportModeDataInfo) {
      return {
        'startTimeStamp': value.startTimeStamp,
        'sportType': value.sportType,
        'sportTime': value.sportTime,
        'steps': value.step,
        'distance': value.distance,
        'calories': value.calories,
        'heartRate': value.heartRate,
        'minimumHeartRate': value.minimumHeartRate,
        'maximumHeartRate': value.maximumHeartRate,
      };
    }
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return null;
  }

  yc.DeviceAppControlMeasureHealthDataType _measurement(int type) =>
      switch (type) {
        YuchengMeasurementType.bloodPressure =>
          yc.DeviceAppControlMeasureHealthDataType.bloodPressure,
        YuchengMeasurementType.bloodOxygen =>
          yc.DeviceAppControlMeasureHealthDataType.bloodOxygen,
        YuchengMeasurementType.bodyTemperature =>
          yc.DeviceAppControlMeasureHealthDataType.bodyTemperature,
        YuchengMeasurementType.bloodGlucose =>
          yc.DeviceAppControlMeasureHealthDataType.bloodGlucose,
        _ => yc.DeviceAppControlMeasureHealthDataType.heartRate,
      };
  @override
  Future<YuchengOperationResult<void>> measure({
    required bool enabled,
    required int type,
  }) async => _r(
    await _plugin.appControlMeasureHealthData(enabled, _measurement(type)),
  );
  @override
  Future<YuchengOperationResult<void>> sport({
    required int state,
    required int type,
  }) async => _r(
    await _plugin.appControlSport(switch (state) {
      YuchengSportState.stop => yc.DeviceSportState.stop,
      YuchengSportState.pause => yc.DeviceSportState.pause,
      YuchengSportState.resume => yc.DeviceSportState.continueSport,
      _ => yc.DeviceSportState.start,
    }, type),
  );
  @override
  Future<YuchengOperationResult<void>> setHealthMonitoring(
    bool enabled,
  ) async => _r(await _plugin.setDeviceHealthMonitoringMode(isEnable: enabled));
  @override
  Future<YuchengOperationResult<void>> setHeartRateAlarm(int value) async => _r(
    await _plugin.setDeviceHeartRateAlarm(
      isEnable: value > 0,
      maxHeartRate: value,
    ),
  );
  @override
  Future<YuchengOperationResult<void>> findDevice() async =>
      _r(await _plugin.findDevice());
  @override
  Future<YuchengOperationResult<void>> camera(bool enabled) async =>
      _r(await _plugin.appControlTakePhoto(enabled));

  @override
  Future<YuchengOperationResult<List<Map<String, Object?>>>>
  watchFaces() async {
    final r = await _plugin.queryWatchFaceInfo();
    final faces = (r?.data ?? const <yc.DeviceWatchInfo>[])
        .map(
          (face) => <String, Object?>{
            'id': '${face.dialID}',
            'dialId': face.dialID,
            'name': face.isCustomDial ? '自定义表盘' : '表盘 ${face.dialID}',
            'isCurrent': face.isCurrentDial,
            'canDelete': face.isSupportDelete,
            'isCustom': face.isCustomDial,
            'type': 'yuc',
            'index': face.dialID,
            'status': face.isSupportDelete ? '已安装表盘' : '内置表盘',
          },
        )
        .toList();
    return YuchengOperationResult(r?.statusCode ?? 1, faces);
  }

  @override
  Future<YuchengOperationResult<void>> changeWatchFace(int dialId) async =>
      _r(await _plugin.changeWatchFace(dialId));
}
