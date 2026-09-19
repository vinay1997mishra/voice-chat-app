# Anamika AI security policy

- Never commit API keys, signing passwords, tokens or private owner data.
- Never allow the app to silently install an update.
- Every self-upgrade request must show the proposed release notes first and require explicit owner approval.
- AI-generated code must be validated and tested before it can become part of a release.
- Untrusted code should run only in an isolated backend sandbox, never directly with Android app privileges.
- Voice transcription is not speaker identity. Owner voice verification requires a dedicated speaker-verification layer.
- Production signing keys belong in protected CI secrets, not source control.
