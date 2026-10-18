// Real XR/U19S handshake, activity/sleep ACK/readback and fresh activity gate.
// Uses the signed-in phone account. Never copies credentials between devices.
import 'ios_wellness_sync_qa_test.dart' as sync;

void main() => sync.runIosWellnessSyncQa(
  targetNamePrefix: 'U19S',
  requireUrion: true,
  includePublicUi: false,
  allowManualConnection: true,
  activityWindow: const Duration(seconds: 180),
);
