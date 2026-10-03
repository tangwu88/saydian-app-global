import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

import '../domain/feature_models.dart';
import '../domain/ecg_waveform.dart';
import '../domain/models.dart';
import 'global_storage_scope.dart';
import 'wearable_bridge.dart';
import 'wearable_routing.dart';
import 'yucheng_payload_mapper.dart';
import 'yucheng_product_client.dart';

class YuchengWearableBridge
    implements
        WearableBridge,
        WearableDeviceDetailsBridge,
        WearableSportPauseBridge,
        WearableConnectionRecoveryBridge {
  YuchengWearableBridge({
    YuchengProductClient? client,
    this.healthReadTimeout = const Duration(seconds: 8),
    this.ecgMeasurementDuration = const Duration(seconds: 60),
    this.initialHealthSettleDelay = const Duration(seconds: 3),
    this.capabilityRetryDelay = const Duration(milliseconds: 500),
    this.deviceInfoSettleDelay = const Duration(seconds: 2),
    this.deviceInfoReadTimeout = const Duration(seconds: 3),
    this.deviceInfoRetryDelay = const Duration(milliseconds: 500),
    YuchengSavedDeviceStore? savedDeviceStore,
  }) : _client = client ?? PluginYuchengProductClient(),
       _savedDeviceStore =
           savedDeviceStore ?? const SecureYuchengSavedDeviceStore();
  final YuchengProductClient _client;
  final YuchengSavedDeviceStore _savedDeviceStore;
  final Duration healthReadTimeout;
  final Duration ecgMeasurementDuration;
  final Duration initialHealthSettleDelay;
  final Duration capabilityRetryDelay;
  final Duration deviceInfoSettleDelay;
  final Duration deviceInfoReadTimeout;
  final Duration deviceInfoRetryDelay;
  final _events = StreamController<WearableEvent>.broadcast();
  bool _initialized = false;
  String? _deviceId;
  String _firmware = '';
  String? _hardwareAddress;
  DeviceBatteryInfo? _battery;
  Future<void>? _deviceInfoLoad;
  int _connectionGeneration = 0;
  DeviceCapabilities? _capabilities;
  Future<DeviceCapabilities>? _capabilityLoad;
  final Map<String, String> _scannedNames = {};
  final Map<String, String> _scannedHardwareAddresses = {};
  bool _needsInitialHealthSettle = false;
  bool _capabilitiesResolved = false;
  HealthMetric? _activeMeasurementMetric;
  DateTime? _measurementStartedAt;
  int? _activeSportType;
  Timer? _ecgTimer;
  int _ecgGeneration = 0;
  int? _ecgRate;
  bool _ecgFinishing = false;
  final List<num> _ecgSamples = [];
  final Map<String, num> _ecgValues = {};

  @override
  Stream<WearableEvent> get events => _events.stream;

  Future<void> _initialize() async {
    if (_initialized) return;
    // The vendor's automatic reconnect can establish a hidden GATT session
    // before this bridge knows the device identifier. The bound watch then
    // disappears from scans while the UI still reports it as disconnected.
    // Keep connection ownership in the app so native and visible state agree.
    await _client.initialize(reconnectEnabled: false, logEnabled: false);
    _client.events.listen(_handleEvent);
    _initialized = true;
  }

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    await _initialize();
    final devices = (await _client.scan())
        .map(
          (row) => DeviceInfo(
            id: '${row['identifier'] ?? ''}',
            name: '${row['name'] ?? ''}',
            rssi: (row['rssi'] as num?)?.toInt(),
            hardwareAddress: row['hardwareAddress']?.toString(),
            firmwareVersion: row['firmwareVersion']?.toString(),
          ),
        )
        .where((d) => d.id.isNotEmpty)
        .toList();
    _scannedNames
      ..clear()
      ..addEntries(devices.map((device) => MapEntry(device.id, device.name)));
    _scannedHardwareAddresses
      ..clear()
      ..addEntries(
        devices
            .where(
              (device) => device.hardwareAddress?.trim().isNotEmpty ?? false,
            )
            .map(
              (device) => MapEntry(device.id, device.hardwareAddress!.trim()),
            ),
      );
    return devices;
  }

  @override
  Future<void> stopScan() async {
    await _initialize();
    await _client.stopScan();
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    await _initialize();
    final scannedName = _scannedNames[deviceId] ?? '';
    if (!YuchengDeviceClassifier.matches(scannedName)) {
      throw PlatformException(
        code: 'YUCHENG_MODEL_MISMATCH',
        message: '此设备暂时无法连接，请选择赛电手表',
      );
    }
    _invalidateDeviceSession();
    final connected = await _client
        .connect(deviceId)
        .timeout(const Duration(seconds: 30), onTimeout: () => false);
    if (!connected) {
      throw PlatformException(
        code: 'YUCHENG_CONNECT_FAILED',
        message: '连接失败，请将手表靠近手机后重试',
      );
    }
    await _rememberDevice(
      deviceId: deviceId,
      name: scannedName,
      hardwareAddress: _scannedHardwareAddresses[deviceId],
    );
    // The plugin starts its own model/MCU/feature queries when BLE reaches the
    // ready state. Issuing another model and setup sequence here can leave its
    // native command queue waiting forever. BLE authentication is therefore
    // the connection boundary; optional metadata is loaded separately.
    final generation = ++_connectionGeneration;
    _deviceId = deviceId;
    _hardwareAddress = _scannedHardwareAddresses[deviceId];
    _capabilities = null;
    _capabilitiesResolved = false;
    _needsInitialHealthSettle = true;
    unawaited(_publishCapabilitiesWhenReady());
    unawaited(_loadDeviceInfo(generation, deviceId, publish: true));
  }

  @override
  Future<void> disconnect() async {
    _invalidateDeviceSession();
    try {
      await _client.disconnect();
    } finally {
      try {
        await _savedDeviceStore.clear();
      } catch (_) {
        // Disconnect is already complete; storage cleanup is best-effort.
      }
    }
  }

  @override
  Future<DeviceInfo?> restoreConnection({
    required WearableUserProfile profile,
  }) async {
    await _initialize();
    YuchengSavedDevice? saved;
    try {
      saved = await _savedDeviceStore.read();
    } catch (_) {
      return null;
    }
    if (saved == null ||
        saved.identifier.trim().isEmpty ||
        !YuchengDeviceClassifier.matches(saved.name)) {
      return null;
    }
    _invalidateDeviceSession();
    final connected = await _client
        .connectSaved(
          identifier: saved.identifier,
          name: saved.name,
          hardwareAddress: saved.hardwareAddress,
        )
        .timeout(const Duration(seconds: 30), onTimeout: () => false);
    if (!connected) return null;
    _scannedNames[saved.identifier] = saved.name;
    final hardwareAddress = saved.hardwareAddress?.trim();
    if (hardwareAddress != null && hardwareAddress.isNotEmpty) {
      _scannedHardwareAddresses[saved.identifier] = hardwareAddress;
    }
    final generation = ++_connectionGeneration;
    _deviceId = saved.identifier;
    _capabilities = null;
    _capabilitiesResolved = false;
    _needsInitialHealthSettle = true;
    unawaited(_publishCapabilitiesWhenReady());
    unawaited(_loadDeviceInfo(generation, saved.identifier, publish: true));
    return _deviceDetails();
  }

  Future<void> _rememberDevice({
    required String deviceId,
    required String name,
    String? hardwareAddress,
  }) async {
    try {
      await _savedDeviceStore.write(
        YuchengSavedDevice(
          identifier: deviceId,
          name: name,
          hardwareAddress: hardwareAddress,
        ),
      );
    } catch (_) {
      // A storage failure must not turn a successful BLE connection into an
      // apparent connection failure. The next launch will simply rescan.
    }
  }

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails({
    bool forceRefresh = false,
  }) async {
    final deviceId = _deviceId;
    if (deviceId == null) return null;
    final generation = _connectionGeneration;
    final updatedAt = _battery?.updatedAt;
    final isFresh =
        updatedAt != null &&
        DateTime.now().toUtc().difference(updatedAt) <
            const Duration(minutes: 5);
    if (forceRefresh || !isFresh) {
      await _loadDeviceInfo(generation, deviceId, publish: false);
    }
    if (!_isCurrentDeviceSession(generation, deviceId)) return null;
    final name = _scannedNames[deviceId] ?? '赛电手表';
    return DeviceInfo(
      id: deviceId,
      name: name,
      model: name,
      hardwareAddress: _hardwareAddress ?? _scannedHardwareAddresses[deviceId],
      firmwareVersion: _firmware.isEmpty ? null : _firmware,
      battery: _battery,
      batteryPercent: _battery?.percent,
    );
  }

  Future<void> _loadDeviceInfo(
    int generation,
    String deviceId, {
    required bool publish,
  }) async {
    if (!_isCurrentDeviceSession(generation, deviceId)) return;
    final activeLoad = _deviceInfoLoad;
    if (activeLoad != null) {
      await activeLoad;
      return;
    }
    late final Future<void> load;
    load = _readDeviceInfo(generation, deviceId, publish: publish);
    _deviceInfoLoad = load;
    try {
      await load;
    } finally {
      if (identical(_deviceInfoLoad, load)) _deviceInfoLoad = null;
    }
  }

  Future<void> _readDeviceInfo(
    int generation,
    String deviceId, {
    required bool publish,
  }) async {
    if (deviceInfoSettleDelay > Duration.zero) {
      await Future<void>.delayed(deviceInfoSettleDelay);
    }
    await _readHardwareAddress(generation, deviceId);
    for (var attempt = 0; attempt < 4; attempt += 1) {
      if (!_isCurrentDeviceSession(generation, deviceId)) return;
      try {
        final result = await _client.basicInfo().timeout(deviceInfoReadTimeout);
        if (!_isCurrentDeviceSession(generation, deviceId)) return;
        final info = result.data;
        if (result.status == 0 && info != null) {
          final firmware = info.firmwareVersion.trim();
          if (firmware.isNotEmpty) _firmware = firmware;
          if (info.batteryPercent >= 0 && info.batteryPercent <= 100) {
            _battery = DeviceBatteryInfo(
              value: info.batteryPercent,
              scale: 100,
              isPercent: true,
              low: info.batteryStatus == 1,
              chargeState: switch (info.batteryStatus) {
                0 || 1 => DeviceBatteryChargeState.normal,
                2 => DeviceBatteryChargeState.charging,
                3 => DeviceBatteryChargeState.full,
                _ => DeviceBatteryChargeState.unknown,
              },
              updatedAt: DateTime.now().toUtc(),
            );
          }
          if (publish && _isCurrentDeviceSession(generation, deviceId)) {
            _events.add(
              WearableEvent(
                type: 'deviceDetails',
                payload: _deviceDetails().toJson(),
              ),
            );
          }
          return;
        }
        if (result.status == 2) return;
      } catch (_) {
        // Device information can share the vendor command queue with the
        // post-connect feature handshake. Retry without clearing an older
        // valid value, and never guess a percentage from another field.
      }
      if (attempt < 3 && deviceInfoRetryDelay > Duration.zero) {
        await Future<void>.delayed(deviceInfoRetryDelay);
      }
    }
  }

  Future<void> _readHardwareAddress(int generation, String deviceId) async {
    if (_hardwareAddress != null ||
        !_isCurrentDeviceSession(generation, deviceId)) {
      return;
    }
    try {
      final result = await _client.macAddress().timeout(deviceInfoReadTimeout);
      if (result.status != 0 ||
          !_isCurrentDeviceSession(generation, deviceId)) {
        return;
      }
      final address = _normalizeHardwareAddress(result.data);
      if (address == null) return;
      _hardwareAddress = address;
      _scannedHardwareAddresses[deviceId] = address;
    } catch (_) {
      // iOS scan results often omit the vendor MAC. Keep the CoreBluetooth
      // identifier as a transparent fallback when the explicit query fails.
    }
  }

  static String? _normalizeHardwareAddress(Object? raw) {
    final separated = '${raw ?? ''}'.trim().replaceAll('-', ':').toUpperCase();
    if (RegExp(r'^(?:[0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(separated)) {
      return separated;
    }
    final compact = separated.replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (compact.length != 12) return null;
    return List.generate(
      6,
      (index) => compact.substring(index * 2, index * 2 + 2),
    ).join(':');
  }

  DeviceInfo _deviceDetails() {
    final deviceId = _connectedId;
    final name = _scannedNames[deviceId] ?? '赛电手表';
    return DeviceInfo(
      id: deviceId,
      name: name,
      model: name,
      hardwareAddress: _hardwareAddress ?? _scannedHardwareAddresses[deviceId],
      firmwareVersion: _firmware.isEmpty ? null : _firmware,
      battery: _battery,
      batteryPercent: _battery?.percent,
    );
  }

  bool _isCurrentDeviceSession(int generation, String deviceId) =>
      _connectionGeneration == generation && _deviceId == deviceId;

  void _invalidateDeviceSession() {
    _retireEcg();
    _connectionGeneration += 1;
    _deviceId = null;
    _firmware = '';
    _hardwareAddress = null;
    _battery = null;
    _deviceInfoLoad = null;
    _capabilities = null;
    _capabilityLoad = null;
    _capabilitiesResolved = false;
    _needsInitialHealthSettle = false;
    _activeMeasurementMetric = null;
    _measurementStartedAt = null;
    _activeSportType = null;
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async {
    _connectedId;
    if (_capabilitiesResolved && _capabilities != null) return _capabilities!;
    final activeLoad = _capabilityLoad;
    if (activeLoad != null) return activeLoad;
    final load = _readCapabilities();
    _capabilityLoad = load;
    try {
      return await load;
    } finally {
      if (identical(_capabilityLoad, load)) _capabilityLoad = null;
    }
  }

  Future<DeviceCapabilities> _readCapabilities() async {
    // W8/JL reports the BLE connection before its device-info and watch-face
    // handshake has finished. Keep retrying through that real-device window;
    // the native failure response is safe after the Android patch below.
    for (var attempt = 0; attempt < 12; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(capabilityRetryDelay);
      }
      try {
        final flags = await _client.capabilities().timeout(
          const Duration(seconds: 2),
        );
        final reported = YuchengPayloadMapper.capabilities(flags);
        if (reported.metrics.isNotEmpty || reported.features.isNotEmpty) {
          _capabilities = reported;
          _capabilitiesResolved = true;
          return reported;
        }
      } catch (_) {
        // The device may still be completing its feature handshake.
      }
    }
    throw PlatformException(
      code: 'CAPABILITIES_UNAVAILABLE',
      message: '暂时无法读取此手表的功能',
    );
  }

  Future<void> _publishCapabilitiesWhenReady() async {
    try {
      final reported = await getCapabilities();
      if (_deviceId == null || _events.isClosed) return;
      _events.add(
        WearableEvent(type: 'capabilitiesUpdated', payload: reported.toJson()),
      );
    } catch (_) {
      // The page keeps a retry action; no guessed capability is published.
    }
  }

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    final id = _connectedId;
    if (_needsInitialHealthSettle) {
      _needsInitialHealthSettle = false;
      // Yuc/JL finishes its device-info handshake shortly after BLE reports
      // ready. Keep this vendor-specific delay inside the Yuc bridge so Vep
      // devices and unrelated UI flows are never held back.
      await Future<void>.delayed(initialHealthSettleDelay);
      if (_deviceId != id) {
        throw PlatformException(code: 'CONNECTION_DROPPED', message: '设备连接已断开');
      }
    }
    final rows = <int, List<Map<String, Object?>>>{};
    for (final type in [
      YuchengHealthDataType.step,
      YuchengHealthDataType.sleep,
      YuchengHealthDataType.heartRate,
      YuchengHealthDataType.bloodPressure,
      YuchengHealthDataType.combined,
    ]) {
      final result = await _client
          .health(type)
          .timeout(
            healthReadTimeout,
            onTimeout: () => throw PlatformException(
              code: 'YUCHENG_SYNC_TIMEOUT',
              message: '手表数据读取超时，请稍后重试',
            ),
          );
      if (result.status == 0) {
        rows[type] = result.data ?? const [];
      } else if (result.status != 2) {
        _require(result);
      }
    }
    return YuchengPayloadMapper.healthRecords(
      deviceId: id,
      firmwareVersion: _firmware,
      rowsByType: rows,
    );
  }

  static const _measurements = {
    HealthMetric.heartRate: YuchengMeasurementType.heartRate,
    HealthMetric.bloodPressure: YuchengMeasurementType.bloodPressure,
    HealthMetric.bloodOxygen: YuchengMeasurementType.bloodOxygen,
    HealthMetric.bodyTemperature: YuchengMeasurementType.bodyTemperature,
    HealthMetric.bloodGlucose: YuchengMeasurementType.bloodGlucose,
  };
  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    _connectedId;
    if (metric == HealthMetric.ecg) {
      await _startEcg();
      return;
    }
    final type = _measurements[metric];
    if (type == null) throw _unsupported();
    _activeMeasurementMetric = metric;
    _measurementStartedAt = DateTime.now().toUtc();
    try {
      _require(await _client.measure(enabled: true, type: type));
    } catch (_) {
      _activeMeasurementMetric = null;
      _measurementStartedAt = null;
      rethrow;
    }
  }

  @override
  Future<void> stopMeasurement(HealthMetric metric) async {
    _connectedId;
    if (metric == HealthMetric.ecg) {
      final client = _client;
      if (client is! YuchengEcgClient) throw _unsupported();
      _retireEcg();
      _activeMeasurementMetric = null;
      _measurementStartedAt = null;
      _require(await (client as YuchengEcgClient).stopEcg());
      return;
    }
    final type = _measurements[metric];
    if (type == null) throw _unsupported();
    if (_activeMeasurementMetric == metric) {
      _activeMeasurementMetric = null;
      _measurementStartedAt = null;
    }
    _require(await _client.measure(enabled: false, type: type));
  }

  void _retireEcg() {
    _ecgGeneration++;
    _ecgTimer?.cancel();
    _ecgTimer = null;
    _ecgFinishing = false;
    _ecgRate = null;
    _ecgSamples.clear();
    _ecgValues.clear();
  }

  Future<void> _startEcg() async {
    final client = _client;
    if (client is! YuchengEcgClient) throw _unsupported();
    if (_activeMeasurementMetric != null) throw _unsupported('请先结束当前测量');
    _retireEcg();
    final generation = _ecgGeneration;
    final connection = _connectionGeneration;
    final deviceId = _connectedId;
    final ecg = client as YuchengEcgClient;
    bool current() =>
        generation == _ecgGeneration &&
        _isCurrentDeviceSession(connection, deviceId);
    try {
      final rate = await ecg.ecgSampleRate().timeout(deviceInfoReadTimeout);
      if (!current()) return;
      if (rate.status == 0) _ecgRate = rate.data;
    } catch (_) {
      // Keep a real recording locally if firmware omits timing metadata.
    }
    if (!current()) return;
    _activeMeasurementMetric = HealthMetric.ecg;
    _measurementStartedAt = DateTime.now().toUtc();
    try {
      _require(await ecg.startEcg().timeout(healthReadTimeout));
      if (!current()) return;
      _ecgTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!current() || _activeMeasurementMetric != HealthMetric.ecg) return;
        final elapsed = DateTime.now().toUtc().difference(
          _measurementStartedAt!,
        );
        if (elapsed >= ecgMeasurementDuration) {
          unawaited(_completeEcg(generation));
        } else {
          _publishEcgProgress();
        }
      });
    } catch (_) {
      if (current()) {
        _retireEcg();
        _activeMeasurementMetric = null;
        _measurementStartedAt = null;
      }
      rethrow;
    }
  }

  void _publishEcgProgress({List<num> samples = const [], bool? contact}) {
    final start = _measurementStartedAt;
    if (start == null) return;
    _events.add(
      WearableEvent(
        type: 'measurementProgress',
        payload: {
          'metric': 'ecg',
          'progress':
              (DateTime.now().toUtc().difference(start).inMilliseconds *
                      100 /
                      ecgMeasurementDuration.inMilliseconds)
                  .round()
                  .clamp(0, 99),
          if (_ecgRate != null) 'frequency': _ecgRate,
          if (samples.isNotEmpty) 'samples': samples,
          if (contact != null) 'wear': contact ? 0 : 1,
        },
      ),
    );
  }

  bool _handleEcgEvent(Map<String, Object?> event) {
    if (_activeMeasurementMetric != HealthMetric.ecg) return false;
    if (_ecgFinishing) {
      return event.keys.any(
        (k) =>
            k.startsWith('deviceRealECG') ||
            k == 'deviceRealBloodPressure' ||
            k == 'deviceEndECG' ||
            k == 'appECGPPGStatus',
      );
    }
    final type = '${event['type'] ?? event['eventType'] ?? ''}';
    final filtered =
        event['deviceRealECGFilteredData'] ??
        (type == 'deviceRealECGFilteredData' ? event['data'] : null);
    if (filtered is List) {
      // Vendor-filtered voltage samples; raw ADC packets are never substituted.
      if (filtered.isNotEmpty &&
          filtered.every((v) => v is num && v.isFinite)) {
        final samples = filtered.cast<num>();
        if (_ecgSamples.length + samples.length <= 1000000) {
          _ecgSamples.addAll(samples);
          _publishEcgProgress(samples: samples);
        }
      }
      return true;
    }
    final blood =
        event['deviceRealBloodPressure'] ??
        (type == 'deviceRealBloodPressure' ? event['data'] : null);
    if (blood is Map) {
      final hr = _number(blood['heartRate']);
      final hrv = _number(blood['hrv']);
      if (hr != null && hr >= 30 && hr <= 210) {
        _ecgValues['meanHeartRate'] = hr;
      }
      if (hrv != null && hrv > 0 && hrv <= 250) {
        _ecgValues['hrv'] = hrv;
      }
      return true;
    }
    final hrv = _number(event['deviceRealECGAlgorithmHRV']);
    if (hrv != null && hrv > 0 && hrv <= 250) {
      _ecgValues['hrv'] = hrv;
      return true;
    }
    final contact = event['appECGPPGStatus'];
    if (contact is Map) {
      _publishEcgProgress();
      return true;
    }
    if (event.containsKey('deviceEndECG') || type == 'deviceEndECG') {
      unawaited(_completeEcg(_ecgGeneration));
      return true;
    }
    return event.containsKey('deviceRealECGData') ||
        type == 'deviceRealECGData';
  }

  Future<void> _completeEcg(int generation) async {
    final start = _measurementStartedAt;
    final deviceId = _deviceId;
    final connection = _connectionGeneration;
    if (_ecgFinishing ||
        generation != _ecgGeneration ||
        start == null ||
        deviceId == null ||
        _activeMeasurementMetric != HealthMetric.ecg) {
      return;
    }
    _ecgFinishing = true;
    _ecgTimer?.cancel();
    final client = _client as YuchengEcgClient;
    bool current() =>
        generation == _ecgGeneration &&
        _isCurrentDeviceSession(connection, deviceId) &&
        _activeMeasurementMetric == HealthMetric.ecg;
    try {
      _require(await client.stopEcg().timeout(healthReadTimeout));
      if (!current()) return;
      try {
        final result = await client.ecgResult().timeout(healthReadTimeout);
        if (!current()) return;
        if (result.status == 0) {
          for (final e in (result.data ?? const <String, num>{}).entries) {
            if (e.value.isFinite) _ecgValues[e.key] = e.value;
          }
        }
      } catch (_) {
        // Live SDK objective values remain usable if analysis is unavailable.
      }
      if (!current()) return;
      if (_ecgRate == null) {
        try {
          final rate = await client.ecgSampleRate().timeout(
            deviceInfoReadTimeout,
          );
          if (!current()) return;
          if (rate.status == 0) _ecgRate = rate.data;
        } catch (_) {}
      }
      if (!current()) return;
      final now = DateTime.now();
      final usableWaveform =
          _ecgRate != null &&
          hasUsableEcgSignal(_ecgSamples, sampleFrequency: _ecgRate!);
      final record = HealthRecord(
        id: 'yc-ecg-${start.microsecondsSinceEpoch}',
        metric: HealthMetric.ecg,
        values: {
          ..._ecgValues,
          'sampleFrequency': ?_ecgRate,
          'durationSeconds':
              now.toUtc().difference(start).inMilliseconds / 1000,
        },
        unit: '',
        measuredAt: now.toUtc(),
        timezone: _timezoneOffset(now.timeZoneOffset),
        deviceId: deviceId,
        firmwareVersion: _firmware,
        quality: _ecgRate != null && !usableWaveform
            ? 'suspect'
            : 'device_reported',
        source: MeasurementSource.wearable,
        origin: MeasurementOrigin.appMeasurement,
        rawVersion: usableWaveform ? 2 : 1,
        samples: List<num>.of(_ecgSamples),
      );
      _activeMeasurementMetric = null;
      _measurementStartedAt = null;
      _retireEcg();
      _events.add(
        WearableEvent(
          type: 'healthRecord',
          payload: {
            ...record.toJson(),
            'measurementStartedAt': start.toIso8601String(),
          },
        ),
      );
    } catch (_) {
      if (!current()) return;
      _retireEcg();
      _activeMeasurementMetric = null;
      _measurementStartedAt = null;
      _events.add(
        const WearableEvent(
          type: 'error',
          payload: {'code': 'ECG_MEASUREMENT_FAILED', 'message': '心电测量未完成，请重试'},
        ),
      );
    }
  }

  static const _sports = {
    SportMode.running: 0x0F,
    SportMode.walking: 0x10,
    SportMode.cycling: 0x03,
    SportMode.hiking: 0x1B,
    SportMode.mountaineering: 0x0B,
  };
  @override
  Future<void> startSport(SportMode mode) async {
    _connectedId;
    final type = _sports[mode];
    if (type == null) throw _unsupported();
    _require(await _client.sport(state: YuchengSportState.start, type: type));
    _activeSportType = type;
  }

  @override
  Future<void> stopSport() async {
    _connectedId;
    _require(
      await _client.sport(
        state: YuchengSportState.stop,
        type: _activeSportType ?? 0,
      ),
    );
    _activeSportType = null;
  }

  @override
  Future<void> pauseSport() async {
    _connectedId;
    final type = _activeSportType;
    if (_capabilities?.supportsSportPause != true || type == null) {
      throw _unsupported('当前手表不支持暂停运动');
    }
    _require(await _client.sport(state: YuchengSportState.pause, type: type));
  }

  @override
  Future<void> resumeSport() async {
    _connectedId;
    final type = _activeSportType;
    if (_capabilities?.supportsSportPause != true || type == null) {
      throw _unsupported('当前手表不支持暂停运动');
    }
    _require(await _client.sport(state: YuchengSportState.resume, type: type));
  }

  @override
  Future<List<SportRecord>> readSportRecords() async {
    _connectedId;
    final r = await _client.health(YuchengHealthDataType.sportHistory);
    _require(r);
    return YuchengPayloadMapper.sportRecords(r.data ?? const []);
  }

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async =>
      throw _unsupported();
  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) async {
    _connectedId;
    if (type != 'heart_rate') throw _unsupported();
    _require(await _client.setHealthMonitoring(enabled));
  }

  @override
  Future<int?> readHeartRateWarning() async => throw _unsupported();
  @override
  Future<void> setHeartRateWarning(int value) async {
    _connectedId;
    _require(await _client.setHeartRateAlarm(value));
  }

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    _connectedId;
    if (feature != DeviceFeature.watchFaces) {
      throw _unsupported();
    }
    final result = await _client.watchFaces();
    _require(result);
    return <String, Object?>{
      'items': result.data ?? const <Map<String, Object?>>[],
      // The Vep online catalogue uses another binary/profile protocol. Keep
      // it hidden until a Yuc-compatible catalogue is configured.
      'onlineMarketSupported': false,
      'source': 'Yuc',
    };
  }

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    _connectedId;
    if (feature != DeviceFeature.watchFaces ||
        values['operation'] != 'switch') {
      throw _unsupported();
    }
    final dialId = int.tryParse('${values['id'] ?? values['index'] ?? ''}');
    if (dialId == null) {
      throw PlatformException(code: 'INVALID_ARGUMENT', message: '表盘标识无效');
    }
    _require(await _client.changeWatchFace(dialId));
  }

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {
    _connectedId;
    if (feature == DeviceFeature.findWatch) {
      // Yucheng exposes findDevice as a one-shot reminder, not a persistent
      // mode. The UI's stop action must therefore be a local state reset;
      // calling the SDK again would make the watch ring a second time.
      if (!enabled) return;
      _require(await _client.findDevice());
    } else if (feature == DeviceFeature.camera) {
      _require(await _client.camera(enabled));
    } else {
      throw _unsupported();
    }
  }

  String get _connectedId =>
      _deviceId ??
      (throw PlatformException(code: 'NOT_CONNECTED', message: '请先连接手表'));
  void _require(YuchengOperationResult<Object?> result) {
    if (result.status == 2) throw _unsupported();
    if (result.status != 0) {
      throw PlatformException(
        code: 'YUCHENG_OPERATION_FAILED',
        message: '手表操作失败，请稍后重试',
      );
    }
  }

  static PlatformException _unsupported([String message = '请在手表上操作']) =>
      PlatformException(code: 'FEATURE_UNSUPPORTED', message: message);

  void _handleEvent(Map<String, Object?> event) {
    if (_handleEcgEvent(event)) return;
    const nativeEventTypes = <String>{
      'bluetoothStateChange',
      'deviceRealHeartRate',
      'deviceRealBloodPressure',
      'deviceRealBloodOxygen',
      'deviceRealTemperature',
      'deviceRealBloodGlucose',
      'deviceRealHRV',
      'deviceHealthDataMeasureStateChange',
      'deviceSportStateChange',
      'deviceRealSport',
      'deviceControlPhotoStateChange',
      'deviceWatchFaceChange',
      'deviceJieLiWatchFaceChange',
    };
    final declaredType = '${event['type'] ?? event['eventType'] ?? ''}';
    final type = declaredType.isNotEmpty
        ? declaredType
        : event.keys.cast<String?>().firstWhere(
                nativeEventTypes.contains,
                orElse: () => null,
              ) ??
              '';
    final rawPayload = event['data'] ?? event[type];
    final payload = rawPayload is Map
        ? rawPayload.map((k, v) => MapEntry('$k', v))
        : <String, Object?>{'value': rawPayload};
    final bluetoothState = payload['state'] ?? payload['value'];
    if (type == 'bluetoothStateChange' && bluetoothState == 4) {
      // Invalidate pending basic-info reads before forwarding the disconnect.
      // A late callback from the old W8 must never populate the next watch's
      // battery value.
      _invalidateDeviceSession();
    }
    if (type == 'deviceHealthDataMeasureStateChange') {
      _handleMeasurementState(payload);
      return;
    }
    final mapped = switch (type) {
      'bluetoothStateChange' => WearableEvent(
        type: bluetoothState == 4 ? 'disconnected' : 'state',
        payload: {'value': bluetoothState == 2 ? 'ready' : 'connecting'},
      ),
      'deviceRealHeartRate' => _liveHealthRecord(HealthMetric.heartRate, {
        'value': _number(payload['value']),
      }),
      'deviceRealBloodPressure' =>
        _liveHealthRecord(HealthMetric.bloodPressure, {
          'systolic': _number(payload['systolicBloodPressure']),
          'diastolic': _number(payload['diastolicBloodPressure']),
          'pulse': _number(payload['heartRate']),
        }),
      'deviceRealBloodOxygen' => _liveHealthRecord(HealthMetric.bloodOxygen, {
        'value': _number(payload['value']),
      }),
      'deviceRealTemperature' => _liveHealthRecord(
        HealthMetric.bodyTemperature,
        {'value': _number(payload['value'])},
      ),
      'deviceRealBloodGlucose' => _liveHealthRecord(HealthMetric.bloodGlucose, {
        'value': _number(payload['value']),
      }),
      'deviceRealHRV' => _liveHealthRecord(HealthMetric.hrv, {
        'value': _number(payload['value']),
      }),
      'deviceSportStateChange' => _sportStateEvent(payload),
      'deviceRealSport' => _sportDataEvent(payload),
      'deviceControlPhotoStateChange' when _isPhotoCaptureState(payload) =>
        WearableEvent(type: 'cameraShutter', payload: payload),
      'deviceWatchFaceChange' || 'deviceJieLiWatchFaceChange' => WearableEvent(
        type: 'deviceFeatureProgress',
        payload: {'feature': 'watch_faces', ...payload},
      ),
      _ => null,
    };
    if (mapped != null) {
      _events.add(mapped);
      final recordMetric = HealthMetric.fromWire('${mapped.payload['type']}');
      if (mapped.type == 'healthRecord' &&
          _activeMeasurementMetric == recordMetric) {
        _activeMeasurementMetric = null;
        _measurementStartedAt = null;
      }
    }
  }

  static bool _isPhotoCaptureState(Map<String, Object?> payload) {
    final raw = payload['value'] ?? payload['state'] ?? payload['index'];
    if (raw is num) return raw.toInt() == 2;
    final normalized = '${raw ?? ''}'.trim().toLowerCase();
    return normalized == '2' ||
        normalized == 'photo' ||
        normalized == 'take_photo';
  }

  WearableEvent _sportStateEvent(Map<String, Object?> payload) {
    final state = _number(payload['state'] ?? payload['value'])?.toInt() ?? -1;
    final type = _number(payload['sportType'])?.toInt();
    if (state == YuchengSportState.stop) {
      _activeSportType = null;
    } else if (type != null && type > 0) {
      _activeSportType = type;
    }
    final mode = _modeForSportType(type);
    final eventPayload = <String, Object?>{
      'value': switch (state) {
        YuchengSportState.stop => 'stopped',
        YuchengSportState.pause => 'paused',
        _ => 'running',
      },
      'state': state,
    };
    if (type != null) eventPayload['sportType'] = type;
    if (mode != null) eventPayload['mode'] = mode.wireName;
    return WearableEvent(type: 'sportState', payload: eventPayload);
  }

  static WearableEvent _sportDataEvent(Map<String, Object?> payload) {
    final normalized = <String, Object?>{};
    void add(String key, Object? raw) {
      final value = _number(raw);
      if (value != null && value.isFinite && value >= 0) {
        normalized[key] = value;
      }
    }

    add('durationSeconds', payload['time']);
    add('heartRate', payload['heartRate']);
    add('steps', payload['step']);
    add('distanceMeters', payload['distance']);
    add('calories', payload['calories']);
    add('vo2max', payload['vo2max']);
    return WearableEvent(type: 'sportData', payload: normalized);
  }

  static SportMode? _modeForSportType(int? type) => switch (type) {
    0x0F => SportMode.running,
    0x10 => SportMode.walking,
    0x03 => SportMode.cycling,
    0x1B => SportMode.hiking,
    0x0B => SportMode.mountaineering,
    _ => null,
  };

  WearableEvent? _liveHealthRecord(
    HealthMetric metric,
    Map<String, num?> rawValues,
  ) {
    final values = <String, num>{
      for (final entry in rawValues.entries)
        if (entry.value != null && entry.value!.isFinite && entry.value! > 0)
          entry.key: entry.value!,
    };
    final hasRequiredValues = switch (metric) {
      HealthMetric.bloodPressure =>
        values.containsKey('systolic') && values.containsKey('diastolic'),
      _ => values.containsKey('value'),
    };
    if (!hasRequiredValues) return null;
    final now = DateTime.now();
    final record = HealthRecord(
      id: 'yc-live-${metric.wireName}-${now.toUtc().microsecondsSinceEpoch}',
      metric: metric,
      values: values,
      unit: metric.defaultUnit,
      measuredAt: now.toUtc(),
      timezone: _timezoneOffset(now.timeZoneOffset),
      deviceId: _deviceId ?? '',
      firmwareVersion: _firmware,
      quality: 'device_reported',
      source: MeasurementSource.wearable,
      rawVersion: 1,
    );
    return WearableEvent(type: 'healthRecord', payload: record.toJson());
  }

  void _handleMeasurementState(Map<String, Object?> payload) {
    final metric = _activeMeasurementMetric;
    final state = _number(payload['state'])?.toInt();
    if (metric == null) {
      final deviceId = _deviceId;
      // Measurements started on the watch have no App measurement session.
      // Their completion must still enter the serial history/read/upload path.
      if (state == 0 && deviceId != null) {
        _events.add(
          WearableEvent(
            type: 'healthDataReady',
            payload: {'deviceId': deviceId, 'source': 'watchNotification'},
          ),
        );
      }
      return;
    }
    if (state == 0) {
      unawaited(_finishMeasurementFromHistory(metric));
      return;
    }
    _events.add(
      WearableEvent(
        type: 'measurementProgress',
        payload: {'metric': metric.wireName, 'progress': 0},
      ),
    );
  }

  Future<void> _finishMeasurementFromHistory(HealthMetric metric) async {
    final startedAt = _measurementStartedAt;
    final type = switch (metric) {
      HealthMetric.heartRate => YuchengHealthDataType.heartRate,
      HealthMetric.bloodPressure => YuchengHealthDataType.bloodPressure,
      HealthMetric.bloodOxygen ||
      HealthMetric.bodyTemperature ||
      HealthMetric.bloodGlucose ||
      HealthMetric.hrv => YuchengHealthDataType.combined,
      _ => null,
    };
    if (type == null) return;
    try {
      final result = await _client.health(type).timeout(healthReadTimeout);
      if (_activeMeasurementMetric != metric) return;
      _require(result);
      final records =
          YuchengPayloadMapper.healthRecords(
              deviceId: _connectedId,
              firmwareVersion: _firmware,
              rowsByType: {type: result.data ?? const []},
            ).where((record) => record.metric == metric).toList()
            ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
      final record = records.firstOrNull;
      if (record != null &&
          (startedAt == null ||
              !record.measuredAt.isBefore(
                startedAt.subtract(const Duration(minutes: 2)),
              ))) {
        _activeMeasurementMetric = null;
        _measurementStartedAt = null;
        _events.add(
          WearableEvent(type: 'healthRecord', payload: record.toJson()),
        );
        return;
      }
    } catch (_) {
      if (_activeMeasurementMetric != metric) return;
    }
    _activeMeasurementMetric = null;
    _measurementStartedAt = null;
    _events.add(
      const WearableEvent(
        type: 'error',
        payload: {
          'code': 'MEASUREMENT_STOP_FAILED',
          'message': '未收到有效测量结果，请确认手表已贴合手腕后重试',
        },
      ),
    );
  }

  static num? _number(Object? value) =>
      value is num ? value : num.tryParse('$value');

  static String _timezoneOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }
}

