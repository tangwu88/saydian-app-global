import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/global_account.dart';
import '../domain/global_care.dart';
import '../domain/models.dart';
import '../l10n/ui_labels.dart';
import 'health_trend_page.dart';
import 'app_theme.dart';
import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';

class GlobalCarePage extends StatefulWidget {
  const GlobalCarePage({required this.controller, super.key});
  final AppController controller;
  @override
  State<GlobalCarePage> createState() => _GlobalCareOverviewState();
}

class _GlobalCareOverviewState extends State<GlobalCarePage> {
  List<GlobalCareRelationship> _members = const [];
  List<HealthRecord> _latest = const [];
  Set<String> _metrics = const {};
  String? _selected;
  late final String? _owner;
  int _generation = 0;
  bool _loading = true;
  bool _failed = false;
  bool get _sameOwner =>
      _owner != null && _owner == widget.controller.session?.accountKey;

  @override
  void initState() {
    super.initState();
    _owner = widget.controller.session?.accountKey;
    widget.controller.addListener(_accountChanged);
    unawaited(_load());
  }

  void _accountChanged() {
    if (!mounted || _sameOwner) return;
    _generation++;
    setState(() {
      _members = const [];
      _latest = const [];
      _metrics = const {};
      _selected = null;
      _loading = false;
      _failed = false;
    });
  }

  @override
  void dispose() {
    _generation++;
    widget.controller.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (!_sameOwner) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
      _latest = const [];
      _metrics = const {};
    });
    try {
      final relationships = await widget.controller.globalCareRelationships();
      if (!mounted || generation != _generation || !_sameOwner) return;
      final members = relationships
          .where((r) => r.active && !r.received)
          .toList();
      final selected =
          members.where((r) => r.id == _selected).firstOrNull ??
          members.firstOrNull;
      setState(() {
        _members = members;
        _selected = selected?.id;
      });
      if (selected != null) {
        final summary = await widget.controller.globalCareSummary(selected.id);
        if (!mounted || generation != _generation || !_sameOwner) return;
        final metrics = (summary['metrics'] as List? ?? const [])
            .whereType<String>()
            .toSet();
        final records = (summary['records'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (r) => globalCareHealthRecord(r.map((k, v) => MapEntry('$k', v))),
            )
            .where((r) => metrics.contains(r.metric.wireName))
            .toList();
        setState(() {
          _metrics = metrics;
          _latest = records;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation && _sameOwner) {
        setState(() {
          _failed = true;
          _latest = const [];
          _metrics = const {};
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _manage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GlobalCareManagementPage(controller: widget.controller),
      ),
    );
    if (mounted && _sameOwner) await _load();
  }

  Future<void> _open(GlobalCareRelationship member, HealthMetric metric) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _GlobalCareRecordsPage(
          controller: widget.controller,
          relationship: member,
          metric: metric.wireName,
          owner: _owner!,
        ),
      ),
    );
    if (mounted && _sameOwner) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final member = _members.where((r) => r.id == _selected).firstOrNull;
    return Scaffold(
      key: const Key('global-care-page'),
      body: !_sameOwner
          ? Center(child: Text(l.signInCloudHint))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.remoteCare,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _manage,
                        icon: const Icon(Icons.manage_accounts_outlined),
                        label: Text(l.manageCare),
                      ),
                    ],
                  ),
                  if (_members.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selected),
                      initialValue: _selected,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: [
                        for (final row in _members)
                          DropdownMenuItem(
                            value: row.id,
                            child: Text(
                              row.name.isEmpty ? l.defaultUser : row.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) {
                              _selected = value;
                              unawaited(_load());
                            },
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_loading) const LinearProgressIndicator(),
                  if (_failed)
                    Card(
                      child: ListTile(
                        title: Text(l.serviceUnavailable),
                        trailing: TextButton(
                          onPressed: _load,
                          child: Text(l.retry),
                        ),
                      ),
                    ),
                  if (!_loading && !_failed && member == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 48,
                              color: SaydianColors.muted,
                            ),
                            const SizedBox(height: 12),
                            Text(l.noData),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _manage,
                              icon: const Icon(Icons.person_add_outlined),
                              label: Text(l.addCare),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!_loading &&
                      !_failed &&
                      member != null &&
                      _metrics.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.carePermissionDenied),
                      ),
                    ),
                  if (!_loading && !_failed && member != null)
                    for (final metric in HealthMetric.values.where(
                      (m) => _metrics.contains(m.wireName),
                    ))
                      _card(member, metric),
                ],
              ),
            ),
    );
  }

  Widget _card(GlobalCareRelationship member, HealthMetric metric) {
    final record = _latest.where((r) => r.metric == metric).firstOrNull;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: SaydianColors.skySoft,
          child: Icon(
            metric == HealthMetric.ecg
                ? Icons.monitor_heart_outlined
                : metric == HealthMetric.sleep
                ? Icons.bedtime_outlined
                : Icons.favorite_outline,
          ),
        ),
        title: Text(
          context.l10n.metricName(metric),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record == null
                    ? context.l10n.noData
                    : metric == HealthMetric.ecg
                    ? context.l10n.ecgDetailTitle
                    : '${record.displayValue} ${record.unit}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: SaydianColors.ink,
                ),
              ),
              if (record != null)
                Text(
                  DateFormat.yMMMd(
                    context.l10n.localeName,
                  ).add_jm().format(record.measuredAt.toLocal()),
                  style: const TextStyle(
                    fontSize: 12,
                    color: SaydianColors.muted,
                  ),
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(member, metric),
      ),
    );
  }
}

