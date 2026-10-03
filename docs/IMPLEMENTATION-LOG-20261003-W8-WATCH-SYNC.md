# W8 watch-origin measurement synchronization — 2026-10-03

- Scope: connected Android W8 watch measurements should trigger a history read, local persistence and the existing global health uploader without pressing Sync. Preserve the App-origin measurement path, session isolation, ACK deduplication and original sensor values.
- Baseline: `1a567a4`, branch `codex/global-device-admin-20261001`, fetched origin ahead/behind 2/0. Existing untracked Android QA note backed up outside Git at `../validation/android-debug-20261003/pre-w8-QA-20261003-ANDROID-DEBUG-WINDOWS.md` and preserved.
- P1 reproduction: W8-ultra firmware 1.07 connected and ready. The user completed measurements on the watch; records appeared in the App only after pressing Sync. `YuchengWearableBridge._handleMeasurementState` returns immediately when `_activeMeasurementMetric` is null, dropping the watch-origin completion notification. Expected: the completion notification triggers the existing serial, coalesced read/upload chain.
- Server baseline: authenticated current-account API readback matched all three actual W8 history IDs (one heart-rate, two blood-pressure records), with local pending count 0. The current account had four server records. Therefore those manual-sync records were already uploaded; an empty repeated upload displayed an idle status with “uploaded 0”, rather than retaining a visible synchronized state. This account snapshot is separate from the previous W9 ECG account snapshot.
- Planned related files: Yucheng bridge and regression tests for watch completion/progress/disconnect/App-origin behavior; controller and regression for confirmed records after a zero-new-row retry. No server change, model inference, SDK binary upgrade or sensor algorithm change.
- Acceptance: actual watch-origin completion without pressing Sync produces real history records in the App and matching IDs in authenticated server readback; pending queue reaches zero. Record host tests, Android Debug/QA Release builds and executable real-device checks separately. iOS builds/hardware cannot run on this Windows host.

## Implemented change

- `lib/services/yucheng_wearable_bridge.dart`: a connected watch-origin terminal measurement state (`state == 0`, no active App measurement) emits `healthDataReady` with the current device ID. The existing scoped, serial/coalesced controller path reads history, saves actual SDK records and invokes the existing uploader. Progress notifications and disconnected notifications remain ignored; App-origin completion retains its history recovery path. The notification itself does not fabricate a health record.
- `lib/services/app_controller.dart`: a successful retry with existing records, zero new uploads, zero rejections and no pending queue retains `CloudHealthSyncState.complete` and displays `数据已同步，无待上传记录`. Pending/rejected/error results retain their existing state. No ACK is synthesized and already confirmed IDs are not reuploaded.
- The two related regression files cover watch-origin completion, progress, disconnect and repeated synchronization of an ACKed row. No server configuration, SDK, measurement value, source-model inference or unrelated App change was made.

## Validation commands and results

Commands ran from the App repository after `. ..\Enter-Development.ps1`; Android builds/run used `$env:GRADLE_USER_HOME='D:\Dev\Gradle'`.

| Check | Command | Result |
| --- | --- | --- |
| Formatting | `dart format lib\services\app_controller.dart lib\services\yucheng_wearable_bridge.dart test\app_controller_stale_callback_test.dart test\yucheng_wearable_bridge_test.dart` | Completed; two test files formatted |
| Focused regression | `flutter test --no-pub test\yucheng_wearable_bridge_test.dart test\app_controller_stale_callback_test.dart test\app_controller_measurement_lifecycle_test.dart --reporter expanded` | 56 passed |
| Static analysis | `flutter analyze --no-pub` | No issues, 14.1 seconds |
| Full regression | `flutter test --no-pub --reporter expanded` | 966 passed, about 38 seconds |
| ARM64 Debug | `flutter build apk --debug --flavor sideload --target-platform android-arm64 --no-pub --dart-define-from-file=config/dev.json.example` | Passed, 28.4 seconds |
| ARM64 internal QA Release | With `$env:SAIDIAN_ALLOW_QA_RELEASE='true'`, `flutter build apk --release --flavor sideload --target-platform android-arm64 --no-pub --dart-define-from-file=config/dev.json.example` | Passed, 44.5 seconds; debug-signed internal QA only |
| Final device run | `flutter run --debug --flavor sideload -d 2KTYD21714200059 --no-pub --dart-define-from-file=config/dev.json.example` in an interactive terminal | Build, replacement install, launch, reconnect and hot reload passed |

