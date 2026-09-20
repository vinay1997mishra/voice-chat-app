# Anamika Code Doctor and Repair Contract

Anamika treats GitHub CI as the source of truth for code correctness.

## Detect
Every proposed mobile change must pass formatting, Flutter static analysis, all tests, and an Android APK compile check.

## Repair loop
An AI coding service may read failed CI diagnostics and propose a patch on a dedicated branch. It may repeat diagnose -> patch -> CI for a bounded number of attempts.

The AI service must never:
- push directly to main;
- merge its own pull request;
- change the owner-approval gate, signing keys, secrets, CODEOWNERS, or security workflow;
- install an APK without explicit owner/user action;
- claim a repair succeeded before CI passes.

## Approval
A passing repair remains only a candidate. The owner reviews the diff and explicitly approves it before merge/release. Production signing secrets belong in a protected GitHub Environment. GitHub environment required reviewers should gate the release job.

## Rollback
Keep each accepted upgrade as a normal Git commit/release so a bad upgrade can be reverted. Never overwrite history to hide an upgrade.

## AI backend boundary
CI can detect compiler, analyzer, formatting, test, and build failures. Generating a semantic repair requires a coding model/backend with authenticated GitHub access. That backend is intentionally not faked or hard-coded into the mobile APK. When connected, it should create repair branches/PRs and use these checks as its feedback loop.
