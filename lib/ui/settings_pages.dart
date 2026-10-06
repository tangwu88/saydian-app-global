part of 'pages.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.memberProfile;
    final name =
        '${profile['nickname'] ?? controller.session?.displayName ?? (controller.isPreviewMode ? (Localizations.localeOf(context).languageCode == 'zh' ? '体验用户' : 'Guest') : context.l10n.defaultUser)}';
    final memberId =
        '${profile['promo_code'] ?? controller.session?.memberId ?? '--'}';
    final avatarUrl = '${profile['head_portrait'] ?? ''}'.trim();
    return ListView(
      key: const Key('my-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (controller.isPreviewMode) ...[
          Material(
            key: const Key('preview-login-prompt'),
            color: SaydianColors.brandRedSoft,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => unawaited(controller.logout()),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      color: SaydianColors.brandRed,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Localizations.localeOf(context).languageCode == 'zh'
                                ? '当前为体验模式'
                                : 'Guest mode',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Localizations.localeOf(context).languageCode == 'zh'
                                ? '登录后可保存健康数据、设备和订单信息'
                                : 'Sign in to save your readings and watch.',
                            style: const TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      context.l10n.signIn,
                      style: const TextStyle(
                        color: SaydianColors.brandRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: SaydianColors.brandRed,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: () =>
              _openPage(context, ProfileEditPage(controller: controller)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: SaydianColors.line),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _MemberAvatar(imageUrl: avatarUrl, showEditBadge: true),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: SaydianColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        controller.session == null
                            ? context.l10n.signInCloudHint
                            : context.l10n.memberId(memberId),
                        style: const TextStyle(
                          color: SaydianColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: SaydianColors.brandRed,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ProfileStat(
                key: const Key('profile-stat-device'),
                icon: Icons.watch_outlined,
                label: context.l10n.device,
                value: controller.connectedDevice == null
                    ? (Localizations.localeOf(context).languageCode == 'zh'
                          ? context.l10n.notConnected
                          : 'No watch')
                    : context.l10n.connected,
                color: SaydianColors.sky,
                onTap: () => controller.selectTab(1),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _ProfileStat(
                key: const Key('profile-stat-health-records'),
                icon: Icons.monitor_heart_outlined,
                label: context.l10n.healthRecords,
                value: Localizations.localeOf(context).languageCode == 'zh'
                    ? context.l10n.recordCount(controller.healthRecords.length)
                    : '${controller.healthRecords.length}',
                color: SaydianColors.sage,
                onTap: () => _openPage(
                  context,
                  AllHealthDataPage(
                    controller: controller,
                    title: context.l10n.healthRecords,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _ProfileStat(
                key: const Key('profile-stat-care-members'),
                icon: Icons.family_restroom_rounded,
                label: context.l10n.careMembers,
                value: Localizations.localeOf(context).languageCode == 'zh'
                    ? context.l10n.memberCount(controller.careMembers.length)
                    : '${controller.careMembers.length}',
                color: SaydianColors.clay,
                onTap: () => _openPage(
                  context,
                  Scaffold(
                    appBar: AppBar(title: Text(context.l10n.remoteCare)),
                    body: CarePage(
                      controller: controller,
                      showTitle: !controller.isIosWellnessEdition,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (showSaydianMall)
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0x17344B7D)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        context.l10n.myOrders,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _openOrders(context, null),
                        child: Text(context.l10n.all),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _OrderEntry(
                          label: context.l10n.awaitingPayment,
                          icon: Icons.account_balance_wallet_outlined,
                          onTap: () => _openOrders(context, 0),
                        ),
                      ),
                      Expanded(
                        child: _OrderEntry(
                          label: context.l10n.awaitingShipment,
                          icon: Icons.inventory_2_outlined,
                          onTap: () => _openOrders(context, 1),
                        ),
                      ),
                      Expanded(
                        child: _OrderEntry(
                          label: context.l10n.awaitingDelivery,
                          icon: Icons.local_shipping_outlined,
                          onTap: () => _openOrders(context, 2),
                        ),
                      ),
                      Expanded(
                        child: _OrderEntry(
                          label: context.l10n.afterSales,
                          icon: Icons.support_agent_rounded,
                          onTap: () => _openPage(
                            context,
                            AfterSalesPage(controller: controller),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE8E8EC)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              if (controller.connectedDevice == null) ...[
                _MyQuickEntry(
                  key: const Key('my-add-device'),
                  title: context.l10n.addDevice,
                  subtitle: context.l10n.searchNearbyWatch,
                  icon: Icons.watch_outlined,
                  color: SaydianColors.brandRed,
                  onTap: () => _openPage(
                    context,
                    DeviceSearchPage(controller: controller),
                  ),
                ),
                const Divider(height: 1, indent: 72),
              ],
              _MyQuickEntry(
                title: context.l10n.unitSettings,
                icon: Icons.straighten_rounded,
                color: SaydianColors.sky,
                onTap: () => _openPage(
                  context,
                  UnitSettingsPage(controller: controller),
                ),
              ),
              if (controller.isGlobalEdition) ...[
                const Divider(height: 1, indent: 72),
                _MyQuickEntry(
                  key: const Key('settings-language'),
                  title: context.l10n.language,
                  subtitle: GlobalLocaleScope.of(context).languageName,
                  icon: Icons.language_rounded,
                  color: SaydianColors.sage,
                  onTap: () => showGlobalLanguagePicker(context),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0x17344B7D)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 14),
                    child: Text(
                      context.l10n.myServices,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                _MyServicesGrid(controller: controller),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openOrders(BuildContext context, int? status) {
    _openPage(
      context,
      OrdersPage(controller: controller, initialStatus: status),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.imageUrl,
    this.imageBytes,
    this.size = 66,
    this.showEditBadge = false,
    this.loading = false,
  });

  final String imageUrl;
  final Uint8List? imageBytes;
  final double size;
  final bool showEditBadge;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [SaydianColors.brandRed, Color(0xFF41464A)],
        ),
      ),
      child: Icon(Icons.person_rounded, color: Colors.white, size: size * 0.52),
    );
    final bytes = imageBytes;
    final image = bytes != null
        ? Image.memory(bytes, fit: BoxFit.cover)
        : imageUrl.isNotEmpty
        ? SafeNetworkImage(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x33A51125), blurRadius: 12),
              ],
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(child: image),
          ),
          if (showEditBadge)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x22A51125)),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: size * 0.18,
                  color: SaydianColors.brandRed,
                ),
              ),
            ),
          if (loading)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: Localizations.localeOf(context).languageCode == 'zh'
        ? '$label，$value'
        : '$label, $value',
    hint: Localizations.localeOf(context).languageCode == 'zh'
        ? '点击查看$label'
        : 'Open $label',
    child: Container(
      constraints: const BoxConstraints(minHeight: 76),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: SaydianColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 23),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: Color(0xFFB1A9A5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _MyServicesGrid extends StatelessWidget {
  const _MyServicesGrid({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, IconData icon, Color color, Widget page})>[
      if (showPaidHealthProfile)
        (
          label: context.l10n.healthProfile,
          icon: Icons.assignment_ind_outlined,
          color: SaydianColors.sky,
          page: HealthProfilePage(controller: controller),
        ),
      (
        label: context.l10n.accountSettings,
        icon: Icons.manage_accounts_outlined,
        color: SaydianColors.sage,
        page: AccountSettingsPage(controller: controller),
      ),
      (
        label: context.l10n.permissions,
        icon: Icons.admin_panel_settings_outlined,
        color: SaydianColors.clay,
        page: PermissionManagementPage(controller: controller),
      ),
      (
        label: context.l10n.helpFeedback,
        icon: Icons.help_outline_rounded,
        color: SaydianColors.sky,
        page: FeedbackPage(controller: controller),
      ),
      (
        label: context.l10n.customerService,
        icon: Icons.headset_mic_outlined,
        color: SaydianColors.sage,
        page: CustomerServicePage(
          isGlobalEdition: controller.isGlobalEdition,
          controller: controller,
        ),
      ),
      (
        label: context.l10n.aboutApp,
        icon: Icons.info_outline_rounded,
        color: SaydianColors.clay,
        page: AboutSaydianPage(controller: controller),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 270 ? 2 : 3;
        final width = constraints.maxWidth / columns;
        return Wrap(
          alignment: WrapAlignment.start,
          runSpacing: 10,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: _MyServiceEntry(
                  label: entry.label,
                  icon: entry.icon,
                  color: entry.color,
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => entry.page)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MyQuickEntry extends StatelessWidget {
  const _MyQuickEntry({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 12,
      leading: _SettingsIcon(icon: icon, color: color),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
            ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _OrderEntry extends StatelessWidget {
  const _OrderEntry({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: SaydianColors.ink, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// Retained for secondary settings layouts.
// ignore: unused_element
class _MySettingCard extends StatelessWidget {
  const _MySettingCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _SettingsIcon(icon: icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyServiceEntry extends StatelessWidget {
  const _MyServiceEntry({
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class UnitSettingsPage extends StatefulWidget {
  const UnitSettingsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<UnitSettingsPage> createState() => _UnitSettingsPageState();
}

class _UnitSettingsPageState extends State<UnitSettingsPage> {
  late String _distance = widget.controller.distanceUnit;
  late String _temperature = widget.controller.temperatureUnit;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode != 'zh';
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.unitSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: RadioGroup<String>(
              groupValue: _distance,
              onChanged: (value) {
                setState(() => _distance = value!);
                widget.controller.setUnits(distance: value);
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: '公里',
                    title: Text(english ? 'Kilometers' : '公里'),
                    subtitle: Text('km'),
                  ),
                  RadioListTile<String>(
                    value: '英里',
                    title: Text(english ? 'Miles' : '英里'),
                    subtitle: Text('mi'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: RadioGroup<String>(
              groupValue: _temperature,
              onChanged: (value) {
                setState(() => _temperature = value!);
                widget.controller.setUnits(temperature: value);
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: '摄氏度（℃）',
                    title: Text(english ? 'Celsius (°C)' : '摄氏度（℃）'),
                  ),
                  RadioListTile<String>(
                    value: '华氏度（℉）',
                    title: Text(english ? 'Fahrenheit (°F)' : '华氏度（℉）'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InlineNotice(
            message: context.l10n.unitChangesHint,
            icon: Icons.info_outline_rounded,
            color: SaydianColors.blue,
          ),
        ],
      ),
    );
  }
}

class GoalSettingsPage extends StatefulWidget {
  const GoalSettingsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<GoalSettingsPage> createState() => _GoalSettingsPageState();
}

class _GoalSettingsPageState extends State<GoalSettingsPage> {
  late final TextEditingController _steps;
  late final TextEditingController _distance;
  late final TextEditingController _calories;

  @override
  void initState() {
    super.initState();
    _steps = TextEditingController(text: '${widget.controller.stepGoal}');
    _distance = TextEditingController(
      text: widget.controller.distanceUnit == '英里'
          ? (widget.controller.distanceGoal * 0.621371).toStringAsFixed(2)
          : '${widget.controller.distanceGoal}',
    );
    _calories = TextEditingController(text: '${widget.controller.calorieGoal}');
  }

  @override
  void dispose() {
    _steps.dispose();
    _distance.dispose();
    _calories.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final steps = int.tryParse(_steps.text);
    final enteredDistance = double.tryParse(_distance.text);
    final distance = enteredDistance == null
        ? null
        : widget.controller.distanceUnit == '英里'
        ? enteredDistance / 0.621371
        : enteredDistance;
    final calories = int.tryParse(_calories.text);
    if (steps == null ||
        distance == null ||
        calories == null ||
        steps <= 0 ||
        distance <= 0 ||
        calories <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localeCopy(context, 'Enter valid goals.', '请输入有效的目标数值'),
          ),
        ),
      );
      return;
    }
    final saved = await widget.controller.saveActivityGoals(
      steps: steps,
      distance: distance,
      calories: calories,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? _localeCopy(context, 'Goals saved.', '目标已保存')
              : _safeUiError(
                  context,
                  widget.controller.errorMessage,
                  _localeCopy(context, 'Couldn’t save. Try again.', '保存失败'),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.goalSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _steps,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.dailyStepGoalField,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  '${context.l10n.dailyDistanceGoalField} (${widget.controller.distanceUnit == '英里' ? 'mi' : 'km'})',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _calories,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.dailyCalorieGoalField,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.controller.isBusy ? null : _save,
            child: Text(context.l10n.saveGoals),
          ),
        ],
      ),
    );
  }
}

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.accountSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProfileEditPage(controller: controller),
                    ),
                  ),
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(context.l10n.personalInfo),
                  subtitle: Text(
                    controller.isGlobalEdition
                        ? context.l10n.emailOrPhone
                        : '注册手机号和基础资料',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                if (showSaydianMall) ...[
                  const Divider(indent: 56),
                  ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ShopAddressBookPage(controller: controller),
                      ),
                    ),
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(context.l10n.deliveryAddresses),
                    subtitle: Text(context.l10n.viewAccountAddresses),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
                const Divider(indent: 56),
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: 'reset-password'),
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
                        ? context.l10n.emailOrPhone
                        : '验证手机号后重新设置登录密码',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(indent: 56),
                ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => controller.isGlobalEdition
                          ? GlobalLegalPage(
                              controller: controller,
                              document: GlobalLegalDocumentType.privacyPolicy,
                            )
                          : ArticleDetailPage(
                              controller: controller,
                              article: const {'id': 3, 'title': '隐私协议'},
                              singleArticle: true,
                            ),
                    ),
                  ),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(context.l10n.privacyAgreement),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('account-logout'),
            onPressed: controller.isBusy
                ? null
                : () async {
                    await controller.logout();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
            child: Text(
              controller.isPreviewMode
                  ? _localeCopy(context, 'Leave guest mode', '退出体验')
                  : context.l10n.signOut,
            ),
          ),
          TextButton(
            onPressed: controller.session == null
                ? null
                : () => _confirmDeleteAccount(context),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.deleteAccount),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.confirmDeleteAccountTitle),
        content: Text(context.l10n.deleteAccountHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.confirmDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteAccount();
  }
}

class AddressPage extends StatefulWidget {
  const AddressPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.loadAddresses());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deliveryAddresses)),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final addresses = widget.controller.addresses;
          if (addresses.isEmpty) {
            return const Center(
              child: Text(
                '暂无收货地址',
                style: TextStyle(color: SaydianColors.muted),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: widget.controller.loadAddresses,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: const CircleAvatar(
                      child: Icon(Icons.location_on_outlined),
                    ),
                    title: Text(
                      '${address['realname'] ?? ''}  ${address['mobile'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${address['address_name'] ?? address['region'] ?? ''}'
                        '${address['address_details'] ?? ''}',
                      ),
                    ),
                    trailing: '${address['is_default']}' == '1'
                        ? const Chip(label: Text('默认'))
                        : null,
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

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _nickname;
  late final TextEditingController _birthday;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late int _gender;
  late String _avatarUrl;
  late String _registeredMobile;
  Uint8List? _avatarBytes;
  String? _avatarFilePath;
  bool _isPickingAvatar = false;
  bool _isLoadingProfile = false;
  bool _profileEdited = false;
  String? _profileLoadError;

  int _profileGender(Object? rawValue) {
    final value = int.tryParse('${rawValue ?? ''}');
    return value == 1 || value == 2 ? value! : 0;
  }

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.memberProfile;
    _nickname = TextEditingController(text: '${profile['nickname'] ?? ''}');
    _birthday = TextEditingController(text: '${profile['birthday'] ?? ''}');
    _height = TextEditingController(text: '${profile['height'] ?? ''}');
    _weight = TextEditingController(text: '${profile['weight'] ?? ''}');
    _gender = _profileGender(profile['gender']);
    _avatarUrl = '${profile['head_portrait'] ?? ''}'.trim();
    _registeredMobile = _mobileFromProfile(profile);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadLatestProfile());
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _birthday.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  String _mobileFromProfile(Map<String, Object?> profile) {
    if (widget.controller.isGlobalEdition) {
      return [profile['emailMasked'], profile['phoneMasked']]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' · ');
    }
    return '${profile['mobile'] ?? ''}'.trim();
  }

  Future<void> _selectBirthday() async {
    final initial = DateTime.tryParse(_birthday.text) ?? DateTime(1990);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      _profileEdited = true;
      _birthday.text = DateFormat('yyyy-MM-dd').format(selected);
    }
  }

  Future<void> _loadLatestProfile() async {
    if (widget.controller.session == null || _isLoadingProfile) return;
    setState(() {
      _isLoadingProfile = true;
      _profileLoadError = null;
    });
    await widget.controller.refreshMemberProfile();
    if (!mounted) return;
    final profile = widget.controller.memberProfile;
    setState(() {
      _isLoadingProfile = false;
      if (profile.isEmpty) {
        _profileLoadError = _safeUiError(
          context,
          widget.controller.errorMessage,
          _localeCopy(
            context,
            'Couldn’t load your profile. Try again.',
            '个人资料读取失败，请稍后重试',
          ),
        );
        return;
      }
      _registeredMobile = _mobileFromProfile(profile);
      if (_profileEdited) return;
      _nickname.text = '${profile['nickname'] ?? ''}';
      _birthday.text = '${profile['birthday'] ?? ''}';
      _height.text = '${profile['height'] ?? ''}';
      _weight.text = '${profile['weight'] ?? ''}';
      _gender = _profileGender(profile['gender']);
      if (_avatarFilePath == null) {
        _avatarUrl = '${profile['head_portrait'] ?? ''}'.trim();
      }
    });
  }

  void _markProfileEdited(String _) {
    _profileEdited = true;
  }

  Future<void> _pickAvatar() async {
    if (widget.controller.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localeCopy(context, 'Sign in to change your photo.', '登录后可更换头像'),
          ),
        ),
      );
      return;
    }
    setState(() => _isPickingAvatar = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 6 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _localeCopy(
                context,
                'Choose a photo under 6 MB.',
                '图片过大，请选择较小的照片',
              ),
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarFilePath = image.path;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localeCopy(
              context,
              'Couldn’t open the photo. Check photo access.',
              '无法读取照片，请检查相册权限后重试',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (_isPickingAvatar) return;
    if (_gender != 1 && _gender != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localeCopy(context, 'Choose a gender.', '请选择性别')),
        ),
      );
      return;
    }
    final height = double.tryParse(_height.text);
    final weight = double.tryParse(_weight.text);
    if (_nickname.text.trim().isEmpty ||
        _birthday.text.isEmpty ||
        height == null ||
        height < 50 ||
        height > 250 ||
        weight == null ||
        weight < 10 ||
        weight > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localeCopy(
              context,
              'Complete all fields. Height: 50–250 cm; weight: 10–500 kg.',
              '请完整填写资料，身高 50~250 cm、体重 10~500 kg',
            ),
          ),
        ),
      );
      return;
    }
    final saved = await widget.controller.saveMemberProfile(
      nickname: _nickname.text.trim(),
      gender: _gender,
      birthday: _birthday.text,
      height: height,
      weight: weight,
      avatarFilePath: _avatarFilePath,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? _localeCopy(context, 'Profile saved.', '个人资料已保存')
              : _safeUiError(
                  context,
                  widget.controller.errorMessage,
                  _localeCopy(context, 'Couldn’t save. Try again.', '保存失败'),
                ),
        ),
      ),
    );
    if (saved) Navigator.of(context).pop();
  }

  Future<void> _logout() async {
    final isPreview = widget.controller.isPreviewMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isPreview
              ? _localeCopy(context, 'Leave guest mode?', '退出体验？')
              : _localeCopy(context, 'Sign out?', '退出登录？'),
        ),
        content: Text(
          isPreview
              ? _localeCopy(context, 'You’ll return to sign in.', '退出后将返回登录页面。')
              : _localeCopy(context, 'Sign out of this account?', '确认退出当前账号吗？'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.exit),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.personalInfo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: _localeCopy(context, 'Change profile photo', '更换头像'),
              child: GestureDetector(
                key: const Key('profile-avatar-picker'),
                onTap: _isPickingAvatar ? null : _pickAvatar,
                child: _MemberAvatar(
                  imageUrl: _avatarUrl,
                  imageBytes: _avatarBytes,
                  size: 94,
                  showEditBadge: true,
                  loading: _isPickingAvatar,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _avatarFilePath == null
                ? _localeCopy(context, 'Tap to change photo', '点击头像更换照片')
                : _localeCopy(context, 'New photo selected', '已选择新头像，保存后生效'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: SaydianColors.muted),
          ),
          if (_isLoadingProfile) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              context.l10n.loadingProfile,
              textAlign: TextAlign.center,
              style: TextStyle(color: SaydianColors.muted),
            ),
          ] else if (_profileLoadError case final message?) ...[
            const SizedBox(height: 14),
            _InlineNotice(
              message: message,
              icon: Icons.info_outline_rounded,
              color: SaydianColors.warning,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _loadLatestProfile,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.readAgain),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Semantics(
            label: widget.controller.isGlobalEdition
                ? '${context.l10n.emailOrPhone}, ${_registeredMobile.isEmpty ? '—' : _registeredMobile}'
                : _registeredMobile.isEmpty
                ? '注册手机号，未获取'
                : '注册手机号，$_registeredMobile',
            child: InputDecorator(
              key: const Key('profile-registered-mobile'),
              decoration: InputDecoration(
                labelText: widget.controller.isGlobalEdition
                    ? context.l10n.emailOrPhone
                    : '注册手机号',
                suffixIcon: const Icon(Icons.lock_outline_rounded),
              ),
              child: Text(
                _registeredMobile.isEmpty
                    ? (widget.controller.isGlobalEdition ? '—' : '未获取')
                    : _registeredMobile,
                style: const TextStyle(color: SaydianColors.ink, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-nickname'),
            controller: _nickname,
            enabled: !_isLoadingProfile,
            onChanged: _markProfileEdited,
            decoration: InputDecoration(labelText: context.l10n.nickname),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('profile-gender-$_gender'),
            initialValue: _gender,
            decoration: InputDecoration(labelText: context.l10n.gender),
            items: [
              DropdownMenuItem(
                value: 0,
                child: Text(_localeCopy(context, 'Not set', '未设置')),
              ),
              DropdownMenuItem(
                value: 1,
                child: Text(_localeCopy(context, 'Male', '男')),
              ),
              DropdownMenuItem(
                value: 2,
                child: Text(_localeCopy(context, 'Female', '女')),
              ),
            ],
            onChanged: _isLoadingProfile
                ? null
                : (value) => setState(() {
                    _profileEdited = true;
                    _gender = value ?? 1;
                  }),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-birthday'),
            controller: _birthday,
            readOnly: true,
            enabled: !_isLoadingProfile,
            onTap: _isLoadingProfile ? null : _selectBirthday,
            decoration: InputDecoration(
              labelText: context.l10n.birthDate,
              suffixIcon: Icon(Icons.calendar_month_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-height'),
            controller: _height,
            enabled: !_isLoadingProfile,
            onChanged: _markProfileEdited,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.l10n.heightCm),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-weight'),
            controller: _weight,
            enabled: !_isLoadingProfile,
            onChanged: _markProfileEdited,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.l10n.weightKg),
          ),
          const SizedBox(height: 18),
          _InlineNotice(
            message: context.l10n.profileSaveExplanation,
            icon: Icons.privacy_tip_outlined,
            color: SaydianColors.blue,
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('profile-save'),
            onPressed:
                widget.controller.isBusy ||
                    _isPickingAvatar ||
                    _isLoadingProfile
                ? null
                : _save,
            child: Text(
              _isPickingAvatar
                  ? _localeCopy(context, 'Opening photo…', '正在读取照片')
                  : context.l10n.saveChanges,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('profile-logout'),
            onPressed: widget.controller.isBusy ? null : _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: SaydianColors.danger,
              side: const BorderSide(color: Color(0x55C6283F)),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: Text(
              widget.controller.isPreviewMode
                  ? _localeCopy(context, 'Leave guest mode', '退出体验')
                  : context.l10n.signOut,
            ),
          ),
        ],
      ),
    );
  }
}

