import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'global_environment.dart';

class GlobalMigrationProof {
  GlobalMigrationProof._(this.batchId, this.accountId);
  final String batchId;
  final String accountId;
  static const sourceOrigin = 'https://app.saydian.cn';
  static String get sourceNamespace => sha256
      .convert(utf8.encode('$sourceOrigin${GlobalEnvironment.apiPrefix}'))
      .toString();

  static GlobalMigrationProof? verified(
    Map<String, Object?> value,
    String accountId,
  ) {
    final uuid = RegExp(
      r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
    );
    final batch = value['batchId'];
    if (!uuid.hasMatch(accountId) ||
        value['schemaVersion'] != 1 ||
        value['completed'] != true ||
        value['sourceOrigin'] != sourceOrigin ||
        value['targetOrigin'] != GlobalEnvironment.origin ||
        value['sourceAccountId'] != accountId ||
        value['targetAccountId'] != accountId ||
        batch is! String ||
        !uuid.hasMatch(batch) ||
        DateTime.tryParse('${value['verifiedAt']}') == null) {
      return null;
    }
    return GlobalMigrationProof._(batch, accountId);
  }

  String get healthOwner => sha256
      .convert(utf8.encode('saydian-health-owner:member:$accountId'))
      .toString();
  String get notificationOwner => sha256
      .convert(utf8.encode('saydian-notification-owner:member:$accountId'))
      .toString();
}
