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
