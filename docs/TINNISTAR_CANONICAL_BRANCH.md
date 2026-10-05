# Canonical Tinni Star branch

The active line is `tinnistar`. Consolidation preserves the entire verified runtime from `d979d6ec5c0edbfe0e05ea3fbd38b4e79889020d`; it changes documentation and branch triggers only.

## Feature coverage retained

| Feature area | Current implementation |
| --- | --- |
| Login, account binding, password reset and public ID | apps/tinni_star/lib/auth; login/reset/mine-function screens; Worker auth/account routes |
| Rooms, seats, mute/unmute, live recovery | room services and LiveKit adapter; Worker directory/presence/WebSocket routes |
| Phone music picker, removal, 300-song limit and queue playback | media/ktv_service.dart and room screen |
| Inbox, seen status, calls and verification/billing | messages/call/verification screens, social/call services and Worker routes |
| Family, CP, store, VIP, sharing and profile | current feature screens/services and server catalogs/transactions |
| Gifts, Lucky Combo, rocket, diamonds and economy | room/gift/wallet services and server transaction stores |
| Fruit Jackpot/Party and newest seven results | remote games, shared casino panel and atomic server settlements |
| Ludo four player corners, real DP/name and microphone | Ludo screen/game, room session and server-authoritative Ludo routes |
| Owner master panel and staff permission controls | standalone owner website and protected Worker APIs; not added to Android |

## History audit

The branch comparisons below are Git ancestry results, not proof that every historical prototype is an active product feature. Many old feature commits were ported/squashed into later implementations and retain divergent history. Copying their old files over the current runtime would remove newer fixes. Old embedded-owner prototypes are superseded by the separate website, as requested. Standalone Anamika and versioned mobile prototypes are historical applications, not extra Android owner-panel controls.

| Existing ref | Compared with verified release | Unique commits in ancestry |
| --- | --- | ---: |
| add-music-phone-picker | diverged | 5 |
| anamika-ai-bootstrap | diverged | 156 |
| anamika-v7-8-1-apk-build | diverged | 3 |
| anamika-v7.8.2-final | diverged | 241 |
| anamika-v8-local-self-upgrade | diverged | 241 |
| anamika-v13-local-self-upgrade | diverged | 560 |
| arm64-apk-under-100mb | diverged | 1 |
| call-verification-billing | diverged | 20 |
| cloudflare/tinni-star-api | diverged | 4 |
| codex/anamika-repair-upgrade | diverged | 4 |
| codex/anamika-v13-headless-connector | diverged | 564 |
| codex/anamika-v13-runtime-repair | diverged | 561 |
| codex/anamika-v13-voice-conversation | diverged | 562 |
| feature/app-fruit-server-sync | diverged | 7 |
| feature/email-otp-password-login | diverged | 12 |
| feature/facebook-login | diverged | 10 |
| feature/fruit-jackpot-live-game | diverged | 11 |
| feature/global-room-presence | diverged | 14 |
| feature/livekit-voice-rtc | diverged | 7 |
| feature/real-users-rooms-google-auth | diverged | 52 |
| feature/reset-password-screen | diverged | 4 |
| feature/server-fruit-game-20s | diverged | 9 |
| feature/staff-credential-edit | diverged | 5 |
| feature/staff-panel-login-fields | diverged | 11 |
| feature/staff-power-controls | diverged | 4 |
| feature/tinni-final-complete-app | behind | 0 |
| feature/v06-vip-game | behind | 0 |
| fix/final-gift-rocket-flow | baseline | 0 |
| fix/login-copy-new-id | diverged | 1 |
| fix/room-seat-voice-lucky-ludo | behind | 0 |
| fix/tinni-app-entry-confirmed-actions | behind | 0 |
| fix/tinni-casino-bottom-games | behind | 0 |
| fix/tinni-reconnect-seat-recovery | behind | 0 |
| functional-pages-cp-store-calls-share | diverged | 35 |
| main | behind | 0 |
| message-inbox-seen-call | diverged | 8 |
| music-remove-max-300 | diverged | 5 |
| owner-manual-call-verify | diverged | 4 |
| owner-panel-all-working | diverged | 52 |
| room-tools-4box | diverged | 4 |
| room-tools-open-correct-function | diverged | 3 |
| security/owner-panel-login | diverged | 8 |
| tinni-blueprint-alignment-v1 | diverged | 38 |
| tinni-owner-panel-v1 | diverged | 5 |
| tinni-owner-web-panel | diverged | 10 |
| v06-dev | diverged | 20 |
| v07-dev | diverged | 64 |
| v08-dev | diverged | 189 |
| v08-vip-preview | diverged | 82 |

## Limits

All available current modules are retained; the existing 175 app/63 Worker tests are evidence for tested behavior. Full real-device/provider/browser coverage is not established. See the final build status for OAuth, OTP, audio, payments/push and device verification requirements.

Repository default-branch settings require GitHub repository administration settings; the available connector exposes branch/content writes but does not expose changing the default branch. Creating/configuring `tinnistar` does not itself rename the GitHub default setting. To use it as GitHub's default, select `tinnistar` in repository Settings → default branch.
