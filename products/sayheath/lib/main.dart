import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'src/cloud.dart';
import 'src/session.dart';
import 'shared/domain/feature_models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SayHeathApp(state: MemberState()));
}

const ink = Color(0xff163b32), mint = Color(0xffe1f3e9);

class SayHeathApp extends StatelessWidget {
  const SayHeathApp({super.key, required this.state});
  final MemberState state;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SayHeath',
    debugShowCheckedModeBanner: false,
    locale: const Locale('en'),
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: ink),
      scaffoldBackgroundColor: const Color(0xfff6f8f5),
      useMaterial3: true,
    ),
    home: Shell(state),
  );
}

Future<void> link(String page) async {
  if (!await launchUrl(
    Uri.parse('$origin/public/$page'),
    mode: LaunchMode.externalApplication,
  )) {
    throw StateError('Could not open the page.');
  }
}

class Shell extends StatefulWidget {
  const Shell(this.s, {super.key});
  final MemberState s;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;
  bool agree = false, register = false;
  final email = TextEditingController(), password = TextEditingController();
  MemberState get s => widget.s;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(s.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      s.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      s.background();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    s.timer?.cancel();
    s.measurementTimeout?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Widget button(String name, Future<void> Function() fn, {IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: OutlinedButton.icon(
          onPressed: s.busy ? null : () => s.run(fn),
          icon: Icon(icon ?? Icons.chevron_right),
          label: Text(name),
        ),
      );
  Widget card(String title, Widget child, {String? sub}) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (sub != null)
            Padding(padding: const EdgeInsets.only(top: 5), child: Text(sub)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
  Future<bool> confirm(String title, String body, String ok) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(ok),
            ),
          ],
        ),
      ) ??
      false;
  Widget legalLinks() => Wrap(
    alignment: WrapAlignment.center,
    children: [
      for (final e in {
        'terms': 'Terms',
        'privacy': 'Privacy Policy',
        'support': 'Support',
      }.entries)
        TextButton(
          onPressed: () => s.run(() => link(e.key)),
          child: Text(e.value),
        ),
    ],
  );
  List<Widget> signIn() => [
    const SizedBox(height: 18),
    Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/wordmark.png',
        width: 102,
        semanticLabel: 'SAYDIAN',
      ),
    ),
    const SizedBox(height: 18),
    Text(
      register ? 'Create your account' : 'Welcome to SayHeath',
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: ink,
      ),
    ),
    const SizedBox(height: 8),
    const Text('Your daily activity, sleep and Family Care in one place.'),
    const SizedBox(height: 24),
    card(
      register ? 'Create an account' : 'Sign in',
      AutofillGroup(
        child: Column(
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: password,
              obscureText: true,
              autofillHints: [
                register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I agree to the SayHeath Terms and Privacy Policy.',
              ),
              value: agree,
              onChanged: (v) => setState(() => agree = v == true),
            ),
            legalLinks(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: !agree || s.busy
                    ? null
                    : () => s.run(() async {
                        if (s.documents == null) await s.loadLegal();
                        await s.sign(
                          email.text.trim(),
                          password.text,
                          register,
                          agree,
                        );
                        if (s.token != null) {
                          password.clear();
                          tab = 0;
                        }
                      }),
                child: Text(register ? 'Create account' : 'Sign in'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => register = !register),
              child: Text(
                register
                    ? 'Already have an account? Sign in'
                    : 'Create an account',
              ),
            ),
          ],
        ),
      ),
    ),
  ];
  List<Widget> overview() {
    final cards = <Widget>[];
    for (final k in ['activity', 'sleep']) {
      final rows = s.daily.where((r) => r['feature'] == k).toList();
      cards.add(
        card(
          k == 'activity' ? 'Daily steps' : 'Sleep',
          rows.isEmpty
              ? Text(
                  k == 'activity'
                      ? 'No steps recorded yet.'
                      : 'No sleep recorded yet.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rows.length > 1)
                      Semantics(
                        label: k == 'activity'
                            ? 'Recent daily steps trend'
                            : 'Recent sleep trend',
                        child: SizedBox(
                          height: 48,
                          child: CustomPaint(
                            painter: DailyTrend(
                              rows.take(7).toList().reversed.toList(),
                            ),
                          ),
                        ),
                      ),
                    for (final r in rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          k == 'activity'
                              ? '${r['value']} steps'
                              : '${((r['value'] as num) / 60).toStringAsFixed(1)} hours',
                        ),
                        trailing: Text(
                          '${r['localDate'] ?? r['observedAt']}'.split('T')[0],
                        ),
                      ),
                  ],
                ),
        ),
      );
    }
    return [
      Text('Your overview', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      ...cards,
      button('Refresh activity and sleep', () => s.home(), icon: Icons.refresh),
      if (s.nextDay != null)
        button('Load earlier records', () => s.home(more: true)),
      button('Family Care', () async {
        setState(() => tab = 2);
        await s.loadFamily();
      }, icon: Icons.group_outlined),
    ];
  }

  Future<void> configure() async {
    final d = s.schedule;
    if (d == null) return;
    int hour = d['startHour'] as int,
        day = d['dayIntervalMinutes'] as int,
        night = d['nightIntervalMinutes'] as int;
    const intervals = [60, 90, 120, 180];
    if (!intervals.contains(day)) day = 60;
    if (!intervals.contains(night)) night = 60;
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Set blood pressure schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your wearable may inflate its cuff automatically. Confirm the start hour and both intervals. Follow the device instructions.',
                ),
                for (final entry in [
                  ('Start hour', List.generate(24, (i) => i), hour),
                  ('Day interval (min)', intervals, day),
                  ('Night interval (min)', intervals, night),
                ])
                  DropdownButtonFormField<int>(
                    initialValue: entry.$3,
                    decoration: InputDecoration(labelText: entry.$1),
                    items: entry.$2
                        .map(
                          (v) => DropdownMenuItem(value: v, child: Text('$v')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        set(() {
                          if (entry.$1 == 'Start hour') {
                            hour = v;
                          } else if (entry.$1.startsWith('Day')) {
                            day = v;
                          } else {
                            night = v;
                          }
                        });
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm schedule'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      await s.setSchedule({
        'enabled': true,
        'startHour': hour,
        'dayIntervalMinutes': day,
        'nightIntervalMinutes': night,
      });
    }
  }

  List<Widget> devices() {
    final c = s.device.active;
    return [
      card(
        c?.info.name ?? 'Connect a device',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (c == null) ...[
              button(
                'Search for devices',
                s.search,
                icon: Icons.bluetooth_searching,
              ),
              for (final v in s.found)
                ListTile(
                  title: Text(v.info.name),
                  subtitle: Text('${v.source} · ${v.info.id}'),
                  onTap: s.busy ? null : () => s.run(() => s.connect(v)),
                ),
            ] else ...[
              Text('${c.source} · Connected'),
              const SizedBox(height: 8),
              button('Sync device', s.sync, icon: Icons.sync),
              button('Disconnect', () async {
                await s.device.disconnect();
                s.attempt = null;
                s.found = [];
                s.emit();
              }),
            ],
          ],
        ),
        sub: c == null
            ? 'Turn on Bluetooth and keep your wearable nearby.'
            : null,
      ),
      if (c?.source == 'U19' && s.policy.live(DateTime.now()))
        for (final f in labels.keys.where(s.policy.enabled.contains))
          card(
            labels[f]!,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!s.policy.allowed.contains(f))
                  button('Review permission', () async {
                    final description = cloudSensors.contains(f)
                        ? 'New readings you choose to take will be saved to your account on servers in the United States.'
                        : f == 'pulse'
                        ? 'Your device’s pulse indices are stored encrypted on this iPhone.'
                        : 'You will choose a schedule separately before it is written to your device.';
                    if (await confirm(labels[f]!, description, 'Allow')) {
                      await s.permission(f, true);
                    }
                  })
                else ...[
                  if (!s.device.supports(f))
                    const Text('Not available from this connected device.')
                  else if (cloudSensors.contains(f)) ...[
                    button('Measure now', () async {
                      if (await confirm(
                        labels[f]!,
                        'Wear your device as instructed. Stop the measurement on the device if you need to.',
                        'Start measurement',
                      )) {
                        await s.start(f);
                      }
                    }),
                    button('View my readings', () => s.sensorHistory(f)),
                    for (final r
                        in s.readings.where((r) => r['feature'] == f).take(12))
                      Text(
                        '${r['observedAt'].toString().split('.').first} · ${(r['values'] as Map).values.join('/')} ${r['unit']}',
                      ),
                  ] else if (f == 'pulse') ...[
                    button('Read device history', s.readPulse),
                    button('Start pulse measurement', () async {
                      if (await confirm(
                        'Pulse insights',
                        'Wear your device as instructed. Stop on the device if needed.',
                        'Start',
                      )) {
                        s.require('pulse');
                        await s.device.bridges['U19']!.writeDeviceFeature(
                          DeviceFeature.healthAssessment,
                          {'operation': 'start'},
                        );
                      }
                    }),
                    if (s.pulses.isNotEmpty) ...[
                      Text('Saved readings (${s.pulses.length})'),
                      if (s.pulses.map((r) => r['measuredAt']).toSet().length >=
                          2)
                        SizedBox(
                          height: 88,
                          child: CustomPaint(painter: PulseChart(s.pulses)),
                        ),
                      const Text('Device indices: flow / vitality / moisture'),
                      for (final r in s.pulses.take(50))
                        Text(
                          '${r['measuredAt'].toString().split('T').join(' ').split('.').first} · ${r['bloodStasis']} / ${r['qiBlood']} / ${r['dampness']}',
                        ),
                    ],
                  ] else ...[
                    button('Read schedule from device', s.checkSchedule),
                    if (s.schedule != null) ...[
                      Text(
                        s.schedule!['enabled'] == true
                            ? 'On · start ${s.schedule!['startHour']}:00; day ${s.schedule!['dayIntervalMinutes']} min, night ${s.schedule!['nightIntervalMinutes']} min'
                            : 'Device schedule is off.',
                      ),
                      button('Set schedule', configure),
                    ],
                  ],
                  TextButton(
                    onPressed: s.busy
                        ? null
                        : () => s.run(() => s.permission(f, false)),
                    child: const Text('Withdraw permission'),
                  ),
                ],
              ],
            ),
          ),
      if (s.knownSchedule && c?.source == 'U19')
        button('Stop active device schedule', () async {
          if (await confirm(
            'Stop schedule?',
            'The app will verify the change by reading the settings from your device.',
            'Stop schedule',
          )) {
            await s.setSchedule({'enabled': false});
          }
        }),
      if (s.attempt != null)
        const Text(
          'If you need to stop an active measurement, use the stop control on your wearable.',
        ),
      TextButton(
        onPressed: () => s.run(() => link('privacy')),
        child: const Text('Device data and privacy'),
      ),
    ];
  }

  Future<void> familyEditor([Json? r]) async {
    final owner = r == null || r['owner'] == true;
    String contact = '';
    bool a = (r?[owner ? 'activity' : 'acceptedActivity'] == true),
        b = (r?[owner ? 'sleep' : 'acceptedSleep'] == true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(
            r == null
                ? 'Invite a family member'
                : owner
                ? 'Choose what to share'
                : 'Accept shared categories',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (r == null)
                TextField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Family member’s account email',
                  ),
                  onChanged: (v) => contact = v,
                ),
              CheckboxListTile(
                title: const Text('Activity'),
                value: a,
                onChanged: owner || r['activity'] == true
                    ? (v) => set(() => a = v == true)
                    : null,
              ),
              CheckboxListTile(
                title: const Text('Sleep'),
                value: b,
                onChanged: owner || r['sleep'] == true
                    ? (v) => set(() => b = v == true)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(r == null ? 'Invite' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await s.call(
      r == null ? 'family' : 'family/${r['id']}/${owner ? 'offer' : 'accept'}',
      body: {if (r == null) 'email': contact.trim(), 'activity': a, 'sleep': b},
    );
    await s.loadFamily();
  }

  List<Widget> care() => [
    card(
      'Family Care',
      const Text(
        'Choose who can see your activity and sleep. Sharing starts only after the other person accepts.',
      ),
    ),
    button('Invite a family member', familyEditor),
    button('Refresh sharing', s.loadFamily),
    for (final r in s.family)
      card(
        '${r['other']}',
        Column(
          children: [
            Text(
              r['owner'] == true
                  ? 'You share with this person.'
                  : 'This person shares with you.',
            ),
            button('Manage categories', () => familyEditor(r)),
            if (r['owner'] == false &&
                (r['acceptedSleep'] == true || r['acceptedActivity'] == true))
              button('View shared activity', () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SharedPage(s, '${r['id']}'),
                  ),
                );
              }),
            button('End sharing', () async {
              if (await confirm(
                'End sharing?',
                'Both people will lose access to this relationship.',
                'End sharing',
              )) {
                await s.call('family/${r['id']}/end', body: {});
                await s.loadFamily();
              }
            }),
          ],
        ),
      ),
  ];
  List<Widget> account() => [
    card(
      'Your account',
      const Text(
        'SayHeath cloud data is stored on servers in the United States.',
      ),
    ),
    legalLinks(),
    button('Sign out', s.signOut),
    button('Delete shared account', () async {
      if (await confirm(
        'Delete your shared account?',
        'Deletion is scheduled after seven days and affects all services using this account. You will be signed out.',
        'Request deletion',
      )) {
        await s.deleteAccount();
      }
    }),
  ];
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: s,
    builder: (c, _) {
      final auth = s.member != null;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            auth
                ? ['SayHeath', 'Device', 'Family Care', 'Account'][tab]
                : 'SayHeath',
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              if (s.busy) const LinearProgressIndicator(),
              if (s.message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Semantics(liveRegion: true, child: Text(s.message)),
                ),
              ...(!auth
                  ? signIn()
                  : switch (tab) {
                      0 => overview(),
                      1 => devices(),
                      2 => care(),
                      _ => account(),
                    }),
            ],
          ),
        ),
        bottomNavigationBar: !auth
            ? null
            : NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: (v) {
                  setState(() => tab = v);
                  s.message = '';
                  if (v == 2) unawaited(s.run(s.loadFamily));
                  if (v == 0) unawaited(s.run(() => s.home()));
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.directions_walk),
                    label: 'Activity',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.watch_outlined),
                    label: 'Device',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    label: 'Family Care',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Account',
                  ),
                ],
              ),
      );
    },
  );
}

