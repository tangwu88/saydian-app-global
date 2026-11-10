import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sayheath/shared/services/qring_wearable_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sayheath/main.dart';
import 'package:sayheath/src/cloud.dart';
import 'package:sayheath/src/device.dart';
import 'package:sayheath/src/session.dart';
import 'package:sayheath/shared/domain/models.dart';

Map<String, dynamic> fixture(
  DateTime time, {
  String? enabled,
  String? allowed,
}) => {
  'userId': 'member-a',
  'release': release,
  'product': product,
  'expiresAt': time.add(const Duration(seconds: 60)).toIso8601String(),
  'features': {
    for (final k in labels.keys)
      k: {'enabled': k == enabled, 'consented': k == allowed},
  },
};

class UiState extends MemberState {
  @override
  Future<void> initialize() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'blood-pressure uploads exclude the accompanying pulse and retain unknowns',
    () {
      expect(
        readingValues('bloodPressure', {
          'systolic': 110,
          'diastolic': 70,
          'pulse': 60,
        }),
        {'systolic': 110, 'diastolic': 70},
      );
      expect(readingValues('bloodPressure', {'systolic': 110}), isNull);
      expect(readingValues('pulse', {'value': 1}), isNull);
    },
  );
  test(
    'QRing pairs without constructing or sending personal attributes',
    () async {
      const channel = MethodChannel('sayheath-test-ring');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodCall? seen;
      messenger.setMockMethodCallHandler(channel, (call) async {
        seen = call;
        return null;
      });
      try {
        await QRingWearableBridge(
          methods: channel,
        ).connectWithoutProfile('synthetic-ring');
        expect(seen?.method, 'connect');
        expect(seen?.arguments, {
          'id': 'synthetic-ring',
          'skipProfileWrite': true,
        });
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );
  final now = DateTime.utc(2026, 11, 11);
  test(
    'malformed, stale, foreign member or future-version flags close every command',
    () {
      final good = fixture(now, enabled: 'heartRate', allowed: 'heartRate');
      for (final bad in [
        null,
        {...good, 'userId': 'different'},
        {...good, 'release': '2.0.0+1'},
        {...good, 'product': 'other'},
        {...good, 'expiresAt': now.toIso8601String()},
        {
          ...good,
          'expiresAt': now.add(const Duration(minutes: 3)).toIso8601String(),
        },
        {
          ...good,
          'features': {
            'heartRate': {'enabled': true, 'consented': true},
          },
        },
        fixture(now, allowed: 'bloodOxygen'),
      ]) {
        expect(Availability.parse(bad, 'member-a', now).allowed, isEmpty);
      }
      expect(Availability.parse(good, 'member-a', now).allowed, {'heartRate'});
    },
  );
  test(
    'default, opt-in, expiry and emergency stop gate different EB1 commands',
    () {
      final d = DeviceLink((_) {})
        ..active = Candidate(
          'U19',
          const DeviceInfo(id: 'synthetic', name: 'U19S'),
        );
      final commands = [
        0x14,
        0x15,
        0x2d,
        0x32,
        0x34,
        0x35,
        0x36,
        0x38,
        0x39,
        0x3a,
        0xff,
      ];
      expect(commands.any((c) => d.permits(c, [1])), isFalse);
      d.policy = Availability(
        {'heartRate'},
        {'heartRate'},
        DateTime.now().add(const Duration(seconds: 30)),
      );
      expect(commands.where((c) => d.permits(c, [1])), [0x15, 0x38]);
      d.policy = Availability(
        {'heartRate'},
        {'heartRate'},
        DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(commands.any((c) => d.permits(c, [1])), isFalse);
      d.stopping = true;
      expect(d.permits(0x35, [0]), isTrue);
      expect(d.permits(0x35, [1]), isFalse);
      expect(d.permits(0x36, []), isTrue);
      expect(d.permits(0x32, [1]), isFalse);
    },
  );
  test(
    'US client rejects alternate hosts, redirects, and malformed envelopes',
    () async {
      var seen = 0;
      final c = Cloud(
        transport: MockClient((r) async {
          seen++;
          expect(r.url.host, 'app.saydian.com');
          expect(r.url.scheme, 'https');
          expect(r.url.path, endsWith('/sayheath/policy'));
          expect(r.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://example.invalid/'},
          );
        }),
      );
      await expectLater(
        c.call('policy', token: 'synthetic'),
        throwsA(isA<CloudError>()),
      );
      await expectLater(
        c.call('https://example.invalid/'),
        throwsArgumentError,
      );
      await expectLater(c.call('../policy'), throwsArgumentError);
      expect(seen, 1);
      final m = Cloud(
        transport: MockClient(
          (_) async => http.Response('{"accepted":true}', 200),
        ),
      );
      await expectLater(m.call('policy'), throwsFormatException);
    },
  );
  test(
    'queue reads only allowed owner and metric, deletes only after exact receipt and stored readback',
    () async {
      const id = 'bdf92f7a-2792-42f8-900e-a107a6ab3141';
      final packet = {
        'id': id,
        'feature': 'heartRate',
        'unit': 'bpm',
        'values': {'value': 60},
        'deviceKey': 'a' * 64,
        'observedAt': '2026-11-11T00:00:00.000Z',
      };
      final paths = <String>[];
      bool mismatch = true;
      FlutterSecureStorage.setMockInitialValues({
        'queue.v1.member-a.heartRate': jsonEncode({id: packet}),
        'queue.v1.member-a.bloodPressure': 'unopened',
        'queue.v1.member-b.heartRate': 'unopened',
        'pulse.private': 'unopened',
      });
      final s =
          MemberState(
              cloud: Cloud(
                transport: MockClient((r) async {
                  paths.add(
                    '${r.method} ${r.url.path.split('/sayheath/').last}',
                  );
                  final data = r.method == 'POST'
                      ? {...packet, 'received': true}
                      : mismatch
                      ? {...packet, 'unit': 'wrong'}
                      : packet;
                  return http.Response(
                    jsonEncode({'code': 200, 'data': data}),
                    200,
                  );
                }),
              ),
            )
            ..member = 'member-a'
            ..token = 'synthetic';
      await s.flush();
      expect(paths, isEmpty);
      s.policy = Availability(
        {'heartRate'},
        {'heartRate'},
        DateTime.now().add(const Duration(seconds: 60)),
      );
      await s.flush();
      expect(
        await MemberState.vault.read(key: 'queue.v1.member-a.heartRate'),
        isNotNull,
      );
      mismatch = false;
      await s.flush();
      expect(paths.last, 'GET captures/$id');
      expect(
        await MemberState.vault.read(key: 'queue.v1.member-a.heartRate'),
        isNull,
      );
      expect(
        await MemberState.vault.read(key: 'queue.v1.member-b.heartRate'),
        'unopened',
      );
      expect(s.readings.single['id'], id);
    },
  );
  test(
    'a revoked older ticket does not block a separately authorized new reading',
    () async {
      const blocked = '11111111-1111-4111-8111-111111111111',
          fresh = '22222222-2222-4222-8222-222222222222';
      Map<String, Object> packet(String id) => {
        'id': id,
        'feature': 'heartRate',
        'unit': 'bpm',
        'values': {'value': 64},
        'deviceKey': 'a' * 64,
        'observedAt': '2026-11-11T00:00:00.000Z',
      };
      const queue = 'queue.v1.current.heartRate';
      FlutterSecureStorage.setMockInitialValues({
        queue: jsonEncode({blocked: packet(blocked), fresh: packet(fresh)}),
      });
      final s =
          MemberState(
              cloud: Cloud(
                transport: MockClient((r) async {
                  if (r.url.path.contains(blocked)) {
                    return http.Response('', 403);
                  }
                  return http.Response(
                    jsonEncode({
                      'code': 200,
                      'data': {
                        ...packet(fresh),
                        if (r.method == 'POST') 'received': true,
                      },
                    }),
                    200,
                  );
                }),
              ),
            )
            ..member = 'current'
            ..token = 'synthetic'
            ..policy = Availability(
              {'heartRate'},
              {'heartRate'},
              DateTime.now().add(const Duration(seconds: 60)),
            );
      await s.flush();
      expect(
        (jsonDecode((await MemberState.vault.read(key: queue))!) as Map).keys,
        [blocked],
      );
      expect(s.readings.single['id'], fresh);
    },
  );
  testWidgets(
    'English sign-in requires agreement; default connected device does not offer sensitive features',
    (tester) async {
      final s = UiState();
      await tester.pumpWidget(SayHeathApp(state: s));
      expect(find.text('SayHeath'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sign in'))
            .onPressed,
        isNull,
      );
      s.member = 'member-a';
      s.token = 'synthetic';
      s.device.active = Candidate(
        'U19',
        const DeviceInfo(id: 'synthetic', name: 'U19S'),
      );
      s.emit();
      await tester.pump();
      await tester.tap(find.text('Device'));
      await tester.pumpAndSettle();
      expect(find.text('Sync device'), findsOneWidget);
      for (final l in labels.values) {
        expect(find.text(l), findsNothing);
      }
      s.policy = Availability(
        {'heartRate'},
        {},
        DateTime.now().add(const Duration(seconds: 60)),
      );
      s.emit();
      await tester.pump();
      expect(find.text('Review permission'), findsOneWidget);
      expect(find.text('Measure now'), findsNothing);
      s.policy = Availability.closed;
      s.emit();
      await tester.pump();
      expect(find.text('Review permission'), findsNothing);
    },
  );
}
