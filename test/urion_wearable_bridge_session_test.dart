import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/urion_eb1_protocol.dart';
import 'package:saydian_app/services/urion_wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Watch watch;
  setUp(() => watch = _Watch());
  tearDown(() => watch.dispose());

  test(
    'read-only capability discovery exposes BP and find without starting measurement',
    () async {
      await watch.connect();
      final capabilities = await watch.bridge.getCapabilities();
      expect(capabilities.manualMetrics, {HealthMetric.bloodPressure});
      expect(capabilities.stoppableManualMetrics, isEmpty);
      expect(capabilities.features, contains(DeviceFeature.findWatch));
      expect(
        capabilities.manualMetrics,
        isNot(contains(HealthMetric.heartRate)),
      );
      expect(
        watch.writes.map((entry) => entry.$2.command),
        isNot(contains(0x32)),
      );
      expect(
        watch.writes.map((entry) => entry.$2.command),
        isNot(contains(0x50)),
      );
    },
  );

  test(
    'BP ACK and old history are not results; paired notices emit one verified new record',
    () async {
      final old = _bp(watch.now.subtract(const Duration(minutes: 1)));
      watch.history = [old];
      await watch.connectAndReadCapabilities();
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      expect(watch.records, isEmpty);
      await watch.emit(Eb1Frame.request(0x73, [1]));
      await watch.emit(Eb1Frame.request(0x73, [3]));
      await _flush();
      expect(watch.records, isEmpty);
      final beforeRead = watch.bpReads;
      await watch.emit(Eb1Frame.request(0x73, [2]));
      await _until(() => watch.bpReads > beforeRead);
      await _flush();
      expect(watch.records, isEmpty);

      final startedAt = watch.now;
      watch.now = watch.now.add(const Duration(seconds: 45));
      final fresh = _bp(watch.now, systolic: 123);
      watch.history = [fresh, fresh, old];
      final readGate = Completer<void>();
      watch.historyGate = readGate;
      await watch.emit(Eb1Frame.request(0x73, [2]));
      await _until(() => watch.historyGateTaken);
      await watch.emit(Eb1Frame.request(0x33));
      readGate.complete();
      await _until(() => watch.records.isNotEmpty);
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(watch.records, hasLength(1));
      final record = watch.records.single;
      expect(
        record.payload['measurementStartedAt'],
        startedAt.toIso8601String(),
      );
      final parsed = HealthRecord.fromJson(record.payload);
      expect(parsed.origin, MeasurementOrigin.appMeasurement);
      expect(parsed.values['systolic'], 123);
      expect(parsed.measuredAt.toUtc(), watch.now);
      expect(parsed.deviceId, 'urion:watch-a');
      expect(
        watch.events
            .where((event) => event.type == 'healthDataReady')
            .every(
              (event) =>
                  event.payload['source'] == 'watchNotification' &&
                  event.payload['deviceId'] == 'watch-a',
            ),
        isTrue,
      );
    },
  );

  test(
    'clock-mismatched and multiple new BP records cannot become a measurement',
    () async {
      await watch.connectAndReadCapabilities();
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      watch.now = watch.now.add(const Duration(seconds: 40));
      watch.history = [_bp(watch.now.subtract(const Duration(days: 3)))];
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(watch.records, isEmpty);
      watch.history = [_bp(watch.now), _bp(watch.now, systolic: 124)];
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(watch.records, isEmpty);
    },
  );

  test(
    'confirmed new start replaces the old context without a stop command',
    () async {
      await watch.connectAndReadCapabilities();
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      watch.now = watch.now.add(const Duration(seconds: 30));
      watch.history = [_bp(watch.now)];
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      final newStart = watch.now;
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(watch.records, isEmpty);
      watch.now = watch.now.add(const Duration(seconds: 40));
      watch.history = [_bp(watch.now, systolic: 121), ...watch.history];
      await watch.emit(Eb1Frame.request(0x73, [2]));
      await _until(() => watch.records.isNotEmpty);
      expect(
        watch.records.single.payload['measurementStartedAt'],
        newStart.toIso8601String(),
      );
      expect(
        watch.writes.where((entry) => entry.$2.command == 0x32),
        hasLength(2),
      );
      expect(watch.writes.where((entry) => entry.$2.command == 0x34), isEmpty);
    },
  );

  test('an enqueued find cannot cross to a newly connected watch', () async {
    await watch.connect();
    final hold = Completer<void>();
    watch.findGate = hold;
    final first = watch.bridge.triggerDeviceAction(DeviceFeature.findWatch);
    final firstCheck = expectLater(first, throwsA(isA<PlatformException>()));
    await _until(() => watch.findGateTaken);
    final second = watch.bridge.triggerDeviceAction(DeviceFeature.findWatch);
    final secondCheck = expectLater(
      second,
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'DEVICE_CHANGED',
        ),
      ),
    );
    await watch.bridge.disconnect();
    final connecting = watch.connect('watch-b');
    hold.complete();
    await Future.wait([firstCheck, secondCheck, connecting]);
    expect(
      watch.writes
          .where((entry) => entry.$2.command == 0x50)
          .map((entry) => entry.$1),
      ['watch-a'],
    );
  });

  test(
    'find waits for ACK and unsupported response withdraws capability',
    () async {
      await watch.connectAndReadCapabilities();
      final hold = Completer<void>();
      watch.findGate = hold;
      var complete = false;
      final finding = watch.bridge
          .triggerDeviceAction(DeviceFeature.findWatch)
          .then((_) => complete = true);
      await _until(() => watch.findGateTaken);
      expect(complete, isFalse);
      hold.complete();
      await finding;
      expect(complete, isTrue);
      watch.findUnsupported = true;
      await expectLater(
        watch.bridge.triggerDeviceAction(DeviceFeature.findWatch),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'UNSUPPORTED_DEVICE',
          ),
        ),
      );
      expect(
        (await watch.bridge.getCapabilities()).features,
        isNot(contains(DeviceFeature.findWatch)),
      );
      expect(
        watch.events.where((event) => event.type == 'capabilitiesUpdated'),
        hasLength(1),
      );
      final count = watch.writes.length;
      await expectLater(
        watch.bridge.triggerDeviceAction(DeviceFeature.findWatch),
        throwsA(isA<PlatformException>()),
      );
      expect(watch.writes.length, count);
    },
  );

  test(
    'setting and battery notices never request health synchronization',
    () async {
      await watch.connect();
      await watch.emit(Eb1Frame.request(0x73, [8]));
      await watch.emit(Eb1Frame.request(0x73, [9]));
      await _flush();
      expect(
        watch.events.where((event) => event.type == 'healthDataReady'),
        isEmpty,
      );
    },
  );
}

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 10));

