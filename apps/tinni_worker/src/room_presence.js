import { DurableObject } from "cloudflare:workers";

const MEMBER_TTL_MS = 30000;

export class RoomPresenceStore extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS room_members (
        user_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        joined_at INTEGER NOT NULL,
        last_seen INTEGER NOT NULL
      );
    `);
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
      `SELECT user_id, display_name, joined_at, last_seen
         FROM room_members
        ORDER BY joined_at ASC`,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      display_name: String(row.display_name),
      joined_at: Number(row.joined_at),
      last_seen: Number(row.last_seen),
    }));
  }

  async join(input) {
    const now = Date.now();
    const userId = String(input?.user_id || "").trim();
    const displayName = String(input?.display_name || "").trim() || "Tinni User";
    if (!userId) throw new Error("user_id is required");

    this.ctx.storage.sql.exec(
      `INSERT INTO room_members (user_id, display_name, joined_at, last_seen)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         display_name = excluded.display_name,
         last_seen = excluded.last_seen`,
      userId,
      displayName,
      now,
      now,
    );

    return {
      ok: true,
      server_time: now,
      members: this._members(now),
    };
  }

  async heartbeat(input) {
    const now = Date.now();
    const userId = String(input?.user_id || "").trim();
    const displayName = String(input?.display_name || "").trim() || "Tinni User";
    if (!userId) throw new Error("user_id is required");

    this.ctx.storage.sql.exec(
      `INSERT INTO room_members (user_id, display_name, joined_at, last_seen)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         display_name = excluded.display_name,
         last_seen = excluded.last_seen`,
      userId,
      displayName,
      now,
      now,
    );

    return {
      ok: true,
      server_time: now,
      members: this._members(now),
    };
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
