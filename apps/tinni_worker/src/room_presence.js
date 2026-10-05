import { DurableObject } from "cloudflare:workers";

const MEMBER_TTL_MS = 1800000;

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
        family_tag TEXT,
        host_tag TEXT,
        agency_name TEXT,
        equipped_frame_id TEXT,
        equipped_entry_id TEXT,
        equipped_profile_card_id TEXT,
        owner_tags_json TEXT NOT NULL DEFAULT '[]',
        mic_enabled INTEGER NOT NULL DEFAULT 0,
        seat_index INTEGER,
        seat_emote TEXT,
        seat_emote_until INTEGER,
        joined_at INTEGER NOT NULL,
        last_seen INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_chat_messages (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL, display_name TEXT NOT NULL,
        text TEXT NOT NULL, is_owner INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
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

      CREATE TABLE IF NOT EXISTS room_chat_bans (
        user_id TEXT PRIMARY KEY,
        banned_by TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_seat_invites (
        target_user_id TEXT PRIMARY KEY,
        seat_index INTEGER NOT NULL,
        invited_by TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_seat_requests (
        user_id TEXT PRIMARY KEY,
        seat_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_seat_locks (
        seat_index INTEGER PRIMARY KEY,
        locked_by TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_seat_mutes (
        seat_index INTEGER PRIMARY KEY,
        muted_by TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_seat_forces (
        user_id TEXT PRIMARY KEY,
        seat_index INTEGER,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_runtime_settings (
        id INTEGER PRIMARY KEY,
        mic_mode TEXT NOT NULL DEFAULT 'apply',
        seat_count INTEGER NOT NULL DEFAULT 0,
        public_screen_enabled INTEGER NOT NULL DEFAULT 0,
        comments_clear_version INTEGER NOT NULL DEFAULT 0,
        owner_comments_clear_version INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
      INSERT OR IGNORE INTO room_runtime_settings (
        id,
        mic_mode,
        public_screen_enabled,
        comments_clear_version,
        owner_comments_clear_version,
        updated_at
      )
      VALUES (1, 'apply', 0, 0, 0, 0);

      CREATE TABLE IF NOT EXISTS room_lucky_numbers (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        number_value INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_gift_totals (
        user_id TEXT PRIMARY KEY,
        coins INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_room_lucky_numbers_time
      ON room_lucky_numbers(created_at DESC);
    `);

    for (const migration of [
      "ALTER TABLE room_members ADD COLUMN avatar_data_url TEXT",
      "ALTER TABLE room_members ADD COLUMN flag_emoji TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE room_members ADD COLUMN country_code TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE room_members ADD COLUMN family_tag TEXT",
      "ALTER TABLE room_members ADD COLUMN host_tag TEXT",
      "ALTER TABLE room_members ADD COLUMN agency_name TEXT",
      "ALTER TABLE room_members ADD COLUMN equipped_frame_id TEXT",
      "ALTER TABLE room_members ADD COLUMN equipped_entry_id TEXT",
      "ALTER TABLE room_members ADD COLUMN equipped_profile_card_id TEXT",
      "ALTER TABLE room_members ADD COLUMN owner_tags_json TEXT NOT NULL DEFAULT '[]'",
      "ALTER TABLE room_members ADD COLUMN owner_medals_json TEXT NOT NULL DEFAULT '[]'",
      "ALTER TABLE room_members ADD COLUMN mic_enabled INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE room_members ADD COLUMN seat_index INTEGER",
      "ALTER TABLE room_members ADD COLUMN seat_emote TEXT",
      "ALTER TABLE room_members ADD COLUMN seat_emote_until INTEGER",
      "ALTER TABLE room_runtime_settings ADD COLUMN seat_count INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE room_runtime_settings ADD COLUMN public_screen_enabled INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE room_runtime_settings ADD COLUMN comments_clear_version INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE room_runtime_settings ADD COLUMN owner_comments_clear_version INTEGER NOT NULL DEFAULT 0",
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

  _activeSocketUserIds() {
    const active = new Set();
    for (const socket of this.ctx.getWebSockets("room-presence")) {
      const attachment = socket.deserializeAttachment?.() || {};
      const userId = String(attachment.userId || "").trim();
      if (userId) active.add(userId);
    }
    return active;
  }

  _prune(now = Date.now()) {
    const cutoff = now - MEMBER_TTL_MS;
    const active = this._activeSocketUserIds();
    const stale = this.ctx.storage.sql.exec(
      "SELECT user_id FROM room_members WHERE last_seen < ?",
      cutoff,
    ).toArray();
    for (const row of stale) {
      const userId = String(row.user_id || "").trim();
      if (!userId || active.has(userId)) continue;
      this.ctx.storage.sql.exec(
        "DELETE FROM room_members WHERE user_id = ?",
        userId,
      );
      this.ctx.storage.sql.exec(
        "DELETE FROM room_mutes WHERE user_id = ?",
        userId,
      );
      this.ctx.storage.sql.exec(
        "DELETE FROM room_seat_forces WHERE user_id = ?",
        userId,
      );
      this.ctx.storage.sql.exec(
        "DELETE FROM room_seat_invites WHERE target_user_id = ?",
        userId,
      );
    }
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

  kickList(now = Date.now()) {
    this._prune(now);
    return this.ctx.storage.sql.exec(
      `SELECT user_id, expires_at, kicked_by, created_at
         FROM room_kicks
        ORDER BY created_at DESC`,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      expires_at: row.expires_at === null || row.expires_at === undefined
        ? null
        : Number(row.expires_at),
      permanent: row.expires_at === null || row.expires_at === undefined,
      kicked_by: String(row.kicked_by),
      created_at: Number(row.created_at),
    }));
  }

  unkick(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) throw new Error("target_user_id is required");
    this.ctx.storage.sql.exec("DELETE FROM room_kicks WHERE user_id = ?", userId);
    return { ok: true, target_user_id: userId, kicks: this.kickList() };
  }

  micMode() {
    const row = this.ctx.storage.sql.exec(
      "SELECT mic_mode FROM room_runtime_settings WHERE id = 1 LIMIT 1",
    ).toArray()[0];
    return row?.mic_mode === "free" ? "free" : "apply";
  }

  seatCount() {
    const row = this.ctx.storage.sql.exec(
      "SELECT seat_count FROM room_runtime_settings WHERE id = 1 LIMIT 1",
    ).toArray()[0];
    const value = Number(row?.seat_count || 0);
    return Number.isInteger(value) && value >= 8 && value <= 42 ? value : null;
  }

  publicScreenEnabled() {
    const row = this.ctx.storage.sql.exec(
      "SELECT public_screen_enabled FROM room_runtime_settings WHERE id = 1 LIMIT 1",
    ).toArray()[0];
    return Number(row?.public_screen_enabled || 0) === 1;
  }

  commentsClearVersion() {
    const row = this.ctx.storage.sql.exec(
      "SELECT comments_clear_version FROM room_runtime_settings WHERE id = 1 LIMIT 1",
    ).toArray()[0];
    return Math.max(0, Number(row?.comments_clear_version || 0));
  }

  ownerCommentsClearVersion() {
    const row = this.ctx.storage.sql.exec(
      "SELECT owner_comments_clear_version FROM room_runtime_settings WHERE id = 1 LIMIT 1",
    ).toArray()[0];
    return Math.max(0, Number(row?.owner_comments_clear_version || 0));
  }

  setPublicScreenEnabled(enabledValue) {
    const enabled = enabledValue === true;
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `UPDATE room_runtime_settings
          SET public_screen_enabled = ?, updated_at = ?
        WHERE id = 1`,
      enabled ? 1 : 0,
      now,
    );
    const result = {
      ok: true,
      public_screen_enabled: enabled,
      comments_clear_version: this.commentsClearVersion(),
      owner_comments_clear_version: this.ownerCommentsClearVersion(),
    };
    this._broadcastPresence("public_screen_changed");
    return result;
  }

  clearComments(clearedByValue, ownerClearValue = false) {
    const clearedBy = String(clearedByValue || "").trim();
    const ownerClear = ownerClearValue === true;
    this.ctx.storage.sql.exec(ownerClear
      ? "DELETE FROM room_chat_messages"
      : "DELETE FROM room_chat_messages WHERE is_owner=0");
    const nextVersion = this.commentsClearVersion() + 1;
    const nextOwnerVersion = ownerClear
      ? this.ownerCommentsClearVersion() + 1
      : this.ownerCommentsClearVersion();
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `UPDATE room_runtime_settings
          SET comments_clear_version = ?,
              owner_comments_clear_version = ?,
              updated_at = ?
        WHERE id = 1`,
      nextVersion,
      nextOwnerVersion,
      now,
    );
    const result = {
      ok: true,
      comments_clear_version: nextVersion,
      owner_comments_clear_version: nextOwnerVersion,
      public_screen_enabled: this.publicScreenEnabled(),
      cleared_by: clearedBy,
      clear_scope: ownerClear ? "all" : "non_owner",
    };
    this._broadcastPresence("comments_cleared");
    return result;
  }

  setMicMode(modeValue) {
    const mode = String(modeValue || "").trim().toLowerCase();
    if (mode !== "free" && mode !== "apply") {
      throw new Error("mic_mode must be free or apply");
    }
    if (mode === "free") {
      this.ctx.storage.sql.exec("DELETE FROM room_seat_requests");
    }
    this.ctx.storage.sql.exec(
      `INSERT INTO room_runtime_settings (id, mic_mode, updated_at)
       VALUES (1, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         mic_mode = excluded.mic_mode,
         updated_at = excluded.updated_at`,
      mode,
      Date.now(),
    );
    const result = { ok: true, mic_mode: mode, seat_count: this.seatCount() };
    this._broadcastPresence("mic_mode_changed");
    return result;
  }

  setSeatCount(seatCountValue) {
    const seatCount = Number(seatCountValue);
    if (!Number.isInteger(seatCount) || seatCount < 8 || seatCount > 42) {
      throw new Error("Room seat count must be 8-42");
    }
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `UPDATE room_runtime_settings
          SET seat_count = ?, updated_at = ?
        WHERE id = 1`,
      seatCount,
      now,
    );

    // Anyone sitting outside the reduced layout is moved safely to audience.
    this.ctx.storage.sql.exec(
      "UPDATE room_members SET seat_index = NULL, mic_enabled = 0, last_seen = ? WHERE seat_index >= ?",
      now,
      seatCount,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_mutes WHERE seat_index >= ?",
      seatCount,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_locks WHERE seat_index >= ?",
      seatCount,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_mutes WHERE seat_index >= ?",
      seatCount,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_requests WHERE seat_index >= ?",
      seatCount,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_invites WHERE seat_index >= ?",
      seatCount,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_forces WHERE seat_index IS NOT NULL AND seat_index >= ?",
      seatCount,
    );

    const result = {
      ok: true,
      seat_count: seatCount,
      mic_mode: this.micMode(),
      members: this._members(now),
    };
    this._broadcastPresence("seat_count_changed", now);
    return result;
  }

    isMember(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return false;
    this._prune();
    const row = this.ctx.storage.sql.exec(
      "SELECT user_id FROM room_members WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    return Boolean(row);
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

  chatBanStatus(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return false;
    const row = this.ctx.storage.sql.exec(
      "SELECT user_id FROM room_chat_bans WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    return Boolean(row);
  }

  setChatBan(input) {
    const targetUserId = String(input?.target_user_id || "").trim();
    const bannedBy = String(input?.banned_by || "").trim();
    const banned = Boolean(input?.banned);
    if (!targetUserId) throw new Error("target_user_id is required");
    if (!bannedBy) throw new Error("banned_by is required");

    const member = this.ctx.storage.sql.exec(
      "SELECT user_id FROM room_members WHERE user_id = ? LIMIT 1",
      targetUserId,
    ).toArray()[0];
    if (!member) throw new Error("User is not in the room");

    if (banned) {
      this.ctx.storage.sql.exec(
        `INSERT INTO room_chat_bans (user_id, banned_by, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT(user_id) DO UPDATE SET
           banned_by = excluded.banned_by,
           updated_at = excluded.updated_at`,
        targetUserId,
        bannedBy,
        Date.now(),
      );
    } else {
      this.ctx.storage.sql.exec(
        "DELETE FROM room_chat_bans WHERE user_id = ?",
        targetUserId,
      );
    }

    const result = {
      ok: true,
      target_user_id: targetUserId,
      chat_banned: banned,
      members: this._members(),
    };
    this._broadcastPresence("chat_ban_changed");
    return result;
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
    const result = {
      ok: true,
      user_id: userId,
      enabled: Boolean(enabled),
      members: this._members(),
    };
    this._broadcastPresence("admin_changed");
    return result;
  }

  lockedSeats() {
    return this.ctx.storage.sql.exec("SELECT seat_index FROM room_seat_locks ORDER BY seat_index").toArray().map((row) => Number(row.seat_index));
  }

  userIdAtSeat(seatIndexValue) {
    const seatIndex = Number(seatIndexValue);
    if (!Number.isInteger(seatIndex) || seatIndex < 0) return null;
    const row = this.ctx.storage.sql.exec(
      "SELECT user_id FROM room_members WHERE seat_index = ? LIMIT 1",
      seatIndex,
    ).toArray()[0];
    return row?.user_id ? String(row.user_id) : null;
  }

  mutedSeats() {
    return this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_seat_mutes ORDER BY seat_index",
    ).toArray().map((row) => Number(row.seat_index));
  }

  setSeatMute(input) {
    const seatIndex = Number(input?.seat_index);
    const mutedBy = String(input?.muted_by || "").trim();
    const muted = input?.muted === true;
    if (!Number.isInteger(seatIndex) || seatIndex < 0) {
      throw new Error("seat_index is required");
    }
    if (!mutedBy) throw new Error("muted_by is required");
    if (muted) {
      this.ctx.storage.sql.exec(
        `INSERT INTO room_seat_mutes (seat_index, muted_by, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT(seat_index) DO UPDATE SET
           muted_by = excluded.muted_by,
           updated_at = excluded.updated_at`,
        seatIndex,
        mutedBy,
        Date.now(),
      );
    } else {
      this.ctx.storage.sql.exec(
        "DELETE FROM room_seat_mutes WHERE seat_index = ?",
        seatIndex,
      );
      const occupant = this.ctx.storage.sql.exec(
        "SELECT user_id FROM room_members WHERE seat_index = ? LIMIT 1",
        seatIndex,
      ).toArray()[0];
      if (occupant?.user_id) {
        this.ctx.storage.sql.exec(
          "DELETE FROM room_mutes WHERE user_id = ? AND seat_index = ?",
          String(occupant.user_id),
          seatIndex,
        );
      }
    }
    const result = {
      ok: true,
      seat_index: seatIndex,
      muted,
      muted_seats: this.mutedSeats(),
      locked_seats: this.lockedSeats(),
      members: this._members(),
    };
    this._broadcastPresence("mute_changed");
    return result;
  }

  setSeatLock(input) {
    const seatIndex = Number(input?.seat_index);
    const lockedBy = String(input?.locked_by || "").trim();
    const locked = input?.locked === true;
    if (!Number.isInteger(seatIndex) || seatIndex < 0) throw new Error("seat_index is required");
    if (!lockedBy) throw new Error("locked_by is required");
    if (locked) {
      const occupied = this.ctx.storage.sql.exec("SELECT user_id FROM room_members WHERE seat_index = ? LIMIT 1", seatIndex).toArray()[0];
      if (occupied) this.removeFromSeat({ target_user_id: String(occupied.user_id) });
      this.ctx.storage.sql.exec(
        `INSERT INTO room_seat_locks (seat_index, locked_by, updated_at) VALUES (?, ?, ?) ON CONFLICT(seat_index) DO UPDATE SET locked_by = excluded.locked_by, updated_at = excluded.updated_at`,
        seatIndex, lockedBy, Date.now(),
      );
    } else {
      this.ctx.storage.sql.exec("DELETE FROM room_seat_locks WHERE seat_index = ?", seatIndex);
    }
    const result = { ok: true, seat_index: seatIndex, locked, locked_seats: this.lockedSeats(), members: this._members() };
    this._broadcastPresence("seat_lock_changed");
    return result;
  }

  _assertSeatAvailable(seatIndex, userId = "") {
    if (seatIndex === null || seatIndex === undefined) return;
    const locked = this.ctx.storage.sql.exec("SELECT seat_index FROM room_seat_locks WHERE seat_index = ? LIMIT 1", seatIndex).toArray()[0];
    if (locked) throw new Error("Seat is locked");
    const occupied = this.ctx.storage.sql.exec("SELECT user_id FROM room_members WHERE seat_index = ? AND user_id != ? LIMIT 1", seatIndex, String(userId || "")).toArray()[0];
    if (occupied) throw new Error("Seat is already occupied");
  }

  seatRequests() {
    return this.ctx.storage.sql.exec(
      `SELECT user_id, seat_index, created_at
         FROM room_seat_requests
        ORDER BY created_at ASC`,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      seat_index: Number(row.seat_index),
      created_at: Number(row.created_at),
    }));
  }

  requestSeat(input) {
    const userId = String(input?.user_id || "").trim();
    const seatIndex = Number(input?.seat_index);
    if (!userId) throw new Error("user_id is required");
    if (!Number.isInteger(seatIndex) || seatIndex < 0) {
      throw new Error("seat_index is required");
    }
    this._assertSeatAvailable(seatIndex, userId);
    if (this.micMode() === "free") {
      // Server-authoritative fallback: stale clients that still call the
      // request endpoint in Free Mic mode must join the seat directly.
      return this.takeSeat({
        user_id: userId,
        seat_index: seatIndex,
        privileged: false,
      });
    }

    const member = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_members WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!member) throw new Error("User is not in the room");
    if (member.seat_index !== null && member.seat_index !== undefined) {
      throw new Error("Leave your current seat first");
    }

    const occupied = this.ctx.storage.sql.exec(
      "SELECT user_id FROM room_members WHERE seat_index = ? LIMIT 1",
      seatIndex,
    ).toArray()[0];
    if (occupied) throw new Error("Seat is already occupied");

    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO room_seat_requests (user_id, seat_index, created_at)
       VALUES (?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         seat_index = excluded.seat_index,
         created_at = excluded.created_at`,
      userId,
      seatIndex,
      now,
    );
    return {
      ok: true,
      server_time: now,
      mic_mode: this.micMode(),
      seat_requests: this.seatRequests(),
      locked_seats: this.lockedSeats(),
      muted_seats: this.mutedSeats(),
      members: this._members(now),
    };
  }

  resolveSeatRequest(input) {
    const targetUserId = String(input?.target_user_id || "").trim();
    const approved = Boolean(input?.approved);
    if (!targetUserId) throw new Error("target_user_id is required");

    const request = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_seat_requests WHERE user_id = ? LIMIT 1",
      targetUserId,
    ).toArray()[0];
    if (!request) throw new Error("Seat request is no longer available");

    const seatIndex = Number(request.seat_index);
    if (approved) {
      if (!this.isMember(targetUserId)) throw new Error("User is no longer in the room");
      this._assertSeatAvailable(seatIndex, targetUserId);
      const occupied = this.ctx.storage.sql.exec(
        "SELECT user_id FROM room_members WHERE seat_index = ? AND user_id != ? LIMIT 1",
        seatIndex,
        targetUserId,
      ).toArray()[0];
      if (occupied) {
        this.ctx.storage.sql.exec(
          "DELETE FROM room_seat_requests WHERE user_id = ?",
          targetUserId,
        );
        throw new Error("Seat is already occupied");
      }

      this.ctx.storage.sql.exec(
        `INSERT INTO room_seat_forces (user_id, seat_index, created_at)
         VALUES (?, ?, ?)
         ON CONFLICT(user_id) DO UPDATE SET
           seat_index = excluded.seat_index,
           created_at = excluded.created_at`,
        targetUserId,
        seatIndex,
        Date.now(),
      );
      this.ctx.storage.sql.exec(
        "UPDATE room_members SET seat_index = ?, mic_enabled = 0, last_seen = ? WHERE user_id = ?",
        seatIndex,
        Date.now(),
        targetUserId,
      );
    }

    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_requests WHERE user_id = ?",
      targetUserId,
    );
    const result = {
      ok: true,
      approved,
      target_user_id: targetUserId,
      seat_index: approved ? seatIndex : null,
      mic_mode: this.micMode(),
      seat_requests: this.seatRequests(),
      members: this._members(),
    };
    this._broadcastPresence(approved ? "seat_changed" : "seat_request_changed");
    return result;
  }

    seatInviteFor(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return null;
    const row = this.ctx.storage.sql.exec(
      `SELECT target_user_id, seat_index, invited_by, created_at
         FROM room_seat_invites
        WHERE target_user_id = ?
        LIMIT 1`,
      userId,
    ).toArray()[0];
    if (!row) return null;
    return {
      target_user_id: String(row.target_user_id),
      seat_index: Number(row.seat_index),
      invited_by: String(row.invited_by),
      created_at: Number(row.created_at),
    };
  }

  inviteToSeat(input) {
    const targetUserId = String(input?.target_user_id || "").trim();
    const invitedBy = String(input?.invited_by || "").trim();
    const seatIndex = Number(input?.seat_index);
    const maxSeatCount = Number(input?.max_seat_count);
    if (!targetUserId || !invitedBy) {
      throw new Error("target_user_id and invited_by are required");
    }
    if (targetUserId === invitedBy) {
      throw new Error("You cannot invite yourself to a seat");
    }
    if (!Number.isInteger(seatIndex) || seatIndex < 0) {
      throw new Error("seat_index is required");
    }
    if (
      Number.isInteger(maxSeatCount) &&
      maxSeatCount > 0 &&
      seatIndex >= maxSeatCount
    ) {
      throw new Error("Seat is outside the current room seat range");
    }

    this._assertSeatAvailable(seatIndex, targetUserId);
    const target = this.ctx.storage.sql.exec(
      "SELECT user_id, seat_index FROM room_members WHERE user_id = ? LIMIT 1",
      targetUserId,
    ).toArray()[0];
    if (!target) throw new Error("User is not in the room");
    if (target.seat_index !== null && target.seat_index !== undefined) {
      throw new Error("User is already on a seat");
    }

    const occupied = this.ctx.storage.sql.exec(
      "SELECT user_id FROM room_members WHERE seat_index = ? LIMIT 1",
      seatIndex,
    ).toArray()[0];
    if (occupied) throw new Error("Seat is already occupied");

    const now = Date.now();
    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_requests WHERE user_id = ?",
      targetUserId,
    );
    this.ctx.storage.sql.exec(
      `INSERT INTO room_seat_invites
        (target_user_id, seat_index, invited_by, created_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(target_user_id) DO UPDATE SET
         seat_index = excluded.seat_index,
         invited_by = excluded.invited_by,
         created_at = excluded.created_at`,
      targetUserId,
      seatIndex,
      invitedBy,
      now,
    );
    const result = {
      ok: true,
      server_time: now,
      mic_mode: this.micMode(),
      target_user_id: targetUserId,
      seat_index: seatIndex,
      members: this._members(now),
    };
    // Push the pending invite immediately to the target's live room socket.
    // _presenceStateFor only exposes the invite belonging to each socket user.
    this._broadcastPresence("seat_invite_changed", now);
    return result;
  }

  respondSeatInvite(input) {
    const userId = String(input?.user_id || "").trim();
    const accepted = Boolean(input?.accepted);
    const maxSeatCount = Number(input?.max_seat_count);
    if (!userId) throw new Error("user_id is required");

    const invite = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_seat_invites WHERE target_user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!invite) {
      const current = this.ctx.storage.sql.exec("SELECT seat_index FROM room_members WHERE user_id=? LIMIT 1",userId).toArray()[0];
      if (!accepted || current?.seat_index != null) {
        return { ...this._presenceStateFor(userId), accepted, seat_index: current?.seat_index ?? null };
      }
      throw new Error("Seat invite is no longer available");
    }

    const seatIndex = Number(invite.seat_index);
    if (accepted) {
      const member = this.ctx.storage.sql.exec(
        "SELECT user_id, seat_index FROM room_members WHERE user_id = ? LIMIT 1",
        userId,
      ).toArray()[0];
      if (!member) {
        this.ctx.storage.sql.exec(
          "DELETE FROM room_seat_invites WHERE target_user_id = ?",
          userId,
        );
        throw new Error("User is no longer in the room");
      }
      if (member.seat_index !== null && member.seat_index !== undefined) {
        this.ctx.storage.sql.exec(
          "DELETE FROM room_seat_invites WHERE target_user_id = ?",
          userId,
        );
        throw new Error("User is already on a seat");
      }
      if (
        Number.isInteger(maxSeatCount) &&
        maxSeatCount > 0 &&
        seatIndex >= maxSeatCount
      ) {
        this.ctx.storage.sql.exec(
          "DELETE FROM room_seat_invites WHERE target_user_id = ?",
          userId,
        );
        throw new Error("Invited seat is no longer available");
      }

      try {
        this._assertSeatAvailable(seatIndex, userId);
      } catch (error) {
        this.ctx.storage.sql.exec(
          "DELETE FROM room_seat_invites WHERE target_user_id = ?",
          userId,
        );
        throw error;
      }

      this.ctx.storage.sql.exec(
        `INSERT INTO room_seat_forces (user_id, seat_index, created_at)
         VALUES (?, ?, ?)
         ON CONFLICT(user_id) DO UPDATE SET
           seat_index = excluded.seat_index,
           created_at = excluded.created_at`,
        userId,
        seatIndex,
        Date.now(),
      );
      this.ctx.storage.sql.exec(
        "UPDATE room_members SET seat_index = ?, mic_enabled = 0, last_seen = ? WHERE user_id = ?",
        seatIndex,
        Date.now(),
        userId,
      );
    }

    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_invites WHERE target_user_id = ?",
      userId,
    );
    const result = {
      ok: true,
      accepted,
      seat_index: accepted ? seatIndex : null,
    };
    this._broadcastPresence(accepted ? "seat_changed" : "seat_invite_changed");
    return result;
  }

  removeFromSeat(input) {
    const targetUserId = String(input?.target_user_id || "").trim();
    if (!targetUserId) throw new Error("target_user_id is required");

    const target = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_members WHERE user_id = ? LIMIT 1",
      targetUserId,
    ).toArray()[0];
    if (!target ||
        target.seat_index === null ||
        target.seat_index === undefined) {
      throw new Error("User is not on a seat");
    }

    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO room_seat_forces (user_id, seat_index, created_at)
       VALUES (?, NULL, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         seat_index = excluded.seat_index,
         created_at = excluded.created_at`,
      targetUserId,
      now,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_mutes WHERE user_id = ?",
      targetUserId,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_invites WHERE target_user_id = ?",
      targetUserId,
    );
    this.ctx.storage.sql.exec(
      "UPDATE room_members SET seat_index = NULL, mic_enabled = 0, last_seen = ? WHERE user_id = ?",
      now,
      targetUserId,
    );
    const result = {
      ok: true,
      target_user_id: targetUserId,
      server_time: now,
      members: this._members(now),
    };
    this._broadcastPresence("seat_changed");
    return result;
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

    const result = {
      ok: true,
      server_time: now,
      mic_mode: this.micMode(),
      members: this._members(now),
    };
    this._broadcastPresence("emote_changed");
    return result;
  }

    muteStatus(userIdValue, seatIndexValue = null) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return false;
    if (seatIndexValue !== null && seatIndexValue !== undefined) {
      const seatMuted = this.ctx.storage.sql.exec(
        "SELECT seat_index FROM room_seat_mutes WHERE seat_index = ? LIMIT 1",
        Number(seatIndexValue),
      ).toArray()[0];
      if (seatMuted) return true;
    }
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
      this.ctx.storage.sql.exec(
        "DELETE FROM room_seat_mutes WHERE seat_index = ?",
        seatIndex,
      );
    }

    const result = {
      ok: true,
      server_time: now,
      target_user_id: targetUserId,
      seat_index: seatIndex,
      muted,
      muted_seats: this.mutedSeats(),
      locked_seats: this.lockedSeats(),
      members: this._members(now),
    };
    this._broadcastPresence("mute_changed");
    return result;
  }

  async kick(input) {
    const now = Date.now();
    const targetUserId = String(input?.target_user_id || "").trim();
    const kickedBy = String(input?.kicked_by || "").trim();
    const roomId = String(input?.room_id || "").trim();
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
    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_requests WHERE user_id = ?",
      targetUserId,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_mutes WHERE user_id = ?",
      targetUserId,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_forces WHERE user_id = ?",
      targetUserId,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM room_seat_invites WHERE target_user_id = ?",
      targetUserId,
    );

    for (const socket of this.ctx.getWebSockets("room-presence")) {
      const attachment = socket.deserializeAttachment?.() || {};
      if (String(attachment.userId || "").trim() !== targetUserId) continue;
      try {
        socket.send(JSON.stringify({
          type: "kicked",
          kicked_user_id: targetUserId,
          expires_at: expiresAt,
        }));
      } catch (_) {}
      try {
        socket.close(4003, "Kicked from room");
      } catch (_) {}
    }

    if (roomId) {
      await this._clearDirectoryPresence(targetUserId, roomId, now);
    }

    this._broadcastPresence("member_kicked", now);
    return {
      ok: true,
      server_time: now,
      mic_mode: this.micMode(),
      kicked_user_id: targetUserId,
      expires_at: expiresAt,
      members: this._members(now),
    };
  }

  luckyNumberEvents(limitValue = 50) {
    const limit = Math.max(1, Math.min(100, Number(limitValue) || 50));
    return this.ctx.storage.sql.exec(
      `SELECT id,user_id,display_name,number_value,created_at
         FROM (
           SELECT id,user_id,display_name,number_value,created_at
             FROM room_lucky_numbers
            ORDER BY created_at DESC
            LIMIT ?
         )
        ORDER BY created_at ASC`,
      limit,
    ).toArray().map((row) => ({
      id: String(row.id),
      user_id: String(row.user_id),
      display_name: String(row.display_name),
      number: Number(row.number_value),
      created_at: Number(row.created_at),
    }));
  }

  drawLuckyNumber(input) {
    const userId = String(input?.user_id || "").trim();
    const displayName = String(input?.display_name || "").trim() || "User";
    if (!userId) throw new Error("user_id is required");
    if (!this.isMember(userId)) throw new Error("User is not in the room");

    const max = 0x100000000;
    const accepted = Math.floor(max / 100) * 100;
    const raw = new Uint32Array(1);
    do {
      crypto.getRandomValues(raw);
    } while (raw[0] >= accepted);
    const number = Number(raw[0] % 100) + 1;

    const id = "lucky-" + crypto.randomUUID();
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO room_lucky_numbers
        (id,user_id,display_name,number_value,created_at)
       VALUES (?,?,?,?,?)`,
      id, userId, displayName, number, now,
    );
    this.ctx.storage.sql.exec(
      `DELETE FROM room_lucky_numbers
        WHERE id NOT IN (
          SELECT id FROM room_lucky_numbers
           ORDER BY created_at DESC
           LIMIT 100
        )`,
    );

    return {
      ok: true,
      event: {
        id,
        user_id: userId,
        display_name: displayName,
        number,
        created_at: now,
      },
      lucky_number_events: this.luckyNumberEvents(),
    };
  }

  _members(now = Date.now()) {
    this._prune(now);
    return this.ctx.storage.sql.exec(
      `SELECT user_id, display_name, avatar_data_url, flag_emoji,
              country_code, family_tag, host_tag, agency_name, equipped_frame_id,
              equipped_entry_id, equipped_profile_card_id,
              owner_tags_json, owner_medals_json, mic_enabled,
              seat_index, seat_emote, seat_emote_until, joined_at, last_seen,
              COALESCE(
                (SELECT coins FROM room_gift_totals rg
                  WHERE rg.user_id = room_members.user_id),
                0
              ) AS received_gift_coins
         FROM room_members
        ORDER BY joined_at ASC`,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      display_name: String(row.display_name),
      avatar_data_url: row.avatar_data_url ? String(row.avatar_data_url) : null,
      flag_emoji: String(row.flag_emoji || ""),
      country_code: String(row.country_code || ""),
      family_tag: row.family_tag ? String(row.family_tag) : null,
      host_tag: row.host_tag ? String(row.host_tag) : null,
      agency_name: row.agency_name ? String(row.agency_name) : null,
      equipped_frame_id: row.equipped_frame_id ? String(row.equipped_frame_id) : null,
      equipped_entry_id: row.equipped_entry_id ? String(row.equipped_entry_id) : null,
      equipped_profile_card_id: row.equipped_profile_card_id ? String(row.equipped_profile_card_id) : null,
      owner_tags: (() => {
        try {
          const value = JSON.parse(String(row.owner_tags_json || "[]"));
          return Array.isArray(value) ? value : [];
        } catch {
          return [];
        }
      })(),
      owner_medals: (() => {
        try {
          const value = JSON.parse(String(row.owner_medals_json || "[]"));
          return Array.isArray(value) ? value : [];
        } catch {
          return [];
        }
      })(),
      seat_index:
        row.seat_index === null || row.seat_index === undefined
          ? null
          : Number(row.seat_index),
      moderation_muted: this.muteStatus(row.user_id, row.seat_index),
      mic_enabled: Number(row.mic_enabled || 0) === 1,
      mic_muted:
        this.muteStatus(row.user_id, row.seat_index) ||
        Number(row.mic_enabled || 0) !== 1,
      chat_banned: this.chatBanStatus(row.user_id),
      is_admin: this.isManager(row.user_id),
      received_gift_coins: Math.max(0, Number(row.received_gift_coins || 0)),
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

  recordGift(input) {
    const now = Date.now();
    const rows = Array.isArray(input?.receivers) ? input.receivers : [];
    let changed = false;
    for (const item of rows) {
      const userId = String(item?.user_id || "").trim();
      const coins = Number(item?.coins || 0);
      if (!userId || !Number.isSafeInteger(coins) || coins <= 0) continue;
      this.ctx.storage.sql.exec(
        `INSERT INTO room_gift_totals (user_id, coins, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT(user_id) DO UPDATE SET
           coins = room_gift_totals.coins + excluded.coins,
           updated_at = excluded.updated_at`,
        userId,
        coins,
        now,
      );
      changed = true;
    }
    if (changed) this._broadcastPresence("gift_received", now);

    const rawEvent = input?.event;
    if (rawEvent && typeof rawEvent === "object") {
      const receiverIds = [...new Set(
        (Array.isArray(rawEvent.receiver_ids) ? rawEvent.receiver_ids : [])
          .map((value) => String(value || "").trim())
          .filter(Boolean),
      )].slice(0, 30);
      const eventId = String(rawEvent.id || "").trim().slice(0, 120);
      const senderId = String(rawEvent.sender_id || "").trim().slice(0, 120);
      const giftId = String(rawEvent.gift_id || "").trim().slice(0, 80);
      if (eventId && senderId && giftId && receiverIds.length > 0) {
        this._broadcastRoomEvent({
          type: "gift_sent",
          gift: {
            id: eventId,
            sender_id: senderId,
            gift_id: giftId,
            gift_name: String(rawEvent.gift_name || "Gift").slice(0, 80),
            receiver_ids: receiverIds,
            quantity: Math.max(1, Math.floor(Number(rawEvent.quantity || 1))),
            lucky: rawEvent.lucky === true,
            multiplier: Math.max(
              0,
              Math.floor(Number(rawEvent.multiplier || 0)),
            ),
            rebate_coins: Math.max(
              0,
              Math.floor(Number(rawEvent.rebate_coins || 0)),
            ),
            created_at: Number(rawEvent.created_at || now),
          },
        });
      }
    }

    return {
      ok: true,
      server_time: now,
      members: this._members(now),
    };
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
    const familyTag = String(input?.family_tag || "").trim() || null;
    const hostTag = String(input?.host_tag || "").trim() || null;
    const agencyName = String(input?.agency_name || "").trim() || null;
    const equippedFrameId = String(input?.equipped_frame_id || "").trim().slice(0, 80) || null;
    const equippedEntryId = String(input?.equipped_entry_id || "").trim().slice(0, 80) || null;
    const equippedProfileCardId = String(input?.equipped_profile_card_id || "").trim().slice(0, 80) || null;
    const ownerTags = Array.isArray(input?.owner_tags)
      ? input.owner_tags
          .map((item) => ({
            name: String(item?.name || "").trim().slice(0, 40),
            color: String(item?.color || "#FFD54F").trim(),
            kind: String(item?.kind || "custom").trim().slice(0, 24),
            designation: String(item?.designation || "").trim().slice(0, 40),
            background_color: String(
              item?.background_color || item?.color || "#FFD54F",
            ).trim(),
          }))
          .filter((item) => item.name && /^#[0-9a-fA-F]{6}$/.test(item.color))
          .slice(0, 12)
      : [];
    const ownerTagsJson = JSON.stringify(ownerTags);
    const ownerMedals = Array.isArray(input?.owner_medals)
      ? input.owner_medals
          .map((item) => ({
            name: String(item?.name || "").trim().slice(0, 40),
            color: String(item?.color || "#FFD54F").trim(),
          }))
          .filter((item) => item.name && /^#[0-9a-fA-F]{6}$/.test(item.color))
          .slice(0, 12)
      : [];
    const ownerMedalsJson = JSON.stringify(ownerMedals);
    const rawSeatIndex = input?.seat_index;
    let seatIndex =
      rawSeatIndex === null || rawSeatIndex === undefined
        ? null
        : Number(rawSeatIndex);
    const forceRow = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_seat_forces WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    const requestedSeat = rawSeatIndex === null || rawSeatIndex === undefined ? null : Number(rawSeatIndex);
    const targetSeat = forceRow?.seat_index === null || forceRow?.seat_index === undefined ? null : Number(forceRow.seat_index);
    const seatForced = Boolean(forceRow) && requestedSeat !== targetSeat;
    if (forceRow) {
      seatIndex =
        forceRow.seat_index === null || forceRow.seat_index === undefined
          ? null
          : Number(forceRow.seat_index);
    }
    const micEnabled = seatIndex !== null && input?.mic_enabled === true;

    if (!userId) throw new Error("user_id is required");
    if (!displayName) throw new Error("display_name is required");
    if (seatIndex !== null && (!Number.isInteger(seatIndex) || seatIndex < 0)) {
      throw new Error("seat_index is invalid");
    }

    this._assertSeatAvailable(seatIndex, userId);

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
      this.ctx.storage.sql.exec(
        "DELETE FROM room_seat_requests WHERE user_id = ?",
        userId,
      );
    }

    this.ctx.storage.sql.exec(
      `INSERT INTO room_members
        (user_id, display_name, avatar_data_url, flag_emoji, country_code,
         family_tag, host_tag, agency_name, equipped_frame_id, equipped_entry_id, equipped_profile_card_id, owner_tags_json, owner_medals_json,
         mic_enabled, seat_index, seat_emote, seat_emote_until, joined_at, last_seen)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         display_name = excluded.display_name,
         avatar_data_url = excluded.avatar_data_url,
         flag_emoji = excluded.flag_emoji,
         country_code = excluded.country_code,
         family_tag = excluded.family_tag,
         host_tag = excluded.host_tag,
         agency_name = excluded.agency_name,
         equipped_frame_id = excluded.equipped_frame_id,
         equipped_entry_id = excluded.equipped_entry_id,
         equipped_profile_card_id = excluded.equipped_profile_card_id,
         owner_tags_json = excluded.owner_tags_json,
         owner_medals_json = excluded.owner_medals_json,
         mic_enabled = excluded.mic_enabled,
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
      familyTag,
      hostTag,
      agencyName,
      equippedFrameId,
      equippedEntryId,
      equippedProfileCardId,
      ownerTagsJson,
      ownerMedalsJson,
      micEnabled ? 1 : 0,
      seatIndex,
      null,
      null,
      now,
      now,
    );

    if (forceRow) {
      this.ctx.storage.sql.exec(
        "DELETE FROM room_seat_forces WHERE user_id = ?",
        userId,
      );
    }
    if (seatIndex !== null) {
      this.ctx.storage.sql.exec(
        "DELETE FROM room_seat_requests WHERE user_id = ?",
        userId,
      );
    }

    return {
      ok: true,
      server_time: now,
      mic_mode: this.micMode(),
      seat_count: this.seatCount(),
      public_screen_enabled: this.publicScreenEnabled(),
      comments_clear_version: this.commentsClearVersion(),
      self_mic_muted: this.muteStatus(userId, seatIndex),
      self_chat_banned: this.chatBanStatus(userId),
      self_seat_forced: seatForced,
      self_forced_seat_index: seatForced ? seatIndex : null,
      pending_seat_invite: this.seatInviteFor(userId),
      lucky_number_events: this.luckyNumberEvents(),
      seat_requests: this.seatRequests(),
      locked_seats: this.lockedSeats(),
      muted_seats: this.mutedSeats(),
      members: this._members(now),
    };
  }

  leaveSeat(userId) {
    if (!this.isMember(userId)) throw new Error("User is not in the room");
    this.removeFromSeat({ target_user_id: userId });
    this.ctx.storage.sql.exec("DELETE FROM room_seat_forces WHERE user_id = ?", userId);
    return this._presenceStateFor(userId);
  }

  takeSeat(input) {
    const userId = String(input?.user_id || "").trim();
    const seatIndex = Number(input?.seat_index);
    const privileged = input?.privileged === true;
    if (!userId) throw new Error("user_id is required");
    if (!Number.isInteger(seatIndex) || seatIndex < 0) throw new Error("seat_index is required");
    if (!this.isMember(userId)) throw new Error("User is not in the room");
    this._assertSeatAvailable(seatIndex, userId);

    if (!privileged && this.micMode() !== "free") {
      throw new Error("Apply for mic and wait for owner/admin approval");
    }
    const current = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_members WHERE user_id = ? LIMIT 1", userId,
    ).toArray()[0];
    if (current?.seat_index !== null && current?.seat_index !== undefined &&
        Number(current.seat_index) === seatIndex) {
      return { ...this._presenceStateFor(userId), seat_index: seatIndex };
    }
    if (current?.seat_index !== null && current?.seat_index !== undefined) {
      throw new Error("Leave your current seat first");
    }

    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO room_seat_forces (user_id, seat_index, created_at)
       VALUES (?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET seat_index = excluded.seat_index, created_at = excluded.created_at`,
      userId, seatIndex, now,
    );
    this.ctx.storage.sql.exec("DELETE FROM room_seat_requests WHERE user_id = ?", userId);
    this.ctx.storage.sql.exec(
      "UPDATE room_members SET seat_index = ?, mic_enabled = 0, last_seen = ? WHERE user_id = ?",
      seatIndex,
      now,
      userId,
    );
    const result = {
      ...this._presenceStateFor(userId, now),
      seat_index: seatIndex,
    };
    this._broadcastPresence("seat_changed");
    return result;
  }

  chatMessages() {
    return this.ctx.storage.sql.exec(
      "SELECT id,user_id,display_name,text,created_at FROM (SELECT * FROM room_chat_messages ORDER BY created_at DESC LIMIT 50) ORDER BY created_at ASC"
    ).toArray();
  }

  postComment(userId, textValue, isOwner = false, requestId = '') {
    if (!this.isMember(userId)) throw new Error("User is not in the room");
    if (this.chatBanStatus(userId)) throw new Error("Room owner/admin has chat banned this ID.");
    if (!this.publicScreenEnabled() && !isOwner && !this.isManager(userId)) {
      throw new Error("Only Admin/Owner can type right now.");
    }
    const text = String(textValue || "").trim();
    if (!text || text.length > 500) throw new Error("Comment must contain 1-500 characters.");
    const id = requestId ? "chat-" + userId + "-" + String(requestId).slice(0,80) : "room-chat-" + crypto.randomUUID();
    const existing = this.ctx.storage.sql.exec("SELECT id,user_id,display_name,text,created_at FROM room_chat_messages WHERE id=? LIMIT 1",id).toArray()[0];
    if (existing) return existing;
    const now = Date.now();
    const member = this.ctx.storage.sql.exec("SELECT display_name FROM room_members WHERE user_id=? LIMIT 1",userId).toArray()[0];
    const event = { id,user_id:userId,display_name:String(member?.display_name || "User"),text,created_at:now };
    this.ctx.storage.sql.exec("INSERT INTO room_chat_messages(id,user_id,display_name,text,is_owner,created_at) VALUES(?,?,?,?,?,?)",
      id,userId,event.display_name,text,isOwner?1:0,now);
    this.ctx.storage.sql.exec("DELETE FROM room_chat_messages WHERE id NOT IN (SELECT id FROM room_chat_messages ORDER BY created_at DESC LIMIT 50)");
    this._touchSocketMember(userId,now);
    this._broadcastRoomEvent({type:"chat_message",message:event});
    return event;
  }

  _presenceState(now = Date.now()) {
    return {
      ok: true,
      server_time: now,
      mic_mode: this.micMode(),
      seat_count: this.seatCount(),
      public_screen_enabled: this.publicScreenEnabled(),
      comments_clear_version: this.commentsClearVersion(),
      owner_comments_clear_version: this.ownerCommentsClearVersion(),
      member_ttl_ms: MEMBER_TTL_MS,
      chat_messages: this.chatMessages(),
      lucky_number_events: this.luckyNumberEvents(),
      seat_requests: this.seatRequests(),
      locked_seats: this.lockedSeats(),
      muted_seats: this.mutedSeats(),
      members: this._members(now),
    };
  }

  _presenceStateFor(userIdValue, now = Date.now()) {
    const userId = String(userIdValue || "").trim();
    const member = userId
      ? this.ctx.storage.sql.exec(
          "SELECT seat_index FROM room_members WHERE user_id = ? LIMIT 1",
          userId,
        ).toArray()[0]
      : null;
    const seatIndex = member?.seat_index === null ||
        member?.seat_index === undefined
      ? null
      : Number(member.seat_index);
    const forceRow = userId
      ? this.ctx.storage.sql.exec(
          "SELECT seat_index FROM room_seat_forces WHERE user_id = ? LIMIT 1",
          userId,
        ).toArray()[0]
      : null;
    const seatForced = Boolean(forceRow);
    const forcedSeatIndex = seatForced &&
        forceRow.seat_index !== null &&
        forceRow.seat_index !== undefined
      ? Number(forceRow.seat_index)
      : null;

    return {
      ...this._presenceState(now),
      self_mic_muted: userId ? this.muteStatus(userId, seatIndex) : false,
      self_chat_banned: userId ? this.chatBanStatus(userId) : false,
      self_seat_forced: seatForced,
      self_forced_seat_index: forcedSeatIndex,
      pending_seat_invite: userId ? this.seatInviteFor(userId) : null,
    };
  }

  _sendSocketState(socket, type = "presence_state", now = Date.now()) {
    if (!socket) return;
    const attachment = socket.deserializeAttachment?.() || {};
    try {
      socket.send(JSON.stringify({
        type,
        ...this._presenceStateFor(attachment.userId, now),
      }));
    } catch (_) {}
  }

  _broadcastPresence(type = "presence_state", now = Date.now()) {
    for (const socket of this.ctx.getWebSockets("room-presence")) {
      this._sendSocketState(socket, type, now);
    }
  }

  _broadcastRoomEvent(event) {
    const payload = JSON.stringify(event);
    for (const socket of this.ctx.getWebSockets("room-presence")) {
      try {
        socket.send(payload);
      } catch (_) {}
    }
  }

  async _touchDirectory(
    userId,
    roomId,
    now = Date.now(),
    socketConnected = null,
  ) {
    if (!userId || !roomId) return;
    try {
      const directoryId = this.env.APP_DIRECTORY.idFromName("tinni-app-directory");
      const directory = this.env.APP_DIRECTORY.get(directoryId);
      await directory.touchPresence(
        userId,
        roomId,
        this._members(now).length,
        socketConnected,
      );
    } catch (_) {}
  }

  async _markDirectorySocketDisconnected(userId, roomId, now = Date.now()) {
    if (!userId || !roomId) return;
    try {
      const directoryId = this.env.APP_DIRECTORY.idFromName("tinni-app-directory");
      const directory = this.env.APP_DIRECTORY.get(directoryId);
      // A transient WebSocket drop is not an explicit room exit. Keep the
      // user's room presence and seat alive, but mark the socket disconnected
      // so reconnect/fallback logic can restore the live transport.
      await directory.touchPresence(
        userId,
        roomId,
        this._members(now).length,
        false,
      );
    } catch (_) {}
  }

  _touchSocketMember(userIdValue, now = Date.now()) {
    const userId = String(userIdValue || "").trim();
    if (!userId) throw new Error("user_id is required");
    const row = this.ctx.storage.sql.exec(
      "SELECT user_id FROM room_members WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!row) throw new Error("User is not in the room");
    this.ctx.storage.sql.exec(
      "UPDATE room_members SET last_seen = ? WHERE user_id = ?",
      now,
      userId,
    );
  }

  _applySocketState(userIdValue, rawSeatIndex, micEnabledValue, isOwner = false, now = Date.now()) {
    const userId = String(userIdValue || "").trim();
    if (!userId) throw new Error("user_id is required");
    const current = this.ctx.storage.sql.exec(
      "SELECT seat_index, mic_enabled FROM room_members WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!current) throw new Error("User is not in the room");

    const nextSeat = rawSeatIndex === null || rawSeatIndex === undefined
      ? null
      : Number(rawSeatIndex);
    if (nextSeat !== null && (!Number.isInteger(nextSeat) || nextSeat < 0)) {
      throw new Error("seat_index is invalid");
    }
    const previousSeat = current.seat_index === null || current.seat_index === undefined
      ? null
      : Number(current.seat_index);
    const previousMicEnabled = Number(current.mic_enabled || 0) === 1;
    const nextMicEnabled = nextSeat !== null && micEnabledValue === true;

    // room_seat_forces is a one-shot server instruction. Once the client
    // acknowledges exactly the forced target seat (including forced-down
    // null), clear it before broadcasting the next presence state. Leaving
    // this row behind makes every later presence broadcast look "forced"
    // again, which resets the local mic back to muted immediately after the
    // user turns it on.
    const forceRow = this.ctx.storage.sql.exec(
      "SELECT seat_index FROM room_seat_forces WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (forceRow) {
      const forcedSeat = forceRow.seat_index === null ||
          forceRow.seat_index === undefined
        ? null
        : Number(forceRow.seat_index);
      if (forcedSeat !== nextSeat) {
        throw new Error("Seat change must acknowledge the owner/admin action first");
      }
      this.ctx.storage.sql.exec(
        "DELETE FROM room_seat_forces WHERE user_id = ?",
        userId,
      );
    }

    if (previousSeat !== nextSeat && nextSeat !== null) {
      this._assertSeatAvailable(nextSeat, userId);
      const privileged = isOwner || this.isManager(userId);
      if (!privileged && this.micMode() !== "free") {
        throw new Error("Apply for mic and wait for owner/admin approval");
      }
    }

    if (previousSeat === nextSeat && previousMicEnabled === nextMicEnabled) {
      this._touchSocketMember(userId, now);
      return false;
    }

    this.ctx.storage.sql.exec(
      `UPDATE room_members
          SET seat_index = ?,
              mic_enabled = ?,
              seat_emote = CASE WHEN seat_index IS ? THEN seat_emote ELSE NULL END,
              seat_emote_until = CASE WHEN seat_index IS ? THEN seat_emote_until ELSE NULL END,
              last_seen = ?
        WHERE user_id = ?`,
      nextSeat,
      nextMicEnabled ? 1 : 0,
      nextSeat,
      nextSeat,
      now,
      userId,
    );

    if (previousSeat !== nextSeat) {
      this.ctx.storage.sql.exec("DELETE FROM room_mutes WHERE user_id = ?", userId);
      this.ctx.storage.sql.exec("DELETE FROM room_seat_requests WHERE user_id = ?", userId);
      this.ctx.storage.sql.exec("DELETE FROM room_seat_forces WHERE user_id = ?", userId);
    }
    return true;
  }

  async fetch(request) {
    if ((request.headers.get("upgrade") || "").toLowerCase() !== "websocket") {
      return new Response("WebSocket required", { status: 426 });
    }
    const userId = String(request.headers.get("x-tinni-user-id") || "").trim();
    const roomId = String(request.headers.get("x-tinni-room-id") || "").trim();
    const isOwner = request.headers.get("x-tinni-room-owner") === "1";
    if (!userId || !roomId || !this.isMember(userId)) {
      return new Response("Unauthorized", { status: 401 });
    }

    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    this.ctx.acceptWebSocket(server, ["room-presence"]);
    server.serializeAttachment({ userId, roomId, isOwner });
    const now = Date.now();
    this._touchSocketMember(userId, now);
    await this._touchDirectory(userId, roomId, now, true);
    this._sendSocketState(server, "presence_state", now);
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(socket, message) {
    const attachment = socket.deserializeAttachment?.() || {};
    const userId = String(attachment.userId || "").trim();
    const roomId = String(attachment.roomId || "").trim();
    if (!userId || !roomId) {
      try { socket.close(1008, "Invalid room presence session"); } catch (_) {}
      return;
    }

    let payload;
    try {
      payload = JSON.parse(
        typeof message === "string" ? message : new TextDecoder().decode(message),
      );
    } catch (_) {
      return;
    }

    const now = Date.now();
    try {
      if (payload?.type === "presence_keepalive") {
        // Backward compatibility for older APKs. This refreshes only the room
        // member grace timestamp and deliberately avoids an App Directory RPC.
        this._touchSocketMember(userId, now);
        return;
      }
      if (payload?.type === "seat_state") {
        const changed = this._applySocketState(
          userId,
          payload.seat_index,
          payload.mic_enabled,
          attachment.isOwner === true,
          now,
        );
        if (changed) this._broadcastPresence("seat_changed", now);
        return;
      }
      if (payload?.type === "chat_message") {
        this.postComment(userId,payload.text,attachment.isOwner === true,payload.client_event_id || '');
        return;
      }
      if (payload?.type === "presence_sync") {
        this._touchSocketMember(userId, now);
        this._sendSocketState(socket, "presence_state", now);
      }
    } catch (error) {
      try {
        socket.send(JSON.stringify({
          type: "presence_error",
          error: String(error?.message || "Presence update failed"),
        }));
      } catch (_) {}
      this._sendSocketState(socket, "presence_state", now);
    }
  }

  async _handleSocketDisconnect(socket) {
    const attachment = socket?.deserializeAttachment?.() || {};
    const userId = String(attachment.userId || "").trim();
    const roomId = String(attachment.roomId || "").trim();
    const now = Date.now();
    if (userId) {
      try {
        this._touchSocketMember(userId, now);
      } catch (_) {}
    }

    // A reconnect can establish a replacement socket before the old socket's
    // close callback runs. Never let that stale close mark the new session
    // offline.
    const replacementActive = this.ctx
      .getWebSockets("room-presence")
      .some((candidate) => {
        if (candidate === socket) return false;
        const other = candidate.deserializeAttachment?.() || {};
        return String(other.userId || "").trim() === userId;
      });
    if (!replacementActive) {
      await this._markDirectorySocketDisconnected(userId, roomId, now);
    }
  }

  async webSocketClose(socket) {
    await this._handleSocketDisconnect(socket);
  }

  async webSocketError(socket) {
    await this._handleSocketDisconnect(socket);
  }

  async join(input) {
    const result = this._upsert(input);
    this._broadcastPresence("member_joined");
    return result;
  }

  async heartbeat(input) {
    const userId = String(input?.user_id || "").trim();
    const before = userId
      ? this.ctx.storage.sql.exec(
          "SELECT seat_index, mic_enabled FROM room_members WHERE user_id = ? LIMIT 1",
          userId,
        ).toArray()[0]
      : null;
    const beforeSeat = before?.seat_index === null || before?.seat_index === undefined
      ? null
      : Number(before.seat_index);
    const beforeMic = Number(before?.mic_enabled || 0) === 1;
    const result = this._upsert(input);
    const after = userId
      ? this.ctx.storage.sql.exec(
          "SELECT seat_index, mic_enabled FROM room_members WHERE user_id = ? LIMIT 1",
          userId,
        ).toArray()[0]
      : null;
    const afterSeat = after?.seat_index === null || after?.seat_index === undefined
      ? null
      : Number(after.seat_index);
    const afterMic = Number(after?.mic_enabled || 0) === 1;
    if (beforeSeat !== afterSeat || beforeMic !== afterMic) {
      this._broadcastPresence("seat_changed");
    }
    return result;
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
      this.ctx.storage.sql.exec(
        "DELETE FROM room_seat_forces WHERE user_id = ?",
        userId,
      );
    }
    const result = {
      ok: true,
      server_time: now,
      members: this._members(now),
    };
    this._broadcastPresence("member_left");
    return result;
  }

  async state(userId = '') {
    return userId ? this._presenceStateFor(userId) : this._presenceState();
  }
}
