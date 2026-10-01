import { DurableObject } from "cloudflare:workers";

const MAX_AVATAR_DATA_LENGTH = 450000;
const MAX_ROOM_THEME_ASSET_LENGTH = 2500000;
const ROOM_THEME_DURATION_DAYS = new Set([7, 10, 15, 30]);
const VERIFIED_DIRECT_CALL_COST_COINS_PER_MINUTE = 400000;
const RANDOM_CALL_COST_COINS_PER_MINUTE = 500000;
const VERIFIED_RECEIVER_REWARD_PERCENT = 80;
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
    birthday: row.birthday ? String(row.birthday) : null,
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

function roomSeatLayout(seatCountValue) {
  const seatCount = Number(seatCountValue);
  let rowCount;
  if (seatCount >= 8 && seatCount <= 10) rowCount = 2;
  else if (seatCount >= 11 && seatCount <= 15) rowCount = 3;
  else if (seatCount >= 16 && seatCount <= 24) rowCount = 4;
  else if (seatCount >= 25 && seatCount <= 30) rowCount = 5;
  else if (seatCount >= 31 && seatCount <= 42) rowCount = 6;
  else return { row_count: 0, row_sizes: [] };

  if (rowCount <= 2) {
    const base = Math.floor(seatCount / rowCount);
    const extra = seatCount % rowCount;
    return {
      row_count: rowCount,
      row_sizes: Array.from({ length: rowCount }, (_, index) =>
        base + (index < extra ? 1 : 0)
      ),
    };
  }

  const upperRowCount = rowCount - 2;
  const seatsPerUpperRow = Math.ceil(seatCount / rowCount);
  const remaining = seatCount - (upperRowCount * seatsPerUpperRow);
  const penultimateRow = Math.ceil(remaining / 2);
  const lastRow = Math.floor(remaining / 2);

  return {
    row_count: rowCount,
    row_sizes: [
      ...Array.from({ length: upperRowCount }, () => seatsPerUpperRow),
      penultimateRow,
      lastRow,
    ],
  };
}

