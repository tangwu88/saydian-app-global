# CoolWear iOS SDK provenance

- Source: the owner's existing SayRing-update-20260930 checkout at cf510fd99e1e2047fcbb775f07abde67dec9df91, copied read-only for the domestic App's LUCKRING integration.
- Original supplied archive: Android&iOS_SDK20260910.zip; SHA-256 e3a7b8ade9383fdd7a1cfb3981bfb4815fa6ccf33cad549b190d2cedc329a339. The original archive and source checkout remain untouched.
- BluetoothLibrary.framework binary SHA-256 f56c39605abded5f57b7ab28f245d67218b9df9e8edbb7fe037755b8cd3ca624. Every copied framework file was compared byte-for-byte with the reference. Vendor notices remain intact.
- iPhoneOS arm64 dynamic framework, minimum iOS 13.0; no simulator slice. Link, embed and sign only the build copy. This is an App dependency, not a separately distributed SDK package.
- Integration uses the existing vendor service IDs F618/F818, real SearchPeripheral objects, exact UUID selection, device-info/capability handshake and cancellation barrier. No model-name capability inference, sample demographics, installation-wide saved target or vendor automatic reconnect is adopted.
- The domestic iOS App keeps its current activity/sleep boundary. Native projection and Dart policy apply independently; adding the transport does not enable blocked health measurements.
- Physical discovery, handshake, capabilities, reconnection and data synchronization require separate device evidence; packaging this SDK does not prove all LUCKRING models work.
