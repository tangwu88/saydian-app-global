import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_controller.dart';

/// Refresh device information only on the visible, foreground device screen.
class DeviceDetailsRefresh extends StatefulWidget {
  const DeviceDetailsRefresh({
    required this.controller,
    required this.child,
    this.deviceTab = false,
    super.key,
  });

  final AppController controller;
  final Widget child;
  final bool deviceTab;

  @override
  State<DeviceDetailsRefresh> createState() => _DeviceDetailsRefreshState();
}

class _DeviceDetailsRefreshState extends State<DeviceDetailsRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;
  Future<void>? _refreshing;
  bool _foreground = true;
  bool _routeVisible = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_update);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeVisible = ModalRoute.isCurrentOf(context) ?? true;
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _update();
  }

  void _update() {
    final visible =
        mounted &&
        _foreground &&
        _routeVisible &&
        (!widget.deviceTab || widget.controller.selectedTab == 1);
    final id = widget.controller.connectedDevice?.id;
    if (!visible || id == null) {
      _timer?.cancel();
      _timer = null;
      _deviceId = null;
      return;
    }
    if (_timer == null || _deviceId != id) {
      _deviceId = id;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final active = _refreshing;
    if (active != null) return active;
    final load = widget.controller
        .refreshConnectedDeviceDetails(forceRefresh: true)
        .then<void>((_) {});
    _refreshing = load;
    try {
      await load;
    } finally {
      if (identical(_refreshing, load)) _refreshing = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_update);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RefreshIndicator(onRefresh: _refresh, child: widget.child);
}
