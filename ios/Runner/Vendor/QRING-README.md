# QRing iOS SDK provenance

- Read-only source: SayRing-update-20260930 at cf510fd99e1e2047fcbb775f07abde67dec9df91, QCBandSDK 1.0.0 / 260918.
- Original supplied archive: QRing_iOS_SDK_V1.0.0_20260918(1).zip; SHA-256 154eeaa37c8fc07e7d581978e9b25c5cf8d5e85f1341537189ab7770843d150f. Source archive and reference checkout remain unchanged.
- Framework binary SHA-256 dde3ce1f803f998aa4795cf3189f805fb3c819cebd408165fecd60497b847393; all 43 files compared byte-for-byte with the reference, vendor notices preserved.
- Static iPhoneOS arm64 framework, minimum iOS 12.0. Link with -ObjC; do not embed a static framework. There is no simulator slice. App integration only, no standalone SDK redistribution.
- Exact CoreBluetooth UUID selection, QCSDK registration, real feature-table handshake and cancellation barriers remain. App-managed connections do not adopt the demo's saved UUID. Native continuous recovery is not configured by the current domestic Dart contract.
- The existing iOS activity/sleep policy applies independently in native and Dart layers. SDK debug logging is disabled; measuring placeholders are explicitly disabled.
- Scan, handshake, data synchronization and long-term recovery each need physical evidence. A source/build check does not prove all QRing models work.
