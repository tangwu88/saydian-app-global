// Physical QA entry point only: flutter run --debug -t tool/xr_connection_probe.dart.
// No account, feature override, cloud call, measurement, activity sync or schedule write.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sayheath/src/cloud.dart';
import 'package:sayheath/src/device.dart';

void main() {
  if (!kDebugMode) throw UnsupportedError('Debug builds only.');
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final link = DeviceLink((_) {});
  bool busy = false;
  String progress = 'Starting the connection check…';
  void report(String code, String message) {
    debugPrint('SAYHEATH_XR_CHECK $code');
    if (mounted) setState(() => progress = message);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  }

  Future<void> run() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      report(
        'scanning',
        'Allow Bluetooth if asked. Keep U19S ending 27:65 nearby.',
      );
      await link.prepare();
      final radios = await link.bridges['U19']!.scanDevices();
      final targets = radios
          .where(
            (d) =>
                (d.hardwareAddress ?? d.id).toUpperCase() ==
                    'CB:BF:62:4F:27:65' &&
                d.name.toUpperCase().contains('U19S'),
          )
          .toList();
      if (targets.length != 1) {
        report(
          'not_found',
          'The specified U19S is not advertising. Disconnect it from other phones and retry.',
        );
        return;
      }
      await link.connect(Candidate('U19', targets.single));
      final denied = [
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
      ].every((c) => !link.permits(c, [1]));
      if (link.active == null ||
          !denied ||
          link.policy != Availability.closed) {
        throw StateError('unexpected gate');
      }
      report(
        'connected_closed',
        'Verified: the selected U19S connected. Optional measurement commands are closed. No measurement or upload was requested.',
      );
    } on PlatformException catch (e) {
      report(
        'native_${e.code.replaceAll(RegExp(r"[^a-zA-Z_0-9]"), "")}',
        'Bluetooth was not ready. Check permission, unlock this iPhone and retry.',
      );
    } catch (_) {
      report(
        'incomplete',
        'Could not confirm the connection. Check the device and retry.',
      );
    } finally {
      try {
        await link.disconnect();
      } catch (_) {}
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SayHeath · Connection check')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(progress),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : run,
              child: const Text('Retry connection check'),
            ),
          ],
        ),
      ),
    ),
  );
}
