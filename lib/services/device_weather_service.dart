import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'safe_resource_client.dart';
import 'global_environment.dart';

class DeviceWeatherException implements Exception {
  const DeviceWeatherException(
    this.message, {
    this.openSettings = false,
    this.locationSettings = false,
  });

  final String message;
  final bool openSettings;
  final bool locationSettings;

  @override
  String toString() => message;
}

class DeviceWeatherForecast {
  const DeviceWeatherForecast({
    required this.city,
    required this.updatedAt,
    required this.hourly,
    required this.daily,
    this.source = 'QWeather',
    this.sourceUrl = 'https://www.qweather.com/',
    this.licenseUrl,
    this.supportsWatchSync = true,
  });

  final String city;
  final DateTime updatedAt;
  final List<Map<String, Object?>> hourly;
  final List<Map<String, Object?>> daily;
  final String source;
  final String sourceUrl;
  final String? licenseUrl;
  final bool supportsWatchSync;

  Map<String, Object?> toFeatureValues({required bool useCelsius}) {
    if (!supportsWatchSync) {
      throw const DeviceWeatherException('当前预报可在手机天气页查看，手表同步尚未支持');
    }
    return {
      'operation': 'sync',
      'enabled': true,
      'useCelsius': useCelsius,
      'city': city,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'hourly': hourly,
      'daily': daily,
    };
  }
}

/// Loads public phone forecasts or the configured QWeather watch forecast.
///
/// The client key stays outside source control and is supplied at build time:
/// `--dart-define=QWEATHER_API_KEY=...`.
class DeviceWeatherService {
  DeviceWeatherService({http.Client? client})
    : _client = SafeResourceClient(
        inner: client,
        purpose: ResourcePurpose.weather,
      );

  final http.Client _client;

  static const _apiKey = String.fromEnvironment('QWEATHER_API_KEY');
  static const _locationChannel = MethodChannel('saydian/weather_location');
  static const _apiHost = String.fromEnvironment(
    'QWEATHER_API_HOST',
    defaultValue: 'https://ny2tuqge5v.re.qweatherapi.com',
  );

  Future<DeviceWeatherForecast> loadCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceWeatherException(
        '请先开启手机定位，再更新天气',
        openSettings: true,
        locationSettings: true,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw DeviceWeatherException(
        '允许位置权限后使用',
        openSettings: permission == LocationPermission.deniedForever,
      );
    }

