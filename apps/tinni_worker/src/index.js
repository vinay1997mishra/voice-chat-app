import { DurableObject } from "cloudflare:workers";

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

async function createSession(payload, secret) {
  const sessionPayload = JSON.stringify({
    ...payload,
    exp: Date.now() + 12 * 60 * 60 * 1000,
  });
  const encoded = stringToBase64Url(sessionPayload);
  const signature = await hmacBytes(encoded, secret);
  return encoded + "." + toBase64Url(signature);
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
  }}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({
        ok: true,
        service: "tinni-star-api",
        message: "Tinni Star API online",
        version: "0.5.0",
      });
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
      return url.pathname === "/login" ? serveLogin(request, env) : env.ASSETS.fetch(request);
    }

    const session = await verifySession(request, env);
    if (!session) {
      if (url.pathname.startsWith("/api/") || url.pathname.startsWith("/auth/")) {
        return json({ ok: false, error: "Unauthorized" }, 401);
      }
      return Response.redirect(new URL("/login", request.url), 302);
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
