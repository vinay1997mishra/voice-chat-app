# Tinni Star Cloudflare Worker

Cloudflare Worker backend entry point for Tinni Star.

Cloudflare Workers Builds settings:

- Project / Worker name: `tinni-star-api`
- Production branch: `main`
- Root directory: `apps/tinni_worker`
- Build command: leave empty
- Deploy command: `npx wrangler deploy`
- Preview command: `npx wrangler preview`

Current endpoints:
- `GET /health`
- `GET /`

Protected owner APIs, game authority, wallet settlement, and other production services must remain server-authoritative and authenticated.