class PermissionManagementPage extends StatefulWidget {
  const PermissionManagementPage({
    required this.controller,
    this.healthOnly = false,
    super.key,
  });

  final AppController controller;
  final bool healthOnly;

  @override
  State<PermissionManagementPage> createState() =>
      _PermissionManagementPageState();
}

class _PermissionManagementPageState extends State<PermissionManagementPage>
    with WidgetsBindingObserver {
  Map<Permission, PermissionStatus> _statuses = const {};

  List<Permission> get _permissions =>
      defaultTargetPlatform == TargetPlatform.android
      ? [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
          Permission.notification,
          Permission.photos,
          Permission.camera,
          Permission.contacts,
        ]
      : [
          Permission.bluetooth,
          Permission.locationWhenInUse,
          Permission.notification,
          Permission.photos,
          Permission.camera,
          Permission.contacts,
        ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.healthOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(widget.controller.refreshDeviceSettings());
      });
    } else {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !widget.healthOnly) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final statuses = <Permission, PermissionStatus>{};
    for (final permission in _permissions) {
      statuses[permission] = await permission.status;
    }
    if (mounted) setState(() => _statuses = statuses);
  }

  Future<void> _request(Permission permission) async {
    final status = _statuses[permission];
    if (permission == Permission.notification ||
        status?.isGranted == true ||
        status?.isPermanentlyDenied == true ||
        status?.isRestricted == true) {
      await openAppSettings();
    } else {
      await permission.request();
    }
    await _refresh();
  }

  String _actionLabel(BuildContext context, Permission permission) {
    final status = _statuses[permission];
    if (permission == Permission.notification ||
        status?.isGranted == true ||
        status?.isPermanentlyDenied == true ||
        status?.isRestricted == true) {
      return context.l10n.settings;
    }
    return context.l10n.allow;
  }

  String _name(BuildContext context, Permission permission) {
    if (permission == Permission.bluetoothScan ||
        permission == Permission.bluetoothConnect ||
        permission == Permission.bluetooth) {
      return context.l10n.bluetooth;
    }
    if (permission == Permission.locationWhenInUse) {
      return context.l10n.location;
    }
    if (permission == Permission.photos) return context.l10n.photos;
    if (permission == Permission.camera) return context.l10n.camera;
    if (permission == Permission.contacts) return context.l10n.contacts;
    return context.l10n.notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.healthOnly
              ? context.l10n.healthMonitoring
              : context.l10n.permissions,
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.healthOnly) ..._healthMonitoringContent(),
            if (!widget.healthOnly) ...[
              const SizedBox(height: 20),
              Text(
                context.l10n.appPermissions,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final permission in _permissions) ...[
                      ListTile(
                        leading: Icon(
                          _statuses[permission]?.isGranted == true
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          color: _statuses[permission]?.isGranted == true
                              ? SaydianColors.green
                              : SaydianColors.orange,
                        ),
                        title: Text(_name(context, permission)),
                        subtitle: Text(
                          _statuses[permission]?.isGranted == true
                              ? context.l10n.permissionAllowed
                              : context.l10n.permissionNotAllowed,
                        ),
                        trailing: TextButton(
                          onPressed: () => _request(permission),
                          child: Text(_actionLabel(context, permission)),
                        ),
                      ),
                      if (permission != _permissions.last)
                        const Divider(indent: 56),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_outlined),
                label: Text(context.l10n.openSystemSettings),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _deviceAutoSwitch({
    required String type,
    required String title,
    required IconData icon,
  }) {
    final settings = widget.controller.autoMeasureSettings;
    final enabled = settings[type] ?? false;
    final interval = widget.controller.autoMeasureIntervals[type];
    return Column(
      children: [
        SwitchListTile(
          key: ValueKey('device-health-auto-$type'),
          secondary: Icon(icon, color: SaydianColors.pink),
          title: Text(title),
          subtitle: Text(enabled ? '已开启' : '已关闭'),
          value: enabled,
          onChanged:
              widget.controller.connectedDevice == null ||
                  widget.controller.isDeviceSettingsLoading
              ? null
              : (value) {
                  unawaited(
                    widget.controller.setAutoMeasureSetting(type, value),
                  );
                },
        ),
        if (interval != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 18, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '监测间隔',
                    style: TextStyle(color: SaydianColors.muted),
                  ),
                ),
                if (interval.canModify)
                  DropdownButton<int>(
                    key: ValueKey('device-health-interval-$type'),
                    value: interval.minutes > 0 ? interval.minutes : null,
                    hint: Text(context.l10n.choose),
                    items: [
                      for (final minutes in interval.choices)
                        DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes 分钟'),
                        ),
                    ],
                    onChanged:
                        !enabled || widget.controller.isDeviceSettingsLoading
                        ? null
                        : (minutes) {
                            if (minutes != null) {
                              unawaited(
                                widget.controller.setAutoMeasureInterval(
                                  type,
                                  minutes,
                                ),
                              );
                            }
                          },
                  )
                else
                  Text(
                    interval.minutes > 0
                        ? '每 ${interval.minutes} 分钟（手表固定）'
                        : '手表固定',
                    style: const TextStyle(color: SaydianColors.muted),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _healthMonitoringContent() {
    final controller = widget.controller;
    final settings = controller.autoMeasureSettings;
    const specs = <({String type, String title, IconData icon})>[
      (
        type: 'heartRate',
        title: '心率自动检测',
        icon: Icons.favorite_outline_rounded,
      ),
      (type: 'bloodOxygen', title: '血氧自动检测', icon: Icons.bloodtype_outlined),
      (type: 'bloodPressure', title: '血压自动检测', icon: Icons.speed_rounded),
      (type: 'bloodGlucose', title: '血糖自动检测', icon: Icons.water_drop_outlined),
      (
        type: 'bodyTemperature',
        title: '体温自动检测',
        icon: Icons.thermostat_rounded,
      ),
      (type: 'hrv', title: 'HRV 自动检测', icon: Icons.monitor_heart_outlined),
    ];
    final tiles = <Widget>[];

    void addTile(Widget tile) {
      if (tiles.isNotEmpty) tiles.add(const Divider(indent: 56));
      tiles.add(tile);
    }

    for (final spec in specs) {
      if (!settings.containsKey(spec.type)) continue;
      addTile(
        _deviceAutoSwitch(type: spec.type, title: spec.title, icon: spec.icon),
      );
      if (spec.type == 'heartRate' && controller.heartRateWarningSupported) {
        addTile(_heartRateWarningTile());
      }
    }
    if (controller.heartRateWarningSupported &&
        !settings.containsKey('heartRate')) {
      addTile(_heartRateWarningTile());
    }

    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              '手表健康检测',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed:
                controller.connectedDevice == null ||
                    controller.isDeviceSettingsLoading
                ? null
                : controller.refreshDeviceSettings,
            tooltip: '从手表刷新',
            icon: controller.isDeviceSettingsLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      Text(
        controller.deviceSettingsStatus,
        style: const TextStyle(color: SaydianColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 8),
      if (controller.connectedDevice == null)
        FeatureStateCard(
          message: context.l10n.connectWatchToUse,
          detail: context.l10n.monitoringHint,
          icon: Icons.watch_outlined,
        )
      else if (tiles.isEmpty)
        FeatureStateCard(
          message: controller.deviceSettingsStatus,
          detail: '没有读取到可设置项目，可重新读取手表设置。',
          icon: Icons.monitor_heart_outlined,
          actionLabel: controller.isDeviceSettingsLoading ? null : '重新读取',
          onAction: controller.isDeviceSettingsLoading
              ? null
              : controller.refreshDeviceSettings,
        )
      else
        Card(child: Column(children: tiles)),
    ];
  }

  Widget _heartRateWarningTile() => ListTile(
    key: const ValueKey('device-health-heart-warning'),
    leading: const Icon(
      Icons.warning_amber_rounded,
      color: SaydianColors.orange,
    ),
    title: Text(context.l10n.watchHighHeartRate),
    subtitle: Text(context.l10n.watchThresholdHint),
    trailing: DropdownButton<int>(
      value: widget.controller.heartRateWarning,
      items: [
        for (var value = 70; value < 190; value += 5)
          DropdownMenuItem(value: value, child: Text('$value 次/分')),
      ],
      onChanged:
          widget.controller.connectedDevice == null ||
              widget.controller.isDeviceSettingsLoading
          ? null
          : (value) {
              if (value != null) {
                unawaited(widget.controller.setHeartRateWarning(value));
              }
            },
    ),
  );
}
