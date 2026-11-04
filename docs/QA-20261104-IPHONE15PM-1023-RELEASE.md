# 2026-11-04 iPhone 15 Pro Max — 1023 Release device test

The user requested installation and real-device testing on the connected iPhone 15 Pro Max. Starting clean source `c47ff0bf566af9af5b3edc50fb678f40a46724e8`, branch codex/us-storage-notices-20261104; fetch and ff-only check succeeded. This is the same accepted runtime as 0002cd7 / all-five-success CI41776718607. No product code, dependencies, store build or policies changed. The XR/Say Ring test processes remain untouched.

## Installation package and target

Exact target: iPhone15pm / iPhone15 Pro Max, UDID 00008130-001C098C2290001C, USB connected/unlocked. Existing international app was 1.0.2(1022), bundle cn.saydian.app.global. No international-app process was running before the backup.

Used the **same 1.0.2(1023) Release archive** already uploaded to Apple, whose existing Apple Development profile includes this exact phone. Deep strict signature, team/application identifier, version/name and profile expiry passed. The Release archive application was copied with ditto into ignored build/iphone15pm-1023-release-test/Runner.app; Runner and App.framework/App are byte-identical to the archived executables. The preceding upload record separately proves archive versus App Store export program sections match.

This is an AOT Release program with device-development signing (get-task-allow=true), not the App Store distribution-profile IPA and not Flutter JIT Debug. It can launch independently without Flutter/LLDB. No recompile, resign, TestFlight invitation or store re-upload was needed. Existing App Store archive/IPA/signatures remain intact.

## Backup and actual preservation

Before installation, copied Documents, Library/Application Support and Library/Preferences into a new dated private directory under the user's Library/Application Support/SayDian/DeviceBackups, with restrictive permissions. Did not export Keychain, decrypt health databases, assign another owner or import China data. Backup proof and raw device logs are private and excluded from Git.

`devicectl device install app` on the exact phone succeeded; the installed-app list now verifies cn.saydian.app.global /1.0.2/1023. **Before launch**, read back and compared all five prior Documents/Application Support files, including three health databases: **10,139,097 bytes**, each size/SHA256 identical. iOS changed the data-container path but preserved the contents. No empty-container recovery or overwrite was performed. Preferences have a separate retained backup; no byte-identity claim is made for normally mutable OS preferences or post-launch databases.

## Start and test boundaries

Normal launch with console capture started the Release process. The first screenshot showed another app the user was using, so it is not a SayDian UI result. Activating the exact international bundle reused PID2822; the next capture occurred during the iOS transition/app switcher and is likewise not a completed-page result. An initial image-view request also ran before the capture command completed and returned file-not-found; after waiting for command completion, the file was available. No app failure was inferred from these capture timing issues.

The Release process remains present and the captured runtime has no crash markers at the current check. Console attachment is stdout capture, not an LLDB/Flutter dependency. Asked the user to keep SayDian foreground on Device and confirm whether this round continues U19S. UI, actual reconnect, new measurement and cloud ACK/readback are recorded separately after real results; prior 1022 feedback is not substituted for this 1023 round.

## Actual device page and U19S sync

The user confirmed foreground testing with U19S. The installed 1023 Device page rendered in English; initially disconnected, with the expected search/help/weather controls. The user then explicitly confirmed selecting U19S and completing manual sync. A first subsequent capture was the iOS Home screen; the same PID2822 remained running with no crash/exit markers, so that foreground change is not counted as a crash. Reactivating the exact bundle and waiting two seconds produced the actual stable Device-page capture.

This 1023 capture verifies **U19S_SD_2765 / Connected / battery56%**, visible Sync device/Disconnect controls, the inline text “The cloud (US servers) has confirmed receipt of these records”, and removal of the separate storage card. This is device-page state and the user's manual-sync report. It does not independently establish fresh measurement IDs, payload contents, new three-metric server readback or measurement accuracy. No real health values or raw screenshots are committed.

The US admin session remained available. Only product selection/member navigation was performed; no member was edited and no raw health record opened. Before any account-specific data matching, requested the current account and three new measurements. **The user then explicitly requested skipping all three blood-pressure/heart-rate/oxygen tests.** That request supersedes the pending measurement/account prompt; no further measurements, account disclosure or three-metric cloud readback is required in this round. Those checks are recorded as user-skipped, not passed.

Final remaining step is a planned stop/relaunch of this exact Release app without console, Flutter or LLDB, leaving the independently running app on the phone. This intentional restart must not be reported as an unexpected termination.

## Independent startup result

Planned SIGTERM stopped the verified international PID2822; the console command consequently exited1, which is an expected result of this deliberate stop, not a spontaneous crash. A normal `devicectl device process launch` without --console, --start-stopped, Flutter or LLDB created **PID2924**. Subsequent process enumeration confirms this exact Release executable still running. The actual rendered account home is accessible and retains the prior account. The settled home uses Chinese in the existing account/device environment; the earlier Device page was observed in English. No fresh-install default-language claim or unverified language-reset diagnosis is made, and no language setting was changed by this task.

Original data preservation proof remains specifically before first launch; post-run database byte identity is not expected or asserted. New physiological measurements/accuracy, fresh three-metric cloud IDs/readback, auto-reconnect after the deliberate final restart, all-day background recovery, and LuckRing/QRing on this build were not tested. Only the three explicitly requested measurement checks were user-skipped; other untested paths remain untested rather than passed. Current scope is completed: 1023 installation, preserved data, normal Release startup, observed Device UI, user-confirmed U19S connection/manual sync and the actual cloud-confirmed UI state.

The US admin was restored to the legal-document page; no member or legal document was edited. Private console logs/screenshots/proofs and encrypted backup files are excluded from Git. This round changes documentation only, reuses the already accepted runtime CI and archive, and does not rerun unchanged source tests/builds or alter the uploaded store package.

## Commands and evidence boundary

```sh
xcrun devicectl device info apps --device 00008130-001C098C2290001C --bundle-id cn.saydian.app.global --include-container-paths
codesign --verify --deep --strict build/store-upload-20261104-1023/Runner.xcarchive/Products/Applications/Runner.app
ditto build/store-upload-20261104-1023/Runner.xcarchive/Products/Applications/Runner.app build/iphone15pm-1023-release-test/Runner.app
xcrun devicectl device install app --device 00008130-001C098C2290001C build/iphone15pm-1023-release-test/Runner.app
xcrun devicectl device process launch --device 00008130-001C098C2290001C --console cn.saydian.app.global
# After the user-skipped measurement step, stop only the verified target PID.
xcrun devicectl device process terminate --device 00008130-001C098C2290001C --pid 2822
xcrun devicectl device process launch --device 00008130-001C098C2290001C cn.saydian.app.global
```

Backups/readback use devicectl copy from with appDataContainer + exact cn.saydian.app.global, the three scoped data directories above and 45s timeout; all five original health/support file sizes and SHA256 values were compared before launch. Only sanitized counts enter this record. Full command output and machine-readable qa-proof.json are retained in the restricted task directory; no Keychain or database contents were decoded.
