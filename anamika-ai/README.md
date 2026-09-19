# Anamika AI Android Bootstrap

Anamika uses a **local-first coding architecture**.

## Core rule

**Coding happens on the phone. The external build server is used only after coding is complete and an APK needs to be compiled.**

## Phone-side capabilities

- Local workspace and source-file storage
- Create/read/update/delete/list project files
- Local Git repository
- Status, branch, checkout, commit, log, diff, tag and merge
- Hindi/English voice commands
- Owner permission system
- Local Android project generation
- Phone-side AI/coding hook for future on-device or direct AI provider integration
- Offline queue for GitHub remote actions

Example:

`app banao notes app`

This generates the Android project in the phone's local workspace. It does **not** contact the APK build server.

## APK build flow

When source code is ready:

`build apk`

Then Anamika:
1. packages the completed local workspace,
2. asks for owner authorization,
3. uploads only the completed project to the configured APK build server,
4. receives build status,
5. downloads the APK,
6. can open Android's installer after owner approval.

## Build server responsibility

The build server only:
- accepts completed project ZIPs,
- runs unit tests,
- runs Android lint,
- runs Gradle APK compilation,
- returns APK/build logs.

It does not generate or edit code.

## Owner Permission System

- NORMAL — read-only operations
- PROTECTED — local file/repo writes
- CRITICAL — merges, push, APK build/download/install, releases, self-update
- ULTRA_CRITICAL — repository/security settings, secrets, repository deletion, PR merge

## Important current limitation

The local project generator can create a valid Android project structure on the phone. A general-purpose AI coding model capable of implementing arbitrary complex apps still needs to be connected as either:
- an on-device model, or
- a phone-direct AI provider connection.

That AI connection remains separate from the APK build server.
