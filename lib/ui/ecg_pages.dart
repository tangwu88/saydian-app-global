part of 'prototype_pages.dart';

class HealthRecordDetailPage extends StatelessWidget {
  const HealthRecordDetailPage({
    required this.controller,
    required this.record,
    this.relationshipId,
    this.ownerAccountKey,
    super.key,
  });

  final AppController controller;
  final HealthRecord record;
  final String? relationshipId;
  final String? ownerAccountKey;

  @override
  Widget build(BuildContext context) {
    if (ownerAccountKey == null) return _buildRecord(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ownerAccountKey == controller.session?.accountKey
          ? _buildRecord(context)
          : Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(context.l10n.signInCloudHint)),
            ),
    );
  }

  Widget _buildRecord(BuildContext context) {
    final projected = controller.wellnessPolicy.projectRecord(this.record);
    if (projected == null) return const IosWellnessUnavailablePage();
    final record = projected;
    if (record.metric == HealthMetric.ecg) {
      return _EcgRecordDetailPage(
        record: record,
        controller: controller,
        relationshipId: relationshipId,
      );
    }
    final time = HealthAnalysisService.displayTime(record);
    final date = record.aggregation != null
        ? DateFormat.yMMMd(context.l10n.localeName).format(time)
        : Localizations.localeOf(context).languageCode == 'zh'
        ? DateFormat('yyyy-MM-dd HH:mm').format(time)
        : DateFormat.yMMMd(context.l10n.localeName).add_jm().format(time);
    final values = <MapEntry<String, num>>[...record.values.entries];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.metricDetails(context.l10n.metricName(record.metric)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    record.displayValue,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _localizedRecordUnit(context, record.unit),
                    style: const TextStyle(color: SaydianColors.muted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    date,
                    style: const TextStyle(color: SaydianColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _usText(
                      context,
                      'Source: ${_englishRecordOrigin(record.origin)}',
                      '数据来源：${record.origin.label}',
                    ),
                    style: const TextStyle(
                      color: SaydianColors.techBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (values.length > 1) ...[
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < values.length; index++) ...[
                    ListTile(
                      title: Text(
                        _localizedHealthValueLabel(
                          context,
                          values[index].key,
                          record.metric,
                        ),
                      ),
                      trailing: Text(
                        '${_formatRecordNumber(values[index].value)} ${_localizedRecordUnit(context, healthValueUnit(values[index].key, record))}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (index != values.length - 1) const Divider(indent: 16),
                  ],
                ],
              ),
            ),
          ],
          if (record.metric == HealthMetric.ecg &&
              record.samples.length > 1) ...[
            const SizedBox(height: 12),
            _EcgWaveformCard(
              samples: record.samples,
              sampleFrequency: record.values['sampleFrequency']?.toInt(),
              calibrated: record.rawVersion >= 2,
              lowSignal: record.quality == 'suspect',
            ),
          ],
          const SizedBox(height: 12),
          if (!controller.isIosWellnessEdition)
            Builder(
              builder: (context) {
                final interpretation = interpretHealthRecord(
                  record,
                  english: Localizations.localeOf(context).languageCode != 'zh',
                );
                return FeatureStateCard(
                  message: interpretation.title,
                  detail: interpretation.detail,
                  icon: record.metric == HealthMetric.ecg
                      ? Icons.monitor_heart_outlined
                      : Icons.insights_rounded,
                  color: SaydianColors.brandRed,
                );
              },
            ),
          const SizedBox(height: 12),
          if (!controller.isIosWellnessEdition)
            FeatureStateCard(
              message: context.l10n.longTermTrendHint,
              detail: context.l10n.measurementVariationHint,
              icon: Icons.health_and_safety_outlined,
              color: SaydianColors.green,
            ),
        ],
      ),
    );
  }

  String _formatRecordNumber(num value) =>
      value is int || value == value.round()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
}

class _EcgRecordDetailPage extends StatefulWidget {
  const _EcgRecordDetailPage({
    required this.record,
    required this.controller,
    this.relationshipId,
  });

  final HealthRecord record;
  final AppController controller;
  final String? relationshipId;

  @override
  State<_EcgRecordDetailPage> createState() => _EcgRecordDetailPageState();
}

