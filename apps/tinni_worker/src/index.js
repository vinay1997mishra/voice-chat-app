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

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({
        ok: true,
        service: "tinni-star-api",
        message: "Tinni Star API online",
        version: "1.5.0",
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

      const directory = getAppDirectoryStore(env);
      const callAccess = directory.callRoomAccess(
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

        const access = directory.roomAccessState(
          appSession.user.user_id,
          roomId,
        );
        if (!access.allowed) {
          return json({
            ok: false,
            error: "Room password is required.",
            room_locked: true,
          }, 403);
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
      const result = getAppDirectoryStore(env).roomPasswordStatus(
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
        following: getAppDirectoryStore(env).listFollowing(
          appSession.user.user_id,
        ),
      });
    }

    if (url.pathname === "/social/friends" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        friends: getAppDirectoryStore(env).listFriends(
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
          getAppDirectoryStore(env).setFollowing(
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
        blocked: getAppDirectoryStore(env).listBlocked(
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
          getAppDirectoryStore(env).setBlocked(
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
          verification: getAppDirectoryStore(env).callVerificationStatus(
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
        const result = getAppDirectoryStore(env).submitCallVerification(
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
          call: getAppDirectoryStore(env).createRandomCall(
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
          call: getAppDirectoryStore(env).createCall(
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
      let call = directory.getCall(callId);
      if (!call) return json({ ok: false, error: "Call not found" }, 404);
      if (call.state === "accepted") {
        call = directory.settleCallBilling(callId, Date.now());
      }
      if (
        call.caller_id !== appSession.user.user_id &&
        call.receiver_id !== appSession.user.user_id
      ) {
        return json({ ok: false, error: "Not a call participant" }, 403);
      }
      return json({ ok: true, call });
    }

    if (url.pathname === "/calls/incoming" && request.method === "GET") {
      const appSession = await verifyAppSession(request, env);
      if (!appSession) return json({ ok: false, error: "Unauthorized" }, 401);
      return json({
        ok: true,
        call: getAppDirectoryStore(env).incomingCall(
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
          call: getAppDirectoryStore(env).respondCall(
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
          call: getAppDirectoryStore(env).endCall(
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
          threads: getAppDirectoryStore(env).listMessageThreads(
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
          messages: getAppDirectoryStore(env).listDirectMessages(
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
        const message = getAppDirectoryStore(env).sendDirectMessage(
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
          getAppDirectoryStore(env).setRoomTheme(
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
      const themes = getAppDirectoryStore(env).listRoomThemes(roomId);
      return json({
        ok: true,
        user_price_coins: 10000000,
        user_duration_days: 7,
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
        const theme = getAppDirectoryStore(env).createUserRoomTheme(
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
          getRoomPresenceStore(env, roomId).setMicMode(body.mic_mode),
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
      if (String(room.owner_id) !== String(appSession.user.user_id)) {
        return json({ ok: false, error: "Only the room owner can manage admins" }, 403);
      }

      const store = getRoomPresenceStore(env, roomId);
      return json(store.setManager(targetUserId, Boolean(body.enabled)));
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
          getRoomPresenceStore(env, roomId).requestSeat({
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
      const canModerate =
        String(room.owner_id) === actorId ||
        (store.isManager(actorId) && store.isMember(actorId));
      if (!canModerate) {
        return json({
          ok: false,
          error: "Only room owner/admin can approve seat requests",
        }, 403);
      }

      try {
        return json(
          store.resolveSeatRequest({
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
      const canModerate =
        String(room.owner_id) === actorId ||
        (store.isManager(actorId) && store.isMember(actorId));
      if (!canModerate) {
        return json({ ok: false, error: "Only room owner/admin can invite to seats" }, 403);
      }

      try {
        return json(store.inviteToSeat({
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
          getRoomPresenceStore(env, String(body.room_id || "").trim())
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
      const canModerate =
        String(room.owner_id) === actorId ||
        (store.isManager(actorId) && store.isMember(actorId));
      if (!canModerate) {
        return json({ ok: false, error: "Only room owner/admin can move users from seats" }, 403);
      }

      try {
        return json(store.removeFromSeat({
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
        const result = getRoomPresenceStore(env, roomId).setEmote({
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
      const canModerate =
        String(room.owner_id) === actorId ||
        (store.isManager(actorId) && store.isMember(actorId));
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
        String(room.owner_id) === actorId ||
        (store.isManager(actorId) && store.isMember(actorId));
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
      if (url.pathname.endsWith("/join")) {
        const access = getAppDirectoryStore(env).roomAccessState(
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
        const officialMessage = getAppDirectoryStore(env).sendOfficialMessage(
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
          getAppDirectoryStore(env).listCallVerificationSubmissions(),
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
          getAppDirectoryStore(env).reviewCallVerification(
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
          getAppDirectoryStore(env).sendOfficialMessage(
            result.user_id,
            "Your Call ID verification is approved. Your ID stays Verified until Owner removes Verified status."
          );
        } else {
          getAppDirectoryStore(env).sendOfficialMessage(
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
          getAppDirectoryStore(env).verifyCallManually(
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
        getAppDirectoryStore(env).sendOfficialMessage(
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
          getAppDirectoryStore(env).revokeCallVerification(
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
        getAppDirectoryStore(env).sendOfficialMessage(
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
      const themes = getAppDirectoryStore(env).listPanelRoomThemes();
      return json({ ok: true, themes });
    }

    if (url.pathname === "/api/room-themes" && request.method === "POST") {
      if (!sessionHasPermission(session, "rooms.theme_create")) {
        return json({ ok: false, error: "Room theme create access required" }, 403);
      }
      const body = await request.json().catch(() => ({}));
      try {
        const theme = getAppDirectoryStore(env).createPanelRoomTheme(body);
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
        const result = getAppDirectoryStore(env).disableRoomTheme(themeId);
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
