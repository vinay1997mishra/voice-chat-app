# Anamika Build Server

This server gives the Anamika Android app two build modes:

1. **Project build**: Anamika uploads an existing Android/Gradle project ZIP.
2. **AI agent build**: Anamika sends an app goal, a server-side coding agent generates the Android project, then the server tests, lints and builds the APK.

## API
- `GET /health`
- `POST /v1/builds` — multipart `project` ZIP + `build_type=debug`
- `POST /v1/agent-builds` — JSON: `{"goal":"create a notes app"}`
- `GET /v1/builds/{id}`
- `GET /v1/builds/{id}/artifact`
- `GET /v1/builds/{id}/log`

## AI coding agent contract

Set `ANAMIKA_GENERATOR_CMD` to an approved coding-agent command installed on the server.

The process receives:
- `ANAMIKA_APP_GOAL` — user's app request
- `ANAMIKA_PROJECT_OUTPUT` — directory where the complete Gradle Android project must be written
- `ANAMIKA_JOB_ID` — build job identifier

The generator must finish with exit code 0 and leave a valid Android Gradle project in `ANAMIKA_PROJECT_OUTPUT`.

After generation the server automatically runs:
- `testDebugUnitTest`
- `lintDebug`
- `assembleDebug`

If all pass, the installable APK becomes available from the artifact endpoint.

## Run with Docker

```bash
docker build -t anamika-build-server .
docker run --rm -p 8080:8080 \
  -e ANAMIKA_GENERATOR_CMD="/opt/anamika/generate-project" \
  anamika-build-server
```

For a private test server, authentication can be omitted. For public internet deployment, use TLS and authentication. If `ANAMIKA_BUILD_TOKEN` is set, the API expects `Authorization: Bearer <token>`.

## Security

Android/Gradle builds can execute code. Production deployments should run every job inside a disposable sandbox/container or VM with:
- no host filesystem access
- no cloud metadata access
- restricted outbound network
- CPU/RAM/disk/time limits
- short-lived workspaces
- TLS
- authentication and rate limiting
- server-side signing keys/secrets only

The reference server creates an installable **debug APK**. Production release signing requires a protected server-side keystore/HSM or secret store. Never put signing keys or permanent API secrets inside the Anamika APK.
