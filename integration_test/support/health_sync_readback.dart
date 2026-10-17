import 'package:saydian_app/services/global_environment.dart';

/// Read back from the same validated realm as the running application.
/// Never send the phone's session to a historical first-party origin.
Uri healthSyncReadbackUri({required String metric, String? before}) =>
    GlobalEnvironment.resolve(
      GlobalEnvironment.configuredOrigin,
      '${GlobalEnvironment.apiPrefix}/health/records',
      {'metric': metric, 'limit': '200', 'before': ?before},
    );