class _EcgRecordDetailPageState extends State<_EcgRecordDetailPage> {
  int _section = 0;
  late HealthRecord _record;
  late final String? _owner;
  bool _loading = false;
  bool _failed = false;
  bool _allowed = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _owner = widget.controller.session?.accountKey;
    widget.controller.addListener(_accountChanged);
    if (_record.samples.isEmpty &&
        widget.controller.isGlobalEdition &&
        _owner != null) {
      unawaited(_loadWaveform());
    }
  }

  void _accountChanged() {
    if (mounted && _owner != widget.controller.session?.accountKey) {
      _generation++;
      setState(() {
        _allowed = false;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.controller.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _loadWaveform() async {
    if (!_allowed || _owner != widget.controller.session?.accountKey) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final record = await widget.controller.loadEcgWaveform(
        widget.record,
        relationshipId: widget.relationshipId,
      );
      if (!mounted ||
          generation != _generation ||
          _owner != widget.controller.session?.accountKey) {
        return;
      }
      setState(() => _record = record);
    } on ApiException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = error.statusCode != 404;
        if (widget.relationshipId != null &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          _allowed = false;
        }
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.ecgDetailTitle)),
        body: Center(child: Text(context.l10n.carePermissionDenied)),
      );
    }
    final record = _record;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.ecgDetailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_failed)
            Card(
              child: ListTile(
                title: Text(context.l10n.serviceUnavailable),
                trailing: TextButton(
                  onPressed: _loadWaveform,
                  child: Text(context.l10n.retry),
                ),
              ),
            ),
          _EcgSummaryCard(record: record),
          const SizedBox(height: 12),
          _EcgWaveformCard(
            samples: record.samples,
            sampleFrequency: record.values['sampleFrequency']?.toInt(),
            calibrated: record.rawVersion >= 2,
            lowSignal: record.quality == 'suspect',
          ),
          const SizedBox(height: 14),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.monitor_heart_outlined),
                label: Text('测量指标'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.health_and_safety_outlined),
                label: Text('风险分析'),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (value) =>
                setState(() => _section = value.first),
          ),
          const SizedBox(height: 12),
          if (_section == 0)
            _EcgMedicalSection(record: record)
          else
            _EcgRiskSection(record: record),
          const SizedBox(height: 16),
          if (widget.relationshipId == null)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'ecg-full-report'),
                  builder: (_) => _EcgFullReportPage(record: record),
                ),
              ),
              icon: const Icon(Icons.description_outlined),
              label: Text(context.l10n.viewFullReport),
            ),
          const SizedBox(height: 12),
          FeatureStateCard(
            message: context.l10n.ecgReferenceHint,
            detail: context.l10n.ecgVariationSafety,
            icon: Icons.info_outline_rounded,
            color: SaydianColors.brandRed,
          ),
        ],
      ),
    );
  }
}

