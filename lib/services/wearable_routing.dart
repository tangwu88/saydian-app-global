import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import '../domain/ios_wellness_policy.dart';
import '../domain/ring_name_policy.dart';
import 'global_storage_scope.dart';
import 'global_saved_device_migration.dart';
import 'wearable_bridge.dart';

enum WearableTransport { veepoo, yucheng, urion, coolwear, qring }

WearableTransport? ringTransportForName(String name) {
  final family = RingNamePolicy.familyForName(name);
  if (family == RingNameFamily.luckring) {
    return WearableTransport.coolwear;
  }
  if (family == RingNameFamily.qring) {
    return WearableTransport.qring;
  }
  final n = name.trim().toUpperCase();
  if (n.startsWith("YC")) return WearableTransport.yucheng;
  if (n.startsWith("TK") || n.startsWith("V")) return WearableTransport.veepoo;
  return null;
}

bool _acceptTransportName(WearableTransport transport, String name) {
  final ring = ringTransportForName(name);
  if (ring != null) return ring == transport;
  return transport != WearableTransport.coolwear &&
      transport != WearableTransport.qring;
}

class YuchengDeviceClassifier {
  const YuchengDeviceClassifier._();

  static bool matches(String name) {
    final normalized = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return normalized.contains('W8');
  }
}

class RoutedDevice {
  const RoutedDevice({
    required this.display,
    required this.transport,
    required this.nativeIdentifier,
  });

  final DeviceInfo display;
  final WearableTransport transport;
  final String nativeIdentifier;

  factory RoutedDevice.fromScan({
    required WearableTransport transport,
    required String nativeIdentifier,
    required String name,
    String? model,
    String? serialNumber,
    String? hardwareAddress,
    String? firmwareVersion,
    DeviceBatteryInfo? battery,
    int? batteryPercent,
    int? rssi,
  }) => RoutedDevice(
    display: DeviceInfo(
      id: scopedID(transport, nativeIdentifier),
      name: name,
      model: model,
      serialNumber: serialNumber,
      hardwareAddress: hardwareAddress,
      firmwareVersion: firmwareVersion,
      battery: battery,
      batteryPercent: batteryPercent,
      rssi: rssi,
    ),
    transport: transport,
    nativeIdentifier: nativeIdentifier,
  );

  factory RoutedDevice.fromDevice(
    WearableTransport transport,
    DeviceInfo device,
  ) => RoutedDevice.fromScan(
    transport: transport,
    nativeIdentifier: device.id,
    name: device.name,
    model: device.model,
    serialNumber: device.serialNumber,
    hardwareAddress: device.hardwareAddress,
    firmwareVersion: device.firmwareVersion,
    battery: device.battery,
    batteryPercent: device.batteryPercent,
    rssi: device.rssi,
  );

  static String scopedID(
    WearableTransport transport,
    String nativeIdentifier,
  ) => '${transport.name}:$nativeIdentifier';
}

