# Anamika AI Android Bootstrap

Anamika uses a **local-first, owner-controlled architecture**.

## Core rule

**Coding happens on the phone. The external build server is used only after coding is complete and an APK needs to be compiled.**

## Internet policy

- Anamika can use the phone's Wi-Fi/mobile-data connection.
- Internal Anamika internet policy defaults to **ON**.
- Owner can say `internet band` to block Anamika-initiated network requests.
- Owner can say `internet chalu` to re-enable them.
- Local coding, local files and local Git continue working while internet is OFF.
- Android `INTERNET` and `ACCESS_NETWORK_STATE` are normal install-time permissions.

## Phone-side coding

- Local workspace and source files
- Create/read/update/delete/list project files
- Local Git: status, branches, checkout, commit, log, diff, tag, merge
- Local Android project generation
- Phone-side AI/coding hook for a future on-device or direct AI provider
- APK build server is not used for coding

Example:

`app banao notes app`

This creates the Android project in the phone's local workspace.

## Owner-authorized cross-app mode

Anamika includes an Accessibility-service foundation for user-authorized app interaction.

Flow:
1. Owner manually enables Anamika Accessibility service in Android Settings.
2. Open a target app once.
3. Return to Anamika and say `app allow current`.
4. Owner authentication authorizes that app.
5. Only authorized apps can be observed/controlled.

Supported foundation:
- remember the recent foreground app
- local allow/deny list
- observe accessible UI events and visible labels
- build a local feature/UI summary with `app model current`
- open an installed app by package
- click visible accessible controls
- type only into focused **non-sensitive** editable fields

Anamika intentionally blocks capture/automation of password, PIN, OTP, CVV and similar secure fields.

This does **not** extract another app's private source code. Anamika can study owner-authorized visible behavior/flows and use that information as a reference for a separate implementation. Proprietary code/assets, authentication bypasses and protected screens are not copied.

Android requires the user to explicitly enable an Accessibility service in Settings. Screen capture, when used later, must use Android MediaProjection and requires user consent according to the Android version.

## APK build flow

When code is ready:

`build apk`

Anamika:
1. packages the completed local workspace,
2. asks for owner authorization,
3. uploads the completed project to the configured APK build server,
4. server runs unit tests, Android lint and Gradle compilation,
5. Anamika downloads the APK,
6. Android installer opens only after owner approval.

## Build server responsibility

The server only:
- accepts completed project ZIPs,
- runs tests,
- runs lint,
- compiles APK,
- returns APK/build logs.

It does not generate or edit source code.

## Owner Permission System

- NORMAL — read-only operations
- PROTECTED — local file/repo writes, internet policy changes, ordinary authorized app control
- CRITICAL — app authorization, merges, push, APK build/install, releases, self-update
- ULTRA_CRITICAL — repository/security settings, secrets, repository deletion, PR merge

## Important limitations

- Android does not allow Anamika to bypass another app's login security, 2FA, CAPTCHA, secure UI or OS permissions.
- Some apps deliberately block screen capture or expose little/no accessibility information.
- General-purpose automation through Accessibility may be subject to app-store policy restrictions even when technically possible.
- A general-purpose AI model for implementing arbitrary complex applications is still a separate phone-side integration from the APK build server.
