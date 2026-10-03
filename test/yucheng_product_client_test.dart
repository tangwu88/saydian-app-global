import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/yucheng_product_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'ycaviation.com/yc_product_plugin_method_channel',
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final example in <({Map<String, Object?> data, int? expected})>[
    (data: {'type': 1, 'sampleRate': 25000}, expected: 250),
    (data: {'type': 1, 'sampleRate': 250}, expected: 250),
    (data: {'samplingRate': 500}, expected: 500),
    (data: {'type': 0, 'sampleRate': 25000}, expected: null),
    (data: {'sampleRate': 25000}, expected: null),
    (data: {'type': 1, 'sampleRate': 25001}, expected: null),
    (data: {'type': 1, 'sampleRate': 0}, expected: null),
    (data: {'type': 1, 'sampleRate': 250.5}, expected: null),
  ]) {
    test(
      'ECG sampling query validates vendor metadata ${example.data}',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'appQuerySampleRate');
              expect(call.arguments, 1);
              return {'code': 0, 'data': example.data};
            });

        final response = await PluginYuchengProductClient().ecgSampleRate();

        expect(response.status, 0);
        expect(response.data, example.expected);
      },
    );
  }

  test('failed ECG sampling query never supplies usable metadata', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => {
            'code': 1,
            'data': {'type': 1, 'sampleRate': 25000},
          },
        );

    final response = await PluginYuchengProductClient().ecgSampleRate();

    expect(response.status, 1);
    expect(response.data, isNull);
  });

  test(
    'saved W8 recovery scans before connecting the exact native device',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'scanDevice' => [
                {
                  'deviceIdentifier': 'AA:BB:CC:00:54:9D',
                  'macAddress': 'AA:BB:CC:00:54:9D',
                  'name': 'W8 Plus 549D',
                  'rssiValue': -55,
                },
              ],
              'disconnectDevice' => true,
              'getBluetoothState' => 1,
              'connectDevice' => true,
              _ => null,
            };
          });

      final client = PluginYuchengProductClient();
      final connected = await client.connectSaved(
        identifier: 'aa:bb:cc:00:54:9d',
        name: 'W8 Plus 549D',
        hardwareAddress: 'AA:BB:CC:00:54:9D',
      );

      expect(connected, isTrue);
      expect(
        calls.map((call) => call.method),
        containsAllInOrder([
          'scanDevice',
          'disconnectDevice',
          'getBluetoothState',
          'connectDevice',
        ]),
      );
      expect(
        calls.lastWhere((call) => call.method == 'connectDevice').arguments,
        'AA:BB:CC:00:54:9D',
      );
    },
  );

  test(
    'saved W8 recovery never guesses a different same-model watch',
    () async {
      var connectCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'scanDevice') {
              return [
                {
                  'deviceIdentifier': 'AA:BB:CC:00:00:02',
                  'macAddress': 'AA:BB:CC:00:00:02',
                  'name': 'W8 Plus 549D',
                  'rssiValue': -40,
                },
              ];
            }
            if (call.method == 'connectDevice') connectCalls++;
            return null;
          });

      final connected = await PluginYuchengProductClient().connectSaved(
        identifier: 'AA:BB:CC:00:00:01',
        name: 'W8 Plus 549D',
        hardwareAddress: 'AA:BB:CC:00:00:01',
      );

      expect(connected, isFalse);
      expect(connectCalls, 0);
    },
  );
}
