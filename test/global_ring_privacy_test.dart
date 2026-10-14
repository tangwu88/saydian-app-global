import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/data_privacy_page.dart';
import 'package:saydian_app/ui/global_legal_page.dart';
import 'package:saydian_app/ui/pages.dart';

class _Wearable extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.8)),
    child: child!,
  ),
  home: home,
);

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('storage notice is readable at narrow width in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const DataPrivacyPage(), locale: locale));
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(locale);
      for (final body in [
        l.dataResidencyBody,
        l.dataLocalBody,
        l.dataChoiceBody,
        l.dataThirdPartyBody,
      ]) {
        final text = find.text(body);
        await tester.scrollUntilVisible(
          text,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(text, findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'supplement stays available during legal outage without granting consent',
    (tester) async {
      final requests = <http.Request>[];
      final vault = MemorySessionVault();
      final controller = AppController(
        vault,
        GlobalSaydianApiClient(
          vault,
          client: MockClient((request) async {
            requests.add(request);
            return http.Response('', 503);
          }),
        ),
        MemoryHealthStore(),
        _Wearable(),
        allowAutomaticWearableRestore: false,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          GlobalLegalPage(
            controller: controller,
            document: GlobalLegalDocumentType.privacyPolicy,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final requestsBefore = requests.length;
      await tester.tap(find.byKey(const Key('data-privacy-link')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('data-privacy-page')), findsOneWidget);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.dataResidencyBody), findsOneWidget);
      expect(requests.length, requestsBefore);
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final source in ['coolwear', 'qring']) {
    testWidgets('$source hero preserves actual name and unknown battery', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vault = MemorySessionVault();
      final controller =
          AppController(
              vault,
              GlobalSaydianApiClient(
                vault,
                client: MockClient((_) async => http.Response('', 503)),
              ),
              MemoryHealthStore(),
              _Wearable(),
              allowAutomaticWearableRestore: false,
            )
            ..connectedDevice = DeviceInfo(
              id: '$source:test',
              name: source == 'coolwear' ? 'R7Pro fixture' : 'R21 fixture',
            );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(Scaffold(body: RingDeviceHero(controller: controller))),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(source == 'coolwear' ? 'LuckRing' : 'QRing'),
        findsOneWidget,
      );
      expect(find.text(controller.connectedDevice!.name), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.byIcon(Icons.battery_unknown_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
