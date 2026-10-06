import 'widgets/safe_network_image.dart';
import '../l10n/global_locale_controller.dart';
import '../l10n/ui_labels.dart';
import 'global_care_page.dart';
import 'ios_wellness_scope.dart';
import 'global_auth_page.dart';
import 'global_legal_page.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/feature_models.dart';
import '../domain/ecg_waveform.dart';
import '../domain/health_interpretation.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';
import '../services/api_client.dart';
import '../services/camera_remote_shutter_gate.dart';
import '../services/device_weather_service.dart';
import '../services/device_watch_face_market_service.dart';
import '../services/health_analysis.dart';
import 'app_theme.dart';
import 'app_update_gate_scope.dart';
import 'brand_assets.dart';
import 'feature_visibility.dart';
import 'health_alert_copy.dart';
import 'watch_face_market_page.dart';

part 'ecg_pages.dart';
part 'device_feature_page.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _distributor = TextEditingController();
  bool _accepted = false;
  bool _obscure = true;
  bool _sendingCode = false;
  int _codeCountdown = 0;
  Timer? _codeTimer;

  @override
  void dispose() {
    _mobile.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    _distributor.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final mobile = _mobile.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      _message('请输入正确的中国大陆手机号');
      return;
    }
    setState(() => _sendingCode = true);
    final success = await widget.controller.sendSmsCode(
      mobile: mobile,
      usage: 'register',
    );
    if (!mounted) return;
    setState(() => _sendingCode = false);
    if (!success) {
      _message(widget.controller.errorMessage ?? '验证码发送失败，请稍后重试');
      return;
    }
    _message('验证码已发送，请注意查收');
    _codeTimer?.cancel();
    setState(() => _codeCountdown = 60);
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _codeCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _codeCountdown = 0);
      } else {
        setState(() => _codeCountdown--);
      }
    });
  }

  Future<void> _submit() async {
    final mobile = _mobile.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      _message('请输入正确的中国大陆手机号');
      return;
    }
    if (_password.text.length < 6) {
      _message('密码至少需要 6 位');
      return;
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(_code.text.trim())) {
      _message('请输入收到的短信验证码');
      return;
    }
    if (_password.text != _confirmation.text) {
      _message('两次输入的密码不一致');
      return;
    }
    if (!_accepted) {
      _message('请先阅读并同意用户协议与隐私政策');
      return;
    }
    final success = await widget.controller.register(
      mobile,
      _password.text,
      code: _code.text,
      privacyConsentGranted: true,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _message(widget.controller.errorMessage ?? '注册失败，请稍后重试');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.signUp)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            const Center(child: SaydianBrandLockup(width: 154)),
            const SizedBox(height: 28),
            TextField(
              key: const Key('registration-mobile'),
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: context.l10n.phoneNumber),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('registration-code'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: context.l10n.smsCode,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    key: const Key('registration-send-code'),
                    onPressed:
                        _sendingCode ||
                            _codeCountdown > 0 ||
                            widget.controller.isBusy
                        ? null
                        : _sendCode,
                    child: Text(
                      _sendingCode
                          ? '发送中'
                          : _codeCountdown > 0
                          ? '${_codeCountdown}s'
                          : '获取验证码',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: '设置密码',
                helperText: '至少 6 位',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmation,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: context.l10n.confirmPassword,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _distributor,
              decoration: const InputDecoration(
                labelText: '经销商编号（选填）',
                helperText: '没有可不填',
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('我已阅读并同意用户协议与隐私政策'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('registration-submit'),
              onPressed: widget.controller.isBusy ? null : _submit,
              child: widget.controller.isBusy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.l10n.signUp),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({this.controller, super.key});

  final AppController? controller;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _message;
  bool _obscure = true;
  bool _sendingCode = false;
  int _codeCountdown = 0;
  Timer? _codeTimer;

  @override
  void dispose() {
    _mobile.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final controller = widget.controller;
    if (controller == null) {
      setState(() => _message = '短信服务暂时无法使用，请稍后再试');
      return;
    }
    final mobile = _mobile.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      setState(() => _message = '请输入正确的中国大陆手机号');
      return;
    }
    setState(() {
      _sendingCode = true;
      _message = null;
    });
    final success = await controller.sendSmsCode(
      mobile: mobile,
      usage: 'up-pwd',
    );
    if (!mounted) return;
    setState(() {
      _sendingCode = false;
      _message = success
          ? '验证码已发送，请注意查收'
          : controller.errorMessage ?? '验证码发送失败，请稍后重试';
    });
    if (!success) return;
    _codeTimer?.cancel();
    setState(() => _codeCountdown = 60);
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _codeCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _codeCountdown = 0);
      } else {
        setState(() => _codeCountdown--);
      }
    });
  }

  Future<void> _submit() async {
    final controller = widget.controller;
    if (controller == null) {
      setState(() => _message = '找回密码服务暂时无法使用，请稍后再试');
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _message = '两次输入的新密码不一致');
      return;
    }
    final success = await controller.resetPassword(
      mobile: _mobile.text,
      code: _code.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码已重置，并已自动登录')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _message = controller.errorMessage ?? '密码重置失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('找回密码')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.lock_reset_rounded,
            size: 72,
            color: SaydianColors.blue,
          ),
          const SizedBox(height: 20),
          const Text(
            '验证手机号',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '输入注册手机号，验证通过后可重新设置密码。',
            textAlign: TextAlign.center,
            style: TextStyle(color: SaydianColors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          TextField(
            key: const Key('password-recovery-mobile'),
            controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: context.l10n.phoneNumber),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('password-recovery-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: context.l10n.smsCode,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  key: const Key('password-recovery-send-code'),
                  onPressed:
                      _sendingCode ||
                          _codeCountdown > 0 ||
                          (widget.controller?.isBusy ?? false)
                      ? null
                      : _sendCode,
                  child: Text(
                    _sendingCode
                        ? '发送中'
                        : _codeCountdown > 0
                        ? '${_codeCountdown}s'
                        : '获取验证码',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('password-recovery-password'),
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: '新密码',
              helperText: '至少 6 位',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('password-recovery-confirmation'),
            controller: _confirmation,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: '确认新密码'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 14),
            FeatureStateCard(
              message: _message!,
              icon: Icons.info_outline_rounded,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('password-recovery-submit'),
            onPressed: widget.controller?.isBusy == true ? null : _submit,
            child: Text(context.l10n.resetPassword),
          ),
        ],
      ),
    );
  }
}

