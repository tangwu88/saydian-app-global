import 'dart:io';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/global_migration_proof.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/global_saved_device_migration.dart';
import 'package:saydian_app/services/wearable_routing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const account = '00000000-0000-4000-8000-000000000001';
const batch = '00000000-0000-4000-8000-000000000002';
Map<String, Object?> evidence() => {
  'schemaVersion': 1,
  'completed': true,
  'batchId': batch,
  'sourceOrigin': 'https://app.saydian.cn',
  'targetOrigin': 'https://app.saydian.com',
  'sourceAccountId': account,
  'targetAccountId': account,
  'verifiedAt': '2026-10-14T00:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'saved devices require the matched signed-in owner and do not return after clearing',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final old = SecureSessionVault.global(
        storageNamespace: GlobalMigrationProof.sourceNamespace,
      );
      final current = SecureSessionVault.global();
      Session session(String id) => Session(
        accessToken: 'synthetic-$id',
        refreshToken: 'synthetic-refresh-$id',
        expiresAt: DateTime.utc(2030),
        memberId: id,
        displayName: 'Test',
        accountKey: 'global:member:$id',
      );
      await old.writeSession(session(account));
      await current.writeSession(session(account));
      const storage = FlutterSecureStorage();
      final sourceKey =
          'saydian.global.env.${GlobalMigrationProof.sourceNamespace}.wearable.binding.v1';
      final raw = jsonEncode({
        'transport': 'qring',
        'nativeIdentifier': 'synthetic-device',
      });
      await storage.write(key: sourceKey, value: raw);
      final proof = GlobalMigrationProof.verified(evidence(), account)!;
      await stageMigratedDevicePreferences(proof, () => false);
      expect(await readMigratedDevicePreferences(null), isNull);
      await stageMigratedDevicePreferences(proof, () => true);
      expect((await readMigratedDevicePreferences(null))?['binding'], raw);
      await current.writeSession(session(batch));
      expect(await readMigratedDevicePreferences(null), isNull);
      await current.writeSession(session(account));
      await const SecureWearableTransportPreferenceStore().clear();
      await stageMigratedDevicePreferences(proof, () => true);
      expect(await readMigratedDevicePreferences(null), isNull);
      expect(await storage.read(key: sourceKey), raw);
      expect((await old.readSession())?.accessToken, 'synthetic-$account');
    },
  );
  test('missing or mismatched mapping never authorizes cross-origin cache', () {
    expect(GlobalMigrationProof.verified(evidence(), account), isNotNull);
    for (final changed in [
      {...evidence(), 'completed': false},
      {...evidence(), 'sourceAccountId': batch},
      {...evidence(), 'targetOrigin': 'https://other.example'},
      {...evidence(), 'verifiedAt': 'bad'},
      <String, Object?>{},
    ]) {
      expect(GlobalMigrationProof.verified(changed, account), isNull);
    }
  });
  test(
    'imports only owned rows, preserves US rows and source file, and makes old acknowledgements pending',
    () async {
      final dir = await Directory.systemTemp.createTemp('saydian-us-cache-');
      addTearDown(() => dir.delete(recursive: true));
      final proof = GlobalMigrationProof.verified(evidence(), account)!;
      final sourceFile = '${dir.path}/source.db';
      final source = await databaseFactoryFfi.openDatabase(sourceFile);
      await source.execute(
        'CREATE TABLE health_records(owner_id TEXT,id TEXT,metric TEXT,measured_at TEXT,payload TEXT,aggregation_kind TEXT,aggregation_local_date TEXT,source_device_id TEXT,synced INTEGER,PRIMARY KEY(owner_id,id))',
      );
      await source.execute(
        'CREATE TABLE sport_records(owner_id TEXT,id TEXT,started_at TEXT,payload TEXT)',
      );
      await source.execute(
        'CREATE TABLE health_warning_alerts(owner_id TEXT,id TEXT,triggered_at TEXT,payload TEXT)',
      );
      await source.execute(
        'CREATE TABLE notification_inbox(account_id TEXT,event_id TEXT,created_at INTEGER,payload TEXT)',
      );
      for (final owner in [proof.healthOwner, 'another-owner']) {
        await source.insert('health_records', {
          'owner_id': owner,
          'id': owner,
          'metric': 'activity',
          'measured_at': '2026-10-14T00:00:00Z',
          'payload': '{}',
          'synced': 1,
        });
      }
      await source.close();
      final before = await File(sourceFile).readAsBytes();
      final destFile = '${dir.path}/destination.db';
      final store = EncryptedHealthStore(
        MemorySessionVault(),
        globalEdition: true,
        databasePathProvider: () async => destFile,
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
      await store.initialize();
      await store.switchOwner(proof.healthOwner);
      Future<Database?> openSource() => databaseFactoryFfi.openDatabase(
        sourceFile,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      expect(
        await store.importVerifiedOriginCache(
          proof,
          canContinue: () => false,
          openSource: openSource,
        ),
        false,
      );
      expect(
        await store.importVerifiedOriginCache(
          proof,
          canContinue: () => true,
          openSource: openSource,
        ),
        true,
      );
      expect(
        await store.importVerifiedOriginCache(
          proof,
          canContinue: () => true,
          openSource: () => throw StateError('already imported'),
        ),
        true,
      );
      await store.close();
      final dest = await databaseFactoryFfi.openDatabase(destFile);
      final rows = await dest.query('health_records');
      expect(rows.length, 1);
      expect(rows.single['owner_id'], proof.healthOwner);
      expect(rows.single['synced'], 0);
      expect(
        await dest.query('metadata', where: 'key = ?', whereArgs: ['cursor']),
        isEmpty,
      );
      await dest.close();
      expect(await File(sourceFile).readAsBytes(), before);
    },
  );
}
