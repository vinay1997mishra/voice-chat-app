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
    `);
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

  async getUserByGoogleSub(googleSubValue) {
    const googleSub = String(googleSubValue || "").trim();
    if (!googleSub) return null;
    const row = this.ctx.storage.sql.exec(
      `SELECT * FROM app_users WHERE google_sub = ? LIMIT 1`,
      googleSub,
    ).toArray()[0];
    return rowToUser(row);
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
    const googleSub = cleanText(input?.google_sub, 160);
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

    if (!googleSub) throw new Error("Google account identity is required");
    if (!email || !email.includes("@")) throw new Error("Valid Gmail/email is required");
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

    const existing = await this.getUserByGoogleSub(googleSub);
    if (existing) return existing;

    const userId = this._nextUserId();
    const now = Date.now();
    try {
      this.ctx.storage.sql.exec(
        `INSERT INTO app_users
          (user_id, google_sub, email, display_name, age, signature,
           country_code, country_name, flag_emoji, gender, avatar_data_url,
           created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        userId,
        googleSub,
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
        throw new Error("This Google account/email is already registered");
      }
      throw error;
    }
    return this.getUserById(userId);
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
      `SELECT * FROM app_rooms ORDER BY created_at DESC LIMIT 500`,
    ).toArray().map(rowToRoom);
  }

  async createRoom(ownerIdValue, input) {
    const ownerId = String(ownerIdValue || "").trim();
    const owner = await this.getUserById(ownerId);
    if (!owner) throw new Error("Owner user does not exist");

    const existing = this.ctx.storage.sql.exec(
      `SELECT * FROM app_rooms WHERE owner_id = ? LIMIT 1`,
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
      `SELECT * FROM app_rooms WHERE id = ? LIMIT 1`,
      ownerId,
    ).toArray().map(rowToRoom)[0];
  }
}
