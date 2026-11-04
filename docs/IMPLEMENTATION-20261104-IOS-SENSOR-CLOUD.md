# 2026-11-04 iOS sensor cloud synchronization

## Authorized scope and baseline

The user explicitly requested blood pressure, heart rate, blood oxygen and related measured data also reach the cloud. Baseline `bf0dfdea0ca2dc920c971bf2fe45bb9cd9663acc`, clean after origin fetch and fast-forward check; branch `codex/ios-sensor-cloud-20261104`. This supersedes the previous activity/sleep-only **upload** restriction. Existing acquisition/device-capability checks and separately granted family-care permissions remain enforced.

This round adds the three already implemented sensor metrics to iOS cloud transport, alongside activity and sleep. Other iOS acquisition/ECG/AI restrictions remain; Android already uses the full supported metric transport. No invented measurements, database deletion, China fallback, or consent-version fabrication. Pending owned records can be retried by the next cloud sync. A server ACK alone marks a submitted record synced.

Planned changes: distinct cloud policy in `ios_wellness_policy.dart`; queue, payload, state and own-history transport boundaries; accurate localized notice; synthetic regression cases; revised privacy draft for review. Existing Google Play 1021 submission is not replaced by these source edits. Legal publication and real-device/cloud acceptance are separate from local tests/builds.

## Checks and evidence

- Initial targeted run: 46 passed, 3 failed. New test fixtures incorrectly expected service exceptions (foreign ACK, offline HTTP, and replaced account) as SyncOutcome results. Production controller already catches these as pending. Corrected test expectations to require ApiException and preserved pending-row assertions; no weakened transport check. A replacement-script match missed the formatted account-switch fixture in the second run: 48 passed, 1 failed. Initial full UTC likewise 1150 passed/1 failed on that fixture. Explicitly corrected its asynchronous error expectation before completing the delayed response.
- Initial analyzer: one brace-style issue in the new test, corrected. Initial full runs and logs retained; final runs are recorded separately below.
- Live **server contract** probe against the real US domain used one newly created, disposable synthetic QA account and three fixed synthetic records with platform=ios. All three metrics received ACK; repeated identical idempotency key produced no duplicate; own history returned exactly the same values, instants, metric and iOS/app-measurement provenance. Anonymous reads denied. Only this owned QA account was deleted afterward and its token rejected. This is not a physical wearable test or an installed client test. No real member data changed. Sanitized evidence: `/private/tmp/saydian-sensor-cloud-20261104/us-probe-result.json`; temporary credentials/private transcript excluded from Git.
- Build identity updated to 1.0.2+1022; Play 1021 is already occupied and remains its previous submitted artifact. No store draft is automatically replaced by source edits.

## Final local regression

- `flutter --no-version-check analyze --no-pub`: No issues (3.6s).
- `TZ=UTC flutter --no-version-check test --no-pub --reporter=expanded`: 1151/1151 passed (28s).
- `TZ=Asia/Shanghai flutter --no-version-check test --no-pub --reporter=expanded`: 1151/1151 passed (32s).
- Nine added cloud regressions cover real GlobalSaydianApiClient payloads under mocked HTTP: three vendor prefixes without requiring a currently connected device, exact values/time/platform/origin, ACK-only marking, duplicate sync, partial/foreign ACK, network retry, remote-member exclusion, unchanged care/acquisition boundaries, and delayed ACK after owner replacement. Four existing policy/state fixtures were updated to the authorized new upload scope; the AUD-03 assertion still requires unacknowledged rows never become complete.
- Sync status now checks persisted records, not a UI-only list. No database schema changes or deletion. Original local records remain intact; projections are transport views.
- Release helpers: 25/25 passed. Native/privacy/auth host checks: 89 passed, 1 Windows-only skipped; remaining lifecycle group recorded below. No native protocol source changed.
- Privacy and terms r4 are concrete English drafts. Existing publication workflow requires legal review before activation; review question was sent while builds continue. No r4 document has been activated by this code change.
- iPhone15pm remains unavailable. The connected XR is running another SayRing task and was left untouched. No new installation, physical measurement, or actual iPhone-to-cloud ACK is asserted.

