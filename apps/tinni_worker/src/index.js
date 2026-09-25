import { DurableObject } from "cloudflare:workers";
import { FruitGameStore } from "./fruit_game.js";
import { RoomPresenceStore } from "./room_presence.js";
import { AppDirectoryStore } from "./app_directory.js";
export { FruitGameStore, RoomPresenceStore, AppDirectoryStore };

const encoder = new TextEncoder();
const decoder = new TextDecoder();

const STAFF_PERMISSIONS = new Set([
  "users",
  "rooms",
  "wallets",
  "hierarchy",
  "roles",
  "vip",
  "gifts",
  "assets",
  "banners",
  "games",
  "policies",
  "audit"
]);

function json(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...headers,
    },
  });
}

function getCookie(request, name) {
  const cookie = request.headers.get("cookie") || "";
  for (const part of cookie.split(";")) {
    const [key, ...rest] = part.trim().split("=");
    if (key === name) return rest.join("=");
  }
  return null;
}

function toBase64Url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function fromBase64Url(value) {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  return new Uint8Array([...binary].map((char) => char.charCodeAt(0)));
}

function stringToBase64Url(value) {
  return toBase64Url(encoder.encode(value));
}

function safeEqualBytes(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) diff |= a[i] ^ b[i];
  return diff === 0;
}

async function hmacBytes(value, secret) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(value));
  return new Uint8Array(signature);
}

async function createLiveKitAccessToken({
  apiKey,
  apiSecret,
  roomId,
  userId,
  displayName,
}) {
  const now = Math.floor(Date.now() / 1000);
  const header = stringToBase64Url(JSON.stringify({
    alg: "HS256",
    typ: "JWT",
  }));
  const payload = stringToBase64Url(JSON.stringify({
    iss: String(apiKey),
    sub: String(userId),
    name: String(displayName || userId),
    nbf: now - 5,
    exp: now + 60 * 60,
    video: {
      roomJoin: true,
      room: String(roomId),
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    },
  }));
  const signingInput = header + "." + payload;
  const signature = await hmacBytes(signingInput, String(apiSecret));
  return signingInput + "." + toBase64Url(signature);
}

async function createSession(
  payload,
  secret,
  maxAgeMs = 12 * 60 * 60 * 1000,
) {
  const sessionPayload = JSON.stringify({
    ...payload,
    exp: Date.now() + maxAgeMs,
  });
  const encoded = stringToBase64Url(sessionPayload);
  const signature = await hmacBytes(encoded, secret);
  return encoded + "." + toBase64Url(signature);
}

async function parseSignedSession(token, secret) {
  if (!token || !secret) return null;
  const dot = token.lastIndexOf(".");
  if (dot <= 0) return null;

  const encoded = token.slice(0, dot);
  const signature = token.slice(dot + 1);
  const expected = await hmacBytes(encoded, secret);

  let actual;
  try {
    actual = fromBase64Url(signature);
  } catch {
    return null;
  }
  if (!safeEqualBytes(expected, actual)) return null;

  try {
    const payload = JSON.parse(decoder.decode(fromBase64Url(encoded)));
    if (Number(payload.exp) <= Date.now()) return null;
    return payload;
  } catch {
    return null;
  }
}

function bearerToken(request) {
  const authorization = request.headers.get("authorization") || "";
  if (!authorization.toLowerCase().startsWith("bearer ")) return null;
  return authorization.slice(7).trim();
}

async function verifyAppSession(request, env) {
  const payload = await parseSignedSession(
    bearerToken(request),
    env.SESSION_SECRET,
  );
  if (!payload || payload.role !== "user" || !payload.userId) return null;

  const store = getAppDirectoryStore(env);
  const user = await store.getUserById(payload.userId);
  if (!user) return null;

  const provider = String(payload.provider || "google");
  const subject = String(payload.subject || payload.googleSub || "");
  const identityUser = await store.getUserByProvider(provider, subject);
  if (!identityUser || identityUser.user_id !== user.user_id) return null;

  if (provider === "email") {
    const version = await store.getEmailCredentialVersion(subject);
    if (version === null || Number(payload.authVersion || 0) !== version) {
      return null;
    }
  }
  return { ...payload, user };
}

async function createAppUserSession(
  user,
  env,
  providerValue,
  subjectValue,
  authVersionValue,
) {
  const provider = String(providerValue || user.auth_provider || "google");
  const subject = String(subjectValue || user.auth_subject || user.google_sub);
  return createSession(
    {
      role: "user",
      userId: user.user_id,
      provider,
      subject,
      ...(provider === "email"
        ? { authVersion: Number(authVersionValue || 1) }
        : {}),
    },
    env.SESSION_SECRET,
    30 * 24 * 60 * 60 * 1000,
  );
}

async function sendEmailOtp(email, otp, env) {
  if (!env.RESEND_API_KEY || !env.EMAIL_FROM) {
    throw new Error("Email OTP service is not configured yet");
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer " + String(env.RESEND_API_KEY),
    },
    body: JSON.stringify({
      from: String(env.EMAIL_FROM),
      to: [String(email)],
      subject: "Your Tinni Star OTP",
      html:
        "<div style=\"font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px\">" +
        "<h2>Tinni Star</h2>" +
        "<p>Your verification code is:</p>" +
        "<div style=\"font-size:32px;font-weight:800;letter-spacing:8px\">" +
        String(otp) +
        "</div>" +
        "<p>This code expires in 10 minutes. Do not share it with anyone.</p>" +
        "</div>",
    }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(
      "Unable to send OTP email" +
        (body ? ": " + body.slice(0, 180) : ""),
    );
  }
}

