import 'package:flutter/material.dart';

import '../l10n/global_locale_controller.dart';

/// Additional operator-provided storage information. This page never records
/// consent or substitutes for the versioned legal document from the server.
class DataPrivacyPage extends StatelessWidget {
  const DataPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sections = [
      (l.dataResidencyTitle, l.dataResidencyBody, Icons.public),
      (l.dataLocalTitle, l.dataLocalBody, Icons.phonelink_lock),
      (l.dataChoiceTitle, l.dataChoiceBody, Icons.privacy_tip_outlined),
      (l.dataThirdPartyTitle, l.dataThirdPartyBody, Icons.info_outline),
    ];
    return Scaffold(
      key: const Key('data-privacy-page'),
      appBar: AppBar(title: Text(l.dataPrivacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final section in sections)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(section.$3),
                    const SizedBox(height: 12),
                    Text(
                      section.$1,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      section.$2,
                      style: const TextStyle(height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DataPrivacyLink extends StatelessWidget {
  const DataPrivacyLink({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const Key('data-privacy-link'),
    icon: const Icon(Icons.public, size: 18),
    label: Text(context.l10n.dataPrivacyTitle),
    onPressed: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DataPrivacyPage())),
  );
}
