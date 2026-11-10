import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../shared/domain/models.dart';
import '../shared/domain/feature_models.dart';
import '../shared/domain/urion_pulse_record.dart';
import 'cloud.dart';
import 'device.dart';

typedef Json = Map<String, dynamic>;

class MemberState extends ChangeNotifier {
  MemberState({Cloud? cloud}) : cloud = cloud ?? Cloud() {
    device = DeviceLink(_onEvent);
  }
  final Cloud cloud;
  late final DeviceLink device;
  static const vault = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );
  String? token, member;
  Json? documents;
  int epoch = 0, policyCall = 0;
  bool busy = false, foreground = true;
  String message = '';
  List<Json> daily = [], family = [], readings = [], pulses = [];
  List<Candidate> found = [];
  Map<String, Object?>? schedule;
  bool knownSchedule = false;
  Availability policy = Availability.closed;
  Json? attempt;
  String? nextDay;
  Future<void> _queueTail = Future.value();
  Future<T> _withQueue<T>(Future<T> Function() action) {
    final result = _queueTail.then((_) => action());
    _queueTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  String _queueKey(String owner, String feature) => 'queue.v1.$owner.$feature';

  Future<Json> _readQueue(String key) async {
    final raw = await vault.read(key: key);
    return raw == null
        ? <String, dynamic>{}
        : Json.from(jsonDecode(raw) as Map);
  }

  Future<void> _editQueue(String key, void Function(Json) edit) =>
      _withQueue(() async {
        final rows = await _readQueue(key);
        edit(rows);
        if (rows.isEmpty) {
          await vault.delete(key: key);
        } else {
          await vault.write(key: key, value: jsonEncode(rows));
        }
      });
  Timer? timer, measurementTimeout;
  String get deviceKey => sha256
      .convert(
        utf8.encode(
          '$member|${device.active?.source}|${device.active?.info.id}',
        ),
      )
      .toString();
  void emit() {
    notifyListeners();
  }

  Future<void> initialize() async {
    final old = await vault.read(key: 'session');
    if (old != null) {
      try {
        final s = jsonDecode(old);
        if (s['token'] is String && s['userId'] is String) {
          token = s['token'];
          member = s['userId'];
        }
      } catch (_) {}
    }
    emit();
    try {
      await loadLegal();
    } catch (_) {}
    if (token != null) {
      try {
        await refresh();
        await home();
      } catch (_) {}
    }
    emit();
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (token != null && foreground) unawaited(refresh().catchError((_) {}));
    });
  }

  Future<void> loadLegal() async {
    final d = await cloud.call('legal');
    if (d is! Map ||
        d['release'] != release ||
        d['product'] != product ||
        d['version'] is! String ||
        d['terms']?['documentType'] != 'sayheath_user_agreement' ||
        d['privacy']?['documentType'] != 'sayheath_privacy_policy') {
      throw const FormatException();
    }
    documents = Map.from(d);
    emit();
  }

  Future<void> sign(
    String email,
    String password,
    bool register,
    bool agreed,
  ) async {
    if (!agreed) {
      throw StateError('Please accept the Terms and Privacy Policy.');
    }
    final d = documents;
    if (d == null) {
      throw StateError(
        'The account documents are not available. Please try again.',
      );
    }
    final n = ++epoch;
    final r = await cloud.call(
      register ? 'register' : 'sign-in',
      body: {
        'email': email,
        'password': password,
        'release': release,
        'legalVersion': d['version'],
        'accepted': true,
      },
    );
    if (n != epoch) return;
    if (r is! Map ||
        r['product'] != product ||
        r['release'] != release ||
        r['userId'] is! String ||
        r['token'] is! String) {
      throw const FormatException();
    }
    member = r['userId'];
    token = r['token'];
    await vault.write(
      key: 'session',
      value: jsonEncode({'userId': member, 'token': token}),
    );
    emit();
    await refresh();
    await home();
  }

  Future<dynamic> call(String path, {Map<String, Object?>? body}) async {
    final n = epoch, t = token;
    if (t == null) throw const CloudError(401);
    try {
      final r = await cloud.call(path, token: t, body: body);
      if (n != epoch || t != token) throw StateError('Session changed.');
      return r;
    } on CloudError catch (e) {
      if (e.status == 401 && n == epoch) await clear();
      rethrow;
    }
  }

  Future<void> clear() async {
    epoch++;
    policyCall++;
    token = null;
    member = null;
    attempt = null;
    measurementTimeout?.cancel();
    policy = Availability.closed;
    daily = [];
    family = [];
    readings = [];
    pulses = [];
    found = [];
    schedule = null;
    knownSchedule = false;
    message = '';
    nextDay = null;
    emit();
    await device.disconnect();
    await vault.delete(key: 'session');
  }

  Future<void> deleteAccount() async {
    final owner = member;
    if (owner == null) throw const CloudError(401);
    await call('delete-account', body: {'confirmSharedAccount': true});
    try {
      await _withQueue(() async {
        for (final f in cloudSensors) {
          await vault.delete(key: _queueKey(owner, f));
        }
        final index = 'pulse.devices.$owner';
        final keys = jsonDecode(await vault.read(key: index) ?? '[]') as List;
        for (final key in keys.whereType<String>()) {
          await vault.delete(key: 'pulse.$key');
        }
        await vault.delete(key: index);
      });
    } finally {
      await clear();
    }
  }

  Future<void> signOut() async {
    try {
      await call('sign-out', body: {});
    } finally {
      await clear();
    }
  }

  Future<void> run(Future<void> Function() fn) async {
    if (busy) return;
    busy = true;
    message = '';
    emit();
    try {
      await fn();
    } catch (e) {
      message = e is StateError
          ? e.message
          : e is CloudError
          ? switch (e.status) {
              401 => 'Sign in again to continue.',
              403 => 'This action is not currently available.',
              409 => 'The information changed. Refresh and try again.',
              503 => 'The service is not ready. Please try again later.',
              _ => 'The server could not complete this request.',
            }
          : 'Could not finish. Check your connection and try again.';
    } finally {
      busy = false;
      emit();
    }
  }

  Future<void> apply(Availability p) async {
    policy = p;
    if (attempt != null && !p.allowed.contains(attempt!['feature'])) {
      attempt = null;
      measurementTimeout?.cancel();
    }
    if (!p.allowed.contains('pulse')) pulses = [];
    if (!p.allowed.contains('scheduledBP')) schedule = null;
    readings = readings.where((r) => p.allowed.contains(r['feature'])).toList();
    emit();
    await device.setPolicy(p);
  }

  Future<void> refresh() async {
    final seq = ++policyCall, n = epoch;
    try {
      final r = await call('policy');
      if (n != epoch || seq != policyCall || !foreground) return;
      await apply(Availability.parse(r, member!, DateTime.now().toUtc()));
    } catch (_) {
      if (n == epoch && seq == policyCall) await apply(Availability.closed);
      rethrow;
    }
  }

  void background() {
    foreground = false;
    policyCall++;
    unawaited(apply(Availability.closed).catchError((_) {}));
  }

  void resume() {
    foreground = true;
    if (token != null) unawaited(refresh().catchError((_) {}));
  }

  Future<void> home({bool more = false}) async {
    final r = await call(
      'activity${more && nextDay != null ? '?cursor=$nextDay' : ''}',
    );
    final items = List<Json>.from(
      (r['items'] as List).map((e) => Map<String, dynamic>.from(e)),
    );
    daily = more ? [...daily, ...items] : items;
    nextDay = r['next'];
    emit();
  }

  Future<void> search() async {
    found = await device.scan();
    if (found.isEmpty) {
      message = 'No devices found. Keep the device nearby and search again.';
    }
    emit();
  }

  Future<void> connect(Candidate c) async {
    await device.connect(c);
    found = [];
    pulses = [];
    schedule = null;
    readings = [];
    attempt = null;
    knownSchedule = (await vault.read(key: 'schedule.$deviceKey')) == 'on';
    await refresh();
    emit();
  }

  Future<void> sync() async {
    final c = device.active, n = epoch, g = device.generation;
    if (c == null) return;
    final records = await device.bridges[c.source]!.syncHealthData();
    var received = 0;
    for (final r in records) {
      if (n != epoch || g != device.generation) return;
      if (r.metric != HealthMetric.steps && r.metric != HealthMetric.sleep) {
        continue;
      }
      final step = r.metric == HealthMetric.steps;
      final v = step
          ? r.values['value'] ?? r.values['steps']
          : r.values['hours'] != null
          ? r.values['hours']! * 60
          : r.values['durationMinutes'] ??
                r.values['minutes'] ??
                (r.unit == 'h' && r.values['value'] != null
                    ? r.values['value']! * 60
                    : null);
      if (v == null || !v.isFinite || v <= 0) continue;
      final local = r.measuredAt.toLocal();
      final ack = await call(
        'activity',
        body: {
          'feature': step ? 'activity' : 'sleep',
          'localDate':
              r.aggregation?.localDate ??
              local.toIso8601String().substring(0, 10),
          'observedAt': r.measuredAt.toUtc().toIso8601String(),
          'offset': local.timeZoneOffset.inMinutes,
          'deviceKey': deviceKey,
          'value': v,
        },
      );
      if (ack['received'] == true) received++;
    }
    await flush();
    await home();
    message = received == 0
        ? 'No new activity or sleep records.'
        : 'Activity and sleep sync complete. US server confirmed $received records.';
    emit();
  }

  Future<void> permission(String f, bool allow) async {
    ++policyCall;
    if (!allow) {
      await apply(Availability.closed);
    }
    await call('permission', body: {'feature': f, 'allow': allow});
    await refresh();
  }

  void require(String f) {
    if (!foreground ||
        !policy.live(DateTime.now()) ||
        !policy.allowed.contains(f) ||
        !device.supports(f)) {
      throw StateError(
        'This feature is not available for the connected device.',
      );
    }
  }

  Future<void> start(String f) async {
    await refresh();
    require(f);
    if (attempt != null) {
      throw StateError('A measurement is already in progress.');
    }
    final id = deviceKey, n = epoch, g = device.generation;
    final ticket = await call(
      'captures',
      body: {'feature': f, 'deviceKey': id},
    );
    if (n != epoch || g != device.generation) return;
    require(f);
    attempt = {
      'id': ticket['id'],
      'feature': f,
      'startedAt': ticket['startedAt'],
      'deviceKey': id,
      'user': member,
    };
    try {
      await device.bridges['U19']!.startMeasurement(DeviceLink.metrics[f]!);
    } catch (_) {
      attempt = null;
      rethrow;
    }
    if (attempt != null) {
      message = 'Measurement started. Wait for a new result from the device.';
      measurementTimeout?.cancel();
      measurementTimeout = Timer(const Duration(minutes: 3), () {
        if (attempt != null) {
          attempt = null;
          message =
              'No new result was confirmed. If still measuring, stop on the device.';
          emit();
        }
      });
    }
    emit();
  }

  Future<void> _saveMeasurement(WearableEvent e) async {
    final a = attempt, c = device.active, user = member, n = epoch;
    if (a == null ||
        user == null ||
        c == null ||
        a['user'] != user ||
        a['deviceKey'] != deviceKey) {
      return;
    }
    final f = a['feature'] as String;
    require(f);
    final r = HealthRecord.fromJson(e.payload),
        time = DateTime.tryParse('${e.payload['measurementStartedAt']}');
    if (r.origin != MeasurementOrigin.appMeasurement ||
        r.source != MeasurementSource.wearable ||
        r.metric != DeviceLink.metrics[f] ||
        r.deviceId != 'urion:${c.info.id}' ||
        time == null ||
        time.isBefore(DateTime.parse(a['startedAt'])) ||
        r.measuredAt.isBefore(DateTime.parse(a['startedAt']))) {
      return;
    }
    final approvedValues = readingValues(f, r.values);
    if (approvedValues == null) return;
    final packet = {
      'id': a['id'],
      'feature': f,
      'deviceKey': deviceKey,
      'values': approvedValues,
      'unit': r.unit,
      'observedAt': r.measuredAt.toUtc().toIso8601String(),
    };
    final key = _queueKey(user, f);
    await _editQueue(key, (rows) {
      if (n == epoch &&
          foreground &&
          policy.live(DateTime.now()) &&
          policy.allowed.contains(f)) {
        rows[a['id'] as String] = packet;
      }
    });
    if (n != epoch) return;
    attempt = null;
    measurementTimeout?.cancel();
    await flush();
    emit();
  }

  bool same(Json packet, dynamic ack) =>
      ack is Map &&
      ack['id'] == packet['id'] &&
      ack['feature'] == packet['feature'] &&
      ack['unit'] == packet['unit'] &&
      DateTime.tryParse(
            '${ack['observedAt']}',
          )?.isAtSameMomentAs(DateTime.parse(packet['observedAt'])) ==
          true &&
      ack['values'] is Map &&
      (packet['values'] as Map).length == (ack['values'] as Map).length &&
      (packet['values'] as Map).entries.every(
        (e) => ack['values'][e.key] == e.value,
      );
  Future<void> flush() async {
    final user = member, n = epoch;
    bool authorized(String f) =>
        user != null &&
        user == member &&
        n == epoch &&
        foreground &&
        policy.live(DateTime.now()) &&
        policy.allowed.contains(f);
    if (user == null) return;
    for (final f in cloudSensors) {
      if (!authorized(f)) continue;
      final key = _queueKey(user, f);
      final items = await _withQueue(() => _readQueue(key));
      for (final item in items.entries) {
        if (!authorized(f)) return;
        final p = Json.from(item.value as Map);
        if (p['feature'] != f || p['id'] != item.key) continue;
        try {
          final ack = await call('captures/${p['id']}/reading', body: p);
          if (!authorized(f) ||
              ack is! Map ||
              ack['received'] != true ||
              !same(p, ack)) {
            continue;
          }
          final stored = await call('captures/${p['id']}');
          if (!authorized(f) || !same(p, stored)) continue;
          await _editQueue(key, (rows) => rows.remove(item.key));
          if (!authorized(f)) return;
          readings = [
            Json.from(stored),
            ...readings.where((r) => r['id'] != item.key),
          ];
          message = 'New reading confirmed on the US server.';
        } on CloudError catch (error) {
          // A ticket invalidated by an earlier withdrawal must not block
          // another, separately authorized capture. Retain it without an ACK.
          if (!{400, 403, 404, 409, 422}.contains(error.status)) rethrow;
          continue;
        }
      }
    }
  }

  Future<void> sensorHistory(String f) async {
    await refresh();
    require(f);
    final records = await call('readings?feature=$f');
    if (policy.allowed.contains(f)) {
      readings = List<Json>.from((records as List).map((r) => Json.from(r)));
      emit();
    }
  }

  Future<void> readPulse() async {
    await refresh();
    require('pulse');
    final key = deviceKey, g = device.generation, n = epoch, c = device.active!;
    final r = await device.bridges['U19']!.readDeviceFeature(
      DeviceFeature.healthAssessment,
    );
    if (n != epoch || g != device.generation) return;
    require('pulse');
    final saved = await vault.read(key: 'pulse.$key');
    final items = <String, UrionPulseRecord>{};
    for (final raw in [
      ...(saved == null ? [] : jsonDecode(saved) as List),
      ...(r['pulseHistory'] as List? ?? []),
    ]) {
      final p = UrionPulseRecord.tryParse(raw, deviceId: 'urion:${c.info.id}');
      if (p != null && p.displayTime() != null) items[p.fingerprint] = p;
    }
    final sorted = items.values.toList()
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    final list = sorted.map((v) => Json.from(v.toMap())).toList();
    if (n != epoch || g != device.generation) return;
    require('pulse');
    await _withQueue(() async {
      if (n != epoch || g != device.generation) return;
      require('pulse');
      final indexKey = 'pulse.devices.$member';
      final keys =
          ((jsonDecode(await vault.read(key: indexKey) ?? '[]')) as List)
              .whereType<String>()
              .toSet()
            ..add(key);
      await vault.write(key: indexKey, value: jsonEncode(keys.toList()));
      await vault.write(key: 'pulse.$key', value: jsonEncode(list));
    });
    if (n == epoch &&
        g == device.generation &&
        policy.allowed.contains('pulse')) {
      pulses = list;
    }
    emit();
  }

  Future<void> checkSchedule() async {
    await refresh();
    require('scheduledBP');
    final key = deviceKey, n = device.generation;
    final value = await device.schedule();
    if (n != device.generation) return;
    schedule = value;
    knownSchedule = value['enabled'] == true;
    await vault.write(
      key: 'schedule.$key',
      value: knownSchedule ? 'on' : 'off',
    );
    emit();
  }

  Future<void> setSchedule(Map<String, Object?> v) async {
    final key = deviceKey, g = device.generation, stop = v['enabled'] == false;
    if (!stop) {
      await refresh();
      require('scheduledBP');
      // A write can reach the wearable even if its acknowledgement is lost.
      // Keep the stop control available until hardware confirms it is off.
      await vault.write(key: 'schedule.$key', value: 'on');
      if (g != device.generation) return;
      require('scheduledBP');
      knownSchedule = true;
      emit();
    } else if (!knownSchedule) {
      throw StateError('No known active schedule.');
    }
    final next = await device.writeSchedule(v, stop: stop);
    if (g != device.generation) return;
    knownSchedule = next['enabled'] == true;
    schedule = next;
    await vault.write(
      key: 'schedule.$key',
      value: knownSchedule ? 'on' : 'off',
    );
    message = 'Settings confirmed by the device.';
    emit();
  }

  Future<void> loadFamily() async {
    family = List<Json>.from(
      (await call('family') as List).map((r) => Json.from(r)),
    );
    emit();
  }

  void _onEvent(WearableEvent e) {
    if (e.type == 'disconnected') {
      attempt = null;
      knownSchedule = false;
      schedule = null;
      pulses = [];
      readings = [];
      message = 'Device disconnected.';
      emit();
    }
    if (e.type == 'healthRecord') {
      unawaited(
        _saveMeasurement(e).catchError((_) {
          message = 'The new reading has not been confirmed by the US server.';
          emit();
        }),
      );
    }
  }
}
