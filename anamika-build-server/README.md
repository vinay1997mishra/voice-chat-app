# Anamika Build Server

This is the reference server for Anamika's phone-to-server APK build mode.

## API
- `GET /health`
- `POST /v1/builds` — multipart field `project` (ZIP), optional `build_type=debug`
- `GET /v1/builds/{id}`
- `GET /v1/builds/{id}/artifact`
- `GET /v1/builds/{id}/log`

## Run with Docker

```bash
docker build -t anamika-build-server .
docker run --rm -p 8080:8080 \
  -e ANAMIKA_BUILD_TOKEN=change-me \
  anamika-build-server
```

For a quick private-network test, `ANAMIKA_BUILD_TOKEN` may be omitted. Do not expose an unauthenticated build server to the public internet.

## Production security

Android/Gradle build scripts can execute code. Treat every submitted project as untrusted. A production deployment should run each build in a disposable sandbox/container or VM with:
- no host filesystem access
- no cloud metadata access
- restricted outbound network
- CPU/RAM/disk/time limits
- short-lived workspace
- TLS
- authentication and rate limits
- server-side secret isolation

The reference API produces an installable **debug APK**. Production release signing should use a protected server-side keystore/HSM/secret store; the signing key must never be embedded in the Anamika APK or uploaded inside the project ZIP.
