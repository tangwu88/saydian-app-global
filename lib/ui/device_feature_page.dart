part of 'prototype_pages.dart';

class DeviceFeaturePage extends StatefulWidget {
  const DeviceFeaturePage({
    required this.controller,
    required this.feature,
    super.key,
  });

  final AppController controller;
  final DeviceFeature feature;

  @override
  State<DeviceFeaturePage> createState() => _DeviceFeaturePageState();
}

class _DeviceFeaturePageState extends State<DeviceFeaturePage>
    with WidgetsBindingObserver {
  String _watchText(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  static const _nativeMethods = MethodChannel('cc.saidian/wearable_methods');
  DeviceScreenSettings? _screen;
  Map<String, Object?> _featureData = const {};
  bool _pulseRequested = false;
  bool _finding = false;
  Timer? _findResetTimer;
  CameraController? _camera;
  XFile? _lastPhoto;
  String? _cameraMessage;
  bool _takingPhoto = false;
  bool _cameraRemoteStarted = false;
  bool _cameraInitializing = false;
  bool _cameraPermissionRequesting = false;
  bool _cameraPermissionPermanentlyDenied = false;
  int _cameraGeneration = 0;
  late final CameraRemoteShutterGate _cameraShutterGate;
  XFile? _dialPhoto;
  int _dialTimePosition = 0;
  final DeviceWeatherService _weatherService = DeviceWeatherService();
  final DeviceWatchFaceMarketService _watchFaceMarketService =
      DeviceWatchFaceMarketService();
  bool _weatherRefreshing = false;
  String? _weatherMessage;
  bool _openingWatchFaceMarket = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraShutterGate = CameraRemoteShutterGate(
      initialSequence: widget.controller.cameraShutterSequence,
    );
    widget.controller.addListener(_handleControllerEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.controller.availabilityFor(widget.feature).isReady) {
        return;
      }
      if (widget.feature == DeviceFeature.screenDisplay) {
        unawaited(_loadScreen());
      } else if (widget.feature == DeviceFeature.healthMonitoring &&
          widget.controller.connectedDevice?.sdkSource !=
              WearableSdkSource.urion) {
        unawaited(widget.controller.refreshDeviceSettings());
      } else if (widget.feature == DeviceFeature.camera) {
        unawaited(_initializeCamera());
      } else if (widget.feature != DeviceFeature.findWatch) {
        unawaited(_loadFeature());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerEvent);
    _findResetTimer?.cancel();
    _cameraGeneration += 1;
    final camera = _camera;
    _camera = null;
    camera?.removeListener(_handleCameraState);
    _cameraShutterGate.disarm(
      currentSequence: widget.controller.cameraShutterSequence,
    );
    if (_cameraRemoteStarted) {
      unawaited(_stopCameraRemoteIgnoringErrors());
    }
    _cameraRemoteStarted = false;
    unawaited(camera?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.feature == DeviceFeature.camera) {
      _cameraShutterGate.setLifecycleState(
        state,
        currentSequence: widget.controller.cameraShutterSequence,
      );
      if (state == AppLifecycleState.resumed) {
        unawaited(_resumeCamera());
      } else {
        unawaited(_suspendCamera());
      }
      return;
    }
    if (state == AppLifecycleState.resumed &&
        widget.feature == DeviceFeature.notifications &&
        widget.controller.availabilityFor(widget.feature).isReady) {
      unawaited(_loadFeature());
    }
  }

  void _handleControllerEvent() {
    if (!mounted) return;
    if (widget.feature == DeviceFeature.findWatch &&
        !widget.controller.availabilityFor(widget.feature).isReady &&
        _finding) {
      _findResetTimer?.cancel();
      setState(() => _finding = false);
    }
    if (widget.feature == DeviceFeature.camera) {
      final availability = widget.controller.availabilityFor(widget.feature);
      if (!availability.isReady) {
        _cameraShutterGate.disarm(
          currentSequence: widget.controller.cameraShutterSequence,
        );
        if (_camera != null || _cameraRemoteStarted || _cameraInitializing) {
          unawaited(_suspendCamera(message: '手表已断开，请重新连接后使用'));
        }
        return;
      }
      if (_camera == null &&
          !_cameraInitializing &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_resumeCamera());
      }
      final sequence = widget.controller.cameraShutterSequence;
      if (_cameraShutterGate.shouldCapture(
        sequence: sequence,
        now: DateTime.now(),
      )) {
        unawaited(_takePhoto());
      }
    }
    final latest = widget.controller.deviceFeatureData[widget.feature];
    if (latest != null &&
        !mapEquals(latest, _featureData) &&
        widget.feature != DeviceFeature.screenDisplay) {
      setState(() {
        _featureData = latest;
        if (latest['justMeasured'] == true) _pulseRequested = false;
      });
      return;
    }
    final progress = latest?['progress'];
    if (progress != null && progress != _featureData['progress']) {
      setState(() => _featureData = {..._featureData, 'progress': progress});
    }
  }

  Future<void> _loadFeature() async {
    final value = await widget.controller.readDeviceFeature(widget.feature);
    if (mounted && value.isNotEmpty) {
      setState(() {
        _featureData = value;
        if (widget.feature == DeviceFeature.healthAssessment &&
            widget.controller.connectedDevice?.sdkSource ==
                WearableSdkSource.urion) {
          _pulseRequested = value['awaitingCompletion'] == true;
        }
      });
      if (widget.feature == DeviceFeature.watchFaces) {
        unawaited(_enrichWatchFacePreviews(value));
      }
    }
  }

  Future<void> _enrichWatchFacePreviews(Map<String, Object?> source) async {
    try {
      final profile = DeviceWatchFaceMarketProfile.fromMap(
        await widget.controller.readWatchFaceProfile(),
      );
      if (!profile.matchesDevice(widget.controller.connectedDevice?.id)) return;
      final catalogue = widget.controller.usesNativeWatchFaceMarket
          ? (await widget.controller.readNativeWatchFaceCatalog())
                .map(DeviceWatchFaceMarketItem.fromNative)
                .where(
                  (item) =>
                      item.available &&
                      item.dialShape == profile.dialShape &&
                      item.binProtocol == profile.binProtocol,
                )
                .take(200)
                .toList(growable: false)
          : await _watchFaceMarketService.loadIndex(profile: profile);
      final rawItems = source['items'];
      if (rawItems is! List) return;
      final enriched = rawItems
          .whereType<Map>()
          .map((raw) {
            final face = raw.map((key, value) => MapEntry('$key', value));
            final existingPreview = _watchFaceMarketService
                .hasUsablePreviewReference(face);
            if (existingPreview) return face;
            final installedPath =
                [face['path'], face['id'], face['filePath'], face['name']]
                    .map((value) => '${value ?? ''}'.trim())
                    .firstWhere((value) => value.isNotEmpty, orElse: () => '');
            final match = _watchFaceMarketService.matchInstalledPath(
              installedPath,
              catalogue,
            );
            return match == null
                ? face
                : {...face, 'previewUrl': match.previewUrl.toString()};
          })
          .toList(growable: false);
      if (mounted &&
          profile.matchesDevice(widget.controller.connectedDevice?.id)) {
        setState(() => _featureData = {...source, 'items': enriched});
      }
    } catch (_) {
      // Installed faces remain usable when the online index is unavailable.
    }
  }

  Future<void> _loadScreen() async {
    final value = await widget.controller.readDeviceFeature(widget.feature);
    if (mounted && value.isNotEmpty) {
      setState(() => _screen = DeviceScreenSettings.fromMap(value));
    }
  }

  Future<void> _saveScreen() async {
    final screen = _screen;
    if (screen == null) return;
    final saved = await widget.controller.writeDeviceFeature(
      widget.feature,
      screen.toMap(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? _watchText('屏幕设置已保存', 'Display settings saved')
              : _watchText(
                  '屏幕设置保存失败，请稍后重试',
                  'Could not save display settings. Try again.',
                ),
        ),
      ),
    );
  }

  Future<bool> _saveFeature(
    Map<String, Object?> values,
    String successMessage, {
    bool reload = true,
  }) async {
    final saved = await widget.controller.writeDeviceFeature(
      widget.feature,
      values,
    );
    if (!mounted) return saved;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? successMessage
              : _watchText(
                  widget.controller.errorMessage ?? '保存失败，请稍后重试',
                  'Could not save this setting. Try again.',
                ),
        ),
      ),
    );
    if (saved && reload) await _loadFeature();
    return saved;
  }

  Future<void> _initializeCamera() async {
    if (_cameraInitializing || _cameraPermissionRequesting || _camera != null) {
      return;
    }
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      _cameraPermissionRequesting = true;
      try {
        var status = await Permission.camera.status;
        if (!status.isGranted) status = await Permission.camera.request();
        if (!mounted) return;
        _cameraPermissionPermanentlyDenied = status.isPermanentlyDenied;
        if (!status.isGranted) {
          setState(() {
            _cameraMessage = status.isPermanentlyDenied
                ? '相机权限已关闭，请在系统设置中开启'
                : '允许相机权限后使用';
          });
          return;
        }
      } on PlatformException {
        if (!mounted) return;
        setState(() => _cameraMessage = '无法读取相机权限，请稍后重试');
        return;
      } finally {
        _cameraPermissionRequesting = false;
      }
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
    }
    _cameraInitializing = true;
    final generation = ++_cameraGeneration;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraMessage = '手机没有可用的相机');
        return;
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted ||
          generation != _cameraGeneration ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      controller.addListener(_handleCameraState);
      _handleCameraState();
      if (controller.value.hasError) return;
      final started = await widget.controller.triggerDeviceAction(
        DeviceFeature.camera,
      );
      if (!mounted || generation != _cameraGeneration) {
        if (started) unawaited(_stopCameraRemoteIgnoringErrors());
        return;
      }
      if (controller.value.hasError) {
        _handleCameraState();
        return;
      }
      setState(() {
        _cameraRemoteStarted = started;
        _cameraMessage = started
            ? '可点击手机按钮，也可在手表上点击拍照'
            : widget.controller.errorMessage ?? '手表相机遥控暂时无法开启';
      });
      if (started) {
        _cameraShutterGate.arm(
          now: DateTime.now(),
          currentSequence: widget.controller.cameraShutterSequence,
        );
      } else {
        _cameraShutterGate.disarm(
          currentSequence: widget.controller.cameraShutterSequence,
        );
      }
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraMessage = error.code == 'CameraAccessDenied'
            ? '允许相机权限后使用'
            : '手机相机暂时无法使用，请稍后重试';
      });
    } catch (_) {
      if (mounted) setState(() => _cameraMessage = '手机相机暂时无法使用，请稍后重试');
    } finally {
      if (generation == _cameraGeneration) _cameraInitializing = false;
    }
  }

  Future<void> _retryCamera() async {
    if (_cameraPermissionPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    if (mounted) setState(() => _cameraMessage = null);
    await _initializeCamera();
  }

  Future<void> _suspendCamera({String message = '返回 App 后将重新打开相机'}) async {
    if (widget.feature != DeviceFeature.camera) return;
    final generation = ++_cameraGeneration;
    _cameraInitializing = false;
    final camera = _camera;
    final shouldStopRemote = _cameraRemoteStarted;
    _camera = null;
    _cameraRemoteStarted = false;
    _cameraShutterGate.disarm(
      currentSequence: widget.controller.cameraShutterSequence,
    );
    camera?.removeListener(_handleCameraState);
    if (mounted) {
      setState(() => _cameraMessage = message);
    }
    if (shouldStopRemote) {
      await _stopCameraRemoteIgnoringErrors();
    }
    await camera?.dispose();
    if (generation != _cameraGeneration) return;
  }

  Future<void> _resumeCamera() async {
    if (!mounted || widget.feature != DeviceFeature.camera) return;
    _cameraShutterGate.setLifecycleState(
      AppLifecycleState.resumed,
      currentSequence: widget.controller.cameraShutterSequence,
    );
    if (!widget.controller.availabilityFor(widget.feature).isReady) {
      if (mounted) setState(() => _cameraMessage = '手表已断开，请重新连接后使用');
      return;
    }
    await _initializeCamera();
  }

  Future<void> _stopCameraRemoteIgnoringErrors() async {
    final controller = widget.controller;
    // `dispose` runs while Flutter has the element tree locked. The controller
    // publishes its busy state synchronously, so defer that notification to
    // the next event turn instead of rebuilding listeners during unmount.
    await Future<void>.delayed(Duration.zero);
    try {
      await controller.triggerDeviceAction(
        DeviceFeature.camera,
        enabled: false,
      );
    } catch (_) {
      // The foreground gate still prevents background callbacks from taking a
      // photo when the watch command cannot be stopped immediately.
    }
  }

  void _handleCameraState() {
    final camera = _camera;
    if (!mounted || camera == null || !camera.value.hasError) return;
    final description = camera.value.errorDescription?.trim() ?? '';
    final message = description.toLowerCase().contains('disabled')
        ? '相机已被系统策略停用，请在系统设置中开启相机后重试'
        : '手机相机暂时无法使用，请检查相机权限或系统设置';
    if (_cameraMessage == message) return;
    final shouldStopRemote = _cameraRemoteStarted;
    setState(() {
      _cameraMessage = message;
      _cameraRemoteStarted = false;
    });
    _cameraShutterGate.disarm(
      currentSequence: widget.controller.cameraShutterSequence,
    );
    if (shouldStopRemote) {
      unawaited(
        widget.controller.triggerDeviceAction(
          DeviceFeature.camera,
          enabled: false,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null ||
        !camera.value.isInitialized ||
        camera.value.hasError ||
        _takingPhoto) {
      return;
    }
    setState(() => _takingPhoto = true);
    try {
      final photo = await camera.takePicture();
      final bytes = await photo.readAsBytes();
      final fileName =
          'saidian-camera-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _nativeMethods.invokeMethod<Object?>('saveGalleryImage', {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': 'image/jpeg',
      });
      if (mounted) {
        setState(() {
          _lastPhoto = photo;
          _cameraMessage = '照片已保存到手机相册';
        });
      }
    } on CameraException catch (error) {
      if (mounted) {
        setState(() => _cameraMessage = '拍照失败（${error.code}），请稍后重试');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _cameraMessage = error.message ?? '照片保存失败，请检查相册权限后重试');
      }
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _toggleFind() async {
    final source = widget.controller.connectedDevice?.sdkSource;
    final isOneShot =
        source == WearableSdkSource.yucheng ||
        source == WearableSdkSource.urion;
    if (isOneShot && _finding) return;
    final next = isOneShot || !_finding;
    final success = await widget.controller.triggerDeviceAction(
      widget.feature,
      enabled: next,
    );
    if (!mounted) return;
    if (success) {
      setState(() => _finding = next);
      if (isOneShot) {
        _findResetTimer?.cancel();
        _findResetTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _finding = false);
        });
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (isOneShot
                    ? _watchText(
                        '已发送查找指令，请留意手表振动',
                        'Find request sent. Watch for a vibration.',
                      )
                    : (next
                          ? _watchText(
                              '手表正在响铃或振动',
                              'Your watch is ringing or vibrating.',
                            )
                          : _watchText('已停止查找', 'Find watch stopped.')))
              : widget.controller.errorMessage ??
                    _watchText(
                      '暂时无法查找手表',
                      'Unable to find your watch right now.',
                    ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final availability = widget.controller.availabilityFor(widget.feature);
        final busy = widget.controller.deviceFeatureBusy.contains(
          widget.feature,
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.feature == DeviceFeature.healthAssessment &&
                      widget.controller.connectedDevice?.sdkSource ==
                          WearableSdkSource.urion
                  ? _watchText('脉搏分析', 'Pulse insights')
                  : context.l10n.deviceFeatureName(widget.feature),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!availability.isReady)
                FeatureStateCard(
                  message: availability.message,
                  detail: _deviceFeatureDescription(context, widget.feature),
                  icon: _deviceFeatureIcon(widget.feature),
                )
              else if (widget.feature == DeviceFeature.findWatch)
                _FindWatchPanel(
                  finding: _finding,
                  busy: busy,
                  supportsStop:
                      widget.controller.connectedDevice?.sdkSource !=
                          WearableSdkSource.yucheng &&
                      widget.controller.connectedDevice?.sdkSource !=
                          WearableSdkSource.urion,
                  onPressed: _toggleFind,
                )
              else if (widget.feature == DeviceFeature.screenDisplay)
                _ScreenSettingsPanel(
                  settings: _screen,
                  busy: busy,
                  onReload: _loadScreen,
                  onChanged: (value) => setState(() => _screen = value),
                  onSave: _saveScreen,
                )
              else if (widget.feature == DeviceFeature.basicSettings)
                _buildBasicSettingsPanel(busy)
              else if (widget.feature == DeviceFeature.healthMonitoring &&
                  widget.controller.connectedDevice?.sdkSource ==
                      WearableSdkSource.urion)
                _buildU19MonitoringPanel(busy)
              else if (widget.feature == DeviceFeature.healthAssessment &&
                  widget.controller.connectedDevice?.sdkSource ==
                      WearableSdkSource.urion)
                _buildU19PulsePanel(busy)
              else
                _buildReadyContent(busy),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReadyContent(bool busy) => switch (widget.feature) {
    DeviceFeature.watchFaces => _buildWatchFacesPanel(busy),
    DeviceFeature.photoWatchFace => _buildPhotoWatchFacePanel(busy),
    DeviceFeature.camera => _buildCameraPanel(),
    DeviceFeature.phoneCalls => _buildPhoneCallsPanel(busy),
    DeviceFeature.contacts => _buildContactsPanel(busy),
    DeviceFeature.notifications => _buildNotificationsPanel(busy),
    DeviceFeature.alarms => _buildAlarmsPanel(busy),
    DeviceFeature.weather => _buildWeatherPanel(busy),
    DeviceFeature.worldClock => _buildWorldClocksPanel(busy),
    DeviceFeature.healthReminders => _buildHealthRemindersPanel(busy),
    DeviceFeature.healthAssessment => _buildHealthAssessmentPanel(busy),
    DeviceFeature.healthMonitoring => _buildHealthMonitoringPanel(),
    _ => FeatureStateCard(
      message: context.l10n.useWatch,
      detail: _deviceFeatureDescription(context, widget.feature),
      icon: _deviceFeatureIcon(widget.feature),
    ),
  };

  Future<void> _saveBasicSetting(String key, Object value) async {
    final saved = await widget.controller.writeDeviceFeature(
      DeviceFeature.basicSettings,
      {key: value},
    );
    if (!mounted) return;
    if (saved) await _loadFeature();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? key == 'syncTime'
                    ? _watchText(
                        '时间和语言请求已发送，请在手表上核对；语言可能保持不变。',
                        'Time and language request sent. Check the watch; its language may stay the same.',
                      )
                    : _watchText(
                        '已保存并从手表确认',
                        'Saved and confirmed by your watch.',
                      )
              : widget.controller.errorMessage ??
                    _watchText(
                      '设置未生效，请重试',
                      'The setting did not take effect. Try again.',
                    ),
        ),
      ),
    );
  }

  Future<void> _syncBasicTime() async {
    final language = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_watchText('时间与手表语言', 'Time & watch language')),
        content: Text(
          _watchText(
            '选择希望手表显示的语言，并发送手机当前时间。部分手表可能不会切换语言，请发送后核对手表。',
            'Choose the language you want on the watch and send your phone’s current time. Some watches may not change language; check the display afterward.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('zh'),
            child: const Text('中文'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('en'),
            child: const Text('English'),
          ),
        ],
      ),
    );
    if (mounted && language is String) {
      await _saveBasicSetting('syncTime', language);
    }
  }

  Future<void> _editBasicNumber(
    String key,
    String label,
    int minimum,
    int maximum,
  ) async {
    final input = TextEditingController(text: '${_featureData[key] ?? ''}');
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: input,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: '$minimum–$maximum'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(input.text.trim());
              if (parsed == null || parsed < minimum || parsed > maximum) {
                return;
              }
              Navigator.of(dialogContext).pop(parsed);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    input.dispose();
    if (value != null && mounted) await _saveBasicSetting(key, value);
  }

  Widget _buildBasicSettingsPanel(bool busy) {
    if (_featureData.isEmpty) {
      return _loadingCard(busy, _watchText('手表设置', 'watch settings'));
    }
    final is24Hour = _featureData['is24Hour'] == true;
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.access_time_rounded),
            title: Text(_watchText('时间与语言', 'Time & language')),
            subtitle: Text(
              _watchText(
                '同步手机时间，并选择手表语言',
                'Sync your phone’s time and request a watch language',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: busy ? null : _syncBasicTime,
          ),
        ),
        Card(
          child: SwitchListTile(
            title: Text(_watchText('24 小时制', '24-hour time')),
            subtitle: Text(
              is24Hour
                  ? _watchText('当前使用 24 小时制', 'Using 24-hour time')
                  : _watchText('当前使用 12 小时制', 'Using 12-hour time'),
            ),
            value: is24Hour,
            onChanged: busy
                ? null
                : (value) => _saveBasicSetting('is24Hour', value),
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(_watchText('步数目标', 'Step goal')),
                subtitle: Text(
                  '${_featureData['stepGoal'] ?? '—'} ${_watchText('步', 'steps')}',
                ),
                onTap: busy
                    ? null
                    : () => _editBasicNumber(
                        'stepGoal',
                        _watchText('步数目标', 'Step goal'),
                        1,
                        100000,
                      ),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(context.l10n.gender),
                subtitle: Text(
                  _featureData['gender'] == 0
                      ? _watchText('男', 'Male')
                      : _watchText('女', 'Female'),
                ),
                onTap: busy
                    ? null
                    : () => _saveBasicSetting(
                        'gender',
                        _featureData['gender'] == 0 ? 1 : 0,
                      ),
              ),
              for (final item in <(String, String, String, int, int)>[
                (
                  'age',
                  _watchText('年龄', 'Age'),
                  _watchText('岁', 'years'),
                  1,
                  120,
                ),
                ('heightCm', _watchText('身高', 'Height'), 'cm', 50, 240),
                ('weightKg', _watchText('体重', 'Weight'), 'kg', 10, 250),
              ]) ...[
                const Divider(height: 1),
                ListTile(
                  title: Text(item.$2),
                  subtitle: Text('${_featureData[item.$1] ?? '—'} ${item.$3}'),
                  onTap: busy
                      ? null
                      : () => _editBasicNumber(
                          item.$1,
                          item.$2,
                          item.$4,
                          item.$5,
                        ),
                ),
              ],
            ],
          ),
        ),
        TextButton.icon(
          onPressed: busy ? null : _loadFeature,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(context.l10n.readAgain),
        ),
      ],
    );
  }

  List<Map<String, Object?>> get _items {
    final raw = _featureData['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  Widget _loadingCard(bool busy, String label) => FeatureStateCard(
    message: busy
        ? _watchText('正在读取$label', 'Loading $label…')
        : _watchText('暂时未读取到$label', 'Could not load $label'),
    detail: _watchText(
      '请保持手表靠近手机后重试。',
      'Keep your watch nearby and try again.',
    ),
    icon: _deviceFeatureIcon(widget.feature),
    actionLabel: busy ? null : context.l10n.retry,
    onAction: busy ? null : _loadFeature,
  );

  Widget _buildWatchFacesPanel(bool busy) {
    final noLocalData = _featureData.isEmpty;
    final faces = _items;
    final progress = (_featureData['progress'] as num?)?.toInt();
    final onlineMarketSupported = _featureData['onlineMarketSupported'] == true;
    return Column(
      children: [
        if (onlineMarketSupported) ...[
          Card(
            color: SaydianColors.brandRedSoft,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6,
              ),
              leading: const Icon(
                Icons.watch_rounded,
                color: SaydianColors.brandRed,
                size: 34,
              ),
              title: Text(
                context.l10n.watchFaceShop,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: busy || _openingWatchFaceMarket
                  ? null
                  : _openWatchFaceMarket,
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(context.l10n.installedWatchFaces),
              subtitle: Text(context.l10n.switchInstalledWatchFace),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '手表中的表盘',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        if (busy && progress != null && progress > 0) ...[
          LinearProgressIndicator(value: progress.clamp(0, 100) / 100),
          const SizedBox(height: 10),
          Text('正在读取表盘 $progress%'),
          const SizedBox(height: 12),
        ],
        if (noLocalData)
          _loadingCard(busy, '手表中的表盘')
        else
          Card(
            child: faces.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('手表中暂未读取到可切换的表盘')),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < faces.length; index++) ...[
                        ListTile(
                          minLeadingWidth: 64,
                          leading: _WatchFaceThumbnail(face: faces[index]),
                          title: Text('${faces[index]['name'] ?? '手表表盘'}'),
                          subtitle: Text(
                            faces[index]['isCurrent'] == true
                                ? '当前使用'
                                : '${faces[index]['status'] ?? '手表表盘'}',
                          ),
                          trailing: faces[index]['isCurrent'] == true
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: SaydianColors.green,
                                )
                              : TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => _switchWatchFace(faces[index]),
                                  child: Text(
                                    context.l10n.useSelectedWatchFace,
                                  ),
                                ),
                        ),
                        if (index != faces.length - 1)
                          const Divider(indent: 72),
                      ],
                    ],
                  ),
          ),
        if (!noLocalData) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : _loadFeature,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.refreshWatchFaces),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openWatchFaceMarket() async {
    if (_openingWatchFaceMarket) return;
    setState(() => _openingWatchFaceMarket = true);
    try {
      final profileData = await widget.controller.readWatchFaceProfile();
      final profile = DeviceWatchFaceMarketProfile.fromMap(profileData);
      if (!profile.matchesDevice(widget.controller.connectedDevice?.id)) {
        throw const DeviceWatchFaceMarketException('连接设备已变化，请重新进入表盘中心');
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DeviceWatchFaceMarketPage(
            controller: widget.controller,
            profile: profile,
          ),
        ),
      );
    } on DeviceWatchFaceMarketException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _openingWatchFaceMarket = false);
    }
  }

  Future<void> _switchWatchFace(Map<String, Object?> face) async {
    await _saveFeature({
      'operation': 'switch',
      'id': '${face['id'] ?? ''}',
      'type': '${face['type'] ?? ''}',
      'index': (face['index'] as num?)?.toInt() ?? 0,
    }, '表盘已切换');
  }

  Widget _buildPhotoWatchFacePanel(bool busy) {
    final progress = (_featureData['progress'] as num?)?.toInt() ?? 0;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      key: const Key('photo-watch-face-picker'),
                      onTap: busy ? null : _pickDialPhoto,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 126,
                        height: 154,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F5),
                          border: Border.all(color: const Color(0xFFD9DDE3)),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: _dialPhoto == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 38,
                                    color: SaydianColors.brandRed,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '点击选择照片',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              )
                            : Image.file(
                                File(_dialPhoto!.path),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.photoWatchFace,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.photoWatchFaceHint,
                            style: TextStyle(
                              color: SaydianColors.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: busy ? null : _pickDialPhoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(_dialPhoto == null ? '选择照片' : '更换照片'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (busy) ...[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: progress > 0 ? progress.clamp(0, 100) / 100 : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      progress > 0 ? '正在传送到手表 $progress%' : '正在准备照片表盘',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _dialTimePosition,
                  decoration: InputDecoration(
                    labelText: context.l10n.timeDisplayPosition,
                    prefixIcon: Icon(Icons.schedule_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('顶部居中')),
                    DropdownMenuItem(value: 1, child: Text('画面中央')),
                    DropdownMenuItem(value: 2, child: Text('底部居中')),
                    DropdownMenuItem(value: 3, child: Text('左上角')),
                    DropdownMenuItem(value: 4, child: Text('右上角')),
                    DropdownMenuItem(value: 5, child: Text('左下角')),
                    DropdownMenuItem(value: 6, child: Text('右下角')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) =>
                            setState(() => _dialTimePosition = value ?? 0),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy || _dialPhoto == null
                        ? null
                        : _uploadDialPhoto,
                    icon: const Icon(Icons.watch_rounded),
                    label: Text(context.l10n.transferSetWatchFace),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.watchTransferKeepNear,
          textAlign: TextAlign.center,
          style: TextStyle(color: SaydianColors.muted, fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _pickDialPhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (photo != null && mounted) setState(() => _dialPhoto = photo);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('允许照片权限后使用')));
    }
  }

  Future<void> _uploadDialPhoto() async {
    final photo = _dialPhoto;
    if (photo == null) return;
    await _saveFeature(
      {
        'operation': 'upload_photo',
        'imagePath': photo.path,
        'timePosition': _dialTimePosition,
      },
      '照片表盘已设置',
      reload: false,
    );
  }

  Widget _buildCameraPanel() {
    final camera = _camera;
    final previewHeight = math.min(
      MediaQuery.sizeOf(context).height * .56,
      560.0,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: previewHeight,
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (camera != null &&
                      camera.value.isInitialized &&
                      !camera.value.hasError)
                    Center(
                      child: AspectRatio(
                        // Camera preview sizes are reported in the sensor's
                        // landscape orientation. In this portrait page the
                        // inverse ratio preserves the natural image without
                        // stretching or cropping.
                        aspectRatio: 1 / camera.value.aspectRatio,
                        child: CameraPreview(camera),
                      ),
                    )
                  else
                    Center(
                      child: _cameraMessage == null
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(
                              Icons.no_photography_outlined,
                              color: Colors.white70,
                              size: 54,
                            ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .58),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            child: Text(
                              _cameraMessage ?? '正在打开相机',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          button: true,
                          label: '拍照并保存到手机',
                          child: SizedBox(
                            width: 68,
                            height: 68,
                            child: FilledButton(
                              key: const ValueKey('camera-shutter-button'),
                              onPressed:
                                  camera == null ||
                                      camera.value.hasError ||
                                      _takingPhoto
                                  ? null
                                  : _takePhoto,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: SaydianColors.brandRed,
                                disabledBackgroundColor: Colors.white54,
                                shape: const CircleBorder(
                                  side: BorderSide(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: _takingPhoto
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: SaydianColors.brandRed,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 30,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.watch_rounded, color: SaydianColors.brandRed),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '可点击手机快门，也可按手表拍照键；照片会保存到手机相册。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: SaydianColors.muted),
                      ),
                    ),
                  ],
                ),
                if (camera == null && _cameraMessage != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const ValueKey('camera-retry-button'),
                    onPressed:
                        _cameraInitializing || _cameraPermissionRequesting
                        ? null
                        : _retryCamera,
                    icon: Icon(
                      _cameraPermissionPermanentlyDenied
                          ? Icons.settings_outlined
                          : Icons.refresh_rounded,
                    ),
                    label: Text(
                      _cameraPermissionPermanentlyDenied ? '前往系统设置' : '重新打开相机',
                    ),
                  ),
                ],
                if (_lastPhoto != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_lastPhoto!.path),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneCallsPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '通话设置');
    final status = switch (_featureData['connectionStatus']) {
      'connected' => '通话连接已建立',
      'broadcasting' => '等待手机配对',
      _ => '通话连接未建立',
    };
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.bluetooth_audio_rounded),
            title: Text(status),
            subtitle: Text(
              _featureData['paired'] == true ? '手机已保存配对信息' : '请在手机蓝牙设置中完成配对',
            ),
            trailing: IconButton(
              onPressed: busy ? null : _loadFeature,
              tooltip: '刷新',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const Divider(indent: 56),
          ListTile(
            leading: Icon(
              _featureData['audioEnabled'] == true
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_outlined,
            ),
            title: Text(context.l10n.callMediaAudio),
            subtitle: Text(
              _featureData['audioEnabled'] == true ? '手表媒体声音已连接' : '媒体声音尚未连接',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    busy || _featureData['connectionStatus'] == 'connected'
                    ? null
                    : () => _saveFeature(const {
                        'enabled': true,
                      }, '已发送通话连接请求，请按系统提示完成配对'),
                icon: const Icon(Icons.bluetooth_connected_rounded),
                label: Text(
                  _featureData['connectionStatus'] == 'connected'
                      ? '通话连接已建立'
                      : '建立通话连接',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureSwitch({
    required String title,
    required String subtitle,
    required String keyName,
    required bool busy,
    bool supported = true,
  }) => SwitchListTile(
    title: Text(title),
    subtitle: Text(supported ? subtitle : '当前手表不支持此项'),
    value: _featureData[keyName] == true,
    onChanged: busy || !supported
        ? null
        : (value) =>
              _saveFeature({..._featureData, keyName: value}, '$title已保存'),
  );

  Widget _buildNotificationsPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '消息通知设置');
    final supported =
        (_featureData['supportedKeys'] as List?)
            ?.map((value) => '$value')
            .toSet() ??
        const <String>{};
    final entries = <(String, String, String)>[
      ('incomingCall', '来电提醒', '有电话时在手表提醒'),
      ('sms', '短信', '在手表显示短信提醒'),
      ('wechat', '微信', '在手表显示微信消息提醒'),
      ('qq', 'QQ', '在手表显示 QQ 消息提醒'),
      ('whatsapp', 'WhatsApp', '在手表显示 WhatsApp 消息提醒'),
      ('dingtalk', '钉钉', '在手表显示钉钉消息提醒'),
      ('wecom', '企业微信', '在手表显示企业微信消息提醒'),
      ('tiktok', '抖音', '在手表显示抖音消息提醒'),
      ('telegram', 'Telegram', '在手表显示 Telegram 消息提醒'),
      ('otherApps', '其他应用', '接收其他已允许应用的消息提醒'),
    ];
    final visibleEntries = entries
        .where((entry) => supported.contains(entry.$1))
        .toList(growable: false);
    final access = _featureData['notificationAccess'] == true;
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              access ? Icons.verified_user_rounded : Icons.security_rounded,
              color: access ? SaydianColors.green : SaydianColors.orange,
            ),
            title: Text(access ? '手机通知权限已允许' : '还需允许手机通知权限'),
            subtitle: Text(access ? '已开启的应用消息可以发送到手表' : '允许后，手表才能显示手机收到的应用消息'),
            trailing: TextButton(
              onPressed: busy
                  ? null
                  : access
                  ? _loadFeature
                  : _openNotificationSettings,
              child: Text(access ? '重新检查' : '去设置'),
            ),
          ),
        ),
        if (visibleEntries.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < visibleEntries.length; index++) ...[
                  _featureSwitch(
                    keyName: visibleEntries[index].$1,
                    title: visibleEntries[index].$2,
                    subtitle: visibleEntries[index].$3,
                    busy: busy,
                  ),
                  if (index != visibleEntries.length - 1)
                    const Divider(indent: 56),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openNotificationSettings() async {
    final opened = await widget.controller.triggerDeviceAction(
      DeviceFeature.notifications,
    );
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.controller.errorMessage ?? '无法打开系统设置')),
    );
  }

  Widget _buildWeatherPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '天气设置');
    final city = '${_featureData['city'] ?? ''}'.trim();
    final updatedAt = (_featureData['updatedAt'] as num?)?.toInt() ?? 0;
    return Column(
      children: [
        Card(
          child: Column(
            children: [
              _featureSwitch(
                keyName: 'enabled',
                title: '在手表显示天气',
                subtitle: '开启后可在手表查看天气信息',
                busy: busy || _weatherRefreshing,
              ),
              const Divider(indent: 56),
              SwitchListTile(
                title: Text(context.l10n.useCelsius),
                subtitle: Text(
                  _featureData['useCelsius'] == true ? '温度显示为 ℃' : '温度显示为 ℉',
                ),
                value: _featureData['useCelsius'] == true,
                onChanged: busy || _weatherRefreshing
                    ? null
                    : (value) => _saveFeature({
                        ..._featureData,
                        'useCelsius': value,
                      }, '温度单位已保存'),
              ),
              if (city.isNotEmpty) ...[
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(city),
                  subtitle: Text(
                    updatedAt > 0
                        ? '上次更新 ${_weatherTimeLabel(updatedAt)}'
                        : '已同步到手表',
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy || _weatherRefreshing
                            ? null
                            : _syncWeather,
                        icon: _weatherRefreshing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_sync_outlined),
                        label: Text(_weatherRefreshing ? '正在更新天气' : '更新当前位置天气'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy || _weatherRefreshing
                            ? null
                            : _chooseWeatherCity,
                        icon: const Icon(Icons.location_city_outlined),
                        label: Text(context.l10n.selectCity),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_weatherMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _weatherMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Future<void> _chooseWeatherCity() async {
    final city = await showDialog<String>(
      context: context,
      builder: (_) => const _CityInputDialog(),
    );
    if (city == null || !mounted) return;
    await _syncWeather(city: city);
  }

  Future<void> _syncWeather({String? city}) async {
    setState(() {
      _weatherRefreshing = true;
      _weatherMessage = null;
    });
    try {
      final forecast = city == null
          ? await _weatherService.loadCurrentLocation()
          : await _weatherService.loadCity(city);
      final values = forecast.toFeatureValues(
        useCelsius: _featureData['useCelsius'] != false,
      );
      final saved = await _saveFeature(values, '天气已同步到手表', reload: false);
      if (saved && mounted) {
        setState(() {
          _featureData = {..._featureData, ...values};
          _weatherMessage = '${forecast.city}天气已更新';
        });
      }
    } on DeviceWeatherException catch (error) {
      if (!mounted) return;
      setState(() => _weatherMessage = error.message);
      if (error.openSettings) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            action: SnackBarAction(
              label: '去设置',
              onPressed: () {
                if (error.locationSettings) {
                  unawaited(Geolocator.openLocationSettings());
                } else {
                  unawaited(Geolocator.openAppSettings());
                }
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _weatherMessage = '天气更新失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _weatherRefreshing = false);
    }
  }

  String _weatherTimeLabel(int milliseconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${value.month}月${value.day}日 '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildAlarmsPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '闹钟');
    final alarms = _items;
    return Column(
      children: [
        Card(
          child: alarms.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('手表中还没有闹钟')),
                )
              : Column(
                  children: [
                    for (var index = 0; index < alarms.length; index++) ...[
                      _alarmTile(alarms[index], busy),
                      if (index != alarms.length - 1) const Divider(indent: 56),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : () => _showAlarmEditor(),
            icon: const Icon(Icons.add_alarm_rounded),
            label: Text(context.l10n.addAlarm),
          ),
        ),
      ],
    );
  }

  Widget _alarmTile(Map<String, Object?> alarm, bool busy) {
    final hour = (alarm['hour'] as num?)?.toInt() ?? 0;
    final minute = (alarm['minute'] as num?)?.toInt() ?? 0;
    final enabled = alarm['enabled'] == true;
    final label = alarm['label']?.toString().trim() ?? '';
    final repeatLabel = _repeatDaysLabel(alarm['repeatDays']);
    return ListTile(
      onTap: busy ? null : () => _showAlarmEditor(alarm),
      leading: const Icon(Icons.alarm_rounded),
      title: Text(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(label.isEmpty ? repeatLabel : '$label · $repeatLabel'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: enabled,
            onChanged: busy
                ? null
                : (value) => _saveFeature({
                    ...alarm,
                    'operation': 'update',
                    'enabled': value,
                  }, value ? '闹钟已开启' : '闹钟已关闭'),
          ),
          IconButton(
            onPressed: busy ? null : () => _deleteAlarm(alarm),
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _showAlarmEditor([Map<String, Object?>? alarm]) async {
    var time = TimeOfDay(
      hour: (alarm?['hour'] as num?)?.toInt() ?? 8,
      minute: (alarm?['minute'] as num?)?.toInt() ?? 0,
    );
    final repeatDays =
        (alarm?['repeatDays'] as List?)
            ?.whereType<num>()
            .map((day) => day.toInt())
            .toSet() ??
        <int>{1, 2, 3, 4, 5, 6, 7};
    var enabled = alarm?['enabled'] != false;
    var label = alarm?['label']?.toString().trim() ?? '闹钟';
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(alarm == null ? '添加闹钟' : '编辑闹钟'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(context.l10n.alarmTime),
                  subtitle: Text(time.format(context)),
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: dialogContext,
                      initialTime: time,
                    );
                    if (selected != null) setDialogState(() => time = selected);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.enableAlarm),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
                TextFormField(
                  initialValue: label,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: context.l10n.reminderName,
                    hintText: '例如：吃药、起床',
                  ),
                  onChanged: (value) => label = value.trim(),
                ),
                const SizedBox(height: 8),
                Text(context.l10n.repeat),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        label: Text(
                          const ['一', '二', '三', '四', '五', '六', '日'][day - 1],
                        ),
                        selected: repeatDays.contains(day),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            repeatDays.add(day);
                          } else {
                            repeatDays.remove(day);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, <String, Object?>{
                if (alarm?['id'] != null) 'id': alarm!['id'],
                'operation': alarm == null ? 'add' : 'update',
                'hour': time.hour,
                'minute': time.minute,
                'enabled': enabled,
                'label': label.isEmpty ? '闹钟' : label,
                'repeatDays': repeatDays.toList()..sort(),
              }),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
    if (values != null) await _saveFeature(values, '闹钟已保存');
  }

  Future<void> _deleteAlarm(Map<String, Object?> alarm) async {
    final confirmed = await _confirm('删除闹钟', '确定删除这个闹钟吗？');
    if (!confirmed) return;
    await _saveFeature({...alarm, 'operation': 'delete'}, '闹钟已删除');
  }

  String _repeatDaysLabel(Object? raw) {
    final days =
        (raw as List?)?.whereType<num>().map((day) => day.toInt()).toSet() ??
        {};
    if (days.isEmpty) return '仅一次';
    if (days.length == 7) return '每天';
    if (days.length == 5 && days.containsAll([1, 2, 3, 4, 5])) return '工作日';
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final sorted = days.toList()..sort();
    return sorted.map((day) => labels[day - 1]).join('、');
  }

  Widget _buildContactsPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '联系人');
    final contacts = _items;
    Map<String, Object?>? emergency;
    for (final contact in contacts) {
      if (contact['isEmergency'] == true) {
        emergency = contact;
        break;
      }
    }
    return Column(
      children: [
        Card(
          color: SaydianColors.brandRedSoft,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: SaydianColors.brandRed,
              foregroundColor: Colors.white,
              child: Icon(Icons.sos_rounded),
            ),
            title: Text(
              context.l10n.emergencyContact,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              emergency == null
                  ? '尚未设置，手表触发 SOS 时将无法快速联系家人'
                  : '${emergency['name'] ?? ''}  ${emergency['phone'] ?? ''}',
            ),
            trailing: TextButton(
              onPressed: busy || contacts.isEmpty
                  ? null
                  : () => _selectEmergencyContact(contacts),
              child: Text(emergency == null ? '立即设置' : '更换'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: contacts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('手表中还没有常用联系人')),
                )
              : Column(
                  children: [
                    for (var index = 0; index < contacts.length; index++) ...[
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(_contactInitial(contacts[index])),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${contacts[index]['name'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (contacts[index]['isEmergency'] == true)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: SaydianColors.brandRedSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: SaydianColors.brandRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text('${contacts[index]['phone'] ?? ''}'),
                        trailing: IconButton(
                          onPressed: busy
                              ? null
                              : () => _deleteContact(contacts[index]),
                          tooltip: '删除',
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                      if (index != contacts.length - 1)
                        const Divider(indent: 56),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy || contacts.length >= 10
                ? null
                : _showContactEditor,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(contacts.length >= 10 ? '联系人已满' : '添加联系人'),
          ),
        ),
      ],
    );
  }

  Future<void> _showContactEditor() async {
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const _ContactEditorDialog(),
    );
    if (values != null) await _saveFeature(values, '联系人已添加');
  }

  Future<void> _deleteContact(Map<String, Object?> contact) async {
    final confirmed = await _confirm('删除联系人', '确定从手表删除这个联系人吗？');
    if (!confirmed) return;
    await _saveFeature({...contact, 'operation': 'delete'}, '联系人已删除');
  }

  Future<void> _toggleEmergencyContact(Map<String, Object?> contact) async {
    final enabled = contact['isEmergency'] != true;
    await _saveFeature({
      ...contact,
      'operation': 'emergency',
      'isEmergency': enabled,
    }, enabled ? '已设为紧急联系人' : '已取消紧急联系人');
  }

  Future<void> _editU19DynamicPressure() async {
    final current = _featureData['dynamicBloodPressure'];
    if (current is! Map) return;
    final original = Map<String, Object?>.from(current);
    var hour = (original['startHour'] as num?)?.toInt() ?? 8;
    var day = (original['dayIntervalMinutes'] as num?)?.toInt() ?? 60;
    var night = (original['nightIntervalMinutes'] as num?)?.toInt() ?? 60;
    if (!{60, 90, 120, 180}.contains(day)) day = 60;
    if (!{60, 90, 120, 180}.contains(night)) night = 60;
    final selected = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: const Key('u19-dynamic-pressure-editor'),
          scrollable: true,
          title: Text(_watchText('定时血压测量', 'Scheduled blood pressure')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _watchText(
                  '开启后手表会按间隔自动充气。请确认手表佩戴合适，并按个人需要谨慎设置。',
                  'The watch will inflate on a schedule. Check the fit and choose intervals carefully.',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('u19-dynamic-start-hour'),
                initialValue: hour,
                decoration: InputDecoration(
                  labelText: _watchText('首次开始时间', 'First start time'),
                ),
                items: [
                  for (var value = 0; value < 24; value++)
                    DropdownMenuItem(
                      value: value,
                      child: Text(
                        TimeOfDay(hour: value, minute: 0).format(context),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => hour = value);
                },
              ),
              const SizedBox(height: 12),
              for (final isDay in [true, false]) ...[
                DropdownButtonFormField<int>(
                  key: Key(
                    isDay
                        ? 'u19-dynamic-day-interval'
                        : 'u19-dynamic-night-interval',
                  ),
                  initialValue: isDay ? day : night,
                  decoration: InputDecoration(
                    labelText: isDay
                        ? _watchText('白天间隔', 'Day interval')
                        : _watchText('夜间间隔', 'Night interval'),
                  ),
                  items: [
                    for (final value in [60, 90, 120, 180])
                      DropdownMenuItem(
                        value: value,
                        child: Text(_watchText('$value 分钟', '$value min')),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        if (isDay) {
                          day = value;
                        } else {
                          night = value;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
              Text(
                _watchText(
                  '测量计划只供日常记录；如有不适请在手表上停止并取下表带。',
                  'For personal tracking only. If uncomfortable, stop on the watch and remove the band.',
                ),
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('u19-dynamic-pressure-enable'),
              onPressed: () => Navigator.pop(dialogContext, {
                'enabled': true,
                'startHour': hour,
                'dayIntervalMinutes': day,
                'nightIntervalMinutes': night,
              }),
              child: Text(_watchText('下一步', 'Continue')),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final confirmed = await _confirm(
      _watchText('确认开启定时充气？', 'Enable scheduled inflation?'),
      _watchText(
        '手表可能在白天和夜间反复充气。确定要启用吗？',
        'Your watch may inflate repeatedly, including at night. Continue?',
      ),
    );
    if (!confirmed || !mounted) return;
    await _saveFeature({
      'dynamicBloodPressure': selected,
    }, _watchText('已从手表确认设置', 'Confirmed by your watch'));
  }

  Widget _buildU19MonitoringPanel(bool busy) {
    if (_featureData.isEmpty) {
      return _loadingCard(busy, _watchText('健康监测', 'health monitoring'));
    }
    final dynamic = _featureData['dynamicBloodPressure'];
    final plan = dynamic is Map ? Map<String, Object?>.from(dynamic) : null;
    return Column(
      children: [
        for (final entry in [
          ('heartRate', _watchText('自动心率', 'Automatic heart rate')),
          ('bloodOxygen', _watchText('自动血氧', 'Automatic blood oxygen')),
        ])
          if (_featureData[entry.$1] is bool)
            Card(
              child: SwitchListTile(
                title: Text(entry.$2),
                value: _featureData[entry.$1] == true,
                onChanged: busy
                    ? null
                    : (value) => _saveFeature({
                        entry.$1: value,
                      }, _watchText('设置已保存', 'Setting saved')),
              ),
            ),
        if (plan != null)
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(_watchText('定时血压测量', 'Scheduled blood pressure')),
                  subtitle: Text(
                    plan['enabled'] == true
                        ? _watchText(
                            '已开启 · ${plan['startHour']}:00 起 · 白天 ${plan['dayIntervalMinutes']} 分钟 / 夜间 ${plan['nightIntervalMinutes']} 分钟',
                            'On · from ${_watchHour(context, plan['startHour'])} · day ${plan['dayIntervalMinutes']} min / night ${plan['nightIntervalMinutes']} min',
                          )
                        : _watchText('已关闭', 'Off'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : _editU19DynamicPressure,
                          child: Text(_watchText('设置计划', 'Set schedule')),
                        ),
                      ),
                      if (plan['enabled'] == true) ...[
                        const SizedBox(width: 10),
                        TextButton(
                          key: const Key('u19-dynamic-pressure-disable'),
                          onPressed: busy
                              ? null
                              : () => _saveFeature({
                                  'dynamicBloodPressure': {
                                    ...plan,
                                    'enabled': false,
                                  },
                                }, _watchText('已关闭', 'Turned off')),
                          child: Text(_watchText('关闭', 'Turn off')),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : _loadFeature,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_watchText('从手表刷新', 'Refresh from watch')),
        ),
      ],
    );
  }

  Future<void> _startU19Pulse() async {
    final confirmed = await _confirm(
      _watchText('开始脉搏分析？', 'Start pulse reading?'),
      _watchText(
        '请保持手表贴合手腕。测量由手表完成，结果仅供日常参考。',
        'Keep the watch snug. Results are for personal wellness tracking, not diagnosis.',
      ),
    );
    if (!confirmed || !mounted) return;
    final started = await _saveFeature(
      {'operation': 'start'},
      _watchText('手表已开始测量', 'Reading started on your watch'),
      reload: false,
    );
    if (mounted && started) setState(() => _pulseRequested = true);
  }

  Widget _buildU19PulsePanel(bool busy) {
    final raw = _featureData['pulse'];
    final pulse = raw is Map ? Map<String, Object?>.from(raw) : null;
    return Column(
      children: [
        if (pulse != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _watchText('手表脉搏指标', 'Watch pulse indices'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final item in [
                    (_watchText('血瘀', 'Flow'), pulse['bloodStasis']),
                    (_watchText('气血', 'Vitality'), pulse['qiBlood']),
                    (_watchText('湿气', 'Moisture'), pulse['dampness']),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.$1)),
                          Text(
                            '${item.$2 ?? '—'} / 10',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _watchText(
                      '以上为手表提供的指数，不用于疾病诊断。',
                      'Watch-provided wellness indices, not a diagnosis.',
                    ),
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: ListTile(
              title: Text(_watchText('暂无脉搏记录', 'No pulse reading yet')),
            ),
          ),
        if (_pulseRequested)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  _watchText(
                    '等待手表完成测量；需要中止时请在手表上操作。',
                    'Waiting for the watch. To stop, use the watch controls.',
                  ),
                ),
                TextButton(
                  key: const Key('u19-pulse-ended-on-watch'),
                  onPressed: () async {
                    final ended = await _confirm(
                      _watchText('手表已结束测量？', 'Finished on your watch?'),
                      _watchText(
                        '请先在手表上结束测量。确认后可以重新开始；此操作不会向手表发送停止指令。',
                        'End the reading on your watch first. This only clears the wait in the app.',
                      ),
                    );
                    if (ended && mounted) {
                      final cleared = await widget.controller
                          .writeDeviceFeature(widget.feature, const {
                            'operation': 'watchEnded',
                          });
                      if (cleared && mounted) {
                        setState(() => _pulseRequested = false);
                      }
                    }
                  },
                  child: Text(_watchText('我已在手表上结束', 'Finished on watch')),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('u19-pulse-start'),
            onPressed: busy || _pulseRequested ? null : _startU19Pulse,
            child: Text(_watchText('开始测量', 'Start reading')),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: busy ? null : _loadFeature,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_watchText('读取手表记录', 'Read watch history')),
        ),
      ],
    );
  }

  Future<void> _selectEmergencyContact(
    List<Map<String, Object?>> contacts,
  ) async {
    final supported = contacts
        .where((contact) => contact['supportsEmergency'] == true)
        .toList(growable: false);
    if (supported.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前手表不支持设置 SOS 联系人')));
      return;
    }
    Map<String, Object?>? picked = supported.firstWhere(
      (contact) => contact['isEmergency'] == true,
      orElse: () => supported.first,
    );
    final selected = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.selectEmergencyContact,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.sosContactHint,
                  style: TextStyle(color: SaydianColors.muted, height: 1.5),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: supported.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = supported[index];
                      final chosen = identical(picked, contact);
                      return Material(
                        color: chosen
                            ? SaydianColors.brandRedSoft
                            : const Color(0xFFF7F7F8),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: chosen
                                ? SaydianColors.brandRed
                                : const Color(0xFFE4E4E7),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          onTap: () => setSheetState(() => picked = contact),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            child: Text(_contactInitial(contact)),
                          ),
                          title: Text(
                            '${contact['name'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text('${contact['phone'] ?? ''}'),
                          trailing: Icon(
                            chosen
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: chosen
                                ? SaydianColors.brandRed
                                : SaydianColors.muted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: picked == null
                      ? null
                      : () => Navigator.pop(sheetContext, picked),
                  icon: const Icon(Icons.sos_rounded),
                  label: Text(context.l10n.confirmEmergencyContact),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && selected['isEmergency'] != true) {
      await _toggleEmergencyContact(selected);
    }
  }

  String _contactInitial(Map<String, Object?> contact) {
    final name = '${contact['name'] ?? '联'}'.trim();
    return name.isEmpty ? '联' : name.substring(0, 1);
  }

  Widget _buildWorldClocksPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '世界时钟');
    final clocks = _items;
    return Column(
      children: [
        Card(
          child: clocks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('手表中还没有世界时钟')),
                )
              : Column(
                  children: [
                    for (var index = 0; index < clocks.length; index++) ...[
                      ListTile(
                        leading: const Icon(Icons.public_rounded),
                        title: Text('${clocks[index]['city'] ?? ''}'),
                        subtitle: Text(
                          _utcLabel(
                            (clocks[index]['utcOffsetMinutes'] as num?)
                                    ?.toInt() ??
                                0,
                          ),
                        ),
                        trailing: IconButton(
                          onPressed: busy
                              ? null
                              : () => _deleteWorldClock(clocks[index]),
                          tooltip: '删除',
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                      if (index != clocks.length - 1) const Divider(indent: 56),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy || clocks.length >= 10
                ? null
                : _showWorldClockEditor,
            icon: const Icon(Icons.add_rounded),
            label: Text(clocks.length >= 10 ? '世界时钟已满' : '添加城市'),
          ),
        ),
      ],
    );
  }

  Future<void> _showWorldClockEditor() async {
    const cities = <(String, int)>[
      ('北京', 480),
      ('东京', 540),
      ('新加坡', 480),
      ('迪拜', 240),
      ('伦敦', 0),
      ('巴黎', 60),
      ('纽约', -300),
      ('洛杉矶', -480),
      ('悉尼', 600),
    ];
    var selected = cities.first;
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.addWorldClock),
          content: DropdownButtonFormField<(String, int)>(
            initialValue: selected,
            decoration: InputDecoration(labelText: context.l10n.city),
            items: [
              for (final city in cities)
                DropdownMenuItem(
                  value: city,
                  child: Text('${city.$1}  ${_utcLabel(city.$2)}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, <String, Object?>{
                'operation': 'add',
                'city': selected.$1,
                'utcOffsetMinutes': selected.$2,
                'enabled': true,
              }),
              child: Text(context.l10n.add),
            ),
          ],
        ),
      ),
    );
    if (values != null) await _saveFeature(values, '世界时钟已添加');
  }

  Future<void> _deleteWorldClock(Map<String, Object?> clock) async {
    final confirmed = await _confirm('删除世界时钟', '确定从手表删除这个城市吗？');
    if (!confirmed) return;
    await _saveFeature({...clock, 'operation': 'delete'}, '世界时钟已删除');
  }

  String _utcLabel(int minutes) {
    final sign = minutes >= 0 ? '+' : '-';
    final absolute = minutes.abs();
    return 'UTC$sign${(absolute ~/ 60).toString().padLeft(2, '0')}:${(absolute % 60).toString().padLeft(2, '0')}';
  }

  Widget _buildHealthRemindersPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '健康提醒');
    final reminders = _items;
    return Card(
      child: reminders.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('当前手表没有可设置的健康提醒')),
            )
          : Column(
              children: [
                for (var index = 0; index < reminders.length; index++) ...[
                  ListTile(
                    onTap: busy
                        ? null
                        : () => _showReminderEditor(reminders[index]),
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text('${reminders[index]['label'] ?? '健康提醒'}'),
                    subtitle: Text(
                      '${_minutesLabel((reminders[index]['startMinutes'] as num?)?.toInt() ?? 0)}–'
                      '${_minutesLabel((reminders[index]['endMinutes'] as num?)?.toInt() ?? 0)}，'
                      '每 ${(reminders[index]['intervalMinutes'] as num?)?.toInt() ?? 60} 分钟',
                    ),
                    trailing: Switch(
                      value: reminders[index]['enabled'] == true,
                      onChanged: busy
                          ? null
                          : (value) => _saveFeature({
                              ...reminders[index],
                              'enabled': value,
                            }, value ? '提醒已开启' : '提醒已关闭'),
                    ),
                  ),
                  if (index != reminders.length - 1) const Divider(indent: 56),
                ],
              ],
            ),
    );
  }

  Future<void> _showReminderEditor(Map<String, Object?> reminder) async {
    var startMinutes = (reminder['startMinutes'] as num?)?.toInt() ?? 480;
    var endMinutes = (reminder['endMinutes'] as num?)?.toInt() ?? 1320;
    final reportedInterval =
        (reminder['intervalMinutes'] as num?)?.toInt() ?? 60;
    var interval = reportedInterval >= 15 && reportedInterval <= 240
        ? reportedInterval
        : 60;
    final intervalOptions = <int>{
      15,
      30,
      45,
      60,
      90,
      120,
      180,
      240,
      interval,
    }.toList(growable: false)..sort();
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${reminder['label'] ?? '健康提醒'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.startTime),
                trailing: Text(_minutesLabel(startMinutes)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay(
                      hour: startMinutes ~/ 60,
                      minute: startMinutes % 60,
                    ),
                  );
                  if (time != null) {
                    setDialogState(
                      () => startMinutes = time.hour * 60 + time.minute,
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.endTime),
                trailing: Text(_minutesLabel(endMinutes)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay(
                      hour: endMinutes ~/ 60,
                      minute: endMinutes % 60,
                    ),
                  );
                  if (time != null) {
                    setDialogState(
                      () => endMinutes = time.hour * 60 + time.minute,
                    );
                  }
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: interval,
                decoration: InputDecoration(
                  labelText: context.l10n.reminderInterval,
                ),
                items: intervalOptions
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes 分钟'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => interval = value ?? interval),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, <String, Object?>{
                ...reminder,
                'startMinutes': startMinutes,
                'endMinutes': endMinutes,
                'intervalMinutes': interval,
              }),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
    if (values != null) await _saveFeature(values, '健康提醒已保存');
  }

  Widget _buildHealthAssessmentPanel(bool busy) {
    if (_featureData.isEmpty) return _loadingCard(busy, '辅助评估设置');
    final items = _items;
    if (items.isEmpty) {
      return FeatureStateCard(
        message: context.l10n.noHealthAssessments,
        detail: context.l10n.modelFeaturesVary,
        icon: Icons.assignment_turned_in_outlined,
      );
    }
    return Column(
      children: [
        Card(
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                SwitchListTile(
                  secondary: const Icon(Icons.health_and_safety_outlined),
                  title: Text('${items[index]['label'] ?? '健康辅助功能'}'),
                  subtitle: Text(context.l10n.assessmentEnabledHint),
                  value: items[index]['enabled'] == true,
                  onChanged: busy
                      ? null
                      : (value) => _saveFeature({
                          ...items[index],
                          'enabled': value,
                        }, value ? '已开启' : '已关闭'),
                ),
                if (index != items.length - 1) const Divider(indent: 56),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.assessmentSafety,
          textAlign: TextAlign.center,
          style: TextStyle(color: SaydianColors.muted, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildHealthMonitoringPanel() {
    final settings = widget.controller.autoMeasureSettings;
    final warningSupported = widget.controller.heartRateWarningSupported;
    if (settings.isEmpty && !warningSupported) {
      return FeatureStateCard(
        message: widget.controller.deviceSettingsStatus,
        icon: Icons.monitor_heart_outlined,
        actionLabel: '重新读取',
        onAction: widget.controller.refreshDeviceSettings,
      );
    }
    const labels = <String, String>{
      'heartRate': '心率自动检测',
      'bloodPressure': '血压自动检测',
      'bloodGlucose': '血糖自动检测',
      'bodyTemperature': '体温自动检测',
    };
    final entries = settings.entries.toList(growable: false);
    return Column(
      children: [
        Card(
          child: Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                SwitchListTile(
                  secondary: const Icon(Icons.sensors_rounded),
                  title: Text(labels[entries[index].key] ?? entries[index].key),
                  subtitle: Text(context.l10n.autoMonitorIntervalHint),
                  value: entries[index].value,
                  onChanged: (enabled) => widget.controller
                      .setAutoMeasureSetting(entries[index].key, enabled),
                ),
                if (index != entries.length - 1)
                  const Divider(height: 1, indent: 56),
              ],
            ],
          ),
        ),
        if (warningSupported) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: SaydianColors.orange,
              ),
              title: Text(context.l10n.watchHeartRateAlert),
              subtitle: Text(context.l10n.sustainedLimitWatchAlert),
              trailing: DropdownButton<int>(
                value: widget.controller.heartRateWarning,
                items: [
                  for (var value = 70; value <= 185; value += 5)
                    DropdownMenuItem(value: value, child: Text('$value bpm')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    widget.controller.setHeartRateWarning(value);
                  }
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.controller.refreshDeviceSettings,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(widget.controller.deviceSettingsStatus),
        ),
      ],
    );
  }

  String _minutesLabel(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      ) ??
      false;
}

class _WatchFaceThumbnail extends StatelessWidget {
  const _WatchFaceThumbnail({required this.face});

  final Map<String, Object?> face;

  @override
  Widget build(BuildContext context) {
    final source = _imageSource;
    final fallback = _fallback;
    Widget image = fallback;
    if (source != null) {
      final uri = Uri.tryParse(source);
      if (uri != null && uri.isScheme('https')) {
        image = SafeNetworkImage(
          source,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      } else {
        final file = File(source.replaceFirst('file://', ''));
        if (file.existsSync()) {
          image = Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        }
      }
    }
    return Semantics(
      image: true,
      label: source == null
          ? '${face['name'] ?? '表盘'}预览暂不可用'
          : '${face['name'] ?? '表盘'}缩略图',
      child: Container(
        width: 62,
        height: 62,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.black12),
        ),
        child: image,
      ),
    );
  }

  String? get _imageSource {
    return DeviceWatchFaceMarketService.findUsablePreviewReference(face);
  }

  Widget get _fallback {
    return ColoredBox(
      color: const Color(0xFFF1F3F5),
      child: Center(
        child: Text(
          '预览\n暂不可用',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SaydianColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FindWatchPanel extends StatelessWidget {
  const _FindWatchPanel({
    required this.finding,
    required this.busy,
    required this.supportsStop,
    required this.onPressed,
  });

  final bool finding;
  final bool busy;
  final bool supportsStop;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode != 'zh';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              finding
                  ? Icons.notifications_active_rounded
                  : Icons.watch_rounded,
              size: 68,
              color: finding ? SaydianColors.orange : SaydianColors.ink,
            ),
            const SizedBox(height: 14),
            Text(
              finding
                  ? (supportsStop
                        ? (english
                              ? 'Listen or feel for your nearby watch.'
                              : '请留意附近响铃或振动的手表')
                        : (english
                              ? 'Find request sent. Watch for a vibration.'
                              : '查找指令已发送，请留意手表振动'))
                  : (english
                        ? 'Make your watch ring or vibrate to find it.'
                        : '让手表响铃或振动，帮助你快速找到它'),
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy || (finding && !supportsStop)
                    ? null
                    : onPressed,
                child: Text(
                  finding
                      ? (supportsStop
                            ? (english ? 'Stop finding' : '停止查找')
                            : (english ? 'Finding…' : '正在查找'))
                      : (english ? 'Find my watch' : '开始查找'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenSettingsPanel extends StatelessWidget {
  const _ScreenSettingsPanel({
    required this.settings,
    required this.busy,
    required this.onReload,
    required this.onChanged,
    required this.onSave,
  });

  final DeviceScreenSettings? settings;
  final bool busy;
  final VoidCallback onReload;
  final ValueChanged<DeviceScreenSettings> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final value = settings;
    if (value == null) {
      return FeatureStateCard(
        message: busy
            ? _usText(context, 'Loading display settings…', '正在读取手表设置')
            : _usText(context, 'Could not load display settings', '暂时未读取到屏幕设置'),
        detail: _usText(
          context,
          'Keep your watch nearby and try again.',
          '请保持手表靠近手机后重试。',
        ),
        icon: Icons.brightness_6_outlined,
        actionLabel: busy ? null : context.l10n.retry,
        onAction: busy ? null : onReload,
      );
    }
    final maximum = value.maximumBrightness.clamp(1, 10);
    final current = value.brightness.clamp(1, maximum);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (value.brightnessSupported) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.autoBrightness),
                subtitle: Text(context.l10n.screenAutoTimeHint),
                value: value.automaticBrightness,
                onChanged: busy
                    ? null
                    : (enabled) => onChanged(
                        value.copyWith(automaticBrightness: enabled),
                      ),
              ),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                _usText(
                  context,
                  'Brightness  $current / $maximum',
                  '屏幕亮度  $current / $maximum',
                ),
              ),
              Slider(
                value: current.toDouble(),
                min: 1,
                max: maximum.toDouble(),
                divisions: maximum > 1 ? maximum - 1 : 1,
                onChanged: busy
                    ? null
                    : (next) => onChanged(
                        value.copyWith(
                          brightness: next.round(),
                          automaticBrightness: false,
                        ),
                      ),
              ),
            ],
            if (value.durationSeconds != null &&
                value.minimumDurationSeconds != null &&
                value.maximumDurationSeconds != null) ...[
              if (value.brightnessSupported) ...[
                const Divider(),
                const SizedBox(height: 12),
              ],
              Text(context.l10n.screenTimeoutSeconds(value.durationSeconds!)),
              Slider(
                value: value.durationSeconds!.toDouble().clamp(
                  value.minimumDurationSeconds!.toDouble(),
                  value.maximumDurationSeconds!.toDouble(),
                ),
                min: value.minimumDurationSeconds!.toDouble(),
                max: value.maximumDurationSeconds!.toDouble(),
                divisions:
                    (value.maximumDurationSeconds! -
                            value.minimumDurationSeconds!) >
                        0
                    ? value.maximumDurationSeconds! -
                          value.minimumDurationSeconds!
                    : 1,
                onChanged: busy
                    ? null
                    : (next) => onChanged(
                        value.copyWith(durationSeconds: next.round()),
                      ),
              ),
            ],
            if (value.raiseToWakeSupported) ...[
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.raiseToWake),
                subtitle: Text(context.l10n.raiseWristScreenHint),
                value: value.raiseToWakeEnabled,
                onChanged: busy
                    ? null
                    : (enabled) => onChanged(
                        value.copyWith(raiseToWakeEnabled: enabled),
                      ),
              ),
              if (value.raiseToWakeCustomTimeSupported) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.activeTime),
                  subtitle: Text(
                    '${_timeLabel(context, value.raiseToWakeStartMinutes)}–${_timeLabel(context, value.raiseToWakeEndMinutes)}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: busy
                      ? null
                      : () => _pickRaiseTime(context, value, onChanged),
                ),
                Text(
                  _usText(
                    context,
                    'Raise-to-wake sensitivity  ${value.raiseToWakeSensitivity} / 10',
                    '抬腕灵敏度  ${value.raiseToWakeSensitivity} / 10',
                  ),
                ),
                Slider(
                  value: value.raiseToWakeSensitivity.toDouble().clamp(1, 10),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: busy
                      ? null
                      : (next) => onChanged(
                          value.copyWith(raiseToWakeSensitivity: next.round()),
                        ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onSave,
                child: Text(context.l10n.saveSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRaiseTime(
    BuildContext context,
    DeviceScreenSettings value,
    ValueChanged<DeviceScreenSettings> onChanged,
  ) async {
    final start = await showTimePicker(
      context: context,
      helpText: _usText(context, 'Start time', '选择开始时间'),
      initialTime: TimeOfDay(
        hour: value.raiseToWakeStartMinutes ~/ 60,
        minute: value.raiseToWakeStartMinutes % 60,
      ),
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: _usText(context, 'End time', '选择结束时间'),
      initialTime: TimeOfDay(
        hour: value.raiseToWakeEndMinutes ~/ 60,
        minute: value.raiseToWakeEndMinutes % 60,
      ),
    );
    if (end == null) return;
    onChanged(
      value.copyWith(
        raiseToWakeStartMinutes: start.hour * 60 + start.minute,
        raiseToWakeEndMinutes: end.hour * 60 + end.minute,
      ),
    );
  }

  String _timeLabel(BuildContext context, int value) =>
      TimeOfDay(hour: value ~/ 60, minute: value % 60).format(context);
}