class GlobalCareManagementPage extends StatefulWidget {
  const GlobalCareManagementPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<GlobalCareManagementPage> createState() =>
      _GlobalCareManagementPageState();
}

class _GlobalCareManagementPageState extends State<GlobalCareManagementPage> {
  List<GlobalCareRelationship> _relationships = const [];
  bool _loading = true;
  bool _working = false;
  bool _failed = false;
  int _generation = 0;
  late String? _owner;
  bool get _sameOwner =>
      _owner != null && _owner == widget.controller.session?.accountKey;

  @override
  void initState() {
    super.initState();
    _owner = widget.controller.session?.accountKey;
    widget.controller.addListener(_accountChanged);
    unawaited(_load());
  }

  void _accountChanged() {
    if (_sameOwner || !mounted) return;
    _generation++;
    setState(() {
      _relationships = const [];
      _loading = false;
      _failed = false;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_accountChanged);
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (!_sameOwner) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await widget.controller.globalCareRelationships();
      if (mounted && generation == _generation && _sameOwner) {
        setState(() => _relationships = rows);
      }
    } catch (_) {
      if (mounted && generation == _generation && _sameOwner) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _operate(Future<void> Function() action) async {
    if (_working || !_sameOwner) return;
    setState(() => _working = true);
    try {
      await action();
      if (!mounted || !_sameOwner) return;
      await _load();
      unawaited(widget.controller.refreshCare());
      unawaited(widget.controller.refreshCareInvitations());
    } catch (_) {
      if (mounted && _sameOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.serviceUnavailable)),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _invite() async {
    final input = TextEditingController();
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(dialog.l10n.addCare),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dialog.l10n.careInviteHint),
              const SizedBox(height: 12),
              TextFormField(
                controller: input,
                key: const Key('global-care-contact'),
                decoration: InputDecoration(
                  labelText: dialog.l10n.emailOrPhone,
                ),
                validator: (value) {
                  try {
                    GlobalAccountIdentity.parse(value ?? '');
                    return null;
                  } catch (_) {
                    return dialog.l10n.invalidCareContact;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(dialog.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState?.validate() == true) {
                Navigator.pop(dialog, input.text);
              }
            },
            child: Text(dialog.l10n.send),
          ),
        ],
      ),
    );
    // Dialog animations can still refer to this controller until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
    if (value == null || !mounted || !_sameOwner) return;
    await _operate(() => widget.controller.globalInviteCare(value));
  }

