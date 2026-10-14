import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cc.saidian.ring/qring/commands');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'missing QRing native transport cannot report discovery success',
    () async {
      await expectLater(
        QRingWearableBridge().scanDevices(),
        throwsA(isA<WearableSdkNotConfigured>()),
      );
    },
  );

  test(
    'R21 name does not substitute for the vendor feature handshake',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'resolved': false,
          'metrics': ['steps'],
        },
      );
      await expectLater(
        QRingWearableBridge().getCapabilities(),
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
}
