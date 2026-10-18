import 'package:flutter/material.dart';
import '../l10n/global_locale_controller.dart';

class UrionLocalHealthNotice extends StatelessWidget {
  const UrionLocalHealthNotice({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        Localizations.localeOf(context).languageCode == 'zh'
            ? '此设备的血压、心率和血氧记录仅保存在本机。云同步和关爱分享目前只包含活动与睡眠。仅供日常参考，作医疗决定前请咨询医生。'
            : 'Blood pressure, heart rate and oxygen records stay on this phone. Cloud sync and sharing include activity and sleep only. For everyday reference; consult a doctor before medical decisions.',
        key: const Key('urion-local-health-notice'),
      ),
    ),
  );
}

class IosWellnessUnavailablePage extends StatelessWidget {
  const IosWellnessUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.healthData)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.iosActivitySleepScope,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
