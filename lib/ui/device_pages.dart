part of 'pages.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final connected = controller.connectedDevice;
    final visibleFeatures = controller.visibleDeviceFeatures;
    final watchFaceFeatures = const [
      DeviceFeature.watchFaces,
      DeviceFeature.photoWatchFace,
    ].where(visibleFeatures.contains).toList(growable: false);
    final primaryFeatures = _primaryFeatures
        .where(visibleFeatures.contains)
        .toList(growable: false);
    return DeviceDetailsRefresh(
      controller: controller,
      deviceTab: true,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (connected != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SaydianColors.skySoft,
                border: Border.all(color: const Color(0xFFE8E8EA)),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: SaydianColors.ink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.watch_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    connected.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _BatteryBadge(
                                  battery: connected.effectiveBattery,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            _ConnectionBadge(
                              label: context.l10n.connectionState(
                                controller.deviceState,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: controller.isDeviceSyncing
                              ? null
                              : () async {
                                  final succeeded = await controller
                                      .syncDeviceData();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        succeeded
                                            ? context
                                                  .l10n
                                                  .deviceDataReadComplete
                                            : context.l10n.syncFailedTryAgain,
                                      ),
                                    ),
                                  );
                                },
                          icon: controller.isDeviceSyncing
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded),
                          label: Text(
                            controller.isDeviceSyncing
                                ? controller.deviceSyncProgress <= 0.1
                                      ? context.l10n.readingData
                                      : '${context.l10n.syncing} ${(controller.deviceSyncProgress * 100).round()}%'
                                : context.l10n.syncData,
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: controller.disconnectDevice,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: Text(context.l10n.disconnect),
                        ),
                      ),
                    ],
                  ),
                  if (controller.cloudSyncState !=
                      CloudHealthSyncState.idle) ...[
                    const SizedBox(height: 8),
                    Row(
                      key: const Key('device-cloud-sync-status'),
                      children: [
                        Expanded(
                          child: Text(
                            switch (controller.cloudSyncState) {
                              CloudHealthSyncState.uploading =>
                                context.l10n.cloudHealthUploading,
                              CloudHealthSyncState.localOnly =>
                                context.l10n.cloudHealthLocalOnly,
                              CloudHealthSyncState.pending =>
                                context.l10n.cloudHealthPending,
                              CloudHealthSyncState.complete =>
                                context.l10n.cloudHealthConfirmed,
                              CloudHealthSyncState.idle => '',
                            },
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: SaydianColors.muted,
                            ),
                          ),
                        ),
                        if (controller.cloudSyncState ==
                            CloudHealthSyncState.pending)
                          TextButton(
                            onPressed: controller.synchronizeCloud,
                            child: Text(context.l10n.retry),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  children: [
                    Container(
                      width: 118,
                      height: 118,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF0F1F2), Color(0xFFFFFFFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.watch_outlined,
                        color: SaydianColors.ink,
                        size: 62,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.addSmartDevice,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.watchNearbyHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DeviceSearchPage(controller: controller),
                          ),
                        ),
                        icon: const Icon(Icons.radar_rounded),
                        label: Text(context.l10n.startSearch),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              key: const Key('phone-weather-entry'),
              leading: const Icon(Icons.wb_sunny_outlined),
              title: Text(_localeCopy(context, 'Phone weather', '手机天气')),
              subtitle: Text(
                _localeCopy(
                  context,
                  'View local forecast on your phone',
                  '查看手机当前位置天气预报',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PhoneWeatherPage(),
                ),
              ),
            ),
          ),
          if (connected != null &&
              controller.deviceCapabilityState ==
                  DeviceCapabilityState.loading) ...[
            Card(
              key: const Key('device-capabilities-loading'),
              child: ListTile(
                leading: const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                title: Text(context.l10n.readingCapabilities),
                subtitle: Text(context.l10n.capabilitiesHint),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (connected != null &&
              controller.deviceCapabilityState ==
                  DeviceCapabilityState.unavailable) ...[
            Card(
              key: const Key('device-capabilities-unavailable'),
              child: ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: Text(context.l10n.capabilitiesFailed),
                subtitle: Text(context.l10n.keepWatchNear),
                trailing: TextButton(
                  key: const Key('device-capabilities-retry'),
                  onPressed: controller.refreshDeviceCapabilities,
                  child: Text(context.l10n.retry),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (connected != null &&
              controller.deviceCapabilityState ==
                  DeviceCapabilityState.ready) ...[
            if (watchFaceFeatures.contains(DeviceFeature.watchFaces)) ...[
              _DeviceWatchFaceMarketStrip(controller: controller),
              const SizedBox(height: 16),
            ],
            if (watchFaceFeatures.isNotEmpty) ...[
              Text(
                context.l10n.personalizeWatch,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (
                    var index = 0;
                    index < watchFaceFeatures.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _deviceFeatureCard(
                        context,
                        watchFaceFeatures[index],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
            ],
            if (primaryFeatures.isNotEmpty) ...[
              Text(
                context.l10n.deviceFeatures,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent:
                      78 +
                      (MediaQuery.textScalerOf(context).scale(1).clamp(1, 2) -
                              1) *
                          72,
                ),
                itemCount: primaryFeatures.length,
                itemBuilder: (context, index) =>
                    _deviceFeatureCard(context, primaryFeatures[index]),
              ),
              const SizedBox(height: 12),
            ],
            if (watchFaceFeatures.isEmpty && primaryFeatures.isEmpty) ...[
              _InlineNotice(
                key: const Key('device-no-integrated-features'),
                message: context.l10n.useWatch,
                icon: Icons.watch_outlined,
                color: SaydianColors.blue,
                compact: true,
              ),
              const SizedBox(height: 12),
            ],
          ],
          Card(
            child: Column(
              children: [
                if (connected != null) ...[
                  ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: 'device-about'),
                        builder: (_) => DeviceInfoPage(controller: controller),
                      ),
                    ),
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(context.l10n.aboutDevice),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                  const Divider(indent: 56),
                ],
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: 'connection-help'),
                      builder: (context) => _InfoPage(
                        title: context.l10n.connectionHelp,
                        message: context.l10n.connectionInstructions,
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.help_outline_rounded),
                  title: Text(context.l10n.connectionHelp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _primaryFeatures = <DeviceFeature>[
    DeviceFeature.findWatch,
    DeviceFeature.camera,
    DeviceFeature.phoneCalls,
    DeviceFeature.contacts,
    DeviceFeature.notifications,
    DeviceFeature.alarms,
    DeviceFeature.weather,
    DeviceFeature.worldClock,
    DeviceFeature.healthReminders,
    DeviceFeature.healthMonitoring,
    DeviceFeature.healthAssessment,
    DeviceFeature.screenDisplay,
    DeviceFeature.basicSettings,
  ];

  Widget _deviceFeatureCard(BuildContext context, DeviceFeature feature) {
    final availability = controller.availabilityFor(feature);
    final isU19Pulse =
        controller.connectedDevice?.sdkSource == WearableSdkSource.urion &&
        feature == DeviceFeature.healthAssessment;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE9E9EC)),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDeviceFeature(context, feature),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _deviceFeatureColor(feature).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isU19Pulse ? Icons.show_chart_rounded : _featureIcon(feature),
                  color: _deviceFeatureColor(feature),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isU19Pulse
                          ? (Localizations.localeOf(context).languageCode ==
                                    'zh'
                                ? '脉搏分析'
                                : 'Pulse insights')
                          : context.l10n.deviceFeatureName(feature),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (!availability.isReady) ...[
                      const SizedBox(height: 3),
                      Text(
                        availability.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SaydianColors.muted,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDeviceFeature(BuildContext context, DeviceFeature feature) {
    if (feature == DeviceFeature.healthMonitoring &&
        controller.connectedDevice?.sdkSource != WearableSdkSource.urion) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'device-health-monitoring'),
          builder: (_) => PermissionManagementPage(
            controller: controller,
            healthOnly: true,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'device-${feature.wireName}'),
        builder: (_) =>
            DeviceFeaturePage(controller: controller, feature: feature),
      ),
    );
  }

  IconData _featureIcon(DeviceFeature feature) => switch (feature) {
    DeviceFeature.watchFaces => Icons.watch_later_outlined,
    DeviceFeature.photoWatchFace => Icons.photo_outlined,
    DeviceFeature.findWatch => Icons.notifications_active_outlined,
    DeviceFeature.camera => Icons.camera_alt_outlined,
    DeviceFeature.phoneCalls => Icons.call_outlined,
    DeviceFeature.contacts => Icons.contacts_outlined,
    DeviceFeature.notifications => Icons.notifications_none_rounded,
    DeviceFeature.alarms => Icons.alarm_rounded,
    DeviceFeature.weather => Icons.cloud_outlined,
    DeviceFeature.worldClock => Icons.public_rounded,
    DeviceFeature.healthReminders => Icons.event_available_outlined,
    DeviceFeature.healthMonitoring => Icons.monitor_heart_outlined,
    DeviceFeature.healthAssessment => Icons.assignment_turned_in_outlined,
    DeviceFeature.screenDisplay => Icons.brightness_6_outlined,
    DeviceFeature.basicSettings => Icons.tune_rounded,
  };

  Color _deviceFeatureColor(DeviceFeature feature) => switch (feature) {
    DeviceFeature.findWatch || DeviceFeature.screenDisplay => SaydianColors.sky,
    DeviceFeature.healthMonitoring ||
    DeviceFeature.healthAssessment => SaydianColors.sage,
    _ => SaydianColors.clay,
  };
}

class _BatteryBadge extends StatelessWidget {
  const _BatteryBadge({required this.battery});

  final DeviceBatteryInfo? battery;

  @override
  Widget build(BuildContext context) {
    final value = battery;
    final percent = value?.percent;
    final color = switch (value) {
      null => SaydianColors.muted,
      DeviceBatteryInfo(isLow: true) => SaydianColors.danger,
      DeviceBatteryInfo(isPercent: true, value: <= 35) => SaydianColors.orange,
      _ => SaydianColors.green,
    };
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final label = value == null
        ? '--'
        : value.isPercent
        ? '${value.value}%'
        : chinese
        ? value.displayLabel
        : '${value.value}/${value.scale}';
    final semantics = value == null
        ? (chinese ? '手表电量暂未读取' : 'Watch battery unavailable')
        : chinese
        ? '手表电量 $label，${value.chargeState.label}'
        : 'Watch battery ${value.isPercent ? label : '${value.value} of ${value.scale} bars'}, ${_batteryChargeLabel(context, value.chargeState)}';
    return Semantics(
      label: semantics,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            value == null
                ? Icons.battery_unknown_rounded
                : value.isCharging
                ? Icons.battery_charging_full_rounded
                : percent != null && percent <= 15
                ? Icons.battery_1_bar_rounded
                : (percent != null && percent <= 50) ||
                      (!value.isPercent && value.value <= 2)
                ? Icons.battery_4_bar_rounded
                : Icons.battery_full_rounded,
            color: color,
            size: 22,
          ),
        ],
      ),
    );
  }
}

String _batteryChargeLabel(
  BuildContext context,
  DeviceBatteryChargeState state,
) => switch (state) {
  DeviceBatteryChargeState.charging => context.l10n.batteryCharging,
  DeviceBatteryChargeState.full => context.l10n.batteryFull,
  DeviceBatteryChargeState.lowPressureDeprecated => context.l10n.batteryLow,
  DeviceBatteryChargeState.normal => context.l10n.batteryNotCharging,
  DeviceBatteryChargeState.fullUnreliable ||
  DeviceBatteryChargeState.unknown => context.l10n.batteryUnknown,
};

class _DeviceWatchFaceMarketStrip extends StatefulWidget {
  const _DeviceWatchFaceMarketStrip({required this.controller});

  final AppController controller;

  @override
  State<_DeviceWatchFaceMarketStrip> createState() =>
      _DeviceWatchFaceMarketStripState();
}

class _DeviceWatchFaceMarketStripState
    extends State<_DeviceWatchFaceMarketStrip> {
  final _service = DeviceWatchFaceMarketService();
  List<DeviceWatchFaceMarketItem> _items = const [];
  DeviceWatchFaceMarketProfile? _profile;
  bool _supported = false;
  String? _loadedDeviceId;
  bool _loading = false;
  final _loadGate = WatchFaceLoadRequestGate();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleDeviceChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleDeviceChanged);
    super.dispose();
  }

  void _handleDeviceChanged() {
    final currentId = widget.controller.connectedDevice?.id;
    if (currentId == _loadedDeviceId) return;
    _loadGate.invalidate();
    if (mounted) {
      setState(() {
        _loadedDeviceId = currentId;
        _profile = null;
        _supported = false;
        _items = const [];
        _loading = false;
      });
    }
    if (currentId != null) unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    if (widget.controller.connectedDevice?.sdkSource !=
        WearableSdkSource.veepoo) {
      return;
    }
    final generation = _loadGate.begin();
    _loading = true;
    final requestedDeviceId = widget.controller.connectedDevice?.id;
    _loadedDeviceId = requestedDeviceId;
    try {
      final profileData = await widget.controller.readWatchFaceProfile();
      if (profileData['onlineMarketSupported'] != true) return;
      final profile = DeviceWatchFaceMarketProfile.fromMap(profileData);
      if (!profile.matchesDevice(requestedDeviceId) ||
          widget.controller.connectedDevice?.id != requestedDeviceId) {
        return;
      }
      final items = widget.controller.usesNativeWatchFaceMarket
          ? (await widget.controller.readNativeWatchFaceCatalog())
                .map(DeviceWatchFaceMarketItem.fromNative)
                .where(
                  (item) =>
                      item.available &&
                      item.dialShape == profile.dialShape &&
                      item.binProtocol == profile.binProtocol,
                )
                .take(4)
                .toList(growable: false)
          : (await _service.loadPage(
              page: 1,
              profile: profile,
            )).items.take(4).toList();
      if (mounted &&
          _loadGate.accepts(
            token: generation,
            requestedDeviceId: requestedDeviceId,
            currentDeviceId: widget.controller.connectedDevice?.id,
          ) &&
          profile.matchesDevice(requestedDeviceId)) {
        setState(() {
          _supported = true;
          _profile = profile;
          _loadedDeviceId = requestedDeviceId;
          _items = items;
        });
      }
    } catch (_) {
      // The full market page has an explicit retry state. Keep this compact
      // preview quiet when the phone is temporarily offline.
    } finally {
      if (_loadGate.accepts(
        token: generation,
        requestedDeviceId: requestedDeviceId,
        currentDeviceId: widget.controller.connectedDevice?.id,
      )) {
        _loading = false;
      }
    }
  }

  void _openMarket() {
    final profile = _profile;
    if (profile == null ||
        !profile.matchesDevice(widget.controller.connectedDevice?.id)) {
      unawaited(_load());
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'device-watch-face-market'),
        builder: (_) => DeviceWatchFaceMarketPage(
          controller: widget.controller,
          profile: profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _openMarket,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '表盘市场',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Text('查看更多', style: TextStyle(color: SaydianColors.muted)),
                Icon(Icons.chevron_right_rounded, color: SaydianColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: _items.isEmpty
              ? Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openMarket,
                    child: const Center(child: Text('进入表盘市场选择更多样式')),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _openMarket,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SafeNetworkImage(
                          item.previewUrl.toString(),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFF171B2B),
                            child: SizedBox.square(
                              dimension: 88,
                              child: Icon(
                                Icons.watch_rounded,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class DeviceSearchPage extends StatefulWidget {
  const DeviceSearchPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<DeviceSearchPage> createState() => _DeviceSearchPageState();
}

class _DeviceSearchPageState extends State<DeviceSearchPage>
    with WidgetsBindingObserver {
  String? _connectingDeviceId;
  bool _scanInFlight = false;
  bool _awaitingScanSettingsReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startScan());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.stopDeviceScan());
    if (_connectingDeviceId != null) {
      unawaited(widget.controller.disconnectDevice());
    }
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_connectingDeviceId != null || _scanInFlight) return;
    _scanInFlight = true;
    try {
      widget.controller.clearError();
      await widget.controller.scanDevices();
    } finally {
      _scanInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingScanSettingsReturn) {
      _awaitingScanSettingsReturn = false;
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_startScan());
      }
    }
  }

  Future<void> _openScanSettings() async {
    final issue = widget.controller.deviceScanIssue;
    if (issue == null || _awaitingScanSettingsReturn) return;
    _awaitingScanSettingsReturn = true;
    try {
      final opened = issue == DeviceScanIssue.locationServiceDisabled
          ? await Geolocator.openLocationSettings()
          : await openAppSettings();
      if (!opened) _awaitingScanSettingsReturn = false;
    } catch (_) {
      _awaitingScanSettingsReturn = false;
    }
    if (mounted && !_awaitingScanSettingsReturn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_scanIssueHint(context, issue))));
    }
  }

  Future<void> _connect(DeviceInfo device) async {
    if (_connectingDeviceId != null) return;
    setState(() => _connectingDeviceId = device.id);
    await widget.controller.connectDevice(device);
    if (!mounted) return;
    if (widget.controller.connectedDevice?.id == device.id &&
        widget.controller.deviceState == DeviceConnectionState.ready) {
      _connectingDeviceId = null;
      Navigator.of(context).pop();
      return;
    }
    setState(() => _connectingDeviceId = null);
  }

  Future<void> _openShop() async {
    await widget.controller.stopDeviceScan();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'shop-home'),
        builder: (_) => ShopHomePage(
          controller: widget.controller,
          ordersPageBuilder: (_) =>
              OrdersPage(controller: widget.controller, initialStatus: null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final devices = controller.scannedDevices;
        final scanning =
            controller.deviceState == DeviceConnectionState.scanning;
        final connecting = _connectingDeviceId != null;
        return PopScope(
          canPop: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.addDevice),
              actions: [
                IconButton(
                  tooltip: context.l10n.searchAgain,
                  onPressed: scanning || connecting ? null : _startScan,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            body: SafeArea(
              child: devices.isEmpty
                  ? _DeviceSearchEmpty(
                      scanning: scanning,
                      errorMessage: controller.errorMessage,
                      issue: controller.deviceScanIssue,
                      onOpenSettings: _openScanSettings,
                      onRetry: scanning || connecting ? null : _startScan,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                      children: [
                        Text(
                          context.l10n.devicesFound,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          scanning
                              ? context.l10n.searchingHint
                              : context.l10n.selectWatch,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: SaydianColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        if (scanning) ...[
                          const SizedBox(height: 14),
                          const LinearProgressIndicator(minHeight: 3),
                        ],
                        if (controller.errorMessage?.trim().isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 14),
                          _InlineNotice(
                            message: _safeUiError(
                              context,
                              controller.errorMessage,
                              context.l10n.searchRecovery,
                            ),
                            icon: Icons.error_outline_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ],
                        const SizedBox(height: 18),
                        for (final device in devices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: connecting
                                    ? null
                                    : () => _connect(device),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    15,
                                    12,
                                    15,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: SaydianColors.ink,
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.watch_rounded,
                                          color: Colors.white,
                                          size: 29,
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    device.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              device.identifierLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: SaydianColors.muted,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _signalIcon(device.rssi),
                                                size: 18,
                                                color: SaydianColors.blue,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${device.rssi ?? '--'}',
                                                style: const TextStyle(
                                                  color: SaydianColors.muted,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 7),
                                          if (_connectingDeviceId == device.id)
                                            const SizedBox.square(
                                              dimension: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          else
                                            Text(
                                              context.l10n.connect,
                                              style: TextStyle(
                                                color: SaydianColors.blue,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (connecting) ...[
                          const SizedBox(height: 8),
                          _InlineNotice(
                            message:
                                Localizations.localeOf(context).languageCode ==
                                    'zh'
                                ? controller.deviceState ==
                                              DeviceConnectionState
                                                  .connecting ||
                                          controller.deviceState ==
                                              DeviceConnectionState
                                                  .authenticating
                                      ? '正在连接；如手表弹出确认，请在 12 秒内确认，并保持手表靠近手机…'
                                      : '正在${_deviceStateLabel(controller.deviceState)}，请保持手表靠近手机…'
                                : controller.deviceState ==
                                      DeviceConnectionState.syncing
                                ? context.l10n.readingData
                                : context.l10n.connecting,
                            icon: Icons.bluetooth_connected_rounded,
                            color: SaydianColors.blue,
                          ),
                        ],
                      ],
                    ),
            ),
            bottomNavigationBar: !showSaydianMall
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      child: TextButton.icon(
                        key: const Key('device-shop-entry'),
                        onPressed: connecting ? null : _openShop,
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: Text(
                          context.l10n.noWatchShopHint,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  IconData _signalIcon(int? rssi) {
    if (rssi == null || rssi < -85) return Icons.signal_cellular_alt_1_bar;
    if (rssi < -65) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt;
  }

  String _deviceStateLabel(DeviceConnectionState state) => switch (state) {
    DeviceConnectionState.connecting => '连接',
    DeviceConnectionState.authenticating => '认证',
    DeviceConnectionState.syncing => '同步数据',
    _ => '连接设备',
  };
}

class _DeviceSearchEmpty extends StatelessWidget {
  const _DeviceSearchEmpty({
    required this.scanning,
    required this.errorMessage,
    required this.issue,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final bool scanning;
  final String? errorMessage;
  final DeviceScanIssue? issue;
  final VoidCallback onOpenSettings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 58, 28, 32),
      children: [
        Container(
          width: 150,
          height: 150,
          margin: const EdgeInsets.symmetric(horizontal: 74),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDCEBFF), Color(0xFFF0F6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            scanning
                ? Icons.radar_rounded
                : issue == DeviceScanIssue.locationServiceDisabled
                ? Icons.location_off_outlined
                : issue != null
                ? Icons.settings_outlined
                : Icons.watch_off_outlined,
            color: SaydianColors.blue,
            size: 76,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          scanning
              ? context.l10n.searchingNearby
              : switch (issue) {
                  DeviceScanIssue.locationServiceDisabled =>
                    context.l10n.scanLocationTitle,
                  DeviceScanIssue.permissionsRequired =>
                    context.l10n.scanPermissionTitle,
                  null => context.l10n.noDevices,
                },
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          scanning
              ? context.l10n.activateWatch
              : issue != null
              ? _scanIssueHint(context, issue!)
              : (errorMessage?.trim().isNotEmpty ?? false)
              ? _safeUiError(context, errorMessage, context.l10n.searchRecovery)
              : context.l10n.checkWatchConnection,
          textAlign: TextAlign.center,
          style: const TextStyle(color: SaydianColors.muted, height: 1.5),
        ),
        if (scanning) ...[
          const SizedBox(height: 24),
          const LinearProgressIndicator(),
        ] else ...[
          const SizedBox(height: 26),
          if (issue != null) ...[
            FilledButton.icon(
              key: const Key('device-scan-open-settings'),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: Text(context.l10n.goToSettings),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.l10n.searchAgain),
          ),
          if (issue == null) ...[
            const SizedBox(height: 20),
            _InlineNotice(
              message: context.l10n.searchRecovery,
              icon: Icons.info_outline_rounded,
              color: SaydianColors.blue,
            ),
          ],
        ],
      ],
    );
  }
}

String _scanIssueHint(BuildContext context, DeviceScanIssue issue) =>
    switch (issue) {
      DeviceScanIssue.locationServiceDisabled => context.l10n.scanLocationHint,
      DeviceScanIssue.permissionsRequired => context.l10n.scanPermissionHint,
    };

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DeviceDetailsRefresh(
      controller: widget.controller,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.aboutDevice)),
        body: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final device = widget.controller.connectedDevice;
            final battery = device?.effectiveBattery;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(context.l10n.deviceName),
                        trailing: Text(device?.name ?? '--'),
                      ),
                      const Divider(indent: 16),
                      ListTile(
                        title: Text(context.l10n.deviceModel),
                        trailing: Text(device?.displayModel ?? '--'),
                      ),
                      const Divider(indent: 16),
                      ListTile(
                        title: Text(context.l10n.connectionStatus),
                        trailing: Text(
                          device == null
                              ? context.l10n.notConnected
                              : context.l10n.connected,
                        ),
                      ),
                      const Divider(indent: 16),
                      ListTile(
                        title: Text(context.l10n.firmwareVersion),
                        trailing: Text(device?.firmwareVersion ?? '--'),
                      ),
                      const Divider(indent: 16),
                      ListTile(
                        title: Text(context.l10n.watchBattery),
                        subtitle: battery?.updatedAt == null
                            ? null
                            : Text(
                                '${Localizations.localeOf(context).languageCode == 'zh' ? '更新于' : 'Updated'} ${DateFormat.yMMMd(context.l10n.localeName).add_jm().format(battery!.updatedAt!.toLocal())}',
                              ),
                        trailing: _BatteryBadge(battery: battery),
                      ),
                      if (battery != null) ...[
                        const Divider(indent: 16),
                        ListTile(
                          title: Text(context.l10n.chargingStatus),
                          trailing: Text(
                            _batteryChargeLabel(context, battery.chargeState),
                          ),
                        ),
                      ],
                      const Divider(indent: 16),
                      ListTile(
                        title: Text(
                          device?.macAddress != null
                              ? (Localizations.localeOf(context).languageCode ==
                                        'zh'
                                    ? 'MAC 地址'
                                    : 'MAC address')
                              : defaultTargetPlatform == TargetPlatform.iOS
                              ? (Localizations.localeOf(context).languageCode ==
                                        'zh'
                                    ? 'iOS 设备标识'
                                    : 'iOS device ID')
                              : (Localizations.localeOf(context).languageCode ==
                                        'zh'
                                    ? '设备标识'
                                    : 'Device ID'),
                        ),
                        subtitle: Text(
                          device?.macAddress ?? device?.nativeId ?? '--',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SaydianColors.green.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF16823A),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
