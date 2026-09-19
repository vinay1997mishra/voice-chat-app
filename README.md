# Anamika AI V7.8 Evergreen — Source Project

V7.8 extends V7.7 Full Toolchain Strict with first-class HTML5/CSS3 validation, evergreen self-upgrade workspace support, universal installed-app discovery, Google/YouTube search launchers, explicit Research/Learn mode, and multilingual command normalization.

## Core rules

1. Owner lock remains mandatory.
2. App automation is owner-enabled per app through Plugin Center.
3. Research mode records only visible/public UI that Android Accessibility exposes while the owner explicitly starts a session.
4. Self-upgrade code may be generated locally, but it is not silently activated. Review + compiler/build checks + owner approval remain required.
5. `FULL VERIFIED` remains strict. Missing real compiler/runtime packs are reported as missing, not faked as passing.
6. HTML5/CSS3 use dedicated validators instead of a fake compiler.
7. Multilingual voice support depends on installed speech recognition/language packs; the local model can normalize text when bundled.

## Build note

This repository is prepared as an Android Studio project, but the current ChatGPT execution environment does not contain a full Android SDK/device toolchain, so a real APK/device build is still required before calling it production-ready.

See `V7_8_EVERGREEN_FEATURES.md`, `FULL_TOOLCHAIN_STATUS.md`, and `PLUGIN_SYSTEM.md`.