  Future<void> _permissions(GlobalCareRelationship row) async {
    final selected = {...row.metrics};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: Text(dialog.l10n.sharedMeasurements),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dialog.l10n.careSharingHint),
                  for (final entry in _metricLabels(dialog).entries)
                    CheckboxListTile(
                      title: Text(entry.value),
                      value: selected.contains(entry.key),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (checked) => update(() {
                        if (checked == true) {
                          selected.add(entry.key);
                        } else {
                          selected.remove(entry.key);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(dialog.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, selected),
              child: Text(dialog.l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted || !_sameOwner) return;
    await _operate(() => widget.controller.globalShareCare(row.id, result));
  }

  Future<void> _revoke(GlobalCareRelationship row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(dialog.l10n.stopSharing),
        content: Text(row.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(dialog.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(dialog.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && _sameOwner) {
      await _operate(() => widget.controller.globalRevokeCare(row.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      key: const Key('global-care-management-page'),
      appBar: AppBar(title: Text(context.l10n.manageCare)),
      body: !_sameOwner
          ? Center(child: Text(l.signInCloudHint))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FilledButton.icon(
                    onPressed: _working ? null : _invite,
                    icon: const Icon(Icons.person_add_outlined),
                    label: Text(l.addCare),
                  ),
                  if (_loading || _working) const LinearProgressIndicator(),
                  if (_failed) ...[
                    Text(l.serviceUnavailable),
                    TextButton(onPressed: _load, child: Text(l.retry)),
                  ],
                  if (!_loading && !_failed && _relationships.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(l.noData)),
                    ),
                  for (final row in _relationships)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.name.isEmpty ? l.defaultUser : row.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              row.active
                                  ? l.careActive
                                  : row.status == 'pending'
                                  ? l.carePending
                                  : l.careClosed,
                            ),
                            if (row.received && row.status == 'pending')
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: _working
                                        ? null
                                        : () => _operate(
                                            () => widget.controller
                                                .globalRespondCare(
                                                  row.id,
                                                  true,
                                                ),
                                          ),
                                    child: Text(l.accept),
                                  ),
                                  TextButton(
                                    onPressed: _working
                                        ? null
                                        : () => _operate(
                                            () => widget.controller
                                                .globalRespondCare(
                                                  row.id,
                                                  false,
                                                ),
                                          ),
                                    child: Text(l.decline),
                                  ),
                                ],
                              ),
                            if (row.active && row.received)
                              TextButton(
                                onPressed: _working
                                    ? null
                                    : () => _permissions(row),
                                child: Text(l.sharedMeasurements),
                              ),
                            if (row.active && !row.received) ...[
                              if (row.metrics.isEmpty)
                                Text(l.carePermissionDenied),
                              for (final metric in row.metrics.where(
                                _metricLabels(context).containsKey,
                              ))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_metricLabels(context)[metric]!),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _working
                                      ? null
                                      : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                _GlobalCareRecordsPage(
                                                  controller: widget.controller,
                                                  relationship: row,
                                                  metric: metric,
                                                  owner: _owner!,
                                                ),
                                          ),
                                        ),
                                ),
                            ],
                            if (row.active || row.status == 'pending')
                              TextButton(
                                onPressed: _working ? null : () => _revoke(row),
                                child: Text(l.stopSharing),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

Map<String, String> _metricLabels(BuildContext context) {
  final l = context.l10n;
  return {
    'steps': l.steps,
    'distance': l.distance,
    'calories': l.calories,
    'sleep': l.sleep,
    'heart_rate': l.heartRate,
    'blood_oxygen': l.bloodOxygen,
    'blood_pressure': l.bloodPressure,
    'blood_glucose': l.bloodGlucose,
    'temperature': l.bodyTemperature,
    'hrv': l.hrv,
    'ecg': l.ecg,
    'body_composition': l.bodyComposition,
    'blood_composition': l.bloodComposition,
  };
}

class _GlobalCareRecordsPage extends StatelessWidget {
  const _GlobalCareRecordsPage({
    required this.controller,
    required this.relationship,
    required this.metric,
    required this.owner,
  });
  final AppController controller;
  final GlobalCareRelationship relationship;
  final String metric;
  final String owner;
  @override
  Widget build(BuildContext context) => HealthTrendPage(
    controller: controller,
    metric: HealthMetric.fromWire(metric),
    memberName: relationship.name.isEmpty
        ? context.l10n.defaultUser
        : relationship.name,
    relationshipId: relationship.id,
    ownerAccountKey: owner,
    recordLoader: (start, end) async {
      final rows = await controller.globalCareRecordsRange(
        relationship.id,
        metric,
        start,
        end,
      );
      if (controller.session?.accountKey != owner) {
        throw const FormatException('Session changed');
      }
      return rows.map(globalCareHealthRecord).toList();
    },
  );
}
