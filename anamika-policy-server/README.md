# Anamika Owner Policy Service

This service is the control plane for public-distribution access and owner recovery. It does **not** generate code and does **not** build APKs.

## Owner recovery

Public and owner copies use Sign in with Google. The server verifies the Google ID token and uses the immutable Google `sub` claim as the account identity.

Initial owner binding can be configured with either:
- `ANAMIKA_OWNER_GOOGLE_SUB` — preferred when already known, or
- `ANAMIKA_OWNER_BOOTSTRAP_EMAIL` — used only for the first verified login; after that the server stores the Google `sub` and ownership is matched by `sub`, not by email.

The policy store must be on persistent storage. If the phone is lost, signing in on a new phone with the same Google account restores the OWNER role as long as the stored owner binding (or `ANAMIKA_OWNER_GOOGLE_SUB`) remains available.

## Function Control

Only an authenticated OWNER session can access:
- `GET /owner/catalog`
- `PUT /owner/catalog/{feature_key}`
- `POST /owner/catalog/register`

Every function has:
- `ownerEnabled`
- `userEnabled`

All public/user features default to **OFF**. A public feature becomes available only after the owner explicitly enables its `Users` switch.

New learned/update modules are registered into the same catalog and also default to Owner OFF / Users OFF until the owner decides.

## Public users

Normal users:
- only see Google sign-in before login,
- never receive owner console access,
- cannot change public entitlements,
- receive only signed feature entitlements from this service.

## Required secrets/config

- `ANAMIKA_GOOGLE_CLIENT_ID` — Google OAuth Web Client ID used to verify ID tokens.
- `ANAMIKA_SESSION_SECRET` — signs short-lived app sessions.
- `ANAMIKA_POLICY_PRIVATE_KEY_PEM` — signs public feature entitlements.
- `ANAMIKA_POLICY_ADMIN_TOKEN` — optional server-admin fallback.
- `ANAMIKA_POLICY_STORE` — persistent JSON path.
- One of:
  - `ANAMIKA_OWNER_GOOGLE_SUB`
  - `ANAMIKA_OWNER_BOOTSTRAP_EMAIL`

Never put the private signing key, admin token, or session secret in a public APK.

## Client configuration

Android builds need:
- `GOOGLE_WEB_CLIENT_ID`
- `ANAMIKA_PUBLIC_AUTH_URL`
- `ANAMIKA_POLICY_BASE_URL`
- `ANAMIKA_OWNER_POLICY_URL`
- `ANAMIKA_OWNER_POLICY_PUBLIC_KEY`

The APK build server remains compile-only and separate from this service.


## ID login and owner recovery

The public login screen can offer both:
- Sign in with Google
- ID + password

A normal ID account receives the USER role.

The special owner ID is configured only on the policy server:
- `ANAMIKA_OWNER_ID`
- `ANAMIKA_OWNER_PASSWORD_HASH`

Generate the password hash with:

```bash
python make_password_hash.py
```

Store the printed hash as `ANAMIKA_OWNER_PASSWORD_HASH`. Never put the owner ID password or its plaintext value in the Android APK, repository, or client configuration.

A successful special ID + password login receives an OWNER session directly. No CAPTCHA/OTP/second-factor is added by Anamika after that login unless the owner later chooses to add one.

Normal ID accounts are stored server-side with scrypt password hashes and can be provisioned through the owner-authenticated ID-user endpoint.

## Recovery priority

Ownership can be recovered on a replacement phone through either:
1. the same verified Google account (matched by Google `sub`), or
2. the special owner ID + password.

Both methods resolve to the same hidden OWNER role and Function Control surface.