class RoutedWearableBridge
    implements
        WearableBridge,
        WearableDeviceDetailsBridge,
        WearableWatchFaceProfileBridge,
        WearableNativeWatchFaceBridge,
        WearableAutoMeasureIntervalBridge,
        WearableSportPauseBridge,
        WearableConnectionRecoveryBridge {
  RoutedWearableBridge({
    required WearableBridge veepoo,
    required WearableBridge yucheng,
    WearableBridge? urion,
    WearableBridge? coolwear,
    WearableBridge? qring,
    WearableTransportPreferenceStore? preferenceStore,
    this.restoreOnlyBoundDevice = false,
    this.recoveryOperationTimeout = const Duration(seconds: 30),
    this.recoveryStopScanTimeout = const Duration(seconds: 3),
  }) : _sources = {
         WearableTransport.veepoo: veepoo,
         WearableTransport.yucheng: yucheng,
         WearableTransport.urion: ?urion,
         WearableTransport.coolwear: ?coolwear,
         WearableTransport.qring: ?qring,
       },
       _preferenceStore =
           preferenceStore ?? const SecureWearableTransportPreferenceStore() {
    _eventController
      ..onListen = _subscribeToSourceEvents
      ..onCancel = _cancelSourceEvents;
  }

  final Map<WearableTransport, WearableBridge> _sources;
  final WearableTransportPreferenceStore _preferenceStore;
  final bool restoreOnlyBoundDevice;
  final Duration recoveryOperationTimeout;
  final Duration recoveryStopScanTimeout;
  final Map<String, RoutedDevice> _scanned = {};
  final StreamController<WearableEvent> _eventController =
      StreamController<WearableEvent>.broadcast();
  final List<StreamSubscription<WearableEvent>> _subscriptions = [];
  WearableTransport? _activeTransport;
  int _connectionGeneration = 0;
  int? _activeConnectionGeneration;
  final Map<WearableTransport, int> _sourceConnectionGenerations = {};
  final Map<WearableTransport, Future<void>> _pendingRecoveryWork = {};
  int? _restoringGeneration;

  WearableBridge get _activeBridge {
    final transport = _activeTransport;
    if (transport == null) {
      throw PlatformException(code: 'NOT_CONNECTED', message: '请先连接设备');
    }
    return _sources[transport]!;
  }

  @override
  Stream<WearableEvent> get events => _eventController.stream;

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    _scanned.clear();
    final failures = <WearableTransport, (Object, StackTrace)>{};
    final batches = await Future.wait(
      _sources.entries.map((entry) async {
        try {
          return MapEntry(entry.key, await entry.value.scanDevices());
        } catch (error, stack) {
          failures[entry.key] = (error, stack);
          return MapEntry(entry.key, const <DeviceInfo>[]);
        }
      }),
    );
    // An unavailable optional SDK must not prevent another SDK from scanning.
    // When every SDK fails, retain the cause so permission/Bluetooth guidance
    // is shown instead of a misleading empty-device result.
    if (failures.length == _sources.length) {
      final failure = failures.values.firstWhere(
        (value) => value.$1 is PlatformException,
        orElse: () => failures.values.first,
      );
      Error.throwWithStackTrace(failure.$1, failure.$2);
    }
    // Rebuild from the completed cross-transport scan to remove stale callbacks.
    _scanned.clear();
    final candidates = <RoutedDevice>[
      for (final batch in batches)
        for (final device in batch.value)
          if (_acceptTransportName(batch.key, device.name) &&
              !(batch.key == WearableTransport.veepoo &&
                  YuchengDeviceClassifier.matches(device.name)))
            RoutedDevice.fromDevice(batch.key, device),
    ];
    final grouped = <String, List<RoutedDevice>>{};
    for (final candidate in candidates) {
      grouped
          .putIfAbsent(
            candidate.display.macAddress ?? candidate.nativeIdentifier,
            () => [],
          )
          .add(candidate);
    }

    for (final group in grouped.values) {
      final selected = _selectDevice(group);
      if (selected == null) continue;
      _scanned[selected.display.id] = selected;
    }
    return _scanned.values.map((device) => device.display).toList();
  }

  RoutedDevice? _selectDevice(List<RoutedDevice> candidates) {
    for (final candidate in candidates) {
      if (candidate.transport == WearableTransport.urion) return candidate;
    }
    for (final candidate in candidates) {
      if (candidate.display.isRing) return candidate;
    }
    final hasYuchengModel = candidates.any(
      (candidate) => YuchengDeviceClassifier.matches(candidate.display.name),
    );
    if (hasYuchengModel) {
      for (final candidate in candidates) {
        if (candidate.transport == WearableTransport.yucheng &&
            YuchengDeviceClassifier.matches(candidate.display.name)) {
          return candidate;
        }
      }
      return candidates.firstWhere(
        (candidate) => candidate.transport == WearableTransport.veepoo,
        orElse: () => candidates.first,
      );
    }
    for (final candidate in candidates) {
      if (candidate.transport == WearableTransport.veepoo) return candidate;
    }
    return null;
  }

  @override
  Future<void> stopScan() {
    if (_restoringGeneration == _connectionGeneration) {
      ++_connectionGeneration;
    }
    return Future.wait(
      _sources.values.map(
        (source) => source.stopScan().timeout(
          recoveryStopScanTimeout,
          onTimeout: () {},
        ),
      ),
    ).then((_) {});
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    final device = _scanned[deviceId];
    if (device == null) {
      throw PlatformException(
        code: 'UNKNOWN_SCANNED_DEVICE',
        message: '请重新扫描后再连接设备',
      );
    }
    if (device.transport == WearableTransport.veepoo &&
        YuchengDeviceClassifier.matches(device.display.name)) {
      throw PlatformException(
        code: 'YUCHENG_DISCOVERY_MISMATCH',
        message: '当前设备暂时无法连接，请重新扫描后重试',
      );
    }
    _requireRecoverySourceAvailable(device.transport);

    final generation = ++_connectionGeneration;
    _activeTransport = device.transport;
    if (kDebugMode) {
      debugPrint('[WearableRoute] connect ${device.transport.name}');
    }
    _activeConnectionGeneration = generation;
    _sourceConnectionGenerations[device.transport] = generation;
    try {
      await _activeBridge.connect(device.nativeIdentifier, profile: profile);
      try {
        if (generation != _connectionGeneration) return;
        final preference = _preferenceStore;
        if (preference is WearableBindingPreferenceStore) {
          await preference.writeBinding(
            SavedWearableBinding(device.transport, device.nativeIdentifier),
          );
        } else {
          await preference.write(device.transport);
        }
      } catch (_) {
        // A preference write is not part of the authenticated BLE boundary.
      }
    } catch (_) {
      if (_activeConnectionGeneration == generation) {
        _activeTransport = null;
        _activeConnectionGeneration = null;
      }
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    ++_connectionGeneration;
    final transport = _activeTransport;
    final connectionOwner = _activeConnectionGeneration;
    // Persist the user's intent to stop automatic recovery, including when
    // native cancellation later times out. Keep the live channel for retry.
    try {
      await _preferenceStore.clear();
    } catch (_) {
      // Native cancellation is still required if local storage is unavailable.
    }
    if (transport == null) return;
    final pending = _pendingRecoveryWork[transport];
    if (pending == null) {
      await _sources[transport]!.disconnect();
    } else {
      await pending.timeout(recoveryOperationTimeout);
    }
    // Retain the owner on failure so an explicit retry still
    // reaches the same native channel instead of reporting a no-op success.
    if (_activeConnectionGeneration == connectionOwner) {
      _activeTransport = null;
      _activeConnectionGeneration = null;
    }
  }

  @override
  Future<DeviceInfo?> restoreConnection({
    required WearableUserProfile profile,
  }) async {
    final generation = ++_connectionGeneration;
    if (restoreOnlyBoundDevice) {
      _restoringGeneration = generation;
      try {
        return await _restoreBoundDevice(profile, generation);
      } finally {
        if (_restoringGeneration == generation) _restoringGeneration = null;
      }
    }
    WearableTransport? preferred;
    try {
      preferred = await _preferenceStore.read();
    } catch (_) {
      preferred = null;
    }
    final entries = preferred == null
        ? _sources.entries
        : _sources.entries.where((entry) => entry.key == preferred);
    for (final entry in entries) {
      final bridge = entry.value;
      if (bridge is! WearableConnectionRecoveryBridge) continue;
      try {
        final details = await (bridge as WearableConnectionRecoveryBridge)
            .restoreConnection(profile: profile);
        if (generation != _connectionGeneration) return null;
        if (details == null) continue;
        _activeTransport = entry.key;
        _activeConnectionGeneration = generation;
        return RoutedDevice.fromDevice(entry.key, details).display;
      } on PlatformException catch (error) {
        if (error.code != 'NO_SAVED_DEVICE') rethrow;
      }
    }
    return null;
  }

  Future<DeviceInfo?> _restoreBoundDevice(
    WearableUserProfile profile,
    int generation,
  ) async {
    final preference = _preferenceStore;
    if (preference is! WearableBindingPreferenceStore) return null;
    SavedWearableBinding? saved;
    try {
      saved = await preference.readBinding();
    } catch (_) {
      return null;
    }
    if (saved == null || generation != _connectionGeneration) return null;
    _requireRecoverySourceAvailable(saved.transport);
    final source = _sources[saved.transport]!;
    // Native SDKs keep installation-wide saved targets. Never ask them to
    // restore a target selected in another API environment.
    final List<DeviceInfo> scanned;
    try {
      scanned = await source.scanDevices().timeout(recoveryOperationTimeout);
    } finally {
      try {
        await source.stopScan().timeout(recoveryStopScanTimeout);
      } on TimeoutException {
        // The controller's explicit connect uses the same grace period for
        // SDKs that stop scanning but fail to complete their method callback.
      }
    }
    if (generation != _connectionGeneration) return null;
    DeviceInfo? target;
    for (final device in scanned) {
      if (device.id == saved.nativeIdentifier) {
        target = device;
        break;
      }
    }
    if (target == null && source is WearableBoundDeviceLookupBridge) {
      target = await (source as WearableBoundDeviceLookupBridge)
          .lookupPreviouslyBoundDevice(saved.nativeIdentifier)
          .timeout(recoveryOperationTimeout);
      if (generation != _connectionGeneration) return null;
      if (target?.id != saved.nativeIdentifier) return null;
    }
    if (target == null || !_acceptTransportName(saved.transport, target.name)) {
      return null;
    }
    final routed = RoutedDevice.fromDevice(saved.transport, target);
    if (saved.transport == WearableTransport.veepoo &&
        YuchengDeviceClassifier.matches(target.name)) {
      return null;
    }
    _activeTransport = saved.transport;
    _activeConnectionGeneration = generation;
    _sourceConnectionGenerations[saved.transport] = generation;
    var timedOut = false;
    final transport = saved.transport;
    final actualWork = () async {
      try {
        await source.connect(routed.nativeIdentifier, profile: profile);
        if (timedOut || generation != _connectionGeneration) {
          await _disconnectRetiredRecovery(source, transport, generation);
        }
      } catch (_) {
        _clearRecoveryOwner(transport, generation);
        rethrow;
      }
    }();
    late final Future<void> trackedWork;
    trackedWork = actualWork.whenComplete(() {
      if (identical(_pendingRecoveryWork[transport], trackedWork)) {
        _pendingRecoveryWork.remove(transport);
      }
    });
    _pendingRecoveryWork[transport] = trackedWork;
    // Keep the actual native chain, not the timeout wrapper, as the channel
    // barrier. A failed wait must not release a still-running SDK operation.
    unawaited(trackedWork.catchError((Object _) {}));
    try {
      await trackedWork.timeout(recoveryOperationTimeout);
    } on TimeoutException {
      timedOut = true;
      if (_activeConnectionGeneration == generation) _activeTransport = null;
      rethrow;
    } catch (_) {
      _clearRecoveryOwner(transport, generation);
      rethrow;
    }
    if (generation != _connectionGeneration) {
      return null;
    }
    _scanned[routed.display.id] = routed;
    return routed.display;
  }

  Future<void> _disconnectRetiredRecovery(
    WearableBridge source,
    WearableTransport transport,
    int generation,
  ) async {
    if (_sourceConnectionGenerations[transport] != generation) return;
    try {
      // Do not timeout this original future: the caller times out its wait,
      // while the same-source barrier stays until native cleanup really ends.
      await source.disconnect();
    } finally {
      _clearRecoveryOwner(transport, generation);
    }
  }

  void _clearRecoveryOwner(WearableTransport transport, int generation) {
    if (_sourceConnectionGenerations[transport] == generation) {
      _sourceConnectionGenerations.remove(transport);
    }
    if (_activeConnectionGeneration == generation) {
      _activeTransport = null;
      _activeConnectionGeneration = null;
    }
  }

  void _requireRecoverySourceAvailable(WearableTransport transport) {
    if (_pendingRecoveryWork.containsKey(transport)) {
      throw PlatformException(
        code: 'RECOVERY_PENDING',
        message: '设备正在恢复连接，请稍后重试',
      );
    }
  }

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails({
    bool forceRefresh = false,
  }) async {
    final transport = _activeTransport;
    if (transport == null) return null;
    final bridge = _sources[transport];
    if (bridge is! WearableDeviceDetailsBridge) return null;
    final details = await (bridge as WearableDeviceDetailsBridge)
        .getConnectedDeviceDetails(forceRefresh: forceRefresh);
    if (details == null) {
      _activeTransport = null;
      return null;
    }
    return RoutedDevice.fromDevice(transport, details).display;
  }

  @override
  Future<Map<String, Object?>> getWatchFaceProfile() async {
    final bridge = _activeBridge;
    if (bridge is! WearableWatchFaceProfileBridge) return const {};
    return (bridge as WearableWatchFaceProfileBridge).getWatchFaceProfile();
  }

  WearableNativeWatchFaceBridge get _nativeWatchFaceBridge {
    final bridge = _activeBridge;
    if (_activeTransport != WearableTransport.veepoo ||
        bridge is! WearableNativeWatchFaceBridge) {
      throw PlatformException(
        code: 'WATCH_FACE_MARKET_UNSUPPORTED',
        message: '当前设备暂不支持在线表盘',
      );
    }
    return bridge as WearableNativeWatchFaceBridge;
  }

  void _requireCurrentConnection(int generation) {
    if (generation != _connectionGeneration || _activeTransport == null) {
      throw PlatformException(
        code: 'DEVICE_CHANGED',
        message: '设备连接已变化，请重新打开表盘商城',
      );
    }
  }

  @override
  Future<List<NativeWatchFaceCatalogItem>> getNativeWatchFaceCatalog() async {
    final generation = _connectionGeneration;
    final result = await _nativeWatchFaceBridge.getNativeWatchFaceCatalog();
    _requireCurrentConnection(generation);
    return result;
  }

  @override
  Future<NativeWatchFaceDownload> downloadNativeWatchFace(
    String catalogId,
  ) async {
    final generation = _connectionGeneration;
    final result = await _nativeWatchFaceBridge.downloadNativeWatchFace(
      catalogId,
    );
    _requireCurrentConnection(generation);
    return result;
  }

  void _requireDeviceSettings() {
    _requirePhysiology();
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async => _localDevicePolicy
      .projectCapabilities(await _activeBridge.getCapabilities());

  IosWellnessPolicy get _localDevicePolicy => IosWellnessPolicy.forSdkSource(
    _activeTransport == WearableTransport.urion
        ? WearableSdkSource.urion
        : null,
  );

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async =>
      _localDevicePolicy.projectRecords(
        await _activeBridge.syncHealthData(cursor: cursor),
      );

  void _requirePhysiology() {
    if (IosWellnessPolicy.current.enabled) {
      throw PlatformException(
        code: 'IOS_WELLNESS_SCOPE',
        message: 'Not available in this iOS edition.',
      );
    }
  }

  void _requireFeature(DeviceFeature feature) {
    if (!IosWellnessPolicy.current.allowsFeature(feature)) {
      _requirePhysiology();
    }
  }

  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    if (!_localDevicePolicy.allowsMeasurement(metric)) _requirePhysiology();
    await _activeBridge.startMeasurement(metric);
  }

  @override
  Future<void> stopMeasurement(HealthMetric metric) async {
    if (!_localDevicePolicy.allowsMeasurement(metric)) _requirePhysiology();
    await _activeBridge.stopMeasurement(metric);
  }

  @override
  Future<void> startSport(SportMode mode) => _activeBridge.startSport(mode);

  @override
  Future<void> stopSport() => _activeBridge.stopSport();

  @override
  Future<void> pauseSport() {
    final bridge = _activeBridge;
    if (bridge is! WearableSportPauseBridge) {
      throw PlatformException(
        code: 'SPORT_PAUSE_UNSUPPORTED',
        message: '当前设备不支持暂停运动',
      );
    }
    return (bridge as WearableSportPauseBridge).pauseSport();
  }

  @override
  Future<void> resumeSport() {
    final bridge = _activeBridge;
    if (bridge is! WearableSportPauseBridge) {
      throw PlatformException(
        code: 'SPORT_PAUSE_UNSUPPORTED',
        message: '当前设备不支持暂停运动',
      );
    }
    return (bridge as WearableSportPauseBridge).resumeSport();
  }

  @override
  Future<List<SportRecord>> readSportRecords() async =>
      (await _activeBridge.readSportRecords())
          .map(IosWellnessPolicy.current.projectSport)
          .toList();

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() =>
      IosWellnessPolicy.current.enabled
      ? Future.value({})
      : _activeBridge.readAutoMeasureSettings();

  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) async {
    _requireDeviceSettings();
    await _activeBridge.setAutoMeasureSetting(type, enabled);
  }

  @override
  Future<Map<String, AutoMeasureIntervalSetting>> readAutoMeasureIntervals() {
    if (IosWellnessPolicy.current.enabled) {
      return Future.value({});
    }
    final bridge = _activeBridge;
    if (bridge is! WearableAutoMeasureIntervalBridge) return Future.value({});
    return (bridge as WearableAutoMeasureIntervalBridge)
        .readAutoMeasureIntervals();
  }

  @override
  Future<void> setAutoMeasureInterval(String type, int minutes) {
    _requireDeviceSettings();
    final bridge = _activeBridge;
    if (bridge is! WearableAutoMeasureIntervalBridge) {
      throw PlatformException(
        code: 'AUTO_MEASURE_INTERVAL_UNSUPPORTED',
        message: '当前设备不支持调整监测间隔',
      );
    }
    return (bridge as WearableAutoMeasureIntervalBridge).setAutoMeasureInterval(
      type,
      minutes,
    );
  }

  @override
  Future<int?> readHeartRateWarning() => IosWellnessPolicy.current.enabled
      ? Future.value(null)
      : _activeBridge.readHeartRateWarning();

  @override
  Future<void> setHeartRateWarning(int value) async {
    _requirePhysiology();
    await _activeBridge.setHeartRateWarning(value);
  }

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    _requireFeature(feature);
    return _activeBridge.readDeviceFeature(feature);
  }

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    _requireFeature(feature);
    await _activeBridge.writeDeviceFeature(feature, values);
  }

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {
    _requireFeature(feature);
    await _activeBridge.triggerDeviceAction(feature, enabled: enabled);
  }

  void _subscribeToSourceEvents() {
    if (_subscriptions.isNotEmpty) return;
    for (final entry in _sources.entries) {
      _subscriptions.add(
        entry.value.events.listen(
          (event) => _forwardEvent(entry.key, event),
          onError: _eventController.addError,
        ),
      );
    }
  }

  void _cancelSourceEvents() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  void _forwardEvent(WearableTransport transport, WearableEvent event) {
    final policy = IosWellnessPolicy.forSdkSource(
      transport == WearableTransport.urion ? WearableSdkSource.urion : null,
    );
    if (policy.enabled) {
      if (event.type == 'healthRecord') {
        if (!policy.allowsWireMetric('${event.payload['type'] ?? ''}')) return;
        final projected = policy.projectRecord(
          HealthRecord.fromJson(event.payload),
        );
        if (projected == null) return;
        event = WearableEvent(type: event.type, payload: projected.toJson());
      } else if ((event.type.startsWith('measurement') &&
              !policy.hasLocalDeviceMetrics) ||
          event.type.toLowerCase().contains('ecg')) {
        return;
      } else if (event.type == 'sportData') {
        event = WearableEvent(
          type: event.type,
          payload: policy.projectSportValues({
            for (final entry in event.payload.entries)
              if (entry.value is num) entry.key: entry.value as num,
          }),
        );
      }
    }
    if (_pendingRecoveryWork.containsKey(transport) &&
        (_sourceConnectionGenerations[transport] != _connectionGeneration ||
            _activeTransport != transport)) {
      // Retired native callbacks may arrive before disconnect finishes. They
      // must not re-adopt the old watch or publish health data after cancellation.
      return;
    }
    if (event.type == 'scanDevice') {
      final device = DeviceInfo.fromMap(event.payload);
      if (!_acceptTransportName(transport, device.name)) return;
      // Both Android SDKs can report the same W8-family watch while scanning.
      // W8 devices are owned by Yucheng, so never expose the Veepoo discovery
      // event to the controller (the completed scan is filtered the same way).
      if (transport == WearableTransport.veepoo &&
          YuchengDeviceClassifier.matches(device.name)) {
        return;
      }
      final routed = RoutedDevice.fromDevice(transport, device);
      final mac = routed.display.macAddress;
      if (mac != null) {
        if (transport != WearableTransport.urion &&
            _scanned.values.any(
              (existing) =>
                  existing.transport == WearableTransport.urion &&
                  existing.display.macAddress == mac,
            )) {
          return;
        }
        if (transport == WearableTransport.urion) {
          _scanned.removeWhere(
            (_, existing) => existing.display.macAddress == mac,
          );
        }
      }
      // A user can tap a device as soon as it appears. Keep the routing table
      // in sync with live discovery events instead of waiting for the native
      // scan Future to finish.
      _scanned[routed.display.id] = routed;
      _eventController.add(
        WearableEvent(type: event.type, payload: routed.display.toJson()),
      );
      return;
    }
    if (transport == _activeTransport) {
      if (event.type == 'disconnected' || event.type == 'reconnected') {
        ++_connectionGeneration;
      }
      if (event.type == 'deviceDetails' ||
          event.type == 'reconnected' ||
          event.type == 'disconnected' ||
          event.type == 'syncProgress' ||
          event.type == 'healthDataReady' ||
          event.type == 'cameraShutter') {
        final payload = Map<String, Object?>.from(event.payload);
        final usesPrimaryId =
            event.type == 'deviceDetails' || event.type == 'reconnected';
        final nativeValue = usesPrimaryId ? payload['id'] : payload['deviceId'];
        final nativeIdentifier = '${nativeValue ?? ''}';
        if (nativeIdentifier.isNotEmpty) {
          final prefix = '${transport.name}:';
          final scopedIdentifier = nativeIdentifier.startsWith(prefix)
              ? nativeIdentifier
              : RoutedDevice.scopedID(transport, nativeIdentifier);
          if (payload.containsKey('id')) payload['id'] = scopedIdentifier;
          if (payload.containsKey('deviceId')) {
            payload['deviceId'] = scopedIdentifier;
          }
        }
        _eventController.add(WearableEvent(type: event.type, payload: payload));
        return;
      }
      _eventController.add(event);
    }
  }

  Future<void> dispose() async {
    _cancelSourceEvents();
    await _eventController.close();
  }
}