class HealthWarningPage extends StatefulWidget {
  const HealthWarningPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<HealthWarningPage> createState() => _HealthWarningPageState();
}

class _HealthWarningPageState extends State<HealthWarningPage> {
  late bool _heartRateEnabled;
  late bool _bloodPressureEnabled;
  late bool _temperatureEnabled;
  late final TextEditingController _heartRateUpper;
  late final TextEditingController _systolicUpper;
  late final TextEditingController _diastolicUpper;
  late final TextEditingController _temperatureUpper;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.healthWarningSettings;
    _heartRateEnabled = settings.heartRateEnabled;
    _bloodPressureEnabled = settings.bloodPressureEnabled;
    _temperatureEnabled = settings.temperatureEnabled;
    _heartRateUpper = TextEditingController(text: '${settings.heartRateUpper}');
    _systolicUpper = TextEditingController(text: '${settings.systolicUpper}');
    _diastolicUpper = TextEditingController(text: '${settings.diastolicUpper}');
    _temperatureUpper = TextEditingController(
      text: settings.temperatureUpper.toStringAsFixed(1),
    );
    widget.controller.addListener(_refresh);
    if (!widget.controller.isIosWellnessEdition) {
      unawaited(widget.controller.refreshNotificationHistory(allPages: true));
      unawaited(widget.controller.markAllHealthWarningsRead());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _heartRateUpper.dispose();
    _systolicUpper.dispose();
    _diastolicUpper.dispose();
    _temperatureUpper.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    final heartRate = int.tryParse(_heartRateUpper.text.trim());
    final systolic = int.tryParse(_systolicUpper.text.trim());
    final diastolic = int.tryParse(_diastolicUpper.text.trim());
    final temperature = double.tryParse(_temperatureUpper.text.trim());
    if (heartRate == null ||
        systolic == null ||
        diastolic == null ||
        temperature == null) {
      _message(_usText(context, 'Enter a valid alert limit.', '请填写正确的报警数值'));
      return;
    }
    final success = await widget.controller.saveHealthWarningSettings(
      HealthWarningSettings(
        heartRateEnabled: _heartRateEnabled,
        heartRateUpper: heartRate,
        bloodPressureEnabled: _bloodPressureEnabled,
        systolicUpper: systolic,
        diastolicUpper: diastolic,
        temperatureEnabled: _temperatureEnabled,
        temperatureUpper: temperature,
      ),
    );
    if (!mounted) return;
    _message(
      success
          ? _usText(context, 'Alert settings saved.', '健康预警设置已保存')
          : _safeNotice(
              widget.controller.errorMessage,
              _usText(context, 'Couldn’t save. Try again.', '保存失败，请稍后重试'),
            ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isExplicitHealthWarning(Map<String, Object?> item) {
    final type = [
      item['type'],
      item['category'],
      item['message_type'],
      item['notice_type'],
    ].whereType<Object>().join(' ').toLowerCase();
    return type.contains('health') ||
        type.contains('warning') ||
        type.contains('健康') ||
        type.contains('预警');
  }

  String _warningStatus(Map<String, Object?> item) {
    final raw =
        [
              item['status_text'],
              item['level_text'],
              item['status_label'],
              item['level'],
            ]
            .whereType<Object>()
            .map((value) => '$value'.trim())
            .firstWhere(
              (value) => value.isNotEmpty && int.tryParse(value) == null,
              orElse: () => '',
            );
    final normalized = raw.toLowerCase();
    if (normalized.contains('high') || raw.contains('高')) {
      return _usText(context, 'High', '偏高');
    }
    if (normalized.contains('low') || raw.contains('低')) {
      return _usText(context, 'Low', '偏低');
    }
    if (normalized.contains('abnormal') || raw.contains('异常')) {
      return _usText(context, 'Needs attention', '异常');
    }
    return _safeNotice(raw, _usText(context, 'Alert', '异常提醒'));
  }

  String _safeNotice(Object? value, String fallback) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return fallback;
    if (Localizations.localeOf(context).languageCode != 'zh' &&
        RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      return fallback;
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isIosWellnessEdition) {
      return const IosWellnessUnavailablePage();
    }
    final warnings = widget.controller.notifications
        .where(_isExplicitHealthWarning)
        .toList();
    final loading = widget.controller.notificationStatus == '正在加载';
    final device = widget.controller.connectedDevice;
    final showTemperature =
        (!widget.controller.isGlobalEdition || device != null) &&
        device?.sdkSource != WearableSdkSource.urion;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.healthAlerts)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.controller.isGlobalEdition) ...[
            FeatureStateCard(
              message: context.l10n.setHealthUpperLimits,
              detail: context.l10n.healthUpperLimitHint,
              icon: Icons.notifications_active_outlined,
              color: SaydianColors.orange,
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('warning-heart-rate-switch'),
                    value: _heartRateEnabled,
                    onChanged: (value) =>
                        setState(() => _heartRateEnabled = value),
                    title: Text(context.l10n.heartRateAlertLabel),
                    subtitle: Text(context.l10n.heartRateAlertHint),
                    secondary: const Icon(Icons.favorite_rounded),
                  ),
                  if (_heartRateEnabled)
                    _WarningThresholdField(
                      key: const Key('warning-heart-rate-threshold'),
                      label: context.l10n.heartRateUpperLimit,
                      controller: _heartRateUpper,
                      unit: 'bpm',
                    ),
                  const Divider(height: 12),
                  SwitchListTile(
                    key: const Key('warning-blood-pressure-switch'),
                    value: _bloodPressureEnabled,
                    onChanged: (value) =>
                        setState(() => _bloodPressureEnabled = value),
                    title: Text(context.l10n.bloodPressureAlertLabel),
                    subtitle: Text(context.l10n.bloodPressureAlertHint),
                    secondary: const Icon(Icons.bloodtype_outlined),
                  ),
                  if (_bloodPressureEnabled) ...[
                    _WarningThresholdField(
                      key: const Key('warning-systolic-threshold'),
                      label: context.l10n.systolicUpperLimit,
                      controller: _systolicUpper,
                      unit: 'mmHg',
                    ),
                    const SizedBox(height: 10),
                    _WarningThresholdField(
                      key: const Key('warning-diastolic-threshold'),
                      label: context.l10n.diastolicUpperLimit,
                      controller: _diastolicUpper,
                      unit: 'mmHg',
                    ),
                  ],
                  if (showTemperature) ...[
                    const Divider(height: 12),
                    SwitchListTile(
                      key: const Key('warning-temperature-switch'),
                      value: _temperatureEnabled,
                      onChanged: (value) =>
                          setState(() => _temperatureEnabled = value),
                      title: Text(context.l10n.temperatureAlertLabel),
                      subtitle: Text(context.l10n.temperatureAlertHint),
                      secondary: const Icon(Icons.thermostat_rounded),
                    ),
                    if (_temperatureEnabled)
                      _WarningThresholdField(
                        key: const Key('warning-temperature-threshold'),
                        label: context.l10n.temperatureUpperLimit,
                        controller: _temperatureUpper,
                        unit: '℃',
                        decimal: true,
                      ),
                  ],
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FilledButton.icon(
                      key: const Key('warning-save'),
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(context.l10n.saveHealthAlerts),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.healthAlertHistory,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final alert in widget.controller.healthWarningAlerts)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: SaydianColors.danger,
                ),
                title: Text(healthAlertTitle(context, alert)),
                subtitle: Text(
                  '${healthAlertMessage(context, alert)}\n${_usText(context, 'Source: ', '来源：')}${healthAlertOrigin(context, alert.origin)}',
                ),
                trailing: Text(
                  Localizations.localeOf(context).languageCode == 'zh'
                      ? DateFormat(
                          'yyyy-MM-dd\nHH:mm',
                        ).format(alert.triggeredAt)
                      : DateFormat.MMMd(
                          context.l10n.localeName,
                        ).add_jm().format(alert.triggeredAt),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (warnings.isEmpty &&
              widget.controller.healthWarningAlerts.isEmpty)
            FeatureStateCard(
              message:
                  widget.controller.notificationStatus == '已加载' ||
                      widget.controller.notificationStatus == '暂无消息'
                  ? _usText(context, 'No alerts', '暂无健康预警')
                  : _safeNotice(
                      widget.controller.notificationStatus,
                      _usText(
                        context,
                        'Couldn’t load alerts. Pull to retry.',
                        '暂时无法读取预警',
                      ),
                    ),
              icon: Icons.health_and_safety_outlined,
              color: SaydianColors.green,
            )
          else
            for (final warning in warnings)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(
                    Icons.health_and_safety_outlined,
                    color: SaydianColors.orange,
                  ),
                  title: Text(
                    _safeNotice(
                      warning['title'] ?? warning['name'],
                      _usText(context, 'Health alert', '健康提醒'),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: SaydianColors.orange,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _warningStatus(warning),
                              style: const TextStyle(
                                color: SaydianColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _safeNotice(
                            warning['content'] ??
                                warning['message'] ??
                                warning['created_at'],
                            _usText(
                              context,
                              'Check your latest reading.',
                              '健康预警',
                            ),
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 14),
          if (widget.controller.isGlobalEdition)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.medical_information_outlined,
                      color: SaydianColors.info,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.seekProfessionalCare,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            context.l10n.watchHealthReference,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: SaydianColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            FeatureStateCard(
              message: context.l10n.seekProfessionalCare,
              detail: context.l10n.watchHealthReference,
              icon: Icons.medical_information_outlined,
            ),
        ],
      ),
    );
  }
}

class _WarningThresholdField extends StatelessWidget {
  const _WarningThresholdField({
    required this.label,
    required this.controller,
    required this.unit,
    this.decimal = false,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String unit;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 112,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          SizedBox(width: 62, child: Text(unit, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class SharingManagementPage extends StatelessWidget {
  const SharingManagementPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final targets = <Map<String, Object?>>[];
    final seenMemberIds = <int>{};
    for (final invitation in controller.careInvitations) {
      final status = int.tryParse('${invitation['examine_status'] ?? 0}') ?? 0;
      final inviterId = int.tryParse('${invitation['inviter_id'] ?? 0}') ?? 0;
      if (status != 1 || inviterId <= 0 || !seenMemberIds.add(inviterId)) {
        continue;
      }
      final rawMember = invitation['member'];
      final member = rawMember is Map
          ? rawMember.map(
              (key, value) => MapEntry<String, Object?>('$key', value),
            )
          : const <String, Object?>{};
      targets.add({
        'member_id': inviterId,
        'nickname': '${member['nickname'] ?? ''}'.trim(),
        'mobile': '${member['mobile'] ?? ''}'.trim(),
        'head_portrait': '${member['head_portrait'] ?? ''}'.trim(),
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('共享管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FeatureStateCard(
            message: '默认不共享任何健康数据',
            detail: '家人接受邀请并选择允许的健康项目后，对方才能查看。',
            icon: Icons.privacy_tip_outlined,
            color: SaydianColors.green,
          ),
          const SizedBox(height: 14),
          if (targets.isEmpty)
            const FeatureStateCard(
              message: '暂无需要授权的关爱人',
              detail: '收到并同意家人的关爱邀请后，可在这里选择允许对方查看的健康项目。',
              icon: Icons.group_outlined,
            )
          else
            for (final member in targets)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () {
                    final memberId = int.tryParse(
                      '${member['member_id'] ?? 0}',
                    );
                    if (memberId == null || memberId == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('成员信息不完整，暂时无法设置共享项目')),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CareShareSettingsPage(
                          controller: controller,
                          member: member,
                          memberId: memberId,
                        ),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    foregroundImage:
                        '${member['head_portrait'] ?? ''}'.startsWith('http')
                        ? SafeNetworkImageProvider('${member['head_portrait']}')
                        : null,
                    child: const Icon(Icons.person_outline),
                  ),
                  title: Text(
                    '${member['nickname'] ?? ''}'.trim().isNotEmpty
                        ? '${member['nickname']}'.trim()
                        : '关爱邀请人',
                  ),
                  subtitle: Text(
                    '${member['mobile'] ?? ''}'.trim().isNotEmpty
                        ? '${member['mobile']} · 设置允许查看的健康项目'
                        : '邀请人账号 ID：${member['member_id']} · 设置允许查看的健康项目',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
        ],
      ),
    );
  }
}

class CareShareSettingsPage extends StatefulWidget {
  const CareShareSettingsPage({
    required this.controller,
    required this.member,
    required this.memberId,
    super.key,
  });

  final AppController controller;
  final Map<String, Object?> member;
  final int memberId;

  @override
  State<CareShareSettingsPage> createState() => _CareShareSettingsPageState();
}

class _CareShareSettingsPageState extends State<CareShareSettingsPage> {
  static const _dailyKeys = <String, String>{
    'steps': '步数',
    'reliang': '卡路里',
    'juli': '距离',
    'sleep': '总睡眠',
  };
  static const _healthKeys = <String, String>{
    'bloodPressure': '血压',
    'bloodGlucose': '血糖',
    'bloodOxygen': '血氧',
    'bodyTemperature': '体温',
    'ecg': '心电图',
    'heartReat': '心率',
    'HRV': 'HRV',
    'bodycomposition': '身体成分',
    'bloodcomposition': '血液成分',
  };

  Set<String> _enabled = const {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late final int _sessionGeneration;
  int _requestGeneration = 0;
  bool _sessionChanged = false;

  bool get _sessionCurrent =>
      !_sessionChanged &&
      widget.controller.isCareShareSessionCurrent(_sessionGeneration);

  bool get _canEdit =>
      _sessionCurrent && !_loading && !_saving && _error == null;

  @override
  void initState() {
    super.initState();
    _sessionGeneration = widget.controller.careShareSessionGeneration;
    widget.controller.addListener(_onSessionChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted || _sessionChanged || _sessionCurrent) return;
    setState(() {
      _sessionChanged = true;
      _requestGeneration++;
      _loading = false;
      _saving = false;
    });
  }

  bool _isCurrentRequest(int generation) =>
      mounted && _sessionCurrent && _requestGeneration == generation;

  Future<void> _load() async {
    if (!_sessionCurrent || _saving) return;
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await widget.controller.loadCareShareSettings(
        memberId: widget.memberId,
      );
      if (!_isCurrentRequest(generation)) return;
      setState(() {
        _enabled = values;
        _loading = false;
      });
    } catch (_) {
      if (!_isCurrentRequest(generation)) return;
      setState(() {
        _error = '共享设置读取失败，请重新读取';
        _loading = false;
      });
    }
  }

  void _setGroup(Iterable<String> keys, bool enabled) {
    if (!_canEdit) return;
    setState(() {
      final values = {..._enabled};
      enabled ? values.addAll(keys) : values.removeAll(keys);
      _enabled = values;
    });
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    final generation = ++_requestGeneration;
    setState(() => _saving = true);
    final succeeded = await widget.controller.saveCareShareSettings(
      memberId: widget.memberId,
      settings: _enabled,
    );
    if (!mounted || !_isCurrentRequest(generation)) return;
    setState(() {
      _saving = false;
      _error = succeeded ? null : '保存未确认，请重新读取后重试';
    });
    if (succeeded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('共享设置已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${widget.member['nickname'] ?? widget.member['mobile'] ?? '关爱成员'}';
    return Scaffold(
      appBar: AppBar(title: const Text('共享数据管理')),
      body: !_sessionCurrent
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: FeatureStateCard(
                message: '账号已变化，请返回后重新查看',
                icon: Icons.person_outline,
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FeatureStateCard(
                  message: name,
                  detail: '仅共享已开启的项目，更改后请保存',
                  icon: Icons.privacy_tip_outlined,
                  color: SaydianColors.green,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  FeatureStateCard(
                    message: _error!,
                    icon: Icons.cloud_off_outlined,
                  ),
                ],
                const SizedBox(height: 14),
                _permissionGroup('每日数据', _dailyKeys),
                const SizedBox(height: 12),
                _permissionGroup('健康数据', _healthKeys),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _canEdit ? _save : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中' : '保存共享设置'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新读取共享设置'),
                ),
              ],
            ),
    );
  }

  Widget _permissionGroup(String title, Map<String, String> values) {
    final allEnabled = values.keys.every(_enabled.contains);
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: TextButton(
              onPressed: _canEdit
                  ? () => _setGroup(values.keys, !allEnabled)
                  : null,
              child: Text(allEnabled ? '全部关闭' : '全选'),
            ),
          ),
          for (final entry in values.entries) ...[
            const Divider(indent: 16),
            SwitchListTile(
              title: Text(entry.value),
              value: _enabled.contains(entry.key),
              onChanged: _canEdit
                  ? (enabled) => _setGroup([entry.key], enabled)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class CareInvitationsPage extends StatefulWidget {
  const CareInvitationsPage({
    required this.controller,
    this.targetInvitationId,
    super.key,
  });

  final AppController controller;
  final String? targetInvitationId;

  @override
  State<CareInvitationsPage> createState() => _CareInvitationsPageState();
}

class _CareInvitationsPageState extends State<CareInvitationsPage> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.isGlobalEdition) {
      unawaited(widget.controller.refreshCareInvitations());
    }
  }

  Future<void> _respond(Map<String, Object?> invite, bool accepted) async {
    final id = int.tryParse('${invite['id'] ?? 0}') ?? 0;
    if (id == 0) return;
    await widget.controller.respondCareInvitation(id: id, accepted: accepted);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isGlobalEdition) {
      return GlobalCarePage(controller: widget.controller);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('关爱邀请')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final invitations = widget.controller.pendingCareInvitations;
          final targetId = widget.targetInvitationId;
          final targetedMatches = targetId == null
              ? const <Map<String, Object?>>[]
              : widget.controller.careInvitations
                    .where(
                      (item) =>
                          '${item['id'] ?? item['invitation_id'] ?? ''}' ==
                          targetId,
                    )
                    .toList(growable: false);
          final targeted = targetedMatches.isEmpty
              ? null
              : targetedMatches.first;
          if (invitations.isEmpty) {
            return RefreshIndicator(
              onRefresh: widget.controller.refreshCareInvitations,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FeatureStateCard(
                    message: targeted != null
                        ? '该关爱邀请已处理'
                        : targetId != null &&
                              widget.controller.careInvitationStatus != '加载中'
                        ? '该关爱邀请已处理或撤销'
                        : widget.controller.careInvitationStatus == '服务暂不可用'
                        ? '关爱邀请服务暂不可用'
                        : '暂无新的关爱邀请',
                    icon: Icons.mark_email_unread_outlined,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: widget.controller.refreshCareInvitations,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: invitations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final invite = invitations[index];
                final member = invite['member'];
                final memberMap = member is Map ? member : const {};
                final nickname = '${memberMap['nickname'] ?? ''}'.trim();
                final mobile = '${memberMap['mobile'] ?? ''}'.trim();
                final avatar = '${memberMap['head_portrait'] ?? ''}'.trim();
                final inviterId = '${invite['inviter_id'] ?? ''}'.trim();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: SaydianColors.brandRedSoft,
                              foregroundImage:
                                  avatar.startsWith('http://') ||
                                      avatar.startsWith('https://')
                                  ? SafeNetworkImageProvider(avatar)
                                  : null,
                              child: const Icon(
                                Icons.person_rounded,
                                color: SaydianColors.brandRed,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nickname.isEmpty ? '赛电用户' : nickname,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    mobile.isNotEmpty
                                        ? mobile
                                        : inviterId.isNotEmpty
                                        ? '邀请人账号 ID：$inviterId'
                                        : '邀请人信息暂不可用',
                                    style: const TextStyle(
                                      color: SaydianColors.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (nickname.isEmpty && mobile.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '请确认邀请人后再接受',
                            style: TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _respond(invite, false),
                                child: const Text('拒绝'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _respond(invite, true),
                                child: const Text('同意'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class HealthCalibrationPage extends StatefulWidget {
  const HealthCalibrationPage({
    required this.controller,
    required this.metric,
    super.key,
  });

  final AppController controller;
  final HealthMetric metric;

  @override
  State<HealthCalibrationPage> createState() => _HealthCalibrationPageState();
}

class _HealthCalibrationPageState extends State<HealthCalibrationPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _primary;
  late final TextEditingController _secondary;
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _primary = TextEditingController(
      text: widget.metric == HealthMetric.bloodPressure ? '120' : '5.5',
    );
    _secondary = TextEditingController(text: '80');
  }

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final values = widget.metric == HealthMetric.bloodPressure
        ? <String, Object?>{
            'operation': 'bp_calibration',
            'enabled': _enabled,
            'systolic': int.tryParse(_primary.text.trim()) ?? 0,
            'diastolic': int.tryParse(_secondary.text.trim()) ?? 0,
          }
        : <String, Object?>{
            'operation': 'glucose_calibration',
            'enabled': _enabled,
            'value': double.tryParse(_primary.text.trim()) ?? 0,
          };
    final saved = await widget.controller.writeDeviceFeature(
      DeviceFeature.healthMonitoring,
      values,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? '${widget.metric.label}校准已保存到手表'
              : widget.controller.errorMessage ?? '校准保存失败，请稍后重试',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBloodPressure = widget.metric == HealthMetric.bloodPressure;
    if (widget.controller.isIosWellnessEdition) {
      return const IosWellnessUnavailablePage();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.metricCalibration(
            context.l10n.metricName(widget.metric),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FeatureStateCard(
              message: context.l10n.calibrationReferenceHint,
              detail: context.l10n.calibrationWearerHint,
              icon: Icons.verified_user_outlined,
              color: SaydianColors.info,
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.enableCalibration),
                      subtitle: Text(context.l10n.calibrationDisabledHint),
                      value: _enabled,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _enabled = value),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _primary,
                      enabled: _enabled && !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: isBloodPressure ? '收缩压（高压）' : '血糖校准值',
                        suffixText: isBloodPressure ? 'mmHg' : 'mmol/L',
                      ),
                      validator: (value) {
                        if (!_enabled) return null;
                        final number = double.tryParse(value?.trim() ?? '');
                        if (number == null) return '请输入有效数值';
                        if (isBloodPressure && (number < 60 || number > 300)) {
                          return '收缩压需在 60–300 mmHg';
                        }
                        if (!isBloodPressure && (number < 1 || number > 30)) {
                          return '血糖值需在 1.0–30.0 mmol/L';
                        }
                        return null;
                      },
                    ),
                    if (isBloodPressure) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _secondary,
                        enabled: _enabled && !_saving,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.l10n.diastolicLowerLabel,
                          suffixText: 'mmHg',
                        ),
                        validator: (value) {
                          if (!_enabled) return null;
                          final low = int.tryParse(value?.trim() ?? '');
                          final high = int.tryParse(_primary.text.trim());
                          if (low == null || low < 20 || low > 200) {
                            return '舒张压需在 20–200 mmHg';
                          }
                          if (high != null && low >= high) {
                            return '舒张压必须低于收缩压';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: Key('health-calibration-${widget.metric.wireName}'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '正在写入手表' : '保存校准'),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({this.controller, super.key});

  final AppController? controller;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _content = TextEditingController();
  final _contact = TextEditingController();
  String _category = '功能建议';
  String? _result;
  bool _submitting = false;

  @override
  void dispose() {
    _content.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_content.text.trim().length < 5) {
      setState(
        () => _result = _usText(
          context,
          'Please add a few more details (at least 5 characters).',
          '请至少填写 5 个字的问题说明',
        ),
      );
      return;
    }
    final controller = widget.controller;
    if (controller == null) {
      setState(() => _result = context.l10n.serviceUnavailable);
      return;
    }
    setState(() {
      _submitting = true;
      _result = null;
    });
    final success = await controller.submitFeedback(
      category: _category,
      content: _content.text,
      contact: _contact.text,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = success
          ? _usText(context, 'Thanks — your feedback was sent.', '反馈已提交，感谢你的建议')
          : _usText(
              context,
              'Could not send feedback. Please try again.',
              controller.errorMessage ?? '反馈提交失败，请稍后重试',
            );
      if (success) _content.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.helpFeedback)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.l10n.feedback,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(labelText: context.l10n.issueType),
            items: [
              DropdownMenuItem(
                value: '功能建议',
                child: Text(_usText(context, 'Feature suggestion', '功能建议')),
              ),
              DropdownMenuItem(
                value: '设备连接',
                child: Text(_usText(context, 'Watch connection', '设备连接')),
              ),
              DropdownMenuItem(
                value: '数据问题',
                child: Text(_usText(context, 'Readings', '数据问题')),
              ),
              if (showSaydianMall)
                DropdownMenuItem(
                  value: '商城订单',
                  child: Text(_usText(context, 'Shop order', '商城订单')),
                ),
            ],
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('feedback-content'),
            controller: _content,
            minLines: 5,
            maxLines: 8,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: context.l10n.issueDescription,
              hintText: context.l10n.describeIssue,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contact,
            decoration: InputDecoration(
              labelText: context.l10n.contactOptional,
              hintText: context.l10n.phoneOrEmail,
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            FeatureStateCard(message: _result!, icon: Icons.info_outline),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting
                  ? _usText(context, 'Sending…', '正在提交…')
                  : _usText(context, 'Send feedback', '提交反馈'),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _usText(context, 'Common questions', '常见问题'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ExpansionTile(
                  title: Text(
                    _usText(context, 'How do I connect my watch?', '如何连接手表？'),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      _usText(
                        context,
                        'Open Watch, tap Search for watches, and keep your watch nearby. Confirm on the watch if prompted.',
                        '打开“设备”页并选择添加设备。搜索时让手表保持亮屏、靠近手机，并在手表端确认配对。',
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1),
                ExpansionTile(
                  title: Text(
                    _usText(
                      context,
                      'Why are my readings empty?',
                      '为什么健康数据暂时为空？',
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      _usText(
                        context,
                        'Connect your watch and sync it. New readings appear after they are received.',
                        '请确认设备已连接并完成同步。设备不支持的项目不会开放入口；新测量数据同步后才会显示趋势。',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerServicePage extends StatelessWidget {
  const CustomerServicePage({
    this.isGlobalEdition = false,
    this.controller,
    super.key,
  });

  final bool isGlobalEdition;
  final AppController? controller;

  static const _phone = '4006386738';
  static const _officialAccount = '赛电';

  Future<void> _call(BuildContext context) async {
    final opened = await launchUrl(Uri(scheme: 'tel', path: _phone));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开拨号界面，请手动拨打 $_phone')));
    }
  }

  Future<void> _copyAccount(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _officialAccount));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('公众号“$_officialAccount”已复制，可前往微信搜索添加')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isGlobalEdition) {
      return _GlobalCustomerServicePage(controller: controller);
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.customerService)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.phone_outlined),
                  ),
                  title: Text(context.l10n.contactPhoneLabel),
                  subtitle: const Text(_phone),
                  trailing: FilledButton.tonal(
                    onPressed: () => _call(context),
                    child: Text(context.l10n.call),
                  ),
                ),
                const Divider(indent: 72, height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.wechat_rounded),
                  ),
                  title: Text(context.l10n.wechatOfficialAccount),
                  subtitle: const Text(_officialAccount),
                  trailing: FilledButton.tonal(
                    onPressed: () => _copyAccount(context),
                    child: Text(context.l10n.addSupportContact),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FeatureStateCard(
            message: context.l10n.contactPreparationHint,
            detail: context.l10n.supportPrivacyWarning,
            icon: Icons.privacy_tip_outlined,
          ),
        ],
      ),
    );
  }
}

class _GlobalCustomerServicePage extends StatelessWidget {
  const _GlobalCustomerServicePage({required this.controller});

  final AppController? controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-customer-service'),
    appBar: AppBar(title: Text(context.l10n.customerService)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.support_agent_outlined),
                ),
                title: Text(context.l10n.helpFeedback),
                subtitle: Text(context.l10n.contactPreparationHint),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: controller == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FeedbackPage(controller: controller),
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FeatureStateCard(
          message: context.l10n.globalSupportFeedbackHint,
          detail: context.l10n.supportPrivacyWarning,
          icon: Icons.privacy_tip_outlined,
        ),
      ],
    ),
  );
}

class AboutSaydianPage extends StatefulWidget {
  const AboutSaydianPage({
    required this.controller,
    this.updateGateController,
    this.packageInfoLoader,
    super.key,
  });

  final AppController controller;
  final AppUpdateGateController? updateGateController;
  final Future<PackageInfo> Function()? packageInfoLoader;

  @override
  State<AboutSaydianPage> createState() => _AboutSaydianPageState();
}

class _AboutSaydianPageState extends State<AboutSaydianPage> {
  String _version = '--';
  String _build = '--';
  String? _introduction;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final package =
          await (widget.packageInfoLoader ?? PackageInfo.fromPlatform)();
      if (mounted) {
        setState(() {
          _version = package.version;
          _build = package.buildNumber;
        });
      }
    } catch (_) {
      // Version remains explicitly unavailable instead of being hard-coded.
    }
    if (widget.controller.isGlobalEdition) return;
    final article = await widget.controller.loadSingleArticle(14);
    final raw = '${article['content'] ?? article['description'] ?? ''}';
    final plain = _aboutPlainText(raw);
    if (mounted && _isUsefulAboutIntroduction(plain)) {
      setState(() => _introduction = plain);
    }
  }

  void _openLegal(GlobalLegalDocumentType document, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.controller.isGlobalEdition
            ? GlobalLegalPage(controller: widget.controller, document: document)
            : _SingleArticlePage(
                controller: widget.controller,
                articleId: document == GlobalLegalDocumentType.privacyPolicy
                    ? 3
                    : 2,
                fallbackTitle: title,
              ),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final gate =
          widget.updateGateController ?? AppUpdateGateScope.maybeOf(context);
      if (gate == null) {
        throw StateError('missing root update gate');
      }
      await gate.checkNow();
    } catch (_) {
      if (mounted) {
        _message(
          _usText(
            context,
            'Could not check for updates. Try again later.',
            '暂时无法检查更新，请稍后再试',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final introduction =
        _introduction ??
        _usText(
          context,
          'Everyday wellness insights from your watch.',
          '记录日常健康趋势，连接家人与设备，让健康管理更简单。',
        );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutApp)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 38, 24, 24),
        children: [
          const Center(child: SaydianBrandLockup(width: 176)),
          const SizedBox(height: 26),
          Text(
            introduction,
            textAlign: TextAlign.center,
            style: TextStyle(color: SaydianColors.muted, height: 1.6),
          ),
          const SizedBox(height: 12),
          Text(
            _build == '--' ? 'V$_version' : 'V$_version ($_build)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: SaydianColors.muted),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(context.l10n.privacyPolicy),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      _openLegal(GlobalLegalDocumentType.privacyPolicy, '隐私政策'),
                ),
                const Divider(indent: 56, height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(context.l10n.termsOfService),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      _openLegal(GlobalLegalDocumentType.userAgreement, '用户协议'),
                ),
                const Divider(indent: 56, height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_alt_rounded),
                  title: Text(context.l10n.checkUpdates),
                  trailing: _checking
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _checking ? null : _checkUpdate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FeatureStateCard(
            message: context.l10n.healthDataExplanation,
            detail: context.l10n.watchMeasurementSafety,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }
}

class _SingleArticlePage extends StatefulWidget {
  const _SingleArticlePage({
    required this.controller,
    required this.articleId,
    required this.fallbackTitle,
  });

  final AppController controller;
  final int articleId;
  final String fallbackTitle;

  @override
  State<_SingleArticlePage> createState() => _SingleArticlePageState();
}

class _SingleArticlePageState extends State<_SingleArticlePage> {
  Map<String, Object?>? _article;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final value = await widget.controller.loadSingleArticle(widget.articleId);
    if (mounted) setState(() => _article = value);
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;
    final title = '${article?['title'] ?? widget.fallbackTitle}';
    final content = _aboutPlainText(
      '${article?['content'] ?? article?['description'] ?? ''}',
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: article == null
          ? const Center(child: CircularProgressIndicator())
          : content.isEmpty
          ? const Center(child: Text('内容暂时无法加载'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [Text(content, style: const TextStyle(height: 1.75))],
            ),
    );
  }
}

String _aboutPlainText(String raw) => raw
    .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
    .replaceAll(
      RegExp(r'</\s*(p|li|h[1-6]|div)\s*>', caseSensitive: false),
      '\n',
    )
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
    .trim();

bool _isUsefulAboutIntroduction(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  return compact.runes.length >= 8;
}

class SecurityCenterPage extends StatelessWidget {
  const SecurityCenterPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.accountAndSecurity)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('security-reset-password'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => controller.isGlobalEdition
                          ? GlobalAuthPage(
                              controller: controller,
                              resetPassword: true,
                            )
                          : PasswordRecoveryPage(controller: controller),
                    ),
                  ),
                  leading: const Icon(Icons.password_rounded),
                  title: Text(context.l10n.resetPassword),
                  subtitle: Text(
                    controller.isGlobalEdition
                        ? context.l10n.verifyContactToReset
                        : '验证手机号后重新设置',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.phonelink_lock_outlined),
                  title: Text(context.l10n.loginProtectionTitle),
                  subtitle: Text(context.l10n.serviceUnavailable),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShoppingCartPage extends StatelessWidget {
  const ShoppingCartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.cart)),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: FeatureStateCard(
          message: '购物车暂时无法使用',
          detail: '你可以从商品详情页直接选择规格并购买。',
          icon: Icons.shopping_cart_outlined,
        ),
      ),
    );
  }
}

class AfterSalesPage extends StatelessWidget {
  const AfterSalesPage({this.orderNumber, super.key});

  final String? orderNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.applyAfterSales)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FeatureStateCard(
          message: '此功能暂时无法使用，请稍后再试',
          detail: orderNumber == null
              ? '售后服务开通后，可从订单详情提交申请。'
              : '订单 $orderNumber 的售后服务开通后，可在这里提交申请。',
          icon: Icons.support_agent_rounded,
        ),
      ),
    );
  }
}

