import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/global_environment.dart';

import '../integration_test/support/health_sync_readback.dart';

void main() {
  test('iOS sync readback uses the configured isolated US API', () {
    final uri = healthSyncReadbackUri(metric: 'steps');
    expect(uri.origin, GlobalEnvironment.configuredOrigin.origin);
    expect(uri.host, 'app.saydian.com');
    expect(uri.scheme, 'https');
    expect(uri.path, '/global/api/saydian-app/v2/health/records');
    expect(uri.queryParameters, {'metric': 'steps', 'limit': '200'});
    expect(uri.userInfo, isEmpty);
  });

  test('iOS sync readback preserves opaque pagination cursors', () {
    const cursor = 'opaque+/= cursor&before=other';
    final uri = healthSyncReadbackUri(metric: 'sleep', before: cursor);
    expect(uri.queryParameters['before'], cursor);
    expect(uri.queryParameters['metric'], 'sleep');
    expect(uri.queryParameters.length, 3);
    expect(uri.host, 'app.saydian.com');
    expect(uri.fragment, isEmpty);
  });

  test('real iOS sync QA cannot regress to the old hard-coded China host', () {
    final source = File(
      'integration_test/ios_wellness_sync_qa_test.dart',
    ).readAsStringSync();
    expect(source, contains('healthSyncReadbackUri('));
    expect(source, isNot(contains('https://app.saydian.cn/')));
  });
}
