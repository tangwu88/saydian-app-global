import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/services/device_weather_service.dart';
import 'package:saydian_app/services/safe_resource_client.dart';

Map<String, Object?> forecastBody() => {
  'source': 'MET Norway',
  'updatedAt': '2026-10-03T07:00:00Z',
  'timeseries': [
    for (final hour in [8, 9, 10])
      {
        'time': '2026-10-03T${hour.toString().padLeft(2, '0')}:00:00Z',
        'data': {
          'instant': {
            'details': {'air_temperature': hour - 10.5, 'wind_speed': 2.4},
          },
          'next_1_hours': {
            'summary': {'symbol_code': 'cloudy'},
          },
        },
      },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const locationChannel = MethodChannel('saydian/weather_location');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(locationChannel, null));
  test(
    'explicit Shenzhen selection uses a city forecast without GPS',
    () async {
      messenger.setMockMethodCallHandler(locationChannel, (_) async {
        fail('Shenzhen selection should not require a phone location fix');
      });
      final data = forecastBody();
      data['timeseries'] = [
        {
          'time': DateTime.now()
              .add(const Duration(hours: 2))
              .toUtc()
              .toIso8601String(),
          'data': {
            'instant': {
              'details': {'air_temperature': 26.3},
            },
          },
        },
      ];
      final service = DeviceWeatherService(
        client: MockClient((request) async {
          expect(request.url.queryParameters, {
            'lat': '22.53',
            'lon': '114.08',
          });
          return http.Response(jsonEncode({'code': 200, 'data': data}), 200);
        }),
      );
      final forecast = await service.loadCity(' Shenzhen ');
      expect(forecast.city, '深圳');
      expect(forecast.hourly.single['temperatureC'], 26.3);
      service.close();
    },
  );
  test('unresolved city never falls back to an unrelated city', () async {
    messenger.setMockMethodCallHandler(locationChannel, (call) async {
      expect(call.method, 'cityLocation');
      expect(call.arguments, {'city': 'unknown city'});
      return null;
    });
    final service = DeviceWeatherService(
      client: MockClient((_) async {
        fail('No weather request should be made for an unresolved city');
      }),
    );
    await expectLater(
      service.loadCity('unknown city'),
      throwsA(isA<DeviceWeatherException>()),
    );
    service.close();
  });
  test(
    'fresh network position is used without exposing an account token',
    () async {
      messenger.setMockMethodCallHandler(locationChannel, (call) async {
        expect(call.method, 'currentNetworkLocation');
        expect(call.arguments, isNull);
        return {
          'latitude': 39.9041,
          'longitude': 116.4039,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
      });
      final service = DeviceWeatherService();
      final position = await service.readNetworkLocation();
      expect(position?.latitude, 39.9041);
      expect(position?.longitude, 116.4039);
      service.close();
    },
  );
  test(
    'expired or unavailable network position leaves GPS fallback available',
    () async {
      final service = DeviceWeatherService();
      messenger.setMockMethodCallHandler(
        locationChannel,
        (_) async => {
          'latitude': 39.9,
          'longitude': 116.4,
          'timestamp': DateTime.now()
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch,
        },
      );
      expect(await service.readNetworkLocation(), isNull);
      messenger.setMockMethodCallHandler(locationChannel, (_) async => null);
      expect(await service.readNetworkLocation(), isNull);
      messenger.setMockMethodCallHandler(
        locationChannel,
        (_) async => {
          'latitude': 100,
          'longitude': 116.4,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      expect(await service.readNetworkLocation(), isNull);
      service.close();
    },
  );
  test(
    'forecast preserves negative temperatures and timestamps, derives daily range',
    () {
      final forecast = DeviceWeatherService.fromPublicForecast(
        forecastBody(),
        now: DateTime.utc(2026, 10, 3, 8),
      );
      expect(forecast.hourly.map((p) => p['temperatureC']), [-2.5, -1.5, -0.5]);
      expect(
        forecast.hourly.first['time'],
        DateTime.utc(2026, 10, 3, 8).millisecondsSinceEpoch,
      );
      expect(forecast.daily.single['minimumC'], -2.5);
      expect(forecast.daily.single['maximumC'], -0.5);
      expect(forecast.hourly.first.containsKey('uvIndex'), isFalse);
      expect(
        forecast.licenseUrl,
        'https://creativecommons.org/licenses/by/4.0/',
      );
      expect(
        () => forecast.toFeatureValues(useCelsius: true),
        throwsA(isA<DeviceWeatherException>()),
      );
    },
  );

  test(
    'invalid measurements and expired forecasts never become zero/current weather',
    () {
      final data = forecastBody();
      final rows = data['timeseries'] as List;
      rows.add({'time': 'invalid', 'data': {}});
      rows.add({
        'time': '2026-10-03T11:00:00Z',
        'data': {
          'instant': {'details': {}},
        },
      });
      final forecast = DeviceWeatherService.fromPublicForecast(
        data,
        now: DateTime.utc(2026, 10, 3, 9),
      );
      expect(forecast.hourly.length, 2);
      expect(forecast.hourly.first['temperatureC'], -1.5);
      expect(
        () => DeviceWeatherService.fromPublicForecast(
          data,
          now: DateTime.utc(2026, 10, 4),
        ),
        throwsA(isA<DeviceWeatherException>()),
      );
    },
  );

  test(
    'only the exact first-party weather route is available to the weather client',
    () {
      final client = SafeResourceClient(purpose: ResourcePurpose.weather);
      expect(
        client.allows(
          Uri.parse(
            'https://app.saydian.cn/global/api/saydian-app/v2/support/weather?lat=1&lon=2',
          ),
        ),
        isTrue,
      );
      for (final url in [
        'https://app.saydian.cn/global/api/saydian-app/v2/auth/login',
        'https://app.saydian.cn/global/api/saydian-app/v2/support/weather/other',
        'https://app.saydian.cn.attacker.example/global/api/saydian-app/v2/support/weather',
        'https://app.saydian.cn/global/api/saydian-app/v2/support/%2e%2e/weather',
      ]) {
        expect(client.allows(Uri.parse(url)), isFalse);
      }
      client.close();
    },
  );

  test(
    'phone request rounds GPS and contains no authentication header',
    () async {
      final data = forecastBody();
      data['timeseries'] = [
        {
          'time': DateTime.now()
              .add(const Duration(hours: 2))
              .toUtc()
              .toIso8601String(),
          'data': {
            'instant': {
              'details': {'air_temperature': 18.2},
            },
          },
        },
      ];
      final service = DeviceWeatherService(
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/global/api/saydian-app/v2/support/weather',
          );
          expect(request.url.queryParameters, {
            'lat': '39.90',
            'lon': '116.40',
          });
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(jsonEncode({'code': 200, 'data': data}), 200);
        }),
      );
      expect(
        (await service.loadCoordinates(
          39.9041,
          116.4039,
        )).hourly.single['temperatureC'],
        18.2,
      );
      service.close();
    },
  );

  for (final status in [302, 503]) {
    test('HTTP $status does not become a forecast', () async {
      final service = DeviceWeatherService(
        client: MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(
        service.loadCoordinates(39.9, 116.4),
        throwsA(isA<DeviceWeatherException>()),
      );
      service.close();
    });
  }

  test('malformed envelope does not become weather', () async {
    final service = DeviceWeatherService(
      client: MockClient((_) async => http.Response('{invalid', 200)),
    );
    await expectLater(
      service.loadCoordinates(39.9, 116.4),
      throwsA(isA<DeviceWeatherException>()),
    );
    service.close();
  });
}