class YuchengSavedDevice {
  const YuchengSavedDevice({
    required this.identifier,
    required this.name,
    this.hardwareAddress,
  });

  final String identifier;
  final String name;
  final String? hardwareAddress;
}

abstract interface class YuchengSavedDeviceStore {
  Future<YuchengSavedDevice?> read();
  Future<void> write(YuchengSavedDevice device);
  Future<void> clear();
}

class SecureYuchengSavedDeviceStore implements YuchengSavedDeviceStore {
  const SecureYuchengSavedDeviceStore({this.storageNamespace});

  final String? storageNamespace;
  String get _prefix =>
      'saydian.global.env.${globalStorageNamespace(storageNamespace)}.wearable.yuc';
  String get _identifierKey => '$_prefix.last.identifier';
  String get _nameKey => '$_prefix.last.name';
  String get _hardwareAddressKey => '$_prefix.last.hardware_address';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<YuchengSavedDevice?> read() async {
    final identifier = (await _storage.read(key: _identifierKey))?.trim() ?? '';
    final name = (await _storage.read(key: _nameKey))?.trim() ?? '';
    if (identifier.isEmpty || name.isEmpty) return null;
    final hardwareAddress = (await _storage.read(
      key: _hardwareAddressKey,
    ))?.trim();
    return YuchengSavedDevice(
      identifier: identifier,
      name: name,
      hardwareAddress: hardwareAddress?.isEmpty == true
          ? null
          : hardwareAddress,
    );
  }

  @override
  Future<void> write(YuchengSavedDevice device) async {
    await _storage.write(key: _identifierKey, value: device.identifier);
    await _storage.write(key: _nameKey, value: device.name);
    await _storage.write(
      key: _hardwareAddressKey,
      value: device.hardwareAddress,
    );
  }

  @override
  Future<void> clear() => Future.wait([
    _storage.delete(key: _identifierKey),
    _storage.delete(key: _nameKey),
    _storage.delete(key: _hardwareAddressKey),
  ]).then((_) {});
}