class DailyTrend extends CustomPainter {
  DailyTrend(this.rows);
  final List<Json> rows;
  @override
  void paint(Canvas canvas, Size size) {
    final times = rows
        .map(
          (r) => DateTime.tryParse(
            '${r['localDate'] ?? r['observedAt']}',
          )?.millisecondsSinceEpoch,
        )
        .toList();
    final ys = rows.map((r) => (r['value'] as num).toDouble()).toList();
    if (ys.length < 2 || times.contains(null)) return;
    final span =
        times.reduce((a, b) => a! > b! ? a : b)! -
        times.reduce((a, b) => a! < b! ? a : b)!;
    if (span == 0) return;
    final minTime = times.reduce((a, b) => a! < b! ? a : b)!;
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final points = List.generate(
      ys.length,
      (i) => Offset(
        4 + (times[i]! - minTime) / span * (size.width - 8),
        size.height - 5 - (maxY > 0 ? ys[i] / maxY : 0) * (size.height - 10),
      ),
    );
    final stroke = Paint()
      ..color = ink
      ..strokeWidth = 2;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 2.5, stroke);
      if (i > 0) canvas.drawLine(points[i - 1], points[i], stroke);
    }
  }

  @override
  bool shouldRepaint(DailyTrend old) => old.rows != rows;
}

