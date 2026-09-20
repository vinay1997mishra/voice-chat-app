# Anamika Safe Self-Upgrade System

## Security invariant
Anamika may prepare and validate an upgrade proposal, but it must never approve its own upgrade. Owner approval is mandatory before a candidate build can run.

## Flow
1. Prepare a proposal with an ID, summary, and changed-file list.
2. Run policy validation. Protected paths and unsafe paths are rejected.
3. Show the proposal/diff to the owner.
4. Owner approves or rejects it.
5. Only an approved proposal may enter the build stage.
6. CI runs Flutter analysis, safety tests, full tests, APK build, and APK signature verification.
7. The verified APK is a candidate artifact. Installation remains an explicit Android/user action.

## Protected controls
The self-upgrade workflow, signing configuration, and keystore are protected from self-modification by the in-app policy. Repository permissions are read-only in the upgrade workflow.

## Important boundary
This repository does not contain an AI coding backend or a production owner-authentication backend. The controller requires a trusted owner-authenticated result supplied by the future authentication layer. It deliberately does not hard-code an owner password or signing secret.

Production release signing must use protected secrets/keys and should be placed behind a GitHub Environment required-reviewer gate. Never commit private signing keys or passwords to the repository.

## Connected repair pipeline
See [ANAMIKA_REPAIR_SETUP.md](ANAMIKA_REPAIR_SETUP.md) for the online repair worker,
owner console, exact-commit approval and explicit remaining release prerequisites.
The workflow now requires an open Anamika PR and its full reviewed head SHA, and
restricts dispatch to the repository owner on main. A passing debug signature is
not evidence of compatibility with an installed production APK.
