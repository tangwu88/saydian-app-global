import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';
import 'app_theme.dart';

/// Mode numbers are vendor-specific. Only modes supplied by the connected
/// bridge are selectable; an unread mode never becomes an "off" selection.
class RingGestureControlPanel extends StatefulWidget {
  const RingGestureControlPanel({required this.controller, super.key});
  final AppController controller;

  @override
  State<RingGestureControlPanel> createState() =>
      _RingGestureControlPanelState();
}

class _RingGestureControlPanelState extends State<RingGestureControlPanel> {
  String _copy(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  Map<String, Object?> _settings = const {};
  String? _message;
  bool _busy = false;
  Object? _revision;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _revision = widget.controller.wearableSettingsRevision;
    _deviceId = widget.controller.connectedDevice?.id;
    widget.controller.addListener(_onDeviceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_read()));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDeviceChanged);
    super.dispose();
  }

  void _onDeviceChanged() {
    final controller = widget.controller;
    if (_revision == controller.wearableSettingsRevision &&
        _deviceId == controller.connectedDevice?.id) {
      return;
    }
    _revision = controller.wearableSettingsRevision;
    _deviceId = controller.connectedDevice?.id;
    if (!mounted) return;
    setState(() {
      _settings = const {};
      _busy = false;
      _message = _copy(
        '设备连接已改变，请重新读取设置',
        'The connection changed. Refresh the settings.',
      );
    });
  }

  bool _current(Object? revision, String? deviceId) =>
      mounted &&
      revision == widget.controller.wearableSettingsRevision &&
      deviceId != null &&
      deviceId == widget.controller.connectedDevice?.id;

  Future<void> _read() async {
    if (!mounted || _busy) return;
    final controller = widget.controller;
    final revision = controller.wearableSettingsRevision;
    final deviceId = controller.connectedDevice?.id;
    setState(() {
      _busy = true;
      _message = null;
    });
    final value = await controller.readDeviceFeature(
      DeviceFeature.gestureControl,
    );
    if (!_current(revision, deviceId)) return;
    setState(() {
      _busy = false;
      _settings = value;
      _message = controller.errorMessage;
    });
  }

  Future<void> _save(int mode) async {
    if (_busy) return;
    final controller = widget.controller;
    final revision = controller.wearableSettingsRevision;
    final deviceId = controller.connectedDevice?.id;
    final previous = _settings;
    setState(() {
      _busy = true;
      _message = _copy('正在保存并确认', 'Saving and confirming…');
    });
    final saved = await controller
        .writeDeviceFeature(DeviceFeature.gestureControl, {
          'mode': mode,
          if (previous['confirmationScope'] == 'device')
            'expectedMode': previous['confirmedMode'],
        });
    if (!_current(revision, deviceId)) return;
    final failure = controller.errorMessage;
    final readback = await controller.readDeviceFeature(
      DeviceFeature.gestureControl,
    );
    if (!_current(revision, deviceId)) return;
    final confirmed = saved && readback['confirmedMode'] == mode;
    setState(() {
      _busy = false;
      _settings = readback;
      _message = confirmed
          ? readback['confirmationScope'] == 'connection'
                ? _copy('设备已确认手势指令', 'Gesture command confirmed by the device.')
                : _copy('手势模式已从设备确认', 'Gesture mode confirmed by the device.')
          : failure ??
                controller.errorMessage ??
                _copy(
                  '设备尚未确认该模式，请重新读取',
                  'The mode is not confirmed. Refresh and try again.',
                );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCoolWear =
        widget.controller.connectedDevice?.sdkSource ==
        WearableSdkSource.coolwear;
    final labels = isCoolWear
        ? {
            0: _copy('关闭', 'Off'),
            1: _copy('短视频', 'Short videos'),
            2: _copy('音乐', 'Music'),
            3: _copy('阅读', 'Reading'),
            4: _copy('拍照', 'Camera'),
            5: _copy('电话', 'Calls'),
          }
        : {
            0: _copy('关闭', 'Off'),
            1: _copy('音乐', 'Music'),
            2: _copy('短视频', 'Short videos'),
            3: _copy('赞念', 'Counter'),
            4: _copy('阅读', 'Reading'),
            5: _copy('拍照', 'Camera'),
            6: _copy('电话', 'Calls'),
            7: _copy('游戏', 'Games'),
          };
    final modes =
        (_settings['supportedModes'] as List?)
            ?.whereType<int>()
            .where(labels.containsKey)
            .toList() ??
        const <int>[];
    final confirmedMode = _settings['confirmedMode'];
    final requiresReconnect = _settings['requiresReconnect'] == true;
    final canSave =
        !_busy &&
        !requiresReconnect &&
        modes.isNotEmpty &&
        (_settings['confirmationScope'] != 'device' || confirmedMode is int);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _copy('手势模式', 'Gesture mode'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              key: const Key('ring-gesture-refresh'),
              tooltip: _copy('从设备刷新', 'Refresh from device'),
              onPressed: _busy ? null : _read,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        Text(
          _settings['touch'] == true
              ? _copy('选择设备触控模式', 'Choose a touch mode')
              : _copy('选择设备手势模式', 'Choose a gesture mode'),
          style: const TextStyle(color: SaydianColors.muted),
        ),
        const SizedBox(height: 12),
        if (_message != null) ...[
          Text(
            Localizations.localeOf(context).languageCode == 'en' &&
                    RegExp(r'[\u3400-\u9fff]').hasMatch(_message!)
                ? 'Could not confirm the device setting. Refresh and try again.'
                : _message!,
            key: const Key('ring-gesture-status'),
          ),
          const SizedBox(height: 12),
        ],
        if (!_busy && modes.isEmpty)
          Text(
            _copy(
              '尚未读取到可设置模式，请刷新设备设置。',
              'No supported modes have been read. Refresh the device settings.',
            ),
          ),
        if (confirmedMode == null && modes.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              _copy(
                '当前模式未知。设备确认后才会显示选中状态。',
                'Current mode unknown. A selection is shown only after confirmation.',
              ),
            ),
          ),
        if (confirmedMode is int && !modes.contains(confirmedMode))
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              _copy(
                '设备当前使用其他控制模式，可选择下面支持的模式。',
                'The device uses another control mode. Choose a supported mode below.',
              ),
            ),
          ),
        Card(
          child: Column(
            children: [
              for (final mode in modes)
                ListTile(
                  key: ValueKey('ring-gesture-mode-$mode'),
                  title: Text(labels[mode]!),
                  leading: Icon(
                    mode == 0 ? Icons.block_outlined : Icons.touch_app_outlined,
                    color: SaydianColors.brandRed,
                  ),
                  trailing: confirmedMode == mode
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: SaydianColors.brandRed,
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: canSave ? () => _save(mode) : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          requiresReconnect
              ? _copy(
                  '设备状态未确认，请重新连接后设置。',
                  'Device state is unconfirmed. Reconnect before changing settings.',
                )
              : _copy(
                  '一次使用一种控制模式。切换模式后，请在对应应用中试用；实际手势动作和兼容性取决于设备固件及手机系统。',
                  'Use one mode at a time. Try the mode in the corresponding app. Gestures and compatibility depend on the device firmware and phone system.',
                ),
          style: const TextStyle(color: SaydianColors.muted, fontSize: 12),
        ),
        if (_settings['confirmationScope'] == 'connection') ...[
          const SizedBox(height: 8),
          Text(
            _copy(
              '此设备不提供当前模式读取，仅保留本次连接内已确认的指令。',
              'This device cannot read back its current mode. Only commands confirmed during this connection are shown.',
            ),
            style: TextStyle(color: SaydianColors.muted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
