// Original AUD-01..04 safety assertions, promoted from tool/audit/.
// Synthetic data only; requests are intercepted by MockClient.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/sync_service.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/global_shop_account_pages.dart';

Session _session(String id) => Session(
  accessToken: 'synthetic-access-$id',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  displayName: 'Synthetic audit user',
  accountKey: 'global:member:$id',
);

http.Response _ok(Object data) =>
    http.Response(jsonEncode({'code': 200, 'data': data}), 200);

HealthRecord _record(
  String id, {
  String timezone = '+00:00',
  HealthMetric metric = HealthMetric.heartRate,
}) => HealthRecord(
  id: id,
  metric: metric,
  values: const {'value': 75},
  unit: 'bpm',
  measuredAt: DateTime.utc(2026, 10, 1),
  timezone: timezone,
  deviceId: 'urion:synthetic',
  firmwareVersion: 'audit',
  quality: 'unknown',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);

class _Wearable extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}

class _Api extends Fake
    implements SaydianApi, GlobalAccountApi, GlobalCommerceApi {
  @override
  Future<void> logout() async {}

  @override
  Future<List<Map<String, Object?>>> getGlobalShopOrders({
    String? status,
    String? group,
  }) async => [
    {
      'id': 'synthetic-order',
      'orderNo': 'SYNTHETIC-OWNER-A-ORDER',
      'status': 'PENDING_PAYMENT',
      'currency': 'USD',
      'currencyExponent': 2,
      'payableCents': 100,
      'items': <Object>[],
      'createdAt': '2026-10-01T00:00:00Z',
    },
  ];

  @override
  Future<Map<String, Object?>> getGlobalCommerceCapabilities() async => {};
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'AUD-01 invalid metadata at queue head must not starve a valid row',
    () async {
      final store = MemoryHealthStore();
      await store.upsert([
        for (var i = 0; i < 10; i++) _record('blocked-$i', timezone: 'invalid'),
        _record('valid-after-head'),
      ]);
      final uploaded = <String>{};
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session('a'),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/capabilities')) {
            return _ok({'dailySummaryVersions': true});
          }
          final rows = (jsonDecode(request.body) as Map)['records'] as List;
          uploaded.addAll(rows.map((r) => (r as Map)['id'] as String));
          return _ok({
            'acceptedIds': uploaded.toList(),
            'rejected': [],
            'nextCursor': null,
          });
        }),
      );
      await HealthSyncService(store, api).synchronizeNow();
      await HealthSyncService(store, api).synchronizeNow();
      expect(uploaded, contains('valid-after-head'));
    },
  );

  test('AUD-02 late logout must not clear a replacement session', () async {
    final vault = MemorySessionVault()..session = _session('a');
    final started = Completer<void>();
    final reply = Completer<http.Response>();
    final api = GlobalSaydianApiClient(
      vault,
      client: MockClient((_) {
        started.complete();
        return reply.future;
      }),
    );
    final logout = api.logout();
    await started.future;
    await vault.writeSession(_session('b'));
    reply.complete(_ok({}));
    await logout;
    expect((await vault.readSession())?.memberId, 'b');
  });

  test(
    'AUD-03 local-only iOS sensor rows must not report cloud complete',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final store = MemoryHealthStore();
      final local = _record('local-physiology');
      await store.upsert([local]);
      final controller = AppController(
        MemorySessionVault(),
        _Api(),
        store,
        _Wearable(),
      );
      addTearDown(controller.dispose);
      controller.session = _session('a');
      controller.connectedDevice = const DeviceInfo(
        id: 'urion:synthetic',
        name: 'U19S',
      );
      controller.healthRecords = [local];
      expect(controller.healthRecords, hasLength(1));
      await controller.synchronizeCloud();
      expect(controller.cloudSyncUploadedCount, 0);
      expect(controller.cloudSyncState, isNot(CloudHealthSyncState.complete));
    },
  );

  testWidgets('AUD-04 a mounted private order page must clear on logout', (
    tester,
  ) async {
    // Widget binding checks foundation globals before tearDown runs.
    debugDefaultTargetPlatformOverride = null;
    final controller = AppController(
      MemorySessionVault()..session = _session('a'),
      _Api(),
      MemoryHealthStore(),
      _Wearable(),
    );
    addTearDown(controller.dispose);
    controller.session = _session('a');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: GlobalShopOrdersPage(
          controller: controller,
          openProduct: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('SYNTHETIC-OWNER-A-ORDER'), findsOneWidget);
    await controller.logout();
    await tester.pumpAndSettle();
    expect(controller.session, isNull);
    expect(find.textContaining('SYNTHETIC-OWNER-A-ORDER'), findsNothing);
  });
  for (final operation in ['logout', 'delete']) {
    for (final replacement in ['b', 'a']) {
      test(
        'AUD-02 $operation late response preserves $replacement replacement login',
        () async {
          final vault = MemorySessionVault()..session = _session('a');
          final started = Completer<void>();
          final reply = Completer<http.Response>();
          final api = GlobalSaydianApiClient(
            vault,
            client: MockClient((_) {
              started.complete();
              return reply.future;
            }),
          );
          final call = operation == 'logout'
              ? api.logout()
              : api.deleteAccount();
          await started.future;
          final fresh = Session(
            accessToken: 'new-login-$replacement',
            refreshToken: '',
            expiresAt: DateTime.utc(2099),
            memberId: replacement,
            displayName: 'Synthetic',
            accountKey: 'global:member:$replacement',
          );
          await vault.writeSession(fresh);
          reply.complete(_ok({}));
          await call;
          expect((await vault.readSession())?.accessToken, fresh.accessToken);
        },
      );
    }
  }

  test('AUD-02 failed logout cannot clear another login', () async {
    final vault = MemorySessionVault()..session = _session('a');
    final started = Completer<void>();
    final reply = Completer<http.Response>();
    final api = GlobalSaydianApiClient(
      vault,
      client: MockClient((_) {
        started.complete();
        return reply.future;
      }),
    );
    final assertion = expectLater(api.logout(), throwsA(isA<ApiException>()));
    await started.future;
    await vault.writeSession(_session('b'));
    reply.complete(http.Response('{}', 500));
    await assertion;
    expect((await vault.readSession())?.memberId, 'b');
  });

  test(
    'AUD-02 secure vault compare-clear is serialized with session writes',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final vault = SecureSessionVault.global();
      await vault.writeSession(_session('a'));
      final write = vault.writeSession(_session('b'));
      final clear = vault.clearSessionIfUnchanged(_session('a'));
      await write;
      expect(await clear, isFalse);
      expect((await vault.readSession())?.memberId, 'b');
      expect(await vault.clearSessionIfUnchanged(_session('b')), isTrue);
      expect(await vault.readSession(), isNull);
    },
  );

  test(
    'AUD-01 SQLite cursor skips bad head, preserves payload and isolates owners after reopen',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp(
        'synthetic-audit-queue-',
      );
      addTearDown(() => dir.delete(recursive: true));
      EncryptedHealthStore open() => EncryptedHealthStore(
        MemorySessionVault(),
        databasePathProvider: () async => '${dir.path}/health.db',
        databaseOpener:
            (
              file, {
              required password,
              required version,
              onConfigure,
              onCreate,
              onUpgrade,
            }) => databaseFactoryFfi.openDatabase(
              file,
              options: OpenDatabaseOptions(
                version: version,
                onConfigure: onConfigure,
                onCreate: onCreate,
                onUpgrade: onUpgrade,
              ),
            ),
      );
      var store = open();
      await store.initialize();
      await store.switchOwner('a');
      final rows = [
        for (var i = 0; i < 10; i++) _record('blocked-$i', timezone: 'invalid'),
        _record('valid-after-head'),
      ];
      await store.upsert(rows);
      final uploaded = <String>{};
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session('a'),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/capabilities')) {
            return _ok({'dailySummaryVersions': true});
          }
          final records = (jsonDecode(request.body) as Map)['records'] as List;
          final ids = records.map((r) => (r as Map)['id'] as String).toList();
          uploaded.addAll(ids);
          return _ok({'acceptedIds': ids, 'rejected': [], 'nextCursor': null});
        }),
      );
      final result = await HealthSyncService(store, api).synchronizeNow();
      expect(result.uploaded, 1);
      expect(result.rejected, 10);
      expect(result.hasPending, isTrue);
      expect(uploaded, {'valid-after-head'});
      final bad = await store.pending();
      expect(bad, hasLength(10));
      expect(bad.first.timezone, 'invalid');
      expect(bad.first.values, rows.first.values);
      await store.close();
      store = open();
      await store.initialize();
      await store.switchOwner('a');
      expect(await store.pending(), hasLength(10));
      final retry = await HealthSyncService(store, api).synchronizeNow();
      expect(retry.uploaded, 0);
      expect(retry.rejected, 10);
      final checkpoint = HealthPendingCursor(bad.last.measuredAt, bad.last.id);
      await store.writeQueueScanCursor(checkpoint);
      await store.close();
      store = open();
      await store.initialize();
      await store.switchOwner('a');
      expect((await store.readQueueScanCursor())?.id, checkpoint.id);
      await store.switchOwner('b');
      expect(await store.pending(), isEmpty);
      expect(await store.readQueueScanCursor(), isNull);
      await store.switchOwner('a');
      expect(await store.pending(), hasLength(10));
      expect((await store.readQueueScanCursor())?.id, checkpoint.id);
      await store.writeQueueScanCursor(null);
      expect(await store.readQueueScanCursor(), isNull);
      await store.close();
    },
  );

  for (final kind in ['empty', 'local', 'cloud', 'mixed']) {
    test('AUD-03 iOS $kind cloud state uses only eligible records', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controller = AppController(
        MemorySessionVault(),
        _Api(),
        MemoryHealthStore(),
        _Wearable(),
      );
      addTearDown(controller.dispose);
      controller.session = _session('a');
      controller.connectedDevice = const DeviceInfo(
        id: 'urion:synthetic',
        name: 'U19S',
      );
      final local = _record('local');
      final cloud = _record('cloud', metric: HealthMetric.steps);
      controller.healthRecords = switch (kind) {
        'local' => [local],
        'cloud' => [cloud],
        'mixed' => [local, cloud],
        _ => [],
      };
      await controller.synchronizeCloud();
      expect(controller.cloudSyncState, switch (kind) {
        'local' => CloudHealthSyncState.localOnly,
        'empty' => CloudHealthSyncState.idle,
        _ => CloudHealthSyncState.complete,
      });
      expect(controller.cloudSyncUploadedCount, 0);
    });
  }

  testWidgets(
    'AUD-04 invalidated private route never adopts the next account',
    (tester) async {
      debugDefaultTargetPlatformOverride = null;
      final controller = AppController(
        MemorySessionVault()..session = _session('a'),
        _Api(),
        MemoryHealthStore(),
        _Wearable(),
      )..session = _session('a');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: GlobalShopOrdersPage(
            controller: controller,
            openProduct: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('SYNTHETIC-OWNER-A-ORDER'), findsOneWidget);
      await controller.logout();
      await tester.pumpAndSettle();
      controller.session = _session('b');
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.textContaining('SYNTHETIC-OWNER-A-ORDER'), findsNothing);
      expect(find.byKey(const Key('global-shop-orders-page')), findsNothing);
    },
  );
  testWidgets('AUD-04 logout closes private modal outside the page subtree', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = null;
    final controller = AppController(
      MemorySessionVault()..session = _session('a'),
      _Api(),
      MemoryHealthStore(),
      _Wearable(),
    )..session = _session('a');
    addTearDown(controller.dispose);
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            pageContext = context;
            return GlobalShopOrdersPage(
              controller: controller,
              openProduct: (_, _) {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: pageContext,
        builder: (_) =>
            const AlertDialog(content: Text('SYNTHETIC-PRIVATE-DRAFT')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SYNTHETIC-PRIVATE-DRAFT'), findsOneWidget);
    await controller.logout();
    await tester.pumpAndSettle();
    expect(find.text('SYNTHETIC-PRIVATE-DRAFT'), findsNothing);
    expect(find.textContaining('SYNTHETIC-OWNER-A-ORDER'), findsNothing);
  });
  for (final operation in ['logout', 'delete']) {
    test(
      'AUD-02 $operation bound to an old snapshot cannot send as replacement login',
      () async {
        final original = _session('a');
        final vault = MemorySessionVault()..session = _session('b');
        var requests = 0;
        final api = GlobalSaydianApiClient(
          vault,
          client: MockClient((_) async {
            requests++;
            return _ok({});
          }),
        );
        await expectLater(
          operation == 'logout'
              ? api.logout(expectedSession: original)
              : api.deleteAccount(expectedSession: original),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'SESSION_CHANGED',
            ),
          ),
        );
        expect(requests, 0);
        expect((await vault.readSession())?.memberId, 'b');
      },
    );
  }
}
