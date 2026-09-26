import { DurableObject } from "cloudflare:workers";

const MAX_AVATAR_DATA_LENGTH = 450000;
const MAX_ROOM_THEME_ASSET_LENGTH = 2500000;
const ROOM_THEME_USER_PRICE_COINS = 10000000;
const ROOM_THEME_USER_DURATION_MS = 7 * 24 * 60 * 60 * 1000;
const UNVERIFIED_DIRECT_CALL_COST_COINS_PER_MINUTE = 200000;
const VERIFIED_DIRECT_CALL_COST_COINS_PER_MINUTE = 400000;
const RANDOM_CALL_COST_COINS_PER_MINUTE = 500000;
const VERIFIED_RECEIVER_REWARD_PERCENT = 80;
const UNVERIFIED_RECEIVER_REWARD_PERCENT = 50;
const CALL_VERIFICATION_IMAGE_MAX_LENGTH = 500000;
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
    call_verified: Number(row.call_verified || 0) === 1,
    call_verification_status: String(
      row.call_verification_status || "unverified"
    ),
    call_verified_at:
      row.call_verified_at == null ? null : Number(row.call_verified_at),
    call_verification_revoked_at:
      row.call_verification_revoked_at == null
        ? null
        : Number(row.call_verification_revoked_at),
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
        created_at INTEGER NOT NULL,
        seen_at INTEGER
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

      CREATE TABLE IF NOT EXISTS app_wallets (
        user_id TEXT PRIMARY KEY,
        coins INTEGER NOT NULL DEFAULT 2000000,
        diamonds INTEGER NOT NULL DEFAULT 17125,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS call_verification_submissions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        status TEXT NOT NULL,
        system_passed INTEGER NOT NULL DEFAULT 0,
        system_details_json TEXT NOT NULL DEFAULT '{}',
        photo_front_data_url TEXT NOT NULL,
        photo_left_data_url TEXT NOT NULL,
        photo_right_data_url TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        reviewed_at INTEGER,
        review_note TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_call_verification_user
        ON call_verification_submissions(user_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_call_verification_status
        ON call_verification_submissions(status, created_at DESC);

      CREATE TABLE IF NOT EXISTS random_call_stats (
        user_id TEXT PRIMARY KEY,
        offers INTEGER NOT NULL DEFAULT 0,
        answered INTEGER NOT NULL DEFAULT 0,
        completed_calls INTEGER NOT NULL DEFAULT 0,
        total_minutes INTEGER NOT NULL DEFAULT 0,
        last_offer_at INTEGER,
        updated_at INTEGER NOT NULL
      );

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

      CREATE TABLE IF NOT EXISTS owner_settings (
        key TEXT PRIMARY KEY,
        value_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS owner_catalog (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        name TEXT NOT NULL,
        data_json TEXT NOT NULL DEFAULT '{}',
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_owner_catalog_kind
        ON owner_catalog(kind, updated_at DESC);

      CREATE TABLE IF NOT EXISTS owner_user_controls (
        user_id TEXT PRIMARY KEY,
        banned INTEGER NOT NULL DEFAULT 0,
        device_banned INTEGER NOT NULL DEFAULT 0,
        invisible INTEGER NOT NULL DEFAULT 0,
        locked_bypass INTEGER NOT NULL DEFAULT 0,
        vip_level INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS owner_wallets (
        user_id TEXT NOT NULL,
        wallet_type TEXT NOT NULL,
        balance INTEGER NOT NULL DEFAULT 0,
        banned INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(user_id, wallet_type)
      );

      CREATE TABLE IF NOT EXISTS owner_hierarchy (
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        parent_user_id TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        data_json TEXT NOT NULL DEFAULT '{}',
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(user_id, role)
      );

      CREATE TABLE IF NOT EXISTS owner_room_controls (
        room_id TEXT PRIMARY KEY,
        banned INTEGER NOT NULL DEFAULT 0,
        background_asset TEXT,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS owner_user_tags (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_owner_user_tags_user
        ON owner_user_tags(user_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS owner_treasury (
        singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
        balance INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS user_id_history (
        old_user_id TEXT PRIMARY KEY,
        new_user_id TEXT NOT NULL,
        changed_at INTEGER NOT NULL
      );
    `);

    for (const migration of [
      "ALTER TABLE app_users ADD COLUMN auth_provider TEXT NOT NULL DEFAULT 'google'",
      "ALTER TABLE room_themes ADD COLUMN starts_at INTEGER",
      "ALTER TABLE app_rooms ADD COLUMN theme_id TEXT NOT NULL DEFAULT 'royal-dark'",
      "ALTER TABLE app_rooms ADD COLUMN theme_asset TEXT",
      "ALTER TABLE app_users ADD COLUMN auth_subject TEXT",
      "ALTER TABLE direct_messages ADD COLUMN seen_at INTEGER",
      "ALTER TABLE app_users ADD COLUMN call_verified INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE app_users ADD COLUMN call_verification_status TEXT NOT NULL DEFAULT 'unverified'",
      "ALTER TABLE app_users ADD COLUMN call_verified_at INTEGER",
      "ALTER TABLE app_users ADD COLUMN call_verification_revoked_at INTEGER",
      "ALTER TABLE app_calls ADD COLUMN accepted_at INTEGER",
      "ALTER TABLE app_calls ADD COLUMN billed_minutes INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE app_calls ADD COLUMN caller_cost_coins INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE app_calls ADD COLUMN receiver_reward_diamonds INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE app_calls ADD COLUMN receiver_earning_eligible INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE app_calls ADD COLUMN end_reason TEXT",
      "ALTER TABLE app_calls ADD COLUMN call_kind TEXT NOT NULL DEFAULT 'direct'",
      "ALTER TABLE app_calls ADD COLUMN cost_coins_per_minute INTEGER NOT NULL DEFAULT 200000",
      "ALTER TABLE app_calls ADD COLUMN receiver_diamonds_per_minute INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE app_calls ADD COLUMN stats_recorded INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE app_wallets ADD COLUMN banned INTEGER NOT NULL DEFAULT 0"
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
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO app_wallets (user_id, coins, diamonds, updated_at)
       SELECT user_id, 2000000, 17125, ? FROM app_users`,
      Date.now(),
    );
    this.ctx.storage.sql.exec(
      "INSERT OR IGNORE INTO owner_treasury (singleton_id, balance, updated_at) VALUES (1, 0, ?)",
      Date.now(),
    );

    const defaultVipEntries = [
      "Deer", "Fox", "Black Panther", "White Tiger", "Golden Lion",
      "Giant Wolf", "Armored Lion", "Thunder Beast",
      "Black Eagle + rider", "Phoenix + rider", "Dragon + rider",
    ];
    for (let index = 0; index < defaultVipEntries.length; index += 1) {
      const level = index + 1;
      this.ctx.storage.sql.exec(
        `INSERT OR IGNORE INTO owner_catalog
          (id, kind, name, data_json, enabled, created_at, updated_at)
         VALUES (?, 'vip', ?, ?, 1, ?, ?)`,
        "vip-" + level,
        "VIP " + level,
        JSON.stringify({
          level,
          price: 0,
          entry: defaultVipEntries[index],
          frame: "Editable",
        }),
        Date.now(),
        Date.now(),
      );
    }

    const defaultRoles = [
      "Host", "Agency Owner", "BD", "Coin Seller", "Merchant",
      "Admin", "Super Admin", "Manager",
    ];
    for (const roleName of defaultRoles) {
      const roleId = "role-" + roleName.toLowerCase().replaceAll(" ", "-");
      this.ctx.storage.sql.exec(
        `INSERT OR IGNORE INTO owner_catalog
          (id, kind, name, data_json, enabled, created_at, updated_at)
         VALUES (?, 'role', ?, '{}', 1, ?, ?)`,
        roleId,
        roleName,
        Date.now(),
        Date.now(),
      );
    }
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


  _ownerSetting(keyValue, fallbackValue = null) {
    const key = String(keyValue || "").trim();
    if (!key) return fallbackValue;
    const row = this.ctx.storage.sql.exec(
      "SELECT value_json FROM owner_settings WHERE key = ? LIMIT 1",
      key,
    ).toArray()[0];
    if (!row) return fallbackValue;
    try { return JSON.parse(String(row.value_json)); } catch { return fallbackValue; }
  }

  _setOwnerSetting(keyValue, value) {
    const key = String(keyValue || "").trim();
    if (!key) throw new Error("Setting key is required");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      \`INSERT INTO owner_settings (key, value_json, updated_at)
       VALUES (?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET
         value_json = excluded.value_json,
         updated_at = excluded.updated_at\`,
      key, JSON.stringify(value), now,
    );
    return { key, value, updated_at: now };
  }

  _resolveOwnerUserId(userIdValue) {
    const raw = String(userIdValue || "").trim();
    if (!raw) return "";
    const direct = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", raw,
    ).toArray()[0];
    if (direct) return String(direct.user_id);
    const history = this.ctx.storage.sql.exec(
      "SELECT new_user_id FROM user_id_history WHERE old_user_id = ? LIMIT 1", raw,
    ).toArray()[0];
    return history ? String(history.new_user_id) : raw;
  }

  listUserTags(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) return [];
    return this.ctx.storage.sql.exec(
      \`SELECT id, name, color, created_at
         FROM owner_user_tags
        WHERE user_id = ?
        ORDER BY created_at DESC\`, userId,
    ).toArray().map((row) => ({
      id: String(row.id), name: String(row.name), color: String(row.color),
      created_at: Number(row.created_at),
    }));
  }

  _userControls(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) return {
      banned: false, device_banned: false, invisible: false,
      locked_bypass: false, vip_level: 0,
    };
    const row = this.ctx.storage.sql.exec(
      "SELECT * FROM owner_user_controls WHERE user_id = ? LIMIT 1", userId,
    ).toArray()[0];
    return {
      banned: Number(row?.banned || 0) === 1,
      device_banned: Number(row?.device_banned || 0) === 1,
      invisible: Number(row?.invisible || 0) === 1,
      locked_bypass: Number(row?.locked_bypass || 0) === 1,
      vip_level: Number(row?.vip_level || 0),
      updated_at: row?.updated_at == null ? null : Number(row.updated_at),
    };
  }

  ownerSearchUsers(queryValue, limitValue = 50) {
    const query = String(queryValue || "").trim();
    const limit = Math.max(1, Math.min(200, Number(limitValue || 50)));
    let resolved = query;
    if (query) {
      const history = this.ctx.storage.sql.exec(
        "SELECT new_user_id FROM user_id_history WHERE old_user_id = ? LIMIT 1", query,
      ).toArray()[0];
      if (history) resolved = String(history.new_user_id);
    }
    const like = "%" + (query || resolved) + "%";
    const rows = query
      ? this.ctx.storage.sql.exec(
          \`SELECT * FROM app_users
            WHERE user_id = ? OR user_id LIKE ? OR display_name LIKE ? OR email LIKE ?
            ORDER BY CASE WHEN user_id = ? THEN 0 ELSE 1 END, created_at DESC
            LIMIT ?\`,
          resolved, like, like, like, resolved, limit,
        ).toArray()
      : this.ctx.storage.sql.exec(
          "SELECT * FROM app_users ORDER BY created_at DESC LIMIT ?", limit,
        ).toArray();
    return rows.map((row) => {
      const user = rowToUser(row);
      return {
        ...user,
        controls: this._userControls(user.user_id),
        wallet: this.getWallet(user.user_id),
        tags: this.listUserTags(user.user_id),
      };
    });
  }

  listVerifiedUsers(queryValue = "") {
    const query = String(queryValue || "").trim();
    const like = "%" + query + "%";
    return this.ctx.storage.sql.exec(
      \`SELECT * FROM app_users
        WHERE call_verified = 1
          AND (? = '' OR user_id LIKE ? OR display_name LIKE ?)
        ORDER BY call_verified_at DESC, user_id ASC
        LIMIT 500\`, query, like, like,
    ).toArray().map((row) => ({
      ...rowToUser(row), tags: this.listUserTags(row.user_id),
    }));
  }

  ownerCatalog(kindValue) {
    const kind = String(kindValue || "").trim();
    const rows = kind
      ? this.ctx.storage.sql.exec(
          "SELECT * FROM owner_catalog WHERE kind = ? ORDER BY updated_at DESC", kind,
        ).toArray()
      : this.ctx.storage.sql.exec(
          "SELECT * FROM owner_catalog ORDER BY kind, updated_at DESC",
        ).toArray();
    return rows.map((row) => {
      let data = {};
      try { data = JSON.parse(String(row.data_json || "{}")); } catch {}
      return {
        id: String(row.id), kind: String(row.kind), name: String(row.name),
        data, enabled: Number(row.enabled) === 1,
        created_at: Number(row.created_at), updated_at: Number(row.updated_at),
      };
    });
  }

  ownerCatalogCreate(kindValue, nameValue, dataValue = {}, enabledValue = true) {
    const kind = cleanText(kindValue, 40).toLowerCase();
    const name = cleanText(nameValue, 80);
    if (!kind || !name) throw new Error("Catalog type and name are required");
    const now = Date.now();
    const id = kind + "-" + now.toString(36) + "-" + crypto.randomUUID().slice(0, 8);
    const data = dataValue && typeof dataValue === "object" ? dataValue : {};
    this.ctx.storage.sql.exec(
      \`INSERT INTO owner_catalog
        (id, kind, name, data_json, enabled, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)\`,
      id, kind, name, JSON.stringify(data), enabledValue === false ? 0 : 1, now, now,
    );
    return this.ownerCatalog(kind).find((item) => item.id === id);
  }

  ownerCatalogPatch(idValue, patchValue = {}) {
    const id = String(idValue || "").trim();
    const current = this.ctx.storage.sql.exec(
      "SELECT * FROM owner_catalog WHERE id = ? LIMIT 1", id,
    ).toArray()[0];
    if (!current) throw new Error("Catalog item not found");
    let data = {};
    try { data = JSON.parse(String(current.data_json || "{}")); } catch {}
    const patch = patchValue && typeof patchValue === "object" ? patchValue : {};
    if (patch.data && typeof patch.data === "object") data = { ...data, ...patch.data };
    const name = patch.name === undefined ? String(current.name) : cleanText(patch.name, 80);
    const enabled = patch.enabled === undefined
      ? Number(current.enabled) : patch.enabled === true ? 1 : 0;
    this.ctx.storage.sql.exec(
      "UPDATE owner_catalog SET name = ?, data_json = ?, enabled = ?, updated_at = ? WHERE id = ?",
      name, JSON.stringify(data), enabled, Date.now(), id,
    );
    return this.ownerCatalog(String(current.kind)).find((item) => item.id === id);
  }

  ownerState() {
    const defaultFeatures = {
      voice_rooms: true, gifts: true, vip: true, games: true,
      host_system: true, agency_system: true, bd_system: true,
      coin_seller: true, merchant: true, banners: true,
      vehicle_entries: true, frames: true,
    };
    const defaultPolicies = {
      coins_per_usd: 2000000, diamonds_per_coin: 1,
      room_online_exp_per_minute: 50, room_online_daily_minutes_cap: 480,
      host_first_target_received_coins: 4000000, host_first_target_usd: 1.6,
      agency_commission_percent: 20, bd_target_1_usd: 500,
      bd_target_1_percent: 7, bd_target_2_usd: 1000,
      bd_target_2_percent: 10, minimum_transfer_usd: 2,
    };
    const treasury = this.ctx.storage.sql.exec(
      "SELECT balance, updated_at FROM owner_treasury WHERE singleton_id = 1 LIMIT 1",
    ).toArray()[0] || { balance: 0, updated_at: 0 };
    return {
      features: { ...defaultFeatures, ...(this._ownerSetting("features", {}) || {}) },
      policies: { ...defaultPolicies, ...(this._ownerSetting("policies", {}) || {}) },
      game_config: this._ownerSetting("game_config", {
        enabled: true, min_bet: 1, max_bet: 1000000,
      }),
      treasury: {
        balance: Number(treasury.balance || 0),
        updated_at: Number(treasury.updated_at || 0),
      },
      catalog: this.ownerCatalog(),
    };
  }

  ownerDashboard() {
    const now = Date.now();
    const dayStart = now - (now % 86400000);
    const users = this.ctx.storage.sql.exec(
      "SELECT COUNT(*) AS count FROM app_users",
    ).toArray()[0];
    const rooms = this.ctx.storage.sql.exec(
      "SELECT COUNT(*) AS count FROM app_rooms",
    ).toArray()[0];
    const sending = this.ctx.storage.sql.exec(
      "SELECT COALESCE(SUM(caller_cost_coins), 0) AS total FROM app_calls WHERE updated_at >= ?",
      dayStart,
    ).toArray()[0];
    const state = this.ownerState();
    return {
      users: Number(users?.count || 0),
      active_rooms: Number(rooms?.count || 0),
      sending_today: Number(sending?.total || 0),
      treasury: state.treasury.balance,
    };
  }

  sendOwnerMessages(textValue, userIdsValue = [], allUsersValue = false) {
    const text = cleanText(textValue, 2000);
    if (!text) throw new Error("Message cannot be empty");
    let targets = [];
    if (allUsersValue === true) {
      targets = this.ctx.storage.sql.exec(
        "SELECT user_id FROM app_users ORDER BY created_at ASC LIMIT 20000",
      ).toArray().map((row) => String(row.user_id));
    } else {
      const requested = Array.isArray(userIdsValue) ? userIdsValue : [];
      if (requested.length === 0) throw new Error("Select at least one user");
      if (requested.length > 500) throw new Error("A selected batch can contain at most 500 IDs");
      targets = [...new Set(requested.map((value) =>
        this._resolveOwnerUserId(value)).filter(Boolean))];
    }
    let sent = 0;
    for (const userId of targets) {
      const exists = this.ctx.storage.sql.exec(
        "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", userId,
      ).toArray()[0];
      if (!exists) continue;
      this.sendOfficialMessage(userId, text, { action: "owner_message" });
      sent += 1;
    }
    return { ok: true, sent, requested: targets.length };
  }

  applyOwnerTag(userIdsValue, nameValue, colorValue) {
    const requested = Array.isArray(userIdsValue) ? userIdsValue : [];
    if (requested.length === 0) throw new Error("Select at least one user");
    if (requested.length > 500) throw new Error("Tag batch is limited to 500 IDs");
    const name = cleanText(nameValue, 40);
    const color = String(colorValue || "").trim();
    if (!name) throw new Error("Tag name is required");
    if (!/^#[0-9a-fA-F]{6}$/.test(color)) throw new Error("Choose a valid tag color");
    let tagged = 0;
    const now = Date.now();
    for (const value of [...new Set(requested)]) {
      const userId = this._resolveOwnerUserId(value);
      const exists = this.ctx.storage.sql.exec(
        "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", userId,
      ).toArray()[0];
      if (!exists) continue;
      const duplicate = this.ctx.storage.sql.exec(
        "SELECT id FROM owner_user_tags WHERE user_id = ? AND name = ? LIMIT 1",
        userId, name,
      ).toArray()[0];
      if (duplicate) {
        this.ctx.storage.sql.exec(
          "UPDATE owner_user_tags SET color = ? WHERE id = ?", color, String(duplicate.id),
        );
      } else {
        this.ctx.storage.sql.exec(
          "INSERT INTO owner_user_tags (id, user_id, name, color, created_at) VALUES (?, ?, ?, ?, ?)",
          "tag-" + now.toString(36) + "-" + crypto.randomUUID().slice(0, 8),
          userId, name, color, now,
        );
      }
      tagged += 1;
    }
    return { ok: true, tagged, name, color };
  }

  removeOwnerTag(userIdValue, tagIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const tagId = String(tagIdValue || "").trim();
    this.ctx.storage.sql.exec(
      "DELETE FROM owner_user_tags WHERE user_id = ? AND id = ?", userId, tagId,
    );
    return { ok: true, user_id: userId, tag_id: tagId };
  }

  _setUserControl(userIdValue, patchValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const exists = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", userId,
    ).toArray()[0];
    if (!exists) throw new Error("User not found");
    const current = this._userControls(userId);
    const patch = patchValue && typeof patchValue === "object" ? patchValue : {};
    const next = {
      banned: patch.banned ?? current.banned,
      device_banned: patch.device_banned ?? current.device_banned,
      invisible: patch.invisible ?? current.invisible,
      locked_bypass: patch.locked_bypass ?? current.locked_bypass,
      vip_level: patch.vip_level ?? current.vip_level,
    };
    this.ctx.storage.sql.exec(
      \`INSERT INTO owner_user_controls
        (user_id, banned, device_banned, invisible, locked_bypass, vip_level, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         banned = excluded.banned, device_banned = excluded.device_banned,
         invisible = excluded.invisible, locked_bypass = excluded.locked_bypass,
         vip_level = excluded.vip_level, updated_at = excluded.updated_at\`,
      userId, next.banned ? 1 : 0, next.device_banned ? 1 : 0,
      next.invisible ? 1 : 0, next.locked_bypass ? 1 : 0,
      Math.max(0, Number(next.vip_level || 0)), Date.now(),
    );
    return this._userControls(userId);
  }

  _manageWallet(userIdValue, walletTypeValue, operationValue, amountValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const walletType = String(walletTypeValue || "normal").trim().toLowerCase();
    const operation = String(operationValue || "").trim().toLowerCase();
    const amount = Math.max(0, Math.floor(Number(amountValue || 0)));
    const user = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", userId,
    ).toArray()[0];
    if (!user) throw new Error("User not found");

    if (walletType === "normal") {
      const now = Date.now();
      this.ctx.storage.sql.exec(
        "INSERT OR IGNORE INTO app_wallets (user_id, coins, diamonds, updated_at) VALUES (?, 0, 0, ?)",
        userId, now,
      );
      if (operation === "credit") {
        this.ctx.storage.sql.exec(
          "UPDATE app_wallets SET coins = coins + ?, updated_at = ? WHERE user_id = ?",
          amount, now, userId,
        );
      } else if (operation === "debit") {
        const wallet = this.getWallet(userId);
        if (wallet.coins < amount) throw new Error("Wallet balance is too low");
        this.ctx.storage.sql.exec(
          "UPDATE app_wallets SET coins = coins - ?, updated_at = ? WHERE user_id = ?",
          amount, now, userId,
        );
      } else if (operation === "ban" || operation === "unban") {
        this.ctx.storage.sql.exec(
          "UPDATE app_wallets SET banned = ?, updated_at = ? WHERE user_id = ?",
          operation === "ban" ? 1 : 0, now, userId,
        );
      }
      return { wallet_type: "normal", ...this.getWallet(userId) };
    }

    if (!["coin_seller", "merchant"].includes(walletType)) {
      throw new Error("Unsupported wallet type");
    }
    const now = Date.now();
    this.ctx.storage.sql.exec(
      \`INSERT OR IGNORE INTO owner_wallets
        (user_id, wallet_type, balance, banned, updated_at)
       VALUES (?, ?, 0, 0, ?)\`,
      userId, walletType, now,
    );
    const row = this.ctx.storage.sql.exec(
      "SELECT * FROM owner_wallets WHERE user_id = ? AND wallet_type = ? LIMIT 1",
      userId, walletType,
    ).toArray()[0];
    if (operation === "credit") {
      this.ctx.storage.sql.exec(
        "UPDATE owner_wallets SET balance = balance + ?, updated_at = ? WHERE user_id = ? AND wallet_type = ?",
        amount, now, userId, walletType,
      );
    } else if (operation === "debit") {
      if (Number(row?.balance || 0) < amount) throw new Error("Wallet balance is too low");
      this.ctx.storage.sql.exec(
        "UPDATE owner_wallets SET balance = balance - ?, updated_at = ? WHERE user_id = ? AND wallet_type = ?",
        amount, now, userId, walletType,
      );
    } else if (operation === "ban" || operation === "unban") {
      this.ctx.storage.sql.exec(
        "UPDATE owner_wallets SET banned = ?, updated_at = ? WHERE user_id = ? AND wallet_type = ?",
        operation === "ban" ? 1 : 0, now, userId, walletType,
      );
    } else if (operation !== "create") {
      throw new Error("Unsupported wallet operation");
    }
    const updated = this.ctx.storage.sql.exec(
      "SELECT * FROM owner_wallets WHERE user_id = ? AND wallet_type = ? LIMIT 1",
      userId, walletType,
    ).toArray()[0];
    return {
      user_id: userId, wallet_type: walletType,
      balance: Number(updated?.balance || 0),
      banned: Number(updated?.banned || 0) === 1,
      updated_at: Number(updated?.updated_at || now),
    };
  }

  _ownerTreasuryAdd(amountValue) {
    const amount = Math.floor(Number(amountValue || 0));
    if (amount <= 0) throw new Error("Enter a valid coin amount");
    this.ctx.storage.sql.exec(
      "UPDATE owner_treasury SET balance = balance + ?, updated_at = ? WHERE singleton_id = 1",
      amount, Date.now(),
    );
    return this.ownerState().treasury;
  }

  _ownerTreasurySend(userIdValue, walletTypeValue, amountValue) {
    const amount = Math.floor(Number(amountValue || 0));
    if (amount <= 0) throw new Error("Enter a valid coin amount");
    const treasury = this.ownerState().treasury;
    if (treasury.balance < amount) throw new Error("Owner Treasury balance is not enough");
    const walletType = String(walletTypeValue || "normal");
    this.ctx.storage.sql.exec(
      "UPDATE owner_treasury SET balance = balance - ?, updated_at = ? WHERE singleton_id = 1",
      amount, Date.now(),
    );
    const wallet = this._manageWallet(userIdValue, walletType, "credit", amount);
    return { treasury: this.ownerState().treasury, wallet };
  }

  _setHierarchy(userIdValue, roleValue, parentValue, activeValue, dataValue = {}) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const role = String(roleValue || "").trim().toLowerCase();
    if (!userId || !role) throw new Error("User ID and role are required");
    const exists = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", userId,
    ).toArray()[0];
    if (!exists) throw new Error("User not found");
    const parent = parentValue ? this._resolveOwnerUserId(parentValue) : null;
    this.ctx.storage.sql.exec(
      \`INSERT INTO owner_hierarchy
        (user_id, role, parent_user_id, active, data_json, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id, role) DO UPDATE SET
         parent_user_id = excluded.parent_user_id, active = excluded.active,
         data_json = excluded.data_json, updated_at = excluded.updated_at\`,
      userId, role, parent, activeValue === false ? 0 : 1,
      JSON.stringify(dataValue && typeof dataValue === "object" ? dataValue : {}),
      Date.now(),
    );
    return { user_id: userId, role, parent_user_id: parent, active: activeValue !== false };
  }

  _changeUserId(oldIdValue, newIdValue) {
    const oldId = this._resolveOwnerUserId(oldIdValue);
    const newId = String(newIdValue || "").trim();
    if (!oldId || !newId) throw new Error("Current and new user ID are required");
    if (!/^\d{6,12}$/.test(newId)) throw new Error("New public ID must contain 6 to 12 digits");
    if (oldId === newId) return this.ownerSearchUsers(newId, 1)[0];
    const user = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", oldId,
    ).toArray()[0];
    if (!user) throw new Error("User not found");
    const taken = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", newId,
    ).toArray()[0];
    if (taken) throw new Error("New public ID is already in use");

    const room = this.ctx.storage.sql.exec(
      "SELECT id FROM app_rooms WHERE owner_id = ? LIMIT 1", oldId,
    ).toArray()[0];
    const oldRoomId = room ? String(room.id) : null;
    const userColumns = [
      ["app_user_identities","user_id"], ["app_wallets","user_id"],
      ["call_verification_submissions","user_id"], ["random_call_stats","user_id"],
      ["email_password_credentials","user_id"], ["owner_user_controls","user_id"],
      ["owner_user_tags","user_id"], ["owner_wallets","user_id"],
      ["owner_hierarchy","user_id"], ["owner_hierarchy","parent_user_id"],
      ["room_lock_attempts","user_id"], ["room_access_grants","user_id"],
      ["room_themes","creator_user_id"], ["app_follows","follower_id"],
      ["app_follows","target_id"], ["app_blocks","blocker_id"],
      ["app_blocks","target_id"], ["direct_messages","from_user_id"],
      ["direct_messages","to_user_id"], ["app_calls","caller_id"],
      ["app_calls","receiver_id"],
    ];
    for (const pair of userColumns) {
      const tableName = pair[0], columnName = pair[1];
      this.ctx.storage.sql.exec(
        "UPDATE " + tableName + " SET " + columnName + " = ? WHERE " + columnName + " = ?",
        newId, oldId,
      );
    }
    this.ctx.storage.sql.exec(
      "UPDATE app_rooms SET owner_id = ? WHERE owner_id = ?", newId, oldId,
    );

    if (oldRoomId && oldRoomId === oldId) {
      const roomColumns = [
        ["room_locks","room_id"], ["room_lock_attempts","room_id"],
        ["room_access_grants","room_id"], ["room_themes","room_id"],
        ["owner_room_controls","room_id"],
      ];
      for (const pair of roomColumns) {
        const tableName = pair[0], columnName = pair[1];
        this.ctx.storage.sql.exec(
          "UPDATE " + tableName + " SET " + columnName + " = ? WHERE " + columnName + " = ?",
          newId, oldRoomId,
        );
      }
      this.ctx.storage.sql.exec(
        "UPDATE app_rooms SET id = ? WHERE id = ?", newId, oldRoomId,
      );
    }

    this.ctx.storage.sql.exec(
      "UPDATE app_users SET user_id = ?, updated_at = ? WHERE user_id = ?",
      newId, Date.now(), oldId,
    );
    this.ctx.storage.sql.exec(
      "INSERT OR REPLACE INTO user_id_history (old_user_id, new_user_id, changed_at) VALUES (?, ?, ?)",
      oldId, newId, Date.now(),
    );
    return this.ownerSearchUsers(newId, 1)[0];
  }

  ownerAction(actionValue, dataValue = {}) {
    const action = String(actionValue || "").trim();
    const data = dataValue && typeof dataValue === "object" ? dataValue : {};
    const on = (value) => ["on","enable","enabled","true","activate","grant","unban"]
      .includes(String(value || "").toLowerCase());

    switch (action) {
      case "treasury-add": return this._ownerTreasuryAdd(data.amount);
      case "treasury-send": return this._ownerTreasurySend(data.user_id, data.wallet_type, data.amount);
      case "user-search": return { users: this.ownerSearchUsers(data.user_id || data.query, 50) };
      case "user-ban": return this._setUserControl(data.user_id, { banned: String(data.status) === "ban" });
      case "device-ban": return this._setUserControl(data.user_id, { device_banned: String(data.status) === "ban" });
      case "user-invisible": return this._setUserControl(data.user_id, { invisible: on(data.status) });
      case "locked-bypass": return this._setUserControl(data.user_id, { locked_bypass: on(data.status) });
      case "vip-grant": return this._setUserControl(data.user_id, {
        vip_level: String(data.operation) === "remove" ? 0 : Math.max(1, Number(data.vip_level || 1)),
      });
      case "id-change": return this._changeUserId(data.user_id, data.new_id);
      case "room-ban": {
        const roomId = String(data.room_id || "").trim();
        if (!this._roomRow(roomId)) throw new Error("Room not found");
        this.ctx.storage.sql.exec(
          \`INSERT INTO owner_room_controls (room_id, banned, background_asset, updated_at)
           VALUES (?, ?, NULL, ?)
           ON CONFLICT(room_id) DO UPDATE SET banned = excluded.banned, updated_at = excluded.updated_at\`,
          roomId, String(data.status) === "ban" ? 1 : 0, Date.now(),
        );
        return { room_id: roomId, banned: String(data.status) === "ban" };
      }
      case "room-name": {
        const roomId = String(data.room_id || "").trim();
        const name = cleanText(data.room_name, 60);
        if (!name) throw new Error("Room name is required");
        const existing = this._roomRow(roomId);
        if (!existing) throw new Error("Room not found");
        this.ctx.storage.sql.exec(
          "UPDATE app_rooms SET title = ?, updated_at = ? WHERE id = ?",
          name, Date.now(), roomId,
        );
        return { room_id: roomId, title: name };
      }
      case "room-dp": {
        const roomId = String(data.room_id || "").trim();
        if (!this._roomRow(roomId)) throw new Error("Room not found");
        const asset = String(data.asset_url || "").trim();
        this.ctx.storage.sql.exec(
          "UPDATE app_rooms SET photo_data_url = ?, updated_at = ? WHERE id = ?",
          asset || null, Date.now(), roomId,
        );
        return { room_id: roomId, photo_data_url: asset || null };
      }
      case "room-bg": {
        const roomId = String(data.room_id || "").trim();
        if (!this._roomRow(roomId)) throw new Error("Room not found");
        const asset = String(data.asset_url || "").trim();
        this.ctx.storage.sql.exec(
          \`INSERT INTO owner_room_controls (room_id, banned, background_asset, updated_at)
           VALUES (?, 0, ?, ?)
           ON CONFLICT(room_id) DO UPDATE SET
             background_asset = excluded.background_asset, updated_at = excluded.updated_at\`,
          roomId, asset || null, Date.now(),
        );
        this.ctx.storage.sql.exec(
          "UPDATE app_rooms SET theme_asset = ?, updated_at = ? WHERE id = ?",
          asset || null, Date.now(), roomId,
        );
        return { room_id: roomId, background_asset: asset || null };
      }
      case "room-live": {
        const roomId = String(data.room_id || data.target_id || "").trim();
        const row = this.ctx.storage.sql.exec(
          "SELECT * FROM app_rooms WHERE id = ? LIMIT 1", roomId,
        ).toArray()[0];
        if (!row) throw new Error("Room not found");
        return { room: rowToRoom(row) };
      }
      case "wallet-normal": return this._manageWallet(data.user_id, "normal", data.operation, data.amount);
      case "wallet-seller": return this._manageWallet(data.user_id, "coin_seller", data.operation, data.amount);
      case "wallet-merchant": return this._manageWallet(data.user_id, "merchant", data.operation, data.amount);
      case "bd-activate": return this._setHierarchy(data.user_id, "bd", null, String(data.operation) !== "remove");
      case "agency-activate": return this._setHierarchy(data.user_id, "agency", null, String(data.operation) !== "remove");
      case "agency-to-bd": return this._setHierarchy(data.agency_owner_id, "agency", data.bd_user_id, true);
      case "agency-from-bd": return this._setHierarchy(data.agency_owner_id, "agency", null, true);
      case "host-add": return this._setHierarchy(data.host_user_id, "host", data.agency_owner_id, true);
      case "host-remove": return this._setHierarchy(data.host_user_id, "host", data.agency_owner_id, false);
      case "bd-target": return this._setOwnerSetting("hierarchy.bd_target", data);
      case "complaints": return { ok: true, message: "Complaints are available in Owner Notifications." };
      case "role-new": return this.ownerCatalogCreate(
        String(data.type || "role"), data.name, { color: data.color || "#FFD54F" },
      );
      case "vip-new": return this.ownerCatalogCreate("vip", data.name || "VIP", {
        level: Number(data.level || data.vip_level || 1),
        price: Number(data.price || 0), entry: data.entry || "", frame: data.frame || "",
      });
      case "gift-new": return this.ownerCatalogCreate("gift", data.name, {
        coin_price: Number(data.coin_price || 0), asset_url: String(data.asset_url || ""),
      });
      case "entry-new": return this.ownerCatalogCreate("entry", data.name, {
        asset_url: String(data.asset_url || ""), vip_level: Number(data.vip_level || 0),
      });
      case "frame-new": return this.ownerCatalogCreate("frame", data.name, {
        asset_url: String(data.asset_url || ""), vip_level: Number(data.vip_level || 0),
      });
      case "banner-new": return this.ownerCatalogCreate("banner", data.title || "Banner", {
        asset_url: String(data.asset_url || ""),
        starts_at: data.starts_at ? Date.parse(String(data.starts_at)) : Date.now(),
        ends_at: data.ends_at ? Date.parse(String(data.ends_at)) : null,
      });
      case "policy-new":
      case "policy-set": {
        const policies = this.ownerState().policies;
        policies[String(data.key || "").trim()] = data.value;
        return this._setOwnerSetting("policies", policies);
      }
      case "feature-set": {
        const features = this.ownerState().features;
        features[String(data.key || "").trim()] = data.enabled === true;
        return this._setOwnerSetting("features", features);
      }
      case "game-switch": {
        const config = this.ownerState().game_config;
        config.enabled = data.enabled !== undefined ? data.enabled === true : !config.enabled;
        return this._setOwnerSetting("game_config", config);
      }
      case "game-limits": {
        const config = this.ownerState().game_config;
        if (data.min_bet !== undefined) config.min_bet = Number(data.min_bet);
        if (data.max_bet !== undefined) config.max_bet = Number(data.max_bet);
        return this._setOwnerSetting("game_config", config);
      }
      case "game-stats": {
        const row = this.ctx.storage.sql.exec(
          \`SELECT COUNT(*) AS calls, COALESCE(SUM(caller_cost_coins),0) AS spent,
                  COALESCE(SUM(receiver_reward_diamonds),0) AS rewards
             FROM app_calls\`,
        ).toArray()[0];
        return {
          sessions: Number(row?.calls || 0), spent_coins: Number(row?.spent || 0),
          reward_diamonds: Number(row?.rewards || 0),
        };
      }
      case "catalog-toggle": return this.ownerCatalogPatch(data.id, { enabled: data.enabled === true });
      case "catalog-edit": return this.ownerCatalogPatch(data.id, data.patch || {});
      default: throw new Error("Unsupported Owner action: " + action);
    }
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
    const requestedId = String(userIdValue || "").trim();
    if (!requestedId) return null;
    const userId = this._resolveOwnerUserId(requestedId);
    const row = this.ctx.storage.sql.exec(
      `SELECT * FROM app_users WHERE user_id = ? LIMIT 1`,
      userId,
    ).toArray()[0];
    const user = rowToUser(row);
    if (!user) return null;
    return {
      ...user,
      previous_user_id: requestedId !== userId ? requestedId : null,
      controls: this._userControls(userId),
      tags: this.listUserTags(userId),
    };
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
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO app_wallets
        (user_id, coins, diamonds, updated_at)
       VALUES (?, 2000000, 17125, ?)`,
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
      `SELECT u.user_id, u.display_name, u.avatar_data_url
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
      avatar_data_url: row.avatar_data_url
        ? String(row.avatar_data_url)
        : null,
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

  getWallet(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) throw new Error("user ID is required");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO app_wallets
        (user_id, coins, diamonds, banned, updated_at)
       VALUES (?, 2000000, 17125, 0, ?)`,
      userId,
      now,
    );
    const row = this.ctx.storage.sql.exec(
      "SELECT user_id, coins, diamonds, banned, updated_at FROM app_wallets WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    return {
      user_id: userId,
      coins: Number(row?.coins || 0),
      diamonds: Number(row?.diamonds || 0),
      banned: Number(row?.banned || 0) === 1,
      updated_at: Number(row?.updated_at || now),
    };
  }

  callVerificationStatus(userIdValue) {
    const user = this.ctx.storage.sql.exec(
      `SELECT user_id, gender, call_verified, call_verification_status,
              call_verified_at, call_verification_revoked_at
         FROM app_users
        WHERE user_id = ?
        LIMIT 1`,
      String(userIdValue || "").trim(),
    ).toArray()[0];
    if (!user) throw new Error("User not found");
    const gender = String(user.gender || "").toLowerCase();
    const supportedGender = VALID_GENDERS.has(gender);
    const verified = Number(user.call_verified || 0) === 1;
    return {
      user_id: String(user.user_id),
      gender,
      required: false,
      verification_available: supportedGender,
      random_call_eligible: supportedGender && verified,
      eligible_for_receiver_earnings: gender === "female" && verified,
      verified,
      status: supportedGender
        ? String(user.call_verification_status || "unverified")
        : "not_available",
      verified_at:
        user.call_verified_at == null ? null : Number(user.call_verified_at),
      revoked_at:
        user.call_verification_revoked_at == null
          ? null
          : Number(user.call_verification_revoked_at),
    };
  }

  submitCallVerification(userIdValue, input) {
    const userId = String(userIdValue || "").trim();
    const user = this.ctx.storage.sql.exec(
      "SELECT user_id, gender, call_verified FROM app_users WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!user) throw new Error("User not found");
    if (!VALID_GENDERS.has(String(user.gender || "").toLowerCase())) {
      throw new Error("Call verification is unavailable for this account");
    }
    if (Number(user.call_verified || 0) === 1) {
      return {
        ok: true,
        already_verified: true,
        verification: this.callVerificationStatus(userId),
      };
    }

    const photos = Array.isArray(input?.photos) ? input.photos : [];
    if (photos.length !== 3) {
      throw new Error("Exactly 3 live verification photos are required");
    }
    const normalized = photos.map((value) => String(value || ""));
    for (const photo of normalized) {
      if (!photo.startsWith("data:image/")) {
        throw new Error("Verification photos must be image captures");
      }
      if (photo.length > CALL_VERIFICATION_IMAGE_MAX_LENGTH) {
        throw new Error("Verification photo is too large");
      }
    }

    const now = Date.now();
    const id =
      "verify-" + now.toString(36) + "-" + crypto.randomUUID().slice(0, 8);
    const systemPassed = input?.system_passed === true;
    const details =
      input?.system_details && typeof input.system_details === "object"
        ? input.system_details
        : {};
    this.ctx.storage.sql.exec(
      `INSERT INTO call_verification_submissions
        (id, user_id, status, system_passed, system_details_json,
         photo_front_data_url, photo_left_data_url, photo_right_data_url,
         created_at)
       VALUES (?, ?, 'pending_owner', ?, ?, ?, ?, ?, ?)`,
      id,
      userId,
      systemPassed ? 1 : 0,
      JSON.stringify(details),
      normalized[0],
      normalized[1],
      normalized[2],
      now,
    );
    this.ctx.storage.sql.exec(
      `UPDATE app_users
          SET call_verified = 0,
              call_verification_status = 'pending_owner',
              updated_at = ?
        WHERE user_id = ?`,
      now,
      userId,
    );
    return {
      ok: true,
      already_verified: false,
      submission_id: id,
      status: "pending_owner",
      system_passed: systemPassed,
      contact_official_manager: !systemPassed,
    };
  }

  listCallVerificationSubmissions() {
    return this.ctx.storage.sql.exec(
      `SELECT v.*, u.display_name, u.gender, u.call_verified,
              u.call_verification_status
         FROM call_verification_submissions v
         JOIN app_users u ON u.user_id = v.user_id
        ORDER BY
          CASE v.status WHEN 'pending_owner' THEN 0 ELSE 1 END,
          v.created_at DESC
        LIMIT 300`,
    ).toArray().map((row) => ({
      id: String(row.id),
      user_id: String(row.user_id),
      display_name: String(row.display_name || row.user_id),
      gender: String(row.gender || ""),
      status: String(row.status),
      system_passed: Number(row.system_passed || 0) === 1,
      system_details: JSON.parse(String(row.system_details_json || "{}")),
      photos: [
        String(row.photo_front_data_url),
        String(row.photo_left_data_url),
        String(row.photo_right_data_url),
      ],
      call_verified: Number(row.call_verified || 0) === 1,
      call_verification_status: String(
        row.call_verification_status || "unverified"
      ),
      created_at: Number(row.created_at),
      reviewed_at:
        row.reviewed_at == null ? null : Number(row.reviewed_at),
      review_note: row.review_note ? String(row.review_note) : null,
    }));
  }

  reviewCallVerification(submissionIdValue, approveValue, noteValue = "") {
    const submissionId = String(submissionIdValue || "").trim();
    const approve = approveValue === true;
    const row = this.ctx.storage.sql.exec(
      "SELECT * FROM call_verification_submissions WHERE id = ? LIMIT 1",
      submissionId,
    ).toArray()[0];
    if (!row) throw new Error("Verification submission not found");
    const now = Date.now();
    const status = approve ? "approved" : "rejected";
    this.ctx.storage.sql.exec(
      `UPDATE call_verification_submissions
          SET status = ?, reviewed_at = ?, review_note = ?
        WHERE id = ?`,
      status,
      now,
      cleanText(noteValue, 500) || null,
      submissionId,
    );
    this.ctx.storage.sql.exec(
      `UPDATE app_users
          SET call_verified = ?,
              call_verification_status = ?,
              call_verified_at = ?,
              call_verification_revoked_at = NULL,
              updated_at = ?
        WHERE user_id = ?`,
      approve ? 1 : 0,
      approve ? "verified" : "rejected",
      approve ? now : null,
      now,
      String(row.user_id),
    );
    return {
      ok: true,
      submission_id: submissionId,
      user_id: String(row.user_id),
      verified: approve,
      status: approve ? "verified" : "rejected",
    };
  }

  verifyCallManually(userIdValue, noteValue = "") {
    const userId = String(userIdValue || "").trim();
    if (!userId) throw new Error("User ID is required");
    const user = this.ctx.storage.sql.exec(
      "SELECT user_id, display_name, gender FROM app_users WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!user) throw new Error("User not found");

    const now = Date.now();
    const note = cleanText(noteValue, 500);
    this.ctx.storage.sql.exec(
      `UPDATE app_users
          SET call_verified = 1,
              call_verification_status = 'verified_owner',
              call_verified_at = ?,
              call_verification_revoked_at = NULL,
              updated_at = ?
        WHERE user_id = ?`,
      now,
      now,
      userId,
    );
    this.ctx.storage.sql.exec(
      `UPDATE call_verification_submissions
          SET status = 'approved_owner_override',
              reviewed_at = ?,
              review_note = ?
        WHERE user_id = ?
          AND status = 'pending_owner'`,
      now,
      note || "Verified manually by Owner",
      userId,
    );

    return {
      ok: true,
      user_id: userId,
      display_name: String(user.display_name || userId),
      gender: String(user.gender || ""),
      verified: true,
      status: "verified_owner",
      verified_at: now,
      note,
    };
  }

  revokeCallVerification(userIdValue, noteValue = "") {
    const userId = String(userIdValue || "").trim();
    const user = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!user) throw new Error("User not found");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `UPDATE app_users
          SET call_verified = 0,
              call_verification_status = 'revoked',
              call_verification_revoked_at = ?,
              updated_at = ?
        WHERE user_id = ?`,
      now,
      now,
      userId,
    );
    return {
      ok: true,
      user_id: userId,
      verified: false,
      status: "revoked",
      note: cleanText(noteValue, 500),
    };
  }

  settleCallBilling(callIdValue, nowValue = Date.now()) {
    const callId = String(callIdValue || "").trim();
    const now = Number(nowValue || Date.now());
    const row = this.ctx.storage.sql.exec(
      "SELECT * FROM app_calls WHERE id = ? LIMIT 1",
      callId,
    ).toArray()[0];
    if (!row || String(row.state) !== "accepted" || row.accepted_at == null) {
      return row ? this.getCall(callId) : null;
    }

    const acceptedAt = Number(row.accepted_at);
    const targetMinutes =
      1 + Math.max(0, Math.floor((now - acceptedAt) / 60000));
    const billedMinutes = Number(row.billed_minutes || 0);
    const dueMinutes = targetMinutes - billedMinutes;
    if (dueMinutes <= 0) return this.getCall(callId);

    const callerWallet = this.getWallet(row.caller_id);
    const affordableMinutes = Math.min(
      dueMinutes,
      Math.floor(
        callerWallet.coins /
          Number(row.cost_coins_per_minute || UNVERIFIED_DIRECT_CALL_COST_COINS_PER_MINUTE)
      ),
    );

    if (affordableMinutes > 0) {
      const perMinuteCost = Number(
        row.cost_coins_per_minute || UNVERIFIED_DIRECT_CALL_COST_COINS_PER_MINUTE
      );
      const perMinuteReward = Number(row.receiver_diamonds_per_minute || 0);
      const callerCost = affordableMinutes * perMinuteCost;
      const receiverReward =
        Number(row.receiver_earning_eligible || 0) === 1
          ? affordableMinutes * perMinuteReward
          : 0;
      this.ctx.storage.sql.exec(
        `UPDATE app_wallets
            SET coins = coins - ?, updated_at = ?
          WHERE user_id = ?`,
        callerCost,
        now,
        String(row.caller_id),
      );
      if (receiverReward > 0) {
        this.ctx.storage.sql.exec(
          `UPDATE app_wallets
              SET diamonds = diamonds + ?, updated_at = ?
            WHERE user_id = ?`,
          receiverReward,
          now,
          String(row.receiver_id),
        );
      }
      this.ctx.storage.sql.exec(
        `UPDATE app_calls
            SET billed_minutes = billed_minutes + ?,
                caller_cost_coins = caller_cost_coins + ?,
                receiver_reward_diamonds = receiver_reward_diamonds + ?,
                updated_at = ?
          WHERE id = ?`,
        affordableMinutes,
        callerCost,
        receiverReward,
        now,
        callId,
      );
    }

    if (affordableMinutes < dueMinutes) {
      this.ctx.storage.sql.exec(
        `UPDATE app_calls
            SET state = 'ended',
                end_reason = 'insufficient_coins',
                updated_at = ?
          WHERE id = ?`,
        now,
        callId,
      );
      this._recordRandomCallCompletion(callId);
    }
    return this.getCall(callId);
  }

  _recordRandomCallCompletion(callIdValue) {
    const callId = String(callIdValue || "").trim();
    const row = this.ctx.storage.sql.exec(
      "SELECT * FROM app_calls WHERE id = ? LIMIT 1",
      callId,
    ).toArray()[0];
    if (!row || String(row.call_kind || "direct") !== "random") return;
    if (Number(row.stats_recorded || 0) === 1) return;
    const minutes = Number(row.billed_minutes || 0);
    this.ctx.storage.sql.exec(
      `INSERT INTO random_call_stats
        (user_id, offers, answered, completed_calls, total_minutes,
         last_offer_at, updated_at)
       VALUES (?, 0, 0, 1, ?, NULL, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         completed_calls = completed_calls + 1,
         total_minutes = total_minutes + excluded.total_minutes,
         updated_at = excluded.updated_at`,
      String(row.receiver_id),
      minutes,
      Date.now(),
    );
    this.ctx.storage.sql.exec(
      "UPDATE app_calls SET stats_recorded = 1 WHERE id = ?",
      callId,
    );
  }

  _isUserBusyInCall(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return false;
    const row = this.ctx.storage.sql.exec(
      `SELECT id FROM app_calls
        WHERE state IN ('ringing', 'accepted')
          AND (caller_id = ? OR receiver_id = ?)
        LIMIT 1`,
      userId,
      userId,
    ).toArray()[0];
    return Boolean(row);
  }

  _randomCallCandidate(callerIdValue, genderValue) {
    const callerId = String(callerIdValue || "").trim();
    const gender = String(genderValue || "").trim().toLowerCase();
    if (!VALID_GENDERS.has(gender)) {
      throw new Error("Choose Girls or Boys before starting a random call");
    }

    const candidates = this.ctx.storage.sql.exec(
      `SELECT u.user_id, u.display_name, u.gender, u.call_verified_at,
              COALESCE(s.offers, 0) AS offers,
              COALESCE(s.answered, 0) AS answered,
              COALESCE(s.completed_calls, 0) AS completed_calls,
              COALESCE(s.total_minutes, 0) AS total_minutes,
              s.last_offer_at
         FROM app_users u
         LEFT JOIN random_call_stats s ON s.user_id = u.user_id
        WHERE u.user_id != ?
          AND u.gender = ?
          AND u.call_verified = 1`,
      callerId,
      gender,
    ).toArray().filter((row) => {
      const id = String(row.user_id);
      return !this._isUserBusyInCall(id) && !this.isBlockedBetween(callerId, id);
    });

    if (candidates.length === 0) return null;

    const callerRandomCount = Number(
      this.ctx.storage.sql.exec(
        `SELECT COUNT(*) AS count
           FROM app_calls
          WHERE caller_id = ? AND call_kind = 'random'`,
        callerId,
      ).toArray()[0]?.count || 0
    );

    const now = Date.now();
    const fresh = candidates.filter((row) =>
      row.call_verified_at != null &&
      now - Number(row.call_verified_at) <= 7 * 24 * 60 * 60 * 1000 &&
      Number(row.offers || 0) < 5
    );

    let pool = candidates;
    // 1 in every 5 random calls gives a fresh verified ID an exposure slot.
    if (callerRandomCount % 5 === 4 && fresh.length > 0) {
      pool = fresh;
      pool.sort((a, b) => {
        const offersDiff = Number(a.offers || 0) - Number(b.offers || 0);
        if (offersDiff !== 0) return offersDiff;
        return Number(a.call_verified_at || 0) - Number(b.call_verified_at || 0);
      });
    } else {
      pool.sort((a, b) => {
        const scoreA =
          Number(a.completed_calls || 0) * 100 +
          Number(a.answered || 0) * 20 +
          Number(a.total_minutes || 0);
        const scoreB =
          Number(b.completed_calls || 0) * 100 +
          Number(b.answered || 0) * 20 +
          Number(b.total_minutes || 0);
        if (scoreA !== scoreB) return scoreB - scoreA;
        return Number(a.last_offer_at || 0) - Number(b.last_offer_at || 0);
      });
    }
    return pool[0] || null;
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
    if (!["voice", "video"].includes(media)) {
      throw new Error("Unsupported call type");
    }
    const receiverVerification = this.callVerificationStatus(receiverId);
    const receiver = this.ctx.storage.sql.exec(
      "SELECT gender FROM app_users WHERE user_id = ? LIMIT 1",
      receiverId,
    ).toArray()[0];
    const receiverFemale =
      String(receiver?.gender || "").toLowerCase() === "female";
    const directCostPerMinute = receiverVerification.verified
      ? VERIFIED_DIRECT_CALL_COST_COINS_PER_MINUTE
      : UNVERIFIED_DIRECT_CALL_COST_COINS_PER_MINUTE;
    const rewardPercent = receiverVerification.verified
      ? VERIFIED_RECEIVER_REWARD_PERCENT
      : UNVERIFIED_RECEIVER_REWARD_PERCENT;
    const receiverRewardPerMinute = receiverFemale
      ? Math.floor(directCostPerMinute * rewardPercent / 100)
      : 0;

    const callerWallet = this.getWallet(callerId);
    if (callerWallet.coins < directCostPerMinute) {
      throw new Error(
        "At least " +
        directCostPerMinute.toLocaleString("en-US") +
        " coins are required to start this friend call"
      );
    }

    this.ctx.storage.sql.exec(
      `UPDATE app_calls
          SET state = 'ended', updated_at = ?
        WHERE (caller_id IN (?, ?) OR receiver_id IN (?, ?))
          AND state IN ('ringing', 'accepted')`,
      Date.now(),
      callerId,
      receiverId,
      callerId,
      receiverId,
    );

    const receiverEligible = receiverFemale;
    const now = Date.now();
    const id = "call-" + now.toString(36) + "-" + crypto.randomUUID().slice(0, 8);
    const roomId = "call-" + id;
    this.ctx.storage.sql.exec(
      `INSERT INTO app_calls
        (id, caller_id, receiver_id, media, state, room_id,
         receiver_earning_eligible, call_kind, cost_coins_per_minute,
         receiver_diamonds_per_minute, created_at, updated_at)
       VALUES (?, ?, ?, ?, 'ringing', ?, ?, 'direct', ?, ?, ?, ?)`,
      id,
      callerId,
      receiverId,
      media,
      roomId,
      receiverEligible ? 1 : 0,
      directCostPerMinute,
      receiverRewardPerMinute,
      now,
      now,
    );
    this._sendCallOfficialMessage(receiverId, {
      call_kind: "direct",
      verified: receiverVerification.verified === true,
      gender: receiverVerification.gender,
      cost_coins_per_minute: directCostPerMinute,
      receiver_diamonds_per_minute: receiverRewardPerMinute,
    });
    return this.getCall(id);
  }

  createRandomCall(callerIdValue, genderValue, mediaValue = "voice") {
    const callerId = String(callerIdValue || "").trim();
    const gender = String(genderValue || "").trim().toLowerCase();
    const media = String(mediaValue || "voice").toLowerCase();
    if (!callerId) throw new Error("caller ID is required");
    if (!["voice", "video"].includes(media)) {
      throw new Error("Unsupported call type");
    }

    const callerWallet = this.getWallet(callerId);
    if (callerWallet.coins < RANDOM_CALL_COST_COINS_PER_MINUTE) {
      throw new Error("At least 500,000 coins are required to start a random call");
    }

    const candidate = this._randomCallCandidate(callerId, gender);
    if (!candidate) {
      throw new Error("No verified available " + (gender === "female" ? "girl" : "boy") + " is free right now");
    }

    const receiverId = String(candidate.user_id);
    const receiverVerification = this.callVerificationStatus(receiverId);
    const receiverEligible =
      receiverVerification.eligible_for_receiver_earnings === true;
    const receiverRewardPerMinute = receiverEligible
      ? Math.floor(
          RANDOM_CALL_COST_COINS_PER_MINUTE *
            VERIFIED_RECEIVER_REWARD_PERCENT / 100
        )
      : 0;

    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO random_call_stats
        (user_id, offers, answered, completed_calls, total_minutes,
         last_offer_at, updated_at)
       VALUES (?, 1, 0, 0, 0, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         offers = offers + 1,
         last_offer_at = excluded.last_offer_at,
         updated_at = excluded.updated_at`,
      receiverId,
      now,
      now,
    );

    const id = "call-" + now.toString(36) + "-" + crypto.randomUUID().slice(0, 8);
    const roomId = "call-" + id;
    this.ctx.storage.sql.exec(
      `INSERT INTO app_calls
        (id, caller_id, receiver_id, media, state, room_id,
         receiver_earning_eligible, call_kind, cost_coins_per_minute,
         receiver_diamonds_per_minute, created_at, updated_at)
       VALUES (?, ?, ?, ?, 'ringing', ?, ?, 'random', ?, ?, ?, ?)`,
      id,
      callerId,
      receiverId,
      media,
      roomId,
      receiverEligible ? 1 : 0,
      RANDOM_CALL_COST_COINS_PER_MINUTE,
      receiverRewardPerMinute,
      now,
      now,
    );
    this._sendCallOfficialMessage(receiverId, {
      call_kind: "random",
      verified: receiverVerification.verified === true,
      gender: receiverVerification.gender,
      cost_coins_per_minute: RANDOM_CALL_COST_COINS_PER_MINUTE,
      receiver_diamonds_per_minute: receiverRewardPerMinute,
    });
    return this.getCall(id);
  }

  _sendCallOfficialMessage(receiverIdValue, input) {
    const receiverId = String(receiverIdValue || "").trim();
    if (!receiverId) return null;
    const kind = String(input?.call_kind || "direct");
    const verified = input?.verified === true;
    const gender = String(input?.gender || "");
    const cost = Number(input?.cost_coins_per_minute || 0);
    const reward = Number(input?.receiver_diamonds_per_minute || 0);

    let text =
      "[CALL_VERIFY] Incoming " +
      (kind === "random" ? "random" : "friend") +
      " paid call. Caller cost: " +
      cost.toLocaleString("en-US") +
      " coins/min. ";

    if (gender === "female") {
      text += verified
        ? "Your ID is Verified. You receive 80% = " +
          reward.toLocaleString("en-US") +
          " diamonds/min when you answer this call. "
        : "Your ID is Unverified. You can answer this call and receive 50% = " +
          reward.toLocaleString("en-US") +
          " diamonds/min. Complete one-time verification to become eligible for the 80% verified rate. ";
    } else {
      text += verified
        ? "Your ID is Verified for the random-call pool. "
        : "Verification is optional for friend calls, but required to enter the verified random-call pool. ";
    }
    text +=
      "Verification is done once and is asked again only if Owner removes Verified status. Open Verify Call ID from this Official message.";

    return this.sendOfficialMessage(receiverId, text, {
      action: "call_verification",
      call_kind: kind,
    });
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
    const callerWallet = this.getWallet(row.caller_id);
    const receiverWallet = this.getWallet(row.receiver_id);
    const receiverVerification = this.callVerificationStatus(row.receiver_id);
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
      accepted_at: row.accepted_at == null ? null : Number(row.accepted_at),
      billed_minutes: Number(row.billed_minutes || 0),
      caller_cost_coins: Number(row.caller_cost_coins || 0),
      receiver_reward_diamonds: Number(row.receiver_reward_diamonds || 0),
      receiver_earning_eligible:
        Number(row.receiver_earning_eligible || 0) === 1,
      call_kind: String(row.call_kind || "direct"),
      cost_coins_per_minute: Number(
        row.cost_coins_per_minute || UNVERIFIED_DIRECT_CALL_COST_COINS_PER_MINUTE
      ),
      receiver_diamonds_per_minute: Number(
        row.receiver_diamonds_per_minute || 0
      ),
      end_reason: row.end_reason ? String(row.end_reason) : null,
      caller_balance_coins: callerWallet.coins,
      receiver_balance_diamonds: receiverWallet.diamonds,
      receiver_verification: receiverVerification,
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
    const now = Date.now();
    if (acceptValue) {
      this.ctx.storage.sql.exec(
        `UPDATE app_calls
            SET state = 'accepted',
                accepted_at = ?,
                updated_at = ?
          WHERE id = ?`,
        now,
        now,
        call.id,
      );
      if (call.call_kind === "random") {
        this.ctx.storage.sql.exec(
          `INSERT INTO random_call_stats
            (user_id, offers, answered, completed_calls, total_minutes,
             last_offer_at, updated_at)
           VALUES (?, 0, 1, 0, 0, NULL, ?)
           ON CONFLICT(user_id) DO UPDATE SET
             answered = answered + 1,
             updated_at = excluded.updated_at`,
          userId,
          now,
        );
      }
      return this.settleCallBilling(call.id, now);
    }
    this.ctx.storage.sql.exec(
      "UPDATE app_calls SET state = 'rejected', updated_at = ? WHERE id = ?",
      now,
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
    if (call.state === "accepted") {
      this.settleCallBilling(call.id, Date.now());
    }
    this.ctx.storage.sql.exec(
      "UPDATE app_calls SET state = 'ended', updated_at = ? WHERE id = ?",
      Date.now(),
      call.id,
    );
    this._recordRandomCallCompletion(call.id);
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

  markConversationSeen(userIdValue, peerUserIdValue) {
    const userId = String(userIdValue || "").trim();
    const peerUserId = String(peerUserIdValue || "").trim();
    if (!userId || !peerUserId) throw new Error("user IDs are required");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `UPDATE direct_messages
          SET seen_at = ?
        WHERE from_user_id = ?
          AND to_user_id = ?
          AND seen_at IS NULL`,
      now,
      peerUserId,
      userId,
    );
    return now;
  }

  listDirectMessages(userIdValue, peerUserIdValue, limitValue = 200) {
    const userId = String(userIdValue || "").trim();
    const peerUserId = String(peerUserIdValue || "").trim();
    const limit = Math.max(1, Math.min(500, Number(limitValue) || 200));
    if (!userId || !peerUserId) throw new Error("user IDs are required");
    if (this.isBlockedBetween(userId, peerUserId)) {
      return [];
    }

    this.markConversationSeen(userId, peerUserId);

    return this.ctx.storage.sql.exec(
      `SELECT id, from_user_id, to_user_id, text, created_at, seen_at
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
      seen_at: row.seen_at == null ? null : Number(row.seen_at),
    }));
  }

  listMessageThreads(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) throw new Error("user ID is required");

    const threads = this.listFriends(userId).map((friend) => {
      const friendId = String(friend.user_id);
      const last = this.ctx.storage.sql.exec(
        `SELECT id, from_user_id, to_user_id, text, created_at, seen_at
           FROM direct_messages
          WHERE (from_user_id = ? AND to_user_id = ?)
             OR (from_user_id = ? AND to_user_id = ?)
          ORDER BY created_at DESC
          LIMIT 1`,
        userId,
        friendId,
        friendId,
        userId,
      ).toArray()[0];
      const unread = this.ctx.storage.sql.exec(
        `SELECT COUNT(*) AS count
           FROM direct_messages
          WHERE from_user_id = ?
            AND to_user_id = ?
            AND seen_at IS NULL`,
        friendId,
        userId,
      ).toArray()[0];

      return {
        user_id: friendId,
        display_name: String(friend.display_name || friendId),
        avatar_data_url: friend.avatar_data_url
          ? String(friend.avatar_data_url)
          : null,
        is_friend: true,
        last_message: last
          ? {
              id: String(last.id),
              from: String(last.from_user_id),
              to: String(last.to_user_id),
              text: String(last.text),
              created_at: Number(last.created_at),
              seen_at: last.seen_at == null ? null : Number(last.seen_at),
            }
          : null,
        unread_count: Number(unread?.count || 0),
      };
    });

    const official = this.ctx.storage.sql.exec(
      `SELECT id, from_user_id, to_user_id, text, created_at, seen_at
         FROM direct_messages
        WHERE (from_user_id = 'tinni-official' AND to_user_id = ?)
           OR (from_user_id = ? AND to_user_id = 'tinni-official')
        ORDER BY created_at DESC
        LIMIT 1`,
      userId,
      userId,
    ).toArray()[0];

    if (official) {
      const unreadOfficial = this.ctx.storage.sql.exec(
        `SELECT COUNT(*) AS count
           FROM direct_messages
          WHERE from_user_id = 'tinni-official'
            AND to_user_id = ?
            AND seen_at IS NULL`,
        userId,
      ).toArray()[0];
      threads.push({
        user_id: "tinni-official",
        display_name: "Tinni Official",
        avatar_data_url: null,
        is_friend: false,
        last_message: {
          id: String(official.id),
          from: String(official.from_user_id),
          to: String(official.to_user_id),
          text: String(official.text),
          created_at: Number(official.created_at),
          seen_at: official.seen_at == null ? null : Number(official.seen_at),
        },
        unread_count: Number(unreadOfficial?.count || 0),
      });
    }

    threads.sort((a, b) => {
      const aTime = Number(a.last_message?.created_at || 0);
      const bTime = Number(b.last_message?.created_at || 0);
      if (aTime !== bTime) return bTime - aTime;
      return String(a.display_name).localeCompare(String(b.display_name));
    });
    return threads;
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
        (id, from_user_id, to_user_id, text, created_at, seen_at)
       VALUES (?, ?, ?, ?, ?, NULL)`,
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
      seen_at: null,
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
        (id, from_user_id, to_user_id, text, created_at, seen_at)
       VALUES (?, 'tinni-official', ?, ?, ?, NULL)`,
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
      seen_at: null,
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

    const roomControl = this.ctx.storage.sql.exec(
      "SELECT banned FROM owner_room_controls WHERE room_id = ? LIMIT 1",
      roomId,
    ).toArray()[0];
    if (Number(roomControl?.banned || 0) === 1) {
      return { ok: false, allowed: false, reason: "room_banned" };
    }

    const userControl = this._userControls(userId);
    if (userControl.locked_bypass) {
      return { ok: true, allowed: true, owner_bypass: true, owner_override: true };
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
