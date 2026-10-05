# Tinni Star Final 0.5.28 (46)

Based on consolidated `fix/final-gift-rocket-flow` at cc763b6d3b3384a2ebc5666c83ec2e530e0404e6, including merged PRs 51, 52 and 53. All existing runtime modules remain included.

## Delivery

Android CI produces the existing-package APK and a separate-install APK named **Tinni Star Final** with application ID `com.tinnistar.tinni_star.finalapp`. Both use the same server and accounts. APKs are signed using the repository's existing development certificate; this is not a new production signing key.

The separate package needs its Android package name and certificate registered with Google OAuth before native Google sign-in can be claimed working. Existing Facebook/deep-link callbacks use the shared tinnistar scheme; with both apps installed, Android can ask which app opens a callback. No provider settings are changed by this PR.

## Changes

- Both Fruit Jackpot and Fruit Party show seven persistent visible result slots. Only confirmed settled rounds are shown, sorted newest first and deduplicated by round ID. The eighth result removes the oldest visible result. Empty slots remain placeholders before seven rounds exist; Lucky 11 shows a dedicated icon and tooltip listing bonus fruits.
- Preserve server-authoritative Ludo with four corner-coloured player positions, real names, avatars and room microphone controls, including token selection, leave/rejoin and turn validation.
- Midnight-blue shared surfaces, readable slate text, champagne accents and a shaded rose CP heart.
- Correct Owner numeric Unique ID creation validation.
- Run full Worker tests, owner frontend syntax checks, Worker bundle dry-run, Flutter analyzer/tests, live health/deep-health/provider checks, APK signing and separate-package identity checks before artifact delivery.
- Add real workerd/SQLite/RPC owner action checks: owner authentication rejection, identity/profile, moderation, VIP, numeric/name IDs, room controls, coins/diamonds and seller/merchant wallets, feature/policy/game settings, catalog create/edit/toggle/remove and persisted dashboard reads.

## Verification boundaries

Automated tests cover exercised operations, not every possible real-device/provider interaction. Existing source-pattern tests are not end-to-end proof. The owner panel remains its protected web app; no owner credential or unrestricted owner controls are embedded in ordinary Android users' builds.

Two-device LiveKit voice/audio, Bluetooth routing, reconnecting on real mobile networks, payment/recharge/withdrawal providers, email delivery, OS push notifications, media decoding on hardware and all owner browser journeys require separate live/device validation. Provider readiness artifacts report configuration, not successful external provider transactions. Disabled or Coming Soon games do not become implemented through this build. No claim of 100% functional coverage is made.

## Feature inventory retained

Authentication/profile/privacy and ID, home/discovery/rooms, room presence/seats/moderation/voice/music/video, messages/social/friends/moments, CP/rings/memories/ranking, gifts/Lucky/Combo/rocket/effects/inventory/VIP/store, wallets/coin-seller/merchant/hierarchy/host/agency/BD, Fruit Jackpot/Fruit Party/Ludo, and existing Anamika/function-pack interfaces. Runtime tests and configured-provider checks run in CI; incomplete integrations remain reported as such.

Owner runtime audit also caught a Full ID dashboard failure: its recent-room query used a non-existent last_entered_at SQL column. Read visited_at with a compatible last_entered_at response alias.

Owner Treasury sends now roll back the debit when the recipient cannot be credited. The real Worker test also checks treasury rollback, hierarchy changes, ten catalog types, Lucky configuration and per-user pricing.
