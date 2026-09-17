# Voice Chat App

Mobile-first social voice-room project. The repository currently starts with a GitHub-only Flutter demo so an installable Android APK can be built without a backend or paid cloud server.

## Phase 1 demo

The first APK includes:

- Demo login/onboarding
- Home and room discovery UI
- Voice-room style seat grid
- Join/leave seat and mic toggle simulation
- Local room chat
- Local test gifts and coin deductions
- Wallet balances and transaction history
- Profile / Me screen
- GitHub Actions APK build

> This phase intentionally uses local/demo data only. Real multi-user login, live voice, server-side wallet, payments and realtime synchronization will be connected in later phases.

## Repository layout

```text
apps/
  mobile/        Flutter Android demo
.github/
  workflows/     Automated APK build
```

## Build

Every push to `main` triggers the Android demo workflow. When it succeeds, download the `voice-chat-demo-apk` artifact from the workflow run and install `app-debug.apk` on an Android phone.

## Security

Never commit API keys, passwords, tokens, payment credentials or production secrets to this repository.
