import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/global_locale_controller.dart';
import '../services/device_weather_service.dart';
import '../services/global_environment.dart';

class PhoneWeatherPage extends StatefulWidget {
  const PhoneWeatherPage({super.key});

  @override
  State<PhoneWeatherPage> createState() => _PhoneWeatherPageState();
}

class _PhoneWeatherPageState extends State<PhoneWeatherPage> {
  final _service = DeviceWeatherService();
  final _city = TextEditingController();
  final _storage = const FlutterSecureStorage();
  static final _cityKey =
      'saydian.global.env.${GlobalEnvironment.storageNamespace}.weather.city';
  DeviceWeatherForecast? _forecast;
  DeviceWeatherException? _error;
  bool _loading = false;

  String _copy(String en, String zh) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    String? savedCity;
    try {
      savedCity = await _storage.read(key: _cityKey);
    } catch (_) {
      // A missing preference does not prevent a fresh weather request.
    }
    if (!mounted) return;
    _city.text = savedCity ?? '';
    await _refresh(useCity: _city.text.isNotEmpty);
  }

  @override
  void dispose() {
    _service.close();
    _city.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool useCity = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _forecast = null;
    });
    try {
      final forecast = useCity
          ? await _service.loadCity(_city.text)
          : await _service.loadCurrentLocation();
      if (mounted) setState(() => _forecast = forecast);
      try {
        await _storage.write(
          key: _cityKey,
          value: useCity ? forecast.city : '',
        );
      } catch (_) {
        // The fetched forecast remains usable if preference storage fails.
      }
    } on DeviceWeatherException catch (error) {
      if (mounted) setState(() => _error = error);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = const DeviceWeatherException('天气数据暂时不可用，请稍后重试'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _temperature(Object? value) =>
      value is num ? '${value.toStringAsFixed(1)} °C' : '—';
  DateTime _time(Map<String, Object?> point) =>
      DateTime.fromMillisecondsSinceEpoch(point['time'] as int);

  String? _conditions(Object? value) {
    if (value is! String) return null;
    if (value.contains('thunder')) return _copy('Thunderstorms', '雷阵雨');
    if (value.contains('sleet')) return _copy('Sleet', '雨夹雪');
    if (value.contains('snow')) return _copy('Snow', '雪');
    if (value.contains('rain')) return _copy('Rain', '雨');
    if (value.contains('fog')) return _copy('Fog', '雾');
    if (value.startsWith('partlycloudy')) return _copy('Partly cloudy', '多云');
    if (value.startsWith('cloudy')) return _copy('Cloudy', '阴');
    if (value.startsWith('clearsky')) return _copy('Clear', '晴');
    if (value.startsWith('fair')) return _copy('Mostly clear', '晴间多云');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final forecast = _forecast;
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.weather)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            forecast != null && forecast.city != '当前位置'
                ? '${forecast.city} ${_copy('forecast', '天气预报')}'
                : _copy('Weather forecast on your phone', '手机天气预报'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _copy(
              'Uses your selected city or phone location for a nearby forecast.',
              '按所选城市或手机定位获取附近区域预报。',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('phone-weather-city'),
            controller: _city,
            enabled: !_loading,
            decoration: InputDecoration(
              labelText: _copy(
                'City (when location is unavailable)',
                '城市（定位不可用时可选择）',
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _refresh(useCity: true),
          ),
          TextButton(
            key: const Key('phone-weather-city-search'),
            onPressed: _loading ? null : () => _refresh(useCity: true),
            child: Text(_copy('Get city weather', '获取城市天气')),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (error != null) ...[
            Text(
              _copy(
                'Weather unavailable. Check location permission and network, then try again.',
                error.message,
              ),
            ),
            if (error.openSettings)
              TextButton(
                onPressed: () async {
                  if (error.locationSettings) {
                    await Geolocator.openLocationSettings();
                  } else {
                    await Geolocator.openAppSettings();
                  }
                },
                child: Text(_copy('Open settings', '打开设置')),
              ),
          ],
          if (forecast != null) ...[
            Text(
              _temperature(forecast.hourly.first['temperatureC']),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            if (_conditions(forecast.hourly.first['symbol'])
                case final String conditions)
              Text(conditions),
            Text(
              '${_copy('Forecast for', '预报时间')} ${DateFormat('MM-dd HH:mm').format(_time(forecast.hourly.first))}',
            ),
            const SizedBox(height: 20),
            Text(
              _copy('Upcoming forecast', '未来天气预报'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final point in forecast.hourly.take(12))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('MM-dd HH:mm').format(_time(point))),
                trailing: Text(_temperature(point['temperatureC'])),
                subtitle: point['windSpeedMs'] is num
                    ? Text('${_copy('Wind', '风速')} ${point['windSpeedMs']} m/s')
                    : null,
              ),
            Text(
              _copy(
                'Daily temperature ranges calculated from forecast points',
                '每日温度范围（按预报时点计算）',
              ),
            ),
            for (final day in forecast.daily)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('MM-dd').format(_time(day))),
                trailing: Text(
                  '${_temperature(day['minimumC'])} – ${_temperature(day['maximumC'])}',
                ),
              ),
            Text(
              '${_copy('Updated', '数据更新')} ${DateFormat('MM-dd HH:mm').format(forecast.updatedAt.toLocal())}',
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(forecast.sourceUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text('${_copy('Source', '数据来源')}: ${forecast.source}'),
            ),
            if (forecast.licenseUrl != null)
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(forecast.licenseUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('CC BY 4.0'),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : () => _refresh(),
            icon: const Icon(Icons.refresh),
            label: Text(_copy('Use current location', '获取当前位置天气')),
          ),
        ],
      ),
    );
  }
}