class FeatureStateCard extends StatelessWidget {
  const FeatureStateCard({
    required this.message,
    required this.icon,
    this.detail,
    this.color = SaydianColors.blue,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? detail;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SaydianColors.muted, height: 1.5),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CityInputDialog extends StatefulWidget {
  const _CityInputDialog();

  @override
  State<_CityInputDialog> createState() => _CityInputDialogState();
}

class _CityInputDialogState extends State<_CityInputDialog> {
  final _city = TextEditingController();

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _city.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.selectCity),
    content: TextField(
      controller: _city,
      autofocus: true,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: context.l10n.cityNameLabel,
        hintText: context.l10n.cityNameExample,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(context.l10n.confirm)),
    ],
  );
}

class _ContactEditorDialog extends StatefulWidget {
  const _ContactEditorDialog();

  @override
  State<_ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<_ContactEditorDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    Navigator.pop(context, <String, Object?>{
      'operation': 'add',
      'name': name,
      'phone': phone,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.addContact),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 12,
          decoration: InputDecoration(labelText: context.l10n.contactName),
        ),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: context.l10n.contactPhone),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
    ],
  );
}

IconData _deviceFeatureIcon(DeviceFeature feature) => switch (feature) {
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

String _usText(BuildContext context, String english, String chinese) =>
    Localizations.localeOf(context).languageCode == 'zh' ? chinese : english;

String _englishRecordOrigin(MeasurementOrigin origin) => switch (origin) {
  MeasurementOrigin.watchHistory => 'Watch history',
  MeasurementOrigin.appMeasurement => 'Started in the app',
  MeasurementOrigin.remoteMember => 'Shared family reading',
  MeasurementOrigin.manualEntry => 'Manual entry',
  MeasurementOrigin.imported => 'Imported',
  MeasurementOrigin.unknown => 'Unknown',
};

String _localizedRecordUnit(BuildContext context, String unit) {
  if (Localizations.localeOf(context).languageCode == 'zh') return unit;
  return switch (unit) {
    '步' => 'steps',
    '次/分' => 'breaths/min',
    '千卡' => 'kcal',
    'kcal/日' => 'kcal/day',
    '℃' => '°C',
    _ => unit,
  };
}

String _localizedHealthValueLabel(
  BuildContext context,
  String key,
  HealthMetric metric,
) {
  if (Localizations.localeOf(context).languageCode == 'zh') {
    return healthValueLabel(key, metric);
  }
  return switch (key) {
    'value' => context.l10n.metricName(metric),
    'systolic' => 'Systolic',
    'diastolic' => 'Diastolic',
    'pulse' || 'meanHeartRate' || 'averageHeartRate' => 'Heart rate',
    'skinTemperature' => 'Skin temperature',
    'averageHRV' || 'hrv' => 'HRV',
    'averageTimeInterval' || 'qt' => 'QT interval',
    'respiratoryRate' => 'Breathing rate',
    'sampleFrequency' => 'Sample rate',
    'BMI' || 'bmi' => 'BMI',
    'durationMinutes' => 'Duration',
    _ => _readableHealthKey(key),
  };
}

String _readableHealthKey(String key) {
  final words = key
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll('_', ' ')
      .trim();
  if (words.isEmpty) return 'Reading';
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

String _watchHour(BuildContext context, Object? value) {
  final hour = int.tryParse('$value');
  if (hour == null || hour < 0 || hour > 23) return '—';
  return TimeOfDay(hour: hour, minute: 0).format(context);
}

String _deviceFeatureDescription(BuildContext context, DeviceFeature feature) =>
    switch (feature) {
      DeviceFeature.watchFaces => _usText(
        context,
        'Choose a watch face',
        '选择并管理手表表盘',
      ),
      DeviceFeature.photoWatchFace => _usText(
        context,
        'Use a photo as your watch face',
        '用自己的照片制作表盘',
      ),
      DeviceFeature.findWatch => _usText(
        context,
        'Make your nearby watch vibrate',
        '让附近的手表响铃或振动',
      ),
      DeviceFeature.camera => _usText(
        context,
        'Take photos with your watch',
        '使用手表控制手机拍照',
      ),
      DeviceFeature.phoneCalls => _usText(
        context,
        'Manage calls on your watch',
        '管理手表通话相关设置',
      ),
      DeviceFeature.contacts => _usText(
        context,
        'Manage watch contacts',
        '管理手表中的常用联系人',
      ),
      DeviceFeature.notifications => _usText(
        context,
        'Choose notifications for your watch',
        '选择需要在手表上提醒的消息',
      ),
      DeviceFeature.alarms => _usText(
        context,
        'Set alarms on your watch',
        '管理手表闹钟和重复日期',
      ),
      DeviceFeature.weather => _usText(
        context,
        'Show local weather on your watch',
        '把所在城市天气同步到手表',
      ),
      DeviceFeature.worldClock => _usText(
        context,
        'See other time zones on your watch',
        '在手表上查看其他城市时间',
      ),
      DeviceFeature.healthReminders => _usText(
        context,
        'Set daily reminders',
        '设置久坐、饮水和日常提醒',
      ),
      DeviceFeature.healthMonitoring => _usText(
        context,
        'Choose automatic readings',
        '设置自动检测和健康提醒',
      ),
      DeviceFeature.healthAssessment => _usText(
        context,
        'View watch-provided insights',
        '查看手表支持的辅助评估',
      ),
      DeviceFeature.screenDisplay => _usText(
        context,
        'Set display brightness and timeout',
        '调节亮度和亮屏方式',
      ),
      DeviceFeature.basicSettings => _usText(
        context,
        'Set watch time and goals',
        '设置手表时间、目标和个人资料',
      ),
    };