    Position? position;
    if (_apiKey.isEmpty && defaultTargetPlatform == TargetPlatform.android) {
      final network = await readNetworkLocation();
      if (network != null) {
        return loadCoordinates(network.latitude, network.longitude);
      }
    }
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                accuracy: LocationAccuracy.medium,
                forceLocationManager: true,
                timeLimit: Duration(seconds: 20),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 20),
              ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) {
      throw const DeviceWeatherException('暂时无法获取当前位置，请稍后重试');
    }
    if (_apiKey.isEmpty &&
        DateTime.now().difference(position.timestamp).abs() >
            const Duration(minutes: 30)) {
      throw const DeviceWeatherException('定位信息已过期，请重新获取当前位置');
    }

    return _apiKey.isEmpty
        ? loadCoordinates(position.latitude, position.longitude)
        : _loadForecast('${position.longitude},${position.latitude}');
  }

  Future<DeviceWeatherForecast> loadCity(String city) async {
    final value = city.trim();
    if (value.isEmpty) {
      throw const DeviceWeatherException('请输入城市名称');
    }
    if (_apiKey.isEmpty) {
      // The user explicitly selected this city; this is not a GPS position.
      if (const {'深圳', '深圳市', 'shenzhen'}.contains(value.toLowerCase())) {
        return loadCoordinates(22.53, 114.08, city: '深圳');
      }
      try {
        final location = await _locationChannel
            .invokeMapMethod<String, Object?>('cityLocation', {'city': value})
            .timeout(const Duration(seconds: 9));
        final lat = location?['latitude'];
        final lon = location?['longitude'];
        if (lat is num &&
            lon is num &&
            lat.isFinite &&
            lon.isFinite &&
            lat.abs() <= 90 &&
            lon.abs() <= 180) {
          return loadCoordinates(
            lat.toDouble(),
            lon.toDouble(),
            city: '${location?['city'] ?? value}',
          );
        }
      } catch (_) {
        // No geocoder or no result stays unavailable, not a guessed city.
      }
      throw const DeviceWeatherException('未找到该城市，请检查名称或使用当前位置');
    }
    return _loadForecast(value);
  }

  void close() => _client.close();

  Future<({double latitude, double longitude})?> readNetworkLocation() async {
    try {
      final value = await _locationChannel
          .invokeMapMethod<String, Object?>('currentNetworkLocation')
          .timeout(const Duration(seconds: 9));
      final lat = value?['latitude'];
      final lon = value?['longitude'];
      final time = value?['timestamp'];
      if (lat is! num ||
          lon is! num ||
          time is! int ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat.abs() > 90 ||
          lon.abs() > 180 ||
          DateTime.now()
                  .difference(DateTime.fromMillisecondsSinceEpoch(time))
                  .abs() >
              const Duration(minutes: 10)) {
        return null;
      }
      return (latitude: lat.toDouble(), longitude: lon.toDouble());
    } catch (_) {
      return null;
    }
  }

  Future<DeviceWeatherForecast> loadCoordinates(
    double latitude,
    double longitude, {
    String city = '当前位置',
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw const DeviceWeatherException('天气位置无效');
    }
    final uri = GlobalEnvironment.resolve(
      GlobalEnvironment.configuredOrigin,
      '${GlobalEnvironment.apiPrefix}/support/weather',
      {'lat': latitude.toStringAsFixed(2), 'lon': longitude.toStringAsFixed(2)},
    );
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw const FormatException();
      final root = jsonDecode(response.body);
      if (root is! Map || root['code'] != 200 || root['data'] is! Map) {
        throw const FormatException();
      }
      return fromPublicForecast(
        Map<String, Object?>.from(root['data'] as Map),
        city: city,
      );
    } catch (_) {
      throw const DeviceWeatherException('天气数据暂时不可用，请检查网络后重试');
    }
  }

  /// Daily ranges are calculated from forecast points, not observations.
  static DeviceWeatherForecast fromPublicForecast(
    Map<String, Object?> data, {
    DateTime? now,
    String city = '当前位置',
  }) {
    final updatedAt = DateTime.tryParse('${data['updatedAt'] ?? ''}');
    final current = (now ?? DateTime.now()).toLocal();
    final cutoff = DateTime(
      current.year,
      current.month,
      current.day,
      current.hour,
    );
    final points = <Map<String, Object?>>[];
    for (final item in _list(data['timeseries'])) {
      final time = DateTime.tryParse('${item['time'] ?? ''}');
      final values = item['data'];
      if (time == null || time.isBefore(cutoff) || values is! Map) continue;
      final instant = values['instant'];
      final details = instant is Map ? instant['details'] : null;
      final temperature = details is Map ? details['air_temperature'] : null;
      if (temperature is! num || !temperature.isFinite) continue;
      final period =
          values['next_1_hours'] ??
          values['next_6_hours'] ??
          values['next_12_hours'];
      final summary = period is Map ? period['summary'] : null;
      final symbol = summary is Map ? summary['symbol_code'] : null;
      final wind = details is Map ? details['wind_speed'] : null;
      points.add({
        'time': time.millisecondsSinceEpoch,
        'temperatureC': temperature.toDouble(),
        if (symbol is String) 'symbol': symbol,
        if (wind is num && wind.isFinite) 'windSpeedMs': wind.toDouble(),
      });
    }
    points.sort((a, b) => (a['time'] as int).compareTo(b['time'] as int));
    if (updatedAt == null || points.isEmpty || data['source'] != 'MET Norway') {
      throw const DeviceWeatherException('天气数据暂时不可用，请稍后重试');
    }
    final grouped = <DateTime, List<double>>{};
    for (final point in points) {
      final time = DateTime.fromMillisecondsSinceEpoch(point['time'] as int);
      final day = DateTime(time.year, time.month, time.day);
      grouped.putIfAbsent(day, () => []).add(point['temperatureC'] as double);
    }
    return DeviceWeatherForecast(
      city: city,
      updatedAt: updatedAt,
      hourly: points.take(24).toList(),
      daily: grouped.entries
          .take(7)
          .map(
            (entry) => <String, Object?>{
              'time': entry.key.millisecondsSinceEpoch,
              'maximumC': entry.value.reduce((a, b) => a > b ? a : b),
              'minimumC': entry.value.reduce((a, b) => a < b ? a : b),
            },
          )
          .toList(),
      source: 'MET Norway',
      sourceUrl: 'https://api.met.no/',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      supportsWatchSync: false,
    );
  }

  Future<DeviceWeatherForecast> _loadForecast(String location) async {
    final locationData = await _get('/geo/v2/city/lookup', {
      'location': location,
    });
    final locationItems = locationData['location'];
    if (locationItems is! List || locationItems.isEmpty) {
      throw const DeviceWeatherException('未找到该城市，请检查后重试');
    }
    final locationItem = locationItems.first;
    final city = _cityLabel(locationItem);
    final locationId = locationItem is Map
        ? '${locationItem['id'] ?? ''}'.trim()
        : '';
    if (locationId.isEmpty) {
      throw const DeviceWeatherException('天气数据暂时不可用，请稍后重试');
    }
    final responses = await Future.wait([
      _get('/v7/weather/24h', {'location': locationId}),
      _get('/v7/weather/7d', {'location': locationId}),
    ]);
    final hourlyData = responses[0];
    final dailyData = responses[1];

    final hourly = _list(hourlyData['hourly']).take(24).map((item) {
      final time = DateTime.tryParse('${item['fxTime'] ?? ''}');
      final tempC = _integer(item['temp']);
      return <String, Object?>{
        'time': (time ?? DateTime.now()).millisecondsSinceEpoch,
        'temperatureC': tempC,
        'weatherCode': _watchWeatherCode('${item['text'] ?? ''}'),
        'uvIndex': 0,
        'windLevel': _windLevel(item['windScale']),
        'visibilityMeters': _visibilityMeters(item['vis']),
      };
    }).toList();
    final daily = _list(dailyData['daily']).take(7).map((item) {
      final date = DateTime.tryParse('${item['fxDate'] ?? ''}');
      return <String, Object?>{
        'time': (date ?? DateTime.now()).millisecondsSinceEpoch,
        'maximumC': _integer(item['tempMax']),
        'minimumC': _integer(item['tempMin']),
        'dayWeatherCode': _watchWeatherCode('${item['textDay'] ?? ''}'),
        'nightWeatherCode': _watchWeatherCode('${item['textNight'] ?? ''}'),
        'uvIndex': _integer(item['uvIndex']).clamp(0, 15),
        'windLevel': _windLevel(item['windScaleDay']),
        'visibilityMeters': _visibilityMeters(item['vis']),
      };
    }).toList();
    if (hourly.isEmpty || daily.isEmpty) {
      throw const DeviceWeatherException('天气数据暂时不可用，请稍后重试');
    }
    return DeviceWeatherForecast(
      city: city,
      updatedAt: DateTime.now(),
      hourly: hourly,
      daily: daily,
    );
  }

  Future<Map<String, Object?>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final base = Uri.parse(_apiHost);
    final uri = base.replace(
      path: path,
      queryParameters: {...query, 'key': _apiKey},
    );
    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const DeviceWeatherException('网络不可用，请检查后重试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DeviceWeatherException('天气服务暂时无法使用，请稍后再试');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || '${decoded['code'] ?? ''}' != '200') {
      throw const DeviceWeatherException('天气服务暂时无法使用，请稍后再试');
    }
    return decoded.map((key, value) => MapEntry('$key', value));
  }

  static List<Map<String, Object?>> _list(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  static String _cityLabel(Object? value) {
    if (value is! Map) return '当前位置';
    final district = '${value['name'] ?? ''}'.trim();
    final city = '${value['adm2'] ?? ''}'.trim();
    if (city.isEmpty) return district.isEmpty ? '当前位置' : district;
    if (district.isEmpty || district == city) return city;
    return '$city$district';
  }

  static int _integer(Object? value) =>
      value is num ? value.round() : int.tryParse('$value') ?? 0;

  static int _visibilityMeters(Object? value) {
    final kilometres = value is num
        ? value.toDouble()
        : double.tryParse('$value');
    return ((kilometres ?? 5) * 1000).round().clamp(0, 100000).toInt();
  }

  static String _windLevel(Object? value) {
    final text = '${value ?? '0'}'.trim();
    return text.isEmpty ? '0' : text.replaceAll('级', '');
  }

  static int _watchWeatherCode(String value) {
    if (value.contains('雷')) return 21;
    if (value.contains('冰雹')) return 25;
    if (value.contains('暴雨') || value.contains('大暴雨')) return 65;
    if (value.contains('大雨')) return 50;
    if (value.contains('中雨')) return 42;
    if (value.contains('阵雨')) return 17;
    if (value.contains('小雨') || value.contains('毛毛雨')) return 33;
    if (value.contains('暴雪') || value.contains('大雪')) return 90;
    if (value.contains('中雪')) return 85;
    if (value.contains('小雪') || value.contains('雨夹雪')) return 73;
    if (value.contains('多云')) return 120;
    if (value.contains('阴') || value.contains('雾') || value.contains('霾')) {
      return 13;
    }
    if (value.contains('晴')) return 3;
    return 120;
  }
}
