import 'package:flutter/material.dart';

import '../l10n/global_locale_controller.dart';

/// A storage-location explanation, independent of the current upload result.
class UsDataStorageNotice extends StatelessWidget {
  const UsDataStorageNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: Container(
        key: const Key('us-data-storage-notice'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: const _UsDataStorageContent(),
      ),
    );
  }
}

class _UsDataStorageContent extends StatelessWidget {
  const _UsDataStorageContent();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.public, size: 20, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.dataResidencyTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.usStorageNotice,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ConnectionHelpPage extends StatelessWidget {
  const ConnectionHelpPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.connectionHelp)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.connectionInstructions,
                  style: const TextStyle(fontSize: 15, height: 1.7),
                ),
                const Divider(height: 32),
                const _UsDataStorageContent(),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('connection-help-privacy-link'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DataPrivacyPage(),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(context.l10n.dataPrivacyTitle)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

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
