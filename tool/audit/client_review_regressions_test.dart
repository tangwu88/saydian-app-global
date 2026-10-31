// Compatibility entrypoint for the original audit command.
// The canonical tests now run in ordinary flutter test and CI.
import '../../test/client_review_regressions_test.dart' as regressions;

void main() => regressions.main();
