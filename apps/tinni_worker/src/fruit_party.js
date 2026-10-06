import { DurableObject } from "cloudflare:workers";
import { saveGameResults, lastGameResult, pendingGameResults, flushGameResults, mainDirectory, recoverMainBets } from "./game_results.js";
import { openGameSocket, handleGameMessage, notifyGameChanged } from "./game_live.js";

export const PARTY_ROUND_MS = 21000;
export const PARTY_RESULT_SPIN_MS = 5000;
export const PARTY_ROUND_CYCLE_MS =
  PARTY_ROUND_MS + PARTY_RESULT_SPIN_MS;
export const PARTY_BET_LOCK_MS = 0;
export const PARTY_LUCKY_WINDOW_MS = 2 * 60 * 60 * 1000;
export const PARTY_START_BALANCE = 10000000;
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
  const picked = [];
  while (pool.length > 0 && picked.length < count) {
    picked.push(pool.splice(randomIndex(pool.length), 1)[0]);
  }
  return picked;
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
  fetch(request) { return openGameSocket(this, request, "fruit-party"); }
  webSocketMessage(socket, message) { return handleGameMessage(this, socket, message); }
  webSocketClose() {}
  webSocketError() {}

  _notifyPhase(now) {
    const phaseKey = roundIdAt(now) + ":" + (now >= bettingEndAt(roundIdAt(now)));
    if (this._livePhaseKey === phaseKey) return;
    this._livePhaseKey = phaseKey;
    notifyGameChanged(this, "fruit-party");
  }

  constructor(ctx, env) {
    super(ctx, env);
    this.env = env;
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

      CREATE TABLE IF NOT EXISTS party_result_outbox (
        user_id TEXT NOT NULL, round_id INTEGER NOT NULL, payload TEXT NOT NULL,
        PRIMARY KEY(user_id, round_id)
      );
      CREATE TABLE IF NOT EXISTS party_latest_results (
        user_id TEXT PRIMARY KEY, round_id INTEGER NOT NULL,
        payload TEXT NOT NULL, delivered INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS idx_party_result_delivery ON party_latest_results(delivered);
      CREATE TABLE IF NOT EXISTS party_wallets (
        user_id TEXT PRIMARY KEY,
        balance INTEGER NOT NULL,
        today_winnings INTEGER NOT NULL DEFAULT 0,
        winnings_day TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    `);
    try { this.ctx.storage.sql.exec("ALTER TABLE party_bets ADD COLUMN main_wallet INTEGER NOT NULL DEFAULT 0"); } catch (error) { const m=String(error?.message||"").toLowerCase(); if(!m.includes("duplicate")&&!m.includes("already exists")) throw error; }
    try { this.ctx.storage.sql.exec("ALTER TABLE party_bets ADD COLUMN room_id TEXT"); } catch (error) { const m=String(error?.message||"").toLowerCase(); if(!m.includes("duplicate")&&!m.includes("already exists")) throw error; }
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
      `SELECT id, user_id, fruit_key, amount, room_id, created_at, main_wallet
         FROM party_bets
        WHERE round_id = ?
        ORDER BY created_at ASC`,
      roundId,
    ).toArray().map((row) => ({
      id: String(row.id), main_wallet: Number(row.main_wallet || 0) === 1,
      user_id: String(row.user_id),
      fruit_key: String(row.fruit_key),
      amount: Number(row.amount),
      room_id: row.room_id ? String(row.room_id) : null,
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


  _luckySchedule(roundId) {
    const windowId = Math.floor(roundStartAt(roundId) / PARTY_LUCKY_WINDOW_MS);
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

  _isLuckyRound(roundId) {
    return this._luckySchedule(roundId).includes(roundId);
  }

  async _ensureStarted(now = Date.now()) {
    const currentRound = roundIdAt(now);
    if (this._meta("started_round") === null) {
      this._setMeta("started_round", currentRound);
    }
    await this._sync(now);
    this._notifyPhase(now);
  }

  async _sync(now = Date.now()) {
    const recoveryPhase = roundIdAt(now) + ":" + (now >= bettingEndAt(roundIdAt(now)));
    if (this._meta("main_wallet_mode") && this._mainRecoveryPhase !== recoveryPhase) {
      try {
        await recoverMainBets(this, "party", "fruit_party");
        this._mainRecoveryPhase = recoveryPhase;
      } catch (error) {
        console.error("Funded bet recovery will retry", String(error?.message || error));
        await this.ctx.storage.setAlarm(now + 15000);
        return;
      }
    }
    const currentRound = roundIdAt(now);
    const startedRound = Number(this._meta("started_round", currentRound));
    const lastRaw = this._meta("last_settled_round");
    let next = lastRaw === null ? startedRound : Number(lastRaw) + 1;

    const eligible = now >= bettingEndAt(currentRound) ? currentRound : currentRound - 1;
    // Read overdue stake-bearing rounds directly after a long idle interval.
    // Never discard a bet, payout, ledger or settled financial result.
    const overdue = this.ctx.storage.sql.exec(
      "SELECT DISTINCT round_id FROM party_bets WHERE round_id >= ? AND round_id <= ? ORDER BY round_id LIMIT 101",
      next, eligible,
    ).toArray();
    for (const row of overdue.slice(0, 100)) await this._settle(Number(row.round_id));
    if (overdue.length > 100) {
      this._setMeta("last_settled_round", Number(overdue[99].round_id));
      await this.ctx.storage.setAlarm(now + 1000);
      return;
    }
    for (let round = Math.max(next, eligible - 6); round <= eligible; round++) {
      await this._settle(round);
    }
    if (next <= eligible) this._setMeta("last_settled_round", eligible);
    const pending = this.ctx.storage.sql.exec(
      "SELECT round_id FROM party_bets WHERE round_id > ? LIMIT 1", eligible,
    ).toArray().length > 0;
    await flushGameResults(this, "party");
    const deliveryPending = pendingGameResults(this, "party");
    const watching = (this.ctx.getWebSockets?.("game:fruit-party") || []).length > 0;
    if (!watching && !pending && !deliveryPending) {
      if (await this.ctx.storage.getAlarm() !== null) await this.ctx.storage.deleteAlarm();
      return;
    }

    const nextAlarm = deliveryPending && !watching && !pending ? now + 15000 :
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
    const lucky11 = this._isLuckyRound(roundId);
    const bonusFruits = lucky11 ? randomDistinctFruits(3) : [];
    const winner = lucky11 ? bonusFruits[0] : weightedFruit();
    const winningKeys = new Set(lucky11 ? bonusFruits.map(fruit => fruit.key) : [winner.key]);

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

    this.ctx.storage.transactionSync(() => {
    const settledAt = Date.now();
    for (const userId of payouts.keys()) {
      const payout = bets.filter(bet => bet.user_id === userId && !bet.main_wallet && winningKeys.has(bet.fruit_key))
        .reduce((sum, bet) => sum + bet.amount * FRUIT_BY_KEY.get(bet.fruit_key).multiplier, 0);
      if (!payout) continue;
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
    saveGameResults(this, "party", "fruit_party", roundId, bets, payouts, winner, bonusFruits);
    });
    if (this.env?.APP_DIRECTORY) {
      const directory = this.env.APP_DIRECTORY.get(this.env.APP_DIRECTORY.idFromName("tinni-app-directory"));
      for (const [userId, payout] of payouts) {
        if (payout < 1000000) continue;
        const roomId = bets.find((bet) => bet.user_id === userId && bet.room_id)?.room_id;
        if (roomId) try { await directory.recordGameWinning(userId, roomId, "fruit_party", payout); } catch (error) { console.error("Game winning notice failed", String(error?.message || error)); }
      }
    }

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
        balance: Number(wallet?.balance ?? PARTY_START_BALANCE),
        today_winnings: Number(wallet?.today_winnings || 0),
        net_profit: Number(wallet?.balance ?? PARTY_START_BALANCE) - PARTY_START_BALANCE,
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
        special_kind: String(row.mode) === "lucky_11_random_3" ? "lucky11" : null,
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

    const mainWallet = userId ? await mainDirectory(this).mainGameWallet(userId,"fruit_party") : {coins:0,today_winnings:0};
    const wallet = {balance:mainWallet.coins,today_winnings:mainWallet.today_winnings};

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
        lucky_window_ms: PARTY_LUCKY_WINDOW_MS,
        lucky_rounds_min: 3, lucky_rounds_max: 4,
        lucky_fruit_count: 3,
        fruits: PARTY_FRUITS,
      },
      last_bet_result: mainWallet.last_bet_result || lastGameResult(this, "party", userId),
      wallet_balance: wallet.balance,
      today_winnings: wallet.today_winnings,
      my_bets: myBets,
      history,
    };
  }

  async placeBet(input) {
    const userId = String(input?.user_id || "").trim();
    const fruitKey = String(input?.fruit_key || "").trim();
    const roomId = String(input?.room_id || "").trim();
    const amount = Number(input?.amount || 0);
    const requestId = String(input?.request_id || crypto.randomUUID());
    if (!userId || !roomId) throw new Error("user_id and room_id are required");
    if (!FRUIT_BY_KEY.has(fruitKey)) throw new Error("Invalid fruit");
    if (!Number.isInteger(amount) || !ALLOWED_BETS.has(amount)) throw new Error("Invalid bet amount");
    if (!/^[a-zA-Z0-9_-]{16,80}$/.test(requestId)) throw new Error("Invalid bet request ID");
    const id = "fruit_party:" + userId + ":" + requestId;
    const prior = this.ctx.storage.sql.exec("SELECT user_id,fruit_key,amount,room_id FROM party_bets WHERE id=?", id).toArray()[0];
    if (prior) {
      if (prior.user_id !== userId || prior.fruit_key !== fruitKey || Number(prior.amount) !== amount || prior.room_id !== roomId) {
        throw new Error("Bet request ID was already used");
      }
      return this.state(userId);
    }
    await this._ensureStarted(Date.now());
    this._setMeta("main_wallet_mode", "1");
    await this.ctx.blockConcurrencyWhile(async () => {
      const now = Date.now(), roundId = roundIdAt(now);
      if (bettingEndAt(roundId) <= now) throw new Error("Betting is locked while the result is spinning");
      // The alarm is durable before the main wallet reserves funds.
      const currentAlarm = await this.ctx.storage.getAlarm();
      if (currentAlarm === null || currentAlarm > bettingEndAt(roundId)) await this.ctx.storage.setAlarm(bettingEndAt(roundId));
      const bet = await mainDirectory(this).reserveMainGameBet({
        id,user_id:userId,game_key:"fruit_party",round_id:roundId,
        fruit_key:fruitKey,amount,room_id:roomId,
      });
      this.ctx.storage.sql.exec(
        "INSERT OR IGNORE INTO party_bets(id,round_id,user_id,fruit_key,amount,room_id,created_at,main_wallet) VALUES(?,?,?,?,?,?,?,1)",
        bet.id,bet.round_id,bet.user_id,bet.fruit_key,bet.amount,bet.room_id,bet.created_at,
      );
    });
    notifyGameChanged(this, "fruit-party");
    return this.state(userId);
  }
}
