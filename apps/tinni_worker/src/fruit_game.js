import { DurableObject } from "cloudflare:workers";

export const ROUND_MS = 21000;
export const RESULT_SPIN_MS = 5000;
export const ROUND_CYCLE_MS = ROUND_MS + RESULT_SPIN_MS;
export const BET_LOCK_MS = 0;
export const HIGH_VOLUME_PLAYER_THRESHOLD = 20;
export const COMPANY_MARGIN_PERCENT = 30;
export const START_BALANCE = 10000000;
export const LUCKY_WINDOW_MS = 2 * 60 * 60 * 1000;
export const ALLOWED_BET_AMOUNTS = Object.freeze([
  5000,
  25000,
  100000,
  500000,
  2000000,
  10000000,
]);
export const RESULT_WEIGHTS = Object.freeze({
  x5: 75,
  x10_20: 20,
  x40: 5,
});

export const FRUITS = [
  { key: "lemon", emoji: "🍋", label: "Lemon", multiplier: 5 },
  { key: "raspberry", emoji: "🫐", label: "Raspberry", multiplier: 5 },
  { key: "kiwi", emoji: "🥝", label: "Kiwi", multiplier: 5 },
  { key: "plum", emoji: "🍑", label: "Plum", multiplier: 5 },
  { key: "banana", emoji: "🍌", label: "Banana", multiplier: 10 },
  { key: "strawberry", emoji: "🍓", label: "Strawberry", multiplier: 10 },
  { key: "watermelon", emoji: "🍉", label: "Watermelon", multiplier: 20 },
  { key: "cherry", emoji: "🍒", label: "Cherry", multiplier: 40 },
];

const FRUIT_BY_KEY = new Map(FRUITS.map((fruit) => [fruit.key, fruit]));
const X5_FRUITS = FRUITS.filter((fruit) => fruit.multiplier === 5);
const X10_20_FRUITS = FRUITS.filter(
  (fruit) => fruit.multiplier === 10 || fruit.multiplier === 20,
);
const X40_FRUITS = FRUITS.filter((fruit) => fruit.multiplier === 40);
const ALLOWED_BET_SET = new Set(ALLOWED_BET_AMOUNTS);

function randomIndex(length) {
  if (length <= 1) return 0;
  const values = new Uint32Array(1);
  const ceiling = Math.floor(0x100000000 / length) * length;
  do {
    crypto.getRandomValues(values);
  } while (values[0] >= ceiling);
  return values[0] % length;
}

function weightedRandomFruit() {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  const roll = values[0] % 100;

  if (roll < RESULT_WEIGHTS.x5) {
    return X5_FRUITS[randomIndex(X5_FRUITS.length)];
  }
  if (roll < RESULT_WEIGHTS.x5 + RESULT_WEIGHTS.x10_20) {
    return X10_20_FRUITS[randomIndex(X10_20_FRUITS.length)];
  }
  return X40_FRUITS[randomIndex(X40_FRUITS.length)];
}

function randomDistinctFruits(count) {
  const pool = [...FRUITS];
  const picked = [];
  while (pool.length > 0 && picked.length < count) {
    picked.push(pool.splice(randomIndex(pool.length), 1)[0]);
  }
  return picked;
}

function roundIdAt(timeMs) {
  return Math.floor(timeMs / ROUND_CYCLE_MS);
}

function roundStartAt(roundId) {
  return roundId * ROUND_CYCLE_MS;
}

function bettingEndAt(roundId) {
  return roundStartAt(roundId) + ROUND_MS;
}

function roundEndAt(roundId) {
  return roundStartAt(roundId) + ROUND_CYCLE_MS;
}

function dayKey(timeMs) {
  return new Date(timeMs).toISOString().slice(0, 10);
}

