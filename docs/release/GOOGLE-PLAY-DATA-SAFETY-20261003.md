# SAYDIAN Health — Android data disclosure evidence

Prepared 2026-10-03. Verify this against the final Play AAB and deployed
international service before submitting declarations. A source path proves an
implemented flow, not that a particular user enabled it.

| Data / access | Observed use | Declaration check |
| --- | --- | --- |
| Email or phone, account ID, credentials | International sign-in, security and account service. Passwords are submitted to the first-party login endpoint. | Declare account/contact data and security purpose; do not publish a test password. |
| Nickname, profile attributes, avatar | Profile update and optional selected-image upload. | Check personal info, photos and user-provided content against the final UI and server. |
| Activity, sleep and wearable readings | Supported records are stored in the account-scoped local database and may be sent to `/global/api/saydian-app/v2/health/records/batch`. | Declare health and fitness collection; confirm server retention and deletion behavior. |
| AI chat text and feedback | User-submitted AI messages and support reports are sent to the international API. | Check user content and provider processing; avoid claiming AI text is never retained without server evidence. |
| Device identifiers and app information | Wearable model/identifier, verified hardware address when available, installation/push ID when push is configured. | Check device ID, diagnostics and third-party SDK behavior in the final AAB. |
| Location | Optional current-location weather request to configured weather provider; Android Bluetooth permission behavior varies by OS. | Check location disclosure, permission timing and weather provider configuration. |
| Notifications from other apps | With user-enabled Notification Listener access, selected notification title/body is forwarded over Bluetooth to the wearable. | Disclose the on-device access and device transfer; verify no unrelated network upload. |
| Contacts, camera, photos | Optional contact transfer, profile or watch-face image, and camera remote features. | Declare only actual accessed and uploaded data; test permission refusal and revocation. |
| Push notifications | JPush may receive registration and device information only when the production provider is configured and the user consents. | Inspect the final SDK, provider contract and production key/channel before answering collection/sharing questions. |
| Commerce or payment | Code remains, but first-release purchase and paid-analysis entrances are hidden. | Test the shipped user journey and SDK initialization before deciding whether purchase data is collected. |

The client uses HTTPS for first-party network calls and an account/environment
scoped encrypted health store. These measures must also be checked in the final
build and service; they do not decide every Google Play data safety answer.

## Health and policy declarations

- Declare the actual wellness and fitness features in the Play Health apps form.
  The listing states the non-medical limitation. Do not claim regulated medical
  approval that has not been documented.
- The final merged Play manifest must omit `REQUEST_INSTALL_PACKAGES` and the
  update APK FileProvider. The manual update action must open the package-bound
  Google Play listing, and a persisted sideload update must not block startup.
- Confirm target API 36, both ARM ABIs, 16 KB native library alignment and the
  complete permission list from the final AAB.
- Review the live privacy notice, public account-deletion page, SDK data
  handling and support contact before submitting Data safety or age rating.
