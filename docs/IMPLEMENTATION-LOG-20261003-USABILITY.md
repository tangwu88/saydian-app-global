# Health App usability — 2026-10-03

- Authorized scope: capability-based ECG entry, complete W8 live ECG measurement and existing artifact synchronization, fresh charging state, Chinese encyclopedia language correction, family health overview with read-only shared trends/details, and concise localized interface copy. Weather remains deferred.
- Baseline: App 50a2ac5, origin branch fetched ahead/behind 4/0; no tracked changes. Existing untracked Android QA note preserved and copied outside Git. Server 48886e2, fetched origin/main ahead/behind 1/0. No reset, clean, implicit feature merge or credential copying.
- Expected: real SDK values and actual sample rate; missing metadata remains pending. Poll device details only while visible/foreground/idle. Family records never enter the owner's local store or upload queue. ECG downloads remain private and permission checked on every request.
- P1 findings: Yucheng ECG flags/methods/events omitted by the App adapter; charging normal fallback incorrectly includes full/unknown and five-minute cache hides changes; three Chinese articles and encyclopedia category have locale en. P2: global care is a raw list; repeated explanatory copy obscures actions. One article has a two-character body and requires content maintenance, not generated replacement text.
- Planned files: wearable adapters/models/controller and related pages; global care/API/trend/detail adapters; existing ARB resources. Server health/care/private-file and scoped admin content editor changes documented in its implementation log.

## Validation

- Implementation and checks in progress. Commands, failures, corrections, builds and real-device results will be appended; no physical ECG/charging/remote-care acceptance is claimed yet. Windows cannot run iOS Debug/Profile builds.

### Implemented and validated

- Capability-based ECG entries now include W8 when its SDK reports live/history ECG; disconnected local ECG history remains accessible. SDK start/stop, 60-second completion, complete filtered millivolt samples, actual sample-rate query and result fields are retained. Missing rate uses rawVersion 1 and remains pending through the existing upload preparation guard; no invented sampling rate or diagnosis.
- Device detail adapters support forceRefresh; W8 coalesces and bypasses cached state on forced reads. Charging distinguishes normal/charging/reliable full/unknown, with low-battery flag separate. Device screens refresh on entry, foreground, pull and every 10 seconds while visible; busy measurements/synchronization/upgrades pause device reads.
- Family overview exposes only server-authorized metrics and latest records. Its read-only day/week/month trends and details reuse owner health components, with a separate management entry. Member changes clear old cards before loading; account changes and permission-denied responses clear old display. Shared records never enter the local owner store. Authenticated private ECG reads verify gzip hash, sample count/rate and account identity.
- Added and shortened localized copy across all eight languages for care, charging, login/cloud, device permission/sync, support, articles and settings-related flows. Essential measurement/medical/authorization/delete instructions retained.
- Server main advanced independently to 53a2bde with content editor locale selection/default/preservation and transactional category consistency. This implementation reuses that merged code; no competing content editor patch is published. Live correction of the original three Chinese records and category remains pending, with unchanged IDs/body/publish times required. The two-character heart-rate article is content pending; no text invented.

### Commands and results

- flutter gen-l10n passed. Flutter analyze --no-pub: no issues. Final flutter test --no-pub --reporter expanded: 995 passed.
- Added full waveform/rate/missing-rate/cancellation/charging cache cases; private download integrity/ownership cases; exact care date-range and account-change tests; visible polling lifecycle/coalescing tests; actual care page member-switch/permission-revocation tests.
- Initial test fake missed required modelName; fixed. One test import was unused; removed. Existing support/battery expectations updated to intended shorter localized labels. Existing in-flight null device-read regression now begins refresh before measurement; separate test ensures reads requested during measurement pause. An initially misplaced scoped care helper was corrected and all tests rerun.
- Android Debug and internal QA Release sideload arm64 builds passed using Flutter 3.44.9, JDK 17 and the existing SDK. QA release is debug-signed, not store publication. Original plugin Kotlin/SDK XML warnings retained; no unrelated dependency upgrades.
- Debug SHA256: 4d97f3b28676bca3052e8bd4f803c434bbbe470c41c8f050fb67d0a57f8062bc. QA Release SHA256: b0019302cc383b02586ca8fcec3823f740625686e282d27f7f17330ddceed63f. Packages and full checks remain outside Git in validation/usability-20261003.
- Huawei PPA-LX3 remains connected; current old Debug VM reports logged-in W8-ultra 34BC firmware 1.07, ready, 36 records read and no pending cloud records. This is a fresh old-package metadata check, not new ECG or charging physical acceptance.
- Server compatibility deployment must precede new phone coverage installation. Deployment/public source publication is pending the user's answer to the repository-visibility question. Physical ECG contacts/charger transitions, actual private server byte/hash comparison, online Chinese article display, real care account acceptance and iOS remain unverified. Windows cannot build or debug iOS.
