import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('physical phone UI compatibility smoke test', (tester) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    await controller.initialize();
    if (!controller.isAuthenticated) controller.enterPreview();

    await tester.pumpWidget(SaydianApp(controller: controller));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.destinations, hasLength(3));
    expect(find.byKey(const Key('dashboard-ai-assistant')), findsOneWidget);
    for (final entry in const ['远程关爱', '健康百科', '健康预警']) {
      expect(find.text(entry), findsOneWidget, reason: '$entry 首页入口缺失');
    }
    expect(find.text('赛电商城'), findsNothing, reason: '国际版不应显示国内商城入口');
    expect(find.text('健康数据'), findsOneWidget);

    for (final entry in const ['远程关爱', '健康百科', '健康预警']) {
      await tester.tap(find.text(entry));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.byType(NavigationBar),
        findsNothing,
        reason: '$entry 未打开独立页面',
      );
      await _popRoute(tester);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('dashboard-ai-ask')));
    await tester.pumpAndSettle();
    expect(find.text('AI 健康管家'), findsOneWidget);
    await _popRoute(tester);
    await tester.pumpAndSettle();

    final heartRate = find.byKey(const ValueKey('health-metric-heartRate'));
    await tester.scrollUntilVisible(
      heartRate,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(heartRate);
    await tester.pumpAndSettle();
    expect(find.text('心率分析'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    await _popRoute(tester);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('全部数据'));
    await tester.tap(find.text('全部数据'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-sport-entries')), findsNothing);
    await _popRoute(tester);
    await tester.pumpAndSettle();

    final sports = find.byKey(const Key('health-sport-entries'));
    await tester.scrollUntilVisible(
      sports,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('运动记录'), findsWidgets);

    controller.selectTab(1);
    await tester.pumpAndSettle();
    expect(find.text('设备'), findsWidgets);
    expect(
      find.text('开始查找').evaluate().isNotEmpty ||
          find.text('同步数据').evaluate().isNotEmpty,
      isTrue,
      reason: '设备页未展示查找或已连接设备操作',
    );

    controller.selectTab(2);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('my-add-device')),
      controller.connectedDevice == null ? findsOneWidget : findsNothing,
    );
    expect(find.byKey(const Key('settings-language')), findsOneWidget);
    expect(find.text('目标设置'), findsNothing);
    await tester.ensureVisible(find.text('联系客服'));
    await tester.tap(find.text('联系客服'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('global-customer-service')), findsOneWidget);
    expect(find.text('4006386738'), findsNothing);
    await _popRoute(tester);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('关于我们'));
    await tester.tap(find.text('关于我们'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
  });
}

Future<void> _popRoute(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}
