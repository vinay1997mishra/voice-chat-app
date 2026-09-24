import { DurableObject } from "cloudflare:workers";

const MAX_AVATAR_DATA_LENGTH = 450000;
const VALID_GENDERS = new Set(["male", "female"]);

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
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_app_rooms_created ON app_rooms(created_at DESC);

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
    `);

    for (const migration of [
      "ALTER TABLE app_users ADD COLUMN auth_provider TEXT NOT NULL DEFAULT 'google'",
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
      `SELECT * FROM app_users
        WHERE auth_provider = ? AND auth_subject = ?
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

    if (!["google", "facebook"].includes(provider)) {
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
    return this.getUserById(userId);
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

  async listRooms() {
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