async function verifyGoogleIdToken(idToken, env) {
  if (!env.GOOGLE_SERVER_CLIENT_ID) {
    throw new Error("Google OAuth is not configured on the server");
  }
  const token = String(idToken || "").trim();
  if (!token) throw new Error("Google ID token is required");

  const response = await fetch(
    "https://oauth2.googleapis.com/tokeninfo?id_token=" +
      encodeURIComponent(token),
    { headers: { "cache-control": "no-store" } },
  );
  if (!response.ok) throw new Error("Google account verification failed");

  const profile = await response.json();
  if (String(profile.aud || "") !== String(env.GOOGLE_SERVER_CLIENT_ID)) {
    throw new Error("Google token audience is invalid");
  }
  if (
    profile.email_verified !== true &&
    String(profile.email_verified || "").toLowerCase() !== "true"
  ) {
    throw new Error("Google email is not verified");
  }
  if (Number(profile.exp || 0) * 1000 <= Date.now()) {
    throw new Error("Google sign-in token has expired");
  }
  return {
    sub: String(profile.sub || ""),
    email: String(profile.email || "").toLowerCase(),
    name: String(profile.name || ""),
    picture: profile.picture ? String(profile.picture) : null,
  };
}

async function verifySession(request, env) {
  const token = getCookie(request, "tinni_owner_session");
  if (!token || !env.SESSION_SECRET) return null;

  const dot = token.lastIndexOf(".");
  if (dot <= 0) return null;

  const encoded = token.slice(0, dot);
  const signature = token.slice(dot + 1);
  const expected = await hmacBytes(encoded, env.SESSION_SECRET);

  let actual;
  try {
    actual = fromBase64Url(signature);
  } catch {
    return null;
  }
  if (!safeEqualBytes(expected, actual)) return null;

  try {
    const payload = JSON.parse(decoder.decode(fromBase64Url(encoded)));
    if (Number(payload.exp) <= Date.now()) return null;
    if (payload.role === "owner") {
      if (!env.OWNER_EMAIL) return null;
      if (String(payload.email).toLowerCase() !== String(env.OWNER_EMAIL).trim().toLowerCase()) return null;
      return payload;
    }
    if (payload.role === "staff") {
      const store = getStaffStore(env);
      const staff = await store.getStaff(String(payload.email || ""));
      if (!staff || !staff.enabled) return null;
      if (Number(payload.authVersion || 1) !== Number(staff.auth_version || 1)) return null;
      return {
        ...payload,
        panelId: staff.id,
        panelName: staff.name,
        permissions: staff.permissions,
      };
    }
    return null;
  } catch {
    return null;
  }
}

function getStaffStore(env) {
  const id = env.STAFF_AUTH.idFromName("tinni-owner-staff-auth");
  return env.STAFF_AUTH.get(id);
}

function getFruitGameStore(env) {
  const id = env.FRUIT_GAME.idFromName("tinni-fruit-game-global");
  return env.FRUIT_GAME.get(id);
}

function getRoomPresenceStore(env, roomId) {
  const id = env.ROOM_PRESENCE.idFromName(String(roomId));
  return env.ROOM_PRESENCE.get(id);
}

function getAppDirectoryStore(env) {
  const id = env.APP_DIRECTORY.idFromName("tinni-app-directory");
  return env.APP_DIRECTORY.get(id);
}

function isPublicAsset(pathname) {
  return pathname === "/login" ||
    pathname === "/login.html" ||
    pathname === "/login.css" ||
    pathname === "/login.js";
}

async function serveLogin(request, env) {
  const url = new URL(request.url);
  url.pathname = "/login.html";
  return env.ASSETS.fetch(new Request(url, request));
}


function sessionCookie(value, maxAge = 43200) {
  return "tinni_owner_session=" + value +
    "; Path=/; Max-Age=" + maxAge +
    "; HttpOnly; Secure; SameSite=Strict";
}

function ownerOnly(session) {
  return session?.role === "owner";
}

function normalizePermissions(value) {
  const list = Array.isArray(value) ? value : [];
  return [...new Set(list.map(String).filter((item) => STAFF_PERMISSIONS.has(item)))];
}

async function derivePassword(password, saltBytes) {
  const material = await crypto.subtle.importKey(
    "raw",
    encoder.encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      hash: "SHA-256",
      salt: saltBytes,
      iterations: 210000,
    },
    material,
    256,
  );
  return new Uint8Array(bits);
}

