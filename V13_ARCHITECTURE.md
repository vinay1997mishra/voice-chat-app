# Anamika 13 — Clean Rebuild Architecture

Anamika 13 is the new development line. V7.8.2 remains only as a migration reference while V13 components are rebuilt behind stable interfaces.

## Non-negotiable goals
- No GitHub/server dependency for normal self-upgrade.
- Phone-local source workspace, validation, build, signing, verification and rollback.
- Internet is optional: it may fetch documentation/dependencies, but an already-cached toolchain must remain usable offline.
- Final Android install/update always uses the Android package installer and owner confirmation.
- Existing phone/voice/plugin/blueprint/file/research capabilities are migrated into V13 modules instead of being deleted.
- Fail closed: an unverified candidate must never replace the installed app.

## V13 subsystem boundaries
1. owner — owner authentication, approval gates and trusted-device state.
2. voice — wake phrase, speech recognition and TTS.
3. assistant — command routing, local/online reasoning adapters and fallback routing.
4. phone — app discovery, intents, settings, calls, contacts and device functions.
5. automation — accessibility-driven owner-authorized UI automation.
6. blueprint — observable app-function discovery and local blueprints.
7. files — attachments, storage library, export and private vault.
8. research — public/visible screen research and local knowledge.
9. developer — project generation, validators and Code Doctor.
10. upgrade — source vault, candidate workspace, local build, signer, verifier, Test Lab and rollback.
11. media — image/video/3D creation and editing.
12. runtime — health checks, crash journal, resource guard and recovery.

## Local self-upgrade state machine
IDLE -> SNAPSHOT -> PLAN -> PATCH -> VALIDATE -> BUILD -> SIGN -> VERIFY -> OWNER_APPROVAL -> INSTALL_REQUESTED -> HEALTH_CHECK -> STABLE

Any failure before installation -> REJECTED.
Any failed post-update health check -> RECOVERY_REQUIRED.

## Security invariants
- Candidate package name must equal com.anamika.ai.
- Candidate versionCode must be greater than installed versionCode.
- Candidate signing certificate must match the installed application.
- Signing material is never committed to source control or exported in plaintext.
- Candidate changes, validation output, APK digest and owner approval are journaled locally.
- No silent install/security bypass.

## Migration rule
The V7.8.2 classes stay available only while their capability is being rebuilt in V13. A legacy module is removed only after its V13 replacement compiles and passes its smoke tests.

## Active build target
Gradle/CI builds only `:app13`. The legacy `:app` V7.x module is not part of the V13 build graph.
