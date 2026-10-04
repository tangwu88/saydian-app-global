# 2026-10-04 SAYDIAN Health 1.0.1 TestFlight

## Scope and baseline

- User approved creating a new Apple build and distributing through the existing public TestFlight group. Preserve the old 1.0.0 Beta Review and the App Store version; no Harmony builds or server changes.
- Before editing: clean codex/global-device-admin-20261001, origin tangwu88/saydian-app-global, HEAD 8e053000aa0c238f0d05714d587cc1603f0eed02. git fetch --prune origin and git pull --ff-only succeeded, Already up to date.
- Read AGENTS.md, international handoff, change/test index, latest usability record, bug retrospective and regression checklist. The latest Windows watch evidence is not new iOS acceptance.
- App Store Connect currently shows 1.0.0 (1012) upload COMPLETE, Beta Review Waiting for Review. External group say public has zero testers and an existing public link, currently unavailable until an approved build exists. User selected reuse of the public link; no unrequested email invitations.
- Version changed to 1.0.1+1013 to avoid the existing same-version review slot. Bundle ID cn.saydian.app.global, team W7SXQ4A226, iPhone-only Release and isolated /global API remain unchanged. No runtime/API/algorithm changes.

## Environment and acceptance gates

- Xcode 26.6 (17F113), valid Apple Distribution identity for W7SXQ4A226, explicit App Store export options and local signing configuration present.
- Available disk initially about 2.9 GiB. Build/cache cleanup must exclude signed archives, package outputs, credentials, original materials and device data. iOS builds run serially.
- devicectl currently reports iPhone15pm unavailable; only an iPhone XR available. Do not substitute another phone without authorization. Final-build iPhone 15 Pro Max UI/watch/server acceptance remains pending connection.
- Required checks: analyzer; UTC and Asia/Shanghai full Flutter tests; release gates; Android regression; iOS Debug/Profile and signed Release; package identity/signature/hash; upload and Apple processing; Beta Review and public link availability. Build/upload/review/installation are separate states.

## Commands and results

- Implementation in progress. Failed attempts, corrections, skipped checks, exact artifact evidence and TestFlight state will be appended below. No new build or invitation availability is claimed yet.

### Host checks and dependency recovery

- First flutter analyze --no-pub failed with 410 issues because multiple locked pub-cache packages were absent, including flutter_lints and permission_handler. Initial UTC test compilation showed the same dependency failure and was stopped; no passing result is claimed for that attempt. flutter pub get recovered the locked dependencies successfully, without pubspec.lock changes or dependency upgrades.
- Repeated flutter analyze --no-pub: no issues. TZ=UTC flutter test --no-pub --reporter compact: 1011 passed. TZ=Asia/Shanghai same command: 1011 passed. python3 scripts/release/test_release_gate.py: 23 passed. git diff --check passed.
- No active Flutter/Xcode build was present before cleanup. git check-ignore confirmed Android intermediates are ignored; lsof +D showed no open handles. An rm-style command was rejected before execution; targeted find -depth -delete removed only build/app/intermediates (about 2.2 GiB). Stopped one idle Gradle daemon; lsof found no handles in caches/9.1.0/transforms, then deleted only those regenerable transforms (about 4.3 GiB). Originals, APK/AAB outputs, dependencies/modules-2, archives, signing files and device data retained. Disk recovered to about 6.9 GiB available after Debug compilation.
- Moved historical build/ios to ignored build/ios-preserved-1012-20261004 before generating new artifacts, preserving all historical IPA/archive files.
- flutter build ios --debug --no-codesign --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn succeeded; Xcode compile 76.1 seconds. No-code-sign build is not device installation. Profile and signed Release pending.

### TestFlight metadata correction

- Existing Beta information had Chinese text under en-US, missing privacy/marketing URLs, empty review notes and an obsolete demo username. Verified the user-authorized replacement credentials once against the exact international password login endpoint; HTTP 201/business code 200. No session/token/body persisted or printed.
- Published /global/privacy-policy and /global/support each returned HTTP 200 text/html. Updated Beta English description, these public URLs, actual review-account fields and hardware/wellness review notes; review contact and feedback email retained. Credentials never enter Git. UI reread confirmed the disabled Saved control.

### New signed artifact and upload blocker

