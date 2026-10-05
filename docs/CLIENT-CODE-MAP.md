# Client maintenance map

## Pages

Keep importing `lib/ui/pages.dart` and `lib/ui/prototype_pages.dart` at existing call sites. Their Dart parts share the original library and private helpers, so routes, constructors and state ownership remain compatible.

| File in lib/ui | Scope |
| --- | --- |
| pages.dart | Shared helpers, legacy login and AI entry/chat |
| dashboard_pages.dart | App shell, home cards and entries |
| health_pages.dart | Health overview, records and measurement dialog |
| sport_pages.dart | Exercise sessions, history and routes |
| article_pages.dart | Encyclopedia categories, lists, article body/images |
| device_pages.dart | Connection, scanning, battery and device information |
| notification_pages.dart | Inbox and notification detail |
| care_pages.dart | Legacy care views and shared metric presentation |
| settings_pages.dart | Profile, units, goals, permissions and account settings |
| order_pages.dart | Legacy orders and after-sales views |
| prototype_pages.dart | Legacy authentication, warnings, sharing and support helpers |
| ecg_pages.dart | ECG detail/report, objective results and waveform previews |
| device_feature_page.dart | SDK device features, watch faces and camera controls |

Global-specific authentication, care, commerce and reports retain their existing dedicated files. Keep own/shared health data and provider SDK routing separate. The source-copy regression reads both root libraries and all their parts; adding a part does not bypass it.

## Android package size

Universal release builds retain both supported ARM architectures and the existing release gate. For a smaller per-device APK, Flutter can build a pair:

```powershell
# After loading the existing Android development environment:
$env:SAIDIAN_ALLOW_QA_RELEASE = 'true'
flutter build apk --release --flavor sideload --target-platform android-arm,android-arm64 --split-per-abi --no-pub --dart-define-from-file=config/dev.json.example
```

Outputs are `app-armeabi-v7a-sideload-release.apk` and `app-arm64-v8a-sideload-release.apk` in `build/app/outputs/flutter-apk`. Select the package matching the device's `adb shell getprop ro.product.cpu.abilist`. Keep both packages to retain 32-bit support. Do not repurpose a per-ABI package as the existing universal production update artifact.

This command creates internal QA packages with the existing QA signing/configuration; it does not publish a store release or deploy the server. Production signing, private configuration and release checks remain in `scripts/release`. SDKs, SQLCipher encryption, language resources and used assets are retained.

## Portable source handoff

`tool/handoff/portable_handoff.py` provides build / verify / import commands using Python and Git only.
It uses committed App/server branches, explicit documents and the optionally verified 1013 IPA.
Working-tree caches, ignored signing files and device containers are not copied. Existing archives/checkouts are refused rather than replaced.

Run its local fixture suite with `python3 -m unittest discover -s tool/handoff -p 'test_*.py'`.
Follow [CURRENT-HANDOFF.md](CURRENT-HANDOFF.md) for the live source/release distinction and clean-machine setup.

## Checks

Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub` and the full Flutter tests. Build Debug and Release after functional changes. Preserve the implementation log and record actual installed-package checksum, UI and server byte verification separately from unit tests. Windows cannot substitute for macOS/iPhone acceptance.
