# Health measurement source metadata — 2026-10-02

## Scope and evidence

- Joint client/server task requested health uploads to preserve `source.deviceId`, `source.model`, `source.origin`, `source.measurementSource`, and `source.platform`. This change is client-only; it does not alter server code or API routes.
- Existing Health V2 uploads already supplied device ID, platform, origin and measurement source. A record had no durable place for a verified device model, so offline retries could not preserve one.
- SDK inspection found no safe product-model value in the currently inspected adapters: Veepoo exposes its advertising/display name as `model`; Yucheng supplies the Bluetooth scan name while `basicInfo()` provides firmware and battery; Urion maps the BLE hardware-revision characteristic to `model`, which is a hardware revision rather than a product model. These values are not uploaded as `source.model`.
- Therefore model is deliberately omitted for records from those current adapters. The optional `HealthRecord.sourceModel` field preserves a model only when an upstream native/SDK payload explicitly supplies verified model metadata. Empty/unknown stays absent, not guessed.
- `origin=app_measurement` distinguishes a watch measurement started by the user in the App; `measurementSource=wearable` continues to identify that the measurement came from wearable hardware. Automatic/history samples retain `watch_history`.

## Changes

- `lib/domain/models.dart`: add optional `sourceModel` to the immutable health record's JSON/store round trip and `copyWith`, omitted when blank.
- `lib/services/global_health_api.dart`: include trimmed `source.model` only when a record carries a nonempty explicit `sourceModel`; preserve device ID, platform, origin and measurement source as before. Upstream adapters must supply that value only from an actual model field.
- SDK audit: no model inference was added; U19 metadata currently surfaced by the native adapter as `model` is the BLE hardware revision and is intentionally not copied into a health record's product-model field.
- Tests cover model persistence, automatic history and App-started wearable measurement payloads, iOS runtime platform, and omission of unknown model metadata. Bridge session tests ensure U19 records do not mislabel the fixture/native details field as a product model.

## Verification

- Red phase: `flutter test --no-pub test/global_health_api_test.dart test/models_test.dart --reporter expanded` failed to compile because the test-first `sourceModel` property did not exist yet. This was the expected pre-implementation failure.
- Initial targeted verification after implementation: `flutter test --no-pub test/global_health_api_test.dart test/models_test.dart test/urion_wearable_bridge_session_test.dart --reporter expanded` — passed, 41 tests.
- `flutter analyze --no-pub` — passed, zero issues.
- `TZ=UTC flutter test --no-pub --reporter compact` — passed, 948 tests.
- `TZ=Asia/Shanghai flutter test --no-pub --reporter compact` — passed, 948 tests.
- `flutter build ios --debug --no-codesign --no-pub` — passed.
- `flutter build ios --profile --no-codesign --no-pub` — passed. Xcode printed existing SPM migration and WeChat simulator-architecture warnings; device builds completed.
- `git diff --check` — passed.
- No real health-data upload, manual App sync, iPhone install/launch, or server API acceptance was performed. This implementation's API assertions use a mocked HTTP client; server ingestion/readback and actual SDK/device provenance remain unverified. Android builds were not run in this Apple-first task.

## Follow-up gate

- If a vendor SDK later exposes an actual product model as a distinct, documented field, map only that field into `sourceModel`, add a transport-specific source test, then repeat the upload/API contract checks. Do not promote a Bluetooth display name, hardware revision, or inferred suffix into `source.model`.