- flutter build ios --profile --no-codesign --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn succeeded, Xcode compile 55.7 seconds, app approximately 62 MB. Profile compilation is not installed-device acceptance.
- Full Python release discovery: 24/24 passed. Canonical format check across lib/test/integration_test reported one existing integration-test indentation mismatch; formatted only integration_test/w8_physical_device_test.dart, without semantic change. The test requires actual W8 hardware and was not executed on an unavailable iPhone.
- Command: SAIDIAN_PRODUCTION_RELEASE=true SAIDIAN_ALLOW_QA_RELEASE=false SAYDIAN_API_BASE_URL=https://app.saydian.cn flutter build ipa --release --no-pub --export-options-plist=ios/ExportOptions-AppStore.plist --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn. Signed archive and App Store IPA export succeeded (7.6-second export). SDK SPM migration and simulator arm64 warnings remain; not a zero-warning build.
- Artifact: build/ios/ipa/SAYDIAN Health.ipa, 37,092,454 bytes, SHA-256 14363daa2d17155ba08ba4437b6f624dfa482d4b8aba0575d3243a3c0b094d45. Unpacked IPA verified with codesign --verify --deep --strict; Info reads cn.saydian.app.global, 1.0.1, 1013, UIDeviceFamily=[1]. Embedded profile is SAYDIAN Health Global App Store Distribution. Archive signature also passed; team W7SXQ4A226, arm64, get-task-allow=false, beta-reports-active=true.
- Preserved new archive in Xcode Archives/2026-10-04/SAYDIAN-Health-1.0.1-1013.xcarchive and opened it with Xcode. Organizer visibly confirms correct international identifier and 1.0.1 (1013), distinct from SayRing.
- Selected App Store Connect distribution (not Internal Only). Upload preparation stopped: App Store Connect access for Xuewu Tang is required; Apple Account authentication must be configured. Manage Accounts opened Apple Accounts with no signed-in accounts and Add Apple Account available. Browser login does not provide Xcode upload authentication. Requested user-owned sign-in/2FA; no credentials guessed, extracted or logged. New build not uploaded, processed, submitted to Beta Review or publicly available at this checkpoint. Old 1012 review retained.
- iPhone 15 Pro Max still unavailable in repeated devicectl checks; an unrelated iPhone XR is connected. No substitution, installation or health upload attempted. Final new iOS device/watch/server acceptance remains pending.

### Cross-platform regression and preserved delivery

- Android regression: flutter build apk --debug --flavor sideload --target-platform=android-arm,android-arm64 --no-pub succeeded (122.4 seconds). Explicit SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --flavor sideload --target-platform=android-arm,android-arm64 --no-pub succeeded (110.9 seconds, approximately 68.3 MB). Internal QA only; no Play upload, Android installation or Harmony command.
- Final format verification across lib, test and integration_test: 186 files, zero changes. node tool/qa_ios_frameworks.mjs confirms all seven inspected vendor frameworks contain arm64.
- Preserved immutable candidate at build/ios-testflight-1013/SAYDIAN-Health-1.0.1-1013.ipa with SHA256SUMS.txt. shasum -a 256 -c SHA256SUMS.txt passed. Standard App Store IPA must be installed through TestFlight/App Store, not directly sideloaded as if it were Ad Hoc.
- Android native tests and generic-device RunnerTests compilation started after the corresponding platform builds; results pending below. Generic compilation is not execution on hardware.

- ./gradlew :app:testSideloadDebugUnitTest --console=plain: BUILD SUCCESSFUL in 31 seconds. JUnit reports 22 tests, zero failures/errors/skips (7 battery, 6 GATT drain, 3 timezone, 1 private-log, 5 watch-face profile).
- xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination generic/platform=iOS -derivedDataPath build/ios-ci-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build-for-testing: TEST BUILD SUCCEEDED. Native RunnerTests compiled, not executed; unavailable target iPhone remains the hardware boundary.
- User completed Xcode account sign-in. Apple Accounts now shows a signed-in account; closing settings resumed Organizer at Locating signing assets. Prior authentication failure preserved above; upload final result pending.
- Prepared a separate target-phone Ad Hoc export from the same signed archive using ios/ExportOptions-AdHoc-iPhone15pm.plist. EXPORT SUCCEEDED. File build/ios-testflight-1013/adhoc-iPhone15pm/SAYDIAN Health.ipa, SHA-256 1c1d82ead1a6de84e95d36b34e00bf3520599e5e0457fd09abef9ff8ddb0b592. Not an installed-device claim; no unavailable phone was overwritten.
- At approximately 15:49 Asia/Shanghai, Organizer returned Upload completed with warnings. All 14 visible issues were missing third-party framework dSYM files. Closing the receipt shows Uploaded to Apple, submission Uploaded, build 1013. This confirms transmission only; Apple processing/Beta Review/public availability remain separate.
- Before delivery commit: fetched origin, tracked branch 0/0 and no foreign edits. gh repo view reports the existing international origin is currently public (contrary to older Private documentation); repository visibility is not changed. User previously authorized normal pushes regardless of repository state. Only version metadata, one whitespace-only test correction and sanitized release records are committed; no artifacts, credentials, health records or signing material. Local platform gates were executed; use skip-ci for this metadata-only delivery to avoid redundant other-platform/Harmony jobs, without claiming remote CI success.

