import 'device_details_refresh.dart';
import 'widgets/safe_network_image.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/feature_models.dart';
import '../l10n/global_locale_controller.dart';
import '../l10n/ui_labels.dart';
import '../services/global_environment.dart';
import '../domain/ecg_waveform.dart';
import '../domain/health_interpretation.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';
import '../services/device_watch_face_market_service.dart';
import '../services/notification_models.dart';
import 'app_theme.dart';
import 'brand_assets.dart';
import 'global_auth_page.dart';
import 'global_legal_page.dart';
import 'global_care_page.dart';
import 'health_reports_page.dart';
import 'health_trend_page.dart';
import 'ios_wellness_scope.dart';
import 'prototype_pages.dart';
import 'shop_pages.dart';
import 'feature_visibility.dart';
import 'watch_face_market_page.dart';
import 'phone_weather_page.dart';

part 'dashboard_pages.dart';
part 'health_pages.dart';
part 'sport_pages.dart';
part 'article_pages.dart';
part 'device_pages.dart';
part 'notification_pages.dart';
part 'care_pages.dart';
part 'settings_pages.dart';
part 'order_pages.dart';

String _localeCopy(BuildContext context, String english, String chinese) =>
    Localizations.localeOf(context).languageCode == 'zh' ? chinese : english;

String _safeUiError(BuildContext context, String? error, String fallback) {
  final message = error?.trim() ?? '';
  final isChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(message);
  final isChineseLocale = Localizations.localeOf(context).languageCode == 'zh';
  if (message.isEmpty || (isChineseLocale != isChinese)) {
    return fallback;
  }
  return message;
}

