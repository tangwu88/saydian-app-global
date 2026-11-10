import 'dart:async';
import 'package:flutter/services.dart';
import '../shared/domain/models.dart';
import '../shared/domain/feature_models.dart';
import '../shared/services/wearable_bridge.dart';
import '../shared/services/urion_wearable_bridge.dart';
import '../shared/services/coolwear_wearable_bridge.dart';
import '../shared/services/qring_wearable_bridge.dart';
import 'cloud.dart';

class Candidate {
  Candidate(this.source, this.info);
  final String source;
  final DeviceInfo info;
}

class DeviceLink {
  static const native = MethodChannel('app.saydian.say/device');
  final void Function(WearableEvent event) onEvent;
  DeviceLink(this.onEvent);
  final bridges = <String, WearableBridge>{};
  final subscriptions = <StreamSubscription<WearableEvent>>[];
  Candidate? active;
  DeviceCapabilities? caps;
  Availability policy = Availability.closed;
  bool stopping = false;
  int generation = 0, scanEpoch = 0;
  bool busy = false;
  bool permits(int cmd, List<int> payload) {
    if (cmd == 0x03 || cmd == 0x07) return true;
    if (active?.source != 'U19') return false;
    if (stopping &&
        (cmd == 0x36 || cmd == 0x35 && payload.isNotEmpty && payload[0] == 0)) {
      return true;
    }
    final f = commandFeature(cmd);
    return f != null &&
        policy.live(DateTime.now()) &&
        policy.allowed.contains(f);
  }

  Future<void> prepare() async {
    if (bridges.isNotEmpty) return;
    await native.invokeMethod<void>('prepare');
    bridges.addAll({
      'U19': UrionWearableBridge(commandAllowed: permits),
      'LuckRing': CoolWearWearableBridge(),
      'QRing': QRingWearableBridge(),
    });
    for (final item in bridges.entries) {
      subscriptions.add(
        item.value.events.listen((e) {
          if (active?.source != item.key) return;
          if (e.type == 'disconnected') {
            active = null;
            caps = null;
            generation++;
            unawaited(setPolicy(Availability.closed));
          }
          onEvent(e);
        }, onError: (_) {}),
      );
    }
  }

  Future<List<Candidate>> scan() async {
    await prepare();
    final id = ++scanEpoch;
    final results = await Future.wait(
      bridges.entries.map((e) async {
        try {
          return (await e.value.scanDevices())
              .map((v) => Candidate(e.key, v))
              .toList();
        } catch (_) {
          return <Candidate>[];
        }
      }),
    );
    if (id != scanEpoch) return [];
    return results.expand((v) => v).toList();
  }

  Future<void> connect(Candidate c) async {
    await disconnect();
    final n = ++generation;
    // EB1 does not write profile on connect. Ring SDKs apply their own compatibility policy.
    await bridges[c.source]!.connect(
      c.info.id,
      profile: WearableUserProfile.fromMember({}, targetSteps: 8000),
    );
    if (n != generation) {
      await bridges[c.source]!.disconnect();
      return;
    }
    active = c;
    await setPolicy(Availability.closed);
    if (n == generation) caps = await bridges[c.source]!.getCapabilities();
  }

  Future<void> disconnect() async {
    ++scanEpoch;
    ++generation;
    final c = active;
    active = null;
    caps = null;
    stopping = false;
    await setPolicy(Availability.closed);
    if (c != null) await bridges[c.source]!.disconnect();
  }

  Future<void> setPolicy(Availability p) async {
    final old = policy;
    policy = p;
    final c = active;
    final changed =
        old.allowed.length != p.allowed.length ||
        !old.allowed.containsAll(p.allowed);
    if (changed) {
      (bridges['U19'] as UrionWearableBridge?)?.invalidateProductCapabilities();
      caps = null;
    }
    if (bridges.isEmpty) return;
    await native.invokeMethod<void>('policy', {
      'device': c?.info.id,
      'features': p.allowed.toList(),
      'seconds':
          (p.until?.difference(DateTime.now()).inMilliseconds ?? 0) / 1000.0,
    });
    if (changed && c != null && identical(active, c)) {
      final n = generation;
      final next = await bridges[c.source]!.getCapabilities();
      if (n == generation && identical(active, c) && identical(p, policy)) {
        caps = next;
      }
    }
  }

  static const metrics = {
    'bloodPressure': HealthMetric.bloodPressure,
    'bloodOxygen': HealthMetric.bloodOxygen,
    'heartRate': HealthMetric.heartRate,
  };
  bool supports(String f) =>
      active?.source == 'U19' &&
      (metrics.containsKey(f)
          ? caps?.manualMetrics?.contains(metrics[f]) == true
          : caps?.features.contains(
                  f == 'pulse'
                      ? DeviceFeature.healthAssessment
                      : DeviceFeature.healthMonitoring,
                ) ==
                true);
  Future<Map<String, Object?>> schedule() async {
    final data = await bridges['U19']!.readDeviceFeature(
      DeviceFeature.healthMonitoring,
    );
    if (data['dynamicBloodPressure'] is! Map) {
      throw const FormatException('No schedule available.');
    }
    return Map<String, Object?>.from(data['dynamicBloodPressure'] as Map);
  }

  Future<Map<String, Object?>> writeSchedule(
    Map<String, Object?> value, {
    bool stop = false,
  }) async {
    final c = active, n = generation;
    if (c == null || c.source != 'U19') throw StateError('No device.');
    if (!stop && (!supports('scheduledBP') || !permits(0x35, [1]))) {
      throw StateError('Unavailable.');
    }
    if (stop && value['enabled'] != false) throw StateError('Invalid stop.');
    stopping = stop;
    try {
      if (stop) await native.invokeMethod<void>('stopSchedule', c.info.id);
      final before = stop ? await schedule() : value;
      if (n != generation) throw StateError('Device changed.');
      await bridges['U19']!.writeDeviceFeature(DeviceFeature.healthMonitoring, {
        'dynamicBloodPressure': stop ? {...before, 'enabled': false} : value,
      });
      final check = await schedule();
      if (n != generation ||
          check['enabled'] != value['enabled'] ||
          !stop &&
              [
                'startHour',
                'dayIntervalMinutes',
                'nightIntervalMinutes',
              ].any((k) => check[k] != value[k])) {
        throw StateError('Unconfirmed.');
      }
      return check;
    } finally {
      stopping = false;
      if (stop) await setPolicy(policy);
    }
  }
}
