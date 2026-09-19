# Anamika AI Android Bootstrap

This folder is an isolated Android bootstrap for Anamika AI.

## Included now
- Android Kotlin app shell
- Hindi/English speech input through Android SpeechRecognizer
- Hindi/English text-to-speech replies
- Command router
- Local memory using SharedPreferences
- Web search command
- GitHub release checker for tags beginning with `anamika-v`
- Owner approval gate before any upgrade handoff
- Update release notes shown before approval
- No silent/self installation
- AI code-generation interface
- Link/video-learning interface
- Unit tests for command parsing
- GitHub Actions APK build, tests and lint
- GitHub release artifact flow
- Security scanning workflow

## Security rules
Anamika must never embed API keys in the APK. AI/code analysis and video/link learning should call a protected backend. Generated code must be reviewed/tested in a sandbox before being accepted.

The current owner gate uses Android device credentials. Speech-to-text alone cannot prove speaker identity, so true owner voice verification must use a dedicated speaker-verification model/service and should remain an additional factor rather than replacing device authentication.

## GitHub release convention
Create tags such as `anamika-v0.1.0`.

The workflow builds an installable debug APK for testing and can attach it to the GitHub release.

## Next backend modules
- AI chat and coding model gateway
- URL/video fetch + transcription + analysis pipeline
- Code sandbox/validator for multiple languages
- Encrypted sync memory
- Speaker verification
- Production APK signing