class _EcgSummaryCard extends StatelessWidget {
  const _EcgSummaryCard({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    final measuredAt = record.measuredAt.toLocal();
    final date = DateFormat('yyyy-MM-dd HH:mm').format(measuredAt);
    return Card(
      color: const Color(0xFF9D1830),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monitor_heart_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '本次心电记录',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: const TextStyle(color: Color(0xFFEECBD2)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    record.origin.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _EcgSummaryValue(
                    label: '心率',
                    value: _ecgValue(record, const ['meanHeartRate', 'value']),
                    unit: 'bpm',
                  ),
                ),
                Expanded(
                  child: _EcgSummaryValue(
                    label: 'QT',
                    value: _ecgValue(record, const ['averageTimeInterval']),
                    unit: 'ms',
                  ),
                ),
                Expanded(
                  child: _EcgSummaryValue(
                    label: 'HRV',
                    value: _ecgValue(record, const ['averageHRV', 'hrv']),
                    unit: 'ms',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EcgSummaryValue extends StatelessWidget {
  const _EcgSummaryValue({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final num? value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: Color(0xFFEECBD2))),
      const SizedBox(height: 4),
      Text(
        value == null ? '--' : _formatEcgNumber(value!),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        unit,
        style: const TextStyle(color: Color(0xFFEECBD2), fontSize: 12),
      ),
    ],
  );
}

class _EcgMedicalSection extends StatelessWidget {
  const _EcgMedicalSection({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    const definitions = <(List<String>, String, String)>[
      (['meanHeartRate'], '平均心率', 'bpm'),
      (['averageHRV', 'hrv'], '心率变异性 HRV', 'ms'),
      (['averageTimeInterval'], 'QT 间期', 'ms'),
      (['respiratoryRate'], '呼吸频率', '次/分'),
      (['sdnn'], 'SDNN', 'ms'),
      (['rmssd'], 'RMSSD', 'ms'),
      (['qrsTime'], 'QRS 时限', 'ms'),
      (['qrsAmplitude'], 'QRS 振幅', ''),
      (['stAmplitude'], 'ST 振幅', ''),
      (['pulseWaveVelocity'], '脉搏波速度', ''),
    ];
    final values = definitions
        .where((item) => _ecgValue(record, item.$1) != null)
        .toList(growable: false);
    if (values.isEmpty) {
      return FeatureStateCard(
        message: context.l10n.ecgBasicOnly,
        icon: Icons.monitor_heart_outlined,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.measurementIndicators,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final itemWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final item in values)
                      SizedBox(
                        width: itemWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    color: SaydianColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatEcgNumber(_ecgValue(record, item.$1)!)} ${item.$3}'
                                      .trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EcgRiskSection extends StatelessWidget {
  const _EcgRiskSection({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    const definitions = <(String, String)>[
      ('diseaseRisk', '综合异常风险'),
      ('myocarditisRisk', '心肌健康风险'),
      ('chdRisk', '冠心病相关风险'),
      ('angioscleroticRisk', '血管硬化相关风险'),
      ('pressureIndex', '压力指数'),
      ('fatigueIndex', '疲劳指数'),
      ('deviceAbnormalFlags', '设备识别异常项'),
    ];
    final values = definitions
        .where((item) => record.values[item.$1] != null)
        .toList(growable: false);
    final hasAnalysis =
        (record.values['riskAnalysisAvailable'] ?? 0) > 0 ||
        values.any((item) => (record.values[item.$1] ?? 0) > 0);
    if (!hasAnalysis) {
      return FeatureStateCard(
        message: context.l10n.riskIndicatorsMissing,
        icon: Icons.health_and_safety_outlined,
      );
    }
    final highestRisk = values
        .where(
          (item) => const {
            'diseaseRisk',
            'myocarditisRisk',
            'chdRisk',
            'angioscleroticRisk',
          }.contains(item.$1),
        )
        .map((item) => record.values[item.$1] ?? 0)
        .fold<num>(0, math.max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.riskAnalysisTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.watchAlgorithmReference,
              style: TextStyle(color: SaydianColors.muted, height: 1.45),
            ),
            const SizedBox(height: 12),
            _EcgRiskOverview(value: highestRisk),
            const SizedBox(height: 14),
            for (var index = 0; index < values.length; index++) ...[
              _EcgRiskRow(
                riskKey: values[index].$1,
                label: values[index].$2,
                value: record.values[values[index].$1]!,
              ),
              if (index != values.length - 1) const Divider(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _EcgRiskRow extends StatelessWidget {
  const _EcgRiskRow({
    required this.riskKey,
    required this.label,
    required this.value,
  });

  final String riskKey;
  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    final normalized = value >= 0 && value <= 100 ? value / 100 : null;
    final level = _ecgRiskLevel(riskKey, value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: level.color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${level.label} · ${_formatEcgNumber(value)}',
                style: TextStyle(
                  color: level.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        if (normalized != null) ...[
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: normalized.toDouble(),
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
        const SizedBox(height: 7),
        Text(
          _ecgRiskDescription(riskKey, value),
          style: const TextStyle(
            color: SaydianColors.muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _EcgRiskOverview extends StatelessWidget {
  const _EcgRiskOverview({required this.value});

  final num value;

  @override
  Widget build(BuildContext context) {
    final level = _ecgRiskLevel('diseaseRisk', value);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: level.color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety_rounded, color: level.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本次风险等级：${level.label}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  value < 30
                      ? '本次设备算法未提示明显高风险，建议继续保持规律监测。'
                      : '建议在静息状态复测；如多次提示异常或伴随不适，请及时就医。',
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

({String label, Color color}) _ecgRiskLevel(String key, num value) {
  if (key == 'pressureIndex' || key == 'fatigueIndex') {
    if (value < 30) return (label: '较低', color: SaydianColors.green);
    if (value < 60) return (label: '中等', color: SaydianColors.orange);
    return (label: '偏高', color: SaydianColors.brandRed);
  }
  if (value < 30) return (label: '低风险', color: SaydianColors.green);
  if (value < 60) return (label: '需关注', color: SaydianColors.orange);
  return (label: '风险较高', color: SaydianColors.brandRed);
}

String _ecgRiskDescription(String key, num value) {
  if (key == 'pressureIndex') {
    return value < 30
        ? '压力指标较低，当前状态相对放松。'
        : value < 60
        ? '压力指标处于中等范围，建议适当休息并保持规律作息。'
        : '压力指标偏高，建议静息后复测，并关注近期睡眠与情绪变化。';
  }
  if (key == 'fatigueIndex') {
    return value < 30
        ? '疲劳指标较低，当前恢复状态较好。'
        : value < 60
        ? '存在一定疲劳，建议减少高强度活动并保证休息。'
        : '疲劳指标偏高，建议充分休息后复测。';
  }
  const names = {
    'diseaseRisk': '综合异常',
    'myocarditisRisk': '心肌健康',
    'chdRisk': '冠心病相关',
    'angioscleroticRisk': '血管硬化相关',
    'deviceAbnormalFlags': '设备识别异常',
  };
  final name = names[key] ?? '该项';
  if (key == 'deviceAbnormalFlags') {
    return value <= 0
        ? '设备未识别到异常标记。'
        : '设备识别到 ${_formatEcgNumber(value)} 项异常标记，建议在静息状态规范佩戴后复测。';
  }
  return value < 30
      ? '$name风险较低，建议继续观察长期趋势。'
      : value < 60
      ? '$name指标需要关注，建议在静息状态规范复测。'
      : '$name指标偏高；若复测仍高或伴有胸闷、心悸等不适，请及时就医。';
}

class _EcgFullReportPage extends StatefulWidget {
  const _EcgFullReportPage({required this.record});

  final HealthRecord record;

  @override
  State<_EcgFullReportPage> createState() => _EcgFullReportPageState();
}

class _EcgFullReportPageState extends State<_EcgFullReportPage> {
  static const _channel = MethodChannel('cc.saidian/wearable_methods');
  final _reportKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _reportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('report boundary unavailable');
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('report encoding failed');
      final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
      await _channel.invokeMethod<Object?>('saveReportImage', {
        'bytes': data.buffer.asUint8List(),
        'fileName': 'saidian-ecg-report-$stamp.png',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('心电报告已保存到手机相册')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('报告保存失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.ecgHealthReport)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _reportKey,
          child: ColoredBox(
            color: const Color(0xFFF6F6F7),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.brandedEcgReport,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  _EcgSummaryCard(record: widget.record),
                  const SizedBox(height: 12),
                  _EcgWaveformCard(
                    samples: widget.record.samples,
                    sampleFrequency: widget.record.values['sampleFrequency']
                        ?.toInt(),
                    calibrated: widget.record.rawVersion >= 2,
                    lowSignal: widget.record.quality == 'suspect',
                  ),
                  const SizedBox(height: 12),
                  _EcgMedicalSection(record: widget.record),
                  const SizedBox(height: 12),
                  _EcgRiskSection(record: widget.record),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.ecgReportSafety,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SaydianColors.muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          label: Text(_saving ? '正在保存报告' : '保存报告图片'),
        ),
      ),
    );
  }
}

num? _ecgValue(HealthRecord record, List<String> keys) {
  for (final key in keys) {
    final value = record.values[key];
    if (value != null) return value;
  }
  return null;
}

String _formatEcgNumber(num value) => value == value.round()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

class _EcgWaveformCard extends StatelessWidget {
  const _EcgWaveformCard({
    required this.samples,
    required this.sampleFrequency,
    required this.calibrated,
    this.lowSignal = false,
  });

  final List<num> samples;
  final int? sampleFrequency;
  final bool calibrated;
  final bool lowSignal;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('心电波形', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              FeatureStateCard(
                message: '手表未返回可用心电波形',
                icon: Icons.monitor_heart_outlined,
              ),
            ],
          ),
        ),
      );
    }
    final frequency = sampleFrequency;
    final confirmedScale =
        calibrated && frequency != null && frequency >= 50 && frequency <= 1000;
    final usableSamples = confirmedScale
        ? selectUsableEcgTail(samples, sampleFrequency: frequency)
        : samples;
    final displaySamples = usableSamples.isEmpty ? samples : usableSamples;
    final durationSeconds = confirmedScale
        ? displaySamples.length / frequency
        : null;
    final chartWidth = durationSeconds == null
        ? math.max(640.0, math.min(12000.0, displaySamples.length * 0.3))
        : math.max(640.0, durationSeconds * 72.0);
    final waveform = prepareEcgDisplayWaveform(
      displaySamples,
      maximumPoints: math.max(2, (chartWidth * 2).round()),
      sampleFrequency: confirmedScale ? frequency : null,
      removeContactArtifacts: confirmedScale,
    );
    final spots = waveform.samples
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.ecgWaveformTitle,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              lowSignal
                  ? context.l10n.ecgWaveformLowSignalHint
                  : durationSeconds == null
                  ? context.l10n.ecgWaveformPreviewHint
                  : '共 ${durationSeconds.toStringAsFixed(1)} 秒 · 左右滑动查看完整记录',
              style: const TextStyle(color: SaydianColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (!waveform.hasVariation)
              FeatureStateCard(
                message: context.l10n.ecgWaveformMissing,
                detail: context.l10n.ecgElectrodeHint,
                icon: Icons.monitor_heart_outlined,
              )
            else
              Semantics(
                label: '设备记录的心电波形，共${displaySamples.length}个采样点',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        minY: waveform.minimum,
                        maxY: waveform.maximum,
                        gridData: FlGridData(
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: SaydianColors.pink.withValues(alpha: 0.12),
                            strokeWidth: 1,
                          ),
                          getDrawingVerticalLine: (_) => FlLine(
                            color: SaydianColors.pink.withValues(alpha: 0.08),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            color: SaydianColors.pink,
                            barWidth: 1.8,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