function rowToRoom(row) {
  if (!row) return null;
  const seatLayout = roomSeatLayout(row.seat_count);
  return {
    id: String(row.id),
    owner_id: String(row.owner_id),
    title: String(row.title),
    country_code: String(row.country_code),
    country_name: String(row.country_name),
    flag_emoji: String(row.flag_emoji),
    seat_count: Number(row.seat_count),
    seat_row_count: seatLayout.row_count,
    seat_row_sizes: seatLayout.row_sizes,
    party_mode: String(row.party_mode),
    locked: Number(row.locked) === 1,
    photo_data_url: row.photo_data_url ? String(row.photo_data_url) : null,
    theme_id: row.theme_id ? String(row.theme_id) : "royal-dark",
    theme_asset: row.theme_asset ? String(row.theme_asset) : null,
    seat_theme_id: row.seat_theme_id ? String(row.seat_theme_id) : "royal-gold",
    created_at: Number(row.created_at),
    updated_at: Number(row.updated_at),
    owner_name: row.owner_name ? String(row.owner_name) : null,
    owner_avatar_data_url: row.owner_avatar_data_url
      ? String(row.owner_avatar_data_url)
      : null,
    owner_flag_emoji: row.owner_flag_emoji
      ? String(row.owner_flag_emoji)
      : null,
    member_count: Number(row.member_count || 0),
    online: Number(row.member_count || 0),
    active_user_exp: Math.max(
      0,
      Number(row.active_user_exp ?? (Number(row.member_count || 0) * 500)),
    ),
    sending_exp: Math.max(0, Number(row.sending_exp || 0)),
    receiving_exp: Math.max(0, Number(row.receiving_exp || 0)),
    room_experience: Math.max(
      0,
      Number(
        row.room_experience ??
          (Number(row.member_count || 0) * 500) +
            Number(row.sending_exp || 0) +
            Number(row.receiving_exp || 0),
      ),
    ),
    announcement: row.announcement ? String(row.announcement) : "",
    category: row.category ? String(row.category) : "",
    privacy: row.privacy ? String(row.privacy) : "public",
    closed: Number(row.closed || 0) === 1,
    room_level: Math.max(1, Number(row.room_level || 1)),
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
        birthday TEXT,
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

      CREATE TABLE IF NOT EXISTS profile_trends (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_profile_trends_user
        ON profile_trends(user_id, created_at DESC);

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
        seat_theme_id TEXT NOT NULL DEFAULT 'royal-gold',
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

      CREATE TABLE IF NOT EXISTS app_room_invites (
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        invited_by TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(room_id, user_id)
      );

      CREATE TABLE IF NOT EXISTS app_recent_rooms (
        user_id TEXT NOT NULL,
        room_id TEXT NOT NULL,
        visited_at INTEGER NOT NULL,
        PRIMARY KEY(user_id, room_id)
      );
      CREATE INDEX IF NOT EXISTS idx_app_recent_rooms_user_time
        ON app_recent_rooms(user_id, visited_at DESC);

      CREATE TABLE IF NOT EXISTS app_user_presence (
        user_id TEXT PRIMARY KEY,
        room_id TEXT,
        last_seen INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_app_user_presence_seen
        ON app_user_presence(last_seen DESC);

      CREATE TABLE IF NOT EXISTS app_room_presence_counts (
        room_id TEXT PRIMARY KEY,
        member_count INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS room_realtime_events (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        event_json TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_room_realtime_events_room_time
        ON room_realtime_events(room_id, created_at DESC);

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

      CREATE TABLE IF NOT EXISTS user_notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        source_user_id TEXT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        read_at INTEGER,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_user_notifications_user_time
        ON user_notifications(user_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS user_feedback (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category TEXT NOT NULL,
        message TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'submitted',
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_user_feedback_user_time
        ON user_feedback(user_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS user_task_claims (
        user_id TEXT NOT NULL,
        task_id TEXT NOT NULL,
        reward_coins INTEGER NOT NULL DEFAULT 0,
        claimed_at INTEGER NOT NULL,
        PRIMARY KEY(user_id, task_id)
      );
      CREATE INDEX IF NOT EXISTS idx_user_task_claims_user
        ON user_task_claims(user_id, claimed_at DESC);

      CREATE TABLE IF NOT EXISTS user_preferences (
        user_id TEXT PRIMARY KEY,
        message_voice INTEGER NOT NULL DEFAULT 1,
        message_vibration INTEGER NOT NULL DEFAULT 1,
        room_floating_only INTEGER NOT NULL DEFAULT 0,
        language TEXT NOT NULL DEFAULT 'English',
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS event_notification_dispatches (
        event_id TEXT NOT NULL,
        phase TEXT NOT NULL,
        user_id TEXT NOT NULL,
        dispatched_at INTEGER NOT NULL,
        PRIMARY KEY(event_id, phase, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_event_notification_dispatches_user_time
        ON event_notification_dispatches(user_id, dispatched_at DESC);

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

      CREATE TABLE IF NOT EXISTS call_privacy_incidents (
        id TEXT PRIMARY KEY,
        call_id TEXT NOT NULL,
        actor_user_id TEXT NOT NULL,
        actor_name TEXT NOT NULL,
        action TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_call_privacy_incidents_call_time
        ON call_privacy_incidents(call_id, created_at DESC);


      CREATE TABLE IF NOT EXISTS gift_transactions (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        gift_id TEXT NOT NULL,
        gift_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        total_cost INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_gift_transactions_room_time
        ON gift_transactions(room_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS lucky_gift_results (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        room_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        gift_id TEXT NOT NULL,
        session_id TEXT,
        multiplier INTEGER NOT NULL DEFAULT 0,
        rebate_coins INTEGER NOT NULL DEFAULT 0,
        pool_contribution INTEGER NOT NULL DEFAULT 0,
        social_value_coins INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_lucky_gift_results_room_time
        ON lucky_gift_results(room_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_lucky_gift_results_sender_time
        ON lucky_gift_results(sender_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS lucky_gift_pool (
        singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
        balance INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS lucky_gift_daily (
        day_key TEXT NOT NULL,
        user_id TEXT NOT NULL,
        sent_count INTEGER NOT NULL DEFAULT 0,
        sent_coins INTEGER NOT NULL DEFAULT 0,
        rebate_coins INTEGER NOT NULL DEFAULT 0,
        highest_multiplier INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(day_key, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_lucky_gift_daily_rank
        ON lucky_gift_daily(day_key, rebate_coins DESC, sent_coins DESC);

      CREATE TABLE IF NOT EXISTS lucky_gift_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        room_id TEXT NOT NULL,
        gift_id TEXT NOT NULL,
        gift_name TEXT NOT NULL,
        unit_price INTEGER NOT NULL,
        send_count INTEGER NOT NULL DEFAULT 0,
        total_sent_coins INTEGER NOT NULL DEFAULT 0,
        total_rebate_coins INTEGER NOT NULL DEFAULT 0,
        highest_multiplier INTEGER NOT NULL DEFAULT 0,
        started_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_lucky_gift_sessions_user_time
        ON lucky_gift_sessions(user_id, updated_at DESC);

      CREATE TABLE IF NOT EXISTS lucky_gift_pool_daily (
        day_key TEXT PRIMARY KEY,
        contributed_coins INTEGER NOT NULL DEFAULT 0,
        distributed_coins INTEGER NOT NULL DEFAULT 0,
        settled_at INTEGER,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS lucky_gift_settlements (
        id TEXT PRIMARY KEY,
        day_key TEXT NOT NULL,
        rank INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        share_percent INTEGER NOT NULL,
        coins INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_lucky_gift_settlements_day
        ON lucky_gift_settlements(day_key, rank ASC);

      CREATE TABLE IF NOT EXISTS room_gift_owner_daily (
        room_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        day_key TEXT NOT NULL,
        gift_coins INTEGER NOT NULL DEFAULT 0,
        owner_share_coins INTEGER NOT NULL DEFAULT 0,
        settled_at INTEGER,
        PRIMARY KEY(room_id, day_key)
      );
      CREATE INDEX IF NOT EXISTS idx_room_gift_owner_daily_unsettled
        ON room_gift_owner_daily(settled_at, day_key);

      CREATE TABLE IF NOT EXISTS room_follows (
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(room_id, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_room_follows_room
        ON room_follows(room_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS room_memberships (
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        joined_at INTEGER NOT NULL,
        PRIMARY KEY(room_id, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_room_memberships_room
        ON room_memberships(room_id, joined_at ASC);

      CREATE TABLE IF NOT EXISTS lucky_pouches (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        creator_id TEXT NOT NULL,
        country_code TEXT NOT NULL,
        total_coins INTEGER NOT NULL,
        total_slots INTEGER NOT NULL,
        remaining_coins INTEGER NOT NULL,
        remaining_slots INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        completed_at INTEGER
      );
      CREATE INDEX IF NOT EXISTS idx_lucky_pouches_room
        ON lucky_pouches(room_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS lucky_pouch_claims (
        pouch_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        coins INTEGER NOT NULL,
        claimed_at INTEGER NOT NULL,
        PRIMARY KEY(pouch_id, user_id)
      );

      CREATE TABLE IF NOT EXISTS country_ribbons (
        id TEXT PRIMARY KEY,
        country_code TEXT NOT NULL,
        kind TEXT NOT NULL,
        priority INTEGER NOT NULL,
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        avatar_data_url TEXT,
        amount INTEGER NOT NULL,
        game_key TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_country_ribbons_country_queue
        ON country_ribbons(country_code, priority DESC, created_at ASC);

      CREATE TABLE IF NOT EXISTS app_wallets (
        user_id TEXT PRIMARY KEY,
        coins INTEGER NOT NULL DEFAULT 0,
        diamonds INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS wallet_coin_guards (
        user_id TEXT PRIMARY KEY,
        expected_coins INTEGER NOT NULL DEFAULT 0,
        quarantined_coins INTEGER NOT NULL DEFAULT 0,
        security_frozen INTEGER NOT NULL DEFAULT 0,
        freeze_reason TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS privileged_wallet_coin_guards (
        user_id TEXT NOT NULL,
        wallet_type TEXT NOT NULL,
        expected_balance INTEGER NOT NULL DEFAULT 0,
        quarantined_coins INTEGER NOT NULL DEFAULT 0,
        security_frozen INTEGER NOT NULL DEFAULT 0,
        freeze_reason TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(user_id, wallet_type)
      );

      CREATE TABLE IF NOT EXISTS room_game_actions (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        game_key TEXT NOT NULL,
        action_value TEXT NOT NULL,
        server_result TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_room_game_actions_room_time ON room_game_actions(room_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS ludo_room_sessions (
        room_id TEXT PRIMARY KEY,
        state_json TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS ludo_room_players (
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        color TEXT NOT NULL,
        joined_at INTEGER NOT NULL,
        PRIMARY KEY(room_id, user_id),
        UNIQUE(room_id, color)
      );
      CREATE INDEX IF NOT EXISTS idx_ludo_room_players_room
        ON ludo_room_players(room_id, joined_at ASC);

      CREATE TABLE IF NOT EXISTS security_action_windows (
        user_id TEXT NOT NULL,
        action_key TEXT NOT NULL,
        window_start INTEGER NOT NULL,
        action_count INTEGER NOT NULL DEFAULT 0,
        blocked_until INTEGER,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(user_id, action_key)
      );

      CREATE TABLE IF NOT EXISTS security_events (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        action_key TEXT NOT NULL,
        reason TEXT NOT NULL,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_security_events_user_time
        ON security_events(user_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS client_analytics_events (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        event_name TEXT NOT NULL,
        properties_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_client_analytics_user_time
        ON client_analytics_events(user_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_client_analytics_name_time
        ON client_analytics_events(event_name, created_at DESC);

      CREATE TABLE IF NOT EXISTS client_crash_reports (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        error_text TEXT NOT NULL,
        stack_text TEXT NOT NULL DEFAULT '',
        context_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_client_crash_user_time
        ON client_crash_reports(user_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS cp_relationships (
        user_a TEXT NOT NULL,
        user_b TEXT NOT NULL,
        state TEXT NOT NULL DEFAULT 'pending',
        intimacy INTEGER NOT NULL DEFAULT 0,
        level INTEGER NOT NULL DEFAULT 1,
        ring_id TEXT,
        requested_by TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(user_a, user_b)
      );
      CREATE INDEX IF NOT EXISTS idx_cp_relationships_users ON cp_relationships(user_a, user_b, state);

      CREATE TABLE IF NOT EXISTS cp_memories (
        id TEXT PRIMARY KEY,
        user_a TEXT NOT NULL,
        user_b TEXT NOT NULL,
        author_id TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_cp_memories_pair_time
        ON cp_memories(user_a, user_b, created_at DESC);

      CREATE TABLE IF NOT EXISTS wallet_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        coins_delta INTEGER NOT NULL DEFAULT 0,
        diamonds_delta INTEGER NOT NULL DEFAULT 0,
        reference_id TEXT,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      );
      CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_transactions_reference
        ON wallet_transactions(user_id, reference_id)
        WHERE reference_id IS NOT NULL;
      CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_time
        ON wallet_transactions(user_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS vip_entitlements (
        user_id TEXT PRIMARY KEY,
        vip_id TEXT NOT NULL,
        vip_level INTEGER NOT NULL,
        starts_at INTEGER NOT NULL,
        expires_at INTEGER,
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


      CREATE TABLE IF NOT EXISTS app_session_revocations (
        token_hash TEXT PRIMARY KEY,
        expires_at INTEGER NOT NULL,
        revoked_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_app_session_revocations_expiry
        ON app_session_revocations(expires_at);

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

      CREATE TABLE IF NOT EXISTS owner_unique_ids (
        public_id TEXT PRIMARY KEY,
        price_coins INTEGER NOT NULL DEFAULT 0,
        assigned_user_id TEXT,
        duration_days INTEGER NOT NULL DEFAULT 0,
        assigned_at INTEGER,
        expires_at INTEGER,
        previous_user_id TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_owner_unique_ids_user
        ON owner_unique_ids(assigned_user_id, updated_at DESC);

      CREATE TABLE IF NOT EXISTS owner_user_price_overrides (
        user_id TEXT NOT NULL,
        price_key TEXT NOT NULL,
        price_coins INTEGER NOT NULL DEFAULT 0,
        duration_days INTEGER,
        expires_at INTEGER,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(user_id, price_key)
      );
      CREATE INDEX IF NOT EXISTS idx_owner_user_price_overrides_expiry
        ON owner_user_price_overrides(expires_at);

      CREATE TABLE IF NOT EXISTS user_inventory (
        user_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        item_kind TEXT NOT NULL,
        acquired_at INTEGER NOT NULL,
        expires_at INTEGER,
        PRIMARY KEY(user_id, item_id)
      );
      CREATE INDEX IF NOT EXISTS idx_user_inventory_user_kind
        ON user_inventory(user_id, item_kind, acquired_at DESC);

      CREATE TABLE IF NOT EXISTS user_equipment (
        user_id TEXT PRIMARY KEY,
        equipped_frame_id TEXT,
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

      CREATE TABLE IF NOT EXISTS hierarchy_period_earnings (
        period_key TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        eligible_coins INTEGER NOT NULL DEFAULT 0,
        credited_usd_cents INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(period_key, user_id, role)
      );
      CREATE INDEX IF NOT EXISTS idx_hierarchy_period_role
        ON hierarchy_period_earnings(period_key, role, updated_at DESC);

      CREATE TABLE IF NOT EXISTS settlement_balances (
        user_id TEXT PRIMARY KEY,
        usd_cents INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS settlement_transfers (
        id TEXT PRIMARY KEY,
        sender_user_id TEXT NOT NULL,
        recipient_user_id TEXT NOT NULL,
        recipient_role TEXT NOT NULL,
        usd_cents INTEGER NOT NULL,
        diamonds_debited INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_settlement_transfers_sender
        ON settlement_transfers(sender_user_id, created_at DESC);

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

      CREATE TABLE IF NOT EXISTS families (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        tag TEXT NOT NULL,
        leader_user_id TEXT NOT NULL,
        experience INTEGER NOT NULL DEFAULT 0,
        wallet_coins INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE UNIQUE INDEX IF NOT EXISTS idx_families_leader
        ON families(leader_user_id);

      CREATE TABLE IF NOT EXISTS family_members (
        family_id TEXT NOT NULL,
        user_id TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL DEFAULT 'member',
        joined_at INTEGER NOT NULL,
        PRIMARY KEY(family_id, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_family_members_family
        ON family_members(family_id, role, joined_at);

      CREATE TABLE IF NOT EXISTS family_join_requests (
        family_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(family_id, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_family_join_requests_status
        ON family_join_requests(family_id, status, created_at);

      CREATE TABLE IF NOT EXISTS family_daily_logins (
        family_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        day_key TEXT NOT NULL,
        exp_awarded INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(family_id, user_id, day_key)
      );

      CREATE TABLE IF NOT EXISTS family_received_coins (
        id TEXT PRIMARY KEY,
        family_id TEXT NOT NULL,
        sender_user_id TEXT NOT NULL,
        receiver_user_id TEXT NOT NULL,
        coins INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'family_wallet',
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_family_received_coins_family_time
        ON family_received_coins(family_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS family_wallet_transfers (
        id TEXT PRIMARY KEY,
        family_id TEXT NOT NULL,
        sender_user_id TEXT NOT NULL,
        receiver_user_id TEXT NOT NULL,
        coins INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_family_wallet_transfers_family_time
        ON family_wallet_transfers(family_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS family_monthly_bonuses (
        family_id TEXT NOT NULL,
        month_key TEXT NOT NULL,
        received_coins INTEGER NOT NULL DEFAULT 0,
        bonus_basis_points INTEGER NOT NULL DEFAULT 0,
        bonus_coins INTEGER NOT NULL DEFAULT 0,
        settled_at INTEGER NOT NULL,
        PRIMARY KEY(family_id, month_key)
      );

      CREATE TABLE IF NOT EXISTS user_id_history (
        old_user_id TEXT PRIMARY KEY,
        new_user_id TEXT NOT NULL,
        changed_at INTEGER NOT NULL
      );
    `);

    for (const migration of [
      "ALTER TABLE app_users ADD COLUMN birthday TEXT",
      "ALTER TABLE app_users ADD COLUMN auth_provider TEXT NOT NULL DEFAULT 'google'",
      "ALTER TABLE room_themes ADD COLUMN starts_at INTEGER",
      "ALTER TABLE app_rooms ADD COLUMN theme_id TEXT NOT NULL DEFAULT 'royal-dark'",
      "ALTER TABLE app_rooms ADD COLUMN theme_asset TEXT",
      "ALTER TABLE app_rooms ADD COLUMN seat_theme_id TEXT NOT NULL DEFAULT 'royal-gold'",
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
      "ALTER TABLE app_wallets ADD COLUMN banned INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE app_rooms ADD COLUMN announcement TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE app_rooms ADD COLUMN category TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE app_rooms ADD COLUMN privacy TEXT NOT NULL DEFAULT 'public'",
      "ALTER TABLE app_rooms ADD COLUMN closed INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE app_rooms ADD COLUMN room_level INTEGER NOT NULL DEFAULT 1",
      "ALTER TABLE user_equipment ADD COLUMN equipped_vehicle_id TEXT",
      "ALTER TABLE user_equipment ADD COLUMN equipped_entry_id TEXT",
      "ALTER TABLE user_equipment ADD COLUMN equipped_profile_card_id TEXT",
      "ALTER TABLE user_equipment ADD COLUMN equipped_ring_id TEXT",
      "ALTER TABLE user_equipment ADD COLUMN equipped_bubble_id TEXT",
      "ALTER TABLE user_equipment ADD COLUMN equipped_profile_background_id TEXT",
      "ALTER TABLE families ADD COLUMN notice TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE lucky_gift_results ADD COLUMN session_id TEXT",
      "ALTER TABLE lucky_gift_results ADD COLUMN social_value_coins INTEGER NOT NULL DEFAULT 0"
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
       SELECT user_id, 0, 0, ? FROM app_users`,
      Date.now(),
    );
    this.ctx.storage.sql.exec(
      "INSERT OR IGNORE INTO owner_treasury (singleton_id, balance, updated_at) VALUES (1, 0, ?)",
      Date.now(),
    );
    this.ctx.storage.sql.exec(
      "INSERT OR IGNORE INTO lucky_gift_pool (singleton_id, balance, updated_at) VALUES (1, 0, ?)",
      Date.now(),
    );
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO wallet_coin_guards
        (user_id,expected_coins,quarantined_coins,security_frozen,freeze_reason,updated_at)
       SELECT user_id,coins,0,0,'',updated_at FROM app_wallets`,
    );
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO privileged_wallet_coin_guards
        (user_id,wallet_type,expected_balance,quarantined_coins,security_frozen,freeze_reason,updated_at)
       SELECT user_id,wallet_type,balance,0,0,'',updated_at FROM owner_wallets`,
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

    const defaultLuckyGifts = [
      ["lucky-colorful-rose", "Colorful Rose", 20, "🌈🌹", "assets/lucky_gifts/colorful_rose.webp"],
      ["lucky-rainbow-heart", "Rainbow Heart", 50, "🌈💖", "assets/lucky_gifts/rainbow_heart.webp"],
      ["lucky-magic-balloon", "Magic Balloon", 100, "🎈", "assets/lucky_gifts/magic_balloon.webp"],
      ["lucky-candy-star", "Candy Star", 200, "🍭⭐", "assets/lucky_gifts/candy_star.webp"],
      ["lucky-neon-butterfly", "Neon Butterfly", 500, "🦋", "assets/lucky_gifts/neon_butterfly.webp"],
      ["lucky-sparkle-crown", "Sparkle Crown", 1000, "👑", "assets/lucky_gifts/sparkle_crown.webp"],
      ["lucky-dream-cake", "Dream Cake", 2000, "🎂", "assets/lucky_gifts/dream_cake.webp"],
      ["lucky-galaxy-ring", "Galaxy Ring", 5000, "💍", "assets/lucky_gifts/galaxy_ring.webp"],
      ["lucky-shining-unicorn", "Shining Unicorn", 10000, "🦄", "assets/lucky_gifts/shining_unicorn.webp"],
      ["lucky-royal-treasure", "Royal Treasure Box", 20000, "🎁", "assets/lucky_gifts/royal_treasure.webp"],
    ];
    for (const [giftId, giftName, coinPrice, emoji, artworkAsset] of defaultLuckyGifts) {
      this.ctx.storage.sql.exec(
        `INSERT OR IGNORE INTO owner_catalog
          (id, kind, name, data_json, enabled, created_at, updated_at)
         VALUES (?, 'gift', ?, ?, 1, ?, ?)`,
        giftId,
        giftName,
        JSON.stringify({
          coin_price: coinPrice,
          effect_kind: "lucky",
          category: "Lucky",
          lucky: true,
          rebate: true,
          emoji,
          max_multiplier: 1000,
          high_win_multiplier: 200,
          host_reward_percent: 10,
          charm_wealth_percent: 10,
          prize_pool_percent: 2,
          artwork_asset: artworkAsset,
          send_effect: "fly_3d",
          impact_effect: "sparkle_pop",
          multiplier_effect: "float_multiplier",
        }),
        Date.now(),
        Date.now(),
      );

      const existingGift = this.ctx.storage.sql.exec(
        "SELECT data_json FROM owner_catalog WHERE id=? AND kind='gift' LIMIT 1",
        giftId,
      ).toArray()[0];
      if (existingGift) {
        try {
          const existingData = JSON.parse(String(existingGift.data_json || "{}"));
          let changed = false;
          const defaults = {
            artwork_asset: artworkAsset,
            send_effect: "fly_3d",
            impact_effect: "sparkle_pop",
            multiplier_effect: "float_multiplier",
          };
          for (const [key, value] of Object.entries(defaults)) {
            if (!existingData[key]) {
              existingData[key] = value;
              changed = true;
            }
          }
          if (changed) {
            this.ctx.storage.sql.exec(
              "UPDATE owner_catalog SET data_json=?,updated_at=? WHERE id=?",
              JSON.stringify(existingData), Date.now(), giftId,
            );
          }
        } catch {}
      }
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
    const premiumEffects = [
      ["frame","frame-royal-gold","Royal Gold",1],
      ["frame","frame-pink-heart","Pink Heart",2],
      ["frame","frame-crystal-star","Crystal Star",3],
      ["frame","frame-crown-queen","Crown Queen",4],
      ["frame","frame-rose-garden","Rose Garden",5],
      ["frame","frame-angel-wings","Angel Wings",6],
      ["frame","frame-diamond-ice-vip","Diamond Ice VIP",7],
      ["frame","frame-flame-king-vip","Flame King VIP",8],
      ["frame","frame-india-pride","India Pride",9],
      ["frame","frame-winner-trophy","Winner Trophy",10],

      ["profile_card","profile-card-royal-gold","Royal Gold Card",1],
      ["profile_card","profile-card-pink-heart","Pink Heart Card",2],
      ["profile_card","profile-card-crystal-star","Crystal Star Card",3],
      ["profile_card","profile-card-vip-queen","VIP Queen Card",4],
      ["profile_card","profile-card-family-leader","Family Leader Card",5],
      ["profile_card","profile-card-host","Host Card",6],
      ["profile_card","profile-card-agency","Agency Card",7],
      ["profile_card","profile-card-india-pride","India Pride Card",8],
      ["profile_card","profile-card-birthday","Birthday Card",9],
      ["profile_card","profile-card-winner","Winner Card",10],

      ["entry","entry-golden-sports-car","Golden Sports Car",1],
      ["entry","entry-angel-wings","Angel Wings",2],
      ["entry","entry-rose-love-castle","Rose Love Castle",3],
      ["entry","entry-royal-lion","Royal Lion",4],
      ["entry","entry-luxury-yacht","Luxury Yacht",5],
      ["entry","entry-princess-castle","Princess Castle",6],
      ["entry","entry-phoenix-fire","Phoenix Fire",7],
      ["entry","entry-diamond-ice","Diamond Ice",8],
      ["entry","entry-rocket-star","Rocket Star",9],
      ["entry","entry-winner-trophy","Winner Trophy",10],
    ];
    for (const [kind,id,name,order] of premiumEffects) {
      const r2Key = "premium/" + kind + "/" + id + ".webp";
      this.ctx.storage.sql.exec(
        `INSERT OR IGNORE INTO owner_catalog
          (id, kind, name, data_json, enabled, created_at, updated_at)
         VALUES (?, ?, ?, ?, 1, ?, ?)`,
        id,
        kind,
        name,
        JSON.stringify({
          coin_price: 0,
          duration_days: 0,
          order,
          effect_style: id,
          effect_version: 1,
          r2_key: r2Key,
          asset_url: "https://tinni-star-api.mishrajii7991.workers.dev/media/" + r2Key,
          preview_mode: "procedural_4d",
          test_release: true,
        }),
        Date.now(),
        Date.now(),
      );
    }

  }

  _ensureEconomyMigrations() {
    // The Durable Object constructor already creates the economy/family
    // tables and applies additive migrations before any RPC method runs.
    // Feature methods call this guard defensively; keep it as an idempotent
    // compatibility hook so those calls never crash the Worker.
    return true;
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
      `INSERT INTO owner_settings (key, value_json, updated_at)
       VALUES (?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET
         value_json = excluded.value_json,
         updated_at = excluded.updated_at`,
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
      `SELECT id, name, color, created_at
         FROM owner_user_tags
        WHERE user_id = ?
        ORDER BY created_at DESC`, userId,
    ).toArray().map((row) => ({
      id: String(row.id), name: String(row.name), color: String(row.color),
      created_at: Number(row.created_at),
    }));
  }

  listUserMedals(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) return [];
    const user = this.ctx.storage.sql.exec(
      "SELECT call_verified FROM app_users WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!user) return [];

    const medals = [];
    if (Number(user.call_verified || 0) === 1) {
      medals.push({ name: "Verified", color: "#4FC3F7" });
    }

    const controls = this._userControls(userId);
    if (Number(controls.vip_level || 0) > 0) {
      medals.push({
        name: "VIP " + Number(controls.vip_level || 0),
        color: "#FFD54F",
      });
    }

    const roles = this.ctx.storage.sql.exec(
      "SELECT role FROM owner_hierarchy WHERE user_id = ? AND active = 1 ORDER BY updated_at DESC",
      userId,
    ).toArray();
    const roleColors = {
      host: "#FFB74D",
      agency: "#AB47BC",
      bd: "#66BB6A",
      manager: "#42A5F5",
      admin: "#EF5350",
      "super admin": "#EC407A",
      merchant: "#26A69A",
      "coin seller": "#8D6E63",
    };
    for (const row of roles) {
      const role = String(row.role || "").trim();
      if (!role) continue;
      const label = role
        .split(/[_\s-]+/)
        .filter(Boolean)
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
        .join(" ");
      medals.push({
        name: label,
        color: roleColors[role.toLowerCase()] || "#90CAF9",
      });
    }

    const deduped = [];
    const seen = new Set();
    for (const medal of medals) {
      const key = medal.name.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      deduped.push(medal);
    }
    return deduped.slice(0, 12);
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
          `SELECT * FROM app_users
            WHERE user_id = ? OR user_id LIKE ? OR display_name LIKE ? OR email LIKE ?
            ORDER BY CASE WHEN user_id = ? THEN 0 ELSE 1 END, created_at DESC
            LIMIT ?`,
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
        medals: this.listUserMedals(user.user_id),
      };
    });
  }

  listVerifiedUsers(queryValue = "") {
    const query = String(queryValue || "").trim();
    const like = "%" + query + "%";
    return this.ctx.storage.sql.exec(
      `SELECT * FROM app_users
        WHERE call_verified = 1
          AND (? = '' OR user_id LIKE ? OR display_name LIKE ?)
        ORDER BY call_verified_at DESC, user_id ASC
        LIMIT 500`, query, like, like,
    ).toArray().map((row) => ({
      ...rowToUser(row),
      tags: this.listUserTags(row.user_id),
      medals: this.listUserMedals(row.user_id),
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
      `INSERT INTO owner_catalog
        (id, kind, name, data_json, enabled, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
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

  userPriceOverrides(userIdValue = "") {
    const userId = String(userIdValue || "").trim();
    const now = Date.now();
    const rows = userId
      ? this.ctx.storage.sql.exec("SELECT * FROM owner_user_price_overrides WHERE user_id = ? AND (expires_at IS NULL OR expires_at > ?) ORDER BY price_key", this._resolveOwnerUserId(userId), now).toArray()
      : this.ctx.storage.sql.exec("SELECT * FROM owner_user_price_overrides WHERE expires_at IS NULL OR expires_at > ? ORDER BY updated_at DESC LIMIT 5000", now).toArray();
    return rows.map((row) => ({
      user_id: String(row.user_id), price_key: String(row.price_key),
      price_coins: Math.max(0, Number(row.price_coins || 0)),
      duration_days: row.duration_days == null ? null : Math.max(0, Number(row.duration_days)),
      expires_at: row.expires_at == null ? null : Number(row.expires_at),
      updated_at: Number(row.updated_at || 0),
    }));
  }

  setUserPriceOverride(userIdValue, priceKeyValue, priceCoinsValue, durationDaysValue = null, expiresAtValue = null) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const priceKey = cleanText(priceKeyValue, 120).toLowerCase();
    if (!userId || !priceKey) throw new Error("User ID and price key are required");
    const exists = this.ctx.storage.sql.exec("SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", userId).toArray()[0];
    if (!exists) throw new Error("User not found");
    const price = Math.max(0, Number(priceCoinsValue || 0));
    const durationDays = durationDaysValue === null || durationDaysValue === undefined || durationDaysValue === ""
      ? null : Math.max(0, Number(durationDaysValue));
    const expiresAt = expiresAtValue ? Number(expiresAtValue) : null;
    if (expiresAt != null && (!Number.isFinite(expiresAt) || expiresAt <= Date.now())) throw new Error("Override expiry must be in the future");
    this.ctx.storage.sql.exec(
      `INSERT INTO owner_user_price_overrides (user_id,price_key,price_coins,duration_days,expires_at,updated_at)
       VALUES (?,?,?,?,?,?)
       ON CONFLICT(user_id,price_key) DO UPDATE SET price_coins=excluded.price_coins,
         duration_days=excluded.duration_days,expires_at=excluded.expires_at,updated_at=excluded.updated_at`,
      userId, priceKey, price, durationDays, expiresAt, Date.now(),
    );
    return this.userPriceOverrides(userId);
  }

  removeUserPriceOverride(userIdValue, priceKeyValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const priceKey = cleanText(priceKeyValue, 120).toLowerCase();
    this.ctx.storage.sql.exec("DELETE FROM owner_user_price_overrides WHERE user_id = ? AND price_key = ?", userId, priceKey);
    return this.userPriceOverrides(userId);
  }

  _effectivePrice(userIdValue, priceKeyValue, basePriceValue, baseDurationDaysValue = null) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const priceKey = cleanText(priceKeyValue, 120).toLowerCase();
    const now = Date.now();
    const row = this.ctx.storage.sql.exec(
      "SELECT price_coins,duration_days FROM owner_user_price_overrides WHERE user_id = ? AND price_key IN (?, '*') AND (expires_at IS NULL OR expires_at > ?) ORDER BY CASE WHEN price_key = ? THEN 0 ELSE 1 END LIMIT 1",
      userId, priceKey, now, priceKey,
    ).toArray()[0];
    const policies = this.ownerState().policies;
    const freeIds = Array.isArray(policies.free_user_ids) ? policies.free_user_ids.map(String) : [];
    if (!row) return {
      price: freeIds.includes(userId) ? 0 : Math.max(0, Number(basePriceValue || 0)),
      duration_days: baseDurationDaysValue == null ? null : Math.max(0, Number(baseDurationDaysValue)),
      overridden: freeIds.includes(userId),
    };
    return {
      price: Math.max(0, Number(row.price_coins || 0)),
      duration_days: row.duration_days == null
        ? (baseDurationDaysValue == null ? null : Math.max(0, Number(baseDurationDaysValue)))
        : Math.max(0, Number(row.duration_days)),
      overridden: true,
    };
  }

  ownerState() {
    this._ensureEconomyMigrations();
    const defaultFeatures = {
      voice_rooms: true, gifts: true, vip: true, games: true,
      host_system: true, agency_system: true, bd_system: true,
      coin_seller: true, merchant: true, banners: true,
      vehicle_entries: true, frames: true,
    };
    const defaultPolicies = {
      coins_per_usd: 2000000, diamonds_per_coin: 1, diamond_usd_reference_diamonds: 4000000, diamond_usd_reference_cents: 170,
      room_online_exp_per_minute: 50, room_online_daily_minutes_cap: 480,
      host_first_target_received_coins: 4000000, host_first_target_usd: 1.7,
      agency_commission_percent: 10, bd_target_1_usd: 500,
      bd_target_1_percent: 7, bd_target_2_usd: 1000,
      bd_target_2_percent: 10, minimum_transfer_usd: 2,
      direct_call_coins: 400000, random_call_coins: 500000, receiver_percent: 80,
      room_theme_coins: 10000000, cp_connect_coins: 0, cp_disconnect_coins: 0, frame_default_coins: 0, vip_default_coins: 0,
      unique_id_purchase_coins: 0, free_user_ids: [],
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
      lucky_gift_config: this._luckyGiftConfig(),
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
      `INSERT INTO owner_user_controls
        (user_id, banned, device_banned, invisible, locked_bypass, vip_level, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         banned = excluded.banned, device_banned = excluded.device_banned,
         invisible = excluded.invisible, locked_bypass = excluded.locked_bypass,
         vip_level = excluded.vip_level, updated_at = excluded.updated_at`,
      userId, next.banned ? 1 : 0, next.device_banned ? 1 : 0,
      next.invisible ? 1 : 0, next.locked_bypass ? 1 : 0,
      Math.max(0, Number(next.vip_level || 0)), Date.now(),
    );
    return this._userControls(userId);
  }

  _normalWalletGuard(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) throw new Error("User ID is required");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT OR IGNORE INTO app_wallets(user_id,coins,diamonds,banned,updated_at) VALUES (?,0,0,0,?)",
      userId, now,
    );
    const wallet = this.ctx.storage.sql.exec(
      "SELECT coins FROM app_wallets WHERE user_id=? LIMIT 1",
      userId,
    ).toArray()[0];
    const actual = Math.max(0, Number(wallet?.coins || 0));
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO wallet_coin_guards
        (user_id,expected_coins,quarantined_coins,security_frozen,freeze_reason,updated_at)
       VALUES (?,?,0,0,'',?)`,
      userId, actual, now,
    );
    let guard = this.ctx.storage.sql.exec(
      "SELECT * FROM wallet_coin_guards WHERE user_id=? LIMIT 1",
      userId,
    ).toArray()[0];
    const expected = Math.max(0, Number(guard?.expected_coins || 0));

    if (actual > expected) {
      const unexpected = actual - expected;
      this.ctx.storage.sql.exec(
        "UPDATE app_wallets SET coins=?,updated_at=? WHERE user_id=?",
        expected, now, userId,
      );
      this.ctx.storage.sql.exec(
        `UPDATE wallet_coin_guards
            SET quarantined_coins=quarantined_coins+?,
                security_frozen=1,
                freeze_reason='unauthorized_coin_credit',
                updated_at=?
          WHERE user_id=?`,
        unexpected, now, userId,
      );
      this._recordSecurityEvent(
        userId,
        "wallet_coin_guard",
        "unauthorized_coin_credit",
        { unexpected_coins: unexpected },
      );
    } else if (actual < expected) {
      // Normal spending reduces the expected balance; only positive drift is suspicious.
      this.ctx.storage.sql.exec(
        "UPDATE wallet_coin_guards SET expected_coins=?,updated_at=? WHERE user_id=?",
        actual, now, userId,
      );
    }

    guard = this.ctx.storage.sql.exec(
      "SELECT * FROM wallet_coin_guards WHERE user_id=? LIMIT 1",
      userId,
    ).toArray()[0];
    const current = this.ctx.storage.sql.exec(
      "SELECT coins FROM app_wallets WHERE user_id=? LIMIT 1",
      userId,
    ).toArray()[0];
    return {
      user_id: userId,
      coins: Math.max(0, Number(current?.coins || 0)),
      expected_coins: Math.max(0, Number(guard?.expected_coins || 0)),
      quarantined_coins: Math.max(0, Number(guard?.quarantined_coins || 0)),
      security_frozen: Number(guard?.security_frozen || 0) === 1,
      freeze_reason: String(guard?.freeze_reason || ""),
    };
  }

  _privilegedWalletGuard(userIdValue, walletTypeValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const walletType = String(walletTypeValue || "").trim().toLowerCase();
    if (!userId || !["coin_seller","merchant"].includes(walletType)) {
      throw new Error("Valid Coin Seller or Merchant wallet is required");
    }
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO owner_wallets
        (user_id,wallet_type,balance,banned,updated_at)
       VALUES (?,?,0,0,?)`,
      userId, walletType, now,
    );
    const wallet = this.ctx.storage.sql.exec(
      "SELECT balance FROM owner_wallets WHERE user_id=? AND wallet_type=? LIMIT 1",
      userId, walletType,
    ).toArray()[0];
    const actual = Math.max(0, Number(wallet?.balance || 0));
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO privileged_wallet_coin_guards
        (user_id,wallet_type,expected_balance,quarantined_coins,security_frozen,freeze_reason,updated_at)
       VALUES (?,?,?,0,0,'',?)`,
      userId, walletType, actual, now,
    );
    let guard = this.ctx.storage.sql.exec(
      "SELECT * FROM privileged_wallet_coin_guards WHERE user_id=? AND wallet_type=? LIMIT 1",
      userId, walletType,
    ).toArray()[0];
    const expected = Math.max(0, Number(guard?.expected_balance || 0));

    if (actual > expected) {
      const unexpected = actual - expected;
      this.ctx.storage.sql.exec(
        "UPDATE owner_wallets SET balance=?,updated_at=? WHERE user_id=? AND wallet_type=?",
        expected, now, userId, walletType,
      );
      this.ctx.storage.sql.exec(
        `UPDATE privileged_wallet_coin_guards
            SET quarantined_coins=quarantined_coins+?,
                security_frozen=1,
                freeze_reason='unauthorized_coin_credit',
                updated_at=?
          WHERE user_id=? AND wallet_type=?`,
        unexpected, now, userId, walletType,
      );
      this._recordSecurityEvent(
        userId,
        "privileged_wallet_coin_guard",
        "unauthorized_coin_credit",
        { wallet_type: walletType, unexpected_coins: unexpected },
      );
    } else if (actual < expected) {
      this.ctx.storage.sql.exec(
        "UPDATE privileged_wallet_coin_guards SET expected_balance=?,updated_at=? WHERE user_id=? AND wallet_type=?",
        actual, now, userId, walletType,
      );
    }

    guard = this.ctx.storage.sql.exec(
      "SELECT * FROM privileged_wallet_coin_guards WHERE user_id=? AND wallet_type=? LIMIT 1",
      userId, walletType,
    ).toArray()[0];
    const current = this.ctx.storage.sql.exec(
      "SELECT balance FROM owner_wallets WHERE user_id=? AND wallet_type=? LIMIT 1",
      userId, walletType,
    ).toArray()[0];
    return {
      user_id: userId,
      wallet_type: walletType,
      balance: Math.max(0, Number(current?.balance || 0)),
      expected_balance: Math.max(0, Number(guard?.expected_balance || 0)),
      quarantined_coins: Math.max(0, Number(guard?.quarantined_coins || 0)),
      security_frozen: Number(guard?.security_frozen || 0) === 1,
      freeze_reason: String(guard?.freeze_reason || ""),
    };
  }

  _debitNormalWalletAuthorized(userIdValue, amountValue, sourceValue = "authorized_spend") {
    const amount = Math.floor(Number(amountValue || 0));
    if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error("Enter a valid coin amount");
    const guard = this._normalWalletGuard(userIdValue);
    if (guard.security_frozen) throw new Error("Wallet is security-frozen. Owner unfreeze is required.");
    if (guard.coins < amount) throw new Error("Wallet balance is not enough");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "UPDATE app_wallets SET coins=coins-?,updated_at=? WHERE user_id=?",
      amount, now, guard.user_id,
    );
    this.ctx.storage.sql.exec(
      "UPDATE wallet_coin_guards SET expected_coins=MAX(0,expected_coins-?),updated_at=? WHERE user_id=?",
      amount, now, guard.user_id,
    );
    return this._normalWalletGuard(guard.user_id);
  }

  _creditNormalWalletAuthorized(userIdValue, amountValue, sourceValue = "authorized_transfer") {
    const amount = Math.floor(Number(amountValue || 0));
    if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error("Enter a valid coin amount");
    const guard = this._normalWalletGuard(userIdValue);
    if (guard.security_frozen) throw new Error("Wallet is security-frozen. Owner unfreeze is required.");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "UPDATE app_wallets SET coins=coins+?,updated_at=? WHERE user_id=?",
      amount, now, guard.user_id,
    );
    this.ctx.storage.sql.exec(
      "UPDATE wallet_coin_guards SET expected_coins=expected_coins+?,updated_at=? WHERE user_id=?",
      amount, now, guard.user_id,
    );
    return this._normalWalletGuard(guard.user_id);
  }

  _creditPrivilegedWalletAuthorized(userIdValue, walletTypeValue, amountValue) {
    const amount = Math.floor(Number(amountValue || 0));
    if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error("Enter a valid coin amount");
    const guard = this._privilegedWalletGuard(userIdValue, walletTypeValue);
    if (guard.security_frozen) throw new Error("Wallet is security-frozen. Owner unfreeze is required.");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "UPDATE owner_wallets SET balance=balance+?,updated_at=? WHERE user_id=? AND wallet_type=?",
      amount, now, guard.user_id, guard.wallet_type,
    );
    this.ctx.storage.sql.exec(
      "UPDATE privileged_wallet_coin_guards SET expected_balance=expected_balance+?,updated_at=? WHERE user_id=? AND wallet_type=?",
      amount, now, guard.user_id, guard.wallet_type,
    );
    return this._privilegedWalletGuard(guard.user_id, guard.wallet_type);
  }

  _debitPrivilegedWalletAuthorized(userIdValue, walletTypeValue, amountValue) {
    const amount = Math.floor(Number(amountValue || 0));
    if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error("Enter a valid coin amount");
    const guard = this._privilegedWalletGuard(userIdValue, walletTypeValue);
    if (guard.security_frozen) throw new Error("Wallet is security-frozen. Owner unfreeze is required.");
    if (guard.balance < amount) throw new Error("Wallet balance is not enough");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "UPDATE owner_wallets SET balance=balance-?,updated_at=? WHERE user_id=? AND wallet_type=?",
      amount, now, guard.user_id, guard.wallet_type,
    );
    this.ctx.storage.sql.exec(
      "UPDATE privileged_wallet_coin_guards SET expected_balance=MAX(0,expected_balance-?),updated_at=? WHERE user_id=? AND wallet_type=?",
      amount, now, guard.user_id, guard.wallet_type,
    );
    return this._privilegedWalletGuard(guard.user_id, guard.wallet_type);
  }

  _ownerUnfreezeWalletSecurity(userIdValue, walletTypeValue = "normal") {
    const userId = this._resolveOwnerUserId(userIdValue);
    const walletType = String(walletTypeValue || "normal").trim().toLowerCase();
    const now = Date.now();
    if (walletType === "normal") {
      this._normalWalletGuard(userId);
      const wallet = this.ctx.storage.sql.exec(
        "SELECT coins FROM app_wallets WHERE user_id=? LIMIT 1", userId,
      ).toArray()[0];
      this.ctx.storage.sql.exec(
        `UPDATE wallet_coin_guards
            SET expected_coins=?,quarantined_coins=0,security_frozen=0,freeze_reason='',updated_at=?
          WHERE user_id=?`,
        Math.max(0, Number(wallet?.coins || 0)), now, userId,
      );
      return { wallet_type: "normal", ...this._normalWalletGuard(userId) };
    }
    if (!["coin_seller","merchant"].includes(walletType)) throw new Error("Unsupported wallet type");
    this._privilegedWalletGuard(userId, walletType);
    const wallet = this.ctx.storage.sql.exec(
      "SELECT balance FROM owner_wallets WHERE user_id=? AND wallet_type=? LIMIT 1",
      userId, walletType,
    ).toArray()[0];
    this.ctx.storage.sql.exec(
      `UPDATE privileged_wallet_coin_guards
          SET expected_balance=?,quarantined_coins=0,security_frozen=0,freeze_reason='',updated_at=?
        WHERE user_id=? AND wallet_type=?`,
      Math.max(0, Number(wallet?.balance || 0)), now, userId, walletType,
    );
    return this._privilegedWalletGuard(userId, walletType);
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
      const guard = this._normalWalletGuard(userId);
      if (guard.security_frozen && !["ban","unban"].includes(operation)) {
        throw new Error("Wallet is security-frozen. Only Owner can remove the security freeze.");
      }
      const now = Date.now();
      if (operation === "credit") {
        const credited = this._creditNormalWalletAuthorized(
          userId,
          amount,
          "owner_or_staff_panel",
        );
        const confirmed = this.getWallet(userId);
        if (
          confirmed.security_frozen ||
          Number(confirmed.coins || 0) !== Number(credited.coins || 0)
        ) {
          throw new Error("Normal wallet credit could not be confirmed");
        }
        this.ctx.storage.sql.exec(
          "INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?,'owner_wallet_credit',?,0,?,?,?)",
          crypto.randomUUID(),
          userId,
          amount,
          "owner-wallet:" + crypto.randomUUID(),
          "Coins added from Owner Panel",
          now,
        );
        return { wallet_type: "normal", ...confirmed, owner_credit_confirmed: true };
      } else if (operation === "debit") {
        const wallet = this.getWallet(userId);
        if (wallet.security_frozen) throw new Error("Wallet is security-frozen");
        if (wallet.coins < amount) throw new Error("Wallet balance is too low");
        this.ctx.storage.sql.exec(
          "UPDATE app_wallets SET coins=coins-?,updated_at=? WHERE user_id=?",
          amount, now, userId,
        );
        this.ctx.storage.sql.exec(
          "UPDATE wallet_coin_guards SET expected_coins=MAX(0,expected_coins-?),updated_at=? WHERE user_id=?",
          amount, now, userId,
        );
      } else if (operation === "ban" || operation === "unban") {
        this.ctx.storage.sql.exec(
          "UPDATE app_wallets SET banned=?,updated_at=? WHERE user_id=?",
          operation === "ban" ? 1 : 0, now, userId,
        );
      } else if (operation !== "create") {
        throw new Error("Unsupported wallet operation");
      }
      return { wallet_type: "normal", ...this.getWallet(userId) };
    }

    if (!["coin_seller", "merchant"].includes(walletType)) {
      throw new Error("Unsupported wallet type");
    }
    const guard = this._privilegedWalletGuard(userId, walletType);
    if (guard.security_frozen && !["ban","unban"].includes(operation)) {
      throw new Error("Wallet is security-frozen. Only Owner can remove the security freeze.");
    }
    const now = Date.now();
    if (operation === "credit") {
      this._creditPrivilegedWalletAuthorized(userId, walletType, amount);
    } else if (operation === "debit") {
      this._debitPrivilegedWalletAuthorized(userId, walletType, amount);
    } else if (operation === "ban" || operation === "unban") {
      this.ctx.storage.sql.exec(
        "UPDATE owner_wallets SET banned=?,updated_at=? WHERE user_id=? AND wallet_type=?",
        operation === "ban" ? 1 : 0, now, userId, walletType,
      );
    } else if (operation !== "create") {
      throw new Error("Unsupported wallet operation");
    }
    const updated = this.ctx.storage.sql.exec(
      "SELECT banned,updated_at FROM owner_wallets WHERE user_id=? AND wallet_type=? LIMIT 1",
      userId, walletType,
    ).toArray()[0];
    const current = this._privilegedWalletGuard(userId, walletType);
    return {
      ...current,
      balance: current.security_frozen ? 0 : current.balance,
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
    const walletType = String(walletTypeValue || "normal").trim().toLowerCase();
    if (walletType === "normal") {
      const guard = this._normalWalletGuard(userIdValue);
      if (guard.security_frozen) throw new Error("Target wallet is security-frozen");
    } else {
      const guard = this._privilegedWalletGuard(userIdValue, walletType);
      if (guard.security_frozen) throw new Error("Target wallet is security-frozen");
    }
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
      "SELECT user_id, country_code FROM app_users WHERE user_id = ? LIMIT 1", userId,
    ).toArray()[0];
    if (!exists) throw new Error("User not found");
    const active = activeValue !== false;
    let parent = parentValue ? this._resolveOwnerUserId(parentValue) : null;

    if (role === "agency" && active) {
      // Agency Owner is always a Host of their own Agency.
      parent = parent || null;
      this.ctx.storage.sql.exec(
        `INSERT INTO owner_hierarchy
          (user_id, role, parent_user_id, active, data_json, updated_at)
         VALUES (?, 'host', ?, 1, ?, ?)
         ON CONFLICT(user_id, role) DO UPDATE SET
           parent_user_id=excluded.parent_user_id, active=1,
           data_json=excluded.data_json, updated_at=excluded.updated_at`,
        userId, userId, JSON.stringify({ agency_owner_host: true }), Date.now(),
      );
    }

    if (role === "host" && active) {
      if (!parent) throw new Error("Host must belong to an Agency");
      const agency = this.ctx.storage.sql.exec(
        "SELECT active FROM owner_hierarchy WHERE user_id = ? AND role = 'agency' LIMIT 1",
        parent,
      ).toArray()[0];
      if (!agency || Number(agency.active || 0) !== 1) {
        throw new Error("Active Agency is required");
      }
      const ownsAgency = this.ctx.storage.sql.exec(
        "SELECT active FROM owner_hierarchy WHERE user_id = ? AND role = 'agency' LIMIT 1",
        userId,
      ).toArray()[0];
      if (ownsAgency && Number(ownsAgency.active || 0) === 1 && parent !== userId) {
        throw new Error("Agency Owner can only be Host of their own Agency");
      }
      const hostUser = this.ctx.storage.sql.exec(
        "SELECT country_code FROM app_users WHERE user_id = ? LIMIT 1", userId,
      ).toArray()[0];
      const agencyUser = this.ctx.storage.sql.exec(
        "SELECT country_code FROM app_users WHERE user_id = ? LIMIT 1", parent,
      ).toArray()[0];
      if (String(hostUser?.country_code || "").toUpperCase() !==
          String(agencyUser?.country_code || "").toUpperCase()) {
        throw new Error("Host and Agency must be from the same country");
      }
    }

    this.ctx.storage.sql.exec(
      `INSERT INTO owner_hierarchy
        (user_id, role, parent_user_id, active, data_json, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id, role) DO UPDATE SET
         parent_user_id = excluded.parent_user_id, active = excluded.active,
         data_json = excluded.data_json, updated_at = excluded.updated_at`,
      userId, role, parent, active ? 1 : 0,
      JSON.stringify(dataValue && typeof dataValue === "object" ? dataValue : {}),
      Date.now(),
    );

    if (role === "agency" && !active) {
      this.ctx.storage.sql.exec(
        "UPDATE owner_hierarchy SET active = 0, updated_at = ? WHERE user_id = ? AND role = 'host' AND parent_user_id = ?",
        Date.now(), userId, userId,
      );
    }
    return { user_id: userId, role, parent_user_id: parent, active };
  }

  _activeHierarchy(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    return this.ctx.storage.sql.exec(
      "SELECT user_id,role,parent_user_id,updated_at FROM owner_hierarchy WHERE user_id = ? AND active = 1 ORDER BY updated_at DESC",
      userId,
    ).toArray().map((row) => ({
      user_id: String(row.user_id), role: String(row.role),
      parent_user_id: row.parent_user_id ? String(row.parent_user_id) : null,
      activated_at: Number(row.updated_at || 0),
    }));
  }

  _isActiveHost(userIdValue) {
    return this._activeHierarchy(userIdValue).some((row) => row.role === "host");
  }

  _periodKey(nowValue = Date.now()) {
    const d = new Date(Number(nowValue || Date.now()));
    const y = d.getUTCFullYear();
    const m = String(d.getUTCMonth() + 1).padStart(2, "0");
    const half = d.getUTCDate() <= 15 ? "H1" : "H2";
    return y + "-" + m + "-" + half;
  }

  _ensureSettlementBalance(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT OR IGNORE INTO settlement_balances (user_id,usd_cents,updated_at) VALUES (?,0,?)",
      userId, now,
    );
    return this.ctx.storage.sql.exec(
      "SELECT usd_cents,updated_at FROM settlement_balances WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
  }

  _creditSettlement(userIdValue, usdCentsValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const cents = Math.max(0, Math.floor(Number(usdCentsValue || 0)));
    if (!userId || cents <= 0) return;
    this._ensureSettlementBalance(userId);
    this.ctx.storage.sql.exec(
      "UPDATE settlement_balances SET usd_cents=usd_cents+?,updated_at=? WHERE user_id=?",
      cents, Date.now(), userId,
    );
  }

  _recordHostEligibleGift(hostUserIdValue, receivedCoinsValue, nowValue = Date.now()) {
    const hostUserId = this._resolveOwnerUserId(hostUserIdValue);
    const receivedCoins = Math.max(0, Math.floor(Number(receivedCoinsValue || 0)));
    if (!hostUserId || receivedCoins <= 0 || !this._isActiveHost(hostUserId)) return;
    const hostRole = this._activeHierarchy(hostUserId).find((row) => row.role === "host");
    const agencyId = hostRole?.parent_user_id;
    if (!agencyId) return;
    const period = this._periodKey(nowValue);
    const now = Number(nowValue || Date.now());

    this.ctx.storage.sql.exec(
      `INSERT INTO hierarchy_period_earnings(period_key,user_id,role,eligible_coins,credited_usd_cents,updated_at)
       VALUES (?,?,'host',?,0,?)
       ON CONFLICT(period_key,user_id,role) DO UPDATE SET
         eligible_coins=eligible_coins+excluded.eligible_coins,updated_at=excluded.updated_at`,
      period, hostUserId, receivedCoins, now,
    );
    this.ctx.storage.sql.exec(
      `INSERT INTO hierarchy_period_earnings(period_key,user_id,role,eligible_coins,credited_usd_cents,updated_at)
       VALUES (?,?,'agency',?,0,?)
       ON CONFLICT(period_key,user_id,role) DO UPDATE SET
         eligible_coins=eligible_coins+excluded.eligible_coins,updated_at=excluded.updated_at`,
      period, agencyId, receivedCoins, now,
    );

    const agencyRow = this.ctx.storage.sql.exec(
      "SELECT eligible_coins,credited_usd_cents FROM hierarchy_period_earnings WHERE period_key=? AND user_id=? AND role='agency' LIMIT 1",
      period, agencyId,
    ).toArray()[0];
    const agencyGrossCents = Math.floor(Number(agencyRow?.eligible_coins || 0) * 170 / 4000000);
    const agencyCommissionCents = Math.floor(agencyGrossCents * 10 / 100);
    const agencyDelta = Math.max(0, agencyCommissionCents - Number(agencyRow?.credited_usd_cents || 0));
    if (agencyDelta > 0) {
      this._creditSettlement(agencyId, agencyDelta);
      this.ctx.storage.sql.exec(
        "UPDATE hierarchy_period_earnings SET credited_usd_cents=?,updated_at=? WHERE period_key=? AND user_id=? AND role='agency'",
        agencyCommissionCents, now, period, agencyId,
      );
    }

    const agencyHierarchy = this._activeHierarchy(agencyId).find((row) => row.role === "agency");
    const bdId = agencyHierarchy?.parent_user_id;
    if (!bdId) return;
    this.ctx.storage.sql.exec(
      `INSERT INTO hierarchy_period_earnings(period_key,user_id,role,eligible_coins,credited_usd_cents,updated_at)
       VALUES (?,?,'bd',?,0,?)
       ON CONFLICT(period_key,user_id,role) DO UPDATE SET
         eligible_coins=eligible_coins+excluded.eligible_coins,updated_at=excluded.updated_at`,
      period, bdId, receivedCoins, now,
    );
    const bdRow = this.ctx.storage.sql.exec(
      "SELECT eligible_coins,credited_usd_cents FROM hierarchy_period_earnings WHERE period_key=? AND user_id=? AND role='bd' LIMIT 1",
      period, bdId,
    ).toArray()[0];
    const bdGrossCents = Math.floor(Number(bdRow?.eligible_coins || 0) * 170 / 4000000);
    const bdPercent = bdGrossCents >= 100000 ? 10 : (bdGrossCents >= 50000 ? 7 : 0);
    const bdCommissionCents = Math.floor(bdGrossCents * bdPercent / 100);
    const bdDelta = Math.max(0, bdCommissionCents - Number(bdRow?.credited_usd_cents || 0));
    if (bdDelta > 0) {
      this._creditSettlement(bdId, bdDelta);
      this.ctx.storage.sql.exec(
        "UPDATE hierarchy_period_earnings SET credited_usd_cents=?,updated_at=? WHERE period_key=? AND user_id=? AND role='bd'",
        bdCommissionCents, now, period, bdId,
      );
    }
  }

  _changeUserId(oldIdValue, newIdValue) {
    const oldId = this._resolveOwnerUserId(oldIdValue);
    const newId = String(newIdValue || "").trim();
    if (!oldId || !newId) throw new Error("Current and new user ID are required");
    const numericId = /^\d{4,8}$/.test(newId);
    const nameId = /^[A-Za-z][A-Za-z0-9_]{2,19}$/.test(newId);
    if (!numericId && !nameId) {
      throw new Error(
        "Public ID must be 4 to 8 digits or a 3 to 20 character Name ID using letters, numbers and underscore",
      );
    }
    if (nameId) {
      const approved = this.ctx.storage.sql.exec(
        "SELECT public_id FROM owner_unique_ids WHERE LOWER(public_id) = LOWER(?) AND enabled = 1 LIMIT 1",
        newId,
      ).toArray()[0];
      if (!approved) {
        throw new Error("Name ID must be added from Owner Panel first");
      }
    }
    if (oldId.toLowerCase() === newId.toLowerCase()) {
      return this.ownerSearchUsers(oldId, 1)[0];
    }
    const user = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", oldId,
    ).toArray()[0];
    if (!user) throw new Error("User not found");
    const taken = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE LOWER(user_id) = LOWER(?) LIMIT 1", newId,
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
      case "wallet-security-unfreeze": return this._ownerUnfreezeWalletSecurity(data.user_id, data.wallet_type);
      case "user-search": return { users: this.ownerSearchUsers(data.user_id || data.query, 50) };
      case "user-ban": return this._setUserControl(data.user_id, { banned: String(data.status) === "ban" });
      case "device-ban": return this._setUserControl(data.user_id, { device_banned: String(data.status) === "ban" });
      case "user-invisible": return this._setUserControl(data.user_id, { invisible: on(data.status) });
      case "locked-bypass": return this._setUserControl(data.user_id, { locked_bypass: on(data.status) });
      case "vip-grant": return this._setUserControl(data.user_id, {
        vip_level: String(data.operation) === "remove" ? 0 : Math.max(1, Number(data.vip_level || 1)),
      });
      case "unique-id-new": {
        const requestedId = String(data.public_id || "").trim();
        const numericId = /^\\d{4,8}$/.test(requestedId);
        const nameId = /^[A-Za-z][A-Za-z0-9_]{2,19}$/.test(requestedId);
        if (!numericId && !nameId) {
          throw new Error(
            "Unique ID must be 4 to 8 digits or a 3 to 20 character Name ID using letters, numbers and underscore",
          );
        }
        const price = Math.max(0, Math.floor(Number(data.price_coins || 0)));
        const durationDays = Math.max(0, Math.floor(Number(data.duration_days || 0)));
        const existingUser = this.ctx.storage.sql.exec(
          "SELECT user_id FROM app_users WHERE LOWER(user_id) = LOWER(?) LIMIT 1",
          requestedId,
        ).toArray()[0];
        if (existingUser) throw new Error("Unique ID is already in use");
        const existingOffer = this.ctx.storage.sql.exec(
          "SELECT public_id FROM owner_unique_ids WHERE LOWER(public_id) = LOWER(?) LIMIT 1",
          requestedId,
        ).toArray()[0];
        const publicId = existingOffer ? String(existingOffer.public_id) : requestedId;
        this.ctx.storage.sql.exec(
          `INSERT INTO owner_unique_ids (public_id,price_coins,duration_days,assigned_user_id,enabled,created_at,updated_at)
           VALUES (?,?,?,NULL,1,?,?)
           ON CONFLICT(public_id) DO UPDATE SET price_coins=excluded.price_coins,duration_days=excluded.duration_days,enabled=1,updated_at=excluded.updated_at`,
          publicId, price, durationDays, Date.now(), Date.now(),
        );
        return {
          public_id: publicId,
          id_type: nameId ? "name" : "number",
          price_coins: price,
          duration_days: durationDays,
          permanent: durationDays === 0,
          enabled: true,
        };
      }
      case "unique-id-price": {
        const requestedId = String(data.public_id || "").trim();
        const price = Math.max(0, Math.floor(Number(data.price_coins || 0)));
        const durationDays = Math.max(0, Math.floor(Number(data.duration_days || 0)));
        const row = this.ctx.storage.sql.exec(
          "SELECT public_id FROM owner_unique_ids WHERE LOWER(public_id) = LOWER(?) LIMIT 1",
          requestedId,
        ).toArray()[0];
        if (!row) throw new Error("Unique ID not found");
        const publicId = String(row.public_id);
        this.ctx.storage.sql.exec(
          "UPDATE owner_unique_ids SET price_coins = ?, duration_days = ?, updated_at = ? WHERE public_id = ?",
          price,
          durationDays,
          Date.now(),
          publicId,
        );
        return {
          public_id: publicId,
          price_coins: price,
          duration_days: durationDays,
          permanent: durationDays === 0,
        };
      }
      case "id-change": return this._changeUserId(data.user_id, data.new_id);
      case "room-ban": {
        const roomId = String(data.room_id || "").trim();
        if (!this._roomRow(roomId)) throw new Error("Room not found");
        this.ctx.storage.sql.exec(
          `INSERT INTO owner_room_controls (room_id, banned, background_asset, updated_at)
           VALUES (?, ?, NULL, ?)
           ON CONFLICT(room_id) DO UPDATE SET banned = excluded.banned, updated_at = excluded.updated_at`,
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
          `INSERT INTO owner_room_controls (room_id, banned, background_asset, updated_at)
           VALUES (?, 0, ?, ?)
           ON CONFLICT(room_id) DO UPDATE SET
             background_asset = excluded.background_asset, updated_at = excluded.updated_at`,
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
        order: Number(data.order || data.level || data.vip_level || 1),
        price: Number(data.price || 0),
        requirements: data.requirements || "",
        duration_days: Number(data.duration_days || 0),
        badge: data.badge || "", profile_frame: data.profile_frame || data.frame || "",
        seat_frame: data.seat_frame || "", entry: data.entry || "",
        entry_asset: data.entry_asset || "", entry_audio: data.entry_audio || "",
        privileges: Array.isArray(data.privileges) ? data.privileges : [],
        permissions: Array.isArray(data.permissions) ? data.permissions : [],
        special_effects: Array.isArray(data.special_effects) ? data.special_effects : [],
        countries: Array.isArray(data.countries) ? data.countries : [],
        starts_at: data.starts_at ? Date.parse(String(data.starts_at)) : null,
        ends_at: data.ends_at ? Date.parse(String(data.ends_at)) : null,
      });
      case "gift-new": {
        const lucky = data.lucky === true || String(data.lucky || "").toLowerCase() === "true";
        return this.ownerCatalogCreate("gift", data.name, {
          coin_price: Math.max(0, Number(data.coin_price || 0)),
          duration_days: Math.max(0, Number(data.duration_days || 0)),
          asset_url: String(data.asset_url || ""),
          effect_kind: lucky ? "lucky" : String(data.effect_kind || ""),
          category: lucky ? "Lucky" : String(data.category || ""),
          lucky,
          rebate: lucky,
          emoji: cleanText(data.emoji || (lucky ? "🎁" : ""), 16),
          max_multiplier: lucky
            ? Math.max(1, Math.min(1000, Number(data.max_multiplier || 1000)))
            : 0,
          high_win_multiplier: lucky
            ? Math.max(1, Math.min(1000, Number(data.high_win_multiplier || 200)))
            : 0,
          host_reward_percent: lucky
            ? Math.max(0, Math.min(100, Number(data.host_reward_percent || 10)))
            : 100,
          charm_wealth_percent: lucky
            ? Math.max(0, Math.min(100, Number(data.charm_wealth_percent || 10)))
            : 100,
          prize_pool_percent: lucky
            ? Math.max(0, Math.min(100, Number(data.prize_pool_percent || 2)))
            : 0,
          order: Number(data.order || 0),
          countries: Array.isArray(data.countries) ? data.countries : [],
          starts_at: data.starts_at ? Date.parse(String(data.starts_at)) : null,
          ends_at: data.ends_at ? Date.parse(String(data.ends_at)) : null,
        });
      }
      case "profile-card-new": return this.ownerCatalogCreate("profile_card", data.name, {
        asset_url: String(data.asset_url || ""), price: Math.max(0, Number(data.price || data.coin_price || 0)),
        duration_days: Math.max(0, Number(data.duration_days || 0)), order: Number(data.order || 0),
        countries: Array.isArray(data.countries) ? data.countries : [],
        starts_at: data.starts_at ? Date.parse(String(data.starts_at)) : null,
        ends_at: data.ends_at ? Date.parse(String(data.ends_at)) : null,
      });
      case "vehicle-new":
      case "entry-new":
      case "ring-new":
      case "bubble-new":
      case "profile-background-new": {
        const kindByAction = {
          "vehicle-new": "vehicle",
          "entry-new": "entry",
          "ring-new": "ring",
          "bubble-new": "bubble",
          "profile-background-new": "profile_background",
        };
        return this.ownerCatalogCreate(kindByAction[action], data.name, {
          asset_url: String(data.asset_url || ""),
          price: Math.max(0, Number(data.price || data.coin_price || 0)),
          duration_days: Math.max(0, Number(data.duration_days || 0)),
          order: Number(data.order || 0),
          countries: Array.isArray(data.countries) ? data.countries : [],
          starts_at: data.starts_at ? Date.parse(String(data.starts_at)) : null,
          ends_at: data.ends_at ? Date.parse(String(data.ends_at)) : null,
        });
      }
      case "frame-new": return this.ownerCatalogCreate("frame", data.name, {
        asset_url: String(data.asset_url || ""), vip_level: Number(data.vip_level || 0),
        price: Math.max(0, Number(data.price || data.coin_price || 0)),
        duration_days: Math.max(0, Number(data.duration_days || 0)),
        order: Number(data.order || 0), countries: Array.isArray(data.countries) ? data.countries : [],
        starts_at: data.starts_at ? Date.parse(String(data.starts_at)) : null,
        ends_at: data.ends_at ? Date.parse(String(data.ends_at)) : null,
      });
      case "banner-new": return this.ownerCatalogCreate("banner", data.title || "Banner", {
        asset_url: String(data.asset_url || ""), order: Number(data.order || 0),
        countries: Array.isArray(data.countries) ? data.countries : [],
        starts_at: data.starts_at ? Date.parse(String(data.starts_at)) : Date.now(),
        ends_at: data.ends_at ? Date.parse(String(data.ends_at)) : null,
      });
      case "policy-new":
      case "policy-set": {
        const policies = this.ownerState().policies;
        policies[String(data.key || "").trim()] = data.value;
        return this._setOwnerSetting("policies", policies);
      }
      case "lucky-gift-config": {
        const current = this._luckyGiftConfig();
        const sourceWeights = data.multiplier_weights &&
            typeof data.multiplier_weights === "object"
          ? data.multiplier_weights
          : current.multiplier_weights;
        const multiplierWeights = {};
        for (const [key, value] of Object.entries(sourceWeights || {})) {
          const multiplier = Math.max(
            0,
            Math.min(1000, Math.floor(Number(key) || 0)),
          );
          const weight = Math.max(0, Math.floor(Number(value) || 0));
          if (weight > 0) multiplierWeights[String(multiplier)] = weight;
        }
        if (Object.keys(multiplierWeights).length === 0) {
          throw new Error("Lucky multiplier weights cannot be empty");
        }
        const rankSharesRaw = Array.isArray(data.rank_shares)
          ? data.rank_shares
          : current.rank_shares;
        const rankShares = rankSharesRaw.slice(0, 3).map((value) =>
          Math.max(0, Math.min(100, Math.floor(Number(value) || 0)))
        );
        while (rankShares.length < 3) rankShares.push(0);
        if (rankShares.reduce((sum, value) => sum + value, 0) > 100) {
          throw new Error("Lucky ranking shares cannot total more than 100%");
        }
        const next = {
          enabled: data.enabled === undefined ? current.enabled !== false : data.enabled === true,
          max_multiplier: Math.max(1, Math.min(1000, Math.floor(Number(data.max_multiplier ?? current.max_multiplier ?? 1000)))),
          high_win_multiplier: Math.max(1, Math.min(1000, Math.floor(Number(data.high_win_multiplier ?? current.high_win_multiplier ?? 200)))),
          banner_multiplier: Math.max(1, Math.min(1000, Math.floor(Number(data.banner_multiplier ?? current.banner_multiplier ?? 500)))),
          ultra_banner_multiplier: Math.max(1, Math.min(1000, Math.floor(Number(data.ultra_banner_multiplier ?? current.ultra_banner_multiplier ?? 1000)))),
          host_reward_percent: Math.max(0, Math.min(100, Number(data.host_reward_percent ?? current.host_reward_percent ?? 10))),
          charm_wealth_percent: Math.max(0, Math.min(100, Number(data.charm_wealth_percent ?? current.charm_wealth_percent ?? 10))),
          prize_pool_percent: Math.max(0, Math.min(100, Number(data.prize_pool_percent ?? current.prize_pool_percent ?? 2))),
          rank_shares: rankShares,
          daily_send_cap: Math.max(0, Math.floor(Number(data.daily_send_cap ?? current.daily_send_cap ?? 0))),
          banners_enabled: data.banners_enabled === undefined ? current.banners_enabled !== false : data.banners_enabled === true,
          testing_mode: data.testing_mode === true,
          event_mode: data.event_mode === true,
          multiplier_weights: multiplierWeights,
        };
        if (next.high_win_multiplier > next.max_multiplier ||
            next.banner_multiplier > next.max_multiplier ||
            next.ultra_banner_multiplier > next.max_multiplier) {
          throw new Error("Lucky thresholds cannot exceed the maximum multiplier");
        }
        if (next.banner_multiplier < next.high_win_multiplier) {
          throw new Error("Lucky banner multiplier must be at least the high-win multiplier");
        }
        if (next.ultra_banner_multiplier < next.banner_multiplier) {
          throw new Error("Lucky ultra banner multiplier must be at least the banner multiplier");
        }
        return this._setOwnerSetting("lucky_gift_config", next);
      }
      case "pricing-set": {
        const policies = this.ownerState().policies;
        policies.direct_call_coins = Math.max(0, Number(data.direct_call_coins || 0));
        policies.random_call_coins = Math.max(0, Number(data.random_call_coins || 0));
        policies.receiver_percent = Math.max(0, Math.min(100, Number(data.receiver_percent || 0)));
        policies.room_theme_coins = Math.max(0, Number(data.room_theme_coins || 0));
        policies.cp_connect_coins = Math.max(0, Number(data.cp_connect_coins || 0));
        policies.cp_disconnect_coins = Math.max(0, Number(data.cp_disconnect_coins || 0));
        policies.frame_default_coins = Math.max(0, Number(data.frame_default_coins || 0));
        policies.vip_default_coins = Math.max(0, Number(data.vip_default_coins || 0));
        policies.unique_id_purchase_coins = Math.max(0, Number(data.unique_id_purchase_coins || 0));
        policies.free_user_ids = Array.isArray(data.free_user_ids) ? data.free_user_ids.map(String) : [];
        return this._setOwnerSetting("policies", policies);
      }
      case "user-price-override-set":
        return this.setUserPriceOverride(data.user_id, data.price_key, data.price_coins, data.duration_days, data.expires_at);
      case "user-price-override-remove":
        return this.removeUserPriceOverride(data.user_id, data.price_key);
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
          `SELECT COUNT(*) AS calls, COALESCE(SUM(caller_cost_coins),0) AS spent,
                  COALESCE(SUM(receiver_reward_diamonds),0) AS rewards
             FROM app_calls`,
        ).toArray()[0];
        return {
          sessions: Number(row?.calls || 0), spent_coins: Number(row?.spent || 0),
          reward_diamonds: Number(row?.rewards || 0),
        };
      }
      case "catalog-toggle": return this.ownerCatalogPatch(data.id, { enabled: data.enabled === true });
      case "catalog-edit": return this.ownerCatalogPatch(data.id, data.patch || {});
      case "catalog-remove": {
        const id = String(data.id || "").trim();
        const row = this.ctx.storage.sql.exec("SELECT id, kind FROM owner_catalog WHERE id = ? LIMIT 1", id).toArray()[0];
        if (!row) throw new Error("Catalog item not found");
        this.ctx.storage.sql.exec("DELETE FROM owner_catalog WHERE id = ?", id);
        return { ok: true, id, kind: String(row.kind) };
      }
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

  async bindEmailIdentity(userIdValue, requestIdValue, otpValue, passwordValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId || !(await this.getUserById(userId))) throw new Error("User not found");
    const password = String(passwordValue || "");
    if (password.length < 8 || password.length > 128) {
      throw new Error("Tinni password must be 8 to 128 characters");
    }
    const verified = await this.verifyEmailOtp(requestIdValue, otpValue);
    const email = String(verified.email || "").trim().toLowerCase();
    if (!email) throw new Error("Verified email is required");

    const linked = await this.getUserByProvider("email", email);
    if (linked && String(linked.user_id) !== String(userId)) {
      throw new Error("This email is already linked to another Tinni account");
    }
    const credential = this.ctx.storage.sql.exec(
      "SELECT user_id,auth_version FROM email_password_credentials WHERE email=? LIMIT 1",
      email,
    ).toArray()[0];
    if (credential && String(credential.user_id) !== String(userId)) {
      throw new Error("This email is already used by another Tinni account");
    }

    await this.linkIdentity(userId, "email", email);
    const salt = crypto.getRandomValues(new Uint8Array(16));
    const hash = await deriveSecret(password, salt, 210000);
    const now = Date.now();
    const nextVersion = Math.max(1, Number(credential?.auth_version || 0) + 1);
    this.ctx.storage.sql.exec(
      `INSERT INTO email_password_credentials
        (email,user_id,password_salt,password_hash,auth_version,created_at,updated_at)
       VALUES (?,?,?,?,?,?,?)
       ON CONFLICT(email) DO UPDATE SET
         user_id=excluded.user_id,
         password_salt=excluded.password_salt,
         password_hash=excluded.password_hash,
         auth_version=excluded.auth_version,
         updated_at=excluded.updated_at`,
      email,userId,toBase64Url(salt),toBase64Url(hash),nextVersion,now,now,
    );
    return {
      ok:true,
      email,
      identities:this.accountIdentities(userId),
    };
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
      medals: this.listUserMedals(userId),
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
    if (
      avatarDataUrl &&
      !avatarDataUrl.startsWith("data:image/") &&
      !avatarDataUrl.startsWith("https://")
    ) {
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
       VALUES (?, 0, 0, ?)`,
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

  async updateUserProfile(userIdValue, input) {
    const userId = String(userIdValue || "").trim();
    const current = await this.getUserById(userId);
    if (!current) throw new Error("User not found");

    const displayName = input?.display_name === undefined
      ? current.display_name : cleanText(input.display_name, 40);
    let birthday = input?.birthday === undefined
      ? (current.birthday || null)
      : cleanText(input.birthday, 10);
    let age = Number(current.age || 0);
    if (birthday) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(birthday)) {
        throw new Error("Birthday must use YYYY-MM-DD");
      }
      const parsed = new Date(birthday + "T00:00:00Z");
      if (!Number.isFinite(parsed.getTime())) {
        throw new Error("Birthday is invalid");
      }
      const nowDate = new Date();
      age = nowDate.getUTCFullYear() - parsed.getUTCFullYear();
      const beforeBirthday =
        nowDate.getUTCMonth() < parsed.getUTCMonth() ||
        (nowDate.getUTCMonth() === parsed.getUTCMonth() &&
          nowDate.getUTCDate() < parsed.getUTCDate());
      if (beforeBirthday) age -= 1;
      if (age < 18 || age > 100) {
        throw new Error("Age must be between 18 and 100");
      }
    }
    const signature = input?.signature === undefined
      ? current.signature : cleanText(input.signature, 3000);
    const countryCode = input?.country_code === undefined
      ? current.country_code : cleanText(input.country_code, 2).toUpperCase();
    const countryName = input?.country_name === undefined
      ? current.country_name : cleanText(input.country_name, 80);
    const flagEmoji = input?.flag_emoji === undefined
      ? current.flag_emoji : cleanText(input.flag_emoji, 16);
    const gender = input?.gender === undefined
      ? current.gender : cleanText(input.gender, 12).toLowerCase();
    const avatarDataUrl = input?.avatar_data_url === undefined
      ? current.avatar_data_url
      : (input.avatar_data_url ? String(input.avatar_data_url) : null);

    if (!displayName) throw new Error("Name is required");
    if (wordCount(signature) > 150) throw new Error("Signature can contain at most 150 words");
    if (!countryCode || !countryName || !flagEmoji) throw new Error("Country and flag are required");
    if (!VALID_GENDERS.has(gender)) throw new Error("Gender must be male or female");
    if (avatarDataUrl && avatarDataUrl.length > MAX_AVATAR_DATA_LENGTH) {
      throw new Error("Profile photo is too large");
    }
    if (avatarDataUrl && !avatarDataUrl.startsWith("data:image/")) {
      throw new Error("Profile photo format is invalid");
    }

    this.ctx.storage.sql.exec(
      `UPDATE app_users
          SET display_name = ?, age = ?, birthday = ?, signature = ?,
              country_code = ?, country_name = ?, flag_emoji = ?, gender = ?,
              avatar_data_url = ?, updated_at = ?
        WHERE user_id = ?`,
      displayName, age, birthday, signature, countryCode, countryName,
      flagEmoji, gender, avatarDataUrl, Date.now(), userId,
    );
    return this.getUserById(userId);
  }

  revokeSession(tokenHashValue, expiresAtValue) {
    const tokenHash = String(tokenHashValue || "").trim();
    const expiresAt = Number(expiresAtValue || 0);
    if (!tokenHash || !Number.isFinite(expiresAt)) throw new Error("Valid session is required");
    const now = Date.now();
    this.ctx.storage.sql.exec("DELETE FROM app_session_revocations WHERE expires_at <= ?", now);
    this.ctx.storage.sql.exec(
      `INSERT INTO app_session_revocations (token_hash, expires_at, revoked_at)
       VALUES (?, ?, ?)
       ON CONFLICT(token_hash) DO UPDATE SET expires_at = excluded.expires_at, revoked_at = excluded.revoked_at`,
      tokenHash, expiresAt, now,
    );
    return { ok: true };
  }

  isSessionRevoked(tokenHashValue) {
    const tokenHash = String(tokenHashValue || "").trim();
    if (!tokenHash) return false;
    const now = Date.now();
    this.ctx.storage.sql.exec("DELETE FROM app_session_revocations WHERE expires_at <= ?", now);
    return Boolean(this.ctx.storage.sql.exec(
      "SELECT token_hash FROM app_session_revocations WHERE token_hash = ? LIMIT 1", tokenHash,
    ).toArray()[0]);
  }

  findRoomByExactId(roomIdValue) {
    const roomId = String(roomIdValue || "").trim();
    if (!roomId) return null;
    const row = this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name,
              u.avatar_data_url AS owner_avatar_data_url,
              u.flag_emoji AS owner_flag_emoji,
              COALESCE(pc.member_count, 0) AS member_count
         FROM app_rooms r
         JOIN app_users u ON u.user_id = r.owner_id
         LEFT JOIN app_room_presence_counts pc ON pc.room_id = r.id
        WHERE r.id = ?
          AND COALESCE(r.closed, 0) = 0
        LIMIT 1`,
      roomId,
    ).toArray()[0];
    return row ? rowToRoom(row) : null;
  }

  findUserByExactPublicId(publicIdValue) {
    const raw = String(publicIdValue || "").trim();
    if (!raw) return null;
    const direct = this.ctx.storage.sql.exec(
      `SELECT u.user_id, u.display_name, u.signature, u.country_code,
              u.country_name, u.flag_emoji, u.gender, u.avatar_data_url,
              p.room_id AS active_room_id, p.last_seen
         FROM app_users u
         LEFT JOIN app_user_presence p ON p.user_id = u.user_id
        WHERE LOWER(u.user_id) = LOWER(?)
        LIMIT 1`,
      raw,
    ).toArray()[0];

    let row = direct;
    if (!row) {
      const history = this.ctx.storage.sql.exec(
        "SELECT new_user_id FROM user_id_history WHERE LOWER(old_user_id) = LOWER(?) LIMIT 1",
        raw,
      ).toArray()[0];
      if (history) {
        row = this.ctx.storage.sql.exec(
          `SELECT u.user_id, u.display_name, u.signature, u.country_code,
                  u.country_name, u.flag_emoji, u.gender, u.avatar_data_url,
                  p.room_id AS active_room_id, p.last_seen
             FROM app_users u
             LEFT JOIN app_user_presence p ON p.user_id = u.user_id
            WHERE u.user_id = ?
            LIMIT 1`,
          String(history.new_user_id),
        ).toArray()[0];
      }
    }
    if (!row) return null;
    const now = Date.now();
    const onlineCutoff = now - 90000;
    return {
      user_id: String(row.user_id),
      display_name: String(row.display_name),
      signature: String(row.signature || ""),
      country_code: String(row.country_code || ""),
      country_name: String(row.country_name || ""),
      flag_emoji: String(row.flag_emoji || ""),
      gender: String(row.gender || ""),
      avatar_data_url: row.avatar_data_url ? String(row.avatar_data_url) : null,
      online: row.last_seen != null && Number(row.last_seen) >= onlineCutoff,
      active_room_id:
        row.last_seen != null &&
        Number(row.last_seen) >= onlineCutoff &&
        row.active_room_id
          ? String(row.active_room_id)
          : null,
    };
  }

  searchUsers(queryValue, limitValue = 30) {
    const query = cleanText(queryValue, 80);
    if (!query) return [];
    const limit = Math.max(1, Math.min(50, Number(limitValue) || 30));
    const exact = this._resolveOwnerUserId(query);
    const like = "%" + query.replaceAll("%", "\\%").replaceAll("_", "\\_") + "%";
    const now = Date.now();
    const onlineCutoff = now - 90000;
    return this.ctx.storage.sql.exec(
      `SELECT u.user_id, u.display_name, u.signature, u.country_code,
              u.country_name, u.flag_emoji, u.gender, u.avatar_data_url,
              p.room_id AS active_room_id, p.last_seen
         FROM app_users u
         LEFT JOIN app_user_presence p ON p.user_id = u.user_id
        WHERE u.user_id = ? OR u.display_name LIKE ? ESCAPE '\\'
        ORDER BY CASE WHEN u.user_id = ? THEN 0 ELSE 1 END, u.display_name ASC
        LIMIT ?`,
      exact, like, exact, limit,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      display_name: String(row.display_name),
      signature: String(row.signature || ""),
      country_code: String(row.country_code || ""),
      country_name: String(row.country_name || ""),
      flag_emoji: String(row.flag_emoji || ""),
      gender: String(row.gender || ""),
      avatar_data_url: row.avatar_data_url ? String(row.avatar_data_url) : null,
      online: row.last_seen != null && Number(row.last_seen) >= onlineCutoff,
      active_room_id:
        row.last_seen != null && Number(row.last_seen) >= onlineCutoff && row.active_room_id
          ? String(row.active_room_id) : null,
    }));
  }

  listFollowers(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return [];
    return this.ctx.storage.sql.exec(
      `SELECT u.user_id, u.display_name, u.avatar_data_url
         FROM app_follows f
         JOIN app_users u ON u.user_id = f.follower_id
        WHERE f.target_id = ?
        ORDER BY f.created_at DESC`,
      userId,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      display_name: String(row.display_name || row.user_id),
      avatar_data_url: row.avatar_data_url ? String(row.avatar_data_url) : null,
    }));
  }

  touchPresence(userIdValue, roomIdValue, memberCountValue = null) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    if (!userId) throw new Error("user_id is required");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO app_user_presence (user_id, room_id, last_seen)
       VALUES (?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET room_id = excluded.room_id, last_seen = excluded.last_seen`,
      userId, roomId || null, now,
    );
    if (roomId && memberCountValue !== null && memberCountValue !== undefined) {
      const count = Math.max(0, Number(memberCountValue) || 0);
      this.ctx.storage.sql.exec(
        `INSERT INTO app_room_presence_counts (room_id, member_count, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT(room_id) DO UPDATE SET member_count = excluded.member_count, updated_at = excluded.updated_at`,
        roomId, count, now,
      );
    }
    return { ok: true, online: true, room_id: roomId || null, last_seen: now };
  }

  recordRoomRealtimeEvent(userIdValue, input = {}) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const roomId = String(input.room_id || "").trim();
    const event = input.event && typeof input.event === "object"
      ? input.event
      : {};
    const eventType = cleanText(event.type, 60);
    if (!userId || !roomId || !eventType) {
      throw new Error("room_id and event.type are required");
    }
    const allowedTypes = new Set([
      "mic_state",
      "seat_state",
      "room_state",
      "emote",
    ]);
    if (!allowedTypes.has(eventType)) {
      throw new Error("Unsupported room realtime event");
    }

    const room = this.ctx.storage.sql.exec(
      "SELECT id,closed FROM app_rooms WHERE id=? LIMIT 1",
      roomId,
    ).toArray()[0];
    if (!room || Number(room.closed || 0) === 1) {
      throw new Error("Room is unavailable");
    }
    const presence = this.ctx.storage.sql.exec(
      "SELECT room_id,last_seen FROM app_user_presence WHERE user_id=? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!presence || String(presence.room_id || "") !== roomId ||
        Date.now() - Number(presence.last_seen || 0) > 120000) {
      throw new Error("You must be active inside this room");
    }

    this._enforceActionRate(userId, "room_realtime_event", 120, 60000, 60000);
    const normalized = {
      ...event,
      type: eventType,
      userId,
    };
    const eventJson = JSON.stringify(normalized);
    if (eventJson.length > 4000) throw new Error("Room event is too large");

    const id = "room-event-" + crypto.randomUUID();
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT INTO room_realtime_events(id,room_id,user_id,event_type,event_json,created_at) VALUES (?,?,?,?,?,?)",
      id, roomId, userId, eventType, eventJson, now,
    );
    // Keep bounded history because these events are transient coordination data.
    this.ctx.storage.sql.exec(
      `DELETE FROM room_realtime_events
        WHERE room_id=?
          AND id NOT IN (
            SELECT id FROM room_realtime_events
             WHERE room_id=?
             ORDER BY created_at DESC
             LIMIT 500
          )`,
      roomId, roomId,
    );
    return {
      ok: true,
      id,
      room_id: roomId,
      user_id: userId,
      event_type: eventType,
      created_at: now,
    };
  }

  clearPresence(userIdValue, roomIdValue, memberCountValue = null) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    if (userId) this.ctx.storage.sql.exec("DELETE FROM app_user_presence WHERE user_id = ?", userId);
    if (roomId && memberCountValue !== null && memberCountValue !== undefined) {
      const now = Date.now();
      const count = Math.max(0, Number(memberCountValue) || 0);
      this.ctx.storage.sql.exec(
        `INSERT INTO app_room_presence_counts (room_id, member_count, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT(room_id) DO UPDATE SET member_count = excluded.member_count, updated_at = excluded.updated_at`,
        roomId, count, now,
      );
    }
    return { ok: true, online: false };
  }

  markRecentRoom(userIdValue, roomIdValue) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    if (!userId || !roomId) throw new Error("user_id and room_id are required");
    const exists = this.ctx.storage.sql.exec("SELECT id FROM app_rooms WHERE id = ? LIMIT 1", roomId).toArray()[0];
    if (!exists) throw new Error("Room not found");
    this.ctx.storage.sql.exec(
      `INSERT INTO app_recent_rooms (user_id, room_id, visited_at)
       VALUES (?, ?, ?)
       ON CONFLICT(user_id, room_id) DO UPDATE SET visited_at = excluded.visited_at`,
      userId, roomId, Date.now(),
    );
    const overflow = this.ctx.storage.sql.exec(
      `SELECT room_id FROM app_recent_rooms WHERE user_id = ?
        ORDER BY visited_at DESC LIMIT -1 OFFSET 25`, userId,
    ).toArray();
    for (const row of overflow) {
      this.ctx.storage.sql.exec(
        "DELETE FROM app_recent_rooms WHERE user_id = ? AND room_id = ?",
        userId, row.room_id,
      );
    }
    return { ok: true };
  }

  listFollowedOnlineRooms(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return [];
    const cutoff = Date.now() - 90000;
    return this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name,
              u.avatar_data_url AS owner_avatar_data_url,
              u.flag_emoji AS owner_flag_emoji,
              COALESCE(pc.member_count, 0) AS member_count
         FROM app_follows f
         JOIN app_rooms r ON r.owner_id = f.target_id
         JOIN app_users u ON u.user_id = r.owner_id
         JOIN app_user_presence p ON p.user_id = r.owner_id
         LEFT JOIN app_room_presence_counts pc ON pc.room_id = r.id
        WHERE f.follower_id = ?
          AND p.room_id = r.id
          AND p.last_seen >= ?
          AND COALESCE(r.closed, 0) = 0
        ORDER BY p.last_seen DESC
        LIMIT 100`,
      userId,
      cutoff,
    ).toArray().map(rowToRoom);
  }

  listRecentRooms(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return [];
    return this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name,
              u.avatar_data_url AS owner_avatar_data_url,
              u.flag_emoji AS owner_flag_emoji,
              COALESCE(pc.member_count, 0) AS member_count
         FROM app_recent_rooms rr
         JOIN app_rooms r ON r.id = rr.room_id
         JOIN app_users u ON u.user_id = r.owner_id
         LEFT JOIN app_room_presence_counts pc ON pc.room_id = r.id
        WHERE rr.user_id = ?
        ORDER BY rr.visited_at DESC
        LIMIT 25`,
      userId,
    ).toArray().map(rowToRoom);
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

  listBlockedProfiles(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) return [];
    return this.ctx.storage.sql.exec(
      `SELECT u.user_id,u.display_name,u.avatar_data_url,u.flag_emoji,b.created_at
         FROM app_blocks b
         JOIN app_users u ON u.user_id=b.target_id
        WHERE b.blocker_id=?
        ORDER BY b.created_at DESC`, userId,
    ).toArray().map((row)=>({
      user_id:String(row.user_id),
      display_name:String(row.display_name || row.user_id),
      avatar_data_url:row.avatar_data_url ? String(row.avatar_data_url) : null,
      flag_emoji:String(row.flag_emoji || ""),
      blocked_at:Number(row.created_at || 0),
    }));
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

  roomFollowState(roomIdValue, userIdValue) {
    const roomId=String(roomIdValue||"").trim(), userId=String(userIdValue||"").trim();
    if(!this._roomRow(roomId)) throw new Error("Room not found");
    const following=userId ? Boolean(this.ctx.storage.sql.exec(
      "SELECT 1 AS yes FROM room_follows WHERE room_id=? AND user_id=? LIMIT 1",roomId,userId,
    ).toArray()[0]) : false;
    const total=Number(this.ctx.storage.sql.exec(
      "SELECT COUNT(*) AS count FROM room_follows WHERE room_id=?",roomId,
    ).toArray()[0]?.count||0);
    const present=Number(this.ctx.storage.sql.exec(
      `SELECT COUNT(*) AS count FROM room_follows f
         JOIN app_user_presence p ON p.user_id=f.user_id
         WHERE f.room_id=? AND p.room_id=? AND p.last_seen>=?`,
      roomId,roomId,Date.now()-120000,
    ).toArray()[0]?.count||0);
    return {room_id:roomId,following,follower_count:total,present_follower_count:present};
  }

  setRoomFollow(userIdValue,roomIdValue,enabledValue){
    const userId=String(userIdValue||"").trim(),roomId=String(roomIdValue||"").trim();
    if(!userId||!roomId)throw new Error("room_id and user are required");
    if(!this._roomRow(roomId))throw new Error("Room not found");
    if(enabledValue)this.ctx.storage.sql.exec(
      "INSERT INTO room_follows(room_id,user_id,created_at) VALUES(?,?,?) ON CONFLICT(room_id,user_id) DO UPDATE SET created_at=excluded.created_at",
      roomId,userId,Date.now(),
    );
    else {
      this.ctx.storage.sql.exec("DELETE FROM room_follows WHERE room_id=? AND user_id=?",roomId,userId);
      this.ctx.storage.sql.exec("DELETE FROM room_memberships WHERE room_id=? AND user_id=?",roomId,userId);
    }
    return {ok:true,...this.roomFollowState(roomId,userId),membership:this.roomMembershipState(roomId,userId)};
  }

  roomMembershipState(roomIdValue, userIdValue) {
    const roomId = String(roomIdValue || "").trim();
    const userId = String(userIdValue || "").trim();
    const room = this._roomRow(roomId);
    if (!room) throw new Error("Room not found");
    const levelSetting = this.ctx.storage.sql.exec(
      "SELECT value_json FROM owner_settings WHERE key = 'room_member_limits' LIMIT 1"
    ).toArray()[0];
    let limits = { "1": 10 };
    try { limits = { ...limits, ...JSON.parse(String(levelSetting?.value_json || "{}")) }; } catch {}
    const level = Math.max(1, Number(room.room_level || 1));
    const configuredLimit = Number(limits[String(level)]);
    const memberLimit = Number.isInteger(configuredLimit) && configuredLimit > 0
      ? configuredLimit
      : (level === 1 ? 10 : null);
    const countRow = this.ctx.storage.sql.exec(
      "SELECT COUNT(*) AS count FROM room_memberships WHERE room_id = ?", roomId,
    ).toArray()[0];
    const membership = userId ? this.ctx.storage.sql.exec(
      "SELECT 1 AS yes FROM room_memberships WHERE room_id = ? AND user_id = ? LIMIT 1", roomId, userId,
    ).toArray()[0] : null;
    return {
      room_id: roomId,
      room_level: level,
      member_count: Number(countRow?.count || 0),
      member_limit: memberLimit,
      is_member: Boolean(membership),
    };
  }

  setRoomMembership(userIdValue, roomIdValue, enabledValue) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    if (!userId || !roomId) throw new Error("room_id and user are required");
    if (!this.getUserById(userId)) throw new Error("User not found");
    const state = this.roomMembershipState(roomId, userId);
    if (enabledValue) {
      if (!this.roomFollowState(roomId, userId).following) throw new Error("Follow the room before becoming a member");
      if (!state.is_member && state.member_limit != null && state.member_count >= state.member_limit) {
        throw new Error("Room member limit reached");
      }
      this.ctx.storage.sql.exec(
        "INSERT INTO room_memberships (room_id,user_id,joined_at) VALUES (?,?,?) ON CONFLICT(room_id,user_id) DO NOTHING",
        roomId, userId, Date.now(),
      );
    } else {
      this.ctx.storage.sql.exec(
        "DELETE FROM room_memberships WHERE room_id = ? AND user_id = ?", roomId, userId,
      );
    }
    return { ok: true, ...this.roomMembershipState(roomId, userId) };
  }

  isRoomMember(roomIdValue, userIdValue) {
    const roomId = String(roomIdValue || "").trim();
    const userId = String(userIdValue || "").trim();
    if (!roomId || !userId) return false;
    return Boolean(this.ctx.storage.sql.exec(
      "SELECT 1 AS yes FROM room_memberships WHERE room_id = ? AND user_id = ? LIMIT 1", roomId, userId,
    ).toArray()[0]);
  }

  roomGiftRanking(roomIdValue, periodValue = "day") {
    const roomId = String(roomIdValue || "").trim();
    const period = ["day","week","month"].includes(String(periodValue)) ? String(periodValue) : "day";
    if (!roomId) throw new Error("room_id is required");
    const now = new Date();
    let start;
    if (period === "day") start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    else if (period === "week") {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const delta = (d.getDay() + 6) % 7;
      d.setDate(d.getDate() - delta); start = d.getTime();
    } else start = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
    const rows = this.ctx.storage.sql.exec(
      `SELECT g.sender_id, SUM(g.total_cost) AS sending, u.display_name, u.avatar_data_url
         FROM gift_transactions g
         LEFT JOIN app_users u ON u.user_id = g.sender_id
         WHERE g.room_id = ? AND g.created_at >= ?
         GROUP BY g.sender_id, u.display_name, u.avatar_data_url
         ORDER BY sending DESC, g.sender_id ASC LIMIT 100`, roomId, start,
    ).toArray();
    const lifetimeRow = this.ctx.storage.sql.exec(
      "SELECT COALESCE(SUM(total_cost), 0) AS total FROM gift_transactions WHERE room_id = ?",
      roomId,
    ).toArray()[0];
    return {
      ok: true, room_id: roomId, period,
      lifetime_total: Math.max(0, Number(lifetimeRow?.total || 0)),
      ranking: rows.map((row, index) => ({
        rank: index + 1, user_id: String(row.sender_id),
        name: String(row.display_name || row.sender_id),
        avatar_data_url: row.avatar_data_url ? String(row.avatar_data_url) : null,
        sending: Number(row.sending || 0),
      })),
    };
  }

  createLuckyPouch(userIdValue, input = {}) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(input.room_id || "").trim();
    const slots = Number(input.users);
    const totalCoins = Number(input.coins);
    const allowed = {
      5: [100000,500000,1000000,2000000,5000000,8000000,10000000],
      20:[100000,500000,1000000,2000000,5000000,8000000,10000000],
      50:[500000,1000000,2000000,5000000,8000000,10000000],
      100:[1000000,2000000,5000000,8000000,10000000],
      200:[1000000,2000000,5000000,8000000,10000000],
      500:[2000000,5000000,8000000,10000000],
    };
    if (!allowed[slots]?.includes(totalCoins)) throw new Error("Invalid Lucky Pouch users/coins combination");
    const room = this._roomRow(roomId);
    if (!room || Number(room.closed || 0) === 1) throw new Error("Room is unavailable");
    const wallet = this.getWallet(userId);
    if (wallet.banned || wallet.coins < totalCoins) throw new Error("Not enough coins");
    const now = Date.now();
    const id = "lp-" + crypto.randomUUID();
    this.ctx.storage.sql.exec("UPDATE app_wallets SET coins = coins - ?, updated_at = ? WHERE user_id = ?", totalCoins, now, userId);
    this.ctx.storage.sql.exec(
      "INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?,?,?,?,?,?,?)",
      "wallet-" + crypto.randomUUID(), userId, "lucky_pouch_open", -totalCoins, 0, id, "Lucky Pouch", now,
    );
    this.ctx.storage.sql.exec(
      "INSERT INTO lucky_pouches (id,room_id,creator_id,country_code,total_coins,total_slots,remaining_coins,remaining_slots,created_at,completed_at) VALUES (?,?,?,?,?,?,?,?,?,NULL)",
      id, roomId, userId, String(room.country_code || ""), totalCoins, slots, totalCoins, slots, now,
    );
    if (totalCoins >= 500000) {
      const user = this.getUserById(userId);
      this.ctx.storage.sql.exec(
        "INSERT INTO country_ribbons (id,country_code,kind,priority,room_id,user_id,user_name,avatar_data_url,amount,game_key,created_at,expires_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
        "ribbon-" + crypto.randomUUID(), String(room.country_code || ""), "lp", 2, roomId, userId,
        String(user?.display_name || userId), user?.avatar_data_url || null, totalCoins, null, now, now + 120000,
      );
    }
    return { ok: true, pouch: this.luckyPouchState(roomId, userId), wallet: this.getWallet(userId) };
  }

  luckyPouchState(roomIdValue, userIdValue) {
    const roomId = String(roomIdValue || "").trim();
    const userId = String(userIdValue || "").trim();
    const row = this.ctx.storage.sql.exec(
      "SELECT * FROM lucky_pouches WHERE room_id = ? AND completed_at IS NULL AND remaining_slots > 0 AND remaining_coins > 0 ORDER BY created_at DESC LIMIT 1", roomId,
    ).toArray()[0];
    if (!row) return null;
    const claimed = userId ? Boolean(this.ctx.storage.sql.exec(
      "SELECT 1 AS yes FROM lucky_pouch_claims WHERE pouch_id = ? AND user_id = ? LIMIT 1", row.id, userId,
    ).toArray()[0]) : false;
    return { ...row, total_coins:Number(row.total_coins), total_slots:Number(row.total_slots), remaining_coins:Number(row.remaining_coins), remaining_slots:Number(row.remaining_slots), created_at:Number(row.created_at), claimed };
  }

  claimLuckyPouch(userIdValue, roomIdValue) {
    const userId = String(userIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    const pouch = this.luckyPouchState(roomId, userId);
    if (!pouch) return { ok:false, finished:true, message:"Next Time" };
    if (pouch.claimed) throw new Error("Lucky Pouch already claimed");
    const remainingCoins = Number(pouch.remaining_coins);
    const remainingSlots = Number(pouch.remaining_slots);
    let coins = remainingCoins;
    if (remainingSlots > 1) {
      const max = Math.max(1, remainingCoins - (remainingSlots - 1));
      const random = crypto.getRandomValues(new Uint32Array(1))[0];
      coins = 1 + (random % max);
    }
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT INTO lucky_pouch_claims (pouch_id,user_id,coins,claimed_at) VALUES (?,?,?,?)",
      pouch.id, userId, coins, now,
    );
    const nextCoins = remainingCoins - coins;
    const nextSlots = remainingSlots - 1;
    const complete = nextSlots <= 0 || nextCoins <= 0;
    this.ctx.storage.sql.exec(
      "UPDATE lucky_pouches SET remaining_coins=?, remaining_slots=?, completed_at=? WHERE id=?",
      nextCoins, nextSlots, complete ? now : null, pouch.id,
    );
    this._creditNormalWalletAuthorized(userId, coins, "lucky_pouch_redistribution");
    this.ctx.storage.sql.exec(
      "INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?,?,?,?,?,?,?)",
      "wallet-" + crypto.randomUUID(), userId, "lucky_pouch_claim", coins, 0, String(pouch.id)+":"+userId, "Lucky Pouch claim", now,
    );
    return { ok:true, coins, finished:complete, remaining_slots:nextSlots, wallet:this.getWallet(userId) };
  }

  countryRibbons(countryCodeValue) {
    const countryCode = String(countryCodeValue || "").trim().toUpperCase();
    if (!countryCode) return [];
    const now = Date.now();
    this.ctx.storage.sql.exec("DELETE FROM country_ribbons WHERE expires_at <= ?", now);
    return this.ctx.storage.sql.exec(
      "SELECT * FROM country_ribbons WHERE country_code = ? AND expires_at > ? ORDER BY priority DESC, created_at ASC LIMIT 50",
      countryCode, now,
    ).toArray().map((row)=>({ ...row, priority:Number(row.priority), amount:Number(row.amount), created_at:Number(row.created_at), expires_at:Number(row.expires_at) }));
  }

  recordGameWinning(userIdValue, roomIdValue, gameKeyValue, amountValue) {
    const userId=String(userIdValue||"").trim(), roomId=String(roomIdValue||"").trim();
    const gameKey=cleanText(gameKeyValue,80), amount=Number(amountValue);
    if (!userId || !roomId || !gameKey || !Number.isSafeInteger(amount) || amount < 1000000) return null;
    const room=this._roomRow(roomId); if(!room) return null;
    const user=this.getUserById(userId); const now=Date.now();
    const id="ribbon-"+crypto.randomUUID();
    this.ctx.storage.sql.exec(
      "INSERT INTO country_ribbons (id,country_code,kind,priority,room_id,user_id,user_name,avatar_data_url,amount,game_key,created_at,expires_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
      id,String(room.country_code||""),"game",1,roomId,userId,String(user?.display_name||userId),user?.avatar_data_url||null,amount,gameKey,now,now+120000,
    );
    return { id, kind:"game", room_id:roomId, amount, game_key:gameKey };
  }

  _indiaGiftDayKey(timestamp = Date.now()) {
    const shifted = new Date(Number(timestamp) + 19800000);
    return shifted.toISOString().slice(0, 10);
  }

  _nextIndiaMidnightUtc(timestamp = Date.now()) {
    const shifted = new Date(Number(timestamp) + 19800000);
    const nextShiftedMidnight = Date.UTC(
      shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate() + 1,
    );
    return nextShiftedMidnight - 19800000;
  }

  _recordRoomGiftSending(room, totalCoins, timestamp = Date.now()) {
    const coins = Math.max(0, Math.floor(Number(totalCoins || 0)));
    if (!room || coins <= 0) return;
    const roomId = String(room.id || "").trim();
    const ownerId = String(room.owner_id || "").trim();
    if (!roomId || !ownerId) return;
    const dayKey = this._indiaGiftDayKey(timestamp);
    this.ctx.storage.sql.exec(
      `INSERT INTO room_gift_owner_daily
        (room_id,owner_id,day_key,gift_coins,owner_share_coins,settled_at)
       VALUES (?,?,?, ?,0,NULL)
       ON CONFLICT(room_id,day_key) DO UPDATE SET
         gift_coins = room_gift_owner_daily.gift_coins + excluded.gift_coins,
         owner_id = excluded.owner_id`,
      roomId, ownerId, dayKey, coins,
    );
    this.ctx.storage.setAlarm(this._nextIndiaMidnightUtc(timestamp));
  }

  settleRoomGiftOwnerShares(timestamp = Date.now()) {
    const today = this._indiaGiftDayKey(timestamp);
    const rows = this.ctx.storage.sql.exec(
      "SELECT room_id,owner_id,day_key,gift_coins FROM room_gift_owner_daily WHERE settled_at IS NULL AND day_key < ? ORDER BY day_key ASC",
      today,
    ).toArray();
    let settled = 0;
    let credited = 0;
    for (const row of rows) {
      const giftCoins = Math.max(0, Math.floor(Number(row.gift_coins || 0)));
      const share = Math.floor(giftCoins * 0.10);
      const ownerId = String(row.owner_id || "");
      const reference = "room-gift-share:" + String(row.room_id) + ":" + String(row.day_key);
      const existing = this.ctx.storage.sql.exec(
        "SELECT id FROM wallet_transactions WHERE user_id = ? AND reference_id = ? LIMIT 1",
        ownerId, reference,
      ).toArray()[0];
      if (!existing && share > 0) {
        this.ctx.storage.sql.exec(
          "INSERT OR IGNORE INTO app_wallets (user_id,coins,diamonds,updated_at) VALUES (?,0,0,?)",
          ownerId, timestamp,
        );
        this._creditNormalWalletAuthorized(ownerId, share, "room_commission");
        this.ctx.storage.sql.exec(
          "INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?, 'room_gift_owner_share',?,0,?,?,?)",
          crypto.randomUUID(), ownerId, share, reference, "10% daily Gift Box sending share", timestamp,
        );
        this._notifyUser(
          ownerId,
          "room_commission",
          "Room commission credited",
          share.toLocaleString("en-US") + " coins added as 10% room gift commission.",
          { metadata: { room_id: String(row.room_id), day_key: String(row.day_key), commission_coins: share } },
        );
        credited += share;
      }
      this.ctx.storage.sql.exec(
        "UPDATE room_gift_owner_daily SET owner_share_coins = ?, settled_at = ? WHERE room_id = ? AND day_key = ? AND settled_at IS NULL",
        share, timestamp, row.room_id, row.day_key,
      );
      settled += 1;
    }
    this.ctx.storage.setAlarm(this._nextIndiaMidnightUtc(timestamp));
    return { ok: true, settled_days: settled, credited_coins: credited };
  }

  settleExpiredUniqueIds(timestamp = Date.now()) {
    this._ensureEconomyMigrations();
    const rows = this.ctx.storage.sql.exec(
      "SELECT public_id,assigned_user_id,previous_user_id FROM owner_unique_ids WHERE assigned_user_id IS NOT NULL AND expires_at IS NOT NULL AND expires_at <= ?",
      timestamp,
    ).toArray();
    let released = 0;
    for (const row of rows) {
      const currentId = String(row.assigned_user_id || "");
      const previousId = String(row.previous_user_id || "");
      if (!currentId || !previousId) continue;
      try {
        this._changeUserId(currentId, previousId);
        this.ctx.storage.sql.exec(
          "UPDATE owner_unique_ids SET assigned_user_id=NULL,assigned_at=NULL,expires_at=NULL,previous_user_id=NULL,updated_at=? WHERE public_id=?",
          timestamp, row.public_id,
        );
        released += 1;
      } catch {}
    }
    return released;
  }

  async alarm() {
    const now = Date.now();
    const gifts = this.settleRoomGiftOwnerShares(now);
    const uniqueIdsReleased = this.settleExpiredUniqueIds(now);
    const eventNotifications = this.dispatchEventNotifications(now);
    return {
      ...gifts,
      unique_ids_released: uniqueIdsReleased,
      event_notifications_sent: Number(eventNotifications?.sent || 0),
    };
  }

  recordClientAnalytics(userIdValue, input = {}) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const eventName = cleanText(input.event_name, 80);
    if (!userId || !eventName) throw new Error("event_name is required");
    this._enforceActionRate(userId, "analytics_event", 120, 60000, 60000);
    const properties = input.properties && typeof input.properties === "object"
      ? input.properties
      : {};
    const propertiesJson = JSON.stringify(properties);
    if (propertiesJson.length > 6000) throw new Error("Analytics properties are too large");
    const id = "analytics-" + crypto.randomUUID();
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT INTO client_analytics_events(id,user_id,event_name,properties_json,created_at) VALUES (?,?,?,?,?)",
      id, userId, eventName, propertiesJson, now,
    );
    return { ok: true, id, created_at: now };
  }

  recordClientCrash(userIdValue, input = {}) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const errorText = cleanText(input.error, 2000);
    const stackText = cleanText(input.stack, 12000);
    if (!userId || !errorText) throw new Error("error is required");
    this._enforceActionRate(userId, "crash_report", 20, 60000, 300000);
    const context = input.context && typeof input.context === "object"
      ? input.context
      : {};
    const contextJson = JSON.stringify(context);
    if (contextJson.length > 6000) throw new Error("Crash context is too large");
    const id = "crash-" + crypto.randomUUID();
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT INTO client_crash_reports(id,user_id,error_text,stack_text,context_json,created_at) VALUES (?,?,?,?,?,?)",
      id, userId, errorText, stackText, contextJson, now,
    );
    return { ok: true, id, created_at: now };
  }

  _recordSecurityEvent(userIdValue, actionKeyValue, reasonValue, metadata = {}) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) return;
    this.ctx.storage.sql.exec(
      "INSERT INTO security_events(id,user_id,action_key,reason,metadata_json,created_at) VALUES (?,?,?,?,?,?)",
      "security-" + crypto.randomUUID(),
      userId,
      cleanText(actionKeyValue, 80),
      cleanText(reasonValue, 200),
      JSON.stringify(metadata && typeof metadata === "object" ? metadata : {}),
      Date.now(),
    );
  }

  _enforceActionRate(userIdValue, actionKeyValue, maxActions, windowMs, blockMs = 60000) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const actionKey = cleanText(actionKeyValue, 80);
    if (!userId || !actionKey) throw new Error("Invalid security action");
    const now = Date.now();
    const row = this.ctx.storage.sql.exec(
      "SELECT window_start,action_count,blocked_until FROM security_action_windows WHERE user_id=? AND action_key=? LIMIT 1",
      userId, actionKey,
    ).toArray()[0];

    if (row && Number(row.blocked_until || 0) > now) {
      throw new Error("Too many requests. Try again shortly.");
    }

    const currentStart = Number(row?.window_start || 0);
    const currentCount = Number(row?.action_count || 0);
    if (!row || now - currentStart >= windowMs) {
      this.ctx.storage.sql.exec(
        `INSERT INTO security_action_windows(user_id,action_key,window_start,action_count,blocked_until,updated_at)
         VALUES (?,?,?,1,NULL,?)
         ON CONFLICT(user_id,action_key) DO UPDATE SET
           window_start=excluded.window_start,action_count=1,blocked_until=NULL,updated_at=excluded.updated_at`,
        userId, actionKey, now, now,
      );
      return;
    }

    if (currentCount >= maxActions) {
      const blockedUntil = now + Math.max(1000, Number(blockMs || 60000));
      this.ctx.storage.sql.exec(
        "UPDATE security_action_windows SET blocked_until=?,updated_at=? WHERE user_id=? AND action_key=?",
        blockedUntil, now, userId, actionKey,
      );
      this._recordSecurityEvent(userId, actionKey, "rate_limit", {
        max_actions: maxActions,
        window_ms: windowMs,
        blocked_until: blockedUntil,
      });
      throw new Error("Too many requests. Try again shortly.");
    }

    this.ctx.storage.sql.exec(
      "UPDATE security_action_windows SET action_count=action_count+1,updated_at=? WHERE user_id=? AND action_key=?",
      now, userId, actionKey,
    );
  }

  _luckyGiftConfig() {
    const configured = this._ownerSetting("lucky_gift_config", {});
    const defaults = {
      enabled: true,
      max_multiplier: 1000,
      high_win_multiplier: 200,
      banner_multiplier: 500,
      ultra_banner_multiplier: 1000,
      host_reward_percent: 10,
      charm_wealth_percent: 10,
      prize_pool_percent: 2,
      rank_shares: [50, 25, 15],
      daily_send_cap: 0,
      banners_enabled: true,
      testing_mode: false,
      event_mode: false,
      multiplier_weights: {
        "0": 900000,
        "1": 45000,
        "5": 25000,
        "7": 12000,
        "9": 7000,
        "10": 5000,
        "20": 2500,
        "22": 1800,
        "30": 900,
        "50": 450,
        "75": 320,
        "100": 250,
        "200": 60,
        "250": 20,
        "500": 12,
        "750": 5,
        "1000": 3,
      },
    };
    const merged = configured && typeof configured === "object"
      ? { ...defaults, ...configured }
      : defaults;
    merged.multiplier_weights = configured?.multiplier_weights &&
        typeof configured.multiplier_weights === "object"
      ? configured.multiplier_weights
      : defaults.multiplier_weights;
    return merged;
  }

  _rollLuckyMultiplier(configValue = null) {
    const config = configValue || this._luckyGiftConfig();
    const maxMultiplier = Math.max(1, Math.min(1000, Number(config.max_multiplier || 1000)));
    const weights = config.multiplier_weights && typeof config.multiplier_weights === "object"
      ? config.multiplier_weights
      : {};
    const entries = Object.entries(weights)
      .map(([multiplier, weight]) => ({
        multiplier: Math.max(0, Math.min(maxMultiplier, Math.floor(Number(multiplier) || 0))),
        weight: Math.max(0, Math.floor(Number(weight) || 0)),
      }))
      .filter((entry) => entry.weight > 0);
    const totalWeight = entries.reduce((sum, entry) => sum + entry.weight, 0);
    if (!Number.isSafeInteger(totalWeight) || totalWeight <= 0) return 0;
    const randomValue = crypto.getRandomValues(new Uint32Array(1))[0] % totalWeight;
    let cursor = 0;
    for (const entry of entries) {
      cursor += entry.weight;
      if (randomValue < cursor) return entry.multiplier;
    }
    return 0;
  }

  _settleLuckyGiftPools(nowValue = Date.now()) {
    const now = Number(nowValue || Date.now());
    const currentDay = new Date(now).toISOString().slice(0, 10);
    const config = this._luckyGiftConfig();
    const rawShares = Array.isArray(config.rank_shares) ? config.rank_shares : [50, 25, 15];
    const shares = rawShares.slice(0, 3).map((value) =>
      Math.max(0, Math.min(100, Math.floor(Number(value) || 0)))
    );
    const totalShare = shares.reduce((sum, value) => sum + value, 0);
    if (totalShare > 100) return;

    const pending = this.ctx.storage.sql.exec(
      `SELECT day_key,contributed_coins
         FROM lucky_gift_pool_daily
        WHERE settled_at IS NULL AND day_key < ?
        ORDER BY day_key ASC
        LIMIT 31`,
      currentDay,
    ).toArray();

    for (const pool of pending) {
      const dayKey = String(pool.day_key || "");
      const contributed = Math.max(0, Number(pool.contributed_coins || 0));
      const ranking = this.ctx.storage.sql.exec(
        `SELECT user_id,rebate_coins,sent_coins
           FROM lucky_gift_daily
          WHERE day_key=?
          ORDER BY rebate_coins DESC,sent_coins DESC,updated_at ASC
          LIMIT 3`,
        dayKey,
      ).toArray();
      let distributed = 0;
      ranking.forEach((row, index) => {
        const share = shares[index] || 0;
        const coins = Math.floor(contributed * share / 100);
        if (coins <= 0) return;
        const userId = String(row.user_id || "");
        if (!userId) return;
        this._creditNormalWalletAuthorized(userId, coins, "lucky_daily_pool");
        this.ctx.storage.sql.exec(
          "INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?,?,?,?,?,?,?)",
          "wallet-" + crypto.randomUUID(), userId, "lucky_daily_pool",
          coins, 0, "lucky-pool:" + dayKey,
          "Lucky Day Ranking #" + (index + 1), now,
        );
        this.ctx.storage.sql.exec(
          "INSERT INTO lucky_gift_settlements (id,day_key,rank,user_id,share_percent,coins,created_at) VALUES (?,?,?,?,?,?,?)",
          "settlement-" + crypto.randomUUID(), dayKey, index + 1, userId, share, coins, now,
        );
        distributed += coins;
      });
      if (distributed > 0) {
        this.ctx.storage.sql.exec(
          "UPDATE lucky_gift_pool SET balance=MAX(0,balance-?),updated_at=? WHERE singleton_id=1",
          distributed, now,
        );
      }
      this.ctx.storage.sql.exec(
        "UPDATE lucky_gift_pool_daily SET distributed_coins=?,settled_at=?,updated_at=? WHERE day_key=?",
        distributed, now, now, dayKey,
      );
    }
  }

  luckyGiftState(userIdValue = "") {
    const userId = String(userIdValue || "").trim();
    const now = Date.now();
    this._settleLuckyGiftPools(now);
    const config = this._luckyGiftConfig();
    const dayKey = new Date(now).toISOString().slice(0, 10);
    const poolRow = this.ctx.storage.sql.exec(
      "SELECT balance,updated_at FROM lucky_gift_pool WHERE singleton_id=1 LIMIT 1",
    ).toArray()[0];
    const ranking = this.ctx.storage.sql.exec(
      `SELECT d.user_id,d.sent_count,d.sent_coins,d.rebate_coins,d.highest_multiplier,
              COALESCE(u.display_name,d.user_id) AS display_name,u.avatar_data_url
         FROM lucky_gift_daily d
         LEFT JOIN app_users u ON u.user_id=d.user_id
        WHERE d.day_key=?
        ORDER BY d.rebate_coins DESC,d.sent_coins DESC,d.updated_at ASC
        LIMIT 50`,
      dayKey,
    ).toArray().map((row, index) => ({
      rank: index + 1,
      user_id: String(row.user_id),
      display_name: String(row.display_name || row.user_id),
      avatar_data_url: row.avatar_data_url ? String(row.avatar_data_url) : null,
      sent_count: Number(row.sent_count || 0),
      sent_coins: Number(row.sent_coins || 0),
      rebate_coins: Number(row.rebate_coins || 0),
      highest_multiplier: Number(row.highest_multiplier || 0),
    }));
    const mine = userId
      ? ranking.find((row) => row.user_id === userId) || null
      : null;
    const sessions = userId
      ? this.ctx.storage.sql.exec(
          `SELECT id,room_id,gift_id,gift_name,unit_price,send_count,total_sent_coins,
                  total_rebate_coins,highest_multiplier,started_at,updated_at
             FROM lucky_gift_sessions
            WHERE user_id=?
            ORDER BY updated_at DESC
            LIMIT 20`,
          userId,
        ).toArray().map((row) => ({
          id: String(row.id),
          room_id: String(row.room_id),
          gift_id: String(row.gift_id),
          gift_name: String(row.gift_name),
          unit_price: Number(row.unit_price || 0),
          send_count: Number(row.send_count || 0),
          total_sent_coins: Number(row.total_sent_coins || 0),
          total_rebate_coins: Number(row.total_rebate_coins || 0),
          highest_multiplier: Number(row.highest_multiplier || 0),
          started_at: Number(row.started_at || 0),
          updated_at: Number(row.updated_at || 0),
        }))
      : [];
    const rawShares = Array.isArray(config.rank_shares) ? config.rank_shares : [50, 25, 15];
    const rankShares = rawShares.slice(0, 3).map((value) =>
      Math.max(0, Math.min(100, Math.floor(Number(value) || 0)))
    );
    const shareTotal = rankShares.reduce((sum, value) => sum + value, 0);
    const countdownEndsAt = Date.parse(dayKey + "T00:00:00.000Z") + 86400000;
    return {
      ok: true,
      day_key: dayKey,
      pool_balance: Math.max(0, Number(poolRow?.balance || 0)),
      pool_updated_at: Number(poolRow?.updated_at || 0),
      max_multiplier: Math.max(1, Math.min(1000, Number(config.max_multiplier || 1000))),
      high_win_multiplier: Math.max(1, Number(config.high_win_multiplier || 200)),
      banner_multiplier: Math.max(1, Number(config.banner_multiplier || 500)),
      ultra_banner_multiplier: Math.max(1, Number(config.ultra_banner_multiplier || 1000)),
      visible_daily_rank_shares: rankShares,
      remaining_share_percent: Math.max(0, 100 - shareTotal),
      countdown_ends_at: countdownEndsAt,
      daily_send_cap: Math.max(0, Number(config.daily_send_cap || 0)),
      testing_mode: config.testing_mode === true,
      event_mode: config.event_mode === true,
      ranking,
      mine,
      recent_sessions: sessions,
    };
  }

  sendGift(senderIdValue, input) {
    const senderId = String(senderIdValue || "").trim();
    this._enforceActionRate(senderId, "gift_send", 20, 10000, 60000);
    const roomId = String(input?.room_id || "").trim();
    const giftId = cleanText(input?.gift_id, 80);
    const quantity = Number(input?.quantity || 1);
    const receivers = [...new Set((Array.isArray(input?.receiver_ids) ? input.receiver_ids : [])
      .map((value) => String(value || "").trim()).filter(Boolean))];
    if (!senderId || !roomId || !giftId) throw new Error("Gift details are required");
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > 1000) throw new Error("Invalid gift quantity");

    const catalogRow = this.ctx.storage.sql.exec(
      "SELECT name, data_json, enabled FROM owner_catalog WHERE id = ? AND kind = 'gift' LIMIT 1",
      giftId,
    ).toArray()[0];
    let giftName = "";
    let unitPrice = 0;
    let giftData = {};
    if (catalogRow && Number(catalogRow.enabled || 0) === 1) {
      try { giftData = JSON.parse(String(catalogRow.data_json || "{}")); } catch {}
      giftName = cleanText(catalogRow.name, 80);
      unitPrice = Number(giftData.coin_price ?? giftData.price ?? 0);
    } else {
      const builtIn = {
        rose: { name: "Rose", price: 100 },
        crystal: { name: "Crystal", price: 500 },
        crown: { name: "Crown", price: 1000 },
      }[giftId];
      if (builtIn) {
        giftName = builtIn.name;
        unitPrice = builtIn.price;
      }
    }
    if (!giftName || !Number.isInteger(unitPrice) || unitPrice < 0) {
      throw new Error("Gift is unavailable");
    }
    if (catalogRow) {
      const now = Date.now();
      if ((giftData.starts_at && Number(giftData.starts_at) > now) ||
          (giftData.ends_at && Number(giftData.ends_at) <= now)) {
        throw new Error("Gift is unavailable");
      }
    }

    const isLucky = giftData.lucky === true ||
      giftData.rebate === true ||
      String(giftData.category || "").toLowerCase() === "lucky";
    const luckyConfig = this._luckyGiftConfig();
    if (isLucky && luckyConfig.enabled === false) {
      throw new Error("Lucky gifts are temporarily unavailable");
    }
    if (isLucky) {
      this._settleLuckyGiftPools(Date.now());
    }
    const luckySessionId = isLucky
      ? cleanText(input?.lucky_session_id || ("lucky-session-" + crypto.randomUUID()), 96)
      : "";
    const charmWealthPercent = Math.max(
      0,
      Math.min(100, Number(giftData.charm_wealth_percent ?? luckyConfig.charm_wealth_percent ?? 10)),
    );
    if (isLucky) {
      const dailyCap = Math.max(0, Math.floor(Number(luckyConfig.daily_send_cap || 0)));
      if (dailyCap > 0) {
        const dayKey = new Date().toISOString().slice(0, 10);
        const used = Number(this.ctx.storage.sql.exec(
          "SELECT sent_count FROM lucky_gift_daily WHERE day_key=? AND user_id=? LIMIT 1",
          dayKey, senderId,
        ).toArray()[0]?.sent_count || 0);
        if (used + quantity * receivers.length > dailyCap) {
          throw new Error("Lucky Gift daily send cap reached");
        }
      }
      const existingSession = this.ctx.storage.sql.exec(
        "SELECT user_id,room_id,gift_id FROM lucky_gift_sessions WHERE id=? LIMIT 1",
        luckySessionId,
      ).toArray()[0];
      if (existingSession &&
          (String(existingSession.user_id) !== senderId ||
           String(existingSession.room_id) !== roomId ||
           String(existingSession.gift_id) !== giftId)) {
        throw new Error("Invalid Lucky Gift session");
      }
    }

    if (receivers.length < 1 || receivers.length > 30) throw new Error("Select at least one valid recipient");
    const room = this._roomRow(roomId);
    if (!room || Number(room.closed || 0) === 1) throw new Error("Room is unavailable");
    for (const receiverId of receivers) {
      const exists = this.ctx.storage.sql.exec(
        "SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1",
        receiverId,
      ).toArray()[0];
      if (!exists) throw new Error("Gift recipient not found");
    }

    const wallet = this.getWallet(senderId);
    if (wallet.banned) throw new Error("Wallet is unavailable");
    if (wallet.security_frozen) throw new Error("Wallet is security-frozen");
    const chargedUnitPrice = this._effectivePrice(senderId, "gift:" + giftId, unitPrice).price;
    const totalCost = chargedUnitPrice * quantity * receivers.length;
    if (!Number.isSafeInteger(totalCost) || totalCost < 0 || wallet.coins < totalCost) {
      throw new Error("Insufficient coins");
    }

    const now = Date.now();
    if (totalCost > 0) {
      this.ctx.storage.sql.exec(
        "UPDATE app_wallets SET coins = coins - ?, updated_at = ? WHERE user_id = ?",
        totalCost, now, senderId,
      );
      this._recordRoomGiftSending(room, totalCost, now);
    }

    const transactions = [];
    const luckyResults = [];
    let totalRebate = 0;
    let highestMultiplier = 0;
    let totalPoolContribution = 0;
    const hostRewardPercent = Math.max(
      0,
      Math.min(100, Number(giftData.host_reward_percent ?? luckyConfig.host_reward_percent ?? 10)),
    );
    const prizePoolPercent = Math.max(
      0,
      Math.min(100, Number(giftData.prize_pool_percent ?? luckyConfig.prize_pool_percent ?? 2)),
    );

    for (const receiverId of receivers) {
      const id = "gift-" + now.toString(36) + "-" + crypto.randomUUID().slice(0, 10);
      const receiverTotal = chargedUnitPrice * quantity;
      this.ctx.storage.sql.exec(
        `INSERT INTO gift_transactions
          (id, room_id, sender_id, receiver_id, gift_id, gift_name, quantity, unit_price, total_cost, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        id, roomId, senderId, receiverId, giftId, giftName, quantity, chargedUnitPrice, receiverTotal, now,
      );
      transactions.push({
        id,
        room_id: roomId,
        sender_id: senderId,
        receiver_id: receiverId,
        gift_id: giftId,
        gift_name: giftName,
        quantity,
        unit_price: chargedUnitPrice,
        total_cost: receiverTotal,
        created_at: now,
      });

      if (receiverTotal > 0 && this._isActiveHost(receiverId)) {
        const hostCredit = isLucky
          ? Math.floor(receiverTotal * hostRewardPercent / 100)
          : receiverTotal;
        if (hostCredit > 0) {
          this.ctx.storage.sql.exec(
            "INSERT OR IGNORE INTO app_wallets (user_id,coins,diamonds,banned,updated_at) VALUES (?,0,0,0,?)",
            receiverId, now,
          );
          this.ctx.storage.sql.exec(
            "UPDATE app_wallets SET diamonds=diamonds+?,updated_at=? WHERE user_id=?",
            hostCredit, now, receiverId,
          );
          this.ctx.storage.sql.exec(
            "INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?,'host_gift_diamonds',0,?,?,?,?)",
            "wallet-" + crypto.randomUUID(), receiverId, hostCredit, id,
            (isLucky ? "Lucky host gift 10%: " : "Host gift: ") + giftName, now,
          );
          this._recordHostEligibleGift(receiverId, hostCredit, now);
        }
      }

      if (isLucky && receiverTotal > 0) {
        const multiplier = this._rollLuckyMultiplier(luckyConfig);
        const rebateCoins = receiverTotal * multiplier;
        const poolContribution = Math.floor(receiverTotal * prizePoolPercent / 100);
        totalRebate += rebateCoins;
        totalPoolContribution += poolContribution;
        highestMultiplier = Math.max(highestMultiplier, multiplier);
        const socialValueCoins = Math.floor(receiverTotal * charmWealthPercent / 100);
        const resultId = "lucky-" + crypto.randomUUID();
        this.ctx.storage.sql.exec(
          `INSERT INTO lucky_gift_results
            (id,transaction_id,room_id,sender_id,receiver_id,gift_id,session_id,multiplier,rebate_coins,pool_contribution,social_value_coins,created_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
          resultId, id, roomId, senderId, receiverId, giftId, luckySessionId,
          multiplier, rebateCoins, poolContribution, socialValueCoins, now,
        );
        luckyResults.push({
          id: resultId,
          transaction_id: id,
          receiver_id: receiverId,
          session_id: luckySessionId,
          multiplier,
          rebate_coins: rebateCoins,
          pool_contribution: poolContribution,
          social_value_coins: socialValueCoins,
        });
      }
    }

    if (isLucky) {
      if (totalPoolContribution > 0) {
        this.ctx.storage.sql.exec(
          "UPDATE lucky_gift_pool SET balance=balance+?,updated_at=? WHERE singleton_id=1",
          totalPoolContribution, now,
        );
        const poolDayKey = new Date(now).toISOString().slice(0, 10);
        this.ctx.storage.sql.exec(
          `INSERT INTO lucky_gift_pool_daily
            (day_key,contributed_coins,distributed_coins,settled_at,updated_at)
           VALUES (?,?,0,NULL,?)
           ON CONFLICT(day_key) DO UPDATE SET
             contributed_coins=lucky_gift_pool_daily.contributed_coins+excluded.contributed_coins,
             updated_at=excluded.updated_at`,
          poolDayKey, totalPoolContribution, now,
        );
      }
      if (totalRebate > 0) {
        this._creditNormalWalletAuthorized(senderId, totalRebate, "lucky_gift_rebate");
        this.ctx.storage.sql.exec(
          "INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?,?,?,?,?,?,?)",
          "wallet-" + crypto.randomUUID(), senderId, "lucky_gift_rebate",
          totalRebate, 0, transactions[0]?.id || giftId,
          "Lucky gift rebate: " + giftName + " ×" + highestMultiplier, now,
        );
      } else {
        // Synchronize the expected anti-tamper balance after an authorized debit.
        this._normalWalletGuard(senderId);
      }

      const dayKey = new Date(now).toISOString().slice(0, 10);
      this.ctx.storage.sql.exec(
        `INSERT INTO lucky_gift_daily
          (day_key,user_id,sent_count,sent_coins,rebate_coins,highest_multiplier,updated_at)
         VALUES (?,?,?,?,?,?,?)
         ON CONFLICT(day_key,user_id) DO UPDATE SET
           sent_count=lucky_gift_daily.sent_count+excluded.sent_count,
           sent_coins=lucky_gift_daily.sent_coins+excluded.sent_coins,
           rebate_coins=lucky_gift_daily.rebate_coins+excluded.rebate_coins,
           highest_multiplier=MAX(lucky_gift_daily.highest_multiplier,excluded.highest_multiplier),
           updated_at=excluded.updated_at`,
        dayKey, senderId, quantity * receivers.length, totalCost,
        totalRebate, highestMultiplier, now,
      );

      this.ctx.storage.sql.exec(
        `INSERT INTO lucky_gift_sessions
          (id,user_id,room_id,gift_id,gift_name,unit_price,send_count,total_sent_coins,
           total_rebate_coins,highest_multiplier,started_at,updated_at)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
         ON CONFLICT(id) DO UPDATE SET
           send_count=lucky_gift_sessions.send_count+excluded.send_count,
           total_sent_coins=lucky_gift_sessions.total_sent_coins+excluded.total_sent_coins,
           total_rebate_coins=lucky_gift_sessions.total_rebate_coins+excluded.total_rebate_coins,
           highest_multiplier=MAX(lucky_gift_sessions.highest_multiplier,excluded.highest_multiplier),
           updated_at=excluded.updated_at`,
        luckySessionId, senderId, roomId, giftId, giftName, chargedUnitPrice,
        quantity * receivers.length, totalCost, totalRebate, highestMultiplier, now, now,
      );

      const highWinThreshold = Math.max(
        1,
        Number(giftData.high_win_multiplier ?? luckyConfig.high_win_multiplier ?? 200),
      );
      const bannerThreshold = Math.max(
        highWinThreshold,
        Number(giftData.banner_multiplier ?? luckyConfig.banner_multiplier ?? 500),
      );
      const ultraBannerThreshold = Math.max(
        bannerThreshold,
        Number(giftData.ultra_banner_multiplier ?? luckyConfig.ultra_banner_multiplier ?? 1000),
      );
      if (luckyConfig.banners_enabled !== false &&
          highestMultiplier >= bannerThreshold &&
          totalRebate > 0) {
        const user = this.getUserById(senderId);
        const countryCode = String(user?.country_code || room.country_code || "").toUpperCase();
        const ultra = highestMultiplier >= ultraBannerThreshold;
        this.ctx.storage.sql.exec(
          "INSERT INTO country_ribbons (id,country_code,kind,priority,room_id,user_id,user_name,avatar_data_url,amount,game_key,created_at,expires_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
          "ribbon-" + crypto.randomUUID(), countryCode,
          ultra ? "lucky_gift_ultra" : "lucky_gift", ultra ? 4 : 3, roomId,
          senderId, String(user?.display_name || senderId), user?.avatar_data_url || null,
          totalRebate, giftName + " • " + highestMultiplier + "x", now, now + 120000,
        );
      }
    } else {
      this._normalWalletGuard(senderId);
    }

    return {
      ok: true,
      total_cost: totalCost,
      wallet: this.getWallet(senderId),
      transactions,
      lucky: isLucky ? {
        enabled: true,
        multiplier: highestMultiplier,
        rebate_coins: totalRebate,
        results: luckyResults,
        pool_contribution: totalPoolContribution,
        pool_balance: this.luckyGiftState(senderId).pool_balance,
        max_multiplier: Math.max(1, Math.min(1000, Number(luckyConfig.max_multiplier || 1000))),
        artwork_asset: String(giftData.artwork_asset || ""),
        send_effect: String(giftData.send_effect || "fly_3d"),
        impact_effect: String(giftData.impact_effect || "sparkle_pop"),
        multiplier_effect: String(giftData.multiplier_effect || "float_multiplier"),
        high_win: highestMultiplier >= Math.max(
          1,
          Number(giftData.high_win_multiplier ?? luckyConfig.high_win_multiplier ?? 200),
        ),
        banner_win: highestMultiplier >= Math.max(
          1,
          Number(giftData.banner_multiplier ?? luckyConfig.banner_multiplier ?? 500),
        ),
        ultra_win: highestMultiplier >= Math.max(
          1,
          Number(giftData.ultra_banner_multiplier ?? luckyConfig.ultra_banner_multiplier ?? 1000),
        ),
        session: this.ctx.storage.sql.exec(
          "SELECT id,gift_name,unit_price,send_count,total_sent_coins,total_rebate_coins,highest_multiplier,started_at,updated_at FROM lucky_gift_sessions WHERE id=? LIMIT 1",
          luckySessionId,
        ).toArray()[0] || null,
      } : null,
    };
  }

  listRoomGifts(roomIdValue, limitValue = 100) {
    const roomId = String(roomIdValue || "").trim();
    const limit = Math.max(1, Math.min(200, Number(limitValue) || 100));
    if (!roomId) return [];
    const rows = this.ctx.storage.sql.exec(
      `SELECT g.*,l.session_id,l.multiplier,l.rebate_coins,l.pool_contribution,l.social_value_coins,
              COALESCE(u.display_name,g.sender_id) AS sender_name,u.avatar_data_url AS sender_avatar_data_url
         FROM gift_transactions g
         LEFT JOIN lucky_gift_results l ON l.transaction_id=g.id
         LEFT JOIN app_users u ON u.user_id=g.sender_id
        WHERE g.room_id=?
        ORDER BY g.created_at DESC
        LIMIT ?`,
      roomId, limit,
    ).toArray();
    return rows.map((row) => ({
      ...row,
      quantity: Number(row.quantity),
      unit_price: Number(row.unit_price),
      total_cost: Number(row.total_cost),
      created_at: Number(row.created_at),
      session_id: row.session_id ? String(row.session_id) : null,
      multiplier: row.multiplier == null ? null : Number(row.multiplier),
      rebate_coins: row.rebate_coins == null ? null : Number(row.rebate_coins),
      pool_contribution: row.pool_contribution == null ? null : Number(row.pool_contribution),
      social_value_coins: row.social_value_coins == null ? null : Number(row.social_value_coins),
      sender_name: String(row.sender_name || row.sender_id),
      sender_avatar_data_url: row.sender_avatar_data_url ? String(row.sender_avatar_data_url) : null,
    }));
  }

  _ludoInitialState() {
    return {
      current_player: "red",
      rolled: null,
      winner: null,
      status: "RED starts. Roll the dice.",
      tokens: {
        red: [-1, -1, -1, -1],
        green: [-1, -1, -1, -1],
        yellow: [-1, -1, -1, -1],
        blue: [-1, -1, -1, -1],
      },
    };
  }

  _ludoTrackIndex(color, progress) {
    const offsets = { red: 0, green: 13, yellow: 26, blue: 39 };
    if (!(color in offsets) || progress < 0 || progress >= 52) return -1;
    return (offsets[color] + progress) % 52;
  }

  _ludoMovableIndexes(state) {
    const dice = Number(state?.rolled || 0);
    const color = String(state?.current_player || "red");
    const tokens = Array.isArray(state?.tokens?.[color]) ? state.tokens[color] : [];
    if (!dice || state?.winner) return [];
    const result = [];
    for (let index = 0; index < tokens.length; index += 1) {
      const progress = Number(tokens[index]);
      if (progress >= 57) continue;
      if (progress < 0) {
        if (dice === 6) result.push(index);
      } else if (progress + dice <= 57) {
        result.push(index);
      }
    }
    return result;
  }

  _ludoAdvancePlayer(roomIdValue, state, keepTurn = false) {
    const roomId = String(roomIdValue || "").trim();
    const previousRoll = Number(state.rolled || 0);
    state.rolled = null;
    if (state.winner) return;
    if (keepTurn && previousRoll === 6) {
      state.status = String(state.current_player).toUpperCase() + " gets another roll.";
      return;
    }
    const colorOrder = ["red", "green", "yellow", "blue"];
    const occupied = new Set(
      this.ctx.storage.sql.exec(
        "SELECT color FROM ludo_room_players WHERE room_id=? ORDER BY joined_at ASC",
        roomId,
      ).toArray().map((row) => String(row.color)),
    );
    const currentIndex = colorOrder.indexOf(String(state.current_player));
    for (let offset = 1; offset <= colorOrder.length; offset += 1) {
      const next = colorOrder[(Math.max(0, currentIndex) + offset) % colorOrder.length];
      if (occupied.has(next)) {
        state.current_player = next;
        state.status = next.toUpperCase() + " turn.";
        return;
      }
    }
    state.status = String(state.current_player).toUpperCase() + " turn.";
  }

  _requireActiveRoomUser(userIdValue, roomIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const roomId = String(roomIdValue || "").trim();
    const room = this.ctx.storage.sql.exec(
      "SELECT id,owner_id,closed FROM app_rooms WHERE id=? LIMIT 1",
      roomId,
    ).toArray()[0];
    if (!room || Number(room.closed || 0) === 1) throw new Error("Room is unavailable");
    const presence = this.ctx.storage.sql.exec(
      "SELECT room_id,last_seen FROM app_user_presence WHERE user_id=? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!presence || String(presence.room_id || "") !== roomId ||
        Date.now() - Number(presence.last_seen || 0) > 120000) {
      throw new Error("You must be active inside this room to play");
    }
    return { userId, roomId, room };
  }

  _ensureLudoPlayer(userIdValue, roomIdValue) {
    const { userId, roomId } = this._requireActiveRoomUser(userIdValue, roomIdValue);
    let player = this.ctx.storage.sql.exec(
      "SELECT color,joined_at FROM ludo_room_players WHERE room_id=? AND user_id=? LIMIT 1",
      roomId, userId,
    ).toArray()[0];
    if (!player) {
      const used = new Set(
        this.ctx.storage.sql.exec(
          "SELECT color FROM ludo_room_players WHERE room_id=?",
          roomId,
        ).toArray().map((row) => String(row.color)),
      );
      const color = ["red", "green", "yellow", "blue"].find((item) => !used.has(item));
      if (color) {
        const now = Date.now();
        this.ctx.storage.sql.exec(
          "INSERT INTO ludo_room_players(room_id,user_id,color,joined_at) VALUES (?,?,?,?)",
          roomId, userId, color, now,
        );
        player = { color, joined_at: now };
      }
    }
    return player ? String(player.color) : null;
  }

  _loadLudoState(roomIdValue) {
    const roomId = String(roomIdValue || "").trim();
    let row = this.ctx.storage.sql.exec(
      "SELECT state_json,version,updated_at FROM ludo_room_sessions WHERE room_id=? LIMIT 1",
      roomId,
    ).toArray()[0];
    if (!row) {
      const state = this._ludoInitialState();
      const now = Date.now();
      this.ctx.storage.sql.exec(
        "INSERT INTO ludo_room_sessions(room_id,state_json,version,updated_at) VALUES (?,?,1,?)",
        roomId, JSON.stringify(state), now,
      );
      row = { state_json: JSON.stringify(state), version: 1, updated_at: now };
    }
    let state;
    try { state = JSON.parse(String(row.state_json || "{}")); }
    catch { state = this._ludoInitialState(); }
    return {
      state,
      version: Math.max(1, Number(row.version || 1)),
      updated_at: Number(row.updated_at || 0),
    };
  }

  _saveLudoState(roomIdValue, state, expectedVersionValue) {
    const roomId = String(roomIdValue || "").trim();
    const expectedVersion = Math.max(1, Number(expectedVersionValue || 1));
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "UPDATE ludo_room_sessions SET state_json=?,version=version+1,updated_at=? WHERE room_id=? AND version=?",
      JSON.stringify(state), now, roomId, expectedVersion,
    );
    const row = this.ctx.storage.sql.exec(
      "SELECT version FROM ludo_room_sessions WHERE room_id=? LIMIT 1",
      roomId,
    ).toArray()[0];
    const nextVersion = Number(row?.version || 0);
    if (nextVersion !== expectedVersion + 1) {
      throw new Error("Game state changed. Refresh and try again.");
    }
    return nextVersion;
  }

  _publicLudoState(userIdValue, roomIdValue, loadedValue = null) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const roomId = String(roomIdValue || "").trim();
    const loaded = loadedValue || this._loadLudoState(roomId);
    const players = this.ctx.storage.sql.exec(
      "SELECT user_id,color,joined_at FROM ludo_room_players WHERE room_id=? ORDER BY joined_at ASC",
      roomId,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      color: String(row.color),
      joined_at: Number(row.joined_at || 0),
    }));
    const mine = players.find((row) => row.user_id === userId) || null;
    return {
      ok: true,
      room_id: roomId,
      player_color: mine?.color || null,
      spectator: !mine,
      players,
      version: loaded.version,
      updated_at: loaded.updated_at,
      ...loaded.state,
      movable_indexes: this._ludoMovableIndexes(loaded.state),
    };
  }

  ludoState(userIdValue, roomIdValue) {
    const { roomId } = this._requireActiveRoomUser(userIdValue, roomIdValue);
    this._ensureLudoPlayer(userIdValue, roomId);
    return this._publicLudoState(userIdValue, roomId);
  }

  ludoRoll(userIdValue, roomIdValue) {
    const { userId, roomId } = this._requireActiveRoomUser(userIdValue, roomIdValue);
    this._enforceActionRate(userId, "ludo_roll", 20, 30000, 60000);
    const color = this._ensureLudoPlayer(userId, roomId);
    if (!color) throw new Error("Ludo table already has four players");
    const loaded = this._loadLudoState(roomId);
    const state = loaded.state;
    if (state.winner) return this._publicLudoState(userId, roomId, loaded);
    if (String(state.current_player) !== color) throw new Error("It is not your turn");
    if (state.rolled != null) return this._publicLudoState(userId, roomId, loaded);

    const random = crypto.getRandomValues(new Uint32Array(1))[0];
    state.rolled = (random % 6) + 1;
    state.status = color.toUpperCase() + " rolled " + state.rolled + ".";
    if (this._ludoMovableIndexes(state).length === 0) {
      this._ludoAdvancePlayer(roomId, state, false);
    }
    const version = this._saveLudoState(roomId, state, loaded.version);
    return this._publicLudoState(userId, roomId, {
      state, version, updated_at: Date.now(),
    });
  }

  ludoMove(userIdValue, roomIdValue, tokenIndexValue) {
    const { userId, roomId } = this._requireActiveRoomUser(userIdValue, roomIdValue);
    this._enforceActionRate(userId, "ludo_move", 30, 30000, 60000);
    const color = this._ensureLudoPlayer(userId, roomId);
    if (!color) throw new Error("Ludo table already has four players");
    const tokenIndex = Number(tokenIndexValue);
    if (!Number.isInteger(tokenIndex) || tokenIndex < 0 || tokenIndex > 3) {
      throw new Error("Invalid Ludo token");
    }
    const loaded = this._loadLudoState(roomId);
    const state = loaded.state;
    if (state.winner) return this._publicLudoState(userId, roomId, loaded);
    if (String(state.current_player) !== color) throw new Error("It is not your turn");
    const dice = Number(state.rolled || 0);
    if (!dice) throw new Error("Roll the dice first");
    const movable = this._ludoMovableIndexes(state);
    if (!movable.includes(tokenIndex)) throw new Error("That token cannot move");

    const tokens = state.tokens[color];
    const current = Number(tokens[tokenIndex]);
    const next = current < 0 ? 0 : current + dice;
    tokens[tokenIndex] = next;

    if (next < 52) {
      const sharedIndex = this._ludoTrackIndex(color, next);
      const safe = new Set([0, 8, 13, 21, 26, 34, 39, 47]);
      if (!safe.has(sharedIndex)) {
        for (const opponent of ["red", "green", "yellow", "blue"]) {
          if (opponent === color) continue;
          for (let index = 0; index < state.tokens[opponent].length; index += 1) {
            const progress = Number(state.tokens[opponent][index]);
            if (progress >= 0 && progress < 52 &&
                this._ludoTrackIndex(opponent, progress) === sharedIndex) {
              state.tokens[opponent][index] = -1;
            }
          }
        }
      }
    }

    if (state.tokens[color].every((progress) => Number(progress) >= 57)) {
      state.winner = color;
      state.rolled = null;
      state.status = color.toUpperCase() + " wins!";
    } else {
      state.status = color.toUpperCase() + " moved token " + (tokenIndex + 1) + ".";
      this._ludoAdvancePlayer(roomId, state, dice === 6);
    }

    const version = this._saveLudoState(roomId, state, loaded.version);
    return this._publicLudoState(userId, roomId, {
      state, version, updated_at: Date.now(),
    });
  }

  ludoReset(userIdValue, roomIdValue) {
    const { userId, roomId, room } = this._requireActiveRoomUser(userIdValue, roomIdValue);
    if (String(room.owner_id || "") !== userId) {
      throw new Error("Only the room owner can restart Ludo");
    }
    this._enforceActionRate(userId, "ludo_reset", 3, 60000, 120000);
    const state = this._ludoInitialState();
    const loaded = this._loadLudoState(roomId);
    const version = this._saveLudoState(roomId, state, loaded.version);
    return this._publicLudoState(userId, roomId, {
      state, version, updated_at: Date.now(),
    });
  }

  playRoomQuickGame(userIdValue, input = {}) {
    const userId = String(userIdValue || "").trim();
    this._enforceActionRate(userId, "quick_game_action", 30, 60000, 120000);
    const roomId = String(input.room_id || "").trim();
    const gameKey = String(input.game_key || "").trim().toLowerCase();
    const action = cleanText(input.action, 40);
    if (!userId || !roomId || !action) throw new Error("room_id, game_key and action are required");
    const allowed = new Set(["lucky_dice", "lucky_wheel", "rps", "teen_patti"]);
    if (!allowed.has(gameKey)) throw new Error("Unsupported room game");
    const room = this.ctx.storage.sql.exec("SELECT id, closed FROM app_rooms WHERE id = ? LIMIT 1", roomId).toArray()[0];
    if (!room || Number(room.closed || 0) === 1) throw new Error("Room is unavailable");
    let result = action;
    const random = crypto.getRandomValues(new Uint32Array(1))[0];
    if (gameKey === "lucky_dice") result = String((random % 6) + 1);
    if (gameKey === "lucky_wheel") result = ["Star","Crown","Rose","Diamond","Lion","Dragon"][random % 6];
    if (gameKey === "rps") result = ["Rock","Paper","Scissors"][random % 3];
    if (gameKey === "teen_patti") result = action === "Join Table" ? "joined" : "viewing";
    const now = Date.now(); const id = "game-" + crypto.randomUUID();
    this.ctx.storage.sql.exec("INSERT INTO room_game_actions (id,room_id,user_id,game_key,action_value,server_result,created_at) VALUES (?,?,?,?,?,?,?)", id, roomId, userId, gameKey, action, result, now);
    return { ok: true, id, room_id: roomId, user_id: userId, game_key: gameKey, action, result, created_at: now };
  }

  cpRanking(limitValue = 100) {
    const limit = Math.max(1, Math.min(200, Number(limitValue || 100)));
    return this.ctx.storage.sql.exec(
      `SELECT c.user_a,c.user_b,c.intimacy,c.level,c.updated_at,
              ua.display_name AS user_a_name,
              ua.avatar_data_url AS user_a_avatar,
              ub.display_name AS user_b_name,
              ub.avatar_data_url AS user_b_avatar
         FROM cp_relationships c
         LEFT JOIN app_users ua ON ua.user_id=c.user_a
         LEFT JOIN app_users ub ON ub.user_id=c.user_b
        WHERE c.state='accepted'
        ORDER BY c.intimacy DESC,c.level DESC,c.updated_at ASC
        LIMIT ?`,
      limit,
    ).toArray().map((row, index) => ({
      rank: index + 1,
      user_a: String(row.user_a),
      user_b: String(row.user_b),
      user_a_name: String(row.user_a_name || row.user_a),
      user_b_name: String(row.user_b_name || row.user_b),
      user_a_avatar: row.user_a_avatar ? String(row.user_a_avatar) : null,
      user_b_avatar: row.user_b_avatar ? String(row.user_b_avatar) : null,
      intimacy: Math.max(0, Number(row.intimacy || 0)),
      level: Math.max(1, Number(row.level || 1)),
    }));
  }

  cpState(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) throw new Error("user ID is required");
    const row = this.ctx.storage.sql.exec(
      "SELECT * FROM cp_relationships WHERE user_a = ? OR user_b = ? ORDER BY updated_at DESC LIMIT 1", userId, userId,
    ).toArray()[0];
    if (!row) return null;
    return { ...row, intimacy: Number(row.intimacy || 0), level: Number(row.level || 1), created_at: Number(row.created_at), updated_at: Number(row.updated_at) };
  }

  cpRequest(userIdValue, targetIdValue) {
    const userId = String(userIdValue || "").trim();
    const targetId = String(targetIdValue || "").trim();
    if (!userId || !targetId || userId === targetId) throw new Error("Choose another user for CP");
    if (!this.getUserById(targetId)) throw new Error("User not found");
    if (this.cpState(userId) || this.cpState(targetId)) throw new Error("A CP flow is already active");
    const policies = this.ownerState().policies;
    const price = this._effectivePrice(userId, "cp:connect", Math.max(0, Number(policies.cp_connect_coins || 0))).price;
    const wallet = this.getWallet(userId);
    if (wallet.banned) throw new Error("Wallet is restricted");
    if (wallet.coins < price) throw new Error("Insufficient coin balance");
    const pair = [userId, targetId].sort(); const now = Date.now();
    if (price > 0) {
      this.ctx.storage.sql.exec("UPDATE app_wallets SET coins = coins - ?, updated_at = ? WHERE user_id = ?", price, now, userId);
      this.ctx.storage.sql.exec("INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?, 'cp_connect',?,0,?,?,?)", crypto.randomUUID(), userId, -price, "cp:" + targetId, "CP connect", now);
    }
    this.ctx.storage.sql.exec("INSERT INTO cp_relationships (user_a,user_b,state,intimacy,level,ring_id,requested_by,created_at,updated_at) VALUES (?,?, 'pending',0,1,NULL,?,?,?)", pair[0], pair[1], userId, now, now);
    return this.cpState(userId);
  }

  cpRespond(userIdValue, acceptValue) {
    const userId = String(userIdValue || "").trim(); const row = this.cpState(userId);
    if (!row || row.state !== "pending" || row.requested_by === userId) throw new Error("No CP request is awaiting your response");
    this.ctx.storage.sql.exec("UPDATE cp_relationships SET state = ?, updated_at = ? WHERE user_a = ? AND user_b = ?", acceptValue === true ? "accepted" : "refused", Date.now(), row.user_a, row.user_b);
    return this.cpState(userId);
  }

  cpDisconnect(userIdValue) {
    const userId = String(userIdValue || "").trim(); const row = this.cpState(userId);
    if (!row) return { ok: true, cp: null, wallet: this.getWallet(userId) };
    const policies = this.ownerState().policies;
    const price = this._effectivePrice(userId, "cp:disconnect", Math.max(0, Number(policies.cp_disconnect_coins || 0))).price;
    const wallet = this.getWallet(userId);
    if (wallet.banned) throw new Error("Wallet is restricted");
    if (wallet.coins < price) throw new Error("Insufficient coin balance");
    const now = Date.now();
    if (price > 0) {
      this.ctx.storage.sql.exec("UPDATE app_wallets SET coins = coins - ?, updated_at = ? WHERE user_id = ?", price, now, userId);
      this.ctx.storage.sql.exec("INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?, 'cp_disconnect',?,0,?,?,?)", crypto.randomUUID(), userId, -price, "cp:" + row.user_a + ":" + row.user_b, "CP disconnect", now);
    }
    this.ctx.storage.sql.exec("DELETE FROM cp_relationships WHERE user_a = ? AND user_b = ?", row.user_a, row.user_b);
    return { ok: true, cp: null, charged_coins: price, wallet: this.getWallet(userId) };
  }

  cpUpdate(userIdValue, input = {}) {
    const userId = String(userIdValue || "").trim();
    const row = this.cpState(userId);
    if (!row || row.state !== "accepted") throw new Error("Active CP relationship is required");
    const action = String(input.action || "").trim();
    if (action === "intimacy") {
      const delta = Math.max(1, Math.min(10000, Number(input.delta || 0)));
      const intimacy = Number(row.intimacy || 0) + delta;
      const level = Math.max(1, Math.floor(intimacy / 1000) + 1);
      this.ctx.storage.sql.exec(
        "UPDATE cp_relationships SET intimacy = ?, level = ?, updated_at = ? WHERE user_a = ? AND user_b = ?",
        intimacy, level, Date.now(), row.user_a, row.user_b,
      );
    } else if (action === "ring") {
      const ringId = cleanText(input.ring_id, 80);
      if (!ringId) throw new Error("ring_id is required");
      this.ctx.storage.sql.exec(
        "UPDATE cp_relationships SET ring_id = ?, updated_at = ? WHERE user_a = ? AND user_b = ?",
        ringId, Date.now(), row.user_a, row.user_b,
      );
    } else {
      throw new Error("Unsupported CP update");
    }
    return this.cpState(userId);
  }

  cpMemories(userIdValue) {
    const row = this.cpState(userIdValue);
    if (!row || row.state !== "accepted") return [];
    return this.ctx.storage.sql.exec(
      "SELECT id, author_id, text, created_at FROM cp_memories WHERE user_a = ? AND user_b = ? ORDER BY created_at DESC LIMIT 200",
      row.user_a, row.user_b,
    ).toArray().map((item) => ({
      id: String(item.id), author_id: String(item.author_id),
      text: String(item.text), created_at: Number(item.created_at),
    }));
  }

  cpAddMemory(userIdValue, textValue) {
    const userId = String(userIdValue || "").trim();
    const row = this.cpState(userId);
    if (!row || row.state !== "accepted") throw new Error("Active CP relationship is required");
    const text = cleanText(textValue, 120);
    if (!text) throw new Error("Memory text is required");
    const memory = { id: crypto.randomUUID(), author_id: userId, text, created_at: Date.now() };
    this.ctx.storage.sql.exec(
      "INSERT INTO cp_memories (id,user_a,user_b,author_id,text,created_at) VALUES (?,?,?,?,?,?)",
      memory.id, row.user_a, row.user_b, userId, text, memory.created_at,
    );
    return memory;
  }

  profileTrends(userIdValue, limitValue = 40) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) throw new Error("User not found");
    const limit = Math.max(1, Math.min(100, Number(limitValue || 40)));
    return this.ctx.storage.sql.exec(
      `SELECT id,user_id,text,created_at
         FROM profile_trends
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT ?`,
      userId, limit,
    ).toArray().map((row) => ({
      id: String(row.id),
      user_id: String(row.user_id),
      text: String(row.text || ""),
      created_at: Number(row.created_at || 0),
    }));
  }

  addProfileTrend(userIdValue, textValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) throw new Error("User not found");
    const text = cleanText(textValue, 500);
    if (!text) throw new Error("Trend text is required");
    const now = Date.now();
    const id = "trend-" + now + "-" + crypto.randomUUID().slice(0, 8);
    this.ctx.storage.sql.exec(
      "INSERT INTO profile_trends (id,user_id,text,created_at) VALUES (?,?,?,?)",
      id, userId, text, now,
    );
    return { id, user_id: userId, text, created_at: now };
  }

  guardianState(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) throw new Error("User not found");
    const now = Date.now();
    const since = now - (30 * 24 * 60 * 60 * 1000);
    const rows = this.ctx.storage.sql.exec(
      `SELECT g.sender_id,
              COALESCE(SUM(g.total_cost),0) AS points,
              u.display_name,
              u.avatar_data_url,
              u.flag_emoji
         FROM gift_transactions g
         LEFT JOIN app_users u ON u.user_id = g.sender_id
        WHERE g.receiver_id = ?
          AND g.created_at >= ?
        GROUP BY g.sender_id, u.display_name, u.avatar_data_url, u.flag_emoji
        ORDER BY points DESC, g.sender_id ASC
        LIMIT 50`,
      userId, since,
    ).toArray();

    const supporters = rows.map((row, index) => ({
      rank: index + 1,
      user_id: String(row.sender_id),
      display_name: String(row.display_name || row.sender_id),
      avatar_data_url: row.avatar_data_url ? String(row.avatar_data_url) : null,
      flag_emoji: String(row.flag_emoji || ""),
      points: Math.max(0, Number(row.points || 0)),
      guardian_eligible: Number(row.points || 0) >= 1000,
    }));
    const top = supporters[0] || null;
    const guardian = top && Number(top.points || 0) >= 10000 ? top : null;
    return {
      guardian,
      supporters,
      candidate_threshold: 1000,
      guardian_threshold: 10000,
      window_days: 30,
      updated_at: now,
    };
  }

  profileStats(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId || !this.getUserById(userId)) throw new Error("User not found");

    const following = Number(this.ctx.storage.sql.exec(
      "SELECT COUNT(*) AS count FROM app_follows WHERE follower_id=?", userId,
    ).toArray()[0]?.count || 0);
    const followers = Number(this.ctx.storage.sql.exec(
      "SELECT COUNT(*) AS count FROM app_follows WHERE target_id=?", userId,
    ).toArray()[0]?.count || 0);
    const sent = Number(this.ctx.storage.sql.exec(
      `SELECT COALESCE(SUM(CASE WHEN l.transaction_id IS NULL THEN g.total_cost ELSE l.social_value_coins END),0) AS total
         FROM gift_transactions g
         LEFT JOIN lucky_gift_results l ON l.transaction_id=g.id
        WHERE g.sender_id=?`, userId,
    ).toArray()[0]?.total || 0);
    const received = Number(this.ctx.storage.sql.exec(
      `SELECT COALESCE(SUM(CASE WHEN l.transaction_id IS NULL THEN g.total_cost ELSE l.social_value_coins END),0) AS total
         FROM gift_transactions g
         LEFT JOIN lucky_gift_results l ON l.transaction_id=g.id
        WHERE g.receiver_id=?`, userId,
    ).toArray()[0]?.total || 0);

    const levelFor = (settingKey, points) => {
      const row = this.ctx.storage.sql.exec(
        "SELECT value_json FROM owner_settings WHERE key=? LIMIT 1", settingKey,
      ).toArray()[0];
      let thresholds = [];
      try {
        const parsed = JSON.parse(String(row?.value_json || "[]"));
        thresholds = Array.isArray(parsed)
          ? parsed.map((value)=>Math.max(0,Number(value||0))).filter(Number.isFinite)
          : [];
      } catch {}
      thresholds.sort((a,b)=>a-b);
      let level = 0;
      for (const threshold of thresholds) {
        if (points >= threshold) level += 1;
        else break;
      }
      const next = level < thresholds.length ? thresholds[level] : null;
      return { level, next_threshold: next, thresholds };
    };

    return {
      user_id:userId,
      following_count:following,
      followers_count:followers,
      lifetime_sent_coins:Math.max(0,sent),
      lifetime_received_coins:Math.max(0,received),
      wealth:levelFor("wealth_level_thresholds", Math.max(0,sent)),
      charm:levelFor("charm_level_thresholds", Math.max(0,received)),
    };
  }

  taskState(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const user = this.ctx.storage.sql.exec(
      "SELECT display_name,country_code,gender FROM app_users WHERE user_id=? LIMIT 1", userId,
    ).toArray()[0];
    if (!user) throw new Error("User not found");
    const followed = Number(this.ctx.storage.sql.exec(
      "SELECT COUNT(*) AS count FROM app_follows WHERE follower_id=?", userId,
    ).toArray()[0]?.count || 0) > 0;
    const family = Boolean(this.ctx.storage.sql.exec(
      "SELECT user_id FROM family_members WHERE user_id=? LIMIT 1", userId,
    ).toArray()[0]);
    const gifted = Boolean(this.ctx.storage.sql.exec(
      "SELECT id FROM gift_transactions WHERE sender_id=? LIMIT 1", userId,
    ).toArray()[0]);
    const enteredRoom = Boolean(this.ctx.storage.sql.exec(
      "SELECT room_id FROM app_recent_rooms WHERE user_id=? LIMIT 1", userId,
    ).toArray()[0]);
    const profileComplete = String(user.display_name || "").trim().length > 0 &&
      String(user.country_code || "").trim().length > 0 &&
      String(user.gender || "").trim().length > 0;
    const definitions = [
      { id:"profile_complete", title:"Complete your profile", reward_coins:100, completed:profileComplete },
      { id:"follow_one", title:"Follow 1 user", reward_coins:100, completed:followed },
      { id:"enter_room", title:"Enter a Party room", reward_coins:100, completed:enteredRoom },
      { id:"send_gift", title:"Send your first gift", reward_coins:200, completed:gifted },
      { id:"join_family", title:"Join a Family", reward_coins:300, completed:family },
    ];
    const claims = new Set(this.ctx.storage.sql.exec(
      "SELECT task_id FROM user_task_claims WHERE user_id=?", userId,
    ).toArray().map((row)=>String(row.task_id)));
    return definitions.map((task)=>({ ...task, claimed:claims.has(task.id) }));
  }

  claimTask(userIdValue, taskIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const taskId = String(taskIdValue || "").trim();
    const task = this.taskState(userId).find((item)=>item.id===taskId);
    if (!task) throw new Error("Task not found");
    if (!task.completed) throw new Error("Complete this task first");
    if (task.claimed) throw new Error("Task reward already claimed");
    const now = Date.now();
    this._creditNormalWalletAuthorized(userId, task.reward_coins, "task_reward");
    this.ctx.storage.sql.exec(
      "INSERT INTO user_task_claims(user_id,task_id,reward_coins,claimed_at) VALUES(?,?,?,?)",
      userId,task.id,task.reward_coins,now,
    );
    this.ctx.storage.sql.exec(
      "INSERT INTO wallet_transactions(id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES(?,?, 'task_reward',?,0,?,?,?)",
      crypto.randomUUID(),userId,task.reward_coins,"task:"+task.id,task.title,now,
    );
    return { ok:true, task:{...task,claimed:true}, tasks:this.taskState(userId), wallet:this.getWallet(userId) };
  }

  userPreferences(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const row = this.ctx.storage.sql.exec(
      "SELECT * FROM user_preferences WHERE user_id = ? LIMIT 1", userId,
    ).toArray()[0];
    return {
      message_voice: row ? Number(row.message_voice) === 1 : true,
      message_vibration: row ? Number(row.message_vibration) === 1 : true,
      room_floating_only: row ? Number(row.room_floating_only) === 1 : false,
      language: row ? String(row.language || "English") : "English",
    };
  }

  updateUserPreferences(userIdValue, input = {}) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const current = this.userPreferences(userId);
    const next = {
      message_voice: input.message_voice === undefined ? current.message_voice : input.message_voice === true,
      message_vibration: input.message_vibration === undefined ? current.message_vibration : input.message_vibration === true,
      room_floating_only: input.room_floating_only === undefined ? current.room_floating_only : input.room_floating_only === true,
      language: cleanText(input.language === undefined ? current.language : input.language, 40) || "English",
    };
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO user_preferences
        (user_id,message_voice,message_vibration,room_floating_only,language,updated_at)
       VALUES (?,?,?,?,?,?)
       ON CONFLICT(user_id) DO UPDATE SET
        message_voice=excluded.message_voice,
        message_vibration=excluded.message_vibration,
        room_floating_only=excluded.room_floating_only,
        language=excluded.language,
        updated_at=excluded.updated_at`,
      userId, next.message_voice ? 1 : 0, next.message_vibration ? 1 : 0,
      next.room_floating_only ? 1 : 0, next.language, now,
    );
    return { ok: true, preferences: next };
  }

  submitUserFeedback(userIdValue, categoryValue, messageValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const category = cleanText(categoryValue || "General", 40) || "General";
    const message = cleanText(messageValue, 2000);
    if (message.length < 3) throw new Error("Feedback message is too short");
    const row = { id: crypto.randomUUID(), user_id: userId, category, message, status: "submitted", created_at: Date.now() };
    this.ctx.storage.sql.exec(
      "INSERT INTO user_feedback (id,user_id,category,message,status,created_at) VALUES (?,?,?,?,?,?)",
      row.id,row.user_id,row.category,row.message,row.status,row.created_at,
    );
    return { ok: true, feedback: row };
  }

  userFeedback(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    return this.ctx.storage.sql.exec(
      "SELECT id,category,message,status,created_at FROM user_feedback WHERE user_id=? ORDER BY created_at DESC LIMIT 100", userId,
    ).toArray().map((row)=>({id:String(row.id),category:String(row.category),message:String(row.message),status:String(row.status),created_at:Number(row.created_at)}));
  }

  accountIdentities(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    return this.ctx.storage.sql.exec(
      "SELECT provider,subject,created_at FROM app_user_identities WHERE user_id=? ORDER BY created_at ASC", userId,
    ).toArray().map((row)=>({provider:String(row.provider),subject:String(row.subject),created_at:Number(row.created_at)}));
  }

  walletTransactions(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    return this.ctx.storage.sql.exec(
      "SELECT id,kind,coins_delta,diamonds_delta,reference_id,note,created_at FROM wallet_transactions WHERE user_id = ? ORDER BY created_at DESC LIMIT 200",
      userId,
    ).toArray().map((row) => ({
      id: String(row.id), kind: String(row.kind),
      coins_delta: Number(row.coins_delta || 0), diamonds_delta: Number(row.diamonds_delta || 0),
      reference_id: row.reference_id ? String(row.reference_id) : null,
      note: String(row.note || ""), created_at: Number(row.created_at),
    }));
  }

  frameCatalog(countryCodeValue = "") {
    const country = String(countryCodeValue || "").trim().toUpperCase();
    return this.ownerCatalog("frame")
      .filter((item) => {
        if (item.enabled === false) return false;
        const countries = Array.isArray(item.data?.countries)
          ? item.data.countries.map((value) => String(value || "").toUpperCase())
          : [];
        const now = Date.now();
        const startsAt = Number(item.data?.starts_at || 0);
        const endsAt = Number(item.data?.ends_at || 0);
        return (!countries.length || countries.includes(country)) &&
          (!startsAt || startsAt <= now) && (!endsAt || endsAt > now);
      })
      .map((item) => ({
        ...item,
        price: Math.max(0, Number(item.data?.price || item.data?.coin_price || 0)),
        asset_url: String(item.data?.asset_url || ""),
        order: Number(item.data?.order || 0),
      }))
      .sort((a, b) => a.order - b.order || a.name.localeCompare(b.name));
  }

  inventoryState(userIdValue) {
    this._ensureEconomyMigrations();
    const userId = this._resolveOwnerUserId(userIdValue);
    const now = Date.now();
    const rows = this.ctx.storage.sql.exec(
      `SELECT ui.item_id,ui.item_kind,ui.acquired_at,ui.expires_at,
              oc.name AS catalog_name,oc.data_json AS catalog_data_json
         FROM user_inventory ui
         LEFT JOIN owner_catalog oc ON oc.id=ui.item_id
        WHERE ui.user_id=? AND (ui.expires_at IS NULL OR ui.expires_at>?)
        ORDER BY ui.acquired_at DESC`,
      userId, now,
    ).toArray();
    const equipment = this.ctx.storage.sql.exec(
      `SELECT equipped_frame_id,equipped_vehicle_id,equipped_entry_id,
              equipped_profile_card_id,equipped_ring_id,equipped_bubble_id,
              equipped_profile_background_id,updated_at
         FROM user_equipment WHERE user_id = ? LIMIT 1`,
      userId,
    ).toArray()[0] || {};
    const activeIds = new Set(rows.map((row) => String(row.item_id)));
    const keys = [
      "equipped_frame_id","equipped_vehicle_id","equipped_entry_id",
      "equipped_profile_card_id","equipped_ring_id","equipped_bubble_id",
      "equipped_profile_background_id",
    ];
    let changed = false;
    for (const key of keys) {
      if (equipment[key] && !activeIds.has(String(equipment[key]))) {
        equipment[key] = null;
        changed = true;
      }
    }
    if (changed) {
      this.ctx.storage.sql.exec(
        `UPDATE user_equipment SET
          equipped_frame_id=?,equipped_vehicle_id=?,equipped_entry_id=?,
          equipped_profile_card_id=?,equipped_ring_id=?,equipped_bubble_id=?,
          equipped_profile_background_id=?,updated_at=?
         WHERE user_id=?`,
        equipment.equipped_frame_id || null,
        equipment.equipped_vehicle_id || null,
        equipment.equipped_entry_id || null,
        equipment.equipped_profile_card_id || null,
        equipment.equipped_ring_id || null,
        equipment.equipped_bubble_id || null,
        equipment.equipped_profile_background_id || null,
        now,userId,
      );
    }
    return {
      owned: rows.map((row) => {
        let data = {};
        try { data = JSON.parse(String(row.catalog_data_json || "{}")); } catch {}
        return {
          item_id: String(row.item_id),
          item_kind: String(row.item_kind),
          name: String(row.catalog_name || row.item_id),
          asset_url: String(data.asset_url || ""),
          acquired_at: Number(row.acquired_at),
          expires_at: row.expires_at == null ? null : Number(row.expires_at),
        };
      }),
      equipped_frame_id: equipment.equipped_frame_id ? String(equipment.equipped_frame_id) : null,
      equipped_vehicle_id: equipment.equipped_vehicle_id ? String(equipment.equipped_vehicle_id) : null,
      equipped_entry_id: equipment.equipped_entry_id ? String(equipment.equipped_entry_id) : null,
      equipped_profile_card_id: equipment.equipped_profile_card_id ? String(equipment.equipped_profile_card_id) : null,
      equipped_ring_id: equipment.equipped_ring_id ? String(equipment.equipped_ring_id) : null,
      equipped_bubble_id: equipment.equipped_bubble_id ? String(equipment.equipped_bubble_id) : null,
      equipped_profile_background_id: equipment.equipped_profile_background_id ? String(equipment.equipped_profile_background_id) : null,
      updated_at: Number(equipment.updated_at || 0),
    };
  }

  purchaseUniqueId(userIdValue, publicIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const requestedId = String(publicIdValue || "").trim();
    if (!/^\d{4,8}$/.test(requestedId)) {
      throw new Error(
        "Name ID cannot be purchased or claimed by a user; only the Owner Master Panel can assign it",
      );
    }
    const offer = this.ctx.storage.sql.exec(
      "SELECT * FROM owner_unique_ids WHERE LOWER(public_id) = LOWER(?) AND enabled = 1 LIMIT 1",
      requestedId,
    ).toArray()[0];
    if (!offer) throw new Error("Unique ID is unavailable");
    const publicId = String(offer.public_id);
    if (offer.assigned_user_id) throw new Error("Unique ID is already assigned");
    const taken = this.ctx.storage.sql.exec(
      "SELECT user_id FROM app_users WHERE LOWER(user_id) = LOWER(?) LIMIT 1",
      publicId,
    ).toArray()[0];
    if (taken) throw new Error("Unique ID is already in use");
    const effective = this._effectivePrice(userId, "unique_id:" + publicId, Math.max(0, Number(offer.price_coins || 0)), Math.max(0, Number(offer.duration_days || 0)));
    const price = effective.price;
    const wallet = this.getWallet(userId);
    if (wallet.banned) throw new Error("Wallet is restricted");
    if (wallet.coins < price) throw new Error("Insufficient coin balance");
    const now = Date.now();
    if (price > 0) {
      this.ctx.storage.sql.exec("UPDATE app_wallets SET coins = coins - ?, updated_at = ? WHERE user_id = ?", price, now, userId);
      this.ctx.storage.sql.exec(
        "INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?, 'unique_id_purchase',?,0,?,?,?)",
        crypto.randomUUID(), userId, -price, "unique-id:" + publicId, publicId, now,
      );
    }
    const previousId = userId;
    const changed = this._changeUserId(previousId, publicId);
    const durationDays = effective.duration_days ?? Math.max(0, Number(offer.duration_days || 0));
    const expiresAt = durationDays > 0 ? now + durationDays * 86400000 : null;
    this.ctx.storage.sql.exec(
      "UPDATE owner_unique_ids SET assigned_user_id = ?, assigned_at = ?, expires_at = ?, previous_user_id = ?, updated_at = ? WHERE public_id = ?", publicId, now, expiresAt, previousId, now, publicId,
    );
    if (expiresAt != null) this.ctx.storage.setAlarm(this._nextIndiaMidnightUtc(now));
    return { ok: true, user: changed, public_id: publicId, price_coins: price, duration_days: durationDays, expires_at: expiresAt, permanent: durationDays === 0, wallet: this.getWallet(publicId) };
  }

  purchasableCatalog(kindValue = "", countryCodeValue = "") {
    const kind = cleanText(kindValue, 40).toLowerCase();
    const country = cleanText(countryCodeValue, 8).toUpperCase();
    const now = Date.now();
    return this.ownerCatalog(kind).filter((item) => {
      if (!item.enabled) return false;
      const data = item.data || {};
      if (data.starts_at && Number(data.starts_at) > now) return false;
      if (data.ends_at && Number(data.ends_at) <= now) return false;
      const countries = Array.isArray(data.countries) ? data.countries.map((v) => String(v).toUpperCase()) : [];
      return !country || countries.length === 0 || countries.includes(country);
    }).map((item) => ({ ...item, price_coins: Math.max(0, Number(item.data?.coin_price ?? item.data?.price ?? 0)), duration_days: Math.max(0, Number(item.data?.duration_days ?? 0)) }));
  }

  purchaseCatalogItem(userIdValue, kindValue, itemIdValue, countryCodeValue = "") {
    const userId = this._resolveOwnerUserId(userIdValue);
    const kind = cleanText(kindValue, 40).toLowerCase();
    if (!["entry","vehicle","profile_card","ring","bubble","profile_background"].includes(kind)) {
      throw new Error("Unsupported purchasable item type");
    }
    const item = this.purchasableCatalog(kind, countryCodeValue).find((v) => v.id === String(itemIdValue || "").trim());
    if (!item) throw new Error("Item is unavailable");
    const existing = this.ctx.storage.sql.exec("SELECT item_id FROM user_inventory WHERE user_id = ? AND item_id = ? LIMIT 1", userId, item.id).toArray()[0];
    if (existing) return { ok: true, duplicate: true, inventory: this.inventoryState(userId), wallet: this.getWallet(userId) };
    const effective = this._effectivePrice(userId, kind + ":" + item.id, item.price_coins, item.duration_days);
    const price = effective.price;
    const wallet = this.getWallet(userId);
    if (wallet.banned) throw new Error("Wallet is restricted");
    if (wallet.coins < price) throw new Error("Insufficient coin balance");
    const now = Date.now();
    if (price > 0) {
      this.ctx.storage.sql.exec("UPDATE app_wallets SET coins = coins - ?, updated_at = ? WHERE user_id = ?", price, now, userId);
      this.ctx.storage.sql.exec("INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?,?,?,0,?,?,?)", crypto.randomUUID(), userId, kind + "_purchase", -price, kind + ":" + item.id, item.name, now);
    }
    const durationDays = effective.duration_days ?? item.duration_days;
    const expiresAt = durationDays > 0 ? now + durationDays * 86400000 : null;
    this.ctx.storage.sql.exec("INSERT INTO user_inventory (user_id,item_id,item_kind,acquired_at,expires_at) VALUES (?,?,?,?,?)", userId, item.id, kind, now, expiresAt);
    return { ok: true, duplicate: false, price_coins: price, duration_days: durationDays, expires_at: expiresAt, inventory: this.inventoryState(userId), wallet: this.getWallet(userId) };
  }

  equipCatalogItem(userIdValue, kindValue, itemIdValue) {
    this._ensureEconomyMigrations();
    const userId = this._resolveOwnerUserId(userIdValue);
    const kind = cleanText(kindValue, 40).toLowerCase();
    const columns = {
      vehicle: "equipped_vehicle_id",
      entry: "equipped_entry_id",
      profile_card: "equipped_profile_card_id",
      ring: "equipped_ring_id",
      bubble: "equipped_bubble_id",
      profile_background: "equipped_profile_background_id",
    };
    const column = columns[kind];
    if (!column) throw new Error("Unsupported equippable item type");
    const itemId = itemIdValue == null ? "" : String(itemIdValue).trim();
    if (itemId) {
      const owned = this.ctx.storage.sql.exec(
        "SELECT item_id FROM user_inventory WHERE user_id=? AND item_id=? AND item_kind=? AND (expires_at IS NULL OR expires_at>?) LIMIT 1",
        userId,itemId,kind,Date.now(),
      ).toArray()[0];
      if (!owned) throw new Error("Item is not owned or has expired");
    }
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT OR IGNORE INTO user_equipment(user_id,equipped_frame_id,updated_at) VALUES(?,NULL,?)",
      userId,now,
    );
    this.ctx.storage.sql.exec(
      "UPDATE user_equipment SET " + column + "=?, updated_at=? WHERE user_id=?",
      itemId || null,now,userId,
    );
    return { ok:true, inventory:this.inventoryState(userId) };
  }

  sendCatalogItem(senderUserIdValue, recipientUserIdValue, kindValue, itemIdValue, countryCodeValue = "") {
    const senderId = this._resolveOwnerUserId(senderUserIdValue);
    const recipientId = this._resolveOwnerUserId(recipientUserIdValue);
    const recipientExists = recipientId
      ? this.ctx.storage.sql.exec(
          "SELECT user_id FROM app_users WHERE user_id=? LIMIT 1", recipientId,
        ).toArray()[0]
      : null;
    if (!recipientExists) throw new Error("Recipient user not found");
    if (String(senderId) === String(recipientId)) throw new Error("Use Buy for your own account");
    const kind = cleanText(kindValue, 40).toLowerCase();
    if (!["entry","vehicle","profile_card","ring","bubble","profile_background","frame"].includes(kind)) {
      throw new Error("Unsupported send item type");
    }
    const itemId = String(itemIdValue || "").trim();
    const item = kind === "frame"
      ? this.frameCatalog(countryCodeValue).find((v)=>v.id===itemId)
      : this.purchasableCatalog(kind,countryCodeValue).find((v)=>v.id===itemId);
    if (!item) throw new Error("Item is unavailable");
    const existing = this.ctx.storage.sql.exec(
      "SELECT item_id FROM user_inventory WHERE user_id=? AND item_id=? AND (expires_at IS NULL OR expires_at>?) LIMIT 1",
      recipientId,itemId,Date.now(),
    ).toArray()[0];
    if (existing) throw new Error("Recipient already owns this item");

    const basePrice = kind === "frame"
      ? Math.max(0,Number(item.price ?? item.data?.price ?? item.data?.coin_price ?? 0))
      : Math.max(0,Number(item.price_coins || 0));
    const baseDuration = kind === "frame"
      ? Math.max(0,Number(item.data?.duration_days || 0))
      : Math.max(0,Number(item.duration_days || 0));
    const effective = this._effectivePrice(senderId, kind + ":" + itemId, basePrice, baseDuration);
    const price = effective.price;
    const wallet = this.getWallet(senderId);
    if (wallet.banned) throw new Error("Wallet is restricted");
    if (wallet.coins < price) throw new Error("Insufficient coin balance");
    const now = Date.now();
    if (price > 0) {
      this.ctx.storage.sql.exec(
        "UPDATE app_wallets SET coins=coins-?,updated_at=? WHERE user_id=?",
        price,now,senderId,
      );
      this.ctx.storage.sql.exec(
        "INSERT INTO wallet_transactions(id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES(?,?,?,?,0,?,?,?)",
        crypto.randomUUID(),senderId,"store_item_send",-price,
        kind+":"+itemId,"Sent "+String(item.name||itemId)+" to "+recipientId,now,
      );
    }
    const durationDays = effective.duration_days ?? baseDuration;
    const expiresAt = durationDays > 0 ? now + durationDays * 86400000 : null;
    this.ctx.storage.sql.exec(
      "INSERT INTO user_inventory(user_id,item_id,item_kind,acquired_at,expires_at) VALUES(?,?,?,?,?)",
      recipientId,itemId,kind,now,expiresAt,
    );
    this._notifyUser(
      recipientId,
      "store_item_received",
      "Store gift received",
      "You received " + String(item.name || itemId) + " from ID " + senderId + ".",
      { source_user_id: senderId, metadata: { item_id:itemId, item_kind:kind } },
    );
    return {
      ok:true,
      recipient_user_id:recipientId,
      price_coins:price,
      duration_days:durationDays,
      expires_at:expiresAt,
      wallet:this.getWallet(senderId),
    };
  }

  purchaseFrame(userIdValue, frameIdValue, countryCodeValue = "") {
    const userId = this._resolveOwnerUserId(userIdValue);
    const frameId = String(frameIdValue || "").trim();
    const frame = this.frameCatalog(countryCodeValue).find((item) => item.id === frameId);
    if (!frame) throw new Error("Frame is unavailable");
    const existing = this.ctx.storage.sql.exec(
      "SELECT item_id FROM user_inventory WHERE user_id = ? AND item_id = ? LIMIT 1",
      userId, frameId,
    ).toArray()[0];
    if (existing) return { ok: true, duplicate: true, inventory: this.inventoryState(userId), wallet: this.getWallet(userId) };
    const wallet = this.getWallet(userId);
    const policies = this.ownerState().policies;
    const effective = this._effectivePrice(userId, "frame:" + frameId, Math.max(0, Number(frame.price ?? policies.frame_default_coins ?? 0)), frame.data?.duration_days ?? 0);
    const price = effective.price;
    if (wallet.banned) throw new Error("Wallet is restricted");
    if (wallet.coins < price) throw new Error("Insufficient coin balance");
    const now = Date.now();
    if (price > 0) {
      this.ctx.storage.sql.exec(
        "UPDATE app_wallets SET coins = coins - ?, updated_at = ? WHERE user_id = ?",
        price, now, userId,
      );
      this.ctx.storage.sql.exec(
        "INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?, 'frame_purchase',?,0,?,?,?)",
        crypto.randomUUID(), userId, -price, "frame:" + frameId, frame.name, now,
      );
    }
    this.ctx.storage.sql.exec(
      "INSERT INTO user_inventory (user_id,item_id,item_kind,acquired_at,expires_at) VALUES (?,?, 'frame',?,?)",
      userId, frameId, now, (effective.duration_days ?? 0) > 0 ? now + (effective.duration_days ?? 0) * 86400000 : null,
    );
    return { ok: true, duplicate: false, inventory: this.inventoryState(userId), wallet: this.getWallet(userId) };
  }

  equipFrame(userIdValue, frameIdValue) {
    this._ensureEconomyMigrations();
    const userId = this._resolveOwnerUserId(userIdValue);
    const frameId = frameIdValue == null ? "" : String(frameIdValue).trim();
    if (frameId) {
      const owned = this.ctx.storage.sql.exec(
        "SELECT item_id FROM user_inventory WHERE user_id = ? AND item_id = ? AND item_kind = 'frame' AND (expires_at IS NULL OR expires_at > ?) LIMIT 1",
        userId, frameId, Date.now(),
      ).toArray()[0];
      if (!owned) throw new Error("Frame is not owned");
    }
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO user_equipment (user_id,equipped_frame_id,updated_at)
       VALUES (?,?,?)
       ON CONFLICT(user_id) DO UPDATE SET equipped_frame_id=excluded.equipped_frame_id, updated_at=excluded.updated_at`,
      userId, frameId || null, now,
    );
    return { ok: true, inventory: this.inventoryState(userId) };
  }

  vipState(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const row = this.ctx.storage.sql.exec(
      "SELECT user_id,vip_id,vip_level,starts_at,expires_at,updated_at FROM vip_entitlements WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!row) return null;
    const expiresAt = row.expires_at == null ? null : Number(row.expires_at);
    if (expiresAt != null && expiresAt <= Date.now()) {
      this.ctx.storage.sql.exec("DELETE FROM vip_entitlements WHERE user_id = ?", userId);
      return null;
    }
    return { user_id: userId, vip_id: String(row.vip_id), vip_level: Number(row.vip_level),
      starts_at: Number(row.starts_at), expires_at: expiresAt, updated_at: Number(row.updated_at) };
  }

  vipPurchase(userIdValue, vipIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const vipId = String(vipIdValue || "").trim();
    const item = this.ownerCatalog("vip").find((value) => value.id === vipId && value.enabled !== false);
    if (!item) throw new Error("VIP level is unavailable");
    const level = Math.max(1, Number(item.data?.level || 0));
    const policies = this.ownerState().policies;
    const freeIds = Array.isArray(policies.free_user_ids) ? policies.free_user_ids.map(String) : [];
    const configuredPrice = Math.max(0, Number(item.data?.price ?? item.data?.coin_price ?? policies.vip_default_coins ?? 0));
    const baseDurationDays = Math.max(0, Number(item.data?.duration_days || item.data?.duration || 30));
    const effective = this._effectivePrice(userId, "vip:" + vipId, configuredPrice, baseDurationDays);
    const price = effective.price;
    const durationDays = effective.duration_days ?? baseDurationDays;
    const wallet = this.getWallet(userId);
    if (wallet.banned) throw new Error("Wallet is restricted");
    if (wallet.coins < price) throw new Error("Insufficient coin balance");
    const now = Date.now();
    const current = this.vipState(userId);
    const base = current?.expires_at && current.expires_at > now ? current.expires_at : now;
    const expiresAt = durationDays === 0 ? null : base + durationDays * 86400000;
    if (price > 0) {
      this.ctx.storage.sql.exec("UPDATE app_wallets SET coins = coins - ?, updated_at = ? WHERE user_id = ?", price, now, userId);
      this.ctx.storage.sql.exec(
        "INSERT INTO wallet_transactions (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?, 'vip_purchase',?,0,?,?,?)",
        crypto.randomUUID(), userId, -price, "vip:" + vipId + ":" + now, item.name, now,
      );
    }
    this.ctx.storage.sql.exec(
      `INSERT INTO vip_entitlements (user_id,vip_id,vip_level,starts_at,expires_at,updated_at)
       VALUES (?,?,?,?,?,?)
       ON CONFLICT(user_id) DO UPDATE SET vip_id=excluded.vip_id,vip_level=excluded.vip_level,
         starts_at=excluded.starts_at,expires_at=excluded.expires_at,updated_at=excluded.updated_at`,
      userId, vipId, level, now, expiresAt, now,
    );
    return { ok: true, vip: this.vipState(userId), wallet: this.getWallet(userId) };
  }

  getWallet(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) throw new Error("user ID is required");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT OR IGNORE INTO app_wallets
        (user_id, coins, diamonds, banned, updated_at)
       VALUES (?, 0, 0, 0, ?)`,
      userId,
      now,
    );
    const coinGuard = this._normalWalletGuard(userId);
    const row = this.ctx.storage.sql.exec(
      "SELECT user_id, coins, diamonds, banned, updated_at FROM app_wallets WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    const roles = this._activeHierarchy(userId);
    const isHost = roles.some((item) => item.role === "host");
    const isAgency = roles.some((item) => item.role === "agency");
    const isBd = roles.some((item) => item.role === "bd");
    const storedDiamonds = Number(row?.diamonds || 0);
    const visibleDiamonds = isHost ? storedDiamonds : 0;
    const diamondUsdCents = isHost ? Math.floor(visibleDiamonds * 170 / 4000000) : 0;
    const settlement = this._ensureSettlementBalance(userId);
    const commissionUsdCents = (isAgency || isBd) ? Number(settlement?.usd_cents || 0) : 0;
    const withdrawableUsdCents = diamondUsdCents + commissionUsdCents;
    const privilegedRows = this.ctx.storage.sql.exec(
      "SELECT wallet_type,banned,updated_at FROM owner_wallets WHERE user_id=? AND wallet_type IN ('coin_seller','merchant')",
      userId,
    ).toArray();
    const privileged = {};
    for (const privilegedRow of privilegedRows) {
      const walletType = String(privilegedRow.wallet_type || "");
      if (!["coin_seller","merchant"].includes(walletType)) continue;
      const guard = this._privilegedWalletGuard(userId, walletType);
      privileged[walletType] = {
        active: true,
        balance: guard.security_frozen ? 0 : guard.balance,
        banned: Number(privilegedRow.banned || 0) === 1,
        security_frozen: guard.security_frozen,
        freeze_reason: guard.freeze_reason,
        updated_at: Number(privilegedRow.updated_at || now),
      };
    }
    return {
      user_id: userId,
      coins: coinGuard.security_frozen ? 0 : Number(row?.coins || 0),
      diamonds: visibleDiamonds,
      diamond_wallet_visible: isHost,
      is_host: isHost,
      is_agency: isAgency,
      is_bd: isBd,
      diamond_usd_cents: diamondUsdCents,
      commission_usd_cents: commissionUsdCents,
      withdrawable_usd_cents: withdrawableUsdCents,
      can_transfer_settlement: !coinGuard.security_frozen &&
        (isHost || isAgency || isBd) && withdrawableUsdCents >= 200,
      usd_rate: { reference_diamonds: 4000000, reference_usd_cents: 170 },
      roles,
      banned: Number(row?.banned || 0) === 1,
      security_frozen: coinGuard.security_frozen,
      freeze_reason: coinGuard.freeze_reason,
      coin_seller_wallet: privileged.coin_seller || null,
      merchant_wallet: privileged.merchant || null,
      updated_at: Number(row?.updated_at || now),
    };
  }

  settlementRecipient(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) throw new Error("Recipient ID is required");
    const user = this.ctx.storage.sql.exec(
      "SELECT user_id,display_name,avatar_data_url FROM app_users WHERE user_id=? LIMIT 1",
      userId,
    ).toArray()[0];
    if (!user) throw new Error("User not found");
    const roleRow = this.ctx.storage.sql.exec(
      "SELECT wallet_type FROM owner_wallets WHERE user_id=? AND wallet_type IN ('coin_seller','merchant') AND banned=0 ORDER BY CASE wallet_type WHEN 'coin_seller' THEN 0 ELSE 1 END LIMIT 1",
      userId,
    ).toArray()[0];
    if (!roleRow) throw new Error("Recipient must be an active Coin Seller or Merchant");
    return {
      user_id: String(user.user_id),
      display_name: String(user.display_name || user.user_id),
      avatar_data_url: user.avatar_data_url ? String(user.avatar_data_url) : null,
      role: String(roleRow.wallet_type),
    };
  }

  transferSettlement(senderUserIdValue, recipientUserIdValue, usdCentsValue) {
    const senderId = this._resolveOwnerUserId(senderUserIdValue);
    this._enforceActionRate(senderId, "settlement_transfer", 5, 60000, 300000);
    const recipient = this.settlementRecipient(recipientUserIdValue);
    const usdCents = Math.floor(Number(usdCentsValue || 0));
    if (usdCents < 200) throw new Error("Minimum transfer is $2");
    if (senderId === recipient.user_id) throw new Error("Cannot transfer to your own account");

    const wallet = this.getWallet(senderId);
    if (!(wallet.is_host || wallet.is_agency || wallet.is_bd)) {
      throw new Error("Only Host, Agency or BD settlement can be transferred");
    }
    if (wallet.withdrawable_usd_cents < usdCents) {
      throw new Error("Settlement balance is not enough");
    }

    let remaining = usdCents;
    let diamondsDebited = 0;
    const commissionRow = this._ensureSettlementBalance(senderId);
    const commissionCents = Number(commissionRow?.usd_cents || 0);
    const commissionDebit = Math.min(remaining, commissionCents);
    if (commissionDebit > 0) {
      this.ctx.storage.sql.exec(
        "UPDATE settlement_balances SET usd_cents=usd_cents-?,updated_at=? WHERE user_id=?",
        commissionDebit, Date.now(), senderId,
      );
      remaining -= commissionDebit;
    }
    if (remaining > 0) {
      if (!wallet.is_host) throw new Error("Settlement balance is not enough");
      diamondsDebited = Math.ceil(remaining * 4000000 / 170);
      if (diamondsDebited > wallet.diamonds) throw new Error("Diamond balance is not enough");
      this.ctx.storage.sql.exec(
        "UPDATE app_wallets SET diamonds=diamonds-?,updated_at=? WHERE user_id=?",
        diamondsDebited, Date.now(), senderId,
      );
    }

    this._ensureSettlementBalance(recipient.user_id);
    this.ctx.storage.sql.exec(
      "UPDATE settlement_balances SET usd_cents=usd_cents+?,updated_at=? WHERE user_id=?",
      usdCents, Date.now(), recipient.user_id,
    );
    const id = "settle-" + crypto.randomUUID();
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT INTO settlement_transfers(id,sender_user_id,recipient_user_id,recipient_role,usd_cents,diamonds_debited,created_at) VALUES (?,?,?,?,?,?,?)",
      id, senderId, recipient.user_id, recipient.role, usdCents, diamondsDebited, now,
    );
    this.ctx.storage.sql.exec(
      "INSERT INTO wallet_transactions(id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?,'settlement_transfer',0,?,?,?,?,?)",
      "wallet-" + crypto.randomUUID(), senderId, -diamondsDebited, id,
      "Transferred $" + (usdCents / 100).toFixed(2) + " to " + recipient.user_id, now,
    );
    return { ok: true, transfer_id: id, recipient, usd_cents: usdCents, diamonds_debited: diamondsDebited, wallet: this.getWallet(senderId) };
  }

  settlementTransfers(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    return this.ctx.storage.sql.exec(
      "SELECT * FROM settlement_transfers WHERE sender_user_id=? ORDER BY created_at DESC LIMIT 200",
      userId,
    ).toArray().map((row) => ({
      id: String(row.id), sender_user_id: String(row.sender_user_id),
      recipient_user_id: String(row.recipient_user_id),
      recipient_role: String(row.recipient_role),
      usd_cents: Number(row.usd_cents || 0),
      diamonds_debited: Number(row.diamonds_debited || 0),
      created_at: Number(row.created_at || 0),
    }));
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
    const policies = this.ownerState().policies;
    const freeIds = Array.isArray(policies.free_user_ids) ? policies.free_user_ids.map(String) : [];
    const directCostPerMinute = this._effectivePrice(callerId, "call:direct", Math.max(0, Number(policies.direct_call_coins ?? VERIFIED_DIRECT_CALL_COST_COINS_PER_MINUTE))).price;
    const rewardPercent = Math.max(0, Math.min(100, Number(policies.receiver_percent ?? VERIFIED_RECEIVER_REWARD_PERCENT)));
    const receiverRewardPerMinute = receiverFemale && receiverVerification.verified
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
    const caller = this.ctx.storage.sql.exec(
      "SELECT display_name FROM app_users WHERE user_id=? LIMIT 1", callerId,
    ).toArray()[0];
    this._notifyUser(
      receiverId,
      "incoming_call",
      "Incoming " + media + " call",
      String(caller?.display_name || callerId) + " is calling you.",
      { source_user_id: callerId, metadata: { call_id: id, media } },
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

    const policies = this.ownerState().policies;
    const freeIds = Array.isArray(policies.free_user_ids) ? policies.free_user_ids.map(String) : [];
    const randomCostPerMinute = this._effectivePrice(callerId, "call:random", Math.max(0, Number(policies.random_call_coins ?? RANDOM_CALL_COST_COINS_PER_MINUTE))).price;
    const rewardPercent = Math.max(0, Math.min(100, Number(policies.receiver_percent ?? VERIFIED_RECEIVER_REWARD_PERCENT)));
    const callerWallet = this.getWallet(callerId);
    if (callerWallet.coins < randomCostPerMinute) {
      throw new Error("At least " + randomCostPerMinute.toLocaleString("en-US") + " coins are required to start a random call");
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
          randomCostPerMinute * rewardPercent / 100
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
      randomCostPerMinute,
      receiverRewardPerMinute,
      now,
      now,
    );
    this._sendCallOfficialMessage(receiverId, {
      call_kind: "random",
      verified: receiverVerification.verified === true,
      gender: receiverVerification.gender,
      cost_coins_per_minute: randomCostPerMinute,
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
        : "Your ID is Unverified. You can answer this call, but paid-call receiver earnings stay at 0 until verification is approved. ";
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

  reportCallPrivacyIncident(userIdValue, callIdValue, actionValue) {
    const userId = String(userIdValue || "").trim();
    const action = String(actionValue || "").trim().toLowerCase();
    if (!["screenshot", "screen_recording"].includes(action)) {
      throw new Error("Unsupported privacy incident");
    }
    const call = this.getCall(callIdValue);
    if (!call) throw new Error("Call not found");
    if (call.caller_id !== userId && call.receiver_id !== userId) {
      throw new Error("Not a call participant");
    }
    if (call.state !== "accepted" || call.media !== "video") {
      throw new Error("Privacy incident requires an active video call");
    }
    const actorName = userId === call.caller_id ? call.caller_name : call.receiver_name;
    const now = Date.now();
    const id = "privacy-" + crypto.randomUUID();
    this.ctx.storage.sql.exec(
      `INSERT INTO call_privacy_incidents
        (id, call_id, actor_user_id, actor_name, action, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
      id, call.id, userId, actorName, action, now,
    );
    this.ctx.storage.sql.exec(
      "UPDATE app_calls SET media = 'voice', updated_at = ? WHERE id = ?",
      now, call.id,
    );
    return this.getCall(call.id);
  }

  latestCallPrivacyIncident(callIdValue) {
    const callId = String(callIdValue || "").trim();
    const row = this.ctx.storage.sql.exec(
      `SELECT id, actor_user_id, actor_name, action, created_at
         FROM call_privacy_incidents
        WHERE call_id = ?
        ORDER BY created_at DESC LIMIT 1`,
      callId,
    ).toArray()[0];
    return row ? {
      id: String(row.id),
      actor_user_id: String(row.actor_user_id),
      actor_name: String(row.actor_name),
      action: String(row.action),
      created_at: Number(row.created_at),
    } : null;
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
    } else if (call.state === "ringing") {
      const otherId = call.caller_id === userId ? call.receiver_id : call.caller_id;
      this._notifyUser(
        otherId,
        "missed_call",
        "Missed call",
        "You missed a " + String(call.media || "voice") + " call.",
        { source_user_id: userId, metadata: { call_id: call.id } },
      );
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

  unreadMessageCount(userIdValue) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return 0;
    const row = this.ctx.storage.sql.exec(
      `SELECT COUNT(*) AS count
         FROM direct_messages
        WHERE to_user_id = ?
          AND seen_at IS NULL`,
      userId,
    ).toArray()[0];
    return Number(row?.count || 0);
  }

  _notifyMessageSocket(userIdValue, payload = {}) {
    const userId = String(userIdValue || "").trim();
    if (!userId) return;
    const message = JSON.stringify({
      ...payload,
      unread_count: this.unreadMessageCount(userId),
    });
    for (const socket of this.ctx.getWebSockets("message-user:" + userId)) {
      try {
        socket.send(message);
      } catch (_) {
        // Closed sockets are cleaned up by the Durable Object runtime.
      }
    }
  }

  async fetch(request) {
    if ((request.headers.get("upgrade") || "").toLowerCase() !== "websocket") {
      return new Response("WebSocket required", { status: 426 });
    }
    const userId = String(request.headers.get("x-tinni-user-id") || "").trim();
    if (!userId) return new Response("Unauthorized", { status: 401 });

    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    this.ctx.acceptWebSocket(server, ["message-user:" + userId]);
    server.send(JSON.stringify({
      type: "inbox_state",
      unread_count: this.unreadMessageCount(userId),
    }));
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage(socket, message) {
    if (String(message || "") === "ping") {
      try {
        socket.send(JSON.stringify({ type: "pong" }));
      } catch (_) {}
    }
  }

  webSocketClose() {}

  webSocketError() {}

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
    this._notifyMessageSocket(userId, {
      type: "messages_seen",
      peer_user_id: peerUserId,
    });
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

  _notifyUser(userIdValue, typeValue, titleValue, messageValue, options = {}) {
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) return null;
    const type = cleanText(typeValue, 60) || "general";
    const title = cleanText(titleValue, 120) || "Tinni Star";
    const message = cleanText(messageValue, 1000);
    if (!message) return null;
    const id = "notice-" + crypto.randomUUID();
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT INTO user_notifications(id,user_id,type,source_user_id,title,message,metadata_json,read_at,created_at) VALUES (?,?,?,?,?,?,?,NULL,?)",
      id, userId, type,
      options.source_user_id ? String(options.source_user_id) : null,
      title, message, JSON.stringify(options.metadata || {}), now,
    );
    return { id, user_id: userId, type, title, message, created_at: now };
  }

  dispatchEventNotifications(nowValue = Date.now(), onlyUserIdValue = "") {
    const now = Number(nowValue || Date.now());
    const eventRows = this.ctx.storage.sql.exec(
      `SELECT id,kind,name,data_json,created_at,updated_at
         FROM owner_catalog
        WHERE enabled = 1
          AND kind IN ('event','activity','reward_event')
        ORDER BY created_at DESC
        LIMIT 200`,
    ).toArray();
    if (!eventRows.length) return { ok: true, sent: 0 };

    const onlyUserId = this._resolveOwnerUserId(onlyUserIdValue);
    const users = onlyUserId
      ? this.ctx.storage.sql.exec(
          "SELECT user_id,country_code FROM app_users WHERE user_id=? LIMIT 1",
          onlyUserId,
        ).toArray()
      : this.ctx.storage.sql.exec(
          "SELECT user_id,country_code FROM app_users ORDER BY created_at DESC",
        ).toArray();
    const dayStart = now - 24 * 60 * 60 * 1000;
    let sent = 0;

    for (const row of eventRows) {
      let data = {};
      try { data = JSON.parse(String(row.data_json || "{}")); } catch {}
      const startsAt = Number(data.starts_at || data.start_at || 0);
      const endsAt = Number(data.ends_at || data.end_at || 0);
      const createdAt = Number(row.created_at || 0);
      const isReward = String(row.kind) === "reward_event";
      const phases = [];

      if (createdAt > 0 && createdAt <= now && now - createdAt <= 24 * 60 * 60 * 1000) {
        phases.push(["new", createdAt]);
      }
      if (startsAt > 0 && startsAt <= now && now - startsAt <= 24 * 60 * 60 * 1000) {
        phases.push(["start", startsAt]);
      }
      if (endsAt > 0 && endsAt <= now && now - endsAt <= 24 * 60 * 60 * 1000) {
        phases.push(["end", endsAt]);
      }
      if (!phases.length) continue;

      const targetedCountries = Array.isArray(data.countries)
        ? new Set(data.countries.map((value) => String(value || "").trim().toUpperCase()).filter(Boolean))
        : new Set();
      const title = cleanText(row.name, 120) || (isReward ? "Reward event" : "Tinni Star event");

      for (const [phase] of phases) {
        for (const user of users) {
          const userId = String(user.user_id || "");
          const country = String(user.country_code || "").toUpperCase();
          if (!userId) continue;
          if (targetedCountries.size && !targetedCountries.has(country)) continue;

          const already = this.ctx.storage.sql.exec(
            "SELECT event_id FROM event_notification_dispatches WHERE event_id=? AND phase=? AND user_id=? LIMIT 1",
            String(row.id), phase, userId,
          ).toArray()[0];
          if (already) continue;

          const countRow = this.ctx.storage.sql.exec(
            `SELECT COUNT(*) AS count
               FROM user_notifications
              WHERE user_id=?
                AND created_at>=?
                AND type IN ('event_new','event_start','event_end','reward_new','reward_start','reward_end')`,
            userId, dayStart,
          ).toArray()[0];
          if (Number(countRow?.count || 0) >= 15) continue;

          const type = (isReward ? "reward_" : "event_") + phase;
          const message = phase === "new"
            ? title + " is available."
            : phase === "start"
              ? title + " has started."
              : title + " has ended.";
          const notice = this._notifyUser(
            userId,
            type,
            title,
            message,
            {
              metadata: {
                event_id: String(row.id),
                event_kind: String(row.kind),
                phase,
                starts_at: startsAt || null,
                ends_at: endsAt || null,
              },
            },
          );
          if (!notice) continue;
          this.ctx.storage.sql.exec(
            "INSERT OR IGNORE INTO event_notification_dispatches(event_id,phase,user_id,dispatched_at) VALUES (?,?,?,?)",
            String(row.id), phase, userId, now,
          );
          sent += 1;
        }
      }
    }

    return { ok: true, sent };
  }

  listUserNotifications(userIdValue, limitValue = 200) {
    const userId = this._resolveOwnerUserId(userIdValue);
    this.dispatchEventNotifications(Date.now(), userId);
    const limit = Math.max(1, Math.min(300, Number(limitValue || 200)));
    return this.ctx.storage.sql.exec(
      "SELECT * FROM user_notifications WHERE user_id=? ORDER BY created_at DESC LIMIT ?",
      userId, limit,
    ).toArray().map((row) => {
      let metadata = {};
      try { metadata = JSON.parse(String(row.metadata_json || "{}")); } catch {}
      return {
        id: String(row.id), type: String(row.type),
        source_user_id: row.source_user_id ? String(row.source_user_id) : null,
        title: String(row.title), message: String(row.message), metadata,
        read: row.read_at != null, read_at: row.read_at == null ? null : Number(row.read_at),
        created_at: Number(row.created_at || 0),
      };
    });
  }

  markUserNotificationRead(userIdValue, notificationIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const id = String(notificationIdValue || "").trim();
    if (!id) throw new Error("Notification ID is required");
    this.ctx.storage.sql.exec(
      "UPDATE user_notifications SET read_at=? WHERE id=? AND user_id=?",
      Date.now(), id, userId,
    );
    return { ok: true };
  }

  notifyFollowersOnline(userIdValue, roomIdValue = "") {
    const userId = this._resolveOwnerUserId(userIdValue);
    const user = this.ctx.storage.sql.exec(
      "SELECT display_name FROM app_users WHERE user_id=? LIMIT 1", userId,
    ).toArray()[0];
    if (!user) return { notified: 0 };
    const cutoff = Date.now() - 30 * 60 * 1000;
    const followers = this.ctx.storage.sql.exec(
      "SELECT follower_id FROM app_follows WHERE target_id=?",
      userId,
    ).toArray();
    let notified = 0;
    for (const row of followers) {
      const followerId = String(row.follower_id || "");
      const recent = this.ctx.storage.sql.exec(
        "SELECT id FROM user_notifications WHERE user_id=? AND type='followed_online' AND source_user_id=? AND created_at>=? LIMIT 1",
        followerId, userId, cutoff,
      ).toArray()[0];
      if (recent) continue;
      this._notifyUser(
        followerId,
        "followed_online",
        "Now online",
        String(user.display_name || userId) + " is online now.",
        { source_user_id: userId, metadata: { room_id: String(roomIdValue || "") } },
      );
      notified += 1;
    }
    return { notified };
  }

  transferCoinsFromSeller(senderUserIdValue, recipientUserIdValue, amountValue, walletTypeValue = "") {
    const senderId = this._resolveOwnerUserId(senderUserIdValue);
    this._enforceActionRate(senderId, "seller_coin_transfer", 10, 60000, 300000);
    const recipientId = this._resolveOwnerUserId(recipientUserIdValue);
    const amount = Math.floor(Number(amountValue || 0));
    if (!senderId || !recipientId) throw new Error("Sender and recipient IDs are required");
    if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error("Enter a valid coin amount");

    const requestedWalletType = String(walletTypeValue || "").trim().toLowerCase();
    if (requestedWalletType && !["coin_seller","merchant"].includes(requestedWalletType)) {
      throw new Error("Unsupported sender wallet type");
    }
    const walletRows = requestedWalletType
      ? this.ctx.storage.sql.exec(
          "SELECT wallet_type,banned FROM owner_wallets WHERE user_id=? AND wallet_type=? LIMIT 1",
          senderId, requestedWalletType,
        ).toArray()
      : this.ctx.storage.sql.exec(
          "SELECT wallet_type,banned FROM owner_wallets WHERE user_id=? AND wallet_type IN ('coin_seller','merchant') ORDER BY CASE wallet_type WHEN 'coin_seller' THEN 0 ELSE 1 END",
          senderId,
        ).toArray();
    let source = null;
    for (const row of walletRows) {
      if (Number(row.banned || 0) === 1) continue;
      const guard = this._privilegedWalletGuard(senderId, row.wallet_type);
      if (!guard.security_frozen && guard.balance >= amount) {
        source = guard;
        break;
      }
    }
    if (!source) throw new Error("Active funded Coin Seller or Merchant wallet is required");

    const recipient = this.ctx.storage.sql.exec(
      "SELECT user_id,display_name FROM app_users WHERE user_id=? LIMIT 1", recipientId,
    ).toArray()[0];
    if (!recipient) throw new Error("Recipient not found");
    const recipientGuard = this._normalWalletGuard(recipientId);
    if (recipientGuard.security_frozen) {
      throw new Error("Recipient wallet is security-frozen. Owner unfreeze is required.");
    }

    const debited = this._debitPrivilegedWalletAuthorized(senderId, source.wallet_type, amount);
    this._creditNormalWalletAuthorized(
      recipientId,
      amount,
      source.wallet_type === "merchant" ? "merchant_transfer" : "coin_seller_transfer",
    );

    const now = Date.now();
    const reference = source.wallet_type + "-transfer:" + crypto.randomUUID();
    this.ctx.storage.sql.exec(
      "INSERT INTO wallet_transactions(id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES (?,?,?, ?,0,?,?,?)",
      "wallet-" + crypto.randomUUID(),
      recipientId,
      source.wallet_type === "merchant" ? "merchant_received" : "coin_seller_received",
      amount,
      reference,
      "Coins received from " + String(source.wallet_type).replaceAll("_", " "),
      now,
    );
    this._notifyUser(
      recipientId,
      "coins_received",
      "Coins received",
      amount.toLocaleString("en-US") + " coins received from " + String(source.wallet_type).replaceAll("_", " ") + ".",
      { source_user_id: senderId, metadata: { amount_coins: amount, sender_role: String(source.wallet_type) } },
    );
    return {
      ok: true,
      recipient_wallet: this.getWallet(recipientId),
      sender_wallet_type: source.wallet_type,
      sender_balance: debited.balance,
      self_transfer: senderId === recipientId,
    };
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
    const sender = this.ctx.storage.sql.exec(
      "SELECT display_name FROM app_users WHERE user_id=? LIMIT 1", fromUserId,
    ).toArray()[0];
    this._notifyUser(
      toUserId,
      "message",
      String(sender?.display_name || fromUserId),
      text,
      { source_user_id: fromUserId, metadata: { message_id: id } },
    );
    const message = {
      id,
      from: fromUserId,
      from_name: String(sender?.display_name || fromUserId),
      to: toUserId,
      text,
      created_at: now,
      seen_at: null,
    };
    this._notifyMessageSocket(toUserId, {
      type: "message_received",
      message,
    });
    return message;
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

    const message = {
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
    this._notifyMessageSocket(toUserId, {
      type: "message_received",
      message,
    });
    return message;
  }

    async listRooms() {
    this._pruneRoomThemes();
    return this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name,
              u.avatar_data_url AS owner_avatar_data_url,
              u.flag_emoji AS owner_flag_emoji,
              COALESCE(pc.member_count, 0) AS member_count,
              COALESCE(pc.member_count, 0) * 500 AS active_user_exp,
              COALESCE(gx.gift_coins, 0) AS sending_exp,
              COALESCE(gx.gift_coins, 0) AS receiving_exp,
              (COALESCE(pc.member_count, 0) * 500)
                + (COALESCE(gx.gift_coins, 0) * 2) AS room_experience
         FROM app_rooms r
         JOIN app_users u ON u.user_id = r.owner_id
         LEFT JOIN app_room_presence_counts pc ON pc.room_id = r.id
         LEFT JOIN (
           SELECT room_id, COALESCE(SUM(total_cost), 0) AS gift_coins
             FROM gift_transactions
            GROUP BY room_id
         ) gx ON gx.room_id = r.id
        WHERE COALESCE(r.closed, 0) = 0
          AND COALESCE(r.locked, 0) = 0
        ORDER BY room_experience DESC,
                 COALESCE(pc.member_count, 0) DESC,
                 r.created_at DESC
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

    const { name, asset } = validateRoomThemePolicy(input?.name, input?.asset);
    const permanent = input?.permanent === true;
    const durationDays = permanent ? null : Number(input?.duration_days);
    if (!permanent && (!Number.isInteger(durationDays) || !ROOM_THEME_DURATION_DAYS.has(durationDays))) {
      throw new Error("Custom background duration must be 7, 10, 15 or 30 days, or Permanent");
    }

    // Price is controlled by server/Owner settings, never by the APK.
    const policy = this._getSetting("room_theme_user_policy", {
      prices: { "7": 10000000, "10": 14000000, "15": 20000000, "30": 35000000, permanent: 100000000 },
    });
    const priceKey = permanent ? "permanent" : String(durationDays);
    const ownerPolicies = this.ownerState().policies;
    const configuredThemePrice = Number(policy?.prices?.[priceKey] ?? (permanent ? null : ownerPolicies.room_theme_coins));
    const themeEffective = this._effectivePrice(userId, "room_theme:" + priceKey, configuredThemePrice, permanent ? 0 : durationDays);
    const priceCoins = themeEffective.price;
    if (!Number.isSafeInteger(priceCoins) || priceCoins < 0) {
      throw new Error("Custom background price is not configured");
    }

    const wallet = this.getWallet(userId);
    if (wallet.banned) throw new Error("Wallet is unavailable");
    if (wallet.coins < priceCoins) throw new Error("Insufficient coins");

    const now = Date.now();
    const id = "theme-user-" + roomId + "-" + now.toString(36) + "-" + crypto.randomUUID().slice(0, 8);
    const effectiveThemeDays = themeEffective.duration_days ?? (permanent ? 0 : durationDays);
    const expiresAt = effectiveThemeDays === 0 ? null : now + effectiveThemeDays * 24 * 60 * 60 * 1000;

    if (priceCoins > 0) {
      this.ctx.storage.sql.exec(
        "UPDATE app_wallets SET coins = coins - ?, updated_at = ? WHERE user_id = ?",
        priceCoins, now, userId,
      );
      this.ctx.storage.sql.exec(
        `INSERT INTO wallet_transactions
          (id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at)
         VALUES (?, ?, 'room_theme_purchase', ?, 0, ?, 'Room theme purchase', ?)`,
        "wallet-theme-" + crypto.randomUUID(),
        userId,
        -priceCoins,
        id,
        now,
      );
    }

    this.ctx.storage.sql.exec(
      `INSERT INTO room_themes
        (id, name, asset, source, room_id, creator_user_id, price_coins,
         created_at, starts_at, expires_at, enabled)
       VALUES (?, ?, ?, 'user', ?, ?, ?, ?, ?, ?, 1)`,
      id, name, asset, roomId, userId, priceCoins, now, now, expiresAt,
    );

    return rowToRoomTheme(
      this.ctx.storage.sql.exec("SELECT * FROM room_themes WHERE id = ? LIMIT 1", id).toArray()[0],
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

    // Personal block rule: if the room owner blocked this user, the blocked
    // user cannot enter the owner's room. A block created by the visitor
    // against the owner does not prevent the visitor from entering.
    const ownerBlockedVisitor = this.ctx.storage.sql.exec(
      `SELECT blocker_id
         FROM app_blocks
        WHERE blocker_id = ? AND target_id = ?
        LIMIT 1`,
      String(room.owner_id),
      userId,
    ).toArray()[0];
    if (ownerBlockedVisitor) {
      return { ok: true, allowed: false, reason: "blocked_by_room_owner" };
    }

    const privacy = String(room.privacy || "public").toLowerCase();
    if (privacy === "private" || privacy === "invite") {
      const invite = this.ctx.storage.sql.exec(
        "SELECT user_id FROM app_room_invites WHERE room_id = ? AND user_id = ? LIMIT 1",
        roomId, userId,
      ).toArray()[0];
      if (!invite) return { ok: true, allowed: false, reason: "invite_required", privacy };
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

  setRoomInvite(roomIdValue, targetUserIdValue, invitedByValue, enabledValue = true) {
    const roomId = String(roomIdValue || "").trim();
    const targetUserId = String(targetUserIdValue || "").trim();
    const invitedBy = String(invitedByValue || "").trim();
    if (!roomId || !targetUserId || !invitedBy) throw new Error("room_id, target_user_id and invited_by are required");
    if (!this._roomRow(roomId)) throw new Error("Room not found");
    if (!this.ctx.storage.sql.exec("SELECT user_id FROM app_users WHERE user_id = ? LIMIT 1", targetUserId).toArray()[0]) throw new Error("Target user not found");
    if (enabledValue === true) {
      this.ctx.storage.sql.exec(
        `INSERT INTO app_room_invites (room_id, user_id, invited_by, created_at) VALUES (?, ?, ?, ?) ON CONFLICT(room_id, user_id) DO UPDATE SET invited_by = excluded.invited_by, created_at = excluded.created_at`,
        roomId, targetUserId, invitedBy, Date.now(),
      );
    } else {
      this.ctx.storage.sql.exec("DELETE FROM app_room_invites WHERE room_id = ? AND user_id = ?", roomId, targetUserId);
    }
    return { ok: true, room_id: roomId, target_user_id: targetUserId, invited: enabledValue === true };
  }

  async updateRoom(ownerIdValue, roomIdValue, input = {}) {
    const ownerId = String(ownerIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    const room = this._roomRow(roomId);
    if (!room) throw new Error("Room not found");
    if (String(room.owner_id) !== ownerId) throw new Error("Only the room owner can edit room settings");

    const title = input.title === undefined ? String(room.title) : cleanText(input.title, 60);
    const announcement = input.announcement === undefined ? String(room.announcement || "") : cleanText(input.announcement, 500);
    const category = input.category === undefined ? String(room.category || "") : cleanText(input.category, 40);
    const countryCode = input.country_code === undefined ? String(room.country_code) : cleanText(input.country_code, 8).toUpperCase();
    const countryName = input.country_name === undefined ? String(room.country_name) : cleanText(input.country_name, 80);
    const flagEmoji = input.flag_emoji === undefined ? String(room.flag_emoji) : cleanText(input.flag_emoji, 16);
    const seatCount = input.seat_count === undefined ? Number(room.seat_count) : Number(input.seat_count);
    const partyMode = input.party_mode === undefined ? String(room.party_mode) : cleanText(input.party_mode, 40);
    const privacy = input.privacy === undefined ? String(room.privacy || "public") : String(input.privacy || "").trim().toLowerCase();
    const closed = input.closed === undefined ? Number(room.closed || 0) === 1 : input.closed === true;
    const photoDataUrl = input.photo_data_url === undefined ? room.photo_data_url : (input.photo_data_url ? String(input.photo_data_url) : null);
    const seatThemeId = input.seat_theme_id === undefined
      ? String(room.seat_theme_id || "royal-gold")
      : String(input.seat_theme_id || "").trim();
    if (!title) throw new Error("Room name is required");
    if (!Number.isInteger(seatCount) || ![8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42].includes(seatCount)) throw new Error("Room capacity must be 8-42 seats");
    if (!["public", "private", "invite"].includes(privacy)) throw new Error("privacy must be public, private or invite");
    if (photoDataUrl && (photoDataUrl.length > MAX_AVATAR_DATA_LENGTH || !photoDataUrl.startsWith("data:image/"))) throw new Error("Room photo is invalid");
    if (!["royal-gold", "neon-blue", "rose-glow"].includes(seatThemeId)) throw new Error("Mic theme is invalid");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `UPDATE app_rooms SET title = ?, announcement = ?, category = ?, country_code = ?, country_name = ?, flag_emoji = ?, seat_count = ?, party_mode = ?, privacy = ?, closed = ?, photo_data_url = ?, seat_theme_id = ?, updated_at = ? WHERE id = ?`,
      title, announcement, category, countryCode, countryName, flagEmoji, seatCount, partyMode, privacy, closed ? 1 : 0, photoDataUrl, seatThemeId, now, roomId,
    );
    const updated = this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name, u.avatar_data_url AS owner_avatar_data_url, u.flag_emoji AS owner_flag_emoji FROM app_rooms r JOIN app_users u ON u.user_id = r.owner_id WHERE r.id = ? LIMIT 1`, roomId,
    ).toArray()[0];
    return { ok: true, room: rowToRoom(updated) };
  }

  async updateRoomSeatCount(actorIdValue, roomIdValue, seatCountValue, isAdminValue = false) {
    const actorId = String(actorIdValue || "").trim();
    const roomId = String(roomIdValue || "").trim();
    const seatCount = Number(seatCountValue);
    const room = this._roomRow(roomId);
    if (!room) throw new Error("Room not found");
    const allowed = [8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42];
    if (!Number.isInteger(seatCount) || !allowed.includes(seatCount)) {
      throw new Error("Room seat count must be 8-42");
    }

    const isOwner = String(room.owner_id) === actorId;
    const isAdmin = isAdminValue === true;
    if (!isOwner && !isAdmin) throw new Error("Only room owner/admin can change seat count");

    const current = Number(room.seat_count);
    if (!isOwner && seatCount < current) {
      throw new Error("Room admin can increase seat count but cannot decrease it");
    }

    const now = Date.now();
    this.ctx.storage.sql.exec(
      "UPDATE app_rooms SET seat_count = ?, updated_at = ? WHERE id = ?",
      seatCount, now, roomId,
    );
    const updated = this.ctx.storage.sql.exec(
      `SELECT r.*, u.display_name AS owner_name, u.avatar_data_url AS owner_avatar_data_url,
              u.flag_emoji AS owner_flag_emoji
         FROM app_rooms r JOIN app_users u ON u.user_id = r.owner_id
        WHERE r.id = ? LIMIT 1`,
      roomId,
    ).toArray()[0];
    return { ok: true, room: rowToRoom(updated) };
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
      if (!/^\\d{5}$/.test(password)) {
        throw new Error("Room password must be exactly 5 digits");
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

  _familyLevelThresholds() {
    const policies = this.ownerState().policies || {};
    const configured = Array.isArray(policies.family_level_thresholds)
      ? policies.family_level_thresholds
          .map((value) => Math.max(0, Math.floor(Number(value || 0))))
          .filter(Number.isSafeInteger)
      : [];
    if (configured.length >= 2 && configured[0] === 0) return configured;
    // Tinni Star family thresholds currently locked by product rules.
    return [
      0,
      50000000,
      240000000,
      580000000,
      970000000,
      1300000000,
      1800000000,
      2500000000,
      3500000000,
      6000000000,
      15000000000,
    ];
  }

  _familyLevelInfo(experienceValue) {
    const experience = Math.max(0, Math.floor(Number(experienceValue || 0)));
    const thresholds = this._familyLevelThresholds();
    let level = 1;
    for (let index = 1; index < thresholds.length; index += 1) {
      if (experience >= thresholds[index]) level = index + 1;
      else break;
    }
    const currentThreshold = thresholds[Math.max(0, level - 1)] || 0;
    const nextThreshold = level < thresholds.length ? thresholds[level] : null;
    const span = nextThreshold == null ? 0 : Math.max(1, nextThreshold - currentThreshold);
    const progress = nextThreshold == null
      ? 1
      : Math.max(0, Math.min(1, (experience - currentThreshold) / span));
    const bonusBasisPoints = 100 + Math.max(0, Math.min(10, level - 1)) * 25;
    return {
      level,
      experience,
      current_threshold: currentThreshold,
      next_threshold: nextThreshold,
      progress,
      monthly_bonus_basis_points: bonusBasisPoints,
      monthly_bonus_percent: bonusBasisPoints / 100,
    };
  }

  _familyMembership(userIdValue) {
    this._ensureEconomyMigrations();
    const userId = this._resolveOwnerUserId(userIdValue);
    if (!userId) return null;
    return this.ctx.storage.sql.exec(
      `SELECT fm.family_id, fm.user_id, fm.role, f.name, f.tag, f.notice,
              f.leader_user_id, f.experience, f.wallet_coins
         FROM family_members fm
         JOIN families f ON f.id = fm.family_id
        WHERE fm.user_id = ?
        LIMIT 1`,
      userId,
    ).toArray()[0] || null;
  }

  _familyCanReview(actorUserIdValue, familyIdValue) {
    const actor = this._familyMembership(actorUserIdValue);
    return Boolean(
      actor &&
      String(actor.family_id) === String(familyIdValue) &&
      (String(actor.role) === "leader" || String(actor.role) === "admin")
    );
  }

  _familyPreviousIndiaMonthWindow(timestampValue = Date.now()) {
    const shifted = new Date(Number(timestampValue) + 19800000);
    const year = shifted.getUTCFullYear();
    const month = shifted.getUTCMonth();
    const currentStartShifted = Date.UTC(year, month, 1);
    const previousStartShifted = Date.UTC(year, month - 1, 1);
    const previous = new Date(previousStartShifted);
    const monthKey =
      previous.getUTCFullYear().toString().padStart(4, "0") + "-" +
      (previous.getUTCMonth() + 1).toString().padStart(2, "0");
    return {
      month_key: monthKey,
      start_at: previousStartShifted - 19800000,
      end_at: currentStartShifted - 19800000,
    };
  }

  _settleFamilyMonthlyBonus(familyIdValue, timestampValue = Date.now()) {
    const familyId = String(familyIdValue || "").trim();
    if (!familyId) return null;
    const window = this._familyPreviousIndiaMonthWindow(timestampValue);
    const existing = this.ctx.storage.sql.exec(
      "SELECT * FROM family_monthly_bonuses WHERE family_id=? AND month_key=? LIMIT 1",
      familyId, window.month_key,
    ).toArray()[0];
    if (existing) {
      return {
        month_key: String(existing.month_key),
        received_coins: Number(existing.received_coins || 0),
        bonus_basis_points: Number(existing.bonus_basis_points || 0),
        bonus_coins: Number(existing.bonus_coins || 0),
        settled_at: Number(existing.settled_at || 0),
      };
    }

    const family = this.ctx.storage.sql.exec(
      "SELECT experience FROM families WHERE id=? LIMIT 1", familyId,
    ).toArray()[0];
    if (!family) return null;
    const received = Number(this.ctx.storage.sql.exec(
      `SELECT COALESCE(SUM(coins),0) AS total
         FROM family_received_coins
        WHERE family_id=? AND created_at>=? AND created_at<?`,
      familyId, window.start_at, window.end_at,
    ).toArray()[0]?.total || 0);
    const level = this._familyLevelInfo(family.experience);
    const bonus = Math.floor(received * level.monthly_bonus_basis_points / 10000);
    const now = Number(timestampValue || Date.now());
    this.ctx.storage.sql.exec(
      `INSERT INTO family_monthly_bonuses
        (family_id,month_key,received_coins,bonus_basis_points,bonus_coins,settled_at)
       VALUES(?,?,?,?,?,?)`,
      familyId,window.month_key,received,level.monthly_bonus_basis_points,bonus,now,
    );
    if (bonus > 0) {
      this.ctx.storage.sql.exec(
        "UPDATE families SET wallet_coins=wallet_coins+?,updated_at=? WHERE id=?",
        bonus,now,familyId,
      );
    }
    return {
      month_key: window.month_key,
      received_coins: received,
      bonus_basis_points: level.monthly_bonus_basis_points,
      bonus_coins: bonus,
      settled_at: now,
    };
  }

  familyList(limitValue = 100) {
    this._ensureEconomyMigrations();
    const limit = Math.max(1, Math.min(200, Number(limitValue || 100)));
    return this.ctx.storage.sql.exec(
      `SELECT f.id,f.name,f.tag,f.notice,f.leader_user_id,f.experience,f.wallet_coins,
              f.created_at,f.updated_at,
              lu.display_name AS leader_name,
              lu.avatar_data_url AS leader_avatar_data_url,
              COUNT(fm.user_id) AS member_count
         FROM families f
         LEFT JOIN family_members fm ON fm.family_id=f.id
         LEFT JOIN app_users lu ON lu.user_id=f.leader_user_id
        GROUP BY f.id
        ORDER BY f.experience DESC, member_count DESC, f.created_at ASC
        LIMIT ?`, limit,
    ).toArray().map((row) => ({
      id: String(row.id),
      name: String(row.name),
      tag: String(row.tag),
      notice: String(row.notice || ""),
      leader_user_id: String(row.leader_user_id),
      leader_name: String(row.leader_name || row.leader_user_id),
      leader_avatar_data_url: row.leader_avatar_data_url
        ? String(row.leader_avatar_data_url)
        : null,
      experience: Number(row.experience || 0),
      wallet_coins: Number(row.wallet_coins || 0),
      member_count: Number(row.member_count || 0),
      level: this._familyLevelInfo(row.experience),
      created_at: Number(row.created_at || 0),
      updated_at: Number(row.updated_at || 0),
    }));
  }

  familyCreate(userIdValue, nameValue, tagValue) {
    this._ensureEconomyMigrations();
    const userId = this._resolveOwnerUserId(userIdValue);
    const userExists = userId
      ? this.ctx.storage.sql.exec(
          "SELECT user_id FROM app_users WHERE user_id=? LIMIT 1", userId,
        ).toArray()[0]
      : null;
    if (!userExists) throw new Error("User not found");
    if (this._familyMembership(userId)) throw new Error("Already in a family");
    const name = cleanText(nameValue, 40);
    const tag = cleanText(tagValue, 12).toUpperCase();
    if (name.length < 2) throw new Error("Family name is too short");
    if (tag.length < 2) throw new Error("Family tag is too short");
    const duplicate = this.ctx.storage.sql.exec(
      "SELECT id FROM families WHERE LOWER(name)=LOWER(?) OR UPPER(tag)=UPPER(?) LIMIT 1",
      name,tag,
    ).toArray()[0];
    if (duplicate) throw new Error("Family name or tag is already in use");
    const now = Date.now();
    const familyId = "family-" + crypto.randomUUID();
    this.ctx.storage.sql.exec(
      `INSERT INTO families
        (id,name,tag,leader_user_id,experience,wallet_coins,created_at,updated_at,notice)
       VALUES(?,?,?,?,0,0,?,?,?)`,
      familyId,name,tag,userId,now,now,"Welcome to " + name + " ❤️",
    );
    this.ctx.storage.sql.exec(
      "INSERT INTO family_members(family_id,user_id,role,joined_at) VALUES(?,?,'leader',?)",
      familyId,userId,now,
    );
    return { ok:true, family_id:familyId };
  }

  async familyState(userIdValue) {
    const membership = this._familyMembership(userIdValue);
    if (!membership) {
      return {
        family: null,
        members: [],
        join_requests: [],
        available_families: this.familyList(100),
      };
    }
    const familyId = String(membership.family_id);
    const settledBonus = this._settleFamilyMonthlyBonus(familyId, Date.now());
    const fresh = this._familyMembership(userIdValue) || membership;
    const members = this.ctx.storage.sql.exec(
      `SELECT fm.user_id, fm.role, fm.joined_at, u.display_name, u.avatar_data_url,
              COALESCE(SUM(rc.coins),0) AS received_coins
         FROM family_members fm
         JOIN app_users u ON u.user_id = fm.user_id
         LEFT JOIN family_received_coins rc
           ON rc.family_id=fm.family_id AND rc.receiver_user_id=fm.user_id
        WHERE fm.family_id = ?
        GROUP BY fm.family_id,fm.user_id
        ORDER BY CASE fm.role WHEN 'leader' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END,
                 received_coins DESC, fm.joined_at`,
      familyId,
    ).toArray().map((row)=>({
      user_id:String(row.user_id),
      role:String(row.role),
      joined_at:Number(row.joined_at || 0),
      display_name:String(row.display_name || row.user_id),
      avatar_data_url:row.avatar_data_url ? String(row.avatar_data_url) : null,
      received_coins:Number(row.received_coins || 0),
    }));
    const requests = this._familyCanReview(userIdValue, familyId)
      ? this.ctx.storage.sql.exec(
          `SELECT r.user_id, r.created_at, u.display_name, u.avatar_data_url
             FROM family_join_requests r
             JOIN app_users u ON u.user_id = r.user_id
            WHERE r.family_id = ? AND r.status = 'pending'
            ORDER BY r.created_at`,
          familyId,
        ).toArray()
      : [];
    const level = this._familyLevelInfo(fresh.experience);
    return {
      family: {
        id: familyId,
        name: String(fresh.name),
        tag: String(fresh.tag),
        notice: String(fresh.notice || ""),
        leader_user_id: String(fresh.leader_user_id),
        experience: Number(fresh.experience || 0),
        wallet_coins: Number(fresh.wallet_coins || 0),
        my_role: String(fresh.role),
        ...level,
        reference_coin_scale: 100,
        reference_20000_tinni_coins: 2000000,
        last_month_bonus: settledBonus,
      },
      members,
      join_requests: requests,
    };
  }

  async familyRequestJoin(userIdValue, familyIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const familyId = String(familyIdValue || "").trim();
    if (this._familyMembership(userId)) throw new Error("Already in a family");
    const family = this.ctx.storage.sql.exec(
      "SELECT id FROM families WHERE id = ? LIMIT 1", familyId,
    ).toArray()[0];
    if (!family) throw new Error("Family not found");
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO family_join_requests
        (family_id, user_id, status, created_at, updated_at)
       VALUES (?, ?, 'pending', ?, ?)
       ON CONFLICT(family_id, user_id) DO UPDATE SET
         status = 'pending', updated_at = excluded.updated_at`,
      familyId, userId, now, now,
    );
    return { ok: true };
  }

  async familyResolveJoin(actorUserIdValue, targetUserIdValue, approveValue) {
    const actor = this._familyMembership(actorUserIdValue);
    if (!actor || !this._familyCanReview(actorUserIdValue, actor.family_id)) {
      throw new Error("Family admin permission required");
    }
    const targetUserId = this._resolveOwnerUserId(targetUserIdValue);
    const request = this.ctx.storage.sql.exec(
      `SELECT user_id FROM family_join_requests
        WHERE family_id = ? AND user_id = ? AND status = 'pending' LIMIT 1`,
      actor.family_id, targetUserId,
    ).toArray()[0];
    if (!request) throw new Error("Pending join request not found");
    const now = Date.now();
    if (Boolean(approveValue)) {
      if (this._familyMembership(targetUserId)) {
        throw new Error("User already belongs to a family");
      }
      this.ctx.storage.sql.exec(
        "INSERT INTO family_members (family_id, user_id, role, joined_at) VALUES (?, ?, 'member', ?)",
        actor.family_id, targetUserId, now,
      );
    }
    this.ctx.storage.sql.exec(
      "UPDATE family_join_requests SET status = ?, updated_at = ? WHERE family_id = ? AND user_id = ?",
      Boolean(approveValue) ? "approved" : "rejected",
      now, actor.family_id, targetUserId,
    );
    return { ok: true, approved: Boolean(approveValue) };
  }

  async familySetAdmin(actorUserIdValue, targetUserIdValue, makeAdminValue) {
    const actor = this._familyMembership(actorUserIdValue);
    if (!actor || String(actor.role) !== "leader") {
      throw new Error("Only Family Leader can manage Family Admins");
    }
    const target = this._familyMembership(targetUserIdValue);
    if (!target || String(target.family_id) !== String(actor.family_id)) {
      throw new Error("Target must be an existing member of the same family");
    }
    if (String(target.role) === "leader") {
      throw new Error("Family Leader role cannot be changed here");
    }
    this.ctx.storage.sql.exec(
      "UPDATE family_members SET role = ? WHERE family_id = ? AND user_id = ?",
      Boolean(makeAdminValue) ? "admin" : "member",
      actor.family_id, target.user_id,
    );
    return { ok: true, role: Boolean(makeAdminValue) ? "admin" : "member" };
  }

  async familyRemoveMember(actorUserIdValue, targetUserIdValue) {
    const actor = this._familyMembership(actorUserIdValue);
    const target = this._familyMembership(targetUserIdValue);
    if (!actor || !target || String(actor.family_id) !== String(target.family_id)) {
      throw new Error("Target must be in your family");
    }
    const actorRole = String(actor.role);
    const targetRole = String(target.role);
    const allowed = actorRole === "leader"
      ? targetRole !== "leader"
      : actorRole === "admin"
        ? targetRole === "member"
        : false;
    if (!allowed) throw new Error("You cannot remove this family member");
    this.ctx.storage.sql.exec(
      "DELETE FROM family_members WHERE family_id = ? AND user_id = ?",
      actor.family_id, target.user_id,
    );
    return { ok: true };
  }

  familyLeave(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const membership = this._familyMembership(userId);
    if (!membership) return { ok:true };
    if (String(membership.role) === "leader") {
      throw new Error("Family Leader cannot leave before transferring or closing the Family");
    }
    this.ctx.storage.sql.exec(
      "DELETE FROM family_members WHERE family_id=? AND user_id=?",
      membership.family_id,userId,
    );
    return { ok:true };
  }

  familyUpdateNotice(userIdValue, noticeValue) {
    const actor = this._familyMembership(userIdValue);
    if (!actor || !["leader","admin"].includes(String(actor.role))) {
      throw new Error("Family Leader/Admin permission required");
    }
    const notice = cleanText(noticeValue, 300);
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "UPDATE families SET notice=?,updated_at=? WHERE id=?",
      notice,now,actor.family_id,
    );
    return { ok:true, notice };
  }

  familyCheckIn(userIdValue) {
    const userId = this._resolveOwnerUserId(userIdValue);
    const membership = this._familyMembership(userId);
    if (!membership) throw new Error("Join a Family first");
    const dayKey = this._indiaGiftDayKey(Date.now());
    const existing = this.ctx.storage.sql.exec(
      "SELECT exp_awarded FROM family_daily_logins WHERE family_id=? AND user_id=? AND day_key=? LIMIT 1",
      membership.family_id,userId,dayKey,
    ).toArray()[0];
    if (existing) {
      return { ok:true, already_checked_in:true, exp_awarded:Number(existing.exp_awarded || 0) };
    }
    const policies = this.ownerState().policies || {};
    const exp = Math.max(1, Math.floor(Number(policies.family_daily_login_exp || 1)));
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT INTO family_daily_logins(family_id,user_id,day_key,exp_awarded,created_at) VALUES(?,?,?,?,?)",
      membership.family_id,userId,dayKey,exp,now,
    );
    this.ctx.storage.sql.exec(
      "UPDATE families SET experience=experience+?,updated_at=? WHERE id=?",
      exp,now,membership.family_id,
    );
    return { ok:true, already_checked_in:false, exp_awarded:exp };
  }

  familyTransferCoins(senderUserIdValue, receiverUserIdValue, coinsValue) {
    const senderId = this._resolveOwnerUserId(senderUserIdValue);
    const receiverId = this._resolveOwnerUserId(receiverUserIdValue);
    const amount = Math.floor(Number(coinsValue || 0));
    if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error("Enter a valid coin amount");
    if (senderId === receiverId) throw new Error("Choose another Family member");
    const sender = this._familyMembership(senderId);
    const receiver = this._familyMembership(receiverId);
    if (!sender || !receiver || String(sender.family_id) !== String(receiver.family_id)) {
      throw new Error("Coins can be sent only to a member of your Family");
    }
    this._enforceActionRate(senderId, "family_wallet_send", 20, 60000, 300000);
    const now = Date.now();
    const id = "family-transfer-" + crypto.randomUUID();
    this._debitNormalWalletAuthorized(senderId, amount, "family_member_transfer");
    this._creditNormalWalletAuthorized(receiverId, amount, "family_member_transfer");
    this.ctx.storage.sql.exec(
      "INSERT INTO family_wallet_transfers(id,family_id,sender_user_id,receiver_user_id,coins,created_at) VALUES(?,?,?,?,?,?)",
      id,sender.family_id,senderId,receiverId,amount,now,
    );
    this.ctx.storage.sql.exec(
      "INSERT INTO family_received_coins(id,family_id,sender_user_id,receiver_user_id,coins,source,created_at) VALUES(?,?,?,?,?,'family_wallet',?)",
      id,sender.family_id,senderId,receiverId,amount,now,
    );
    // Receiving coins gives Family EXP 1:1. Sending coins gives no Family EXP.
    this.ctx.storage.sql.exec(
      "UPDATE families SET experience=experience+?,updated_at=? WHERE id=?",
      amount,now,sender.family_id,
    );
    this.ctx.storage.sql.exec(
      "INSERT INTO wallet_transactions(id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES(?,?, 'family_send',?,0,?,?,?)",
      crypto.randomUUID(),senderId,-amount,id,"Family Wallet send to "+receiverId,now,
    );
    this.ctx.storage.sql.exec(
      "INSERT INTO wallet_transactions(id,user_id,kind,coins_delta,diamonds_delta,reference_id,note,created_at) VALUES(?,?, 'family_receive',?,0,?,?,?)",
      crypto.randomUUID(),receiverId,amount,id,"Family Wallet received from "+senderId,now,
    );
    this._notifyUser(
      receiverId,
      "family_coins_received",
      "Family Wallet",
      amount.toLocaleString("en-US") + " coins received from " + senderId + ".",
      { source_user_id:senderId, metadata:{ family_id:String(sender.family_id), coins:amount } },
    );
    return {
      ok:true,
      transfer_id:id,
      sender_wallet:this.getWallet(senderId),
      receiver_user_id:receiverId,
      coins:amount,
      family_level:this._familyLevelInfo(Number(sender.experience || 0) + amount),
    };
  }

  familyWalletTransfers(userIdValue, limitValue = 100) {
    const membership = this._familyMembership(userIdValue);
    if (!membership) return [];
    const limit = Math.max(1, Math.min(200, Number(limitValue || 100)));
    return this.ctx.storage.sql.exec(
      `SELECT t.*, su.display_name AS sender_name, ru.display_name AS receiver_name
         FROM family_wallet_transfers t
         JOIN app_users su ON su.user_id=t.sender_user_id
         JOIN app_users ru ON ru.user_id=t.receiver_user_id
        WHERE t.family_id=?
        ORDER BY t.created_at DESC LIMIT ?`,
      membership.family_id,limit,
    ).toArray().map((row)=>({
      id:String(row.id),
      sender_user_id:String(row.sender_user_id),
      sender_name:String(row.sender_name || row.sender_user_id),
      receiver_user_id:String(row.receiver_user_id),
      receiver_name:String(row.receiver_name || row.receiver_user_id),
      coins:Number(row.coins || 0),
      created_at:Number(row.created_at || 0),
    }));
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
    if (!Number.isInteger(seatCount) || ![8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42].includes(seatCount)) {
      throw new Error("Room seat count must be 8-42");
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
