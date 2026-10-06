import 'package:flutter/material.dart';
import '../l10n/global_locale_controller.dart';

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
