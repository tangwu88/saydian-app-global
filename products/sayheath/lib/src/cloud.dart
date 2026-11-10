import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const product = 'sayheath', release = '1.0.0+1';
const origin = 'https://app.saydian.com/global/api/saydian-app/v2/sayheath';
const labels = <String, String>{
  'bloodPressure': 'Blood pressure',
  'bloodOxygen': 'Blood oxygen',
  'heartRate': 'Heart rate',
  'pulse': 'Pulse insights',
  'scheduledBP': 'Scheduled blood pressure',
};
const cloudSensors = {'bloodPressure', 'bloodOxygen', 'heartRate'};

/// Vendor BP packets may also include pulse. Project only the separately authorized fields.
Map<String, num>? readingValues(String feature, Map<String, num> values) {
  if (!cloudSensors.contains(feature)) return null;
  final keys = feature == 'bloodPressure'
      ? ['systolic', 'diastolic']
      : ['value'];
  if (!keys.every((k) => values[k] != null && values[k]!.isFinite)) return null;
  return {for (final key in keys) key: values[key]!};
}

class CloudError implements Exception {
  const CloudError(this.status);
  final int status;
}

class Cloud {
  Cloud({http.Client? transport}) : _transport = transport ?? http.Client();
  final http.Client _transport;
  Future<dynamic> call(
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    if (!RegExp(r'^[a-z0-9][a-zA-Z0-9/?=&_.%-]*$').hasMatch(path) ||
        path.contains('..') ||
        path.contains('//')) {
      throw ArgumentError('Invalid service path.');
    }
    final req = http.Request(
      body == null ? 'GET' : 'POST',
      Uri.parse('$origin/$path'),
    )..followRedirects = false;
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final response = await _transport
        .send(req)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 14));
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw CloudError(response.statusCode);
    }
    final obj = jsonDecode(utf8.decode(response.bodyBytes));
    if (obj is! Map || obj['code'] != 200 || !obj.containsKey('data')) {
      throw const FormatException('Unexpected response.');
    }
    return obj['data'];
  }
}

class Availability {
  const Availability(this.enabled, this.allowed, this.until);
  final Set<String> enabled, allowed;
  final DateTime? until;
  static const closed = Availability({}, {}, null);
  bool live(DateTime now) => until?.isAfter(now.toUtc()) == true;
  static Availability parse(dynamic obj, String member, DateTime now) {
    if (obj is! Map ||
        obj['product'] != product ||
        obj['release'] != release ||
        obj['userId'] != member) {
      return closed;
    }
    final flags = obj['features'],
        end = DateTime.tryParse('${obj['expiresAt']}')?.toUtc();
    if (flags is! Map ||
        flags.length != labels.length ||
        end == null ||
        !end.isAfter(now) ||
        end.difference(now) > const Duration(seconds: 65)) {
      return closed;
    }
    final enabled = <String>{}, allowed = <String>{};
    for (final k in labels.keys) {
      final f = flags[k];
      if (f is! Map ||
          f['enabled'] is! bool ||
          f['consented'] is! bool ||
          f['enabled'] == false && f['consented'] == true) {
        return closed;
      }
      if (f['enabled'] == true) enabled.add(k);
      if (f['consented'] == true) allowed.add(k);
    }
    return Availability(
      Set.unmodifiable(enabled),
      Set.unmodifiable(allowed),
      end,
    );
  }
}

String? commandFeature(int c) => switch (c) {
  0x14 || 0x32 => 'bloodPressure',
  0x2d || 0x39 => 'bloodOxygen',
  0x15 || 0x38 => 'heartRate',
  0x34 || 0x3a => 'pulse',
  0x35 || 0x36 => 'scheduledBP',
  _ => null,
};
