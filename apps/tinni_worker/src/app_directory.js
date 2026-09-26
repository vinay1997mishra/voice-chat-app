import { DurableObject } from "cloudflare:workers";

const MAX_AVATAR_DATA_LENGTH = 450000;
const MAX_ROOM_THEME_ASSET_LENGTH = 2500000;
const ROOM_THEME_USER_PRICE_COINS = 10000000;
const ROOM_THEME_USER_DURATION_MS = 7 * 24 * 60 * 60 * 1000;
const VALID_GENDERS = new Set(["male", "female"]);
const encoder = new TextEncoder();

function toBase64Url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function fromBase64Url(value) {
  let base64 = String(value || "").replaceAll("-", "+").replaceAll("_", "/");
  while (base64.length % 4) base64 += "=";
  const binary = atob(base64);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function safeEqualBytes(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let index = 0; index < a.length; index += 1) {
    diff |= a[index] ^ b[index];
  }
  return diff === 0;
}

async function deriveSecret(secret, saltBytes, iterations) {
  const material = await crypto.subtle.importKey(
    "raw",
    encoder.encode(String(secret)),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      hash: "SHA-256",
      salt: saltBytes,
      iterations,
    },
    material,
    256,
  );
  return new Uint8Array(bits);
}

function randomOtp() {
  const values = new Uint32Array(1);
  const limit = Math.floor(0x100000000 / 1000000) * 1000000;
  do {
    crypto.getRandomValues(values);
  } while (values[0] >= limit);
  return String(values[0] % 1000000).padStart(6, "0");
}

function cleanText(value, maxLength) {
  return String(value || "").trim().slice(0, maxLength);
}

function wordCount(value) {
  const text = String(value || "").trim();
  return text ? text.split(/\s+/).length : 0;
}

function rowToUser(row) {
  if (!row) return null;
  return {
    user_id: String(row.user_id),
    google_sub: String(row.google_sub),
    auth_provider: String(row.auth_provider || "google"),
    auth_subject: String(row.auth_subject || row.google_sub),
    email: String(row.email),
    display_name: String(row.display_name),
    age: Number(row.age),
    signature: String(row.signature || ""),
    country_code: String(row.country_code),
    country_name: String(row.country_name),
    flag_emoji: String(row.flag_emoji),
    gender: String(row.gender),
    avatar_data_url: row.avatar_data_url ? String(row.avatar_data_url) : null,
    created_at: Number(row.created_at),
    updated_at: Number(row.updated_at),
  };
}

function rowToRoom(row) {
  if (!row) return null;
  return {
    id: String(row.id),
    owner_id: String(row.owner_id),
    title: String(row.title),
    country_code: String(row.country_code),
    country_name: String(row.country_name),
    flag_emoji: String(row.flag_emoji),
    seat_count: Number(row.seat_count),
    party_mode: String(row.party_mode),
    locked: Number(row.locked) === 1,
    photo_data_url: row.photo_data_url ? String(row.photo_data_url) : null,
    theme_id: row.theme_id ? String(row.theme_id) : "royal-dark",
    theme_asset: row.theme_asset ? String(row.theme_asset) : null,
    created_at: Number(row.created_at),
    updated_at: Number(row.updated_at),
    owner_name: row.owner_name ? String(row.owner_name) : null,
    owner_avatar_data_url: row.owner_avatar_data_url
      ? String(row.owner_avatar_data_url)
      : null,
    owner_flag_emoji: row.owner_flag_emoji
      ? String(row.owner_flag_emoji)
      : null,
  };
}

function rowToRoomTheme(row) {
  if (!row) return null;
  return {
    id: String(row.id),
    name: String(row.name),
    asset: String(row.asset),
    source: String(row.source),
    room_id: row.room_id ? String(row.room_id) : null,
    creator_user_id: row.creator_user_id ? String(row.creator_user_id) : null,
    price_coins: Number(row.price_coins || 0),
    created_at: Number(row.created_at),
    starts_at:
      row.starts_at === null || row.starts_at === undefined
        ? null
        : Number(row.starts_at),
    expires_at:
      row.expires_at === null || row.expires_at === undefined
        ? null
        : Number(row.expires_at),
    enabled: Number(row.enabled) === 1,
  };
}

function validateRoomThemePolicy(nameValue, assetValue) {
  const name = cleanText(nameValue, 60);
  const asset = String(assetValue || "").trim();
  const combined = (name + " " + asset).toLowerCase();

  const blocked = [
    "porn",
    "porno",
    "nude",
    "nudity",
    "nsfw",
    "xxx",
    "erotic",
    "sexual",
    "sex ",
    " sex",
    "politic",
    "election",
    "campaign",
    "candidate",
    "ballot",
    "vote ",
    " voting",
  ];
  if (blocked.some((term) => combined.includes(term))) {
    throw new Error("Sexual or political room themes are not allowed");
  }
  if (!name) throw new Error("Theme name is required");
  if (!asset) throw new Error("Theme image is required");
  if (asset.length > MAX_ROOM_THEME_ASSET_LENGTH) {
    throw new Error("Theme image is too large");
  }
  if (
    !asset.startsWith("data:image/") &&
    !asset.startsWith("https://")
  ) {
    throw new Error("Theme image must be an image upload or HTTPS URL");
  }
  return { name, asset };
}

