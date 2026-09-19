# Anamika Owner Policy Service

This service exists only for **public-distribution feature control**. It does not generate code and does not build APKs.

A public Anamika install has a random installation ID. It requests an entitlement for that ID. The service signs the response with the Anamika owner's ECDSA private key. Public APKs contain only the matching public key and reject unsigned or modified policies.

## What the owner can control

Feature keys include chat, voice input, voice reply, memory, search, internet, local coding, link analysis, Git/GitHub, app study, cross-app control, APK build and self-update.

Use subject `*` for public defaults, or a specific installation ID for per-install overrides.

## Required secrets

- `ANAMIKA_POLICY_ADMIN_TOKEN` — protects admin changes.
- `ANAMIKA_POLICY_PRIVATE_KEY_PEM` — ECDSA private key used only by this service.
- `ANAMIKA_POLICY_STORE` — optional persistent JSON path.

Never put the private key or admin token in a public APK.

## Client configuration

The public Android release needs:
- `ANAMIKA_OWNER_POLICY_URL` pointing to this service's HTTPS `/entitlements` endpoint.
- `ANAMIKA_OWNER_POLICY_PUBLIC_KEY` containing the Base64 DER/X.509 public key.

## Important

This is a separate control-plane service. The Anamika APK build server remains compile-only.