Future<void> _until(bool Function() ready) async {
  for (var attempt = 0; attempt < 100 && !ready(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(ready(), isTrue, reason: 'Expected mock event was not delivered');
}

Eb1Frame _bp(DateTime instant, {int systolic = 120}) {
  final timestamp = instant.millisecondsSinceEpoch ~/ 1000;
  return Eb1Frame.request(0x14, [
    for (var index = 0; index < 4; index++) (timestamp >> (index * 8)) & 255,
    80,
    systolic,
    65,
  ]);
}

class _Watch {
  _Watch() {
    messenger.setMockMethodCallHandler(methods, _method);
    messenger.setMockMethodCallHandler(
      const MethodChannel('test/u19-session-events'),
      (_) async => null,
    );
    bridge = UrionWearableBridge(
      methods: methods,
      eventChannel: eventChannel,
      requestTimeout: const Duration(seconds: 1),
      now: () => now,
    );
    subscription = bridge.events.listen(events.add);
  }

  static const methods = MethodChannel('test/u19-session-methods');
  static const eventChannel = EventChannel('test/u19-session-events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late final UrionWearableBridge bridge;
  late final StreamSubscription<WearableEvent> subscription;
  DateTime now = DateTime.utc(2026, 9, 28, 6);
  String id = 'watch-a';
  int generation = 0;
  int bpReads = 0;
  List<Eb1Frame> history = [];
  final events = <WearableEvent>[];
  final writes = <(String, Eb1Frame)>[];
  Completer<void>? historyGate;
  Completer<void>? findGate;
  bool historyGateTaken = false;
  bool findGateTaken = false;
  bool findUnsupported = false;
  List<WearableEvent> get records =>
      events.where((event) => event.type == 'healthRecord').toList();

  Future<void> connect([String device = 'watch-a']) => bridge.connect(
    device,
    profile: const WearableUserProfile(
      gender: 1,
      heightCm: 170,
      weightKg: 65,
      birthYear: 1990,
      age: 36,
      targetSteps: 6000,
    ),
  );
  Future<void> connectAndReadCapabilities() async {
    await connect();
    await bridge.getCapabilities();
  }

  Future<Object?> _method(MethodCall call) async {
    if (call.method == 'connect') {
      id = (call.arguments as Map)['deviceId'] as String;
      return {'generation': ++generation};
    }
    if (call.method == 'getDeviceDetails') {
      return {
        'id': id,
        'name': 'Protocol fixture',
        'model': 'fixture',
        'firmwareVersion': 'test',
      };
    }
    if (call.method != 'writeFrame') return null;
    final request = Eb1Frame.parse(
      List<int>.from((call.arguments as Map)['bytes']),
    )!;
    final requestId = id;
    final requestGeneration = generation;
    writes.add((id, request));
    final replies = <Eb1Frame>[];
    switch (request.command) {
      case 0x03:
        replies.add(Eb1Frame.request(0x03, [80]));
      case 0x14:
        bpReads++;
        if (historyGate case final gate?) {
          historyGate = null;
          historyGateTaken = true;
          await gate.future;
        }
        replies.addAll(history.take(request[6]));
        if (history.length < request[6]) {
          replies.add(Eb1Frame.request(0x14, [255, 255, 255, 255]));
        }
      case 0x07:
        final today = DateTime.now();
        for (var index = 0; index < 2; index++) {
          replies.add(
            Eb1Frame.request(0x07, [
              index,
              0,
              eb1EncodeBcd(today.year % 100),
              eb1EncodeBcd(today.month),
              eb1EncodeBcd(today.day),
            ]),
          );
        }
      case 0x1f:
        replies.add(Eb1Frame.request(0x1f, [1, 10]));
      case 0x16 || 0x2c:
        replies.add(Eb1Frame.request(request.command, [1, 2]));
      case 0x0a:
        replies.add(Eb1Frame.request(0x0a, [1, 0, 0, 1, 36, 170, 65]));
      case 0x21:
        replies.add(Eb1Frame.request(0x21, [1, 0x70, 0x17]));
      case 0x32:
        replies.add(Eb1Frame.request(0x32));
      case 0x50:
        if (findGate case final gate?) {
          findGate = null;
          findGateTaken = true;
          await gate.future;
        }
        replies.add(
          Eb1Frame.request(
            findUnsupported ? 0xd0 : 0x50,
            findUnsupported ? [0xee] : [],
          ),
        );
      default:
        throw StateError('Unexpected write ${request.command}');
    }
    for (final reply in replies) {
      await emit(reply, device: requestId, session: requestGeneration);
    }
    return null;
  }

  Future<void> emit(Eb1Frame frame, {String? device, int? session}) async {
    await messenger.handlePlatformMessage(
      eventChannel.name,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'type': 'bytes',
        'payload': {
          'deviceId': device ?? id,
          'generation': session ?? generation,
          'bytes': frame.bytes,
        },
      }),
      (_) {},
    );
  }

  Future<void> dispose() async {
    await subscription.cancel();
    await bridge.dispose();
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('test/u19-session-events'),
      null,
    );
  }
}
