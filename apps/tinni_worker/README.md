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


## Staff credential changes

The platform owner can change a staff panel's login Gmail/email and reset its password after creation.

- Existing passwords are never displayed.
- Password resets generate a new random salt and PBKDF2-SHA256 hash.
- Gmail/email changes enforce uniqueness.
- Email or password changes increment the staff authentication version so existing staff sessions are invalidated and the staff member must log in again with the new credentials.


## Facebook login

Tinni Star supports Facebook login through a server-side browser OAuth flow. This avoids requiring the native Facebook SDK inside the APK.

Required Cloudflare Worker secrets:

- `FACEBOOK_APP_ID`
- `FACEBOOK_APP_SECRET`

In the Meta app's Facebook Login settings, add this exact Valid OAuth Redirect URI:

`https://tinni-star-api.mishrajii7991.workers.dev/app-auth/facebook/callback`

The app reads only a boolean `facebook_configured` flag from `/app-config`; the Facebook App Secret is never sent to the mobile app.

If a Facebook account email already belongs to an existing Google-created Tinni ID, the Facebook identity is linked to that same Tinni ID instead of creating a duplicate account.


## Email OTP and Tinni password login

Users can choose **Email / Gmail Login** below Google and Facebook.

Flow:

1. Enter email/Gmail ID.
2. Send a 6-digit OTP to that inbox.
3. Verify OTP.
4. Create a Tinni password (the user's actual Gmail password is never requested).
5. New users finish DP/name/age/country flag/gender/signature setup.
6. On later logins, users can enter the same email + Tinni password directly.

Passwords are stored only as salted PBKDF2-SHA256 hashes. OTP values are also stored as salted hashes, expire after 10 minutes, and are limited to 5 verification attempts.

Cloudflare Worker secrets required to send OTP email through Resend:

- `RESEND_API_KEY`
- `EMAIL_FROM` (a verified sender such as `Tinni Star <login@yourdomain.com>`)

Direct email + Tinni password login still works if the email delivery provider is temporarily unavailable; only sending a new/reset OTP requires the provider.
