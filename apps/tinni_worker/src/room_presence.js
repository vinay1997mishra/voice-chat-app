import { DurableObject } from "cloudflare:workers";

const MEMBER_TTL_MS = 30000;

export class RoomPresenceStore extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS room_members (
        user_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        avatar_data_url TEXT,
        flag_emoji TEXT NOT NULL DEFAULT '',
        country_code TEXT NOT NULL DEFAULT '',
        joined_at INTEGER NOT NULL,
        last_seen INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_kicks (
        user_id TEXT PRIMARY KEY,
        expires_at INTEGER,
        kicked_by TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_managers (
        user_id TEXT PRIMARY KEY,
        role TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    `);

    for (const migration of [
      "ALTER TABLE room_members ADD COLUMN avatar_data_url TEXT",
      "ALTER TABLE room_members ADD COLUMN flag_emoji TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE room_members ADD COLUMN country_code TEXT NOT NULL DEFAULT ''",
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
  }

  _prune(now = Date.now()) {
    this.ctx.storage.sql.exec(
      "DELETE FROM room_members WHERE last_seen < ?",
      now - MEMBER_TTL_MS,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_kicks WHERE expires_at IS NOT NULL AND expires_at <= ?",
      now,
    );
  }

  kickStatus(userIdValue, now = Date.now()) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return null;
    this._prune(now);
    const row = this.ctx.storage.sql.exec(
      "SELECT expires_at FROM room_kicks WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!row) return null;
    return {
      kicked: true,
      permanent: row.expires_at === null || row.expires_at === undefined,
      expires_at:
        row.expires_at === null || row.expires_at === undefined
          ? null
          : Number(row.expires_at),
    };
  }

  isManager(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return false;
    const row = this.ctx.storage.sql.exec(
      "SELECT user_id FROM room_managers WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    return Boolean(row);
  }

  setManager(userIdValue, enabled) {
    const userId = String(userIdValue || "").trim();
    if (!userId) throw new Error("user_id is required");
    if (enabled) {
      this.ctx.storage.sql.exec(
        `INSERT INTO room_managers (user_id, role, updated_at)
         VALUES (?, 'admin', ?)
         ON CONFLICT(user_id) DO UPDATE SET
           role = excluded.role,
           updated_at = excluded.updated_at`,
        userId,
        Date.now(),
      );
    } else {
      this.ctx.storage.sql.exec(
        "DELETE FROM room_managers WHERE user_id = ?",
        userId,
      );
    }
    return { ok: true, user_id: userId, enabled: Boolean(enabled) };
  }

  kick(input) {
    const now = Date.now();
    const targetUserId = String(input?.target_user_id || "").trim();
    const kickedBy = String(input?.kicked_by || "").trim();
    const durationMs = input?.duration_ms;

    if (!targetUserId) throw new Error("target_user_id is required");
    if (!kickedBy) throw new Error("kicked_by is required");

    let expiresAt = null;
    if (durationMs !== null && durationMs !== undefined) {
      const duration = Number(durationMs);
      if (!Number.isFinite(duration) || duration <= 0) {
        throw new Error("duration_ms must be positive or null");
      }
      expiresAt = now + duration;
    }

    this.ctx.storage.sql.exec(
      `INSERT INTO room_kicks (user_id, expires_at, kicked_by, created_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         expires_at = excluded.expires_at,
         kicked_by = excluded.kicked_by,
         created_at = excluded.created_at`,
      targetUserId,
      expiresAt,
      kickedBy,
      now,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_members WHERE user_id = ?",
      targetUserId,
    );

    return {
      ok: true,
      server_time: now,
      kicked_user_id: targetUserId,
      expires_at: expiresAt,
      members: this._members(now),
    };
  }

  _members(now = Date.now()) {
    this._prune(now);
    return this.ctx.storage.sql.exec(
      `SELECT user_id, display_name, avatar_data_url, flag_emoji,
              country_code, joined_at, last_seen
         FROM room_members
        ORDER BY joined_at ASC`,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      display_name: String(row.display_name),
      avatar_data_url: row.avatar_data_url ? String(row.avatar_data_url) : null,
      flag_emoji: String(row.flag_emoji || ""),
      country_code: String(row.country_code || ""),
      joined_at: Number(row.joined_at),
      last_seen: Number(row.last_seen),
    }));
  }

  _upsert(input) {
    const now = Date.now();
    const userId = String(input?.user_id || "").trim();
    const displayName = String(input?.display_name || "").trim();
    const avatarDataUrl = input?.avatar_data_url
      ? String(input.avatar_data_url)
      : null;
    const flagEmoji = String(input?.flag_emoji || "").trim();
    const countryCode = String(input?.country_code || "").trim().toUpperCase();

    if (!userId) throw new Error("user_id is required");
    if (!displayName) throw new Error("display_name is required");

    const kick = this.kickStatus(userId, now);
    if (kick) {
      const suffix = kick.permanent ? "permanent" : String(kick.expires_at);
      throw new Error("KICKED_FROM_ROOM:" + suffix);
    }

    this.ctx.storage.sql.exec(
      `INSERT INTO room_members
        (user_id, display_name, avatar_data_url, flag_emoji, country_code,
         joined_at, last_seen)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         display_name = excluded.display_name,
         avatar_data_url = excluded.avatar_data_url,
         flag_emoji = excluded.flag_emoji,
         country_code = excluded.country_code,
         last_seen = excluded.last_seen`,
      userId,
      displayName,
      avatarDataUrl,
      flagEmoji,
      countryCode,
      now,
      now,
    );

    return {
      ok: true,
      server_time: now,
      members: this._members(now),
    };
  }

  async join(input) {
    return this._upsert(input);
  }

  async heartbeat(input) {
    return this._upsert(input);
  }

  async leave(input) {
    const now = Date.now();
    const userId = String(input?.user_id || "").trim();
    if (userId) {
      this.ctx.storage.sql.exec(
        "DELETE FROM room_members WHERE user_id = ?",
        userId,
      );
    }
    return {
      ok: true,
      server_time: now,
      members: this._members(now),
    };
  }

  async state() {
    const now = Date.now();
    return {
      ok: true,
      server_time: now,
      member_ttl_ms: MEMBER_TTL_MS,
      members: this._members(now),
    };
  }
}
