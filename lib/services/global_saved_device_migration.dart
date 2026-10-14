import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'global_migration_proof.dart';
import 'global_storage_scope.dart';
import 'secure_vault.dart';

String migratedDeviceKey(String? namespace) =>
    'saydian.global.env.${globalStorageNamespace(namespace)}.wearable.verified-migration.v1';

/// One atomic secure-storage value; each reader also checks the signed-in owner.
Future<Map<String, Object?>?> readMigratedDevicePreferences(
  String? namespace,
) async {
  const storage = FlutterSecureStorage();
  final raw = await storage.read(key: migratedDeviceKey(namespace));
  if (raw == null) return null;
  try {
    final value = jsonDecode(raw);
    final session = await SecureSessionVault.global(
      storageNamespace: namespace,
    ).readSession();
    if (value is! Map ||
        session == null ||
        value['accountId'] != session.memberId) {
      return null;
    }
    return value.map((key, value) => MapEntry('$key', value));
  } on FormatException {
    return null;
  }
}

Future<void> stageMigratedDevicePreferences(
  GlobalMigrationProof proof,
  bool Function() canContinue,
) async {
  const storage = FlutterSecureStorage();
  final handled =
      '${migratedDeviceKey(null)}.${proof.accountId}.${proof.batchId}.handled';
  if (await storage.read(key: handled) == 'completed') return;
  final source = SecureSessionVault.global(
    storageNamespace: GlobalMigrationProof.sourceNamespace,
  );
  if ((await source.readSession())?.memberId != proof.accountId ||
      !canContinue()) {
    return;
  }
  final prefix = 'saydian.global.env.${GlobalMigrationProof.sourceNamespace}';
  final binding = await storage.read(key: '$prefix.wearable.binding.v1');
  final identifier = await storage.read(
    key: '$prefix.wearable.yuc.last.identifier',
  );
  final name = await storage.read(key: '$prefix.wearable.yuc.last.name');
  final address = await storage.read(
    key: '$prefix.wearable.yuc.last.hardware_address',
  );
  if (!canContinue() ||
      (await SecureSessionVault.global().readSession())?.memberId !=
          proof.accountId) {
    return;
  }
  // Source sessions and keys are deliberately never copied.
  await storage.write(
    key: migratedDeviceKey(null),
    value: jsonEncode({
      'accountId': proof.accountId,
      'batchId': proof.batchId,
      'binding': binding,
      'yucIdentifier': identifier,
      'yucName': name,
      'yucHardwareAddress': address,
    }),
  );
  await storage.write(key: handled, value: 'completed');
}