export class FruitGameStore extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS fruit_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS fruit_bets (
        id TEXT PRIMARY KEY,
        round_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        fruit_key TEXT NOT NULL,
        amount INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_fruit_bets_round ON fruit_bets(round_id);

      CREATE TABLE IF NOT EXISTS fruit_results (
        round_id INTEGER PRIMARY KEY,
        fruit_key TEXT NOT NULL,
        mode TEXT NOT NULL,
        total_bet INTEGER NOT NULL,
        total_payout INTEGER NOT NULL,
        company_retained INTEGER NOT NULL,
        active_players INTEGER NOT NULL,
        margin_target_met INTEGER NOT NULL,
        settled_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS fruit_wallets (
        user_id TEXT PRIMARY KEY,
        balance INTEGER NOT NULL,
        today_winnings INTEGER NOT NULL DEFAULT 0,
        winnings_day TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    `);

    this._ensureResultColumn("special_kind", "TEXT");
    this._ensureResultColumn(
      "bonus_fruits_json",
      "TEXT NOT NULL DEFAULT '[]'",
    );
    this._ensureResultColumn(
      "jackpot_hit",
      "INTEGER NOT NULL DEFAULT 0",
    );
    this._ensureResultColumn(
      "jackpot_payout",
      "INTEGER NOT NULL DEFAULT 0",
    );
  }

  _ensureResultColumn(name, definition) {
    try {
      this.ctx.storage.sql.exec(
        "ALTER TABLE fruit_results ADD COLUMN " + name + " " + definition,
      );
    } catch (error) {
      const message = String(error?.message || "").toLowerCase();
      if (!message.includes("duplicate") && !message.includes("already exists")) {
        throw error;
      }
    }
  }

  _meta(key, fallback = null) {
    const row = this.ctx.storage.sql.exec(
      "SELECT value FROM fruit_meta WHERE key = ? LIMIT 1",
      key,
    ).toArray()[0];
    return row ? String(row.value) : fallback;
  }

  _setMeta(key, value) {
    this.ctx.storage.sql.exec(
      `INSERT INTO fruit_meta (key, value) VALUES (?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
      key,
      String(value),
    );
  }

  _bets(roundId) {
    return this.ctx.storage.sql.exec(
      `SELECT user_id, fruit_key, amount, created_at
         FROM fruit_bets
        WHERE round_id = ?
        ORDER BY created_at ASC`,
      roundId,
    ).toArray().map((row) => ({
      user_id: String(row.user_id),
      fruit_key: String(row.fruit_key),
      amount: Number(row.amount),
      created_at: Number(row.created_at),
    }));
  }

  _ensureWallet(userId, now = Date.now()) {
    if (!userId) return;
    const today = dayKey(now);
    this.ctx.storage.sql.exec(
      `INSERT INTO fruit_wallets
        (user_id, balance, today_winnings, winnings_day, updated_at)
       VALUES (?, ?, 0, ?, ?)
       ON CONFLICT(user_id) DO NOTHING`,
      userId,
      START_BALANCE,
      today,
      now,
    );

    const wallet = this.ctx.storage.sql.exec(
      `SELECT winnings_day FROM fruit_wallets WHERE user_id = ? LIMIT 1`,
      userId,
    ).toArray()[0];
    if (wallet && String(wallet.winnings_day) !== today) {
      this.ctx.storage.sql.exec(
        `UPDATE fruit_wallets
            SET today_winnings = 0, winnings_day = ?, updated_at = ?
          WHERE user_id = ?`,
        today,
        now,
        userId,
      );
    }
  }

  _wallet(userId, now = Date.now()) {
    if (!userId) {
      return { balance: 0, today_winnings: 0 };
    }
    this._ensureWallet(userId, now);
    const row = this.ctx.storage.sql.exec(
      `SELECT balance, today_winnings
         FROM fruit_wallets
        WHERE user_id = ?
        LIMIT 1`,
      userId,
    ).toArray()[0];
    return {
      balance: Number(row?.balance || 0),
      today_winnings: Number(row?.today_winnings || 0),
    };
  }

  _luckySchedule(roundId) {
    const windowId = Math.floor(roundStartAt(roundId) / LUCKY_WINDOW_MS);
    const storedWindowId = this._meta("lucky_window_id");
    let rounds = [];

    if (storedWindowId === String(windowId)) {
      try {
        rounds = JSON.parse(this._meta("lucky_rounds_json", "[]"));
      } catch {
        rounds = [];
      }
    }

    if (storedWindowId !== String(windowId) || !Array.isArray(rounds)) {
      const windowStart = windowId * LUCKY_WINDOW_MS;
      const windowEnd = windowStart + LUCKY_WINDOW_MS;
      const firstRound = Math.ceil(windowStart / ROUND_CYCLE_MS);
      const lastRound = Math.floor((windowEnd - 1) / ROUND_CYCLE_MS);
      const totalRounds = Math.max(1, lastRound - firstRound + 1);
      const count = 3 + randomIndex(2);
      const selected = new Set();

      while (selected.size < Math.min(count, totalRounds)) {
        selected.add(firstRound + randomIndex(totalRounds));
      }

      rounds = [...selected].sort((a, b) => a - b);
      this._setMeta("lucky_window_id", windowId);
      this._setMeta("lucky_rounds_json", JSON.stringify(rounds));
    }

    return rounds;
  }

  _isLuckyRound(roundId) {
    return this._luckySchedule(roundId).includes(roundId);
  }

  async _ensureStarted(now = Date.now()) {
    const currentRound = roundIdAt(now);
    if (this._meta("started_round") === null) {
      this._setMeta("started_round", currentRound);
      this._setMeta("jackpot", 85763);
    }
    await this._sync(now);
  }

  async _sync(now = Date.now()) {
    const currentRound = roundIdAt(now);
    const startedRound = Number(this._meta("started_round", currentRound));
    const lastSettledRaw = this._meta("last_settled_round");
    let nextToSettle = lastSettledRaw === null
      ? startedRound
      : Number(lastSettledRaw) + 1;

    let processed = 0;
    while (
      (
        nextToSettle < currentRound ||
        (
          nextToSettle === currentRound &&
          now >= bettingEndAt(currentRound)
        )
      ) &&
      processed < 100
    ) {
      await this._settle(nextToSettle);
      this._setMeta("last_settled_round", nextToSettle);
      nextToSettle += 1;
      processed += 1;
    }

    const nextAlarm =
      now < bettingEndAt(currentRound)
        ? bettingEndAt(currentRound)
        : roundEndAt(currentRound);
    const existingAlarm = await this.ctx.storage.getAlarm();
    if (existingAlarm === null || Math.abs(existingAlarm - nextAlarm) > 500) {
      await this.ctx.storage.setAlarm(nextAlarm);
    }
  }

  async alarm() {
    await this._ensureStarted(Date.now());
  }

  async _settle(roundId) {
    const already = this.ctx.storage.sql.exec(
      "SELECT round_id FROM fruit_results WHERE round_id = ? LIMIT 1",
      roundId,
    ).toArray()[0];
    if (already) return;

    const bets = this._bets(roundId);
    const totalBet = bets.reduce((sum, bet) => sum + bet.amount, 0);
    const players = new Set(bets.map((bet) => bet.user_id));
    const lucky11 = this._isLuckyRound(roundId);
    const bonusFruits = lucky11 ? randomDistinctFruits(3) : [];
    const winner = lucky11 ? bonusFruits[0] : weightedRandomFruit();
    const mode = lucky11
      ? "lucky_11_random_3"
      : "weighted_random_75_20_5";
    const winningKeys = lucky11
      ? new Set(bonusFruits.map((fruit) => fruit.key))
      : new Set([winner.key]);

    const payoutsByUser = new Map();
    for (const bet of bets) {
      if (!winningKeys.has(bet.fruit_key)) continue;
      const fruit = FRUIT_BY_KEY.get(bet.fruit_key);
      if (!fruit) continue;
      const payout = bet.amount * fruit.multiplier;
      payoutsByUser.set(
        bet.user_id,
        (payoutsByUser.get(bet.user_id) || 0) + payout,
      );
    }

    const settledAt = Date.now();
    for (const [userId, payout] of payoutsByUser) {
      this._ensureWallet(userId, settledAt);
      this.ctx.storage.sql.exec(
        `UPDATE fruit_wallets
            SET balance = balance + ?,
                today_winnings = today_winnings + ?,
                updated_at = ?
          WHERE user_id = ?`,
        payout,
        payout,
        settledAt,
        userId,
      );
    }

    let totalPayout = 0;
    for (const bet of bets) {
      if (!winningKeys.has(bet.fruit_key)) continue;
      const fruit = FRUIT_BY_KEY.get(bet.fruit_key);
      if (fruit) totalPayout += bet.amount * fruit.multiplier;
    }

    const retained = totalBet - totalPayout;

    this.ctx.storage.sql.exec(
      `INSERT INTO fruit_results
        (round_id, fruit_key, mode, total_bet, total_payout, company_retained,
         active_players, margin_target_met, settled_at, special_kind,
         bonus_fruits_json, jackpot_hit, jackpot_payout)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      roundId,
      winner.key,
      mode,
      totalBet,
      totalPayout,
      retained,
      players.size,
      1,
      settledAt,
      lucky11 ? "lucky11" : null,
      JSON.stringify(bonusFruits.map((fruit) => fruit.key)),
      0,
      0,
    );
  }

  ownerStats(userIdValue = "") {
    const userId = String(userIdValue || "").trim();
    const totals = this.ctx.storage.sql.exec(
      `SELECT COUNT(*) AS bet_count,
              COALESCE(SUM(amount), 0) AS total_bet,
              COUNT(DISTINCT user_id) AS unique_players
         FROM fruit_bets`
    ).toArray()[0] || {};
    const resultTotals = this.ctx.storage.sql.exec(
      `SELECT COUNT(*) AS rounds,
              COALESCE(SUM(total_payout), 0) AS total_payout
         FROM fruit_results`
    ).toArray()[0] || {};

    let player = null;
    if (userId) {
      const userBet = this.ctx.storage.sql.exec(
        `SELECT COUNT(*) AS bet_count,
                COALESCE(SUM(amount), 0) AS total_bet
           FROM fruit_bets
          WHERE user_id = ?`,
        userId,
      ).toArray()[0] || {};
      const wallet = this.ctx.storage.sql.exec(
        `SELECT balance, today_winnings
           FROM fruit_wallets
          WHERE user_id = ?
          LIMIT 1`,
        userId,
      ).toArray()[0];
      player = {
        user_id: userId,
        bet_count: Number(userBet.bet_count || 0),
        total_bet: Number(userBet.total_bet || 0),
        balance: Number(wallet?.balance || START_BALANCE),
        today_winnings: Number(wallet?.today_winnings || 0),
        net_profit: Number(wallet?.balance || START_BALANCE) - START_BALANCE,
      };
    }

    return {
      bet_count: Number(totals.bet_count || 0),
      total_bet: Number(totals.total_bet || 0),
      unique_players: Number(totals.unique_players || 0),
      rounds: Number(resultTotals.rounds || 0),
      total_payout: Number(resultTotals.total_payout || 0),
      house_net: Number(totals.total_bet || 0) - Number(resultTotals.total_payout || 0),
      player,
    };
  }

  async state(userIdValue = "") {
    const now = Date.now();
    await this._ensureStarted(now);

    const roundId = roundIdAt(now);
    const bettingEnd = bettingEndAt(roundId);
    const cycleEnd = roundEndAt(roundId);
    const inResultSpin = now >= bettingEnd;
    const remainingMs = Math.max(0, bettingEnd - now);
    const resultSpinRemainingMs = inResultSpin
      ? Math.max(0, cycleEnd - now)
      : 0;
    const bets = this._bets(roundId);
    const userId = String(userIdValue || "").trim();

    const myBets = Object.fromEntries(FRUITS.map((fruit) => [fruit.key, 0]));
    if (userId) {
      for (const bet of bets) {
        if (bet.user_id === userId && myBets[bet.fruit_key] !== undefined) {
          myBets[bet.fruit_key] += bet.amount;
        }
      }
    }

    const history = this.ctx.storage.sql.exec(
      `SELECT round_id, fruit_key, mode, total_bet, total_payout,
              company_retained, active_players, margin_target_met, settled_at,
              special_kind, bonus_fruits_json, jackpot_hit, jackpot_payout
         FROM fruit_results
        ORDER BY round_id DESC
        LIMIT 20`,
    ).toArray().map((row) => {
      const fruit = FRUIT_BY_KEY.get(String(row.fruit_key));
      let bonusKeys = [];
      try {
        bonusKeys = JSON.parse(String(row.bonus_fruits_json || "[]"));
      } catch {
        bonusKeys = [];
      }
      const bonusFruits = Array.isArray(bonusKeys)
        ? bonusKeys.map((key) => FRUIT_BY_KEY.get(String(key))).filter(Boolean)
        : [];
      return {
        round_id: Number(row.round_id),
        fruit,
        mode: String(row.mode),
        special_kind: row.special_kind ? String(row.special_kind) : null,
        bonus_fruits: bonusFruits,
        total_bet: Number(row.total_bet),
        total_payout: Number(row.total_payout),
        company_retained: Number(row.company_retained),
        active_players: Number(row.active_players),
        margin_target_met: Number(row.margin_target_met) === 1,
        jackpot_hit: Number(row.jackpot_hit || 0) === 1,
        jackpot_payout: Number(row.jackpot_payout || 0),
        settled_at: Number(row.settled_at),
      };
    });

    const wallet = this._wallet(userId, now);

    return {
      ok: true,
      server_time: now,
      round: {
        round_id: roundId,
        round_start: roundStartAt(roundId),
        round_end: bettingEnd,
        cycle_end: cycleEnd,
        remaining_ms: remainingMs,
        result_spin_remaining_ms: resultSpinRemainingMs,
        result_spin_ms: RESULT_SPIN_MS,
        phase: inResultSpin ? "result_spin" : "betting",
        round_duration_ms: ROUND_MS,
        round_cycle_ms: ROUND_CYCLE_MS,
        betting_open: !inResultSpin && remainingMs > 0,
        bet_lock_ms: BET_LOCK_MS,
        total_bet: bets.reduce((sum, bet) => sum + bet.amount, 0),
        active_players: new Set(bets.map((bet) => bet.user_id)).size,
      },
      config: {
        high_volume_player_threshold: HIGH_VOLUME_PLAYER_THRESHOLD,
        company_margin_percent: COMPANY_MARGIN_PERCENT,
        result_weights_percent: RESULT_WEIGHTS,
        bet_amounts: ALLOWED_BET_AMOUNTS,
        lucky_11: {
          window_ms: LUCKY_WINDOW_MS,
          events_per_window_min: 3,
          events_per_window_max: 4,
          random_bonus_fruits: 3,
        },
        fruits: FRUITS,
      },
      jackpot: Number(this._meta("jackpot", "85763")),
      wallet_balance: wallet.balance,
      today_winnings: wallet.today_winnings,
      my_bets: myBets,
      history,
    };
  }

  async placeBet(input) {
    const now = Date.now();
    await this._ensureStarted(now);

    const userId = String(input?.user_id || "").trim();
    const fruitKey = String(input?.fruit_key || "").trim();
    const amount = Number(input?.amount || 0);
    const roundId = roundIdAt(now);
    const remainingMs = bettingEndAt(roundId) - now;

    if (!userId) throw new Error("user_id is required");
    if (!FRUIT_BY_KEY.has(fruitKey)) throw new Error("Invalid fruit");
    if (!Number.isInteger(amount) || !ALLOWED_BET_SET.has(amount)) {
      throw new Error("Invalid bet amount");
    }
    if (remainingMs <= 0) {
      throw new Error("Betting is locked while the result is spinning");
    }

    this._ensureWallet(userId, now);
    const wallet = this._wallet(userId, now);
    if (wallet.balance < amount) {
      throw new Error("Not enough coins");
    }

    this.ctx.storage.sql.exec(
      `UPDATE fruit_wallets
          SET balance = balance - ?, updated_at = ?
        WHERE user_id = ? AND balance >= ?`,
      amount,
      now,
      userId,
      amount,
    );

    const updatedWallet = this._wallet(userId, now);
    if (updatedWallet.balance !== wallet.balance - amount) {
      throw new Error("Unable to reserve bet balance");
    }

    this.ctx.storage.sql.exec(
      `INSERT INTO fruit_bets
        (id, round_id, user_id, fruit_key, amount, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
      crypto.randomUUID(),
      roundId,
      userId,
      fruitKey,
      amount,
      now,
    );

    const contribution = Math.floor(amount / 100);
    if (contribution > 0) {
      const jackpot = Number(this._meta("jackpot", "85763"));
      this._setMeta("jackpot", jackpot + contribution);
    }

    return this.state(userId);
  }
}
