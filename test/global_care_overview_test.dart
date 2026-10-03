import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_care.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/global_care_page.dart';

class _Api extends Fake implements SaydianApi, GlobalAccountApi {}

class _Wearable extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}

Session _session(String id) => Session(
  accessToken: 'synthetic',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  displayName: 'QA',
  accountKey: 'global:member:$id',
);

class _Controller extends AppController {
  _Controller()
    : super(MemorySessionVault(), _Api(), MemoryHealthStore(), _Wearable()) {
    session = _session('a');
  }
  final calls = <String>[];
  Completer<Map<String, Object?>>? pending;
  bool denied = false;
  @override
  Future<List<GlobalCareRelationship>> globalCareRelationships() async => [
    for (final id in ['one', 'two'])
      GlobalCareRelationship(
        id: id,
        status: 'active',
        received: false,
        name: 'QA $id',
        metrics: const {'heart_rate'},
      ),
  ];
  @override
  Future<Map<String, Object?>> globalCareSummary(String id) async {
    calls.add(id);
    if (denied) throw const ApiException('synthetic denied', statusCode: 403);
    return pending?.future ??
        {
          'metrics': ['heart_rate'],
          'records': [
            {
              'id': 'synthetic-$id',
              'metric': 'heart_rate',
              'values': {'heartRate': id == 'one' ? 73 : 81},
              'unit': 'bpm',
              'observedAt': '2026-10-03T12:00:00Z',
            },
            {
              'id': 'not-authorized',
              'metric': 'blood_glucose',
              'values': {'bloodGlucose': 7},
              'unit': 'mmol/L',
              'observedAt': '2026-10-03T12:00:00Z',
            },
          ],
        };
  }

  void switchAccount() {
    session = _session('b');
    notifyListeners();
  }
}

Future<void> _pump(WidgetTester tester, _Controller controller) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GlobalCarePage(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'overview filters unshared metrics and clears old member before replacement arrives',
    (tester) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      await _pump(tester, controller);
      expect(find.textContaining('73'), findsOneWidget);
      expect(find.text('Blood glucose'), findsNothing);
      controller.pending = Completer<Map<String, Object?>>();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QA two').last);
      await tester.pump();
      expect(find.textContaining('73'), findsNothing);
      controller.pending!.complete({
        'metrics': ['heart_rate'],
        'records': [
          {
            'id': 'synthetic-two',
            'metric': 'heart_rate',
            'values': {'heartRate': 81},
            'unit': 'bpm',
            'observedAt': '2026-10-03T12:00:00Z',
          },
        ],
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('81'), findsOneWidget);
      expect(controller.calls, ['one', 'two']);
      expect(controller.healthRecords, isEmpty);
      controller.switchAccount();
      await tester.pump();
      expect(find.textContaining('81'), findsNothing);
    },
  );
  testWidgets(
    'permission denial on refresh removes previously displayed measurements',
    (tester) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      await _pump(tester, controller);
      expect(find.textContaining('73'), findsOneWidget);
      controller.denied = true;
      final indicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await indicator.onRefresh();
      await tester.pumpAndSettle();
      expect(find.textContaining('73'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      expect(controller.healthRecords, isEmpty);
    },
  );
}