Logs and sanitized readback summaries are outside Git under `../validation/android-debug-20261003/`: `w8-analyze-20261003.log`, `w8-full-tests-20261003.log`, `w8-debug-build-20261003.log`, `w8-qa-release-retry-20261003.log`, `w8-baseline-sync-20261003.json`, `w8-automatic-sync-acceptance-20261003.json`, `w8-installed-debug-readback-20261003.json`, `w8-final-device-readback-20261003.json` and `w8-build-debug-acceptance-20261003.json`. Readbacks compare actual local and authenticated server IDs in memory; saved summaries contain counts/types/status, without tokens or health values.

## Real-device and server acceptance

- Device: Huawei PPA-LX3, Android 10/API 29, package `cn.saydian.app.global`, version `1.0.0 (1012)`. The user's connected watch is W8-ultra 34BC, firmware 1.07. App session and stored records survived replacement installation; the watch automatically reconnected to `ready`.
- The user completed a new watch measurement and explicitly confirmed completion without pressing App Sync. The live heart-rate callback saved/uploaded one new record, rejected zero and left pending zero; all five then-local IDs matched five server IDs. This verifies automatic real-measurement persistence/upload on the live callback path. The newly added completion-to-history notification branch passed host regression; that particular branch was not independently distinguished in the user's live measurement.
- The first final Debug cold start automatically read additional history and uploaded seven new records, with local 12/server 12/matched 12 and pending zero. Later watch measurements raised the count; a subsequent read must not be used as a no-new-data deduplication test.
- Final settled readback after the interactive Debug replacement: local 14/server 14/matched 14, pending zero, cloud state `complete`. Both sides contain seven heart-rate, three blood-pressure and one each blood-oxygen, blood-glucose, temperature and HRV record. Server readback uses only `https://app.saydian.cn/global/api/saydian-app/v2/health/records` with the current phone account.
- The interactive Flutter debug session remains attached. Sending `r` succeeded: `Reloaded 0 libraries in 871ms`; no source changes were pending during this connection check. Final App process was present and W8 remained ready.
- The original current-account manual-sync records had already reached the server. The corrected confirmed-state display addresses the misleading zero-new-upload result; no server outage was reproduced for those records.

## Failures retained and recovery

- The first QA Release attempt used the misspelled `SAYDIAN_ALLOW_QA_RELEASE` environment variable and failed the signing gate in 6.5 seconds. The gate was preserved; retrying with the required `SAIDIAN_ALLOW_QA_RELEASE=true` passed. This package is not production-signed.
- A redirected `flutter run` installed/launched successfully but its stdin was closed, preventing interactive hot reload. Two later attach attempts supplied the host DDS URL where Flutter expected the device VM URL; forwarding failed before HTTP headers. No App data was cleared. The owned redirected Flutter tool process was stopped and a fresh interactive `flutter run` rebuilt/reinstalled successfully; hot reload then passed. The final replacement install took 149.3 seconds.
- VM source evaluation was unavailable (`No compilation service available; cannot evaluate from source`). Read-only object inspection/invocation and authenticated API readback provided the final metadata checks instead. No synthetic measurement was inserted into the real account.
- Existing Kotlin migration warnings were emitted; both Android builds succeeded. iOS Debug/Profile, other watch models/firmware and all watch-origin completion metric variants were not hardware-accepted on this Windows host.

## Final artifacts and delivery scope

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Final `build/app/outputs/flutter-apk/app-sideload-debug.apk` | 122953911 | `658583a82d78d5ac492b8eef9490809b0c1f790b33915e0600e4e8345c7fc688` |
| Internal `build/app/outputs/flutter-apk/app-sideload-release.apk` | 47009413 | `e6d2956134c690118e199a9119059036ca2bc3106910b34a4b0956bf682a4c64` |

The final Debug APK is installed on the connected phone and real-device debugging is running. Source and this implementation record are delivered together in a scoped local Git commit; no remote push or production release was requested. The pre-existing untracked Android QA note remains untracked and unchanged.
