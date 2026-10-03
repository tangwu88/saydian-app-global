part of 'pages.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _scheduledError;

  void _showPendingError(BuildContext context) {
    final message = widget.controller.errorMessage?.trim();
    if (message == null || message.isEmpty || message == _scheduledError) {
      return;
    }
    final fallback = message.contains('数据读取失败') || message.contains('数据同步失败')
        ? context.l10n.syncFailedTryAgain
        : widget.controller.deviceState == DeviceConnectionState.error
        ? context.l10n.searchRecovery
        : context.l10n.serviceUnavailable;
    final visibleMessage = _safeUiError(context, message, fallback);
    _scheduledError = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(visibleMessage)));
      widget.controller.clearError();
      _scheduledError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    _showPendingError(context);
    final controller = widget.controller;
    final selectedIndex = controller.selectedTab.clamp(0, 2).toInt();
    final pages = [
      DashboardPage(controller: controller),
      DevicePage(controller: controller),
      SettingsPage(controller: controller),
    ];
    return Scaffold(
      appBar: selectedIndex == 0
          ? null
          : AppBar(
              title: Text(
                selectedIndex == 1 ? context.l10n.device : context.l10n.profile,
              ),
              actions: const [],
            ),
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1EAE6))),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: controller.selectTab,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.favorite_border_rounded),
              selectedIcon: const Icon(Icons.favorite_rounded),
              label: context.l10n.health,
            ),
            NavigationDestination(
              icon: const Icon(Icons.watch_outlined),
              selectedIcon: const Icon(Icons.watch_rounded),
              label: context.l10n.device,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: context.l10n.profile,
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final latest = controller.latestByMetric;
    final disconnected = controller.connectedDevice == null;
    const supportedMetrics = [
      HealthMetric.bloodPressure,
      HealthMetric.heartRate,
      HealthMetric.bloodOxygen,
      HealthMetric.bloodGlucose,
      HealthMetric.bodyTemperature,
      HealthMetric.ecg,
      HealthMetric.hrv,
      HealthMetric.bodyComposition,
      HealthMetric.bloodComposition,
      HealthMetric.sleep,
    ];
    final metrics = supportedMetrics
        .where((metric) {
          if (controller.isGlobalEdition &&
              disconnected &&
              const {
                HealthMetric.bodyTemperature,
                HealthMetric.hrv,
                HealthMetric.bodyComposition,
                HealthMetric.bloodComposition,
              }.contains(metric)) {
            return false;
          }
          return controller.shouldShowHealthMetric(metric);
        })
        .toList(growable: false);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: controller.synchronizeCloud,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DashboardHeader(controller: controller),
                  const SizedBox(height: 12),
                  _AiHealthAssistantCard(controller: controller),
                  const SizedBox(height: 12),
                  _FeatureEntryGrid(
                    onCare: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(context.l10n.remoteCare)),
                          body: CarePage(controller: controller),
                        ),
                      ),
                    ),
                    onEncyclopedia: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(
                          name: 'health-encyclopedia-categories',
                        ),
                        builder: (_) =>
                            ArticleCategoryPage(controller: controller),
                      ),
                    ),
                    onWarning: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: 'health-warnings'),
                        builder: (_) =>
                            HealthWarningPage(controller: controller),
                      ),
                    ),
                    onMall: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: 'shop-home'),
                        builder: (_) => ShopHomePage(
                          controller: controller,
                          ordersPageBuilder: (_) => OrdersPage(
                            controller: controller,
                            initialStatus: null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(
                    title: context.l10n.healthData,
                    subtitle: DateFormat.MMMd(
                      context.l10n.localeName,
                    ).format(DateTime.now()),
                    actionLabel: context.l10n.allData,
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: 'all-health-data'),
                        builder: (_) =>
                            AllHealthDataPage(controller: controller),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (metrics.isEmpty)
                    _InlineNotice(
                      key: const Key('dashboard-health-empty-notice'),
                      message: disconnected
                          ? controller.isRestoringWearableConnection
                                ? context.l10n.connectingWatch
                                : context.l10n.connectWatchForData
                          : context.l10n.noHealthData,
                      icon: Icons.watch_outlined,
                      color: SaydianColors.blue,
                      compact: true,
                      centered: true,
                      onTap:
                          disconnected &&
                              !controller.isRestoringWearableConnection
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: 'device-search',
                                ),
                                builder: (_) =>
                                    DeviceSearchPage(controller: controller),
                              ),
                            )
                          : null,
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: metrics.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 142 + (textScale - 1) * 160,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final metric = metrics[index];
                        return _MetricCard(
                          controller: controller,
                          metric: metric,
                          record: latest[metric],
                        );
                      },
                    ),
                  if ((!controller.isGlobalEdition || !disconnected) &&
                      controller.connectedDevice?.sdkSource !=
                          WearableSdkSource.urion) ...[
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.workoutsAndRecords,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SportEntryPanel(controller: controller),
                  ],
                ]),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _InlineNotice(
                    key: const Key('dashboard-health-notice'),
                    message: context.l10n.healthDisclaimer,
                    icon: Icons.health_and_safety_outlined,
                    color: SaydianColors.green,
                    compact: true,
                    legal: true,
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

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final profileName = '${controller.memberProfile['nickname'] ?? ''}'.trim();
    final sessionName = controller.session?.displayName.trim() ?? '';
    final name = profileName.isNotEmpty
        ? profileName
        : sessionName.isNotEmpty
        ? sessionName
        : controller.isPreviewMode
        ? (Localizations.localeOf(context).languageCode == 'zh'
              ? '体验用户'
              : 'Guest')
        : context.l10n.defaultUser;
    final avatarUrl = '${controller.memberProfile['head_portrait'] ?? ''}'
        .trim();
    return Row(
      key: const Key('dashboard-header'),
      children: [
        KeyedSubtree(
          key: const Key('dashboard-profile-avatar'),
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: avatarUrl.isEmpty
                ? const SaydianBrandMark(size: 46)
                : ClipOval(
                    child: SafeNetworkImage(
                      avatarUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const SaydianBrandMark(size: 46),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            name,
            key: const Key('dashboard-profile-name'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: SaydianColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: controller.notificationUnreadCount > 0,
          label: Text(
            controller.notificationUnreadCount > 99
                ? '99+'
                : '${controller.notificationUnreadCount}',
          ),
          smallSize: 9,
          backgroundColor: Color(0xFFD70B25),
          child: IconButton(
            key: const Key('dashboard-notifications-button'),
            tooltip: controller.notificationUnreadCount > 0
                ? context.l10n.unreadMessages(
                    controller.notificationUnreadCount,
                  )
                : context.l10n.messages,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NotificationsPage(controller: controller),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded, size: 27),
          ),
        ),
      ],
    );
  }
}

class _AiHealthAssistantCard extends StatelessWidget {
  const _AiHealthAssistantCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final stacked = textScale >= 1.8;
    final doctor = SizedBox(
      height: stacked ? 196 : 140,
      child: ClipRect(
        child: stacked
            ? Image.asset(
                'assets/branding/ai-health-manager-doctor.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              )
            : Transform.scale(
                scale: 1.28,
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(18, 0),
                  child: Image.asset(
                    'assets/branding/ai-health-manager-doctor.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
      ),
    );
    final content = Padding(
      padding: EdgeInsets.fromLTRB(stacked ? 16 : 4, stacked ? 6 : 7, 13, 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.aiAssistant,
            style: const TextStyle(
              color: SaydianColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            key: const Key('dashboard-ai-ask'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'ai-health-chat'),
                builder: (_) => AiChatPage(controller: controller, app: 1),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: SaydianColors.brandRed,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
              shape: const StadiumBorder(),
            ),
            child: Text(
              context.l10n.askNow,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      key: const Key('dashboard-ai-assistant'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: SaydianColors.line, width: 1.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [doctor, content],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 36, child: doctor),
                Expanded(flex: 64, child: content),
              ],
            ),
    );
  }
}

// Retained for the full activity-goal page; intentionally hidden on the home.
// ignore: unused_element
class _TodayHealthOverview extends StatelessWidget {
  const _TodayHealthOverview({
    required this.latest,
    required this.stepTarget,
    required this.distanceTarget,
    required this.calorieTarget,
    required this.distanceUnit,
    required this.onSetGoal,
  });

  final Map<HealthMetric, HealthRecord> latest;
  final double stepTarget;
  final double distanceTarget;
  final double calorieTarget;
  final String distanceUnit;
  final VoidCallback onSetGoal;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('dashboard-today-health'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE8F7ED), Color(0xFFF3F8E8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today’s activity',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Keep moving toward your daily goals',
                          style: TextStyle(
                            color: SaydianColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onSetGoal,
                    icon: const Icon(Icons.track_changes_rounded, size: 18),
                    label: Text(context.l10n.goals),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
            child: Column(
              children: [
                _GoalProgressRow(
                  metric: HealthMetric.steps,
                  record: latest[HealthMetric.steps],
                  target: stepTarget,
                  distanceUnit: distanceUnit,
                  color: const Color(0xFF80BAF5),
                ),
                const SizedBox(height: 16),
                _GoalProgressRow(
                  metric: HealthMetric.distance,
                  record: latest[HealthMetric.distance],
                  target: distanceTarget,
                  distanceUnit: distanceUnit,
                  color: const Color(0xFF6CDE53),
                ),
                const SizedBox(height: 16),
                _GoalProgressRow(
                  metric: HealthMetric.calories,
                  record: latest[HealthMetric.calories],
                  target: calorieTarget,
                  distanceUnit: distanceUnit,
                  color: const Color(0xFFFF9949),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalProgressRow extends StatelessWidget {
  const _GoalProgressRow({
    required this.metric,
    required this.record,
    required this.target,
    required this.distanceUnit,
    required this.color,
  });

  final HealthMetric metric;
  final HealthRecord? record;
  final double target;
  final String distanceUnit;
  final Color color;

  num? get _value {
    if (record == null || record!.values.isEmpty) return null;
    return record!.values['value'] ?? record!.values.values.first;
  }

  String _format(num value) {
    if (metric == HealthMetric.distance) return value.toStringAsFixed(2);
    return value.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final progress = value == null
        ? 0.0
        : (value.toDouble() / target).clamp(0.0, 1.0).toDouble();
    final usesMiles = metric == HealthMetric.distance && distanceUnit == '英里';
    final unit = switch (metric) {
      HealthMetric.distance => usesMiles ? 'mi' : 'km',
      HealthMetric.calories => '千卡',
      _ => metric.defaultUnit,
    };
    final currentText = value == null
        ? '--'
        : _format(usesMiles ? value * 0.621371 : value);
    final targetText = _format(usesMiles ? target * 0.621371 : target);

    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 34,
          child: Text(
            context.l10n.metricName(metric),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 106,
          child: Text(
            '$currentText/$targetText$unit',
            textAlign: TextAlign.right,
            maxLines: 1,
            style: const TextStyle(
              color: SaydianColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureEntryGrid extends StatelessWidget {
  const _FeatureEntryGrid({
    required this.onCare,
    required this.onEncyclopedia,
    required this.onWarning,
    required this.onMall,
  });

  final VoidCallback onCare;
  final VoidCallback onEncyclopedia;
  final VoidCallback onWarning;
  final VoidCallback onMall;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('dashboard-functions'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _FeatureEntry(
                label: context.l10n.remoteCare,
                icon: Icons.family_restroom_rounded,
                color: SaydianColors.sky,
                onTap: onCare,
              ),
            ),
            Expanded(
              child: _FeatureEntry(
                label: context.l10n.healthLibrary,
                icon: Icons.menu_book_rounded,
                color: SaydianColors.sage,
                onTap: onEncyclopedia,
              ),
            ),
            Expanded(
              child: _FeatureEntry(
                label: context.l10n.healthAlerts,
                icon: Icons.health_and_safety_rounded,
                color: SaydianColors.clay,
                onTap: onWarning,
              ),
            ),
            if (showSaydianMall)
              Expanded(
                child: _FeatureEntry(
                  label: context.l10n.shop,
                  icon: Icons.shopping_bag_rounded,
                  color: SaydianColors.ink,
                  onTap: onMall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureEntry extends StatelessWidget {
  const _FeatureEntry({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Retained for device-focused layouts; intentionally hidden on the home.
// ignore: unused_element
class _DeviceHero extends StatelessWidget {
  const _DeviceHero({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final device = controller.connectedDevice;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF6FF), Color(0xFFF5F3E7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: SaydianColors.ink,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.watch_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device?.name ?? '尚未连接手表',
                        style: const TextStyle(
                          color: SaydianColors.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  device == null
                      ? '连接后同步健康数据'
                      : '${device.displayModel} · ${controller.syncStatus}',
                  style: const TextStyle(
                    color: SaydianColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => controller.selectTab(1),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(device == null ? '连接' : '管理'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.controller,
    required this.metric,
    required this.record,
  });

  final AppController controller;
  final HealthMetric metric;
  final HealthRecord? record;

  @override
  Widget build(BuildContext context) {
    final icon = switch (metric) {
      HealthMetric.steps => Icons.directions_walk,
      HealthMetric.sleep => Icons.bedtime_outlined,
      HealthMetric.heartRate => Icons.favorite_outline,
      HealthMetric.bloodOxygen => Icons.water_drop_outlined,
      HealthMetric.bloodPressure => Icons.speed_outlined,
      HealthMetric.bloodGlucose => Icons.bloodtype_outlined,
      HealthMetric.bodyTemperature => Icons.thermostat_outlined,
      HealthMetric.ecg => Icons.monitor_heart_outlined,
      HealthMetric.hrv => Icons.show_chart_rounded,
      HealthMetric.bodyComposition => Icons.accessibility_new_rounded,
      HealthMetric.bloodComposition => Icons.science_outlined,
      _ => Icons.monitor_heart_outlined,
    };
    final iconColor = switch (metric) {
      HealthMetric.bloodPressure => SaydianColors.clay,
      HealthMetric.heartRate => SaydianColors.heart,
      HealthMetric.bloodOxygen => SaydianColors.sky,
      HealthMetric.sleep => SaydianColors.sage,
      _ => SaydianColors.sky,
    };
    final chartColor = iconColor;
    final status = _homeMetricStatus(controller, record);
    final needsAttention = !{
      _HomeMetricStatus.normal,
      _HomeMetricStatus.recorded,
      _HomeMetricStatus.noData,
    }.contains(status);
    final statusLabel = switch (status) {
      _HomeMetricStatus.normal => context.l10n.statusNormal,
      _HomeMetricStatus.recorded => context.l10n.statusRecorded,
      _HomeMetricStatus.noData => context.l10n.noData,
      _HomeMetricStatus.attention => context.l10n.statusAttention,
      _HomeMetricStatus.outOfRange => context.l10n.statusOutOfRange,
      _HomeMetricStatus.low => context.l10n.statusLow,
      _HomeMetricStatus.high => context.l10n.statusHigh,
    };
    final supportsManualMeasurement =
        controller.canMeasureHealthMetric(metric) &&
        const {
          HealthMetric.bloodPressure,
          HealthMetric.heartRate,
          HealthMetric.bloodOxygen,
          HealthMetric.bloodGlucose,
          HealthMetric.bodyTemperature,
          HealthMetric.ecg,
          HealthMetric.hrv,
          HealthMetric.bodyComposition,
          HealthMetric.bloodComposition,
        }.contains(metric);
    return GestureDetector(
      key: ValueKey('health-metric-${metric.name}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HealthTrendPage(
            controller: controller,
            metric: metric,
            onMeasure: supportsManualMeasurement
                ? () =>
                      _showHealthMeasurementDialog(context, controller, metric)
                : null,
          ),
        ),
      ),
      child: Card(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.11),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      metric == HealthMetric.bodyTemperature &&
                              Localizations.localeOf(context).languageCode !=
                                  'zh'
                          ? 'Temp.'
                          : context.l10n.metricName(metric),
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (needsAttention) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: needsAttention
                              ? const Color(0xFFFFE7E5)
                              : SaydianColors.brandRedSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: needsAttention
                                ? SaydianColors.danger
                                : SaydianColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _healthDisplayValue(record, controller),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _healthDisplayUnit(
                            context,
                            metric,
                            record,
                            controller,
                          ),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(color: SaydianColors.muted),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              HealthMetricMiniChart(
                controller: controller,
                metric: metric,
                color: chartColor,
                showEmptyLabel: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HomeMetricStatus {
  normal,
  recorded,
  noData,
  attention,
  outOfRange,
  low,
  high,
}

_HomeMetricStatus _homeMetricStatus(
  AppController controller,
  HealthRecord? record,
) {
  if (record == null) return _HomeMetricStatus.noData;
  final quality = record.quality.toLowerCase();
  if (quality.contains('poor') ||
      quality.contains('warning') ||
      quality.contains('abnormal')) {
    return _HomeMetricStatus.attention;
  }
  final primary = record.values['value'];
  if (record.metric == HealthMetric.heartRate &&
      primary != null &&
      (primary < 60 || primary > 100)) {
    return _HomeMetricStatus.outOfRange;
  }
  if (record.metric == HealthMetric.bloodOxygen &&
      primary != null &&
      primary < 95) {
    return _HomeMetricStatus.low;
  }
  if (record.metric == HealthMetric.bodyTemperature &&
      primary != null &&
      (primary < 36 || primary > 37.3)) {
    return primary > 37.3 ? _HomeMetricStatus.high : _HomeMetricStatus.low;
  }
  if (record.metric == HealthMetric.bloodPressure) {
    final systolic = record.values['systolic'];
    final diastolic = record.values['diastolic'];
    if (systolic != null && diastolic != null) {
      if (systolic >= 140 || diastolic >= 90) return _HomeMetricStatus.high;
      if (systolic < 90 || diastolic < 60) return _HomeMetricStatus.low;
    }
  }
  if (record.metric == HealthMetric.ecg) {
    return (record.values['deviceAbnormalFlags'] ?? 0) > 0
        ? _HomeMetricStatus.attention
        : _HomeMetricStatus.recorded;
  }
  if (record.metric == HealthMetric.hrv) return _HomeMetricStatus.recorded;
  final settings = controller.healthWarningSettings;
  if (record.metric == HealthMetric.heartRate && settings.heartRateEnabled) {
    final value = record.values['value'];
    if (value != null && value > settings.heartRateUpper) {
      return _HomeMetricStatus.attention;
    }
  }
  if (record.metric == HealthMetric.bloodPressure &&
      settings.bloodPressureEnabled) {
    final systolic = record.values['systolic'];
    final diastolic = record.values['diastolic'];
    if ((systolic != null && systolic > settings.systolicUpper) ||
        (diastolic != null && diastolic > settings.diastolicUpper)) {
      return _HomeMetricStatus.attention;
    }
  }
  if (record.metric == HealthMetric.bodyTemperature &&
      settings.temperatureEnabled) {
    final value = record.values['value'];
    if (value != null && value > settings.temperatureUpper) {
      return _HomeMetricStatus.attention;
    }
  }
  return _HomeMetricStatus.normal;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final heading = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 19,
              color: SaydianColors.muted,
            ),
            const SizedBox(width: 5),
            Text(
              subtitle,
              style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
            ),
          ],
        ),
      ],
    );
    final action = TextButton.icon(
      onPressed: onAction,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.chevron_right_rounded, size: 21),
      label: Text(
        actionLabel,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    if (enlargedText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          Align(alignment: Alignment.centerRight, child: action),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: heading),
        action,
      ],
    );
  }
}
