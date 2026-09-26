import { DurableObject } from "cloudflare:workers";

export const PARTY_ROUND_MS = 21000;
export const PARTY_RESULT_SPIN_MS = 5000;
export const PARTY_ROUND_CYCLE_MS =
  PARTY_ROUND_MS + PARTY_RESULT_SPIN_MS;
export const PARTY_BET_LOCK_MS = 0;
export const PARTY_START_BALANCE = 10000000;
export const PARTY_LUCKY_WINDOW_MS = 2 * 60 * 60 * 1000;
export const PARTY_BET_AMOUNTS = Object.freeze([
  5000,
  25000,
  100000,
  500000,
  2000000,
  10000000,
]);

export const PARTY_FRUITS = [
  { key: "lemon", emoji: "🍋", label: "Lemon", multiplier: 5 },
  { key: "raspberry", emoji: "🫐", label: "Raspberry", multiplier: 5 },
  { key: "kiwi", emoji: "🥝", label: "Kiwi", multiplier: 5 },
  { key: "plum", emoji: "🍑", label: "Plum", multiplier: 5 },
  { key: "banana", emoji: "🍌", label: "Banana", multiplier: 10 },
  { key: "strawberry", emoji: "🍓", label: "Strawberry", multiplier: 15 },
  { key: "watermelon", emoji: "🍉", label: "Watermelon", multiplier: 25 },
  { key: "cherry", emoji: "🍒", label: "Cherry", multiplier: 45 },
];

const FRUIT_BY_KEY = new Map(PARTY_FRUITS.map((fruit) => [fruit.key, fruit]));
const ALLOWED_BETS = new Set(PARTY_BET_AMOUNTS);
const X5 = PARTY_FRUITS.filter((fruit) => fruit.multiplier === 5);
const MID = PARTY_FRUITS.filter(
  (fruit) =>
    fruit.multiplier === 10 ||
    fruit.multiplier === 15 ||
    fruit.multiplier === 25,
);
const HIGH = PARTY_FRUITS.filter((fruit) => fruit.multiplier === 45);

function randomIndex(length) {
  if (length <= 1) return 0;
  const values = new Uint32Array(1);
  const ceiling = Math.floor(0x100000000 / length) * length;
  do {
    crypto.getRandomValues(values);
  } while (values[0] >= ceiling);
  return values[0] % length;
}

function weightedFruit() {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  const roll = values[0] % 100;
  if (roll < 75) return X5[randomIndex(X5.length)];
  if (roll < 95) return MID[randomIndex(MID.length)];
  return HIGH[randomIndex(HIGH.length)];
}

function randomDistinctFruits(count) {
  const pool = [...PARTY_FRUITS];
  const result = [];
  while (pool.length && result.length < count) {
    result.push(pool.splice(randomIndex(pool.length), 1)[0]);
  }
  return result;
}

function roundIdAt(ms) {
  return Math.floor(ms / PARTY_ROUND_CYCLE_MS);
}

function roundStartAt(roundId) {
  return roundId * PARTY_ROUND_CYCLE_MS;
}

function bettingEndAt(roundId) {
  return roundStartAt(roundId) + PARTY_ROUND_MS;
}

function roundEndAt(roundId) {
  return roundStartAt(roundId) + PARTY_ROUND_CYCLE_MS;
}

function dayKey(ms) {
  return new Date(ms).toISOString().slice(0, 10);
}

