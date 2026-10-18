// Real-device page coverage using the existing phone session and production UI.
// Hardware ACK and fresh activity are separate gates; this entry does not run
// the legacy activity-only sensor assumptions against Urion local metrics.
import 'ios_full_page_qa_test.dart' as pages;

void main() => pages.runIosFullPageQa(
  includeWellnessSync: false,
  strictPageCoverage: true,
);
