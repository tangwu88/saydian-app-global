# SAYDIAN Health — Google Play submission copy

Prepared 2026-10-03 for the independent international app `cn.saydian.app.global`.
This is review copy, not evidence of a Play Console submission.

## Store listing

**App name:** SAYDIAN Health

**Default language:** English (United States)

**Category:** Health & Fitness

**Price:** Free

**Short description** (under 80 characters):

> Explore wellness trends from a compatible SAYDIAN wearable.

**Full description:**

> SAYDIAN Health helps you connect a compatible SAYDIAN wearable and review the
> wellness information it reports. Pair a supported device over Bluetooth to
> view available activity, sleep, and health readings in one place. Available
> measurements and device settings depend on the connected model.
>
> Use your account to keep supported records in sync and manage your profile.
> Optional features include sharing selected information with a remote care
> member, asking the AI health assistant general wellness questions, and sending
> feedback to our support team. You choose whether to enable optional device
> permissions and notifications.
>
> A compatible wearable is required for device measurements. An internet
> connection is needed for account and cloud features. The app can display only
> data actually provided by a connected device or the SAYDIAN Health service.
>
> SAYDIAN Health is for personal wellness reference. It is not a medical device
> and does not diagnose, treat, cure, or prevent any medical condition. Do not
> use it for medical decisions or emergencies. Consult a qualified professional
> when you need medical advice.

**First release notes:**

> Initial release: connect a compatible wearable, review supported wellness
> readings, manage your profile, and contact support from the app.

## Reviewer instructions

- Sign in using the verified international SAYDIAN Health review account entered
  privately in Play Console. Do not put credentials in this repository or in
  a public review note.
- Account, profile, available health pages, AI and help can be inspected without
  a wearable. Device-specific measurement, Bluetooth pairing and sync require
  compatible hardware. The device connection guide is available from the Watch
  page; describe only functions actually present in the submitted build.
- Measurements are general wellness information, not medical advice. Optional
  permissions are requested when a user selects a related feature.
- Provide a separate, real Android connection recording if Play requests proof
  of hardware behavior. Existing iPhone footage is not Android evidence.

## Console fields requiring verified external facts

| Field | Source required before submission |
| --- | --- |
| Developer legal identity | The supplied Hong Kong incorporation certificate names Hong Kong Saydian Technology Limited. D&B Hong Kong accepted an application enquiry on 2026-10-03; the nine-digit D-U-N-S record and matching Google payments profile remain pending. The company registration number is not a D-U-N-S number. Do not substitute an individual's Apple identity. |
| Public developer contact | Working organization email and phone that Google verifies. |
| App support contact | Working, tested international support email or public support page. In-app feedback exists but is not a substitute for this field. |
| Privacy policy | Public, current SAYDIAN Health URL that covers Android and is consistent with the published in-app document. |
| Account deletion URL | Public SAYDIAN Health page with a discoverable deletion request path; in-app deletion already exists. |
| Login for review | Verified production international account; separate authorization is required before sharing its credentials with Google. |
| Countries | Only jurisdictions with verified service availability and required disclosures; exclude France. |
| Screenshots | Fresh Android screenshots using synthetic demo data. Do not reuse private iPhone health screenshots. |
| Feature graphic | `assets/google-play/feature-graphic-en-US.jpg` is a verified 1024 × 500 JPEG rendered from the approved SAYDIAN wordmark; review the final image before upload. |
| Play icon | `assets/google-play/app-icon-512.png` is derived from the approved 1024 px launcher source without changing that source. |

The Play Data safety and Health apps forms must be answered from the shipped
Android artifact and live provider configuration. Use
`GOOGLE-PLAY-DATA-SAFETY-20261003.md` as an evidence checklist, not a prefilled
attestation.

## Organization enrollment status

The Hong Kong incorporation certificate was supplied on 2026-10-03 as a
read-only source outside this repository. No D-U-N-S number has been issued or
supplied. The real contact and company fields were submitted to
[Dun & Bradstreet Hong Kong's official request form](https://www.dnb.com.hk/forms/get-duns-number)
with the user's specific authorization. The browser displayed
`https://www.dnb.com.hk/success?formid=10039` and stated that the message was
received and the team would follow up. This is an enquiry acknowledgement,
not a D-U-N-S issuance or a completed Google Play developer registration. The
source page says an application can take 30 working days. Google Play's
organization account cannot be created until a valid nine-digit D-U-N-S
number is available, unless Google explicitly grants another path.

The Play Console website is at its organization-signup payment-profile step.
The company/business account type and the exact English legal name as the
developer display name have been entered. The signed-in Google identity is a
personal Gmail account, and Google recommends a company-domain account to
reduce verification steps. No Google payments profile was created, no fee was
paid, no terms were accepted, and no Play app record exists yet. The browser
currently offers only “create a new payments profile”; do not confuse this
registration draft with a submitted app.

The Play upload keystore is independent of the sideload release key. It was
generated locally with `scripts/release/create_play_upload_key.sh` on
2026-10-03. Back up the ignored `android/app/saydian-global-play-upload.p12` and
`android/play-upload.properties` securely. Never commit either file. A QA
artifact signed with the Android debug key is not an uploadable production AAB.
The upload certificate's SHA-256 fingerprint is
`CE:B2:56:24:AF:84:A1:D6:A8:EF:17:4F:8F:3B:7F:60:8A:76:51:4C:C7:B8:E7:3D:89:78:10:45:FC:B6:8D:74`;
verify this fingerprint against the keystore before Google Play App Signing
registration. Do not regenerate or replace the key after registration.
