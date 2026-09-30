import { DurableObject } from "cloudflare:workers";
import { FruitGameStore } from "./fruit_game.js";
import { FruitPartyStore } from "./fruit_party.js";
import { RoomPresenceStore } from "./room_presence.js";
import { AppDirectoryStore } from "./app_directory.js";
export { FruitGameStore, FruitPartyStore, RoomPresenceStore, AppDirectoryStore };

const encoder = new TextEncoder();
const decoder = new TextDecoder();

const STAFF_PERMISSIONS = new Set([
  // Legacy whole-module permissions are kept for existing staff panels.
  "users", "rooms", "wallets", "hierarchy", "roles", "vip",
  "gifts", "assets", "banners", "games", "policies", "audit",

  "users.search",
  "users.ban_id",
  "users.ban_device",
  "users.invisible",
  "users.locked_room_bypass",
  "users.change_id",
  "users.unique_id",

  "rooms.search",
  "rooms.ban",
  "rooms.rename",
  "rooms.dp",
  "rooms.background",
  "rooms.live_seats",
  "rooms.theme_view",
  "rooms.theme_create",
  "rooms.theme_remove",

  "wallets.normal",
  "wallets.seller",
  "wallets.merchant",
  "wallets.treasury_send",

  "hierarchy.bd_manage",
  "hierarchy.agency_manage",
  "hierarchy.agency_bd_link",
  "hierarchy.host_manage",
  "hierarchy.targets",
  "hierarchy.complaints",

  "roles.view",
  "roles.manage",

  "vip.view",
  "vip.create",
  "vip.edit",
  "vip.toggle",
  "vip.grant_remove",

  "gifts.view",
  "gifts.create",
  "gifts.edit",
  "gifts.remove",

  "assets.entries",
  "assets.frames",

  "banners.view",
  "banners.create",
  "banners.remove",

  "games.view",
  "games.toggle",
  "games.limits",
  "games.investigate",

  "policies.view",
  "policies.create",
  "policies.edit",
  "policies.pricing",

  "audit.view",
  "audit.export",
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

async function sessionTokenHash(token) {
  const bytes = new TextEncoder().encode(String(token || ""));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return toBase64Url(new Uint8Array(digest));
}

async function verifyAppSession(request, env) {
  const token = bearerToken(request);
  const payload = await parseSignedSession(token, env.SESSION_SECRET);
  if (!payload || payload.role !== "user" || !payload.userId) return null;

  const store = getAppDirectoryStore(env);
  if (await store.isSessionRevoked(await sessionTokenHash(token))) return null;
  const user = await store.getUserById(payload.userId);
  if (!user) return null;
  if (user.controls?.banned || user.controls?.device_banned) return null;

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

function getFruitPartyStore(env) {
  const id = env.FRUIT_PARTY.idFromName("tinni-fruit-party-global");
  return env.FRUIT_PARTY.get(id);
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

function sessionHasPermission(session, permission) {
  if (ownerOnly(session)) return true;
  if (session?.role !== "staff") return false;
  const permissions = new Set(Array.isArray(session.permissions) ? session.permissions : []);
  const group = String(permission || "").split(".")[0];
  return permissions.has(group) || permissions.has(permission);
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

      CREATE TABLE IF NOT EXISTS panel_audit_log (
        id TEXT PRIMARY KEY,
        actor_role TEXT NOT NULL,
        panel_id TEXT,
        panel_name TEXT,
        actor_email TEXT,
        action TEXT NOT NULL,
        target_type TEXT,
        target_id TEXT,
        details_json TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_panel_audit_panel_time
        ON panel_audit_log(panel_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_panel_audit_time
        ON panel_audit_log(created_at DESC);

      CREATE TABLE IF NOT EXISTS owner_notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        source_user_id TEXT,
        source_display_name TEXT,
        target_type TEXT,
        target_id TEXT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        metadata_json TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_owner_notifications_time
        ON owner_notifications(created_at DESC);
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

  async recordAudit(input) {
    const id = crypto.randomUUID();
    const createdAt = Date.now();
    const actorRole = String(input?.actor_role || "staff");
    const panelId = input?.panel_id ? String(input.panel_id) : null;
    const panelName = input?.panel_name ? String(input.panel_name) : null;
    const actorEmail = input?.actor_email ? String(input.actor_email) : null;
    const action = String(input?.action || "").trim();
    const targetType = input?.target_type ? String(input.target_type) : null;
    const targetId = input?.target_id ? String(input.target_id) : null;
    if (!action) throw new Error("Audit action is required");

    this.ctx.storage.sql.exec(
      `INSERT INTO panel_audit_log
        (id, actor_role, panel_id, panel_name, actor_email, action, target_type, target_id, details_json, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      id,
      actorRole,
      panelId,
      panelName,
      actorEmail,
      action,
      targetType,
      targetId,
      JSON.stringify(input?.details || {}),
      createdAt,
    );

    return { id, created_at: createdAt };
  }

  async listAudit(input = {}) {
    const panelId = input?.panel_id ? String(input.panel_id) : "";
    const rawLimit = Number(input?.limit || 250);
    const limit = Math.min(500, Math.max(1, Number.isFinite(rawLimit) ? rawLimit : 250));
    const rows = panelId
      ? this.ctx.storage.sql.exec(
          `SELECT id, actor_role, panel_id, panel_name, actor_email, action,
                  target_type, target_id, details_json, created_at
             FROM panel_audit_log
            WHERE panel_id = ?
            ORDER BY created_at DESC
            LIMIT ?`,
          panelId,
          limit,
        ).toArray()
      : this.ctx.storage.sql.exec(
          `SELECT id, actor_role, panel_id, panel_name, actor_email, action,
                  target_type, target_id, details_json, created_at
             FROM panel_audit_log
            ORDER BY created_at DESC
            LIMIT ?`,
          limit,
        ).toArray();

    return rows.map((row) => ({
      id: String(row.id),
      actor_role: String(row.actor_role),
      panel_id: row.panel_id ? String(row.panel_id) : null,
      panel_name: row.panel_name ? String(row.panel_name) : null,
      actor_email: row.actor_email ? String(row.actor_email) : null,
      action: String(row.action),
      target_type: row.target_type ? String(row.target_type) : null,
      target_id: row.target_id ? String(row.target_id) : null,
      details: JSON.parse(String(row.details_json || "{}")),
      created_at: Number(row.created_at),
    }));
  }

  async auditSummary(input = {}) {
    const panelId = input?.panel_id ? String(input.panel_id) : "";
    const byPanel = panelId
      ? this.ctx.storage.sql.exec(
          `SELECT panel_id, panel_name, actor_role, COUNT(*) AS total_actions
             FROM panel_audit_log
            WHERE panel_id = ?
            GROUP BY panel_id, panel_name, actor_role
            ORDER BY total_actions DESC`,
          panelId,
        ).toArray()
      : this.ctx.storage.sql.exec(
          `SELECT panel_id, panel_name, actor_role, COUNT(*) AS total_actions
             FROM panel_audit_log
            GROUP BY panel_id, panel_name, actor_role
            ORDER BY total_actions DESC`,
        ).toArray();

    const byAction = panelId
      ? this.ctx.storage.sql.exec(
          `SELECT action, COUNT(*) AS count
             FROM panel_audit_log
            WHERE panel_id = ?
            GROUP BY action
            ORDER BY count DESC`,
          panelId,
        ).toArray()
      : this.ctx.storage.sql.exec(
          `SELECT action, COUNT(*) AS count
             FROM panel_audit_log
            GROUP BY action
            ORDER BY count DESC`,
        ).toArray();

    return {
      by_panel: byPanel.map((row) => ({
        panel_id: row.panel_id ? String(row.panel_id) : null,
        panel_name: row.panel_name ? String(row.panel_name) : null,
        actor_role: String(row.actor_role),
        total_actions: Number(row.total_actions || 0),
      })),
      by_action: byAction.map((row) => ({
        action: String(row.action),
        count: Number(row.count || 0),
      })),
    };
  }

  async deleteAudit(idValue) {
    const id = String(idValue || "").trim();
    if (!id) throw new Error("Audit record ID is required");
    this.ctx.storage.sql.exec("DELETE FROM panel_audit_log WHERE id = ?", id);
    return { ok: true };
  }

  async clearAudit(panelIdValue = "") {
    const panelId = String(panelIdValue || "").trim();
    if (panelId) {
      this.ctx.storage.sql.exec("DELETE FROM panel_audit_log WHERE panel_id = ?", panelId);
    } else {
      this.ctx.storage.sql.exec("DELETE FROM panel_audit_log");
    }
    return { ok: true };
  }

  async createOwnerNotification(input) {
    const id = crypto.randomUUID();
    const createdAt = Date.now();
    const type = String(input?.type || "general");
    const title = String(input?.title || "Notification").trim();
    const message = String(input?.message || "").trim();
    if (!message) throw new Error("Notification message is required");

    this.ctx.storage.sql.exec(
      `INSERT INTO owner_notifications
        (id, type, source_user_id, source_display_name, target_type, target_id,
         title, message, metadata_json, is_read, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)`,
      id,
      type,
      input?.source_user_id ? String(input.source_user_id) : null,
      input?.source_display_name ? String(input.source_display_name) : null,
      input?.target_type ? String(input.target_type) : null,
      input?.target_id ? String(input.target_id) : null,
      title,
      message,
      JSON.stringify(input?.metadata || {}),
      createdAt,
    );

    return { id, created_at: createdAt };
  }

  async listOwnerNotifications(input = {}) {
    const rawLimit = Number(input?.limit || 200);
    const limit = Math.min(500, Math.max(1, Number.isFinite(rawLimit) ? rawLimit : 200));
    return this.ctx.storage.sql.exec(
      `SELECT id, type, source_user_id, source_display_name, target_type, target_id,
              title, message, metadata_json, is_read, created_at
         FROM owner_notifications
        ORDER BY created_at DESC
        LIMIT ?`,
      limit,
    ).toArray().map((row) => ({
      id: String(row.id),
      type: String(row.type),
      source_user_id: row.source_user_id ? String(row.source_user_id) : null,
      source_display_name: row.source_display_name ? String(row.source_display_name) : null,
      target_type: row.target_type ? String(row.target_type) : null,
      target_id: row.target_id ? String(row.target_id) : null,
      title: String(row.title),
      message: String(row.message),
      metadata: JSON.parse(String(row.metadata_json || "{}")),
      is_read: Number(row.is_read) === 1,
      created_at: Number(row.created_at),
    }));
  }

  async markOwnerNotificationRead(idValue, isReadValue = true) {
    const id = String(idValue || "").trim();
    if (!id) throw new Error("Notification ID is required");
    this.ctx.storage.sql.exec(
      "UPDATE owner_notifications SET is_read = ? WHERE id = ?",
      isReadValue ? 1 : 0,
      id,
    );
    return { ok: true };
  }

  async deleteOwnerNotification(idValue) {
    const id = String(idValue || "").trim();
    if (!id) throw new Error("Notification ID is required");
    this.ctx.storage.sql.exec("DELETE FROM owner_notifications WHERE id = ?", id);
    return { ok: true };
  }
}

function auditActor(session) {
  if (ownerOnly(session)) {
    return {
      actor_role: "owner",
      panel_id: "owner-main",
      panel_name: "Owner Main Panel",
      actor_email: String(session?.email || ""),
    };
  }
  return {
    actor_role: "staff",
    panel_id: String(session?.panelId || ""),
    panel_name: String(session?.panelName || "Staff Panel"),
    actor_email: String(session?.email || ""),
  };
}

async function writeAudit(env, session, action, targetType = null, targetId = null, details = {}) {
  return getStaffStore(env).recordAudit({
    ...auditActor(session),
    action,
    target_type: targetType,
    target_id: targetId,
    details,
  });
}


function publicLegalPage(title, bodyHtml) {
  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${title} - Tinni Star</title>
  <style>
    body{margin:0;background:#09051a;color:#f6f1ff;font-family:Arial,sans-serif;line-height:1.6}
    main{max-width:820px;margin:auto;padding:32px 20px 56px}
    h1,h2{color:#ffd85a} a{color:#d5a8ff} .card{background:#15102c;border:1px solid #3a2866;border-radius:18px;padding:24px}
    .muted{color:#c4bbd8;font-size:14px}
  </style>
</head>
<body><main><div class="card"><h1>${title}</h1>${bodyHtml}</div></main></body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
    },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);


    if (url.pathname === "/privacy" && request.method === "GET") {
      return publicLegalPage("Privacy Policy", `
        <p class="muted">Effective: 27 September 2026</p>
        <p>Tinni Star is a social voice-room application. This policy explains how information is handled when you use Tinni Star, including when you sign in with Facebook.</p>
        <h2>Information we may collect</h2>
        <p>When you use Facebook Login, Tinni Star may receive your Facebook user ID, name/public profile information, and email address when Facebook makes it available. We may also process profile details you provide in Tinni Star, app activity needed to provide social and voice-room features, and limited device/network information needed for security, abuse prevention, and service reliability.</p>
        <h2>How information is used</h2>
        <p>Information is used to authenticate you, create and operate your account, provide Tinni Star features, protect users and the service, prevent fraud or abuse, moderate content where necessary, troubleshoot problems, and comply with applicable law.</p>
        <h2>Sharing</h2>
        <p>Tinni Star does not sell personal information. Information may be processed by service providers only where needed to operate the app, or disclosed when required by law or to protect users and the service.</p>
        <h2>Retention and deletion</h2>
        <p>Data is kept only for as long as reasonably necessary for the purposes above, subject to legal and security requirements. You may request deletion using the <a href="/data-deletion">Tinni Star data deletion instructions</a>.</p>
        <h2>Children</h2>
        <p>Tinni Star is not intended for children under 13, or a higher minimum age where local law requires it.</p>
        <h2>Contact</h2>
        <p>Privacy and data-deletion requests may be sent to <a href="mailto:vny.mishra1997@gmail.com">vny.mishra1997@gmail.com</a>.</p>
      `);
    }

    if (url.pathname === "/data-deletion" && request.method === "GET") {
      return publicLegalPage("User Data Deletion", `
        <p>You can request deletion of personal data associated with your Tinni Star account.</p>
        <h2>How to request deletion</h2>
        <ol>
          <li>Send an email to <a href="mailto:vny.mishra1997@gmail.com?subject=Tinni%20Star%20Data%20Deletion%20Request">vny.mishra1997@gmail.com</a> with the subject <strong>Tinni Star Data Deletion Request</strong>.</li>
          <li>Include your Tinni Star user ID and the email address linked to your account so the account can be verified.</li>
          <li>If you used Facebook Login, you may also remove Tinni Star from Facebook's Apps and Websites settings. Removing Facebook access does not by itself guarantee deletion of data already stored by Tinni Star, so send the deletion request above as well.</li>
        </ol>
        <p>After verification, data that is not required to be retained for legal, fraud-prevention, security, or dispute-resolution reasons will be deleted or anonymized. Requests are normally processed within 30 days.</p>
      `);
    }

    if (url.pathname === "/terms" && request.method === "GET") {
      return publicLegalPage("Terms of Service", `
        <p class="muted">Effective: 27 September 2026</p>
        <p>By using Tinni Star, you agree to use the service lawfully and respectfully. You must not use the service for fraud, harassment, illegal activity, impersonation, account theft, or abuse of other users.</p>
        <p>Tinni Star may restrict or suspend accounts when reasonably necessary to protect users, enforce app rules, comply with law, or protect service integrity.</p>
        <p>Features may change as the service develops. These terms do not remove rights that cannot legally be waived under applicable consumer or privacy law.</p>
        <p>Questions may be sent to <a href="mailto:vny.mishra1997@gmail.com">vny.mishra1997@gmail.com</a>.</p>
      `);
    }

    if (url.pathname === "/health") {
      return json({
        ok: true,
        service: "tinni-star-api",
        message: "Tinni Star API online",
        version: "1.5.0",
      });
    }

    if (url.pathname === "/app-config" && request.method === "GET") {
      const ownerState = getAppDirectoryStore(env).ownerState();
      const features = ownerState.features || {};
      const gameConfig = ownerState.game_config || {};
      return json({
        ok: true,
        google_server_client_id: env.GOOGLE_SERVER_CLIENT_ID || null,
        facebook_configured: Boolean(env.FACEBOOK_APP_ID && env.FACEBOOK_APP_SECRET),
        email_otp_configured: Boolean(env.RESEND_API_KEY && env.EMAIL_FROM),
        remote_config: {
          room_recommendation_enabled: true,
          gift_effects_enabled: features.gifts !== false,
          ktv_enabled: features.voice_rooms !== false,
          games_enabled: features.games !== false && gameConfig.enabled !== false,
          voice_rooms_enabled: features.voice_rooms !== false,
          vip_enabled: features.vip !== false,
          host_system_enabled: features.host_system !== false,
          agency_system_enabled: features.agency_system !== false,
          bd_system_enabled: features.bd_system !== false,
          coin_seller_enabled: features.coin_seller !== false,
          merchant_enabled: features.merchant !== false,
          banners_enabled: features.banners !== false,
          vehicle_entries_enabled: features.vehicle_entries !== false,
          frames_enabled: features.frames !== false,
        },
      });
    }

    if (url.pathname.startsWith("/media/") && request.method === "GET") {
      if (!env.EFFECT_MEDIA) {
        return new Response("Media storage is not configured", { status: 503 });
      }
      const key = decodeURIComponent(url.pathname.slice("/media/".length));
      if (!key || key.includes("..")) {
        return new Response("Invalid media key", { status: 400 });
      }
      const object = await env.EFFECT_MEDIA.get(key);
      if (!object) return new Response("Not found", { status: 404 });
      const headers = new Headers();
      object.writeHttpMetadata(headers);
      headers.set("etag", object.httpEtag);
      headers.set("cache-control", "public, max-age=604800, immutable");
      return new Response(object.body, { headers });
    }

    if (url.pathname === "/telemetry/analytics" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(
          await getAppDirectoryStore(env).recordClientAnalytics(
            appSession.user.user_id,
            body,
          ),
          201,
        );
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to record analytics"),
        }, 400);
      }
    }

    if (url.pathname === "/telemetry/crash" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(
          await getAppDirectoryStore(env).recordClientCrash(
            appSession.user.user_id,
            body,
          ),
          201,
        );
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to record crash"),
        }, 400);
      }
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

        const appReturnUrl =
          "tinnistar://auth/facebook-complete?request_id=" +
          encodeURIComponent(requestId);
        return new Response(
          `<!doctype html>
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="refresh" content="0;url=${appReturnUrl}">
<body style="font-family:sans-serif;background:#080604;color:#fff3c4;padding:32px;text-align:center">
  <h2>Tinni Star</h2>
  <p>Facebook login complete. Opening Tinni Star…</p>
  <p><a href="${appReturnUrl}" style="color:#ffd54f">Open Tinni Star</a></p>
  <script>location.replace(${JSON.stringify(appReturnUrl)});</script>
</body>`,
          {
            status: 200,
            headers: {
              "content-type": "text/html; charset=utf-8",
              "cache-control": "no-store",
            },
          },
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

    if (url.pathname === "/app/logout" && request.method === "POST") {
      const token = bearerToken(request);
      const payload = await parseSignedSession(token, env.SESSION_SECRET);
      if (!payload || payload.role !== "user" || !payload.userId) {
        return json({ ok: false, error: "Unauthorized" }, 401);
      }
      await getAppDirectoryStore(env).revokeSession(
        await sessionTokenHash(token),
        Number(payload.exp),
      );
      return json({ ok: true });
    }

    if (url.pathname === "/account/link/email/start" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      if (!env.RESEND_API_KEY || !env.EMAIL_FROM) {
        return json({ ok: false, error: "Email OTP service is not configured yet" }, 503);
      }
      const body = await request.json().catch(() => ({}));
      try {
        const pending = await getAppDirectoryStore(env).startEmailOtp(body.email);
        await sendEmailOtp(pending.email, pending.otp, env);
        return json({
          ok:true,
          request_id:pending.request_id,
          email:pending.email,
          expires_at:pending.expires_at,
        }, 201);
      } catch (error) {
        return json({ ok:false, error:String(error?.message || "Unable to send email OTP") }, 400);
      }
    }

    if (url.pathname === "/account/link/email/verify" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false, error:"Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).bindEmailIdentity(
          appSession.user.user_id,
          body.request_id,
          body.otp,
          body.password,
        ));
      } catch (error) {
        return json({ ok:false, error:String(error?.message || "Unable to bind email") }, 400);
      }
    }

    if (url.pathname === "/account/link/google" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        const google = await verifyGoogleIdToken(body.id_token, env);
        if (!google.sub) throw new Error("Google account identity is incomplete");
        const store = getAppDirectoryStore(env);
        await store.linkIdentity(appSession.user.user_id, "google", google.sub);
        return json({
          ok: true,
          identities: await store.accountIdentities(appSession.user.user_id),
        });
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to bind Google account"),
        }, 400);
      }
    }

    if (url.pathname === "/app/me" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, user: appSession.user });
    }

    if (url.pathname === "/app/profile" && request.method === "PATCH") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        const user = await getAppDirectoryStore(env).updateUserProfile(
          appSession.user.user_id,
          body,
        );
        return json({ ok: true, user });
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to update profile") }, 400);
      }
    }

    if (url.pathname === "/rooms/search" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const roomId = String(url.searchParams.get("id") || "").trim();
      if (!roomId) return json({ ok: true, room: null });
      return json({
        ok: true,
        room: await getAppDirectoryStore(env).findRoomByExactId(roomId),
      });
    }

    if (url.pathname === "/users/search" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const query = String(url.searchParams.get("q") || "").trim();
      if (!query) return json({ ok: true, users: [] });
      return json({
        ok: true,
        users: await getAppDirectoryStore(env).searchUsers(query, 30),
      });
    }

    if (url.pathname === "/social/followers" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const requested = String(url.searchParams.get("user_id") || appSession.user.user_id).trim();
      return json({
        ok: true,
        followers: await getAppDirectoryStore(env).listFollowers(requested),
      });
    }

    if (url.pathname === "/rooms/followed" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        rooms: await getAppDirectoryStore(env).listFollowedOnlineRooms(appSession.user.user_id),
      });
    }

    if (url.pathname === "/rooms/recent" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        rooms: await getAppDirectoryStore(env).listRecentRooms(appSession.user.user_id),
      });
    }

    if (url.pathname === "/family/list" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      return json({
        ok:true,
        families: await getAppDirectoryStore(env).familyList(
          url.searchParams.get("limit") || 100,
        ),
      });
    }

    if (url.pathname === "/family/create" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      const body = await request.json().catch(() => ({}));
      try {
        const result = await getAppDirectoryStore(env).familyCreate(
          appSession.user.user_id,body.name,body.tag,
        );
        return json(result,201);
      } catch (error) {
        return json({ok:false,error:String(error?.message || "Unable to create Family")},400);
      }
    }

    if (url.pathname === "/family/notice" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).familyUpdateNotice(
          appSession.user.user_id,body.notice,
        ));
      } catch (error) {
        return json({ok:false,error:String(error?.message || "Unable to update Family notice")},400);
      }
    }

    if (url.pathname === "/family/leave" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      try {
        return json(await getAppDirectoryStore(env).familyLeave(
          appSession.user.user_id,
        ));
      } catch (error) {
        return json({ok:false,error:String(error?.message || "Unable to leave Family")},400);
      }
    }

    if (url.pathname === "/family/check-in" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      try {
        return json(await getAppDirectoryStore(env).familyCheckIn(
          appSession.user.user_id,
        ));
      } catch (error) {
        return json({ok:false,error:String(error?.message || "Unable to check in")},400);
      }
    }

    if (url.pathname === "/family/wallet/send" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).familyTransferCoins(
          appSession.user.user_id,body.receiver_user_id,body.coins,
        ),201);
      } catch (error) {
        return json({ok:false,error:String(error?.message || "Unable to send Family coins")},400);
      }
    }

    if (url.pathname === "/family/wallet/transfers" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      return json({
        ok:true,
        transfers: await getAppDirectoryStore(env).familyWalletTransfers(
          appSession.user.user_id,url.searchParams.get("limit") || 100,
        ),
      });
    }

    if (url.pathname === "/family" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        ...(await getAppDirectoryStore(env).familyState(
          appSession.user.user_id,
        )),
      });
    }

    if (url.pathname === "/family/join-request" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).familyRequestJoin(
          appSession.user.user_id,
          body.family_id,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to request family join") }, 400);
      }
    }

    if (url.pathname === "/family/join-request/resolve" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).familyResolveJoin(
          appSession.user.user_id,
          body.user_id,
          body.approve === true,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to resolve family request") }, 400);
      }
    }

    if (url.pathname === "/family/admin" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).familySetAdmin(
          appSession.user.user_id,
          body.user_id,
          body.admin === true,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to manage Family Admin") }, 400);
      }
    }

    if (url.pathname === "/family/member/remove" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).familyRemoveMember(
          appSession.user.user_id,
          body.user_id,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to remove family member") }, 400);
      }
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

      const directory = getAppDirectoryStore(env);
      const callAccess = await directory.callRoomAccess(
        appSession.user.user_id,
        roomId,
      );

      if (!callAccess.allowed) {
        const rooms = await directory.listRooms();
        const room = rooms.find(
          (item) => String(item.id || item.room_id || "") === roomId,
        );
        if (!room) {
          return json({ ok: false, error: "Room not found" }, 404);
        }

        const access = await directory.roomAccessState(
          appSession.user.user_id,
          roomId,
        );
        if (!access.allowed) {
          return json({
            ok: false,
            error: access.reason === "blocked_by_room_owner"
              ? "You cannot enter this user's room."
              : access.reason === "invite_required"
                ? "Room invite is required."
                : "Room password is required.",
            room_locked: access.locked === true,
            invite_required: access.reason === "invite_required",
            blocked_by_room_owner: access.reason === "blocked_by_room_owner",
          }, 403);
        }

        const kick = await getRoomPresenceStore(env, roomId).kickStatus(
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

    if (url.pathname === "/room-games/action" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const ownerState = await getAppDirectoryStore(env).ownerState();
      if (ownerState.features?.games === false || ownerState.game_config?.enabled === false) return json({ ok: false, error: "Games are disabled by Owner" }, 403);
      try { return json(await getAppDirectoryStore(env).playRoomQuickGame(appSession.user.user_id, body), 201); }
      catch (error) { return json({ ok: false, error: String(error?.message || "Unable to play room game") }, 400); }
    }

    if (url.pathname === "/ludo/state" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const roomId = String(url.searchParams.get("room_id") || "").trim();
      if (!roomId) return json({ ok: false, error: "room_id is required" }, 400);
      const ownerState = await getAppDirectoryStore(env).ownerState();
      if (ownerState.features?.games === false || ownerState.game_config?.enabled === false) {
        return json({ ok: false, error: "Games are disabled by Owner" }, 403);
      }
      try {
        return json(await getAppDirectoryStore(env).ludoState(
          appSession.user.user_id,
          roomId,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to load Ludo") }, 400);
      }
    }

    if (url.pathname === "/ludo/roll" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).ludoRoll(
          appSession.user.user_id,
          body.room_id,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to roll Ludo dice") }, 400);
      }
    }

    if (url.pathname === "/ludo/move" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).ludoMove(
          appSession.user.user_id,
          body.room_id,
          body.token_index,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to move Ludo token") }, 400);
      }
    }

    if (url.pathname === "/ludo/reset" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).ludoReset(
          appSession.user.user_id,
          body.room_id,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to restart Ludo") }, 400);
      }
    }

    if (url.pathname === "/cp" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, cp: await getAppDirectoryStore(env).cpState(appSession.user.user_id) });
    }

    if (url.pathname === "/cp/request" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try { const store = getAppDirectoryStore(env); return json({ ok: true, cp: await store.cpRequest(appSession.user.user_id, body.target_user_id), wallet: await store.getWallet(appSession.user.user_id) }, 201); }
      catch (error) { return json({ ok: false, error: String(error?.message || "Unable to request CP") }, 400); }
    }

    if (url.pathname === "/cp/respond" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try { return json({ ok: true, cp: await getAppDirectoryStore(env).cpRespond(appSession.user.user_id, body.accept === true) }); }
      catch (error) { return json({ ok: false, error: String(error?.message || "Unable to respond to CP") }, 400); }
    }

    if (url.pathname === "/cp/disconnect" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      try { return json(await getAppDirectoryStore(env).cpDisconnect(appSession.user.user_id)); }
      catch (error) { return json({ ok: false, error: String(error?.message || "Unable to disconnect CP") }, 400); }
    }

    if (url.pathname === "/cp/update" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try { return json({ ok: true, cp: await getAppDirectoryStore(env).cpUpdate(appSession.user.user_id, body) }); }
      catch (error) { return json({ ok: false, error: String(error?.message || "Unable to update CP") }, 400); }
    }

    if (url.pathname === "/cp/memories" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, memories: await getAppDirectoryStore(env).cpMemories(appSession.user.user_id) });
    }

    if (url.pathname === "/cp/memories" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try { return json({ ok: true, memory: await getAppDirectoryStore(env).cpAddMemory(appSession.user.user_id, body.text) }, 201); }
      catch (error) { return json({ ok: false, error: String(error?.message || "Unable to add CP memory") }, 400); }
    }

    if (url.pathname === "/account/stats" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false, error:"Unauthorized" }, 401);
      return json({
        ok:true,
        stats: await getAppDirectoryStore(env).profileStats(appSession.user.user_id),
      });
    }

    if (url.pathname === "/tasks" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, tasks: await getAppDirectoryStore(env).taskState(appSession.user.user_id) });
    }

    if (url.pathname === "/tasks/claim" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).claimTask(
          appSession.user.user_id, body.task_id,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to claim task") }, 400);
      }
    }

    if (url.pathname === "/account/preferences" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, preferences: await getAppDirectoryStore(env).userPreferences(appSession.user.user_id) });
    }

    if (url.pathname === "/account/preferences" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).updateUserPreferences(appSession.user.user_id, body));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to update preferences") }, 400);
      }
    }

    if (url.pathname === "/account/identities" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, identities: await getAppDirectoryStore(env).accountIdentities(appSession.user.user_id) });
    }

    if (url.pathname === "/feedback" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, feedback: await getAppDirectoryStore(env).userFeedback(appSession.user.user_id) });
    }

    if (url.pathname === "/feedback" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).submitUserFeedback(
          appSession.user.user_id, body.category, body.message,
        ), 201);
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to submit feedback") }, 400);
      }
    }

    if (url.pathname === "/wallet" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, wallet: await getAppDirectoryStore(env).getWallet(appSession.user.user_id) });
    }

    if (url.pathname === "/wallet/transactions" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, transactions: await getAppDirectoryStore(env).walletTransactions(appSession.user.user_id) });
    }

    if (url.pathname === "/wallet/settlement/recipient" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      try {
        const recipient = await getAppDirectoryStore(env).settlementRecipient(
          url.searchParams.get("user_id") || "",
        );
        return json({ ok: true, recipient });
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Recipient not found") }, 400);
      }
    }

    if (url.pathname === "/wallet/settlement/transfer" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).transferSettlement(
          appSession.user.user_id,
          body.recipient_user_id,
          body.usd_cents,
        ), 201);
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to transfer settlement") }, 400);
      }
    }

    if (url.pathname === "/wallet/settlement/transfers" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        transfers: await getAppDirectoryStore(env).settlementTransfers(appSession.user.user_id),
      });
    }

    if (url.pathname === "/wallet/coins/transfer" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).transferCoinsFromSeller(
          appSession.user.user_id,
          body.recipient_user_id,
          body.amount_coins,
          body.wallet_type,
        ), 201);
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to transfer coins") }, 400);
      }
    }

    if (url.pathname === "/notifications" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        notifications: await getAppDirectoryStore(env).listUserNotifications(
          appSession.user.user_id,
          url.searchParams.get("limit") || 200,
        ),
      });
    }

    if (url.pathname === "/notifications/read" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).markUserNotificationRead(
          appSession.user.user_id,
          body.notification_id,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to mark notification") }, 400);
      }
    }

    if (url.pathname === "/unique-ids/catalog" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const rows = getAppDirectoryStore(env).ctx.storage.sql.exec(
        "SELECT public_id,price_coins,duration_days,assigned_user_id,enabled,updated_at FROM owner_unique_ids WHERE enabled = 1 ORDER BY LENGTH(public_id), public_id"
      ).toArray();
      return json({ ok: true, unique_ids: rows.map((row) => ({
        public_id: String(row.public_id), price_coins: Number(row.price_coins || 0),
        duration_days: Number(row.duration_days || 0), permanent: Number(row.duration_days || 0) === 0,
        available: !row.assigned_user_id, updated_at: Number(row.updated_at || 0),
      })) });
    }

    if (url.pathname === "/unique-ids/purchase" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).purchaseUniqueId(appSession.user.user_id, body.public_id));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to purchase unique ID") }, 400);
      }
    }

    if (url.pathname === "/store/catalog" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const kind = String(url.searchParams.get("kind") || "");
      return json({ ok: true, items: getAppDirectoryStore(env).purchasableCatalog(kind, url.searchParams.get("country") || "") });
    }
    if (url.pathname === "/store/purchase" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try { return json(getAppDirectoryStore(env).purchaseCatalogItem(appSession.user.user_id, body.kind, body.item_id, body.country || "")); }
      catch (error) { return json({ ok: false, error: String(error?.message || "Unable to purchase item") }, 400); }
    }

    if (url.pathname === "/store/equip" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).equipCatalogItem(
          appSession.user.user_id,
          body.kind,
          body.item_id,
        ));
      } catch (error) {
        return json({ ok:false,error:String(error?.message || "Unable to equip item") },400);
      }
    }

    if (url.pathname === "/store/send" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).sendCatalogItem(
          appSession.user.user_id,
          body.recipient_user_id,
          body.kind,
          body.item_id,
          appSession.user.country_code || "",
        ),201);
      } catch (error) {
        return json({ ok:false,error:String(error?.message || "Unable to send item") },400);
      }
    }

    if (url.pathname === "/frames/catalog" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        frames: await getAppDirectoryStore(env).frameCatalog(appSession.user.country_code),
      });
    }

    if (url.pathname === "/inventory" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        inventory: await getAppDirectoryStore(env).inventoryState(appSession.user.user_id),
      });
    }

    if (url.pathname === "/frames/purchase" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).purchaseFrame(
          appSession.user.user_id, body.frame_id, appSession.user.country_code,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to purchase frame") }, 400);
      }
    }

    if (url.pathname === "/frames/equip" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).equipFrame(
          appSession.user.user_id, body.frame_id,
        ));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to equip frame") }, 400);
      }
    }

    if (url.pathname === "/vip/me" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({ ok: true, vip: await getAppDirectoryStore(env).vipState(appSession.user.user_id) });
    }

    if (url.pathname === "/vip/purchase" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try { return json(await getAppDirectoryStore(env).vipPurchase(appSession.user.user_id, body.vip_id)); }
      catch (error) { return json({ ok: false, error: String(error?.message || "Unable to purchase VIP") }, 400); }
    }

    if (url.pathname === "/vip/catalog" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const items = await getAppDirectoryStore(env).ownerCatalog("vip");
      return json({ ok: true, vip: items.filter((item) => item.enabled !== false) });
    }

    if (url.pathname === "/gifts/send" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(await getAppDirectoryStore(env).sendGift(appSession.user.user_id, body), 201);
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to send gift") }, 400);
      }
    }

    if (url.pathname === "/gifts/ranking" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const roomId = String(url.searchParams.get("room_id") || "").trim();
      const period = String(url.searchParams.get("period") || "day").trim();
      try { return json(await getAppDirectoryStore(env).roomGiftRanking(roomId, period)); }
      catch (error) { return json({ ok:false,error:String(error?.message||"Unable to load sending ranking") },400); }
    }

    if (url.pathname === "/rooms/follow" && request.method === "GET") {
      const appSession=await verifyAppSession(request,env);
      if(!appSession)return json({ok:false,error:"Unauthorized"},401);
      const roomId=String(url.searchParams.get("room_id")||"").trim();
      try{return json({ok:true,...await getAppDirectoryStore(env).roomFollowState(roomId,appSession.user.user_id)});}
      catch(error){return json({ok:false,error:String(error?.message||"Unable to load room follow")},400);}
    }

    if (url.pathname === "/rooms/follow" && request.method === "POST") {
      const appSession=await verifyAppSession(request,env);
      if(!appSession)return json({ok:false,error:"Unauthorized"},401);
      const body=await request.json().catch(()=>({}));
      try{return json(await getAppDirectoryStore(env).setRoomFollow(appSession.user.user_id,body.room_id,body.following===true));}
      catch(error){return json({ok:false,error:String(error?.message||"Unable to update room follow")},400);}
    }

    if (url.pathname === "/rooms/membership" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      const roomId=String(url.searchParams.get("room_id")||"").trim();
      try { return json({ok:true,...await getAppDirectoryStore(env).roomMembershipState(roomId,appSession.user.user_id)}); }
      catch(error){ return json({ok:false,error:String(error?.message||"Unable to load membership")},400); }
    }

    if (url.pathname === "/rooms/membership" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok:false,error:"Unauthorized" },401);
      const body=await request.json().catch(()=>({}));
      try { return json(await getAppDirectoryStore(env).setRoomMembership(appSession.user.user_id,body.room_id,body.member===true)); }
      catch(error){ return json({ok:false,error:String(error?.message||"Unable to update membership")},400); }
    }

    if (url.pathname === "/lucky-pouch" && request.method === "GET") {
      const appSession=await verifyAppSession(request,env);
      if(!appSession)return json({ok:false,error:"Unauthorized"},401);
      const roomId=String(url.searchParams.get("room_id")||"").trim();
      return json({ok:true,pouch:await getAppDirectoryStore(env).luckyPouchState(roomId,appSession.user.user_id)});
    }

    if (url.pathname === "/lucky-pouch/open" && request.method === "POST") {
      const appSession=await verifyAppSession(request,env);
      if(!appSession)return json({ok:false,error:"Unauthorized"},401);
      const body=await request.json().catch(()=>({}));
      try{return json(await getAppDirectoryStore(env).createLuckyPouch(appSession.user.user_id,body),201);}
      catch(error){return json({ok:false,error:String(error?.message||"Unable to open Lucky Pouch")},400);}
    }

    if (url.pathname === "/lucky-pouch/claim" && request.method === "POST") {
      const appSession=await verifyAppSession(request,env);
      if(!appSession)return json({ok:false,error:"Unauthorized"},401);
      const body=await request.json().catch(()=>({}));
      try{return json(await getAppDirectoryStore(env).claimLuckyPouch(appSession.user.user_id,body.room_id));}
      catch(error){return json({ok:false,error:String(error?.message||"Unable to claim Lucky Pouch")},400);}
    }

    if (url.pathname === "/ribbons" && request.method === "GET") {
      const appSession=await verifyAppSession(request,env);
      if(!appSession)return json({ok:false,error:"Unauthorized"},401);
      const country=String(appSession.user.country_code||"").toUpperCase();
      return json({ok:true,country_code:country,ribbons:await getAppDirectoryStore(env).countryRibbons(country)});
    }

    if (url.pathname === "/gifts/room" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const roomId = String(url.searchParams.get("room_id") || "").trim();
      if (!roomId) return json({ ok: false, error: "room_id is required" }, 400);
      return json({ ok: true, gifts: await getAppDirectoryStore(env).listRoomGifts(roomId) });
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

    if (url.pathname === "/rooms/seat-count" && request.method === "PATCH") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const seatCount = Number(body.seat_count);
      if (!roomId || !Number.isInteger(seatCount)) {
        return json({ ok: false, error: "room_id and seat_count are required" }, 400);
      }
      const directory = getAppDirectoryStore(env);
      const room = await directory.findRoomByExactId(roomId);
      if (!room) return json({ ok: false, error: "Room not found" }, 404);
      const actorId = String(appSession.user.user_id);
      const store = getRoomPresenceStore(env, roomId);
      const isManager = await store.isManager(actorId);
      const isMember = await store.isMember(actorId);
      const isAdmin = isManager && isMember;
      if (String(room.owner_id) !== actorId && !isAdmin) {
        return json({ ok: false, error: "Only room owner/admin can change seat count" }, 403);
      }
      try {
        return json(await directory.updateRoomSeatCount(actorId, roomId, seatCount, isAdmin));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to change seat count") }, 400);
      }
    }

    if (url.pathname === "/rooms/settings" && request.method === "PATCH") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      if (!roomId) return json({ ok: false, error: "room_id is required" }, 400);
      try {
        return json(await getAppDirectoryStore(env).updateRoom(appSession.user.user_id, roomId, body));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to update room") }, 400);
      }
    }

    if (url.pathname === "/rooms/invite" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const targetUserId = String(body.target_user_id || "").trim();
      if (!roomId || !targetUserId) return json({ ok: false, error: "room_id and target_user_id are required" }, 400);
      const directory = getAppDirectoryStore(env);
      const rooms = await directory.listRooms();
      const room = rooms.find((item) => String(item.id || item.room_id || "") === roomId);
      if (!room) return json({ ok: false, error: "Room not found" }, 404);
      const actorId = String(appSession.user.user_id);
      const store = getRoomPresenceStore(env, roomId);
      const isManager = await store.isManager(actorId);
      const isMember = await store.isMember(actorId);
      if (String(room.owner_id) !== actorId && !(isManager && isMember)) return json({ ok: false, error: "Only room owner/admin can manage invites" }, 403);
      try { return json(await directory.setRoomInvite(roomId, targetUserId, actorId, body.invited !== false)); }
      catch (error) { return json({ ok: false, error: String(error?.message || "Unable to update room invite") }, 400); }
    }

    if (url.pathname === "/rooms/lock" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      if (!roomId) {
        return json({ ok: false, error: "room_id is required" }, 400);
      }
      try {
        const result = await getAppDirectoryStore(env).setRoomLock(
          appSession.user.user_id,
          roomId,
          body,
        );
        return json(result);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to change room lock"),
        }, 400);
      }
    }

    if (url.pathname === "/rooms/access" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const roomId = String(url.searchParams.get("room_id") || "").trim();
      if (!roomId) {
        return json({ ok: false, error: "room_id is required" }, 400);
      }
      const result = await getAppDirectoryStore(env).roomPasswordStatus(
        appSession.user.user_id,
        roomId,
      );
      return json(result, result.blocked ? 403 : 200);
    }

    if (url.pathname === "/rooms/access" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      if (!roomId) {
        return json({ ok: false, error: "room_id is required" }, 400);
      }
      try {
        const result = await getAppDirectoryStore(env).verifyRoomPassword(
          appSession.user.user_id,
          roomId,
          body.password,
        );
        return json(result, result.allowed ? 200 : 403);
      } catch (error) {
        return json({
          ok: false,
          allowed: false,
          error: String(error?.message || "Unable to verify room password"),
        }, 400);
      }
    }

    if (url.pathname === "/social/following" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        following: await getAppDirectoryStore(env).listFollowing(
          appSession.user.user_id,
        ),
      });
    }

    if (url.pathname === "/social/friends" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        friends: await getAppDirectoryStore(env).listFriends(
          appSession.user.user_id,
        ),
      });
    }

    if (url.pathname === "/social/follow" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(
          await getAppDirectoryStore(env).setFollowing(
            appSession.user.user_id,
            body.target_user_id,
            body.following === true,
          ),
        );
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to update follow"),
        }, 400);
      }
    }

    if (url.pathname === "/social/blocked" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        blocked: await getAppDirectoryStore(env).listBlocked(
          appSession.user.user_id,
        ),
      });
    }

    if (url.pathname === "/social/blocked/details" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        blocked: await getAppDirectoryStore(env).listBlockedProfiles(
          appSession.user.user_id,
        ),
      });
    }

    if (url.pathname === "/social/block" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(
          await getAppDirectoryStore(env).setBlocked(
            appSession.user.user_id,
            body.target_user_id,
            body.blocked === true,
          ),
        );
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to update block"),
        }, 400);
      }
    }

    if (
      url.pathname === "/calls/verification/status" &&
      request.method === "GET"
    ) {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      try {
        return json({
          ok: true,
          verification: await getAppDirectoryStore(env).callVerificationStatus(
            appSession.user.user_id,
          ),
        });
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to load verification status"),
        }, 400);
      }
    }

    if (
      url.pathname === "/calls/verification/submit" &&
      request.method === "POST"
    ) {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        const result = await getAppDirectoryStore(env).submitCallVerification(
          appSession.user.user_id,
          body,
        );
        if (!result.already_verified) {
          const screenshots = Array.isArray(body.photos)
            ? body.photos.slice(0, 3).map(String)
            : [];
          await getStaffStore(env).createOwnerNotification({
            type: "call_verification",
            title: "Call verification review",
            message:
              (body.system_passed === true
                ? "System liveness pre-check passed. "
                : "System liveness pre-check did not pass. ") +
              "Review the 3 live photos and make the final decision.",
            source_user_id: appSession.user.user_id,
            source_display_name: appSession.user.display_name,
            target_type: "call_verification",
            target_id: result.submission_id,
            metadata: {
              screenshots,
              system_passed: body.system_passed === true,
            },
          });
        }
        return json(result, result.already_verified ? 200 : 201);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to submit verification"),
        }, 400);
      }
    }

    if (url.pathname === "/calls/random" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json({
          ok: true,
          call: await getAppDirectoryStore(env).createRandomCall(
            appSession.user.user_id,
            body.gender,
            body.media,
          ),
        }, 201);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to start random call"),
        }, 400);
      }
    }

    if (url.pathname === "/calls" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json({
          ok: true,
          call: await getAppDirectoryStore(env).createCall(
            appSession.user.user_id,
            body.receiver_id,
            body.media,
          ),
        }, 201);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to start call"),
        }, 400);
      }
    }

    if (url.pathname === "/calls/status" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const callId = String(url.searchParams.get("call_id") || "").trim();
      const directory = getAppDirectoryStore(env);
      let call = await directory.getCall(callId);
      if (!call) return json({ ok: false, error: "Call not found" }, 404);
      if (call.state === "accepted") {
        call = await directory.settleCallBilling(callId, Date.now());
      }
      if (
        call.caller_id !== appSession.user.user_id &&
        call.receiver_id !== appSession.user.user_id
      ) {
        return json({ ok: false, error: "Not a call participant" }, 403);
      }
      const incident = await directory.latestCallPrivacyIncident(callId);
      return json({ ok: true, call, privacy_incident: incident });
    }

    if (url.pathname === "/calls/privacy-incident" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        const directory = getAppDirectoryStore(env);
        const call = await directory.reportCallPrivacyIncident(
          appSession.user.user_id,
          body.call_id,
          body.action,
        );
        return json({
          ok: true,
          call,
          privacy_incident: await directory.latestCallPrivacyIncident(body.call_id),
        });
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to report privacy incident") }, 400);
      }
    }

    if (url.pathname === "/calls/incoming" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        call: await getAppDirectoryStore(env).incomingCall(
          appSession.user.user_id,
        ),
      });
    }

    if (url.pathname === "/calls/respond" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json({
          ok: true,
          call: await getAppDirectoryStore(env).respondCall(
            appSession.user.user_id,
            body.call_id,
            body.accept === true,
          ),
        });
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to answer call"),
        }, 400);
      }
    }

    if (url.pathname === "/calls/end" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json({
          ok: true,
          call: await getAppDirectoryStore(env).endCall(
            appSession.user.user_id,
            body.call_id,
          ),
        });
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to end call"),
        }, 400);
      }
    }

    if (url.pathname === "/messages/inbox" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      try {
        return json({
          ok: true,
          threads: await getAppDirectoryStore(env).listMessageThreads(
            appSession.user.user_id,
          ),
        });
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to load inbox"),
        }, 400);
      }
    }

    if (url.pathname === "/messages" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const peerUserId = String(
        url.searchParams.get("peer_user_id") || "",
      ).trim();
      if (!peerUserId) {
        return json({ ok: false, error: "peer_user_id is required" }, 400);
      }
      try {
        return json({
          ok: true,
          messages: await getAppDirectoryStore(env).listDirectMessages(
            appSession.user.user_id,
            peerUserId,
            url.searchParams.get("limit"),
          ),
        });
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to load messages"),
        }, 400);
      }
    }

    if (url.pathname === "/messages" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        const message = await getAppDirectoryStore(env).sendDirectMessage(
          appSession.user.user_id,
          body.to_user_id,
          body.text,
        );
        return json({ ok: true, message }, 201);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to send message"),
        }, 400);
      }
    }

    if (url.pathname === "/rooms/theme" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      if (!roomId) {
        return json({ ok: false, error: "room_id is required" }, 400);
      }
      try {
        return json(
          await getAppDirectoryStore(env).setRoomTheme(
            appSession.user.user_id,
            roomId,
            body,
          ),
        );
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to change room theme"),
        }, 400);
      }
    }

    if (url.pathname === "/room-themes" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const roomId = String(url.searchParams.get("room_id") || "").trim();
      if (!roomId) {
        return json({ ok: false, error: "room_id is required" }, 400);
      }
      const themes = await getAppDirectoryStore(env).listRoomThemes(roomId);
      const ownerState = await getAppDirectoryStore(env).ownerState();
      const policy = ownerState.settings?.room_theme_user_policy || {
        prices: { "7": 10000000, "10": 14000000, "15": 20000000, "30": 35000000, permanent: 100000000 },
      };
      return json({
        ok: true,
        user_duration_options: [7, 10, 15, 30, "permanent"],
        user_prices: policy.prices,
        themes,
      });
    }

    if (url.pathname === "/room-themes" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      if (!roomId) {
        return json({ ok: false, error: "room_id is required" }, 400);
      }
      try {
        const theme = await getAppDirectoryStore(env).createUserRoomTheme(
          appSession.user.user_id,
          roomId,
          body,
        );
        return json({ ok: true, theme }, 201);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to add room theme"),
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
      const ownerState = await getAppDirectoryStore(env).ownerState();
      const gameConfig = ownerState.game_config || {};
      if (ownerState.features?.games === false || gameConfig.enabled === false) {
        return json({ ok: false, error: "Games are disabled by Owner" }, 403);
      }
      const amount = Number(body.amount || 0);
      if (Number.isFinite(Number(gameConfig.min_bet)) && amount < Number(gameConfig.min_bet)) {
        return json({ ok: false, error: "Bet is below Owner minimum" }, 400);
      }
      if (Number.isFinite(Number(gameConfig.max_bet)) && amount > Number(gameConfig.max_bet)) {
        return json({ ok: false, error: "Bet is above Owner maximum" }, 400);
      }
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

    if (url.pathname === "/fruit-party/state" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const state = await getFruitPartyStore(env).state(appSession.user.user_id);
      return json(state);
    }

    if (url.pathname === "/fruit-party/bet" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const ownerState = await getAppDirectoryStore(env).ownerState();
      const gameConfig = ownerState.game_config || {};
      if (ownerState.features?.games === false || gameConfig.enabled === false) {
        return json({ ok: false, error: "Games are disabled by Owner" }, 403);
      }
      const amount = Number(body.amount || 0);
      if (Number.isFinite(Number(gameConfig.min_bet)) && amount < Number(gameConfig.min_bet)) {
        return json({ ok: false, error: "Bet is below Owner minimum" }, 400);
      }
      if (Number.isFinite(Number(gameConfig.max_bet)) && amount > Number(gameConfig.max_bet)) {
        return json({ ok: false, error: "Bet is above Owner maximum" }, 400);
      }
      try {
        const state = await getFruitPartyStore(env).placeBet({
          ...body,
          user_id: appSession.user.user_id,
        });
        return json(state, 201);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to place Fruit Party bet"),
        }, 400);
      }
    }

    if (url.pathname === "/app-user/tags" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const requestedId = String(
        url.searchParams.get("user_id") || appSession.user.user_id || "",
      ).trim();
      const directory = getAppDirectoryStore(env);
      const tags = await directory.listUserTags(requestedId);
      const medals = await directory.listUserMedals(requestedId);
      return json({ ok: true, user_id: requestedId, tags, medals });
    }

    if (url.pathname === "/room-events" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(
          await getAppDirectoryStore(env).recordRoomRealtimeEvent(
            appSession.user.user_id,
            body,
          ),
          201,
        );
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to send room event"),
        }, 400);
      }
    }

    if (url.pathname === "/room-presence/state" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const roomId = String(url.searchParams.get("room_id") || "").trim();
      if (!roomId) return json({ ok: false, error: "room_id is required" }, 400);
      return json(await getRoomPresenceStore(env, roomId).state());
    }

    if (url.pathname === "/room-presence/mic-mode" && request.method === "POST") {
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
      if (!room) return json({ ok: false, error: "Room not found" }, 404);
      if (String(room.owner_id) !== String(appSession.user.user_id)) {
        return json({ ok: false, error: "Only the room owner can change mic mode" }, 403);
      }

      try {
        return json(
          await getRoomPresenceStore(env, roomId).setMicMode(body.mic_mode),
        );
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to change mic mode"),
        }, 400);
      }
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
      const store = getRoomPresenceStore(env, roomId);
      const actorId = String(appSession.user.user_id);
      const canManageAdmins = String(room.owner_id) === actorId;
      if (!canManageAdmins) {
        return json({ ok: false, error: "Only the room owner can manage admins" }, 403);
      }
      if (String(room.owner_id) === targetUserId) {
        return json({ ok: false, error: "Room owner role cannot be changed" }, 400);
      }
      const targetMatches = await getAppDirectoryStore(env).searchUsers(
        targetUserId,
        5,
      );
      const targetUser = targetMatches.find(
        (item) => String(item.user_id || "") === targetUserId,
      );
      if (!targetUser) {
        return json({ ok: false, error: "User ID not found" }, 404);
      }
      return json(await store.setManager(targetUserId, Boolean(body.enabled)));
    }

    if (url.pathname === "/room-presence/chat-ban" && request.method === "POST") {
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
      if (String(room.owner_id) === targetUserId) {
        return json({ ok: false, error: "Room owner cannot be chat banned" }, 400);
      }

      const store = getRoomPresenceStore(env, roomId);
      const actorId = String(appSession.user.user_id);
      const actorIsManager = await store.isManager(actorId);
      const actorIsMember = await store.isMember(actorId);
      const canModerate =
        String(room.owner_id) === actorId || (actorIsManager && actorIsMember);
      if (!canModerate) {
        return json({ ok: false, error: "Only room owner/admin can control room chat" }, 403);
      }
      const targetIsManager = await store.isManager(targetUserId);
      if (actorId !== String(room.owner_id) && targetIsManager) {
        return json({ ok: false, error: "Room admins cannot moderate another admin" }, 403);
      }


      try {
        return json(await store.setChatBan({
          target_user_id: targetUserId,
          banned_by: actorId,
          banned: body.banned === true,
        }));
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to update chat ban"),
        }, 400);
      }
    }

    if (url.pathname === "/room-presence/seat-lock" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const seatIndex = Number(body.seat_index);
      if (!roomId || !Number.isInteger(seatIndex) || seatIndex < 0) return json({ ok: false, error: "room_id and seat_index are required" }, 400);
      const rooms = await getAppDirectoryStore(env).listRooms();
      const room = rooms.find((item) => String(item.id || item.room_id || "") === roomId);
      if (!room) return json({ ok: false, error: "Room not found" }, 404);
      const store = getRoomPresenceStore(env, roomId);
      const actorId = String(appSession.user.user_id);
      const isManager = await store.isManager(actorId);
      const isMember = await store.isMember(actorId);
      const actorIsOwner = String(room.owner_id) === actorId;
      if (!actorIsOwner && !(isManager && isMember)) return json({ ok: false, error: "Only room owner/admin can lock seats" }, 403);
      const occupantId = await store.userIdAtSeat(seatIndex);
      if (!actorIsOwner && occupantId) {
        if (occupantId === String(room.owner_id)) {
          return json({ ok: false, error: "Room admins cannot lock the owner seat" }, 403);
        }
        if (await store.isManager(occupantId)) {
          return json({ ok: false, error: "Room admins cannot lock another admin seat" }, 403);
        }
      }
      try { return json(await store.setSeatLock({ seat_index: seatIndex, locked_by: actorId, locked: body.locked === true })); }
      catch (error) { return json({ ok: false, error: String(error?.message || "Unable to update seat lock") }, 400); }
    }

    if (url.pathname === "/room-presence/seat-mute" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const seatIndex = Number(body.seat_index);
      if (!roomId || !Number.isInteger(seatIndex) || seatIndex < 0) {
        return json({ ok: false, error: "room_id and seat_index are required" }, 400);
      }
      const rooms = await getAppDirectoryStore(env).listRooms();
      const room = rooms.find((item) => String(item.id || item.room_id || "") === roomId);
      if (!room) return json({ ok: false, error: "Room not found" }, 404);
      const store = getRoomPresenceStore(env, roomId);
      const actorId = String(appSession.user.user_id);
      const isManager = await store.isManager(actorId);
      const isMember = await store.isMember(actorId);
      const actorIsOwner = String(room.owner_id) === actorId;
      if (!actorIsOwner && !(isManager && isMember)) {
        return json({ ok: false, error: "Only room owner/admin can mute seats" }, 403);
      }
      const occupantId = await store.userIdAtSeat(seatIndex);
      if (!actorIsOwner && occupantId) {
        if (occupantId === String(room.owner_id)) {
          return json({ ok: false, error: "Room admins cannot mute the owner seat" }, 403);
        }
        if (await store.isManager(occupantId)) {
          return json({ ok: false, error: "Room admins cannot mute another admin seat" }, 403);
        }
      }
      try {
        return json(await store.setSeatMute({
          seat_index: seatIndex,
          muted_by: actorId,
          muted: body.muted === true,
        }));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to update seat mute") }, 400);
      }
    }

    if (url.pathname === "/room-presence/seat-take" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const seatIndex = Number(body.seat_index);
      if (!roomId || !Number.isInteger(seatIndex) || seatIndex < 0) {
        return json({ ok: false, error: "room_id and seat_index are required" }, 400);
      }
      const directory = getAppDirectoryStore(env);
      const room = await directory.findRoomByExactId(roomId);
      if (!room) return json({ ok: false, error: "Room not found" }, 404);
      const store = getRoomPresenceStore(env, roomId);
      const actorId = String(appSession.user.user_id);
      const isManager = await store.isManager(actorId);
      const isMember = await store.isMember(actorId);
      const privileged = String(room.owner_id) === actorId || (isManager && isMember);
      try {
        return json(await store.takeSeat({
          user_id: actorId,
          seat_index: seatIndex,
          privileged,
        }));
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to take seat") }, 400);
      }
    }

    if (url.pathname === "/room-presence/seat-request" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const seatIndex = Number(body.seat_index);
      if (!roomId || !Number.isInteger(seatIndex) || seatIndex < 0) {
        return json({
          ok: false,
          error: "room_id and seat_index are required",
        }, 400);
      }

      try {
        return json(
          await getRoomPresenceStore(env, roomId).requestSeat({
            user_id: appSession.user.user_id,
            seat_index: seatIndex,
          }),
        );
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to request seat"),
        }, 400);
      }
    }

    if (url.pathname === "/room-presence/seat-request/resolve" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const targetUserId = String(body.target_user_id || "").trim();
      if (!roomId || !targetUserId) {
        return json({
          ok: false,
          error: "room_id and target_user_id are required",
        }, 400);
      }

      const rooms = await getAppDirectoryStore(env).listRooms();
      const room = rooms.find(
        (item) => String(item.id || item.room_id || "") === roomId,
      );
      if (!room) return json({ ok: false, error: "Room not found" }, 404);

      const store = getRoomPresenceStore(env, roomId);
      const actorId = String(appSession.user.user_id);
      const isManager = await store.isManager(actorId);
      const isMember = await store.isMember(actorId);
      const canModerate =
        String(room.owner_id) === actorId || (isManager && isMember);
      if (!canModerate) {
        return json({
          ok: false,
          error: "Only room owner/admin can approve seat requests",
        }, 403);
      }

      try {
        return json(
          await store.resolveSeatRequest({
            target_user_id: targetUserId,
            approved: body.approved === true,
          }),
        );
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to resolve seat request"),
        }, 400);
      }
    }

    if (url.pathname === "/room-presence/seat-invite" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const targetUserId = String(body.target_user_id || "").trim();
      const seatIndex = Number(body.seat_index);
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
      const isManager = await store.isManager(actorId);
      const isMember = await store.isMember(actorId);
      const canModerate =
        String(room.owner_id) === actorId || (isManager && isMember);
      if (!canModerate) {
        return json({ ok: false, error: "Only room owner/admin can invite to seats" }, 403);
      }

      try {
        return json(await store.inviteToSeat({
          target_user_id: targetUserId,
          invited_by: actorId,
          seat_index: seatIndex,
        }));
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to invite user to seat"),
        }, 400);
      }
    }

    if (url.pathname === "/room-presence/seat-invite/respond" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      try {
        return json(
          await getRoomPresenceStore(env, String(body.room_id || "").trim())
            .respondSeatInvite({
              user_id: appSession.user.user_id,
              accepted: body.accepted === true,
            }),
        );
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to respond to seat invite"),
        }, 400);
      }
    }

    if (url.pathname === "/room-presence/seat-remove" && request.method === "POST") {
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
      const isManager = await store.isManager(actorId);
      const isMember = await store.isMember(actorId);
      const canModerate =
        String(room.owner_id) === actorId || (isManager && isMember);
      if (!canModerate) {
        return json({ ok: false, error: "Only room owner/admin can move users from seats" }, 403);
      }
      if (String(room.owner_id) === targetUserId) {
        return json({ ok: false, error: "Room owner cannot be moved to audience" }, 400);
      }
      const targetIsManager = await store.isManager(targetUserId);
      if (actorId !== String(room.owner_id) && targetIsManager) {
        return json({ ok: false, error: "Room admins cannot move another admin to audience" }, 403);
      }

      try {
        return json(await store.removeFromSeat({
          target_user_id: targetUserId,
        }));
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to move user to audience"),
        }, 400);
      }
    }

    if (url.pathname === "/room-presence/emote" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const emote = String(body.emote || "").trim();
      const seatIndex = Number(body.seat_index);
      if (!roomId || !emote || !Number.isInteger(seatIndex) || seatIndex < 0) {
        return json({
          ok: false,
          error: "room_id, emote and seat_index are required",
        }, 400);
      }

      try {
        const result = await getRoomPresenceStore(env, roomId).setEmote({
          user_id: appSession.user.user_id,
          seat_index: seatIndex,
          emote,
        });
        return json(result);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to send room emote"),
        }, 400);
      }
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
      const isManager = await store.isManager(actorId);
      const isMember = await store.isMember(actorId);
      const canModerate =
        String(room.owner_id) === actorId || (isManager && isMember);
      if (!canModerate) {
        return json({ ok: false, error: "Only room owner/admin can mute users" }, 403);
      }
      const targetIsManager = await store.isManager(targetUserId);
      if (actorId !== String(room.owner_id) && targetIsManager) {
        return json({ ok: false, error: "Room admins cannot moderate another admin" }, 403);
      }

      if (String(room.owner_id) === targetUserId) {
        return json({ ok: false, error: "Room owner cannot be muted" }, 400);
      }

      try {
        return json(await store.setMute({
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
      const isManager = await store.isManager(actorId);
      const isMember = await store.isMember(actorId);
      const canModerate =
        String(room.owner_id) === actorId || (isManager && isMember);
      if (!canModerate) {
        return json({ ok: false, error: "Only room owner/admin can kick users" }, 403);
      }
      const targetIsManager = await store.isManager(targetUserId);
      if (actorId !== String(room.owner_id) && targetIsManager) {
        return json({ ok: false, error: "Room admins cannot moderate another admin" }, 403);
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
          12 * 60 * 60 * 1000,
          48 * 60 * 60 * 1000,
        ]);
        if (!allowed.has(durationMs)) {
          return json({ ok: false, error: "Invalid kick duration" }, 400);
        }
      }

      return json(await store.kick({
        target_user_id: targetUserId,
        kicked_by: actorId,
        duration_ms: durationMs,
      }));
    }

    if (url.pathname === "/room-presence/kicks" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const roomId = String(url.searchParams.get("room_id") || "").trim();
      if (!roomId) return json({ ok: false, error: "room_id is required" }, 400);
      const rooms = await getAppDirectoryStore(env).listRooms();
      const room = rooms.find((item) => String(item.id || item.room_id || "") === roomId);
      if (!room) return json({ ok: false, error: "Room not found" }, 404);
      if (String(room.owner_id) !== String(appSession.user.user_id)) {
        return json({ ok: false, error: "Only room owner can view Kickout List" }, 403);
      }
      return json({ ok: true, kicks: await getRoomPresenceStore(env, roomId).kickList() });
    }

    if (url.pathname === "/room-presence/unkick" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));
      const roomId = String(body.room_id || "").trim();
      const targetUserId = String(body.target_user_id || "").trim();
      if (!roomId || !targetUserId) {
        return json({ ok: false, error: "room_id and target_user_id are required" }, 400);
      }
      const rooms = await getAppDirectoryStore(env).listRooms();
      const room = rooms.find((item) => String(item.id || item.room_id || "") === roomId);
      if (!room) return json({ ok: false, error: "Room not found" }, 404);
      if (String(room.owner_id) !== String(appSession.user.user_id)) {
        return json({ ok: false, error: "Only room owner can unkick users" }, 403);
      }
      return json(await getRoomPresenceStore(env, roomId).unkick(targetUserId));
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
      if (url.pathname.endsWith("/join")) {
        const access = await getAppDirectoryStore(env).roomAccessState(
          user.user_id,
          roomId,
        );
        if (!access.allowed) {
          return json({
            ok: false,
            error: "Room password is required.",
            room_locked: true,
          }, 403);
        }
      }
      const presenceBody = {
        room_id: roomId,
        user_id: user.user_id,
        display_name: user.display_name,
        avatar_data_url: user.avatar_data_url,
        flag_emoji: user.flag_emoji,
        country_code: user.country_code,
        family_tag: body.family_tag,
        host_tag: body.host_tag,
        agency_name: body.agency_name,
        equipped_frame_id: body.equipped_frame_id,
        equipped_entry_id: body.equipped_entry_id,
        equipped_profile_card_id: body.equipped_profile_card_id,
        owner_tags: Array.isArray(user.tags) ? user.tags : [],
        owner_medals: Array.isArray(user.medals) ? user.medals : [],
        seat_index:
          body.seat_index === null || body.seat_index === undefined
            ? null
            : Number(body.seat_index),
      };
      try {
        const directory = getAppDirectoryStore(env);
        if (url.pathname.endsWith("/join")) {
          const result = await store.join(presenceBody);
          await directory.touchPresence(user.user_id, roomId, result.members?.length || 0);
          await directory.markRecentRoom(user.user_id, roomId);
          await directory.notifyFollowersOnline(user.user_id, roomId);
          return json(result, 201);
        }
        if (url.pathname.endsWith("/heartbeat")) {
          const result = await store.heartbeat(presenceBody);
          await directory.touchPresence(user.user_id, roomId, result.members?.length || 0);
          return json(result);
        }
        const result = await store.leave(presenceBody);
        await directory.clearPresence(user.user_id, roomId, result.members?.length || 0);
        return json(result);
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

    if (url.pathname === "/app/complaints" && request.method === "POST") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      const body = await request.json().catch(() => ({}));

      const allowedCategories = new Set([
        "sexual_nude_exploitation",
        "child_safety_minor_exploitation",
        "harassment_bullying_hate",
        "threats_violence_weapons",
        "terrorism_extremism_drugs",
        "self_harm_suicide",
        "fraud_scam_payment_abuse",
        "account_theft_phishing_impersonation",
        "privacy_doxxing",
        "illegal_gambling_betting",
        "spam_advertising",
        "copyright_stolen_content",
        "room_abuse",
        "other",
      ]);

      const targetUserId = String(body.target_user_id || "").trim();
      const targetDisplayName = String(body.target_display_name || "").trim();
      const roomId = String(body.room_id || "").trim();
      const rawCategories = Array.isArray(body.categories) ? body.categories : [];
      const categories = [...new Set(
        rawCategories
          .map((value) => String(value || "").trim())
          .filter((value) => allowedCategories.has(value)),
      )];
      const otherDetails = String(body.other_details || "").trim();
      const screenshots = Array.isArray(body.screenshots)
        ? body.screenshots
            .map((value) => String(value || "").trim())
            .filter((value) => value.startsWith("data:image/"))
            .slice(0, 5)
        : [];

      if (!targetUserId) {
        return json({ ok: false, error: "target_user_id is required" }, 400);
      }
      if (targetUserId === String(appSession.user.user_id)) {
        return json({ ok: false, error: "You cannot report your own ID" }, 400);
      }
      if (categories.length === 0) {
        return json({ ok: false, error: "Select at least one report reason" }, 400);
      }
      if (categories.includes("other") && otherDetails.length < 3) {
        return json({ ok: false, error: "Write details for Other" }, 400);
      }
      if (screenshots.some((value) => value.length > 950000)) {
        return json({ ok: false, error: "One or more screenshots are too large" }, 413);
      }

      const categoryLabels = {
        sexual_nude_exploitation: "Sexual / Nude Content & Sexual Exploitation",
        child_safety_minor_exploitation: "Child Safety / Minor Exploitation",
        harassment_bullying_hate: "Harassment / Bullying / Hate Speech",
        threats_violence_weapons: "Threats / Violence / Weapons",
        terrorism_extremism_drugs: "Terrorism / Extremism / Drugs / Illegal Substances",
        self_harm_suicide: "Self-harm / Suicide Encouragement",
        fraud_scam_payment_abuse: "Fraud / Scam / Fake Coins / Payment Abuse",
        account_theft_phishing_impersonation: "Account Theft / Phishing / Impersonation",
        privacy_doxxing: "Privacy / Personal Information / Doxxing",
        illegal_gambling_betting: "Illegal Gambling / Betting",
        spam_advertising: "Spam / Advertising",
        copyright_stolen_content: "Copyright / Stolen Content",
        room_abuse: "Room Abuse / Prohibited Room Activity",
        other: "Other",
      };
      const labels = categories.map((key) => categoryLabels[key] || key);
      const message = labels.join(", ") +
        (otherDetails ? " — " + otherDetails : "");

      const notification = await getStaffStore(env).createOwnerNotification({
        type: "user_report",
        source_user_id: appSession.user.user_id,
        source_display_name: appSession.user.display_name,
        target_type: "user",
        target_id: targetUserId,
        title: "User report" + (targetDisplayName ? ": " + targetDisplayName : ""),
        message,
        metadata: {
          categories,
          category_labels: labels,
          other_details: otherDetails || null,
          screenshots,
          screenshot_count: screenshots.length,
          room_id: roomId || null,
          target_display_name: targetDisplayName || null,
          reporter_user_id: appSession.user.user_id,
          reporter_display_name: appSession.user.display_name,
        },
      });

      return json({
        ok: true,
        report_id: notification.id,
        owner_notification_created: true,
        screenshot_count: screenshots.length,
      }, 201);
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

    if (url.pathname === "/api/owner/official-message" && request.method === "POST") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const body = await request.json().catch(() => ({}));
      const targetUserId = String(body.target_user_id || "").trim();
      const message = String(body.message || "").trim();
      const reportId = String(body.report_id || "").trim();
      const recipientKind = String(body.recipient_kind || "").trim();

      if (!targetUserId) {
        return json({ ok: false, error: "target_user_id is required" }, 400);
      }
      if (!message) {
        return json({ ok: false, error: "Message cannot be empty" }, 400);
      }
      if (message.length > 2000) {
        return json({ ok: false, error: "Message is too long" }, 400);
      }

      try {
        const officialMessage = await getAppDirectoryStore(env).sendOfficialMessage(
          targetUserId,
          message,
          {
            report_id: reportId || null,
            recipient_kind: recipientKind || null,
          },
        );

        await writeAudit(
          env,
          session,
          "official.message.send",
          "user",
          targetUserId,
          {
            sender_name: "Tinni Official",
            report_id: reportId || null,
            recipient_kind: recipientKind || null,
            message_id: officialMessage.id,
          },
        );

        return json({
          ok: true,
          message: officialMessage,
          sender_name: "Tinni Official",
        }, 201);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to send official message"),
        }, 400);
      }
    }

    if (url.pathname === "/api/owner/notifications" && request.method === "GET") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const notifications = await getStaffStore(env).listOwnerNotifications({
        limit: url.searchParams.get("limit") || 200,
      });
      return json({
        ok: true,
        notifications,
        unread_count: notifications.filter((item) => !item.is_read).length,
      });
    }

    const ownerNotificationMatch = url.pathname.match(/^\/api\/owner\/notifications\/([^/]+)$/);
    if (ownerNotificationMatch && request.method === "PATCH") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const body = await request.json().catch(() => ({}));
      return json(await getStaffStore(env).markOwnerNotificationRead(
        decodeURIComponent(ownerNotificationMatch[1]),
        body.is_read !== false,
      ));
    }

    if (ownerNotificationMatch && request.method === "DELETE") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      return json(await getStaffStore(env).deleteOwnerNotification(
        decodeURIComponent(ownerNotificationMatch[1]),
      ));
    }

    if (
      url.pathname === "/api/call-verifications" &&
      request.method === "GET"
    ) {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      return json({
        ok: true,
        submissions:
          await getAppDirectoryStore(env).listCallVerificationSubmissions(),
      });
    }

    const callVerificationReviewMatch = url.pathname.match(
      /^\/api\/call-verifications\/([^/]+)\/review$/,
    );
    if (callVerificationReviewMatch && request.method === "POST") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const body = await request.json().catch(() => ({}));
      try {
        const result =
          await getAppDirectoryStore(env).reviewCallVerification(
            decodeURIComponent(callVerificationReviewMatch[1]),
            body.approve === true,
            body.note,
          );
        await writeAudit(
          env,
          session,
          body.approve === true
            ? "call.verification.approve"
            : "call.verification.reject",
          "user",
          result.user_id,
          { submission_id: result.submission_id },
        );
        if (body.approve === true) {
          await getAppDirectoryStore(env).sendOfficialMessage(
            result.user_id,
            "Your Call ID verification is approved. Your ID stays Verified until Owner removes Verified status."
          );
        } else {
          await getAppDirectoryStore(env).sendOfficialMessage(
            result.user_id,
            "Your Call ID verification was rejected. Please contact the Official Manager for help with verification."
          );
          await getStaffStore(env).createOwnerNotification({
            type: "call_verification_rejected",
            title: "Call verification rejected",
            message:
              "The user was instructed to contact the Official Manager.",
            source_user_id: result.user_id,
            target_type: "call_verification",
            target_id: result.submission_id,
            metadata: {},
          });
        }
        return json(result);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to review verification"),
        }, 400);
      }
    }

    const callVerificationManualVerifyMatch = url.pathname.match(
      /^\/api\/call-verifications\/user\/([^/]+)\/verify$/,
    );
    if (callVerificationManualVerifyMatch && request.method === "POST") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const body = await request.json().catch(() => ({}));
      try {
        const userId = decodeURIComponent(
          callVerificationManualVerifyMatch[1],
        );
        const result =
          await getAppDirectoryStore(env).verifyCallManually(
            userId,
            body.note,
          );
        await writeAudit(
          env,
          session,
          "call.verification.manual_verify",
          "user",
          userId,
          {
            note: String(body.note || ""),
            verification_method: "owner_override",
          },
        );
        await getAppDirectoryStore(env).sendOfficialMessage(
          userId,
          "Owner manually verified your Call ID. Your ID stays Verified until Owner removes Verified status."
        );
        return json(result);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to verify ID"),
        }, 400);
      }
    }

    const callVerificationRevokeMatch = url.pathname.match(
      /^\/api\/call-verifications\/user\/([^/]+)\/revoke$/,
    );
    if (callVerificationRevokeMatch && request.method === "POST") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const body = await request.json().catch(() => ({}));
      try {
        const userId = decodeURIComponent(callVerificationRevokeMatch[1]);
        const result =
          await getAppDirectoryStore(env).revokeCallVerification(
            userId,
            body.note,
          );
        await writeAudit(
          env,
          session,
          "call.verification.revoke",
          "user",
          userId,
          { note: String(body.note || "") },
        );
        await getAppDirectoryStore(env).sendOfficialMessage(
          userId,
          "Owner removed your Call ID Verified status. Verification will be required again to return to the Verified call benefits and random-call pool."
        );
        return json(result);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to revoke verification"),
        }, 400);
      }
    }

    if (url.pathname === "/api/owner/state" && request.method === "GET") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      return json({
        ok: true,
        state: await getAppDirectoryStore(env).ownerState(),
        dashboard: await getAppDirectoryStore(env).ownerDashboard(),
      });
    }

    if (url.pathname === "/api/owner/users/search" && request.method === "GET") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const query = String(url.searchParams.get("q") || "");
      const users = await getAppDirectoryStore(env).ownerSearchUsers(
        query,
        url.searchParams.get("limit") || 50,
      );
      return json({ ok: true, users });
    }

    if (url.pathname === "/api/owner/verified-users" && request.method === "GET") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      return json({
        ok: true,
        users: await getAppDirectoryStore(env).listVerifiedUsers(
          String(url.searchParams.get("q") || ""),
        ),
      });
    }

    if (url.pathname === "/api/owner/messages" && request.method === "POST") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const body = await request.json().catch(() => ({}));
      try {
        const result = await getAppDirectoryStore(env).sendOwnerMessages(
          body.text,
          body.user_ids,
          body.all_users === true,
        );
        await writeAudit(
          env,
          session,
          body.all_users === true ? "message.broadcast_all" : "message.bulk_selected",
          "users",
          body.all_users === true ? "all" : (Array.isArray(body.user_ids) ? body.user_ids.join(",") : ""),
          { sent: result.sent },
        );
        return json(result);
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to send message") }, 400);
      }
    }

    if (url.pathname === "/api/owner/tags" && request.method === "POST") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const body = await request.json().catch(() => ({}));
      try {
        const result = await getAppDirectoryStore(env).applyOwnerTag(
          body.user_ids,
          body.name,
          body.color,
        );
        await writeAudit(
          env,
          session,
          "user.tag.apply",
          "users",
          Array.isArray(body.user_ids) ? body.user_ids.join(",") : "",
          { name: result.name, color: result.color, tagged: result.tagged },
        );
        return json(result);
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to apply tag") }, 400);
      }
    }

    const ownerTagDeleteMatch = url.pathname.match(
      /^\/api\/owner\/tags\/([^/]+)\/([^/]+)$/,
    );
    if (ownerTagDeleteMatch && request.method === "DELETE") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const userId = decodeURIComponent(ownerTagDeleteMatch[1]);
      const tagId = decodeURIComponent(ownerTagDeleteMatch[2]);
      const result = await getAppDirectoryStore(env).removeOwnerTag(userId, tagId);
      await writeAudit(env, session, "user.tag.remove", "user", userId, { tag_id: tagId });
      return json(result);
    }

    if (url.pathname === "/api/owner/room-live" && request.method === "GET") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const roomId = String(url.searchParams.get("room_id") || "").trim();
      if (!roomId) return json({ ok: false, error: "room_id is required" }, 400);
      const rooms = await getAppDirectoryStore(env).listRooms();
      const room = rooms.find((item) => String(item.id || "") === roomId);
      if (!room) return json({ ok: false, error: "Room not found" }, 404);
      const presence = await getRoomPresenceStore(env, roomId).state();
      return json({ ok: true, room, presence });
    }

    if (url.pathname === "/api/owner/game-stats" && request.method === "GET") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const userId = String(url.searchParams.get("user_id") || "").trim();
      const jackpot = await getFruitGameStore(env).ownerStats(userId);
      const party = await getFruitPartyStore(env).ownerStats(userId);
      return json({
        ok: true,
        user_id: userId || null,
        jackpot,
        party,
        totals: {
          bet_count: Number(jackpot.bet_count || 0) + Number(party.bet_count || 0),
          total_bet: Number(jackpot.total_bet || 0) + Number(party.total_bet || 0),
          total_payout: Number(jackpot.total_payout || 0) + Number(party.total_payout || 0),
          unique_players: Math.max(
            Number(jackpot.unique_players || 0),
            Number(party.unique_players || 0),
          ),
          house_net: Number(jackpot.house_net || 0) + Number(party.house_net || 0),
        },
      });
    }

    if (url.pathname === "/api/owner/action" && request.method === "POST") {
      const body = await request.json().catch(() => ({}));
      const actionPermissions = {
        "user-search":"users.search","user-ban":"users.ban_id","device-ban":"users.ban_device",
        "user-invisible":"users.invisible","locked-bypass":"users.locked_room_bypass","id-change":"users.change_id","unique-id-new":"users.unique_id","unique-id-price":"users.unique_id",
        "room-ban":"rooms.ban","room-name":"rooms.rename","room-dp":"rooms.dp","room-bg":"rooms.background",
        "wallet-normal":"wallets.normal","wallet-seller":"wallets.seller","wallet-merchant":"wallets.merchant",
        "treasury-send":"wallets.treasury_send","bd-activate":"hierarchy.bd_manage","agency-activate":"hierarchy.agency_manage",
        "agency-to-bd":"hierarchy.agency_bd_link","agency-from-bd":"hierarchy.agency_bd_link","host-add":"hierarchy.host_manage",
        "host-remove":"hierarchy.host_manage","bd-target":"hierarchy.targets","complaints":"hierarchy.complaints",
        "role-new":"roles.manage","vip-new":"vip.create","vip-grant":"vip.grant_remove","gift-new":"gifts.create",
        "entry-new":"assets.entries","profile-card-new":"assets.frames","frame-new":"assets.frames","banner-new":"banners.create","game-switch":"games.toggle",
        "game-limits":"games.limits","game-stats":"games.investigate","policy-new":"policies.create","policy-set":"policies.edit",
        "feature-set":"policies.edit","pricing-set":"policies.pricing","user-price-override-set":"policies.pricing","user-price-override-remove":"policies.pricing",
      };
      const catalogAction = ["catalog-toggle","catalog-edit","catalog-remove"].includes(String(body.action || ""));
      let requiredPermission = actionPermissions[String(body.action || "")];
      if (catalogAction && !ownerOnly(session)) {
        const item = (await getAppDirectoryStore(env).ownerCatalog()).find((entry) => String(entry.id) === String(body.data?.id || ""));
        if (!item) return json({ ok: false, error: "Catalog item not found" }, 404);
        const operation = String(body.action).replace("catalog-", "");
        const kind = String(item.kind || "");
        if (kind === "vip") requiredPermission = operation === "toggle" ? "vip.toggle" : "vip.edit";
        else if (kind === "gift") requiredPermission = operation === "edit" ? "gifts.edit" : "gifts.remove";
        else if (kind === "entry") requiredPermission = "assets.entries";
        else if (kind === "frame") requiredPermission = "assets.frames";
        else if (kind === "banner") requiredPermission = operation === "remove" ? "banners.remove" : "banners.create";
        else requiredPermission = "roles.manage";
      }
      if (!ownerOnly(session) && (!requiredPermission || !sessionHasPermission(session, requiredPermission))) {
        return json({ ok: false, error: "Owner or assigned staff permission required" }, 403);
      }
      try {
        const result = await getAppDirectoryStore(env).ownerAction(body.action, body.data);
        await writeAudit(
          env,
          session,
          "owner.action." + String(body.action || "unknown"),
          "owner_action",
          String(body.data?.user_id || body.data?.room_id || body.data?.target_id || ""),
          { data: body.data || {}, result },
        );
        return json({ ok: true, result, state: await getAppDirectoryStore(env).ownerState() });
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Owner action failed") }, 400);
      }
    }

    const ownerCatalogMatch = url.pathname.match(/^\/api\/owner\/catalog\/([^/]+)$/);
    if (ownerCatalogMatch && request.method === "PATCH") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      const body = await request.json().catch(() => ({}));
      try {
        const item = await getAppDirectoryStore(env).ownerCatalogPatch(
          decodeURIComponent(ownerCatalogMatch[1]),
          body,
        );
        await writeAudit(env, session, "owner.catalog.update", "catalog", item.id, body);
        return json({ ok: true, item });
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to update item") }, 400);
      }
    }

    if (url.pathname === "/api/audit/summary" && request.method === "GET") {
      if (!ownerOnly(session) && !sessionHasPermission(session, "audit.view")) {
        return json({ ok: false, error: "Audit access required" }, 403);
      }
      const panelId = ownerOnly(session)
        ? String(url.searchParams.get("panel_id") || "")
        : String(session.panelId || "");
      const summary = await getStaffStore(env).auditSummary({ panel_id: panelId });
      return json({ ok: true, summary });
    }

    if (url.pathname === "/api/audit" && request.method === "GET") {
      if (!ownerOnly(session) && !sessionHasPermission(session, "audit.view")) {
        return json({ ok: false, error: "Audit access required" }, 403);
      }
      const panelId = ownerOnly(session)
        ? String(url.searchParams.get("panel_id") || "")
        : String(session.panelId || "");
      const records = await getStaffStore(env).listAudit({
        panel_id: panelId,
        limit: url.searchParams.get("limit") || 250,
      });
      return json({
        ok: true,
        records,
        scope: ownerOnly(session) ? (panelId || "all") : "own-panel",
        can_delete: ownerOnly(session),
      });
    }

    if (url.pathname === "/api/audit" && request.method === "DELETE") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      return json(await getStaffStore(env).clearAudit(
        String(url.searchParams.get("panel_id") || ""),
      ));
    }

    const auditRecordMatch = url.pathname.match(/^\/api\/audit\/([^/]+)$/);
    if (auditRecordMatch && request.method === "DELETE") {
      if (!ownerOnly(session)) {
        return json({ ok: false, error: "Owner access required" }, 403);
      }
      return json(await getStaffStore(env).deleteAudit(
        decodeURIComponent(auditRecordMatch[1]),
      ));
    }

    if (url.pathname === "/api/staff/panels" && request.method === "POST") {
      if (!ownerOnly(session)) return json({ ok: false, error: "Owner access required" }, 403);
      const body = await request.json().catch(() => ({}));
      try {
        const panel = await getStaffStore(env).createPanel(body);
        await writeAudit(env, session, "staff.panel.create", "panel", panel.id, {
          panel_name: panel.name,
          staff_email: panel.email,
          assigned_user_id: panel.assigned_user_id || null,
          permissions: panel.permissions,
        });
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
        await writeAudit(env, session, "staff.panel.update", "panel", panel.id, {
          panel_name: panel.name,
          changed: {
            staff_email: body.staff_email !== undefined,
            password: body.password !== undefined,
            permissions: body.permissions !== undefined,
            enabled: body.enabled !== undefined,
          },
          enabled: panel.enabled,
          permissions: panel.permissions,
        });
        return json({ ok: true, panel });
      } catch (error) {
        return json({ ok: false, error: String(error?.message || "Unable to update staff panel") }, 400);
      }
    }

    if (url.pathname === "/api/room-themes" && request.method === "GET") {
      if (!sessionHasPermission(session, "rooms.theme_view")) {
        return json({ ok: false, error: "Room theme view access required" }, 403);
      }
      const themes = await getAppDirectoryStore(env).listPanelRoomThemes();
      return json({ ok: true, themes });
    }

    if (url.pathname === "/api/room-themes" && request.method === "POST") {
      if (!sessionHasPermission(session, "rooms.theme_create")) {
        return json({ ok: false, error: "Room theme create access required" }, 403);
      }
      const body = await request.json().catch(() => ({}));
      try {
        const theme = await getAppDirectoryStore(env).createPanelRoomTheme(body);
        await writeAudit(env, session, "room.theme.create", "room_theme", theme.id, {
          name: theme.name,
          permanent: Boolean(theme.permanent),
          starts_at: theme.starts_at || null,
          expires_at: theme.expires_at || null,
        });
        return json({ ok: true, theme }, 201);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to add room theme"),
        }, 400);
      }
    }

    const roomThemeMatch = url.pathname.match(/^\/api\/room-themes\/([^/]+)$/);
    if (roomThemeMatch && request.method === "DELETE") {
      if (!sessionHasPermission(session, "rooms.theme_remove")) {
        return json({ ok: false, error: "Room theme remove access required" }, 403);
      }
      try {
        const themeId = decodeURIComponent(roomThemeMatch[1]);
        const result = await getAppDirectoryStore(env).disableRoomTheme(themeId);
        await writeAudit(env, session, "room.theme.remove", "room_theme", themeId, {});
        return json(result);
      } catch (error) {
        return json({
          ok: false,
          error: String(error?.message || "Unable to remove room theme"),
        }, 400);
      }
    }

    if (url.pathname.startsWith("/api/")) {
      return json({ ok: false, error: "API endpoint not implemented" }, 404);
    }

    if (url.pathname === "/") {
      const assetUrl = new URL(request.url);
      assetUrl.pathname = "/index.html";
      return env.ASSETS.fetch(new Request(assetUrl, request));
    }

    return env.ASSETS.fetch(request);
  },
};