export class StaffAuthStore extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS staff_panels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        assigned_user_id TEXT,
        email TEXT NOT NULL UNIQUE,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        permissions_json TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_staff_panels_email ON staff_panels(email);
    `);
    try {
      this.ctx.storage.sql.exec(
        "ALTER TABLE staff_panels ADD COLUMN auth_version INTEGER NOT NULL DEFAULT 1"
      );
    } catch (error) {
      if (!String(error?.message || "").toLowerCase().includes("duplicate")) {
        throw error;
      }
    }
  }

  async createPanel(input) {
    const name = String(input?.name || "").trim();
    const assignedUserId = String(input?.assigned_user_id || "").trim();
    const email = String(input?.staff_email || "").trim().toLowerCase();
    const password = String(input?.password || "");
    const permissions = normalizePermissions(input?.permissions);

    if (!name) throw new Error("Panel name is required");
    if (!email || !email.includes("@")) throw new Error("Valid staff email is required");
    if (password.length < 10) throw new Error("Staff password must be at least 10 characters");
    if (permissions.length === 0) throw new Error("Select at least one staff permission");

    const salt = crypto.getRandomValues(new Uint8Array(16));
    const hash = await derivePassword(password, salt);
    const id = crypto.randomUUID();
    const now = Date.now();

    try {
      this.ctx.storage.sql.exec(
        `INSERT INTO staff_panels
          (id, name, assigned_user_id, email, password_salt, password_hash, permissions_json, enabled, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)`,
        id,
        name,
        assignedUserId || null,
        email,
        toBase64Url(salt),
        toBase64Url(hash),
        JSON.stringify(permissions),
        now,
        now,
      );
    } catch (error) {
      if (String(error?.message || "").toLowerCase().includes("unique")) {
        throw new Error("This staff email already has a panel login");
      }
      throw error;
    }

    return {
      id,
      name,
      assigned_user_id: assignedUserId,
      email,
      permissions,
      enabled: true,
      created_at: now,
    };
  }

  async verifyCredentials(emailValue, passwordValue) {
    const email = String(emailValue || "").trim().toLowerCase();
    const password = String(passwordValue || "");
    if (!email || !password) return null;

    const rows = this.ctx.storage.sql.exec(
      `SELECT id, name, assigned_user_id, email, password_salt, password_hash,
              permissions_json, enabled, auth_version, created_at
         FROM staff_panels
        WHERE email = ?
        LIMIT 1`,
      email,
    ).toArray();

    const row = rows[0];
    if (!row || Number(row.enabled) !== 1) return null;

    const salt = fromBase64Url(String(row.password_salt));
    const expected = fromBase64Url(String(row.password_hash));
    const actual = await derivePassword(password, salt);
    if (!safeEqualBytes(expected, actual)) return null;

    return {
      id: String(row.id),
      name: String(row.name),
      assigned_user_id: row.assigned_user_id ? String(row.assigned_user_id) : "",
      email: String(row.email),
      permissions: JSON.parse(String(row.permissions_json || "[]")),
      enabled: true,
      auth_version: Number(row.auth_version || 1),
      created_at: Number(row.created_at),
    };
  }

  async getStaff(emailValue) {
    const email = String(emailValue || "").trim().toLowerCase();
    const rows = this.ctx.storage.sql.exec(
      `SELECT id, name, assigned_user_id, email, permissions_json, enabled, auth_version, created_at
         FROM staff_panels
        WHERE email = ?
        LIMIT 1`,
      email,
    ).toArray();
    const row = rows[0];
    if (!row) return null;
    return {
      id: String(row.id),
      name: String(row.name),
      assigned_user_id: row.assigned_user_id ? String(row.assigned_user_id) : "",
      email: String(row.email),
      permissions: JSON.parse(String(row.permissions_json || "[]")),
      enabled: Number(row.enabled) === 1,
      auth_version: Number(row.auth_version || 1),
      created_at: Number(row.created_at),
    };
  }

  async listPanels() {
    return this.ctx.storage.sql.exec(
      `SELECT id, name, assigned_user_id, email, permissions_json, enabled, auth_version, created_at
         FROM staff_panels
        ORDER BY created_at DESC`,
    ).toArray().map((row) => ({
      id: String(row.id),
      name: String(row.name),
      assigned_user_id: row.assigned_user_id ? String(row.assigned_user_id) : "",
      email: String(row.email),
      permissions: JSON.parse(String(row.permissions_json || "[]")),
      enabled: Number(row.enabled) === 1,
      auth_version: Number(row.auth_version || 1),
      created_at: Number(row.created_at),
    }));
  }

  async updatePanelAccess(panelIdValue, input) {
    const panelId = String(panelIdValue || "").trim();
    if (!panelId) throw new Error("Panel ID is required");

    const rows = this.ctx.storage.sql.exec(
      `SELECT id, email, password_salt, password_hash, permissions_json, enabled,
              auth_version
         FROM staff_panels
        WHERE id = ?
        LIMIT 1`,
      panelId,
    ).toArray();
    const current = rows[0];
    if (!current) throw new Error("Staff panel not found");

    const permissions = input?.permissions === undefined
      ? JSON.parse(String(current.permissions_json || "[]"))
      : normalizePermissions(input.permissions);
    const enabled = input?.enabled === undefined
      ? Number(current.enabled) === 1
      : Boolean(input.enabled);

    if (enabled && permissions.length === 0) {
      throw new Error("Active staff panel must have at least one permission");
    }

    const nextEmail = input?.staff_email === undefined
      ? String(current.email)
      : String(input.staff_email || "").trim().toLowerCase();
    if (!nextEmail || !nextEmail.includes("@")) {
      throw new Error("Valid staff email is required");
    }

    const newPassword = input?.password === undefined ? "" : String(input.password || "");
    if (newPassword && newPassword.length < 10) {
      throw new Error("Staff password must be at least 10 characters");
    }

    let passwordSalt = String(current.password_salt);
    let passwordHash = String(current.password_hash);
    let authVersion = Number(current.auth_version || 1);

    const emailChanged = nextEmail !== String(current.email).toLowerCase();
    if (newPassword) {
      const salt = crypto.getRandomValues(new Uint8Array(16));
      const hash = await derivePassword(newPassword, salt);
      passwordSalt = toBase64Url(salt);
      passwordHash = toBase64Url(hash);
    }

    if (emailChanged || newPassword) {
      authVersion += 1;
    }

    try {
      this.ctx.storage.sql.exec(
        `UPDATE staff_panels
            SET email = ?, password_salt = ?, password_hash = ?,
                permissions_json = ?, enabled = ?, auth_version = ?, updated_at = ?
          WHERE id = ?`,
        nextEmail,
        passwordSalt,
        passwordHash,
        JSON.stringify(permissions),
        enabled ? 1 : 0,
        authVersion,
        Date.now(),
        panelId,
      );
    } catch (error) {
      if (String(error?.message || "").toLowerCase().includes("unique")) {
        throw new Error("This staff email is already in use");
      }
      throw error;
    }

    const updated = this.ctx.storage.sql.exec(
      `SELECT id, name, assigned_user_id, email, permissions_json, enabled,
              auth_version, created_at
         FROM staff_panels
        WHERE id = ?
        LIMIT 1`,
      panelId,
    ).toArray()[0];

    return {
      id: String(updated.id),
      name: String(updated.name),
      assigned_user_id: updated.assigned_user_id ? String(updated.assigned_user_id) : "",
      email: String(updated.email),
      permissions: JSON.parse(String(updated.permissions_json || "[]")),
      enabled: Number(updated.enabled) === 1,
      auth_version: Number(updated.auth_version || 1),
      created_at: Number(updated.created_at),
    };
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({
        ok: true,
        service: "tinni-star-api",
        message: "Tinni Star API online",
        version: "1.2.0",
      });
    }

    if (url.pathname === "/app-config" && request.method === "GET") {
      return json({
        ok: true,
        google_server_client_id: env.GOOGLE_SERVER_CLIENT_ID || null,
        facebook_configured: Boolean(env.FACEBOOK_APP_ID && env.FACEBOOK_APP_SECRET),
        email_otp_configured: Boolean(env.RESEND_API_KEY && env.EMAIL_FROM),
      });
    }

    if (url.pathname === "/app-auth/google" && request.method === "POST") {
      if (!env.SESSION_SECRET) {
        return json({ ok: false, error: "App session secret is not configured" }, 503);
      }
      const body = await request.json().catch(() => ({}));
      try {
        const google = await verifyGoogleIdToken(body.id_token, env);
        if (!google.sub || !google.email) {
          throw new Error("Google account identity is incomplete");
        }

        const store = getAppDirectoryStore(env);
        let user = await store.getUserByGoogleSub(google.sub);
        if (!user && google.email) {
          const emailUser = await store.getUserByEmail(google.email);
          if (emailUser) {
            user = await store.linkIdentity(emailUser.user_id, "google", google.sub);
          }
        }
        const profile = body.profile && typeof body.profile === "object"
          ? body.profile
          : null;

        if (!user && !profile) {
          return json({
            ok: false,
            profile_required: true,
            google: {
              email: google.email,
              display_name: google.name,
              photo_url: google.picture,
            },
          }, 428);
        }

        if (!user) {
          user = await store.createUser({
            auth_provider: "google",
            auth_subject: google.sub,
            google_sub: google.sub,
            email: google.email,
            display_name: profile.display_name,
            age: profile.age,
            signature: profile.signature,
            country_code: profile.country_code,
            country_name: profile.country_name,
            flag_emoji: profile.flag_emoji,
            gender: profile.gender,
            avatar_data_url: profile.avatar_data_url,
          });
        }

        const token = await createAppUserSession(user, env, "google", google.sub);

        return json({
          ok: true,
          token,
          user: { ...user, auth_provider: "google" },
        });
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Google login failed"),
        }, 400);
      }
    }

    if (url.pathname === "/app-auth/facebook/start" && request.method === "POST") {
      if (!env.SESSION_SECRET) {
        return json({ ok: false, error: "App session secret is not configured" }, 503);
      }
      if (!env.FACEBOOK_APP_ID || !env.FACEBOOK_APP_SECRET) {
        return json({ ok: false, error: "Facebook login is not configured yet" }, 503);
      }

      const store = getAppDirectoryStore(env);
      const pending = await store.startFacebookLogin();
      const callbackUrl = new URL("/app-auth/facebook/callback", env.PUBLIC_API_ORIGIN || request.url).toString();
      const authUrl = new URL("https://www.facebook.com/dialog/oauth");
      authUrl.searchParams.set("client_id", String(env.FACEBOOK_APP_ID));
      authUrl.searchParams.set("redirect_uri", callbackUrl);
      authUrl.searchParams.set("state", pending.request_id);
      authUrl.searchParams.set("scope", "public_profile,email");
      authUrl.searchParams.set("response_type", "code");

      return json({
        ok: true,
        request_id: pending.request_id,
        auth_url: authUrl.toString(),
      }, 201);
    }

    if (url.pathname === "/app-auth/facebook/callback" && request.method === "GET") {
      const requestId = String(url.searchParams.get("state") || "").trim();
      const code = String(url.searchParams.get("code") || "").trim();
      const oauthError = String(
        url.searchParams.get("error_description") ||
        url.searchParams.get("error_message") ||
        url.searchParams.get("error") ||
        ""
      ).trim();
      const store = getAppDirectoryStore(env);
      const pending = await store.getFacebookLogin(requestId);

      if (!pending || pending.status !== "pending") {
        return new Response(
          "<!doctype html><meta name='viewport' content='width=device-width'><body style='font-family:sans-serif;background:#080604;color:#fff3c4;padding:32px'><h2>Tinni Star</h2><p>This Facebook login request is invalid or expired.</p></body>",
          { status: 400, headers: { "content-type": "text/html; charset=utf-8" } },
        );
      }

      if (oauthError || !code) {
        await store.failFacebookLogin(requestId, oauthError || "Facebook login was cancelled");
        return new Response(
          "<!doctype html><meta name='viewport' content='width=device-width'><body style='font-family:sans-serif;background:#080604;color:#fff3c4;padding:32px'><h2>Tinni Star</h2><p>Facebook login was cancelled. You can return to the app.</p></body>",
          { status: 200, headers: { "content-type": "text/html; charset=utf-8" } },
        );
      }

      try {
        const callbackUrl = new URL("/app-auth/facebook/callback", env.PUBLIC_API_ORIGIN || request.url).toString();
        const tokenUrl = new URL("https://graph.facebook.com/oauth/access_token");
        tokenUrl.searchParams.set("client_id", String(env.FACEBOOK_APP_ID));
        tokenUrl.searchParams.set("client_secret", String(env.FACEBOOK_APP_SECRET));
        tokenUrl.searchParams.set("redirect_uri", callbackUrl);
        tokenUrl.searchParams.set("code", code);

        const tokenResponse = await fetch(tokenUrl.toString(), {
          headers: { "cache-control": "no-store" },
        });
        const tokenData = await tokenResponse.json();
        if (!tokenResponse.ok || !tokenData.access_token) {
          throw new Error("Facebook token exchange failed");
        }

        const profileUrl = new URL("https://graph.facebook.com/me");
        profileUrl.searchParams.set("fields", "id,name,email,picture.type(large)");
        profileUrl.searchParams.set("access_token", String(tokenData.access_token));
        const profileResponse = await fetch(profileUrl.toString(), {
          headers: { "cache-control": "no-store" },
        });
        const facebook = await profileResponse.json();
        if (!profileResponse.ok || !facebook.id) {
          throw new Error("Facebook profile verification failed");
        }

        await store.completeFacebookLogin(requestId, {
          id: facebook.id,
          email: facebook.email || "",
          name: facebook.name || "Facebook User",
          picture: facebook.picture?.data?.url || "",
        });

        return new Response(
          "<!doctype html><meta name='viewport' content='width=device-width'><body style='font-family:sans-serif;background:#080604;color:#fff3c4;padding:32px'><h2>Tinni Star</h2><p>Facebook login complete. Return to the Tinni Star app.</p></body>",
          { status: 200, headers: { "content-type": "text/html; charset=utf-8" } },
        );
      } catch (error) {
        await store.failFacebookLogin(
          requestId,
          String(error?.message || "Facebook login failed"),
        );
        return new Response(
          "<!doctype html><meta name='viewport' content='width=device-width'><body style='font-family:sans-serif;background:#080604;color:#fff3c4;padding:32px'><h2>Tinni Star</h2><p>Facebook login failed. Return to the app and try again.</p></body>",
          { status: 400, headers: { "content-type": "text/html; charset=utf-8" } },
        );
      }
    }

    if (url.pathname === "/app-auth/facebook/status" && request.method === "GET") {
      if (!env.SESSION_SECRET) {
        return json({ ok: false, error: "App session secret is not configured" }, 503);
      }
      const requestId = String(url.searchParams.get("request_id") || "").trim();
      const store = getAppDirectoryStore(env);
      const pending = await store.getFacebookLogin(requestId);
      if (!pending) return json({ ok: false, error: "Facebook login request not found" }, 404);
      if (pending.status === "failed" || pending.status === "expired") {
        return json({
          ok: false,
          status: pending.status,
          error: pending.error || "Facebook login expired or failed",
        }, 400);
      }
      if (pending.status !== "authorized") {
        return json({ ok: true, status: "pending" });
      }

      let user = await store.getUserByProvider("facebook", pending.facebook_id);
      if (user) {
        const token = await createAppUserSession(
          user,
          env,
          "facebook",
          pending.facebook_id,
        );
        return json({
          ok: true,
          status: "complete",
          token,
          user: { ...user, auth_provider: "facebook" },
        });
      }

      return json({
        ok: true,
        status: "profile_required",
        request_id: pending.request_id,
        provider: {
          type: "facebook",
          email: pending.email || "",
          display_name: pending.display_name || "",
          photo_url: pending.picture_url || null,
        },
      });
    }

    if (url.pathname === "/app-auth/facebook/complete" && request.method === "POST") {
      if (!env.SESSION_SECRET) {
        return json({ ok: false, error: "App session secret is not configured" }, 503);
      }
      const body = await request.json().catch(() => ({}));
      const requestId = String(body.request_id || "").trim();
      const profile = body.profile && typeof body.profile === "object"
        ? body.profile
        : null;
      const store = getAppDirectoryStore(env);
      const pending = await store.getFacebookLogin(requestId);

      if (!pending || pending.status !== "authorized" || !pending.facebook_id) {
        return json({ ok: false, error: "Facebook login request is not ready" }, 400);
      }
      if (!profile) {
        return json({ ok: false, error: "Profile details are required" }, 400);
      }

      try {
        let user = await store.getUserByProvider("facebook", pending.facebook_id);
        if (!user && pending.email) {
          const emailUser = await store.getUserByEmail(pending.email);
          if (emailUser) {
            user = await store.linkIdentity(
              emailUser.user_id,
              "facebook",
              pending.facebook_id,
            );
          }
        }
        if (!user) {
          const email = pending.email ||
            ("facebook-" + pending.facebook_id + "@tinni.invalid");
          user = await store.createUser({
            auth_provider: "facebook",
            auth_subject: pending.facebook_id,
            email,
            display_name: profile.display_name,
            age: profile.age,
            signature: profile.signature,
            country_code: profile.country_code,
            country_name: profile.country_name,
            flag_emoji: profile.flag_emoji,
            gender: profile.gender,
            avatar_data_url: profile.avatar_data_url,
          });
        }

        const token = await createAppUserSession(
          user,
          env,
          "facebook",
          pending.facebook_id,
        );
        return json({
          ok: true,
          token,
          user: { ...user, auth_provider: "facebook" },
        });
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to create Facebook user"),
        }, 400);
      }
    }

    if (url.pathname === "/app-auth/email/start" && request.method === "POST") {
      if (!env.SESSION_SECRET) {
        return json({ ok: false, error: "App session secret is not configured" }, 503);
      }
      if (!env.RESEND_API_KEY || !env.EMAIL_FROM) {
        return json({ ok: false, error: "Email OTP service is not configured yet" }, 503);
      }

      const body = await request.json().catch(() => ({}));
      const store = getAppDirectoryStore(env);
      try {
        const pending = await store.startEmailOtp(body.email);
        await sendEmailOtp(pending.email, pending.otp, env);
        return json({
          ok: true,
          request_id: pending.request_id,
          email: pending.email,
          expires_at: pending.expires_at,
        }, 201);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to send email OTP"),
        }, 400);
      }
    }

    if (url.pathname === "/app-auth/email/verify" && request.method === "POST") {
      if (!env.SESSION_SECRET) {
        return json({ ok: false, error: "App session secret is not configured" }, 503);
      }

      const body = await request.json().catch(() => ({}));
      const store = getAppDirectoryStore(env);
      try {
        const verified = await store.verifyEmailOtp(body.request_id, body.otp);
        const setupToken = await createSession(
          {
            role: "email_setup",
            requestId: String(body.request_id || ""),
            email: verified.email,
          },
          env.SESSION_SECRET,
          10 * 60 * 1000,
        );
        return json({
          ok: true,
          setup_token: setupToken,
          email: verified.email,
          profile_required: verified.profile_required,
        });
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "OTP verification failed"),
        }, 400);
      }
    }

    if (url.pathname === "/app-auth/email/complete" && request.method === "POST") {
      if (!env.SESSION_SECRET) {
        return json({ ok: false, error: "App session secret is not configured" }, 503);
      }

      const body = await request.json().catch(() => ({}));
      const setup = await parseSignedSession(
        String(body.setup_token || ""),
        env.SESSION_SECRET,
      );
      if (
        !setup ||
        setup.role !== "email_setup" ||
        !setup.requestId ||
        !setup.email
      ) {
        return json({ ok: false, error: "Email verification session expired" }, 401);
      }

      const profile = body.profile && typeof body.profile === "object"
        ? body.profile
        : null;
      const store = getAppDirectoryStore(env);
      try {
        const completed = await store.completeEmailPassword(
          setup.requestId,
          body.password,
          profile,
        );
        if (String(completed.email) !== String(setup.email).toLowerCase()) {
          throw new Error("Verified email does not match");
        }

        const token = await createAppUserSession(
          completed.user,
          env,
          "email",
          completed.email,
          completed.auth_version,
        );
        return json({
          ok: true,
          token,
          user: { ...completed.user, auth_provider: "email" },
        });
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to save Tinni password"),
        }, 400);
      }
    }

    if (url.pathname === "/app-auth/email/login" && request.method === "POST") {
      if (!env.SESSION_SECRET) {
        return json({ ok: false, error: "App session secret is not configured" }, 503);
      }

      const body = await request.json().catch(() => ({}));
      const store = getAppDirectoryStore(env);
      const verified = await store.verifyEmailPassword(body.email, body.password);
      if (!verified) {
        return json({ ok: false, error: "Invalid email or Tinni password" }, 401);
      }

      const token = await createAppUserSession(
        verified.user,
        env,
        "email",
        verified.email,
        verified.auth_version,
      );
      return json({
        ok: true,
        token,
        user: { ...verified.user, auth_provider: "email" },
      });
    }

    if (url.pathname === "/app/me" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, user: appSession.user });
    }

    if (url.pathname === "/livekit/token" && request.method === "POST") {
      if (!env.LIVEKIT_URL || !env.LIVEKIT_API_KEY || !env.LIVEKIT_API_SECRET) {
        return json({
          ok: false,
          error: "LiveKit is not configured on the server",
        }, 503);
      }

      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);

      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      if (!roomId) {
        return json({ ok: false, error: "room_id is required" }, 400);
      }

      const rooms = await getAppDirectoryStore(env).listRooms();
      const room = rooms.find(
        (item) => String(item.id || item.room_id || "") === roomId,
      );
      if (!room) {
        return json({ ok: false, error: "Room not found" }, 404);
      }

      const kick = getRoomPresenceStore(env, roomId).kickStatus(
        appSession.user.user_id,
      );
      if (kick) {
        return json({
          ok: false,
          error: "You are kicked from this room.",
          kick_expires_at: kick.expires_at,
          permanent: kick.permanent,
        }, 403);
      }

      const token = await createLiveKitAccessToken({
        apiKey: env.LIVEKIT_API_KEY,
        apiSecret: env.LIVEKIT_API_SECRET,
        roomId,
        userId: appSession.user.user_id,
        displayName: appSession.user.display_name,
      });

      return json({
        ok: true,
        server_url: String(env.LIVEKIT_URL),
        token,
        room_id: roomId,
        user_id: appSession.user.user_id,
        expires_in: 3600,
      });
    }

    if (url.pathname === "/rooms" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const rooms = await getAppDirectoryStore(env).listRooms();
      return json({ ok: true, rooms });
    }

    if (url.pathname === "/rooms" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        const room = await getAppDirectoryStore(env).createRoom(
          appSession.user.user_id,
          body,
        );
        return json({ ok: true, room }, 201);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to create room"),
        }, 400);
      }
    }

    if (url.pathname === "/fruit-game/state" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const state = await getFruitGameStore(env).state(appSession.user.user_id);
      return json(state);
    }

    if (url.pathname === "/fruit-game/bet" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        const state = await getFruitGameStore(env).placeBet({
          ...body,
          user_id: appSession.user.user_id,
        });
        return json(state, 201);
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to place bet") }, 400);
      }
    }

    if (url.pathname === "/room-presence/state" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const roomId = String(url.searchParams.get("room_id") || "").trim();
      if (!roomId) return json({ ok: false, error: "room_id is required" }, 400);
      return json(await getRoomPresenceStore(env, roomId).state());
    }

    if (url.pathname === "/room-presence/admin" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const targetUserId = String(body.target_user_id || "").trim();
      if (!roomId || !targetUserId) {
        return json({ ok: false, error: "room_id and target_user_id are required" }, 400);
      }

      const rooms = await getAppDirectoryStore(env).listRooms();
      const room = rooms.find(
        (item) => String(item.id || item.room_id || "") === roomId,
      );
      if (!room) return json({ ok: false, error: "Room not found" }, 404);
      if (String(room.owner_id) !== String(appSession.user.user_id)) {
        return json({ ok: false, error: "Only the room owner can manage admins" }, 403);
      }

      const store = getRoomPresenceStore(env, roomId);
      return json(store.setManager(targetUserId, Boolean(body.enabled)));
    }

    if (url.pathname === "/room-presence/mute" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const targetUserId = String(body.target_user_id || "").trim();
      const seatIndex = Number(body.seat_index);
      const muted = Boolean(body.muted);
      if (!roomId || !targetUserId || !Number.isInteger(seatIndex) || seatIndex < 0) {
        return json({
          ok: false,
          error: "room_id, target_user_id and seat_index are required",
        }, 400);
      }

      const rooms = await getAppDirectoryStore(env).listRooms();
      const room = rooms.find(
        (item) => String(item.id || item.room_id || "") === roomId,
      );
      if (!room) return json({ ok: false, error: "Room not found" }, 404);

      const store = getRoomPresenceStore(env, roomId);
      const actorId = String(appSession.user.user_id);
      const canModerate =
        String(room.owner_id) === actorId || store.isManager(actorId);
      if (!canModerate) {
        return json({ ok: false, error: "Only room owner/admin can mute users" }, 403);
      }
      if (String(room.owner_id) === targetUserId) {
        return json({ ok: false, error: "Room owner cannot be muted" }, 400);
      }

      try {
        return json(store.setMute({
          target_user_id: targetUserId,
          seat_index: seatIndex,
          muted_by: actorId,
          muted,
        }));
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to update room mute"),
        }, 400);
      }
    }

    if (url.pathname === "/room-presence/kick" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const targetUserId = String(body.target_user_id || "").trim();
      if (!roomId || !targetUserId) {
        return json({ ok: false, error: "room_id and target_user_id are required" }, 400);
      }

      const rooms = await getAppDirectoryStore(env).listRooms();
      const room = rooms.find(
        (item) => String(item.id || item.room_id || "") === roomId,
      );
      if (!room) return json({ ok: false, error: "Room not found" }, 404);

      const store = getRoomPresenceStore(env, roomId);
      const actorId = String(appSession.user.user_id);
      const canModerate =
        String(room.owner_id) === actorId || store.isManager(actorId);
      if (!canModerate) {
        return json({ ok: false, error: "Only room owner/admin can kick users" }, 403);
      }
      if (String(room.owner_id) === targetUserId) {
        return json({ ok: false, error: "Room owner cannot be kicked" }, 400);
      }

      const rawDuration = body.duration_ms;
      let durationMs = null;
      if (rawDuration !== null && rawDuration !== undefined) {
        durationMs = Number(rawDuration);
        const allowed = new Set([
          2 * 60 * 60 * 1000,
          6 * 60 * 60 * 1000,
          24 * 60 * 60 * 1000,
        ]);
        if (!allowed.has(durationMs)) {
          return json({ ok: false, error: "Invalid kick duration" }, 400);
        }
      }

      return json(store.kick({
        target_user_id: targetUserId,
        kicked_by: actorId,
        duration_ms: durationMs,
      }));
    }

    if (
      (url.pathname === "/room-presence/join" ||
       url.pathname === "/room-presence/heartbeat" ||
       url.pathname === "/room-presence/leave") &&
      request.method === "POST"
    ) {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      if (!roomId) return json({ ok: false, error: "room_id is required" }, 400);
      const store = getRoomPresenceStore(env, roomId);
      const user = appSession.user;
      const presenceBody = {
        room_id: roomId,
        user_id: user.user_id,
        display_name: user.display_name,
        avatar_data_url: user.avatar_data_url,
        flag_emoji: user.flag_emoji,
        country_code: user.country_code,
        seat_index:
          body.seat_index === null || body.seat_index === undefined
            ? null
            : Number(body.seat_index),
      };
      try {
        if (url.pathname.endsWith("/join")) {
          return json(await store.join(presenceBody), 201);
        }
        if (url.pathname.endsWith("/heartbeat")) {
          return json(await store.heartbeat(presenceBody));
        }
        return json(await store.leave(presenceBody));
      } catch (error) {
        const message = String(error?.message || "Room presence failed");
        if (message.startsWith("KICKED_FROM_ROOM:")) {
          const value = message.slice("KICKED_FROM_ROOM:".length);
          return json({
            ok: false,
            error: "You are kicked from this room.",
            permanent: value === "permanent",
            kick_expires_at: value === "permanent" ? null : Number(value),
          }, 403);
        }
        return json({ ok: false, error: message }, 400);
      }
    }

    if (url.pathname === "/auth/login" && request.method === "POST") {
      if (!env.SESSION_SECRET) {
        return json({ ok: false, error: "Login session secret is not configured yet" }, 503);
      }

      const body = await request.json().catch(() => ({}));
      const email = String(body.email || "").trim().toLowerCase();
      const password = String(body.password || "");

      const ownerEmail = String(env.OWNER_EMAIL || "").trim().toLowerCase();
      if (ownerEmail && email === ownerEmail) {
        if (!env.OWNER_PASSWORD || password !== env.OWNER_PASSWORD) {
          return json({ ok: false, error: "Invalid email or password" }, 401);
        }
        const session = await createSession(
          { role: "owner", email: env.OWNER_EMAIL, permissions: ["*"] },
          env.SESSION_SECRET,
        );
        return json(
          { ok: true, role: "owner" },
          200,
          { "set-cookie": sessionCookie(session) },
        );
      }

      const staff = await getStaffStore(env).verifyCredentials(email, password);
      if (!staff) {
        return json({ ok: false, error: "Invalid email or password" }, 401);
      }

      const session = await createSession(
        {
          role: "staff",
          email: staff.email,
          panelId: staff.id,
          panelName: staff.name,
          permissions: staff.permissions,
          authVersion: staff.auth_version || 1,
        },
        env.SESSION_SECRET,
      );
      return json(
        { ok: true, role: "staff", panel: staff.name },
        200,
        { "set-cookie": sessionCookie(session) },
      );
    }

    if (url.pathname === "/auth/logout" && request.method === "POST") {
      return json(
        { ok: true },
        200,
        { "set-cookie": sessionCookie("", 0) },
      );
    }

    if (isPublicAsset(url.pathname)) {
      if (url.pathname === "/login") return serveLogin(request, env);
      return env.ASSETS.fetch(request);
    }

    const session = await verifySession(request, env);
    if (!session) {
      if (url.pathname.startsWith("/api/") || url.pathname.startsWith("/auth/")) {
        return json({ ok: false, error: "Unauthorized" }, 401);
      }
      return Response.redirect(new URL("/login", env.PUBLIC_API_ORIGIN || request.url), 302);
    }

    if (url.pathname === "/auth/session" && request.method === "GET") {
      return json({
        ok: true,
        role: session.role,
        email: session.email,
        panelId: session.panelId || null,
        panelName: session.panelName || null,
        permissions: session.permissions || [],
      });
    }

    if (url.pathname === "/api/staff/panels" && request.method === "POST") {
      if (!ownerOnly(session)) return json({ ok: false, error: "Owner access required" }, 403);
      const body = await request.json().catch(() => ({}));
      try {
        const panel = await getStaffStore(env).createPanel(body);
        return json({ ok: true, panel }, 201);
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to create staff panel") }, 400);
      }
    }

    if (url.pathname === "/api/staff/panels" && request.method === "GET") {
      if (!ownerOnly(session)) return json({ ok: false, error: "Owner access required" }, 403);
      const panels = await getStaffStore(env).listPanels();
      return json({ ok: true, panels });
    }

    const staffPanelMatch = url.pathname.match(/^\/api\/staff\/panels\/([^/]+)$/);
    if (staffPanelMatch && request.method === "PATCH") {
      if (!ownerOnly(session)) return json({ ok: false, error: "Owner access required" }, 403);
      const body = await request.json().catch(() => ({}));
      try {
        const panel = await getStaffStore(env).updatePanelAccess(
          decodeURIComponent(staffPanelMatch[1]),
          body,
        );
        return json({ ok: true, panel });
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to update staff panel") }, 400);
      }
    }

    if (url.pathname.startsWith("/api/")) {
      return json({ ok: false, error: "API endpoint not implemented" }, 404);
    }

    return env.ASSETS.fetch(request);
  },
};
