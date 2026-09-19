# Anamika APK Build Server

This server has one job only: **compile a completed Android project into an APK**.

Coding, project generation, file editing and Git work stay on the Anamika phone app. The server is contacted only after the local project is ready and the owner requests an APK build.

## Flow

1. Anamika creates/edits source code in the phone's local workspace.
2. The owner approves `build apk`.
3. Anamika packages the completed project as ZIP.
4. The ZIP is uploaded to this build server.
5. The server runs:
   - `testDebugUnitTest`
   - `lintDebug`
   - `assembleDebug`
6. The resulting APK is returned to Anamika.
7. Anamika downloads it and can open Android's install screen after owner approval.

## API

- `GET /health`
- `POST /v1/builds` — completed project ZIP
- `GET /v1/builds/{id}` — build status
- `GET /v1/builds/{id}/artifact` — APK
- `GET /v1/builds/{id}/log` — build log

There is intentionally **no AI/code-generation endpoint** on this server.

## Run with Docker

```bash
docker build -t anamika-apk-builder .
docker run --rm -p 8080:8080 anamika-apk-builder
```

For public deployment, enable TLS, authentication, rate limits and isolated/disposable build sandboxes.

The current reference server builds installable **debug APKs**. Production signed APK/AAB support should keep signing keys only on the protected build server or secure signing service.
