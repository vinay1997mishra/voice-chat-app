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
        seat_index INTEGER,
        seat_emote TEXT,
        seat_emote_until INTEGER,
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

      CREATE TABLE IF NOT EXISTS room_mutes (
        user_id TEXT PRIMARY KEY,
        seat_index INTEGER NOT NULL,
        muted_by TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    `);

    for (const migration of [
      "ALTER TABLE room_members ADD COLUMN avatar_data_url TEXT",
      "ALTER TABLE room_members ADD COLUMN flag_emoji TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE room_members ADD COLUMN country_code TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE room_members ADD COLUMN seat_index INTEGER",
      "ALTER TABLE room_members ADD COLUMN seat_emote TEXT",
      "ALTER TABLE room_members ADD COLUMN seat_emote_until INTEGER",
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

  setEmote(input) {
    const now = Date.now();
    const userId = String(input?.user_id || "").trim();
    const emote = String(input?.emote || "").trim();
    const seatIndex = Number(input?.seat_index);

    if (!userId) throw new Error("user_id is required");
    if (!emote || emote.length > 16) {
      throw new Error("emote is invalid");
    }
    if (!Number.isInteger(seatIndex) || seatIndex < 0) {
      throw new Error("seat_index is required");
    }

    const member = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_members WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!member || member.seat_index === null || member.seat_index === undefined) {
      throw new Error("You must be on a seat to use emotes");
    }
    if (Number(member.seat_index) !== seatIndex) {
      throw new Error("Seat changed. Try again.");
    }

    this.ctx.storage.sql.exec(
      "UPDATE room_members SET seat_emote = ?, seat_emote_until = ?, last_seen = ? WHERE user_id = ?",
      emote,
      now + 3000,
      now,
      userId,
    );

    return {
      ok: true,
      server_time: now,
      members: this._members(now),
    };
  }

    muteStatus(userIdValue, seatIndexValue = null) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return false;
    const row = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_mutes WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!row) return false;
    if (seatIndexValue === null || seatIndexValue === undefined) return true;
    return Number(row.seat_index) === Number(seatIndexValue);
  }

  setMute(input) {
    const now = Date.now();
    const targetUserId = String(input?.target_user_id || "").trim();
    const mutedBy = String(input?.muted_by || "").trim();
    const muted = Boolean(input?.muted);
    const seatIndex = Number(input?.seat_index);

    if (!targetUserId) throw new Error("target_user_id is required");
    if (!mutedBy) throw new Error("muted_by is required");
    if (!Number.isInteger(seatIndex) || seatIndex < 0) {
      throw new Error("seat_index is required");
    }

    const member = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_members WHERE user_id = ? LIMIT 1",
      targetUserId,
    ).toArray()[0];
    if (!member || member.seat_index === null || member.seat_index === undefined) {
      throw new Error("User is not on a seat");
    }
    if (Number(member.seat_index) !== seatIndex) {
      throw new Error("User changed seat");
    }

    if (muted) {
      this.ctx.storage.sql.exec(
        `INSERT INTO room_mutes (user_id, seat_index, muted_by, created_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(user_id) DO UPDATE SET
           seat_index = excluded.seat_index,
           muted_by = excluded.muted_by,
           created_at = excluded.created_at`,
        targetUserId,
        seatIndex,
        mutedBy,
        now,
      );
    } else {
      this.ctx.storage.sql.exec(
        "DELETE FROM room_mutes WHERE user_id = ?",
        targetUserId,
      );
    }

    return {
      ok: true,
      server_time: now,
      target_user_id: targetUserId,
      seat_index: seatIndex,
      muted,
      members: this._members(now),
    };
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
              country_code, seat_index, seat_emote, seat_emote_until, joined_at, last_seen
         FROM room_members
        ORDER BY joined_at ASC`,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      display_name: String(row.display_name),
      avatar_data_url: row.avatar_data_url ? String(row.avatar_data_url) : null,
      flag_emoji: String(row.flag_emoji || ""),
      country_code: String(row.country_code || ""),
      seat_index:
        row.seat_index === null || row.seat_index === undefined
          ? null
          : Number(row.seat_index),
      mic_muted: this.muteStatus(row.user_id, row.seat_index),
      seat_emote:
        row.seat_emote &&
        row.seat_emote_until !== null &&
        row.seat_emote_until !== undefined &&
        Number(row.seat_emote_until) > now
          ? String(row.seat_emote)
          : null,
      seat_emote_until:
        row.seat_emote &&
        row.seat_emote_until !== null &&
        row.seat_emote_until !== undefined &&
        Number(row.seat_emote_until) > now
          ? Number(row.seat_emote_until)
          : null,
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
    const rawSeatIndex = input?.seat_index;
    const seatIndex =
      rawSeatIndex === null || rawSeatIndex === undefined
        ? null
        : Number(rawSeatIndex);

    if (!userId) throw new Error("user_id is required");
    if (!displayName) throw new Error("display_name is required");
    if (seatIndex !== null && (!Number.isInteger(seatIndex) || seatIndex < 0)) {
      throw new Error("seat_index is invalid");
    }

    const kick = this.kickStatus(userId, now);
    if (kick) {
      const suffix = kick.permanent ? "permanent" : String(kick.expires_at);
      throw new Error("KICKED_FROM_ROOM:" + suffix);
    }

    const previousMember = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_members WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    const seatChanged =
      previousMember &&
      (
        (previousMember.seat_index === null || previousMember.seat_index === undefined)
          ? seatIndex !== null
          : seatIndex === null || Number(previousMember.seat_index) !== seatIndex
      );

    const muteRow = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_mutes WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (
      muteRow &&
      (seatIndex === null || Number(muteRow.seat_index) !== seatIndex)
    ) {
      this.ctx.storage.sql.exec(
        "DELETE FROM room_mutes WHERE user_id = ?",
        userId,
      );
    }

    this.ctx.storage.sql.exec(
      `INSERT INTO room_members
        (user_id, display_name, avatar_data_url, flag_emoji, country_code,
         seat_index, seat_emote, seat_emote_until, joined_at, last_seen)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         display_name = excluded.display_name,
         avatar_data_url = excluded.avatar_data_url,
         flag_emoji = excluded.flag_emoji,
         country_code = excluded.country_code,
         seat_index = excluded.seat_index,
         seat_emote = CASE
           WHEN room_members.seat_index IS excluded.seat_index THEN room_members.seat_emote
           ELSE NULL
         END,
         last_seen = excluded.last_seen`,
      userId,
      displayName,
      avatarDataUrl,
      flagEmoji,
      countryCode,
      seatIndex,
      null,
      null,
      now,
      now,
    );

    return {
      ok: true,
      server_time: now,
      self_mic_muted: this.muteStatus(userId, seatIndex),
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
      this.ctx.storage.sql.exec(
        "DELETE FROM room_mutes WHERE user_id = ?",
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