class PulseChart extends CustomPainter {
  PulseChart(this.rows);
  final List<Json> rows;
  @override
  void paint(Canvas c, Size size) {
    final sorted = rows.reversed.toList(),
        a = DateTime.parse(sorted.first['measuredAt']).millisecondsSinceEpoch,
        b = DateTime.parse(sorted.last['measuredAt']).millisecondsSinceEpoch;
    if (b <= a) return;
    for (final entry in {
      'bloodStasis': Colors.teal,
      'qiBlood': Colors.orange,
      'dampness': Colors.indigo,
    }.entries) {
      final p = Path();
      for (var i = 0; i < sorted.length; i++) {
        final row = sorted[i],
            x =
                (DateTime.parse(row['measuredAt']).millisecondsSinceEpoch - a) /
                (b - a) *
                size.width,
            y =
                size.height -
                4 -
                (row[entry.key] as num) / 10 * (size.height - 8);
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = entry.value,
      );
    }
  }

  @override
  bool shouldRepaint(PulseChart p) => !identical(rows, p.rows);
}

class SharedPage extends StatefulWidget {
  const SharedPage(this.s, this.id, {super.key});
  final MemberState s;
  final String id;
  @override
  State<SharedPage> createState() => _SharedPageState();
}

class _SharedPageState extends State<SharedPage> with WidgetsBindingObserver {
  List<Json> rows = [];
  Timer? t;
  bool live = true;
  String state = 'Loading…';
  int revision = 0;
  Future<void> load() async {
    final n = ++revision;
    try {
      final r = await widget.s.call('family/${widget.id}/read', body: {});
      if (mounted && live && n == revision) {
        setState(() {
          rows = List<Json>.from((r['items'] as List).map((e) => Json.from(e)));
          state = 'No shared records.';
        });
      }
    } catch (_) {
      if (mounted && n == revision) {
        setState(() {
          rows = [];
          state = 'Shared records are not available.';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
    t = Timer.periodic(const Duration(seconds: 10), (_) {
      if (live) unawaited(load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState v) {
    live = v == AppLifecycleState.resumed;
    revision++;
    if (!live) {
      setState(() => rows = []);
    } else {
      unawaited(load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Shared activity and sleep')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: rows.isEmpty
          ? [Text(state)]
          : [
              for (final r in rows)
                ListTile(
                  title: Text('${r['value']} ${r['unit']}'),
                  subtitle: Text('${r['localDate'] ?? r['observedAt']}'),
                ),
            ],
    ),
  );
}
