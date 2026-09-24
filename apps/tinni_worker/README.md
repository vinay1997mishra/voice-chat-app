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


## Owner Panel login secrets

The Owner Panel is protected by Worker authentication. Configure these as Cloudflare encrypted secrets, not repository variables:

- `OWNER_EMAIL` — the owner login email
- `OWNER_PASSWORD` — the owner login password
- `SESSION_SECRET` — a long random value used to sign secure session cookies

The Worker issues an HttpOnly, Secure, SameSite=Strict session cookie after a successful login. Do not commit any of these values to GitHub.