Platform builds and Git delivery are recorded below.

## Platform builds

All builds used remote push disabled, no dependency upgrades and the independent .com configuration. Android Play Debug (34.0s) and internal QA Release (49.2s) passed for arm/arm64. Actual release manifest: cn.saydian.app.global / 1.0.2 (1022), min26/target36. SHA256 Debug `65ec9d7bd7a1639cfb9a662ec156311494c0a41549158678838ed92be69c94e6`; QA Release `d71653fe155fb1a5500e8eaa86f1c99aeb553d0528bdf290cd4cfbdffffa1111`. QA release is not a Play production upload.

Serial iOS Profile (56.0s, 64.4MB) and Debug (20.1s) no-codesign builds passed, actual Info.plist cn.saydian.app.global / 1.0.2 / 1022. Existing private Xcode27 minimum-iOS15 override used; vendor simulator/SwiftPM and Android future Kotlin warnings retained. Neither no-codesign bundle is claimed as signed/installed/App Store-ready. No same-repository parallel Xcode builds.

`dart format --output=none --set-exit-if-changed lib test` and `git diff --check` passed. Urion native lifecycle 3/3 passed; combined Node groups total 92 passed/1 Windows-only skip.

## Legal approval

The user explicitly confirmed the concrete r4 privacy and terms drafts reviewed and authorized publication during this round. American backend publication and public readback are tracked below; China backend and Say Ring documents remain outside this task.

Android native unit tests `:app:testPlayDebugUnitTest :app:testSideloadDebugUnitTest`: BUILD SUCCESSFUL /16s, XML each38 tests, 0failures.

### Actual US publication and readback

Both r4 documents were newly created under Saydian Health on the **US** admin, reviewed and activated only after the user's explicit approval. The old r3 rows are retained and inactive. The form publication confirmation was clicked for each exact type/version. Rich editor normalizes paragraph whitespace; normalized wording was verified equal to the approved source. Hidden native switch inputs did not accept click, so the observed visible Element Plus switch container was used and actual checked states read back before saving.

Live auth/capabilities now returns consentVersion `global-appstore-2026-11-04-r4`. Both versioned legal API bodies match all approved words; SHA256 privacy `2e2355475dbe224c5aad8c75ef4dda67c957dea58b964d8d64404a799dae0748`, terms `8d28b319273abd7ee5e7a853c8fdbc4437763ff5dd93b308cc301c87da093d11`. Initial raw HTML version assertion failed because public pages are JavaScript shells, not stale policies; actual browser-rendered privacy shows r4 and iOS sensor cloud wording. Public terms rendering checked separately. No new server program deployment was needed for existing sensor ingestion. No China records/policies or other product legal documents were changed.

Local evidence (ignored): `build/sensor-cloud-20261104/privacy-r4-published.jpg`, admin list screenshot; private probe/command logs remain outside Git. Build artifacts and credentials excluded.

## Git delivery

Local implementation commit `17e120786a49b97fbd3756e841592f65d0c25e95` is preserved on `codex/ios-sensor-cloud-local-20261104`. The authorized GitHub connection published equivalent source commit `78d32720fb238437f3d6c2a518ae971b7e06fae7` on `codex/ios-sensor-cloud-20261104`. Full tree `9b2838fe2116d8daf02a96c1d9f7759f8fd75d0b` matches exactly; fresh origin fetch and full-tree diff passed. No main merge or force push. Current working branch tracks the canonical remote.

Source CI [41766547984](https://github.com/tangwu88/saydian-app-global/actions/runs/41766547984) was observed in_progress for exactly that source SHA. Local tests/builds are passed; cloud CI is a separate pending result at this delivery snapshot. This following record-only commit skips redundant CI, without treating the source CI as already passed.

Public browser-rendered terms additionally verified r4, the saved activity/sleep/BP/heart-rate/oxygen US-sync clause, and US location. The public privacy screenshot shows the actual active r4 wording. Final unresolved acceptance: unavailable iPhone15pm/new signed installation/actual sensor-to-cloud ACK; no 1022 production store upload or submission in this task. The user's earlier physical-device deferral remains respected.
