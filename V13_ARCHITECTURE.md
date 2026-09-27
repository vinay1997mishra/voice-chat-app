# Anamika AI 13 — Clean Rebuild

Anamika 13 is a new Android application codebase. No V7.x application source is part of the V13 working tree or build graph.

## Rules
- Every V13 feature is implemented from new source under `app13/`.
- GitHub/server is not required by the runtime self-update design.
- Phone-local self-upgrade must use private source workspaces, validation, a local Android build toolchain, matching signing identity, APK verification, owner approval, and Android PackageInstaller.
- A failed or unverified candidate must never replace the installed app.
- AI/reasoning is isolated from deterministic phone functions so an AI failure cannot take down the assistant core.
- Accessibility automation is owner-controlled per app and only uses UI Android exposes.
- Final update installation follows Android security confirmation; no silent-install bypass.

## Current clean modules
- Owner PIN/trusted-device core
- Crash journal and health monitor
- Text command router
- Foreground speech input and TTS
- Background wake service foundation
- Installed-app launcher and calculator
- Owner-controlled Plugin Center
- Accessibility tap/type/back bridge
- Deep Blueprint recorder
- Local source vault and self-upgrade workspace
- APK signature/version verifier
- Android self-update installer
- Local build-toolchain readiness gate

## Build target
Only `:app13` is compiled for Anamika 13.
