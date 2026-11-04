# 2026-11-04 Apple 1.0.2 (1023) build and upload

## Authorization and accepted source

The user requested the CI results be checked and, only after all passed, a new Apple build be created and uploaded to App Store Connect. Starting branch `codex/us-storage-notices-20261104`, clean HEAD `3050bfb386c11cc43e7ba6393adf755f03164c38`; origin fetch and fast-forward check succeeded. Runtime and workflow files are identical to source `0002cd743001a63235eac1fc2b27e039b56ac8bd` (full diff excluding docs is empty).

GitHub run [41776718607](https://github.com/tangwu88/saydian-app-global/actions/runs/41776718607) completed **success**. All five jobs were individually checked: quality, Android, iOS, Harmony contracts UTC and Asia/Shanghai. Previous run 41774487076 also completed success, but the new build uses the newer accepted source. Documentation-only follow-ups do not replace the runtime CI evidence.

This release includes iOS saved blood-pressure/heart-rate/oxygen cloud synchronization, the reviewed/published r4 policy scope, and the unified connection-help / inline US-server status changes. Device acquisition capabilities, separate care permissions, original records and ACK-only completion remain unchanged. There is no new physical sensor/cloud acceptance in this build task. Recent 1151 tests in each timezone and the full platform build matrix are recorded in the US storage notice implementation record and independently covered by CI.

## Preparation

Live App Store Connect TestFlight lists 1.0.1 (1020) as the latest uploaded build, completed but missing export-compliance information. The distribution draft remains rejected 1.0.1 / build 1018 with old activity/sleep-only description and r3 review notes. Those fields will need accurate updates before a later submission; this upload task does not resubmit that old draft. A visible Paid Applications Schedule warning requires attention by the Account Holder; no agreement was accepted automatically.

Build identity selected: **1.0.2 (1023)**, `cn.saydian.app.global`, SayDian, standard `lib/main.dart`. CLI build overrides preserve pubspec's development identifier 1.0.2+1022 and keep the accepted runtime source unchanged. An Apple build-number collision would require a fresh increment/rebuild, not editing a signed package.

Disk preflight initially showed about 3.7 GiB available. After confirming ignored/untracked generated directories, no active Gradle task and no files held there by the idle daemon, removed only this repository's `build/app/intermediates` and `build/test_cache/build`. Free space increased to 7.14 GiB (7.02 GiB after preparation). Preserved code, final APK/AAB/IPA files, all old release archives, phone backups and other projects. No system/global cache purge or phone-data action.

Release helper tests, actual archive/signature verification and upload results are appended below as completed. Credentials and raw Xcode logs stay in a restricted temporary directory. Build artifacts remain in ignored `build/store-upload-20261104-1023/`.

## Build command

No other same-repository Xcode build was running. Existing default archive/IPA outputs were moved into the new release directory before building to prevent stale 1018/1020 files from being mistaken for 1023. The exact production gate and automatic export configuration from the previously validated release flow are used; Xcode 27 / iOS 15 minimum override is release-local, not a source or dependency change.

```sh
export SAIDIAN_PRODUCTION_RELEASE=true SAIDIAN_ALLOW_QA_RELEASE=false SAIDIAN_DISABLE_REMOTE_PUSH=true
export JPUSH_APP_KEY= SAYDIAN_API_BASE_URL=https://app.saydian.com
export SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update
export XCODE_XCCONFIG_FILE="$PWD/build/store-upload-20261104-1023/archive-1023.xcconfig"
flutter --no-version-check build ipa --release --no-pub --target=lib/main.dart --build-name=1.0.2 --build-number=1023 --export-options-plist=build/store-upload-20261104-1023/ExportOptions-Local.plist --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update --dart-define=JPUSH_APP_KEY=
```

`ExportOptions-Local.plist`: method app-store-connect, automatic signing, team W7SXQ4A226, destination export, manageAppVersionAndBuildNumber=false. The separate upload options use destination upload with the same values. Local identity metadata currently lists one valid Apple Development identity; automatic distribution export must be judged from actual Xcode results, not inferred from that list alone.

## Completed checks

`python3 -m unittest discover -s scripts/release -p 'test_*.py'`: **25 passed**, 6.853 seconds. Example domestic-looking URLs printed by this suite are synthetic test fixtures, not release configuration; actual command and AOT use the approved .com origin.

Xcode Release archive completed in **53.5 seconds**, 257.0 MB. Actual archived Info.plist verified 1.0.2/1023, cn.saydian.app.global, SayDian, iPhone-only, minimum iOS15.0. `codesign --verify --deep --strict` passed; team/application identifier correct, no push/HealthKit entitlement or Bonjour debug declaration. Approved .com origin is in AOT; iOS QA-entry marker and requestAlwaysAuthorization are absent from packaged framework executables. Archive is development-signed (get-task-allow=true), which is explicitly not yet an App Store distribution IPA. Actual distribution export remains a separate required result.

The private verification helper was syntax-checked, then entitlement parsing simplified before execution; no failed package validation was ignored. Existing closed-vendor SwiftPM/simulator architecture notices remain warnings, with no product/dependency changes. No phone install, health-record modification or App Store review submission occurred during archive creation.

## Distribution IPA verified

Automatic App Store export succeeded in **148.5 seconds** with the existing Xcode account; no new login, certificate revocation or account-setting change was required. The archive and export were moved into the dedicated 1023 directory only after export completed, retaining previous outputs separately.

Actual IPA: `build/store-upload-20261104-1023/export/SayDian.ipa`, **37,949,005 bytes**, SHA-256 **af8177bdc9e573c185cff3b0fc36b5c29ad7ed0f00c3a6a539dbe877d6400577**. Bundle/version/build/name/iPhone/minimumOS match the archive. Deep strict signature verification, Apple Distribution authority, expected team/application identifier, App Store provisioning profile without device list and get-task-allow=false passed; no APNs/HealthKit entitlement. US origin/QA/Always-location checks passed on actual exported executables as well.

Parsed thin/fat arm64 Mach-O UUIDs and all file-backed sections of both Runner and App.framework/App: archive and distribution export match exactly for program content. This comparison excludes signature metadata, which changes under legitimate distribution signing. `ipa-verification.json` records the package results; its uploaded=false intentionally distinguishes verification from subsequent upload.

Only after those checks, started the upload-mode export of this same unchanged archive:

```sh
xcodebuild -exportArchive -archivePath build/store-upload-20261104-1023/Runner.xcarchive -exportPath build/store-upload-20261104-1023/upload-1023 -exportOptionsPlist build/store-upload-20261104-1023/ExportOptions-Upload.plist -allowProvisioningUpdates
```

Xcode will re-export and upload the archive; the local exported IPA hash is not asserted to be the hash of Xcode's re-compressed transport file. Upload completion, Apple processing and store review remain separate results.

## Upload accepted

Upload-mode Xcode export exited **0**, with explicit **Upload succeeded** and **EXPORT SUCCEEDED**. `upload-receipt.json` records uploaded=true, exact archive/bundle/1.0.2(1023), accepted source/CI, and the independently verified local IPA hash. The visible Paid Applications Schedule banner did not block this actual export/upload; no agreement or account setting was changed.

Fifteen existing vendor dSYM warnings were non-blocking: ABParTool, BluetoothLibrary, GRDFUSDK, JLAV2Lib, JLAudioUnitKit, JLBmpConvertKit, JLDialUnit, JLLogHelper, JLPackageResKit, JL_AdvParse, JL_BLEKit, JL_HashPair, JL_OTALib, RTKLEFoundation, RTKOTASDK. They limit symbolication of vendor stacks; symbols were not fabricated or mismatched. No new SDK was introduced. Raw logs remain private and the sanitized receipt is in the ignored release directory.

The exported Info.plist does not declare ITSAppUsesNonExemptEncryption. Any Apple processing/export-compliance status is checked separately below; upload success alone does not mean testing, store review or public release. No old build was deleted or resubmitted.

## Live Apple readback

After upload, the international app's TestFlight page explicitly lists **version 1.0.2, build (1023), Processing**, created November 4, 2026 at 2:01 PM (Asia/Shanghai). This independently confirms receipt in the correct app 6817980969. Processing is not yet complete at this checkpoint. Old 1020/1018 rows remain intact; no duplicate upload, review update, tester invitation or public release was performed.