class LoginPage extends StatefulWidget {
  const LoginPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _accepted = false;
  bool _obscure = true;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_accepted) {
      widget.controller.clearError();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先阅读并同意用户协议与隐私政策')));
      return;
    }
    await widget.controller.login(
      _account.text,
      _password.text,
      privacyConsentGranted: true,
    );
  }

  Future<void> _wechatLogin() async {
    if (widget.controller.isWechatLoginInProgress) {
      widget.controller.cancelWechatLogin();
      return;
    }
    if (!_accepted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先同意用户协议与隐私政策')));
      return;
    }
    FocusScope.of(context).unfocus();
    await widget.controller.loginWithWechat(privacyConsentGranted: true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final media = MediaQuery.of(context);
    final compactLayout =
        media.size.height < 700 || media.viewInsets.bottom > 0;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: saydianSoftGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(26, compactLayout ? 28 : 96, 26, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 375),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    SizedBox(height: compactLayout ? 32 : 64),
                    TextField(
                      controller: _account,
                      enabled: !controller.isBusy,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        hintText: '手机号 / 账号',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.phone_iphone_outlined,
                          color: SaydianColors.muted,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      enabled: !controller.isBusy,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        hintText: '密码',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: SaydianColors.muted,
                          size: 22,
                        ),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: controller.isBusy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  settings: const RouteSettings(
                                    name: 'password-recovery',
                                  ),
                                  builder: (_) => PasswordRecoveryPage(
                                    controller: controller,
                                  ),
                                ),
                              ),
                        child: Text(context.l10n.forgotPassword),
                      ),
                    ),
                    if (controller.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _InlineNotice(
                        message: controller.errorMessage!,
                        icon: Icons.error_outline,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(height: compactLayout ? 10 : 20),
                    _AgreementRow(
                      accepted: _accepted,
                      onChanged: (value) =>
                          setState(() => _accepted = value ?? false),
                      onOpenAgreement: _openAgreement,
                    ),
                    SizedBox(height: compactLayout ? 10 : 16),
                    FilledButton(
                      onPressed: controller.isBusy ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:
                          controller.isBusy &&
                              !controller.isWechatLoginInProgress
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.l10n.signIn),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: controller.isBusy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: 'registration',
                                ),
                                builder: (_) =>
                                    RegistrationPage(controller: controller),
                              ),
                            ),
                      style: TextButton.styleFrom(
                        foregroundColor: SaydianColors.ink,
                        minimumSize: const Size.fromHeight(38),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('注册账户'),
                    ),
                    if (!kIsWeb &&
                        (defaultTargetPlatform == TargetPlatform.iOS ||
                            defaultTargetPlatform ==
                                TargetPlatform.android)) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: OutlinedButton(
                            key: const Key('wechat-login'),
                            onPressed:
                                controller.isBusy &&
                                    !controller.canCancelWechatLogin
                                ? null
                                : _wechatLogin,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF07883E),
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              controller.isWechatLoginInProgress
                                  ? controller.canCancelWechatLogin
                                        ? '取消微信登录'
                                        : '正在登录'
                                  : '微信授权登录',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ] else if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: controller.enterPreview,
                        icon: const CircleAvatar(
                          radius: 14,
                          backgroundColor: SaydianColors.green,
                          child: Icon(
                            Icons.visibility_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        label: const Text('快速体验'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openAgreement({required int id, required String title}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArticleDetailPage(
          controller: widget.controller,
          article: {'id': id, 'title': title},
          singleArticle: true,
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return const Center(child: SaydianBrandLockup(width: 190));
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.accepted,
    required this.onChanged,
    required this.onOpenAgreement,
  });

  final bool accepted;
  final ValueChanged<bool?> onChanged;
  final void Function({required int id, required String title}) onOpenAgreement;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextButton.styleFrom(
      foregroundColor: SaydianColors.blue,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: const TextStyle(fontSize: 14),
    );
    return Row(
      key: const Key('login-agreement'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: accepted, onChanged: onChanged),
        const SizedBox(width: 2),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.l10n.agreeToTerms, style: TextStyle(fontSize: 14)),
              TextButton(
                onPressed: () => onOpenAgreement(id: 2, title: '用户协议'),
                style: linkStyle,
                child: Text(context.l10n.termsOfService),
              ),
              const Text('和', style: TextStyle(fontSize: 14)),
              TextButton(
                onPressed: () => onOpenAgreement(id: 3, title: '隐私政策'),
                style: linkStyle,
                child: Text(context.l10n.privacyPolicy),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AiPage extends StatelessWidget {
  const AiPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isIosWellnessEdition) {
      return const IosWellnessUnavailablePage();
    }
    return RefreshIndicator(
      onRefresh: controller.refreshAiArticles,
      child: ListView(
        key: const Key('ai-page'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE7EFFF), Color(0xFFF8FAFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFF516392),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.aiAssistant,
                            style: TextStyle(
                              color: Color(0xFF27479C),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            context.l10n.aiAssistantIntro,
                            style: TextStyle(
                              color: Color(0xFF516392),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _openChat(context, app: 1),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(context.l10n.askNow),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: InkWell(
              onTap: () => _openChat(context, app: 2),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.aiAssistant,
                            style: TextStyle(
                              color: Color(0xFF27479C),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            context.l10n.aiAssistantIntro,
                            style: TextStyle(
                              color: Color(0xFF6881C1),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFFDDE9FF),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: Color(0xFF27479C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                context.l10n.healthLibrary,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                controller.aiStatus,
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (controller.aiArticles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('暂无健康百科内容')),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < controller.aiArticles.take(5).length;
                    index++
                  ) ...[
                    _ArticleTile(
                      article: controller.aiArticles[index],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ArticleDetailPage(
                            controller: controller,
                            article: controller.aiArticles[index],
                          ),
                        ),
                      ),
                    ),
                    if (index < controller.aiArticles.take(5).length - 1)
                      const Divider(indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, {required int app}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiChatPage(controller: controller, app: app),
      ),
    );
  }
}

/// International content uses opaque string IDs and the global content service.
/// Language changes reload content instead of displaying the previous language
/// as if the server had supplied a translation.
class AiChatPage extends StatefulWidget {
  const AiChatPage({required this.controller, required this.app, super.key});

  final AppController controller;
  final int app;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _messages = ScrollController();

  @override
  void initState() {
    super.initState();
    if (!widget.controller.isIosWellnessEdition) unawaited(_loadMessages());
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _messages.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    await widget.controller.refreshAiMessages(app: widget.app);
    _scrollToLatest(jump: true);
  }

  Future<void> _send() async {
    final message = _input.text;
    if (message.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _scrollToLatest();
    final sent = await widget.controller.sendAiMessage(
      app: widget.app,
      message: message,
    );
    if (sent) {
      _input.clear();
      _scrollToLatest();
    }
  }

  void _scrollToLatest({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messages.hasClients) return;
      final target = _messages.position.maxScrollExtent;
      if (jump) {
        _messages.jumpTo(target);
      } else {
        _messages.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isIosWellnessEdition) {
      return const IosWellnessUnavailablePage();
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aiAssistant)),
      backgroundColor: const Color(0xFFF7F4F1),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: widget.controller.aiMessages.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Center(
                              child: FeatureStateCard(
                                message: context.l10n.aiAssistant,
                                detail:
                                    '${context.l10n.aiAssistantIntro}\n\n${context.l10n.healthDisclaimer}',
                                icon: Icons.health_and_safety_outlined,
                                color: SaydianColors.brandRed,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _messages,
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.controller.aiMessages.length,
                      itemBuilder: (context, index) {
                        final message = widget.controller.aiMessages[index];
                        final mine =
                            message['my'] == 1 ||
                            message['my'] == '1' ||
                            message['my'] == true ||
                            message['role'] == 'user';
                        final failed = message['send_failed'] == true;
                        final text =
                            '${message['message'] ?? message['content'] ?? ''}';
                        final bubble = Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .7,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: mine ? SaydianColors.brandRed : Colors.white,
                            border: mine
                                ? null
                                : Border.all(color: const Color(0x11000000)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(mine ? 18 : 5),
                              bottomRight: Radius.circular(mine ? 5 : 18),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text,
                                style: TextStyle(
                                  color: mine
                                      ? Colors.white
                                      : SaydianColors.ink,
                                  height: 1.5,
                                ),
                              ),
                              if (failed) ...[
                                const SizedBox(height: 5),
                                Text(
                                  context.l10n.messageSendFailed,
                                  style: TextStyle(
                                    color: Color(0xFFFFD7D7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            mainAxisAlignment: mine
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine) ...[
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: SaydianColors.brandRedSoft,
                                  foregroundColor: SaydianColors.brandRed,
                                  child: Icon(
                                    Icons.health_and_safety_outlined,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 9),
                              ],
                              Flexible(child: bubble),
                              if (mine) ...[
                                const SizedBox(width: 9),
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: SaydianColors.ink,
                                  foregroundColor: Colors.white,
                                  child: Icon(Icons.person_rounded, size: 20),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0x11000000))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('ai-message-input'),
                        controller: _input,
                        focusNode: _inputFocus,
                        minLines: 1,
                        maxLines:
                            MediaQuery.sizeOf(context).height -
                                    MediaQuery.viewInsetsOf(context).bottom <
                                430
                            ? 2
                            : 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: context.l10n.typeMessage,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    IconButton.filled(
                      onPressed: widget.controller.isBusy ? null : _send,
                      icon: const Icon(Icons.send_rounded),
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

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.7),
          ),
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

// Retained for secondary status layouts.
// ignore: unused_element
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(message),
        trailing: action,
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    super.key,
    required this.message,
    required this.icon,
    required this.color,
    this.compact = false,
    this.legal = false,
    this.centered = false,
    this.onTap,
  });

  final String message;
  final IconData icon;
  final Color color;
  final bool compact;
  final bool legal;
  final bool centered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final padding = legal || compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.all(14);
    final borderRadius = BorderRadius.circular(compact || legal ? 10 : 14);
    final decoration = BoxDecoration(
      color: color.withValues(alpha: legal ? 0.05 : 0.08),
      border: Border.all(color: color.withValues(alpha: legal ? 0.15 : 0.24)),
      borderRadius: borderRadius,
    );
    final text = Text(
      message,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: color,
        fontSize: centered
            ? 15
            : legal
            ? 12
            : compact
            ? 12.5
            : null,
        fontWeight: centered ? FontWeight.w600 : null,
        height: centered
            ? 1.35
            : legal
            ? 1.4
            : compact
            ? 1.3
            : 1.45,
      ),
    );
    final content = Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: compact || legal ? 16 : 20),
        SizedBox(width: compact || legal ? 7 : 10),
        if (centered) Flexible(child: text) else Expanded(child: text),
      ],
    );
    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: decoration,
        child: content,
      );
    }
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Padding(padding: padding, child: content),
          ),
        ),
      ),
    );
  }
}
