import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Widget host(Widget page, {double scale = 1}) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildSaydianTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: page,
  );

  void noChinese(WidgetTester tester) {
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(
        text.data ?? text.textSpan?.toPlainText() ?? '',
        isNot(matches(RegExp(r'[\u4e00-\u9fff]'))),
      );
    }
  }

  setUp(() {
    messenger.setMockMethodCallHandler(permissions, (call) async {
      if (call.method == 'checkPermissionStatus') return 0;
      if (call.method == 'openAppSettings') return true;
      if (call.method == 'requestPermissions') {
        return {for (final id in call.arguments as List) id: 1};
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(permissions, null));

  testWidgets(
    'English permission page requests notifications and refreshes status',
    (tester) async {
      final controller = _UiController();
      addTearDown(controller.dispose);
      var allowed = false;
      var requests = 0;
      messenger.setMockMethodCallHandler(permissions, (call) async {
        if (call.method == 'checkPermissionStatus') {
          return call.arguments == Permission.notification.value && allowed
              ? 1
              : 0;
        }
        if (call.method == 'requestPermissions') {
          expect(call.arguments, [Permission.notification.value]);
          requests++;
          allowed = true;
          return {Permission.notification.value: 1};
        }
        return true;
      });
      await tester.binding.setSurfaceSize(const Size(347, 754));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(PermissionManagementPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      noChinese(tester);
      final row = find.ancestor(
        of: find.text('Notifications'),
        matching: find.byType(ListTile),
      );
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(
        find.descendant(of: row, matching: find.text('Allowed')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('English empty messages remain refreshable', (tester) async {
    final controller = _UiController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(NotificationsPage(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
    noChinese(tester);
    final before = controller.refreshes;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(controller.refreshes, greaterThan(before));
  });

  testWidgets('failed message loads show retry rather than empty success', (
    tester,
  ) async {
    final controller = _UiController()..nextStatus = '消息暂时无法加载';
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(NotificationsPage(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text('Could not load messages. Try again.'), findsOneWidget);
    expect(find.text('No messages yet'), findsNothing);
    noChinese(tester);
    controller.nextStatus = '暂无消息';
    await tester.tap(find.byKey(const Key('messages-retry')));
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('English permission lookup failure has a recoverable state', (
    tester,
  ) async {
    final controller = _UiController();
    addTearDown(controller.dispose);
    messenger.setMockMethodCallHandler(permissions, (_) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });
    await tester.pumpWidget(
      host(PermissionManagementPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Could not check permissions. Try again.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('permissions-retry')), findsOneWidget);
    noChinese(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'permanently denied notifications open settings without requesting again',
    (tester) async {
      final controller = _UiController();
      addTearDown(controller.dispose);
      var settingsOpened = 0;
      messenger.setMockMethodCallHandler(permissions, (call) async {
        if (call.method == 'checkPermissionStatus') return 4;
        if (call.method == 'requestPermissions') {
          fail('Must use settings after permanent denial');
        }
        if (call.method == 'openAppSettings') {
          settingsOpened++;
          return true;
        }
        return null;
      });
      await tester.pumpWidget(
        host(PermissionManagementPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.text('Notifications'),
        matching: find.byType(ListTile),
      );
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();
      expect(settingsOpened, 1);
      noChinese(tester);
    },
  );

  testWidgets('permission request failure is visible and can be retried', (
    tester,
  ) async {
    final controller = _UiController();
    addTearDown(controller.dispose);
    var requests = 0;
    messenger.setMockMethodCallHandler(permissions, (call) async {
      if (call.method == 'checkPermissionStatus') return 0;
      if (call.method == 'requestPermissions') {
        requests++;
        if (requests == 1) throw PlatformException(code: 'UNAVAILABLE');
        return {Permission.notification.value: 0};
      }
      return true;
    });
    await tester.pumpWidget(
      host(PermissionManagementPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text('Notifications'),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(row);
    final button = find.descendant(of: row, matching: find.byType(TextButton));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.text('Could not open permission settings. Try again.'),
      findsOneWidget,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('U19 controls fit a narrow phone at font scale $scale', (
      tester,
    ) async {
      final controller = _UiController()
        ..connectedDevice = const DeviceInfo(id: 'urion:qa-watch', name: 'U19')
        ..deviceCapabilityState = DeviceCapabilityState.ready
        ..capabilities = const DeviceCapabilities(
          metrics: {HealthMetric.heartRate},
          features: {
            DeviceFeature.healthMonitoring,
            DeviceFeature.basicSettings,
          },
          integratedFeatures: {
            DeviceFeature.healthMonitoring,
            DeviceFeature.basicSettings,
          },
        );
      addTearDown(controller.dispose);
      await tester.binding.setSurfaceSize(const Size(347, 754));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(
          Scaffold(body: DevicePage(controller: controller)),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      final label = find.text('Health monitoring');
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      expect(find.text('Weather'), findsNothing);
    });
  }
}

class _UiController extends AppController {
  _UiController()
    : super(MemorySessionVault(), _Api(), MemoryHealthStore(), _Wearable());
  String nextStatus = '暂无消息';
  int refreshes = 0;

  @override
  Future<void> refreshNotifications() async {
    refreshes++;
    notificationStatus = nextStatus;
    notifyListeners();
  }
}

class _Api extends Fake implements SaydianApi {}

class _Wearable extends Fake implements WearableBridge {}