export class FruitPartyStore extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS party_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS party_bets (
        id TEXT PRIMARY KEY,
        round_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        fruit_key TEXT NOT NULL,
        amount INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_party_bets_round
        ON party_bets(round_id);

      CREATE TABLE IF NOT EXISTS party_results (
        round_id INTEGER PRIMARY KEY,
        fruit_key TEXT NOT NULL,
        mode TEXT NOT NULL,
        bonus_fruits_json TEXT NOT NULL DEFAULT '[]',
        total_bet INTEGER NOT NULL,
        total_payout INTEGER NOT NULL,
        active_players INTEGER NOT NULL,
        settled_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS party_wallets (
        user_id TEXT PRIMARY KEY,
        balance INTEGER NOT NULL,
        today_winnings INTEGER NOT NULL DEFAULT 0,
        winnings_day TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    `);
  }

  _meta(key, fallback = null) {
    const row = this.ctx.storage.sql.exec(
      "SELECT value FROM party_meta WHERE key = ? LIMIT 1",
      key,
    ).toArray()[0];
    return row ? String(row.value) : fallback;
  }

  _setMeta(key, value) {
    this.ctx.storage.sql.exec(
      `INSERT INTO party_meta (key, value) VALUES (?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
      key,
      String(value),
    );
  }

  _bets(roundId) {
    return this.ctx.storage.sql.exec(
      `SELECT user_id, fruit_key, amount, created_at
         FROM party_bets
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
      `INSERT INTO party_wallets
        (user_id, balance, today_winnings, winnings_day, updated_at)
       VALUES (?, ?, 0, ?, ?)
       ON CONFLICT(user_id) DO NOTHING`,
      userId,
      PARTY_START_BALANCE,
      today,
      now,
    );
    const row = this.ctx.storage.sql.exec(
      "SELECT winnings_day FROM party_wallets WHERE user_id = ? LIMIT 1",
      userId,
    ).toArray()[0];
    if (row && String(row.winnings_day) !== today) {
      this.ctx.storage.sql.exec(
        `UPDATE party_wallets
            SET today_winnings = 0, winnings_day = ?, updated_at = ?
          WHERE user_id = ?`,
        today,
        now,
        userId,
      );
    }
  }

  _wallet(userId, now = Date.now()) {
    if (!userId) return { balance: 0, today_winnings: 0 };
    this._ensureWallet(userId, now);
    const row = this.ctx.storage.sql.exec(
      `SELECT balance, today_winnings
         FROM party_wallets
        WHERE user_id = ?
        LIMIT 1`,
      userId,
    ).toArray()[0];
    return {
      balance: Number(row?.balance || 0),
      today_winnings: Number(row?.today_winnings || 0),
    };
  }

  _luckyRounds(roundId) {
    const windowId = Math.floor(
      roundStartAt(roundId) / PARTY_LUCKY_WINDOW_MS,
    );
    let rounds = [];
    if (this._meta("lucky_window_id") === String(windowId)) {
      try {
        rounds = JSON.parse(this._meta("lucky_rounds_json", "[]"));
      } catch {
        rounds = [];
      }
    }

    if (this._meta("lucky_window_id") !== String(windowId) ||
        !Array.isArray(rounds)) {
      const windowStart = windowId * PARTY_LUCKY_WINDOW_MS;
      const windowEnd = windowStart + PARTY_LUCKY_WINDOW_MS;
      const firstRound = Math.ceil(windowStart / PARTY_ROUND_CYCLE_MS);
      const lastRound = Math.floor((windowEnd - 1) / PARTY_ROUND_CYCLE_MS);
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

  async _ensureStarted(now = Date.now()) {
    const currentRound = roundIdAt(now);
    if (this._meta("started_round") === null) {
      this._setMeta("started_round", currentRound);
    }
    await this._sync(now);
  }

  async _sync(now = Date.now()) {
    const currentRound = roundIdAt(now);
    const startedRound = Number(this._meta("started_round", currentRound));
    const lastRaw = this._meta("last_settled_round");
    let next = lastRaw === null ? startedRound : Number(lastRaw) + 1;

    let processed = 0;
    while (
      (
        next < currentRound ||
        (
          next === currentRound &&
          now >= bettingEndAt(currentRound)
        )
      ) &&
      processed < 100
    ) {
      await this._settle(next);
      this._setMeta("last_settled_round", next);
      next += 1;
      processed += 1;
    }

    const nextAlarm =
      now < bettingEndAt(currentRound)
        ? bettingEndAt(currentRound)
        : roundEndAt(currentRound);
    const currentAlarm = await this.ctx.storage.getAlarm();
    if (currentAlarm === null || Math.abs(currentAlarm - nextAlarm) > 500) {
      await this.ctx.storage.setAlarm(nextAlarm);
    }
  }

  async alarm() {
    await this._ensureStarted(Date.now());
  }

  async _settle(roundId) {
    const exists = this.ctx.storage.sql.exec(
      "SELECT round_id FROM party_results WHERE round_id = ? LIMIT 1",
      roundId,
    ).toArray()[0];
    if (exists) return;

    const bets = this._bets(roundId);
    const players = new Set(bets.map((bet) => bet.user_id));
    const totalBet = bets.reduce((sum, bet) => sum + bet.amount, 0);
    const lucky11 = this._luckyRounds(roundId).includes(roundId);
    const bonusFruits = lucky11 ? randomDistinctFruits(3) : [];
    const winner = lucky11 ? bonusFruits[0] : weightedFruit();
    const winningKeys = lucky11
      ? new Set(bonusFruits.map((fruit) => fruit.key))
      : new Set([winner.key]);

    const payouts = new Map();
    let totalPayout = 0;
    for (const bet of bets) {
      if (!winningKeys.has(bet.fruit_key)) continue;
      const fruit = FRUIT_BY_KEY.get(bet.fruit_key);
      if (!fruit) continue;
      const payout = bet.amount * fruit.multiplier;
      totalPayout += payout;
      payouts.set(
        bet.user_id,
        (payouts.get(bet.user_id) || 0) + payout,
      );
    }

    const settledAt = Date.now();
    for (const [userId, payout] of payouts) {
      this._ensureWallet(userId, settledAt);
      this.ctx.storage.sql.exec(
        `UPDATE party_wallets
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

    this.ctx.storage.sql.exec(
      `INSERT INTO party_results
        (round_id, fruit_key, mode, bonus_fruits_json, total_bet,
         total_payout, active_players, settled_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      roundId,
      winner.key,
      lucky11 ? "lucky_11_random_3" : "weighted_random",
      JSON.stringify(bonusFruits.map((fruit) => fruit.key)),
      totalBet,
      totalPayout,
      players.size,
      settledAt,
    );
  }

  ownerStats(userIdValue = "") {
    const userId = String(userIdValue || "").trim();
    const totals = this.ctx.storage.sql.exec(
      `SELECT COUNT(*) AS bet_count,
              COALESCE(SUM(amount), 0) AS total_bet,
              COUNT(DISTINCT user_id) AS unique_players
         FROM party_bets`
    ).toArray()[0] || {};
    const resultTotals = this.ctx.storage.sql.exec(
      `SELECT COUNT(*) AS rounds,
              COALESCE(SUM(total_payout), 0) AS total_payout
         FROM party_results`
    ).toArray()[0] || {};

    let player = null;
    if (userId) {
      const userBet = this.ctx.storage.sql.exec(
        `SELECT COUNT(*) AS bet_count,
                COALESCE(SUM(amount), 0) AS total_bet
           FROM party_bets
          WHERE user_id = ?`,
        userId,
      ).toArray()[0] || {};
      const wallet = this.ctx.storage.sql.exec(
        `SELECT balance, today_winnings
           FROM party_wallets
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
    const myBets = Object.fromEntries(
      PARTY_FRUITS.map((fruit) => [fruit.key, 0]),
    );

    for (const bet of bets) {
      if (bet.user_id === userId && myBets[bet.fruit_key] !== undefined) {
        myBets[bet.fruit_key] += bet.amount;
      }
    }

    const history = this.ctx.storage.sql.exec(
      `SELECT round_id, fruit_key, mode, bonus_fruits_json,
              total_bet, total_payout, active_players, settled_at
         FROM party_results
        ORDER BY round_id DESC
        LIMIT 20`,
    ).toArray().map((row) => {
      let bonusKeys = [];
      try {
        bonusKeys = JSON.parse(String(row.bonus_fruits_json || "[]"));
      } catch {
        bonusKeys = [];
      }
      return {
        round_id: Number(row.round_id),
        fruit: FRUIT_BY_KEY.get(String(row.fruit_key)),
        mode: String(row.mode),
        special_kind:
          String(row.mode) === "lucky_11_random_3" ? "lucky11" : null,
        bonus_fruits: Array.isArray(bonusKeys)
          ? bonusKeys
              .map((key) => FRUIT_BY_KEY.get(String(key)))
              .filter(Boolean)
          : [],
        total_bet: Number(row.total_bet),
        total_payout: Number(row.total_payout),
        active_players: Number(row.active_players),
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
        result_spin_ms: PARTY_RESULT_SPIN_MS,
        phase: inResultSpin ? "result_spin" : "betting",
        round_duration_ms: PARTY_ROUND_MS,
        round_cycle_ms: PARTY_ROUND_CYCLE_MS,
        betting_open: !inResultSpin && remainingMs > 0,
        bet_lock_ms: PARTY_BET_LOCK_MS,
        total_bet: bets.reduce((sum, bet) => sum + bet.amount, 0),
        active_players: new Set(bets.map((bet) => bet.user_id)).size,
      },
      config: {
        bet_amounts: PARTY_BET_AMOUNTS,
        fruits: PARTY_FRUITS,
        lucky_11: {
          window_ms: PARTY_LUCKY_WINDOW_MS,
          events_per_window_min: 3,
          events_per_window_max: 4,
          random_bonus_fruits: 3,
        },
      },
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
    if (!Number.isInteger(amount) || !ALLOWED_BETS.has(amount)) {
      throw new Error("Invalid bet amount");
    }
    if (remainingMs <= 0) {
      throw new Error("Betting is locked while the result is spinning");
    }

    this._ensureWallet(userId, now);
    const wallet = this._wallet(userId, now);
    if (wallet.balance < amount) throw new Error("Not enough coins");

    this.ctx.storage.sql.exec(
      `UPDATE party_wallets
          SET balance = balance - ?, updated_at = ?
        WHERE user_id = ? AND balance >= ?`,
      amount,
      now,
      userId,
      amount,
    );

    this.ctx.storage.sql.exec(
      `INSERT INTO party_bets
        (id, round_id, user_id, fruit_key, amount, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
      crypto.randomUUID(),
      roundId,
      userId,
      fruitKey,
      amount,
      now,
    );

    return this.state(userId);
  }
}
