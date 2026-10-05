# Tinni Star

**Canonical development, Android build and server deployment branch: [tinnistar](https://github.com/vinay1997mishra/voice-chat-app/tree/tinnistar).**

This branch starts from the verified consolidated release at `d979d6ec5c0edbfe0e05ea3fbd38b4e79889020d`, including the latest seat/voice recovery, fruit-game/Ludo, recent-seven-results, visual and protected owner-website fixes. Its runtime files are preserved unchanged from that release.

## Active applications

- `apps/tinni_star`: Flutter Android user application.
- `apps/tinni_worker`: Cloudflare Worker, durable SQLite stores, room/WebSocket APIs and server-authoritative transactions/games.
- `apps/tinni_owner_panel`: protected standalone owner/staff website. Owner master-panel functions are not embedded in the Android app.
- `docs/TINNI_STAR_COMPLETE_IMPLEMENTATION_BLUEPRINT_V3.md`: product blueprint.
- `apps/mobile` and earlier feature/prototype branches are historical work; build the active Android application from `apps/tinni_star`.

## Included user features

Authentication/profile/ID/privacy, rooms/discovery/presence/seats/moderation/voice, music/media, messages/friends/social/family, CP/rings/memories/rankings, gifts/Lucky/Combo/rocket/effects, inventory/VIP/store, normal/diamond/role wallets and hierarchy portals, Fruit Jackpot/Fruit Party/Ludo, and the existing connector/function-pack interfaces.

Both fruit games show the seven newest distinct confirmed settled results. A new result replaces the oldest visible result. Ludo preserves four corner-coloured player positions with names, avatars and room microphone controls.

## Checks and builds

Pushes and pull requests to `tinnistar` run the Android and Worker workflows when their relevant paths change. Android CI runs full Worker checks, Flutter analysis/tests, live server health/provider-configuration checks, and APK identity/signing checks. It uploads:
- `Tinni-Star-ARM64`: existing-package APK.
- `Tinni-Star-Split-APKs`: existing-package architecture variants.
- `Tinni-Star-Final-Separate-APKs`: separate-install **Tinni Star Final**, package `com.tinnistar.tinni_star.finalapp`.
- Game previews and provider-readiness reports.

Relevant pushes to `tinnistar` deploy the Worker and owner website through the existing configured Cloudflare workflow. Use this branch for future work. Other branch refs are retained for history; no historical feature branch is deleted by consolidation.

## Verification status

The preserved release passed Flutter analysis, all **175 app tests**, all **63 Worker tests**, Worker bundle dry-run, APK signing/identity checks and live server health/deep-health checks. The canonical-branch workflows must report their own results; a branch name is not proof of full functional coverage.

Separate-package Google OAuth registration, email OTP provider configuration, real two-device audio/mobile-network/Bluetooth checks, external payment/push/provider flows and complete owner-browser/device journeys remain outstanding. Existing Coming Soon or unavailable integrations do not become implemented through consolidation. APKs use the existing development signing certificate.

See [canonical branch audit](docs/TINNISTAR_CANONICAL_BRANCH.md) and [final build status](docs/TINNI_STAR_FINAL_BUILD_STATUS.md). Never commit credentials or provider secrets.