export class AppDirectoryStore extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS app_users (
        user_id TEXT PRIMARY KEY,
        google_sub TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        age INTEGER NOT NULL,
        signature TEXT NOT NULL DEFAULT '',
        country_code TEXT NOT NULL,
        country_name TEXT NOT NULL,
        flag_emoji TEXT NOT NULL,
        gender TEXT NOT NULL,
        avatar_data_url TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_app_users_google_sub ON app_users(google_sub);
      CREATE INDEX IF NOT EXISTS idx_app_users_email ON app_users(email);

      CREATE TABLE IF NOT EXISTS app_rooms (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        country_code TEXT NOT NULL,
        country_name TEXT NOT NULL,
        flag_emoji TEXT NOT NULL,
        seat_count INTEGER NOT NULL,
        party_mode TEXT NOT NULL,
        locked INTEGER NOT NULL DEFAULT 0,
        photo_data_url TEXT,
        theme_id TEXT NOT NULL DEFAULT 'royal-dark',
        theme_asset TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_app_rooms_created ON app_rooms(created_at DESC);

      CREATE TABLE IF NOT EXISTS room_themes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        asset TEXT NOT NULL,
        source TEXT NOT NULL,
        room_id TEXT,
        creator_user_id TEXT,
        price_coins INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        starts_at INTEGER,
        expires_at INTEGER,
        enabled INTEGER NOT NULL DEFAULT 1
      );
      CREATE INDEX IF NOT EXISTS idx_room_themes_room
        ON room_themes(room_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_room_themes_expiry
        ON room_themes(expires_at);

      CREATE TABLE IF NOT EXISTS room_locks (
        room_id TEXT PRIMARY KEY,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        generation INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_lock_attempts (
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        generation INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(room_id, user_id)
      );

      CREATE TABLE IF NOT EXISTS room_access_grants (
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        generation INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(room_id, user_id)
      );

      CREATE TABLE IF NOT EXISTS app_follows (
        follower_id TEXT NOT NULL,
        target_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(follower_id, target_id)
      );
      CREATE INDEX IF NOT EXISTS idx_app_follows_target
        ON app_follows(target_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS app_blocks (
        blocker_id TEXT NOT NULL,
        target_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(blocker_id, target_id)
      );
      CREATE INDEX IF NOT EXISTS idx_app_blocks_target
        ON app_blocks(target_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS direct_messages (
        id TEXT PRIMARY KEY,
        from_user_id TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_direct_messages_pair
        ON direct_messages(from_user_id, to_user_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS app_calls (
        id TEXT PRIMARY KEY,
        caller_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        media TEXT NOT NULL,
        state TEXT NOT NULL,
        room_id TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_app_calls_receiver
        ON app_calls(receiver_id, state, updated_at DESC);
      CREATE INDEX IF NOT EXISTS idx_app_calls_caller
        ON app_calls(caller_id, state, updated_at DESC);

      CREATE TABLE IF NOT EXISTS app_user_identities (
        provider TEXT NOT NULL,
        subject TEXT NOT NULL,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(provider, subject)
      );
      CREATE INDEX IF NOT EXISTS idx_app_user_identities_user
        ON app_user_identities(user_id);

      CREATE TABLE IF NOT EXISTS facebook_login_requests (
        request_id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        facebook_id TEXT,
        email TEXT,
        display_name TEXT,
        picture_url TEXT,
        error TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS email_otp_requests (
        request_id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        otp_salt TEXT NOT NULL,
        otp_hash TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        verified INTEGER NOT NULL DEFAULT 0,
        expires_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_email_otp_email
        ON email_otp_requests(email);

      CREATE TABLE IF NOT EXISTS email_password_credentials (
        email TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        auth_version INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    `);

    for (const migration of [
      "ALTER TABLE app_users ADD COLUMN auth_provider TEXT NOT NULL DEFAULT 'google'",
      "ALTER TABLE room_themes ADD COLUMN starts_at INTEGER",
      "ALTER TABLE app_rooms ADD COLUMN theme_id TEXT NOT NULL DEFAULT 'royal-dark'",
      "ALTER TABLE app_rooms ADD COLUMN theme_asset TEXT",
      "ALTER TABLE app_users ADD COLUMN auth_subject TEXT"
    ]) {
      try {
        this.ctx.storage.sql.exec(migration);
      } catch (error) {
        const message = String(error?.message || "").toLowerCase();
        if (!message.includes("duplicate") && !message.includes("already exists")) {
          throw error;
        }
      }
    }

    this.ctx.storage.sql.exec(
      "UPDATE app_users SET auth_subject = google_sub WHERE auth_subject IS NULL OR auth_subject = ''"
    );
    this.ctx.storage.sql.exec(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_app_users_auth_identity ON app_users(auth_provider, auth_subject)"
    );
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO app_user_identities
        (provider, subject, user_id, created_at)
       SELECT auth_provider, auth_subject, user_id, created_at
         FROM app_users
        WHERE auth_subject IS NOT NULL AND auth_subject != ''`
    );
  }

  _nextUserId() {
    for (let attempt = 0; attempt < 50; attempt += 1) {
      const values = new Uint32Array(1);
      crypto.getRandomValues(values);
      const value = 10000000 + (values[0] % 90000000);
      const userId = String(value);
      const existing = this.ctx.storage.sql.exec(
        "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1",
        userId,
      ).toArray()[0];
      if (!existing) return userId;
    }
    throw new Error("Unable to allocate user ID");
  }

  async getUserByProvider(providerValue, subjectValue) {
    const provider = String(providerValue || "").trim().toLowerCase();
    const subject = String(subjectValue || "").trim();
    if (!provider || !subject) return null;

    let row = this.ctx.storage.sql.exec(
      `SELECT u.*
         FROM app_user_identities i
         JOIN app_users u ON u.user_id = i.user_id
        WHERE i.provider = ? AND i.subject = ?
        LIMIT 1`,
      provider,
      subject,
    ).toArray()[0];

    if (!row && provider === "google") {
      row = this.ctx.storage.sql.exec(
        `SELECT * FROM app_users WHERE google_sub = ? LIMIT 1`,
        subject,
      ).toArray()[0];
    }
    return rowToUser(row);
  }

  async getUserByEmail(emailValue) {
    const email = String(emailValue || "").trim().toLowerCase();
    if (!email) return null;
    const row = this.ctx.storage.sql.exec(
      `SELECT * FROM app_users WHERE email = ? LIMIT 1`,
      email,
    ).toArray()[0];
    return rowToUser(row);
  }

  async linkIdentity(userIdValue, providerValue, subjectValue) {
    const userId = String(userIdValue || "").trim();
    const provider = String(providerValue || "").trim().toLowerCase();
    const subject = String(subjectValue || "").trim();
    if (!userId || !provider || !subject) {
      throw new Error("Login identity is incomplete");
    }

    const existing = await this.getUserByProvider(provider, subject);
    if (existing && existing.user_id !== userId) {
      throw new Error("This login identity is already linked to another account");
    }

    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO app_user_identities
        (provider, subject, user_id, created_at)
       VALUES (?, ?, ?, ?)`,
      provider,
      subject,
      userId,
      Date.now(),
    );
    return this.getUserById(userId);
  }

  async getUserByGoogleSub(googleSubValue) {
    return this.getUserByProvider("google", googleSubValue);
  }

  async getUserById(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return null;
    const row = this.ctx.storage.sql.exec(
      `SELECT * FROM app_users WHERE user_id = ? LIMIT 1`,
      userId,
    ).toArray()[0];
    return rowToUser(row);
  }

  async createUser(input) {
    const provider = cleanText(input?.auth_provider || "google", 24).toLowerCase();
    const subject = cleanText(input?.auth_subject || input?.google_sub, 160);
    const googleSub = provider === "google" ? subject : provider + ":" + subject;
    const email = cleanText(input?.email, 240).toLowerCase();
    const displayName = cleanText(input?.display_name, 40);
    const age = Number(input?.age);
    const signature = cleanText(input?.signature, 3000);
    const countryCode = cleanText(input?.country_code, 2).toUpperCase();
    const countryName = cleanText(input?.country_name, 80);
    const flagEmoji = cleanText(input?.flag_emoji, 16);
    const gender = cleanText(input?.gender, 12).toLowerCase();
    const avatarDataUrl = input?.avatar_data_url
      ? String(input.avatar_data_url)
      : null;

    if (!["google", "facebook", "email"].includes(provider)) {
      throw new Error("Unsupported login provider");
    }
    if (!subject) throw new Error("Login account identity is required");
    if (!email || !email.includes("@")) throw new Error("Valid account email is required");
    if (!displayName) throw new Error("Name is required");
    if (!Number.isInteger(age) || age < 1 || age > 120) throw new Error("Age must be between 1 and 120");
    if (!countryCode || !countryName || !flagEmoji) throw new Error("Country and flag are required");
    if (!VALID_GENDERS.has(gender)) throw new Error("Gender must be male or female");
    if (wordCount(signature) > 150) throw new Error("Signature can contain at most 150 words");
    if (avatarDataUrl && avatarDataUrl.length > MAX_AVATAR_DATA_LENGTH) {
      throw new Error("Profile photo is too large");
    }
    if (avatarDataUrl && !avatarDataUrl.startsWith("data:image/")) {
      throw new Error("Profile photo format is invalid");
    }

    const existing = await this.getUserByProvider(provider, subject);
    if (existing) return existing;

    const userId = this._nextUserId();
    const now = Date.now();
    try {
      this.ctx.storage.sql.exec(
        `INSERT INTO app_users
          (user_id, google_sub, auth_provider, auth_subject, email,
           display_name, age, signature, country_code, country_name,
           flag_emoji, gender, avatar_data_url, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        userId,
        googleSub,
        provider,
        subject,
        email,
        displayName,
        age,
        signature,
        countryCode,
        countryName,
        flagEmoji,
        gender,
        avatarDataUrl,
        now,
        now,
      );
    } catch (error) {
      if (String(error?.message || "").toLowerCase().includes("unique")) {
        throw new Error("This login account/email is already registered");
      }
      throw error;
    }
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO app_user_identities
        (provider, subject, user_id, created_at)
       VALUES (?, ?, ?, ?)`,
      provider,
      subject,
      userId,
      now,
    );
    return this.getUserById(userId);
  }

  async startEmailOtp(emailValue) {
    const email = cleanText(emailValue, 240).toLowerCase();
    if (!email || !email.includes("@")) {
      throw new Error("Valid email is required");
    }

    const now = Date.now();
    const recent = this.ctx.storage.sql.exec(
      `SELECT created_at FROM email_otp_requests
        WHERE email = ?
        ORDER BY created_at DESC
        LIMIT 1`,
      email,
    ).toArray()[0];
    if (recent && now - Number(recent.created_at) < 60000) {
      throw new Error("Please wait before requesting another OTP");
    }

    const otp = randomOtp();
    const salt = crypto.getRandomValues(new Uint8Array(16));
    const hash = await deriveSecret(otp, salt, 120000);
    const requestId = crypto.randomUUID() + crypto.randomUUID().replaceAll("-", "");

    this.ctx.storage.sql.exec(
      `INSERT INTO email_otp_requests
        (request_id, email, otp_salt, otp_hash, attempts, verified,
         expires_at, created_at, updated_at)
       VALUES (?, ?, ?, ?, 0, 0, ?, ?, ?)`,
      requestId,
      email,
      toBase64Url(salt),
      toBase64Url(hash),
      now + 10 * 60 * 1000,
      now,
      now,
    );

    return {
      request_id: requestId,
      email,
      otp,
      expires_at: now + 10 * 60 * 1000,
    };
  }

  async verifyEmailOtp(requestIdValue, otpValue) {
    const requestId = String(requestIdValue || "").trim();
    const otp = String(otpValue || "").trim();
    const row = this.ctx.storage.sql.exec(
      `SELECT * FROM email_otp_requests
        WHERE request_id = ?
        LIMIT 1`,
      requestId,
    ).toArray()[0];

    if (!row) throw new Error("OTP request not found");
    if (Number(row.verified) === 1) {
      return {
        email: String(row.email),
        profile_required: !(await this.getUserByEmail(row.email)),
      };
    }
    if (Date.now() > Number(row.expires_at)) throw new Error("OTP has expired");
    if (Number(row.attempts) >= 5) throw new Error("Too many OTP attempts");
    if (!/^\d{6}$/.test(otp)) throw new Error("Enter the 6-digit OTP");

    const nextAttempts = Number(row.attempts) + 1;
    this.ctx.storage.sql.exec(
      `UPDATE email_otp_requests
          SET attempts = ?, updated_at = ?
        WHERE request_id = ?`,
      nextAttempts,
      Date.now(),
      requestId,
    );

    const actual = await deriveSecret(
      otp,
      fromBase64Url(row.otp_salt),
      120000,
    );
    const expected = fromBase64Url(row.otp_hash);
    if (!safeEqualBytes(actual, expected)) {
      throw new Error("Incorrect OTP");
    }

    this.ctx.storage.sql.exec(
      `UPDATE email_otp_requests
          SET verified = 1, updated_at = ?
        WHERE request_id = ?`,
      Date.now(),
      requestId,
    );

    return {
      email: String(row.email),
      profile_required: !(await this.getUserByEmail(row.email)),
    };
  }

  async completeEmailPassword(requestIdValue, passwordValue, profile) {
    const requestId = String(requestIdValue || "").trim();
    const password = String(passwordValue || "");
    if (password.length < 8 || password.length > 128) {
      throw new Error("Tinni password must be 8 to 128 characters");
    }

    const row = this.ctx.storage.sql.exec(
      `SELECT * FROM email_otp_requests
        WHERE request_id = ?
        LIMIT 1`,
      requestId,
    ).toArray()[0];
    if (!row || Number(row.verified) !== 1) {
      throw new Error("Email OTP verification is required");
    }
    if (Date.now() > Number(row.expires_at)) {
      throw new Error("Email verification has expired");
    }

    const email = String(row.email).toLowerCase();
    let user = await this.getUserByEmail(email);

    if (!user) {
      if (!profile || typeof profile !== "object") {
        throw new Error("Profile details are required");
      }
      user = await this.createUser({
        auth_provider: "email",
        auth_subject: email,
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
    } else {
      await this.linkIdentity(user.user_id, "email", email);
      user = await this.getUserById(user.user_id);
    }

    const salt = crypto.getRandomValues(new Uint8Array(16));
    const hash = await deriveSecret(password, salt, 210000);
    const now = Date.now();
    const existing = this.ctx.storage.sql.exec(
      `SELECT auth_version FROM email_password_credentials
        WHERE email = ?
        LIMIT 1`,
      email,
    ).toArray()[0];
    const authVersion = existing ? Number(existing.auth_version || 1) + 1 : 1;

    this.ctx.storage.sql.exec(
      `INSERT INTO email_password_credentials
        (email, user_id, password_salt, password_hash, auth_version,
         created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(email) DO UPDATE SET
         user_id = excluded.user_id,
         password_salt = excluded.password_salt,
         password_hash = excluded.password_hash,
         auth_version = excluded.auth_version,
         updated_at = excluded.updated_at`,
      email,
      user.user_id,
      toBase64Url(salt),
      toBase64Url(hash),
      authVersion,
      now,
      now,
    );

    return {
      user,
      email,
      auth_version: authVersion,
    };
  }

  async getEmailCredentialVersion(emailValue) {
    const email = cleanText(emailValue, 240).toLowerCase();
    if (!email) return null;
    const row = this.ctx.storage.sql.exec(
      `SELECT auth_version FROM email_password_credentials
        WHERE email = ?
        LIMIT 1`,
      email,
    ).toArray()[0];
    return row ? Number(row.auth_version || 1) : null;
  }

  async verifyEmailPassword(emailValue, passwordValue) {
    const email = cleanText(emailValue, 240).toLowerCase();
    const password = String(passwordValue || "");
    if (!email || !password) return null;

    const row = this.ctx.storage.sql.exec(
      `SELECT * FROM email_password_credentials
        WHERE email = ?
        LIMIT 1`,
      email,
    ).toArray()[0];
    if (!row) return null;

    const actual = await deriveSecret(
      password,
      fromBase64Url(row.password_salt),
      210000,
    );
    const expected = fromBase64Url(row.password_hash);
    if (!safeEqualBytes(actual, expected)) return null;

    const user = await this.getUserById(row.user_id);
    if (!user) return null;
    return {
      user,
      email,
      auth_version: Number(row.auth_version || 1),
    };
  }

  async startFacebookLogin() {
    const now = Date.now();
    const requestId = crypto.randomUUID() + crypto.randomUUID().replaceAll("-", "");
    this.ctx.storage.sql.exec(
      `INSERT INTO facebook_login_requests
        (request_id, status, created_at, updated_at)
       VALUES (?, 'pending', ?, ?)`,
      requestId,
      now,
      now,
    );
    return { request_id: requestId, created_at: now };
  }

  async getFacebookLogin(requestIdValue) {
    const requestId = String(requestIdValue || "").trim();
    if (!requestId) return null;
    const row = this.ctx.storage.sql.exec(
      `SELECT * FROM facebook_login_requests
        WHERE request_id = ?
        LIMIT 1`,
      requestId,
    ).toArray()[0];
    if (!row) return null;
    if (Date.now() - Number(row.created_at) > 10 * 60 * 1000) {
      return { request_id: requestId, status: "expired" };
    }
    return {
      request_id: requestId,
      status: String(row.status),
      facebook_id: row.facebook_id ? String(row.facebook_id) : null,
      email: row.email ? String(row.email) : null,
      display_name: row.display_name ? String(row.display_name) : null,
      picture_url: row.picture_url ? String(row.picture_url) : null,
      error: row.error ? String(row.error) : null,
      created_at: Number(row.created_at),
      updated_at: Number(row.updated_at),
    };
  }

  async completeFacebookLogin(requestIdValue, profile) {
    const requestId = String(requestIdValue || "").trim();
    const facebookId = cleanText(profile?.id, 160);
    if (!requestId || !facebookId) throw new Error("Invalid Facebook login response");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `UPDATE facebook_login_requests
          SET status = 'authorized',
              facebook_id = ?,
              email = ?,
              display_name = ?,
              picture_url = ?,
              error = NULL,
              updated_at = ?
        WHERE request_id = ? AND status = 'pending'`,
      facebookId,
      cleanText(profile?.email, 240).toLowerCase() || null,
      cleanText(profile?.name, 80) || "Facebook User",
      cleanText(profile?.picture, 2000) || null,
      now,
      requestId,
    );
    return this.getFacebookLogin(requestId);
  }

  async failFacebookLogin(requestIdValue, messageValue) {
    const requestId = String(requestIdValue || "").trim();
    if (!requestId) return;
    this.ctx.storage.sql.exec(
      `UPDATE facebook_login_requests
          SET status = 'failed', error = ?, updated_at = ?
        WHERE request_id = ?`,
      cleanText(messageValue, 500) || "Facebook login failed",
      Date.now(),
      requestId,
    );
  }

  async listUsers() {
    return this.ctx.storage.sql.exec(
      `SELECT user_id, google_sub, email, display_name, age, signature,
              country_code, country_name, flag_emoji, gender, avatar_data_url,
              created_at, updated_at
         FROM app_users
        ORDER BY created_at DESC
        LIMIT 500`,
    ).toArray().map(rowToUser);
  }

  listFollowing(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return [];
    return this.ctx.storage.sql.exec(
      `SELECT target_id
         FROM app_follows
        WHERE follower_id = ?
        ORDER BY created_at DESC`,
      userId,
    ).toArray().map((row) => String(row.target_id));
  }

  listFriends(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return [];
    return this.ctx.storage.sql.exec(
      `SELECT u.user_id, u.display_name
         FROM app_follows mine
         JOIN app_follows theirs
           ON theirs.follower_id = mine.target_id
          AND theirs.target_id = mine.follower_id
         JOIN app_users u ON u.user_id = mine.target_id
        WHERE mine.follower_id = ?
          AND NOT EXISTS (
            SELECT 1
              FROM app_blocks b
             WHERE (b.blocker_id = ? AND b.target_id = u.user_id)
                OR (b.blocker_id = u.user_id AND b.target_id = ?)
          )
        ORDER BY mine.created_at DESC`,
      userId,
      userId,
      userId,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      display_name: String(row.display_name || row.user_id),
    }));
  }

  areFriends(firstUserIdValue, secondUserIdValue) {
    const firstUserId = String(firstUserIdValue || "").trim();
    const secondUserId = String(secondUserIdValue || "").trim();
    if (!firstUserId || !secondUserId || firstUserId === secondUserId) {
      return false;
    }
    const row = this.ctx.storage.sql.exec(
      `SELECT 1 AS ok
         FROM app_follows a
         JOIN app_follows b
           ON b.follower_id = a.target_id
          AND b.target_id = a.follower_id
        WHERE a.follower_id = ?
          AND a.target_id = ?
        LIMIT 1`,
      firstUserId,
      secondUserId,
    ).toArray()[0];
    return Boolean(row) && !this.isBlockedBetween(firstUserId, secondUserId);
  }

  setFollowing(userIdValue, targetIdValue, followingValue) {
    const userId = String(userIdValue || "").trim();
    const targetId = String(targetIdValue || "").trim();
    if (!userId || !targetId) throw new Error("user IDs are required");
    if (userId === targetId) throw new Error("You cannot follow yourself");

    const target = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1",
      targetId,
    ).toArray()[0];
    if (!target) throw new Error("User not found");

    if (followingValue) {
      this.ctx.storage.sql.exec(
        `INSERT INTO app_follows (follower_id, target_id, created_at)
         VALUES (?, ?, ?)
         ON CONFLICT(follower_id, target_id) DO UPDATE SET
           created_at = excluded.created_at`,
        userId,
        targetId,
        Date.now(),
      );
    } else {
      this.ctx.storage.sql.exec(
        "DELETE FROM app_follows WHERE follower_id = ? AND target_id = ?",
        userId,
        targetId,
      );
    }

    return {
      ok: true,
      target_user_id: targetId,
      following: Boolean(followingValue),
    };
  }

  listBlocked(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return [];
    return this.ctx.storage.sql.exec(
      `SELECT target_id
         FROM app_blocks
        WHERE blocker_id = ?
        ORDER BY created_at DESC`,
      userId,
    ).toArray().map((row) => String(row.target_id));
  }

  isBlockedBetween(firstUserIdValue, secondUserIdValue) {
    const firstUserId = String(firstUserIdValue || "").trim();
    const secondUserId = String(secondUserIdValue || "").trim();
    if (!firstUserId || !secondUserId) return false;
    const row = this.ctx.storage.sql.exec(
      `SELECT blocker_id
         FROM app_blocks
        WHERE (blocker_id = ? AND target_id = ?)
           OR (blocker_id = ? AND target_id = ?)
        LIMIT 1`,
      firstUserId,
      secondUserId,
      secondUserId,
      firstUserId,
    ).toArray()[0];
    return Boolean(row);
  }

  setBlocked(userIdValue, targetIdValue, blockedValue) {
    const userId = String(userIdValue || "").trim();
    const targetId = String(targetIdValue || "").trim();
    if (!userId || !targetId) throw new Error("user IDs are required");
    if (userId === targetId) throw new Error("You cannot block yourself");

    const target = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1",
      targetId,
    ).toArray()[0];
    if (!target) throw new Error("User not found");

    if (blockedValue) {
      this.ctx.storage.sql.exec(
        `INSERT INTO app_blocks (blocker_id, target_id, created_at)
         VALUES (?, ?, ?)
         ON CONFLICT(blocker_id, target_id) DO UPDATE SET
           created_at = excluded.created_at`,
        userId,
        targetId,
        Date.now(),
      );
      this.ctx.storage.sql.exec(
        "DELETE FROM app_follows WHERE follower_id = ? AND target_id = ?",
        userId,
        targetId,
      );
    } else {
      this.ctx.storage.sql.exec(
        "DELETE FROM app_blocks WHERE blocker_id = ? AND target_id = ?",
        userId,
        targetId,
      );
    }

    return {
      ok: true,
      target_user_id: targetId,
      blocked: Boolean(blockedValue),
    };
  }

  createCall(callerIdValue, receiverIdValue, mediaValue = "voice") {
    const callerId = String(callerIdValue || "").trim();
    const receiverId = String(receiverIdValue || "").trim();
    const media = String(mediaValue || "voice").toLowerCase();
    if (!callerId || !receiverId) throw new Error("user IDs are required");
    if (callerId === receiverId) throw new Error("You cannot call yourself");
    if (!this.areFriends(callerId, receiverId)) {
      throw new Error("Calls are limited to mutual friends");
    }
    if (media !== "voice") throw new Error("Only voice calls are supported");

    this.ctx.storage.sql.exec(
      `UPDATE app_calls
          SET state = 'ended', updated_at = ?
        WHERE (caller_id = ? OR receiver_id = ?)
          AND state IN ('ringing', 'accepted')`,
      Date.now(),
      callerId,
      callerId,
    );

    const now = Date.now();
    const id = "call-" + now.toString(36) + "-" + crypto.randomUUID().slice(0, 8);
    const roomId = "call-" + id;
    this.ctx.storage.sql.exec(
      `INSERT INTO app_calls
        (id, caller_id, receiver_id, media, state, room_id, created_at, updated_at)
       VALUES (?, ?, ?, ?, 'ringing', ?, ?, ?)`,
      id,
      callerId,
      receiverId,
      media,
      roomId,
      now,
      now,
    );
    return this.getCall(id);
  }

  getCall(callIdValue) {
    const callId = String(callIdValue || "").trim();
    if (!callId) return null;
    const row = this.ctx.storage.sql.exec(
      `SELECT c.*, caller.display_name AS caller_name,
                receiver.display_name AS receiver_name
         FROM app_calls c
         JOIN app_users caller ON caller.user_id = c.caller_id
         JOIN app_users receiver ON receiver.user_id = c.receiver_id
        WHERE c.id = ?
        LIMIT 1`,
      callId,
    ).toArray()[0];
    if (!row) return null;
    return {
      id: String(row.id),
      caller_id: String(row.caller_id),
      caller_name: String(row.caller_name || row.caller_id),
      receiver_id: String(row.receiver_id),
      receiver_name: String(row.receiver_name || row.receiver_id),
      media: String(row.media),
      state: String(row.state),
      room_id: String(row.room_id),
      created_at: Number(row.created_at),
      updated_at: Number(row.updated_at),
    };
  }

  incomingCall(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return null;
    const row = this.ctx.storage.sql.exec(
      `SELECT id
         FROM app_calls
        WHERE receiver_id = ?
          AND state = 'ringing'
          AND updated_at >= ?
        ORDER BY updated_at DESC
        LIMIT 1`,
      userId,
      Date.now() - 120000,
    ).toArray()[0];
    if (!row) return null;
    return this.getCall(row.id);
  }

  respondCall(userIdValue, callIdValue, acceptValue) {
    const userId = String(userIdValue || "").trim();
    const call = this.getCall(callIdValue);
    if (!call) throw new Error("Call not found");
    if (call.receiver_id !== userId) throw new Error("Only the receiver can answer");
    if (call.state !== "ringing") return call;
    this.ctx.storage.sql.exec(
      "UPDATE app_calls SET state = ?, updated_at = ? WHERE id = ?",
      acceptValue ? "accepted" : "rejected",
      Date.now(),
      call.id,
    );
    return this.getCall(call.id);
  }

  endCall(userIdValue, callIdValue) {
    const userId = String(userIdValue || "").trim();
    const call = this.getCall(callIdValue);
    if (!call) throw new Error("Call not found");
    if (call.caller_id !== userId && call.receiver_id !== userId) {
      throw new Error("Not a call participant");
    }
    this.ctx.storage.sql.exec(
      "UPDATE app_calls SET state = 'ended', updated_at = ? WHERE id = ?",
      Date.now(),
      call.id,
    );
    return this.getCall(call.id);
  }

  callRoomAccess(userIdValue, roomIdValue) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    if (!userId || !roomId.startsWith("call-")) return { allowed: false };
    const row = this.ctx.storage.sql.exec(
      `SELECT id, caller_id, receiver_id, state
         FROM app_calls
        WHERE room_id = ?
          AND state IN ('ringing', 'accepted')
          AND (caller_id = ? OR receiver_id = ?)
        LIMIT 1`,
      roomId,
      userId,
      userId,
    ).toArray()[0];
    return row
      ? { allowed: true, call_id: String(row.id), state: String(row.state) }
      : { allowed: false };
  }

  listDirectMessages(userIdValue, peerUserIdValue, limitValue = 200) {
    const userId = String(userIdValue || "").trim();
    const peerUserId = String(peerUserIdValue || "").trim();
    const limit = Math.max(1, Math.min(500, Number(limitValue) || 200));
    if (!userId || !peerUserId) throw new Error("user IDs are required");
    if (this.isBlockedBetween(userId, peerUserId)) {
      return [];
    }

    return this.ctx.storage.sql.exec(
      `SELECT id, from_user_id, to_user_id, text, created_at
         FROM direct_messages
        WHERE (from_user_id = ? AND to_user_id = ?)
           OR (from_user_id = ? AND to_user_id = ?)
        ORDER BY created_at ASC
        LIMIT ?`,
      userId,
      peerUserId,
      peerUserId,
      userId,
      limit,
    ).toArray().map((row) => ({
      id: String(row.id),
      from: String(row.from_user_id),
      to: String(row.to_user_id),
      text: String(row.text),
      created_at: Number(row.created_at),
    }));
  }

  sendDirectMessage(fromUserIdValue, toUserIdValue, textValue) {
    const fromUserId = String(fromUserIdValue || "").trim();
    const toUserId = String(toUserIdValue || "").trim();
    const text = cleanText(textValue, 1000);
    if (!fromUserId || !toUserId) throw new Error("user IDs are required");
    if (!text) throw new Error("Message cannot be empty");
    if (this.isBlockedBetween(fromUserId, toUserId)) {
      throw new Error("Messaging is unavailable because one of these users is blocked");
    }

    const target = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1",
      toUserId,
    ).toArray()[0];
    if (!target) throw new Error("User not found");

    const now = Date.now();
    const id =
      "dm-" + now.toString(36) + "-" + crypto.randomUUID().slice(0, 8);
    this.ctx.storage.sql.exec(
      `INSERT INTO direct_messages
        (id, from_user_id, to_user_id, text, created_at)
       VALUES (?, ?, ?, ?, ?)`,
      id,
      fromUserId,
      toUserId,
      text,
      now,
    );
    return {
      id,
      from: fromUserId,
      to: toUserId,
      text,
      created_at: now,
    };
  }


  sendOfficialMessage(toUserIdValue, textValue, contextValue = {}) {
    const toUserId = String(toUserIdValue || "").trim();
    const text = cleanText(textValue, 2000);
    if (!toUserId) throw new Error("Target user ID is required");
    if (!text) throw new Error("Message cannot be empty");

    const target = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1",
      toUserId,
    ).toArray()[0];
    if (!target) throw new Error("User not found");

    const now = Date.now();
    const id =
      "official-" + now.toString(36) + "-" + crypto.randomUUID().slice(0, 8);

    this.ctx.storage.sql.exec(
      `INSERT INTO direct_messages
        (id, from_user_id, to_user_id, text, created_at)
       VALUES (?, 'tinni-official', ?, ?, ?)`,
      id,
      toUserId,
      text,
      now,
    );

    return {
      id,
      from: "tinni-official",
      from_name: "Tinni Official",
      to: toUserId,
      text,
      created_at: now,
      context: contextValue && typeof contextValue === "object"
        ? contextValue
        : {},
    };
  }

    async listRooms() {
    this._pruneRoomThemes();
    return this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name,
              u.avatar_data_url AS owner_avatar_data_url,
              u.flag_emoji AS owner_flag_emoji
         FROM app_rooms r
         JOIN app_users u ON u.user_id = r.owner_id
        ORDER BY r.created_at DESC
        LIMIT 500`,
    ).toArray().map(rowToRoom);
  }

  _pruneRoomThemes(now = Date.now()) {
    this.ctx.storage.sql.exec(
      "UPDATE room_themes SET enabled = 0 WHERE expires_at IS NOT NULL AND expires_at <= ?",
      now,
    );
    this.ctx.storage.sql.exec(
      `UPDATE app_rooms
          SET theme_id = 'royal-dark',
              theme_asset = NULL,
              updated_at = ?
        WHERE theme_id IN (
          SELECT id
            FROM room_themes
           WHERE enabled = 0
              OR (expires_at IS NOT NULL AND expires_at <= ?)
        )`,
      now,
      now,
    );
  }

  listRoomThemes(roomIdValue) {
    const roomId = String(roomIdValue || "").trim();
    const now = Date.now();
    this._pruneRoomThemes(now);
    return this.ctx.storage.sql.exec(
      `SELECT *
         FROM room_themes
        WHERE enabled = 1
          AND (room_id IS NULL OR room_id = ?)
          AND (starts_at IS NULL OR starts_at <= ?)
          AND (expires_at IS NULL OR expires_at > ?)
        ORDER BY CASE WHEN source = 'panel' THEN 0 ELSE 1 END,
                 created_at DESC`,
      roomId,
      now,
      now,
    ).toArray().map(rowToRoomTheme);
  }

  listPanelRoomThemes() {
    const now = Date.now();
    this._pruneRoomThemes(now);
    return this.ctx.storage.sql.exec(
      `SELECT *
         FROM room_themes
        WHERE source = 'panel'
          AND enabled = 1
        ORDER BY
          CASE
            WHEN starts_at IS NULL OR starts_at <= ? THEN 0
            ELSE 1
          END,
          COALESCE(starts_at, created_at) ASC,
          created_at DESC`,
      now,
    ).toArray().map(rowToRoomTheme);
  }

    createUserRoomTheme(userIdValue, roomIdValue, input) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    const room = this._roomRow(roomId);
    if (!room) throw new Error("Room not found");
    if (String(room.owner_id) !== userId) {
      throw new Error("Only the room owner can add a custom room theme");
    }
    if (input?.policy_confirmed !== true) {
      throw new Error("Confirm the no-sexual/no-political theme policy");
    }

    const { name, asset } = validateRoomThemePolicy(
      input?.name,
      input?.asset,
    );
    const now = Date.now();
    const id =
      "theme-user-" + roomId + "-" + now.toString(36) + "-" +
      crypto.randomUUID().slice(0, 8);
    const expiresAt = now + ROOM_THEME_USER_DURATION_MS;

    this.ctx.storage.sql.exec(
      `INSERT INTO room_themes
        (id, name, asset, source, room_id, creator_user_id, price_coins,
         created_at, starts_at, expires_at, enabled)
       VALUES (?, ?, ?, 'user', ?, ?, ?, ?, ?, ?, 1)`,
      id,
      name,
      asset,
      roomId,
      userId,
      ROOM_THEME_USER_PRICE_COINS,
      now,
      now,
      expiresAt,
    );

    return rowToRoomTheme(
      this.ctx.storage.sql.exec(
        "SELECT * FROM room_themes WHERE id = ? LIMIT 1",
        id,
      ).toArray()[0],
    );
  }

  createPanelRoomTheme(input) {
    const { name, asset } = validateRoomThemePolicy(
      input?.name,
      input?.asset,
    );
    const now = Date.now();
    const permanent = input?.permanent === true;
    const rawStartsAt = input?.starts_at;
    const rawEndsAt = input?.ends_at;
    const startsAt =
      rawStartsAt === null || rawStartsAt === undefined || rawStartsAt === ""
        ? now
        : Number(rawStartsAt);
    const expiresAt =
      permanent
        ? null
        : Number(rawEndsAt);

    if (!Number.isFinite(startsAt)) {
      throw new Error("Valid start date/time is required");
    }
    if (!permanent) {
      if (!Number.isFinite(expiresAt)) {
        throw new Error("Valid end date/time is required");
      }
      if (expiresAt <= startsAt) {
        throw new Error("End date/time must be after start date/time");
      }
    }

    const id =
      "theme-panel-" + now.toString(36) + "-" +
      crypto.randomUUID().slice(0, 8);

    this.ctx.storage.sql.exec(
      `INSERT INTO room_themes
        (id, name, asset, source, room_id, creator_user_id, price_coins,
         created_at, starts_at, expires_at, enabled)
       VALUES (?, ?, ?, 'panel', NULL, NULL, 0, ?, ?, ?, 1)`,
      id,
      name,
      asset,
      now,
      startsAt,
      expiresAt,
    );

    return rowToRoomTheme(
      this.ctx.storage.sql.exec(
        "SELECT * FROM room_themes WHERE id = ? LIMIT 1",
        id,
      ).toArray()[0],
    );
  }

  disableRoomTheme(themeIdValue) {
    const themeId = String(themeIdValue || "").trim();
    if (!themeId) throw new Error("Theme ID is required");
    this.ctx.storage.sql.exec(
      "UPDATE room_themes SET enabled = 0 WHERE id = ?",
      themeId,
    );
    return { ok: true, id: themeId };
  }

    setRoomTheme(ownerIdValue, roomIdValue, input) {
    const ownerId = String(ownerIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    const themeId = String(input?.theme_id || "").trim();
    const themeAsset = input?.theme_asset == null
      ? null
      : String(input.theme_asset).trim();
    const room = this._roomRow(roomId);

    if (!room) throw new Error("Room not found");
    if (String(room.owner_id) !== ownerId) {
      throw new Error("Only the room owner can change room theme");
    }
    if (!themeId) throw new Error("theme_id is required");

    const builtIn = new Set(["royal-dark", "night-blue", "rose-gold"]);
    if (!builtIn.has(themeId)) {
      const now = Date.now();
      const theme = this.ctx.storage.sql.exec(
        `SELECT *
           FROM room_themes
          WHERE id = ?
            AND enabled = 1
            AND (room_id IS NULL OR room_id = ?)
            AND (starts_at IS NULL OR starts_at <= ?)
            AND (expires_at IS NULL OR expires_at > ?)
          LIMIT 1`,
        themeId,
        roomId,
        now,
        now,
      ).toArray()[0];
      if (!theme) throw new Error("Room theme is unavailable or expired");
      if (themeAsset && String(theme.asset) !== themeAsset) {
        throw new Error("Room theme asset mismatch");
      }
    }

    const now = Date.now();
    this.ctx.storage.sql.exec(
      `UPDATE app_rooms
          SET theme_id = ?, theme_asset = ?, updated_at = ?
        WHERE id = ?`,
      themeId,
      themeAsset || null,
      now,
      roomId,
    );

    const updated = this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name,
              u.avatar_data_url AS owner_avatar_data_url,
              u.flag_emoji AS owner_flag_emoji
         FROM app_rooms r
         JOIN app_users u ON u.user_id = r.owner_id
        WHERE r.id = ?
        LIMIT 1`,
      roomId,
    ).toArray()[0];

    return { ok: true, room: rowToRoom(updated) };
  }

    _roomRow(roomIdValue) {
    const roomId = String(roomIdValue || "").trim();
    if (!roomId) return null;
    return this.ctx.storage.sql.exec(
      "SELECT * FROM app_rooms WHERE id = ? LIMIT 1",
      roomId,
    ).toArray()[0] || null;
  }

  _roomLockRow(roomIdValue) {
    const roomId = String(roomIdValue || "").trim();
    if (!roomId) return null;
    return this.ctx.storage.sql.exec(
      "SELECT * FROM room_locks WHERE room_id = ? LIMIT 1",
      roomId,
    ).toArray()[0] || null;
  }

  roomAccessState(userIdValue, roomIdValue) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    const room = this._roomRow(roomId);
    if (!room) {
      return { ok: false, allowed: false, reason: "room_not_found" };
    }

    if (String(room.owner_id) === userId) {
      return { ok: true, allowed: true, owner_bypass: true };
    }
    if (Number(room.locked) !== 1) {
      return { ok: true, allowed: true, locked: false };
    }

    const lock = this._roomLockRow(roomId);
    if (!lock) {
      return { ok: false, allowed: false, reason: "lock_not_configured" };
    }

    const now = Date.now();
    this.ctx.storage.sql.exec(
      "DELETE FROM room_access_grants WHERE expires_at <= ?",
      now,
    );
    const grant = this.ctx.storage.sql.exec(
      `SELECT generation, expires_at
         FROM room_access_grants
        WHERE room_id = ? AND user_id = ?
        LIMIT 1`,
      roomId,
      userId,
    ).toArray()[0];

    const allowed = Boolean(
      grant &&
      Number(grant.generation) === Number(lock.generation) &&
      Number(grant.expires_at) > now,
    );
    return {
      ok: true,
      allowed,
      locked: true,
      owner_bypass: false,
    };
  }

  roomPasswordStatus(userIdValue, roomIdValue) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    const room = this._roomRow(roomId);

    if (!room) {
      return {
        ok: false,
        allowed: false,
        blocked: false,
        attempts_remaining: 0,
        error: "Room not found",
      };
    }
    if (String(room.owner_id) === userId) {
      return {
        ok: true,
        allowed: true,
        owner_bypass: true,
        blocked: false,
        attempts_remaining: 5,
      };
    }
    if (Number(room.locked) !== 1) {
      return {
        ok: true,
        allowed: true,
        locked: false,
        blocked: false,
        attempts_remaining: 5,
      };
    }

    const lock = this._roomLockRow(roomId);
    if (!lock) {
      return {
        ok: false,
        allowed: false,
        blocked: true,
        attempts_remaining: 0,
        error: "Room lock is not configured",
      };
    }

    const access = this.roomAccessState(userId, roomId);
    if (access.allowed) {
      return {
        ok: true,
        allowed: true,
        locked: true,
        blocked: false,
        attempts_remaining: 5,
      };
    }

    const row = this.ctx.storage.sql.exec(
      `SELECT generation, attempts
         FROM room_lock_attempts
        WHERE room_id = ? AND user_id = ?
        LIMIT 1`,
      roomId,
      userId,
    ).toArray()[0];
    const attempts =
      row && Number(row.generation) === Number(lock.generation)
        ? Number(row.attempts || 0)
        : 0;
    const blocked = attempts >= 5;
    return {
      ok: !blocked,
      allowed: false,
      locked: true,
      blocked,
      attempts_remaining: Math.max(0, 5 - attempts),
      error: blocked
        ? "Too many wrong password attempts. Wait until the room is opened."
        : null,
    };
  }

    async verifyRoomPassword(userIdValue, roomIdValue, passwordValue) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    const password = String(passwordValue || "");
    const room = this._roomRow(roomId);

    if (!room) throw new Error("Room not found");
    if (String(room.owner_id) === userId) {
      return {
        ok: true,
        allowed: true,
        owner_bypass: true,
        attempts_remaining: 5,
      };
    }
    if (Number(room.locked) !== 1) {
      return {
        ok: true,
        allowed: true,
        locked: false,
        attempts_remaining: 5,
      };
    }

    const lock = this._roomLockRow(roomId);
    if (!lock) throw new Error("Room lock is not configured");

    const currentAttempt = this.ctx.storage.sql.exec(
      `SELECT generation, attempts
         FROM room_lock_attempts
        WHERE room_id = ? AND user_id = ?
        LIMIT 1`,
      roomId,
      userId,
    ).toArray()[0];

    let attempts =
      currentAttempt &&
      Number(currentAttempt.generation) === Number(lock.generation)
        ? Number(currentAttempt.attempts || 0)
        : 0;

    if (attempts >= 5) {
      return {
        ok: false,
        allowed: false,
        blocked: true,
        attempts_remaining: 0,
        error: "Too many wrong password attempts. Wait until the room is opened.",
      };
    }

    const actual = await deriveSecret(
      password,
      fromBase64Url(String(lock.password_salt)),
      120000,
    );
    const expected = fromBase64Url(String(lock.password_hash));

    if (!safeEqualBytes(actual, expected)) {
      attempts += 1;
      const now = Date.now();
      this.ctx.storage.sql.exec(
        `INSERT INTO room_lock_attempts
          (room_id, user_id, generation, attempts, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(room_id, user_id) DO UPDATE SET
           generation = excluded.generation,
           attempts = excluded.attempts,
           updated_at = excluded.updated_at`,
        roomId,
        userId,
        Number(lock.generation),
        attempts,
        now,
      );
      return {
        ok: false,
        allowed: false,
        blocked: attempts >= 5,
        attempts_remaining: Math.max(0, 5 - attempts),
        error:
          attempts >= 5
            ? "Too many wrong password attempts. Wait until the room is opened."
            : "Incorrect room password",
      };
    }

    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO room_access_grants
        (room_id, user_id, generation, expires_at, created_at)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(room_id, user_id) DO UPDATE SET
         generation = excluded.generation,
         expires_at = excluded.expires_at,
         created_at = excluded.created_at`,
      roomId,
      userId,
      Number(lock.generation),
      now + 2 * 60 * 1000,
      now,
    );

    return {
      ok: true,
      allowed: true,
      blocked: false,
      attempts_remaining: Math.max(0, 5 - attempts),
    };
  }

  async setRoomLock(ownerIdValue, roomIdValue, input) {
    const ownerId = String(ownerIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    const locked = Boolean(input?.locked);
    const password = String(input?.password || "");
    const room = this._roomRow(roomId);

    if (!room) throw new Error("Room not found");
    if (String(room.owner_id) !== ownerId) {
      throw new Error("Only the room owner can change room lock");
    }

    const now = Date.now();
    const oldLock = this._roomLockRow(roomId);
    const nextGeneration = Number(oldLock?.generation || 0) + 1;

    if (locked) {
      if (password.length < 4 || password.length > 32) {
        throw new Error("Room password must be 4 to 32 characters");
      }
      const salt = crypto.getRandomValues(new Uint8Array(16));
      const hash = await deriveSecret(password, salt, 120000);
      this.ctx.storage.sql.exec(
        `INSERT INTO room_locks
          (room_id, password_salt, password_hash, generation, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(room_id) DO UPDATE SET
           password_salt = excluded.password_salt,
           password_hash = excluded.password_hash,
           generation = excluded.generation,
           updated_at = excluded.updated_at`,
        roomId,
        toBase64Url(salt),
        toBase64Url(hash),
        nextGeneration,
        now,
      );
      this.ctx.storage.sql.exec(
        "UPDATE app_rooms SET locked = 1, updated_at = ? WHERE id = ?",
        now,
        roomId,
      );
    } else {
      this.ctx.storage.sql.exec(
        "UPDATE app_rooms SET locked = 0, updated_at = ? WHERE id = ?",
        now,
        roomId,
      );
      if (oldLock) {
        this.ctx.storage.sql.exec(
          "UPDATE room_locks SET generation = ?, updated_at = ? WHERE room_id = ?",
          nextGeneration,
          now,
          roomId,
        );
      }
      this.ctx.storage.sql.exec(
        "DELETE FROM room_lock_attempts WHERE room_id = ?",
        roomId,
      );
      this.ctx.storage.sql.exec(
        "DELETE FROM room_access_grants WHERE room_id = ?",
        roomId,
      );
    }

    const updated = this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name,
              u.avatar_data_url AS owner_avatar_data_url,
              u.flag_emoji AS owner_flag_emoji
         FROM app_rooms r
         JOIN app_users u ON u.user_id = r.owner_id
        WHERE r.id = ?
        LIMIT 1`,
      roomId,
    ).toArray()[0];

    return {
      ok: true,
      room: rowToRoom(updated),
    };
  }

    async createRoom(ownerIdValue, input) {
    const ownerId = String(ownerIdValue || "").trim();
    const owner = await this.getUserById(ownerId);
    if (!owner) throw new Error("Owner user does not exist");

    const existing = this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name,
              u.avatar_data_url AS owner_avatar_data_url,
              u.flag_emoji AS owner_flag_emoji
         FROM app_rooms r
         JOIN app_users u ON u.user_id = r.owner_id
        WHERE r.owner_id = ?
        LIMIT 1`,
      ownerId,
    ).toArray()[0];
    if (existing) return rowToRoom(existing);

    const title = cleanText(input?.title, 60);
    const seatCount = Number(input?.seat_count || 12);
    const partyMode = cleanText(input?.party_mode, 40) || "Friends-making Party";
    const locked = Boolean(input?.locked);
    const photoDataUrl = input?.photo_data_url
      ? String(input.photo_data_url)
      : null;

    if (!title) throw new Error("Room name is required");
    if (!Number.isInteger(seatCount) || seatCount < 1 || seatCount > 30) {
      throw new Error("Invalid seat count");
    }
    if (photoDataUrl && photoDataUrl.length > MAX_AVATAR_DATA_LENGTH) {
      throw new Error("Room photo is too large");
    }
    if (photoDataUrl && !photoDataUrl.startsWith("data:image/")) {
      throw new Error("Room photo format is invalid");
    }

    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO app_rooms
        (id, owner_id, title, country_code, country_name, flag_emoji,
         seat_count, party_mode, locked, photo_data_url, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      ownerId,
      ownerId,
      title,
      owner.country_code,
      owner.country_name,
      owner.flag_emoji,
      seatCount,
      partyMode,
      locked ? 1 : 0,
      photoDataUrl,
      now,
      now,
    );
    return this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name,
              u.avatar_data_url AS owner_avatar_data_url,
              u.flag_emoji AS owner_flag_emoji
         FROM app_rooms r
         JOIN app_users u ON u.user_id = r.owner_id
        WHERE r.id = ?
        LIMIT 1`,
      ownerId,
    ).toArray().map(rowToRoom)[0];
  }
}