## English beta testing instructions

Please test sign-in, profile changes, avatar and nickname consistency, English navigation, and startup branding. With a compatible SAYDIAN wearable, test device discovery, connection, reconnecting after moving out of range, and health-history synchronization. Check that confirmed records remain uploaded and repeated synchronization does not create duplicate records. ECG availability depends on the connected device and firmware; missing or low-quality data must not be interpreted as a normal result. Please report the phone model, iOS version, wearable model, and steps to reproduce an issue. This app supports personal wellness tracking only and is not intended for diagnosis, treatment, emergency monitoring, or medical decisions.

Review credentials remain only in Apple's protected review fields; no credentials or real health records are included in this document.

## Apple processing and Beta submission result

- Apple accepted build 1.0.1 (1013), build ID 351d6853-3e7b-4d1d-a547-5cd960df4f94. At approximately 15:53 Asia/Shanghai it appeared as selectable; after export compliance the build status was Ready to Submit. The upper upload-progress widget briefly still read Processing, so availability is evidenced by the actual selectable build and subsequent successful Beta submission, not that stale progress widget.
- Apple processing details included warning 90683 concerning NSLocationAlwaysAndWhenInUseUsageDescription. No new background-location behavior or unused permission was added merely to suppress a vendor-SDK warning. Organizer also reported 14 missing vendor dSYM warnings, as recorded above. These are warnings, not a zero-warning delivery or evidence of a rejected build.
- Export compliance selected standard encryption in addition to Apple's operating-system encryption (consistent with the bundled SQLCipher/AES use), not no encryption or proprietary encryption. Selected No for App Store distribution in France, preserving the user's existing excluded-France scope. Apple's export-compliance reference states that the relevant French declaration is required only for App Store distribution in France: https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption . The console saved compliance and made the build ready to submit; this does not claim a geographical restriction on the public TestFlight link.
- Added 1013 to existing external group say public (40682783-7ba0-49a3-8fc2-1460d564823d), with the English test instructions above and Automatically Notify Testers checked. Clicked Submit for Review. At approximately 16:02 Asia/Shanghai the group visibly contained two builds: new 1.0.1 (1013) Waiting for Review and retained 1.0.0 (1012) Waiting for Review. No old review was withdrawn, no formal App Store version changed and no Harmony build performed.
- Reuse invitation URL: https://testflight.apple.com/join/Tp2ThpNm . A direct browser check returned Apple's generic TestFlight instructions rather than an app-specific install/join invitation. External approval, invitation acceptance and actual download are NOT verified yet. Public trial is not reported as ready while Beta Review is pending.
- Final artifact verification at 16:03: both entries in build/ios-testflight-1013/SHA256SUMS.txt passed. Store IPA and target-phone Ad Hoc IPA are retained. A screenshot of the group showing new build Waiting for Review is saved at /private/tmp/saydian-testflight-1013-review.jpg; no credentials or health records are visible.
- Final devicectl check still reports iPhone15pm unavailable and only iPhone XR connected. New iPhone 15 Pro Max installation, all-page UI review, genuine watch measurement/server acknowledgement, retry queue and duplicate-sync hardware acceptance remain outstanding. The successful host tests and Android regression do not substitute for them.
- Version/test record commit 96e70cb29082c95a12c432b3ce517249b88265b5 was pushed successfully to the international branch. This sanitized follow-up record is also committed/pushed; signing material, IPA files, private authentication and real health data remain outside Git.
