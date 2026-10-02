import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(
    'build/ios/real-device-qa-20261002/screenshots/final-expanded',
  );
  await output.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      await File('${output.path}/$safeName.png').writeAsBytes(bytes);
      return true;
    },
  );
}
