const encoder = new TextEncoder();

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
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function stringToBase64Url(value) {
  return toBase64Url(encoder.encode(value));
}

async function hmac(value, secret) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(value));
  return toBase64Url(new Uint8Array(signature));
}

async function createSession(email, secret) {
  const payload = JSON.stringify({
    email,
    exp: Date.now() + 12 * 60 * 60 * 1000,
  });
  const encoded = stringToBase64Url(payload);
  const signature = await hmac(encoded, secret);
  return encoded + "." + signature;
}

function decodeBase64Url(value) {
  const padded = value.replaceAll("-", "+").replaceAll("_", "/") + "===".slice((value.length + 3) % 4);
  const binary = atob(padded);
  return new Uint8Array([...binary].map((char) => char.charCodeAt(0)));
}

async function verifySession(request, env) {
  const token = getCookie(request, "tinni_owner_session");
  if (!token || !env.SESSION_SECRET || !env.OWNER_EMAIL) return false;

  const dot = token.lastIndexOf(".");
  if (dot <= 0) return false;

  const encoded = token.slice(0, dot);
  const signature = token.slice(dot + 1);
  const expected = await hmac(encoded, env.SESSION_SECRET);
  if (signature !== expected) return false;

  try {
    const payload = JSON.parse(new TextDecoder().decode(decodeBase64Url(encoded)));
    return payload.email === env.OWNER_EMAIL && Number(payload.exp) > Date.now();
  } catch {
    return false;
  }
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

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({
        ok: true,
        service: "tinni-star-api",
        message: "Tinni Star API online",
        version: "0.2.0",
      });
    }

    if (url.pathname === "/auth/login" && request.method === "POST") {
      if (!env.OWNER_EMAIL || !env.OWNER_PASSWORD || !env.SESSION_SECRET) {
        return json({ ok: false, error: "Owner login is not configured yet" }, 503);
      }

      const body = await request.json().catch(() => ({}));
      const email = String(body.email || "").trim().toLowerCase();
      const password = String(body.password || "");

      if (email !== String(env.OWNER_EMAIL).trim().toLowerCase() || password !== env.OWNER_PASSWORD) {
        return json({ ok: false, error: "Invalid email or password" }, 401);
      }

      const session = await createSession(env.OWNER_EMAIL, env.SESSION_SECRET);
      return json(
        { ok: true },
        200,
        {
          "set-cookie": "tinni_owner_session=" + session + "; Path=/; Max-Age=43200; HttpOnly; Secure; SameSite=Strict",
        },
      );
    }

    if (url.pathname === "/auth/logout" && request.method === "POST") {
      return json(
        { ok: true },
        200,
        {
          "set-cookie": "tinni_owner_session=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Strict",
        },
      );
    }

    if (isPublicAsset(url.pathname)) {
      return url.pathname === "/login" ? serveLogin(request, env) : env.ASSETS.fetch(request);
    }

    const authenticated = await verifySession(request, env);
    if (!authenticated) {
      if (url.pathname.startsWith("/api/") || url.pathname.startsWith("/auth/")) {
        return json({ ok: false, error: "Unauthorized" }, 401);
      }
      return Response.redirect(new URL("/login", request.url), 302);
    }

    if (url.pathname === "/auth/session" && request.method === "GET") {
      return json({ ok: true, email: env.OWNER_EMAIL });
    }

    if (url.pathname.startsWith("/api/")) {
      return json({ ok: false, error: "API endpoint not implemented" }, 404);
    }

    return env.ASSETS.fetch(request);
  },
};
