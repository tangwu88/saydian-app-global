import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/device_state_machine.dart';
import '../domain/feature_models.dart';
import '../domain/models.dart';
import 'urion_eb1_protocol.dart';
import 'wearable_bridge.dart';

/// A separate EB1 transport. It does not call either vendor SDK and never
/// claims a watch from its advertised name alone.
class UrionWearableBridge
    implements WearableBridge, WearableDeviceDetailsBridge {
  UrionWearableBridge({
    MethodChannel? methods,
    EventChannel? eventChannel,
    this.requestTimeout = const Duration(seconds: 8),
    this.connectTimeout = const Duration(seconds: 30),
  }) : _methods = methods ?? const MethodChannel('cc.saidian/urion_methods'),
       _eventChannel =
           eventChannel ?? const EventChannel('cc.saidian/urion_events') {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      _onNativeEvent,
    );
  }

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  final Duration requestTimeout;
  final Duration connectTimeout;
  final SerialOperationQueue _queue = SerialOperationQueue();
  final FlutterSecureStorage _languageStorage = const FlutterSecureStorage();
  final Eb1FrameBuffer _buffer = Eb1FrameBuffer();
  final StreamController<WearableEvent> _events =
      StreamController<WearableEvent>.broadcast();
  late final StreamSubscription<dynamic> _subscription;
  _Eb1Pending? _pending;
  String? _deviceId;
  int? _nativeGeneration;
  int _session = 0;
  DeviceInfo? _details;
  DeviceCapabilities? _capabilities;

  String _languageKey(String id) =>
      'urion_time_language_${sha256.convert(utf8.encode(id))}';

  @override
  Stream<WearableEvent> get events => _events.stream;

  Future<void> dispose() async {
    await _subscription.cancel();
    await _events.close();
  }

  void _onNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    final event = WearableEvent.fromMap(Map<Object?, Object?>.from(raw));
    if (event.type == 'scanDevice') {
      _events.add(event);
      return;
    }
    if (event.type == 'disconnected') {
      final id = '${event.payload['deviceId'] ?? ''}';
      if (_deviceId != null && id == _deviceId) {
        _retireSession();
        _events.add(event);
      }
      return;
    }
    if (event.type == 'deviceDetails') {
      if ('${event.payload['id'] ?? ''}' == _deviceId) {
        _details = DeviceInfo.fromMap(event.payload);
        _events.add(event);
      }
      return;
    }
    if (event.type != 'bytes' || _deviceId == null) return;
    if (event.payload['deviceId'] != _deviceId ||
        event.payload['generation'] != _nativeGeneration) {
      return;
    }
    final bytes = event.payload['bytes'];
    if (bytes is! Uint8List && bytes is! List<int>) return;
    for (final frame in _buffer.add(
      bytes is Uint8List ? bytes : bytes as List<int>,
    )) {
      if (frame.command == 0x73 || frame.command == 0x33) {
        _events.add(const WearableEvent(type: 'healthDataReady', payload: {}));
        continue;
      }
      final pending = _pending;
      if (pending == null || pending.session != _session) continue;
      if (frame.isError && frame.command == (pending.command | 0x80)) {
        pending.fail(
          PlatformException(
            code: frame.isUnsupported
                ? 'UNSUPPORTED_DEVICE'
                : 'DEVICE_REJECTED',
            message: frame.isUnsupported ? '当前手表不支持此功能' : '手表暂时无法完成操作，请重试',
          ),
        );
        continue;
      }
      if (frame.command == pending.command) pending.accept(frame);
    }
  }

  void _retireSession() {
    _session++;
    _pending?.fail(
      PlatformException(code: 'DEVICE_DISCONNECTED', message: '手表已断开连接'),
    );
    _pending = null;
    _deviceId = null;
    _nativeGeneration = null;
    _details = null;
    _capabilities = null;
    _buffer.reset();
  }

  Future<List<Eb1Frame>> _exchange(
    int command, [
    List<int> payload = const [],
    int count = 1,
  ]) async {
    final id = _deviceId;
    if (id == null) {
      throw PlatformException(code: 'NOT_CONNECTED', message: '请先连接手表');
    }
    if (_pending != null) throw StateError('EB1 commands must be serial');
    final pending = _Eb1Pending(command, _session, count);
    _pending = pending;
    try {
      await _methods
          .invokeMethod<void>('writeFrame', {
            'bytes': Eb1Frame.request(command, payload).bytes,
          })
          .timeout(requestTimeout);
      return await pending.result.timeout(requestTimeout);
    } on TimeoutException {
      // A late response has no request identifier. Retiring this GATT session
      // is the only safe way to prevent it matching a later same-command read.
      _retireSession();
      await _methods.invokeMethod<void>('disconnect');
      _events.add(WearableEvent(
        type: 'disconnected',
        payload: {'deviceId': id},
      ));
      throw PlatformException(
        code: 'DEVICE_TIMEOUT',
        message: '手表暂时无响应，请重新连接后重试',
      );
    } finally {
      if (identical(_pending, pending)) _pending = null;
    }
  }

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    final raw = await _methods.invokeListMethod<Map<Object?, Object?>>(
      'scanDevices',
    );
    return (raw ?? const []).map(DeviceInfo.fromMap).toList(growable: false);
  }

  @override
  Future<void> stopScan() => _methods.invokeMethod<void>('stopScan');

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    _retireSession();
    final Map<Object?, Object?>? raw;
    try {
      raw = await _methods
          .invokeMapMethod<Object?, Object?>('connect', {'deviceId': deviceId})
          .timeout(connectTimeout);
    } on TimeoutException {
      _retireSession();
      await _methods.invokeMethod<void>('disconnect');
      throw PlatformException(
        code: 'CONNECT_TIMEOUT',
        message: '连接超时，请将手表靠近手机后重试',
      );
    }
    _deviceId = deviceId;
    _nativeGeneration = (raw?['generation'] as num?)?.toInt();
    if (_nativeGeneration == null) {
      await disconnect();
      throw PlatformException(code: 'CONNECT_FAILED', message: '暂时无法连接手表');
    }
    final details = await getConnectedDeviceDetails();
    if (details == null) {
      await disconnect();
      throw PlatformException(code: 'CONNECT_FAILED', message: '暂时无法连接手表');
    }
    // Notification subscription is completed by native before connect returns.
    // An EB1 read additionally verifies the byte-level session is responsive.
    try {
      final battery = (await _queue.run(() => _exchange(0x03))).single;
      final level = battery[1];
      if (level > 100) throw const FormatException('Invalid EB1 battery');
      _details = DeviceInfo(
        id: details.id,
        name: details.name,
        model: details.model,
        hardwareAddress: details.hardwareAddress,
        firmwareVersion: details.firmwareVersion,
        battery: DeviceBatteryInfo.percentage(level),
        rssi: details.rssi,
      );
      _events.add(
        WearableEvent(type: 'deviceDetails', payload: _details!.toJson()),
      );
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _retireSession();
    await _methods.invokeMethod<void>('disconnect');
  }

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async {
    if (_deviceId == null) return null;
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'getDeviceDetails',
    );
    if (raw == null || '${raw['id']}' != _deviceId) return null;
    final native = DeviceInfo.fromMap(raw);
    return _details = DeviceInfo(
      id: native.id,
      name: native.name,
      model: native.model,
      hardwareAddress: native.hardwareAddress,
      firmwareVersion: native.firmwareVersion,
      battery: _details?.battery ?? native.battery,
      rssi: native.rssi,
    );
  }

  @override
  Future<DeviceCapabilities> getCapabilities() => _queue.run(() async {
    if (_capabilities != null) return _capabilities!;
    final metrics = <HealthMetric>{};
    final features = <DeviceFeature>{};
    try {
      final daily = await _exchange(0x07, [0], 2);
      Eb1DailySnapshot.parse(daily[0], daily[1]);
      metrics.addAll({HealthMetric.steps, HealthMetric.sleep});
    } on PlatformException catch (error) {
      if (error.code != 'UNSUPPORTED_DEVICE') {
        rethrow;
      }
    }
    try {
      final screen = (await _exchange(0x1f, [1])).single;
      if (screen[1] == 1 && screen[2] >= 1 && screen[2] <= 20) {
        features.add(DeviceFeature.screenDisplay);
      }
    } on PlatformException catch (error) {
      if (error.code != 'UNSUPPORTED_DEVICE') rethrow;
    }
    final settingsReadable = <int>[];
    for (final command in [0x16, 0x2c]) {
      try {
        final answer = (await _exchange(command, [1])).single;
        if (answer[1] == 1) settingsReadable.add(command);
      } on PlatformException catch (error) {
        if (error.code != 'UNSUPPORTED_DEVICE') rethrow;
      }
    }
    if (settingsReadable.isNotEmpty) {
      features.add(DeviceFeature.healthMonitoring);
    }
    try {
      final profile = (await _exchange(0x0a, [1])).single;
      final goals = (await _exchange(0x21, [1])).single;
      if (profile[1] == 1 &&
          (profile[2] == 0 || profile[2] == 1) &&
          goals[1] == 1) {
        features.add(DeviceFeature.basicSettings);
      }
    } on PlatformException catch (error) {
      if (error.code != 'UNSUPPORTED_DEVICE') rethrow;
    }
    // A feature is visible only after a safe read confirms this firmware's
    // protocol shape. Manual starts and destructive writes are never probes.
    _capabilities = DeviceCapabilities(
      metrics: metrics,
      manualMetrics: const {},
      stoppableManualMetrics: const {},
      sportModes: const {},
      features: features,
      integratedFeatures: features,
    );
    return _capabilities!;
  });

  @override
  Future<List<HealthRecord>> syncHealthData({
    String? cursor,
  }) => _queue.run(() async {
    final packets = await _exchange(0x07, [0], 2);
    final snapshot = Eb1DailySnapshot.parse(packets[0], packets[1]);
    final today = DateTime.now();
    final watchDate = snapshot.localDate;
    final dayDistance = DateTime.utc(today.year, today.month, today.day)
        .difference(watchDate).inDays;
    final unexpectedDayIndex = snapshot.daysAgo != 0;
    final unexpectedDate = dayDistance.abs() > 1;
    final invalidDuration = snapshot.sleepMinutes > 1440 ||
        snapshot.deepMinutes > 1440 ||
        snapshot.lightMinutes > 1440;
    if (kDebugMode) {
      debugPrint(
        '[U19Sync] daily: index=${snapshot.daysAgo} '
        'dayOffset=$dayDistance',
      );
    }
    if (unexpectedDayIndex || unexpectedDate || invalidDuration) {
      if (kDebugMode) {
        debugPrint('[U19Sync] daily rejected: index=$unexpectedDayIndex '
            'date=$unexpectedDate duration=$invalidDuration');
      }
      throw const FormatException('Unverified EB1 daily data');
    }
    final id = _deviceId!;
    final observedAt = DateTime.now().toUtc();
    final localDate =
        '${snapshot.localDate.year.toString().padLeft(4, '0')}-'
        '${snapshot.localDate.month.toString().padLeft(2, '0')}-'
        '${snapshot.localDate.day.toString().padLeft(2, '0')}';
    final offset = DateTime.now().timeZoneOffset;
    final offsetMinutes = offset.inMinutes;
    final timezone =
        '${offsetMinutes < 0 ? '-' : '+'}'
        '${(offsetMinutes.abs() ~/ 60).toString().padLeft(2, '0')}:'
        '${(offsetMinutes.abs() % 60).toString().padLeft(2, '0')}';
    HealthRecord summary(
      HealthMetric metric,
      num value,
      String unit, {
      String valueKey = 'value',
    }) {
      final versionContent = '$id|$localDate|${metric.wireName}|$value';
      final hash = sha256.convert(utf8.encode(versionContent)).bytes;
      final uuidBytes = hash.take(16).toList();
      uuidBytes[6] = (uuidBytes[6] & 0x0f) | 0x50;
      uuidBytes[8] = (uuidBytes[8] & 0x3f) | 0x80;
      final hex = uuidBytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final versionId =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      return HealthRecord(
        id: versionId,
        metric: metric,
        values: {valueKey: value},
        unit: unit,
        measuredAt: observedAt,
        timezone: timezone,
        deviceId: 'urion:$id',
        firmwareVersion: _details?.firmwareVersion ?? '',
        quality: 'valid',
        source: MeasurementSource.wearable,
        origin: MeasurementOrigin.watchHistory,
        rawVersion: 1,
        aggregation: HealthAggregation.dailySummary(localDate),
      );
    }

    final result = <HealthRecord>[];
    if (snapshot.steps > 0) {
      result.add(summary(HealthMetric.steps, snapshot.steps, '步'));
    }
    if (snapshot.sleepMinutes > 0) {
      result.add(
        summary(
          HealthMetric.sleep,
          snapshot.sleepMinutes / 60,
          'h',
          valueKey: 'hours',
        ),
      );
    }
    return result;
  });

  @override
  Future<void> startMeasurement(HealthMetric metric) => _queue.run(() async {
    final command = switch (metric) {
      HealthMetric.bloodPressure => 0x32,
      HealthMetric.heartRate => 0x38,
      HealthMetric.bloodOxygen => 0x39,
      _ => throw PlatformException(
        code: 'UNSUPPORTED_DEVICE',
        message: '请在手表上操作',
      ),
    };
    // 0x32/0x38/0x39 have fourteen zero payload bytes in the EB1 spec.
    await _exchange(command);
  });

  @override
  Future<void> stopMeasurement(HealthMetric metric) async =>
      throw PlatformException(
        code: 'MEASUREMENT_STOP_UNSUPPORTED',
        message: '请在手表上结束测量',
      );

  @override
  Future<void> startSport(SportMode mode) async =>
      throw const WearableSdkNotConfigured();
  @override
  Future<void> stopSport() async => throw const WearableSdkNotConfigured();
  @override
  Future<List<SportRecord>> readSportRecords() async => const [];

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() => _queue.run(() async {
    final result = <String, bool>{};
    for (final entry in {'heartRate': 0x16, 'bloodOxygen': 0x2c}.entries) {
      try {
        final response = (await _exchange(entry.value, [1])).single;
        if (response[1] == 1 && (response[2] == 1 || response[2] == 2)) {
          result[entry.key] = response[2] == 1;
        }
      } on PlatformException catch (error) {
        if (error.code != 'UNSUPPORTED_DEVICE') rethrow;
      }
    }
    return result;
  });

  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) =>
      _queue.run(() async {
        final command = switch (type) {
          'heartRate' => 0x16,
          'bloodOxygen' => 0x2c,
          _ => throw PlatformException(
            code: 'UNSUPPORTED_DEVICE',
            message: '当前手表不支持此功能',
          ),
        };
        final before = (await _exchange(command, [1])).single;
        if (before[1] != 1) throw const FormatException('Invalid setting read');
        await _exchange(command, [2, enabled ? 1 : 2]);
        final after = (await _exchange(command, [1])).single;
        if (after[2] != (enabled ? 1 : 2)) {
          throw PlatformException(
            code: 'SETTING_NOT_CONFIRMED',
            message: '设置未生效，请重试',
          );
        }
      });

  @override
  Future<int?> readHeartRateWarning() async => null;
  @override
  Future<void> setHeartRateWarning(int value) async =>
      throw const WearableSdkNotConfigured();

  @override
  Future<Map<String, Object?>> readDeviceFeature(
    DeviceFeature feature,
  ) => _queue.run(() async {
    if (feature == DeviceFeature.basicSettings) {
      final profile = (await _exchange(0x0a, [1])).single;
      final goals = (await _exchange(0x21, [1])).single;
      if (profile[1] != 1 || goals[1] != 1) {
        throw const FormatException('Invalid EB1 settings response');
      }
      final timeLanguage = await _languageStorage.read(
        key: _languageKey(_deviceId!),
      );
      return <String, Object?>{
        'is24Hour': profile[2] == 0,
        'gender': profile[4],
        'age': profile[5],
        'heightCm': profile[6],
        'weightKg': profile[7],
        'stepGoal': eb1UnsignedLittle(goals, 2, 3),
        if (timeLanguage == 'zh' || timeLanguage == 'en')
          'timeLanguage': timeLanguage,
      };
    }
    if (feature == DeviceFeature.screenDisplay) {
      final response = (await _exchange(0x1f, [1])).single;
      if (response[1] != 1 || response[2] < 1 || response[2] > 20) {
        throw const FormatException('Invalid screen setting');
      }
      return <String, Object?>{
        'brightnessSupported': false,
        'brightness': 1,
        'maximumBrightness': 1,
        'automaticBrightness': false,
        'durationSeconds': response[2],
        'minimumDurationSeconds': 1,
        'maximumDurationSeconds': 20,
      };
    }
    if (feature == DeviceFeature.healthMonitoring) {
      final values = <String, Object?>{};
      for (final entry in {'heartRate': 0x16, 'bloodOxygen': 0x2c}.entries) {
        final response = (await _exchange(entry.value, [1])).single;
        if (response[1] == 1) values[entry.key] = response[2] == 1;
      }
      return values;
    }
    throw PlatformException(code: 'UNSUPPORTED_DEVICE', message: '当前手表不支持此功能');
  });

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    if (feature == DeviceFeature.basicSettings) {
      await _queue.run(() async {
        if (values.length != 1) {
          throw const FormatException('Only one EB1 setting may change at a time');
        }
        final entry = values.entries.single;
        if (entry.key == 'syncTime') {
          final selectedLanguage = entry.value == true
              ? await _languageStorage.read(key: _languageKey(_deviceId!))
              : entry.value;
          if (selectedLanguage != 'zh' && selectedLanguage != 'en') {
            throw const FormatException('Confirm watch language before time sync');
          }
          final now = DateTime.now();
          final response = (await _exchange(0x01, [
            eb1EncodeBcd(now.year % 100),
            eb1EncodeBcd(now.month),
            eb1EncodeBcd(now.day),
            eb1EncodeBcd(now.hour),
            eb1EncodeBcd(now.minute),
            eb1EncodeBcd(now.second),
            selectedLanguage == 'zh' ? 0 : 1,
          ])).single;
          if (response.command != 0x01) {
            throw const FormatException('Invalid EB1 time acknowledgement');
          }
          // The protocol has no clock readback. Do not claim verification.
          await _languageStorage.write(
            key: _languageKey(_deviceId!),
            value: selectedLanguage as String,
          );
          return;
        }
        if (entry.key == 'stepGoal') {
          final goal = entry.value;
          if (goal is! int || goal < 1 || goal > 0xffffff) {
            throw const FormatException('Invalid EB1 step goal');
          }
          final before = (await _exchange(0x21, [1])).single;
          if (before[1] != 1) throw const FormatException('Invalid EB1 goal read');
          final payload = before.bytes.sublist(2, 15);
          payload[0] = goal & 0xff;
          payload[1] = (goal >> 8) & 0xff;
          payload[2] = (goal >> 16) & 0xff;
          await _exchange(0x21, [2, ...payload]);
          final after = (await _exchange(0x21, [1])).single;
          if (after[1] != 1 || eb1UnsignedLittle(after, 2, 3) != goal) {
            throw PlatformException(code: 'SETTING_NOT_CONFIRMED', message: '设置未生效，请重试');
          }
          return;
        }
        final field = switch (entry.key) {
          'is24Hour' => 2,
          'gender' => 4,
          'age' => 5,
          'heightCm' => 6,
          'weightKg' => 7,
          _ => throw const FormatException('Unsupported EB1 setting'),
        };
        final value = entry.key == 'is24Hour'
            ? (entry.value == true ? 0 : 1)
            : entry.value;
        if (value is! int || value < 0 || value > 255 ||
            (entry.key == 'gender' && value > 1) ||
            (entry.key == 'age' && (value < 1 || value > 120)) ||
            (entry.key == 'heightCm' && (value < 50 || value > 240)) ||
            (entry.key == 'weightKg' && (value < 10 || value > 250))) {
          throw const FormatException('Invalid EB1 profile value');
        }
        final before = (await _exchange(0x0a, [1])).single;
        if (before[1] != 1) throw const FormatException('Invalid EB1 profile read');
        final payload = before.bytes.sublist(2, 10);
        payload[field - 2] = value;
        await _exchange(0x0a, [2, ...payload]);
        final after = (await _exchange(0x0a, [1])).single;
        if (after[1] != 1 || after[field] != value) {
          throw PlatformException(code: 'SETTING_NOT_CONFIRMED', message: '设置未生效，请重试');
        }
      });
      return;
    }
    if (feature == DeviceFeature.screenDisplay) {
      final value = values['durationSeconds'];
      if (value is! num || value.toInt() < 1 || value.toInt() > 20) {
        throw const FormatException('Invalid screen timeout');
      }
      await _queue.run(() async {
        final before = (await _exchange(0x1f, [1])).single;
        if (before[1] != 1) throw const FormatException('Invalid setting read');
        await _exchange(0x1f, [2, value.toInt()]);
        final after = (await _exchange(0x1f, [1])).single;
        if (after[2] != value.toInt()) {
          throw PlatformException(
            code: 'SETTING_NOT_CONFIRMED',
            message: '设置未生效，请重试',
          );
        }
      });
      return;
    }
    if (feature == DeviceFeature.healthMonitoring) {
      for (final entry in values.entries) {
        if (entry.value is bool) {
          await setAutoMeasureSetting(entry.key, entry.value == true);
        }
      }
      return;
    }
    throw PlatformException(code: 'UNSUPPORTED_DEVICE', message: '当前手表不支持此功能');
  }

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {
    if (feature != DeviceFeature.findWatch || !enabled) {
      throw PlatformException(
        code: 'UNSUPPORTED_DEVICE',
        message: '当前手表不支持此功能',
      );
    }
    await _queue.run(() => _exchange(0x50, [0x55, 0xaa]));
  }
}

class _Eb1Pending {
  _Eb1Pending(this.command, this.session, this.count) {
    // A native write can fail before _exchange begins awaiting the response.
    // Register an error listener now so retiring that session is never an
    // unhandled asynchronous exception.
    unawaited(_completer.future.catchError((Object _) => <Eb1Frame>[]));
  }

  final int command;
  final int session;
  final int count;
  final Completer<List<Eb1Frame>> _completer = Completer<List<Eb1Frame>>();
  final List<Eb1Frame> _frames = [];

  Future<List<Eb1Frame>> get result => _completer.future;

  void accept(Eb1Frame frame) {
    if (_completer.isCompleted) return;
    if (count > 1 && frame[1] != _frames.length) {
      fail(const FormatException('Out-of-order EB1 response'));
      return;
    }
    _frames.add(frame);
    if (_frames.length == count) _completer.complete(_frames);
  }

  void fail(Object error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }
}
