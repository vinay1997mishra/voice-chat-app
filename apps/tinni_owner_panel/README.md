# Tinni Star Owner Web Panel

Standalone platform-owner control panel for Tinni Star.

This panel is deliberately **separate from the Android app**. Room owners and normal users do not receive it.

## Current scope

- Website-style responsive Owner dashboard
- Owner Treasury UI
- Master feature switches
- User / room investigation screens
- User, device, room and wallet control surfaces
- Coin Seller / Merchant wallet management surfaces
- BD / Agency / Host owner-override controls
- Multiple tags / roles / posts
- Full VIP catalog editor surface
- Gift, entry-effect, frame and banner management surfaces
- Host / Agency / BD policy editor
- Game investigation/control surface
- Custom panel builder surface
- Audit-log surface
- Existing Cloudflare Worker health check

## Security model

Do not put an owner password, API token, D1 credential or other secret in this frontend.

Before enabling real owner actions, the Cloudflare Worker must expose protected owner APIs and verify an authenticated platform-owner session server-side. Deploy the web panel behind Cloudflare Access (or an equivalent owner-only authentication layer) as an additional boundary.

## Cloudflare Pages

This project is static and has no build step.

- Root directory: `apps/tinni_owner_panel`
- Build command: leave empty
- Output directory: `.`

The current backend base URL is defined in `app.js`.

## Important

UI actions that do not yet have protected server endpoints intentionally do not claim success. They show that the Owner API is not connected yet. Treasury behavior is currently a frontend preview until the protected Owner Treasury endpoints are implemented.
