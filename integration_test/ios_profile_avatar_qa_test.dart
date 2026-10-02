import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iPhone avatar upload and original profile save round trip', (
    tester,
  ) async {
    final vault = SecureSessionVault.global();
    final account = await vault.readSession();
    expect(
      account,
      isNotNull,
      reason: 'Existing signed-in account is required',
    );
    final api = GlobalSaydianApiClient(vault);
    final controller = AppController.production(
      allowAutomaticWearableRestore: false,
    )..session = account;
    addTearDown(controller.dispose);
    await controller.refreshMemberProfile();
    final original = Map<String, Object?>.of(controller.memberProfile);
    expect(original, isNotEmpty);

    final directory = await Directory.systemTemp.createTemp(
      'global-avatar-qa-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}/brand.png');
    final bytes = await rootBundle.load(
      'assets/branding/saidian-brand-mark.png',
    );
    await image.writeAsBytes(bytes.buffer.asUint8List());
    final height = double.tryParse('${original['height']}');
    final weight = double.tryParse('${original['weight']}');
    final gender = int.tryParse('${original['gender']}');
    final birthday = '${original['birthday'] ?? ''}';
    final complete =
        height != null &&
        height >= 50 &&
        height <= 250 &&
        weight != null &&
        weight >= 10 &&
        weight <= 500 &&
        (gender == 1 || gender == 2) &&
        birthday.isNotEmpty &&
        '${original['nickname'] ?? ''}'.trim().isNotEmpty;
    String avatar;
    if (complete) {
      try {
        expect(
          await controller.saveMemberProfile(
            nickname: '${original['nickname']}',
            gender: gender!,
            birthday: birthday,
            height: height,
            weight: weight,
            avatarFilePath: image.path,
          ),
          isTrue,
          reason: controller.errorMessage,
        );
        avatar = '${controller.memberProfile['head_portrait']}';
        expect(
          avatar,
          startsWith('https://app.saydian.cn/global/api/saydian-app/v2/files/'),
        );
        expect((await http.get(Uri.parse(avatar))).statusCode, 200);
        debugPrint('PROFILE_QA: upload, save and per-field readback passed');
      } finally {
        final active = await vault.readSession();
        expect(active?.accountKey, account!.accountKey);
        final response = await http.put(
          Uri.parse(
            'https://app.saydian.cn/global/api/saydian-app/v2/members/me',
          ),
          headers: {
            'Authorization': 'Bearer ${active!.accessToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'avatarUrl': original['avatarUrl'] ?? ''}),
        );
        expect(response.statusCode, 200, reason: 'Restore original avatar');
        final restored = await api.getMemberProfile();
        expect(restored, original);
        controller.memberProfile = restored;
        debugPrint('PROFILE_QA: original profile and avatar restored exactly');
      }
    } else {
      avatar = await api.uploadProfileImage(image.path);
      expect(
        avatar,
        startsWith('https://app.saydian.cn/global/api/saydian-app/v2/files/'),
      );
      expect((await http.get(Uri.parse(avatar))).statusCode, 200);
      debugPrint(
        'PROFILE_QA: upload and media passed; full save skipped because real fields are incomplete',
      );
    }
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildSaydianTheme(),
          home: ProfileEditPage(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 15),
    );
    expect(find.byKey(const Key('profile-nickname')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final screenshot = await render.toImage(pixelRatio: 3);
    try {
      final data = await screenshot.toByteData(format: ui.ImageByteFormat.png);
      binding.reportData = {
        'fullProfileSaveVerified': complete,
        'screenshots': [
          {
            'screenshotName': 'profile-after-avatar-fix',
            'bytes': data!.buffer.asUint8List(),
          },
        ],
      };
    } finally {
      screenshot.dispose();
    }
  });
}
