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


## Staff panel accounts

Custom staff panels use the same login page as the owner.

When the owner creates a staff panel, the form collects:

- Panel name
- Optional linked user ID
- Staff login Gmail/email
- Staff login password + confirmation
- Exact panel permissions

Staff passwords are never stored as plain text. The Worker stores a random salt and a PBKDF2-SHA256 password hash in the SQLite-backed `StaffAuthStore` Durable Object. Cloudflare provisions the Durable Object namespace from `wrangler.jsonc` during deployment.

Staff sessions are signed with `SESSION_SECRET`, and the UI is filtered to the permissions saved on that staff panel. Owner-only staff management endpoints remain restricted to the owner session.


## Staff power management

The Owner Panel shows every permission currently granted to each staff panel. The owner can:

- turn individual powers on or off at any time
- disable or re-enable the entire staff login
- see the staff email, linked user ID, active status, and current permissions

Permission and enabled-state changes are persisted in the StaffAuthStore and are re-checked on authenticated requests, so removed access does not rely only on hiding UI controls.