abstract interface class WearableTransportPreferenceStore {
  Future<WearableTransport?> read();
  Future<void> write(WearableTransport transport);
  Future<void> clear();
}

class SavedWearableBinding {
  const SavedWearableBinding(this.transport, this.nativeIdentifier);

  final WearableTransport transport;
  final String nativeIdentifier;
}

abstract interface class WearableBindingPreferenceStore
    implements WearableTransportPreferenceStore {
  Future<SavedWearableBinding?> readBinding();
  Future<void> writeBinding(SavedWearableBinding binding);
}

class SecureWearableTransportPreferenceStore
    implements WearableBindingPreferenceStore {
  const SecureWearableTransportPreferenceStore({this.storageNamespace});

  final String? storageNamespace;
  String get _key =>
      'saydian.global.env.${globalStorageNamespace(storageNamespace)}.wearable.binding.v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, Object?>?> _readValue() async {
    final value =
        await _storage.read(key: _key) ??
        (await readMigratedDevicePreferences(storageNamespace))?['binding'];
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  WearableTransport? _transport(Object? value) {
    for (final transport in WearableTransport.values) {
      if (transport.name == value) return transport;
    }
    return null;
  }

  @override
  Future<WearableTransport?> read() async =>
      _transport((await _readValue())?['transport']);

  @override
  Future<SavedWearableBinding?> readBinding() async {
    final value = await _readValue();
    final transport = _transport(value?['transport']);
    final identifier = value?['nativeIdentifier'];
    if (transport == null || identifier is! String || identifier.isEmpty) {
      return null;
    }
    return SavedWearableBinding(transport, identifier);
  }

  @override
  Future<void> write(WearableTransport transport) => _storage.write(
    key: _key,
    value: jsonEncode({'transport': transport.name}),
  );

  @override
  Future<void> writeBinding(SavedWearableBinding binding) => _storage.write(
    key: _key,
    value: jsonEncode({
      'transport': binding.transport.name,
      'nativeIdentifier': binding.nativeIdentifier,
    }),
  );

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: migratedDeviceKey(storageNamespace));
  }
}
