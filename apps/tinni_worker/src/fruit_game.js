import * as coldStorage from "./cold_storage.js";
import { DurableObject } from "cloudflare:workers";
import { saveGameResults, lastGameResult, pendingGameResults, flushGameResults, mainDirectory, recoverMainBets } from "./game_results.js";
import { openGameSocket, handleGameMessage, notifyGameChanged } from "./game_live.js";

export const ROUND_MS = 21000;
export const RESULT_SPIN_MS = 5000;
export const ROUND_CYCLE_MS = ROUND_MS + RESULT_SPIN_MS;
export const BET_LOCK_MS = 0;
export const JACKPOT_CONTRIBUTION_PERCENT = 7;
export const JACKPOT_OPENINGS_PER_HOUR = 8;
export const JACKPOT_WINDOW_MS = Math.floor(60 * 60 * 1000 / JACKPOT_OPENINGS_PER_HOUR);
export const JACKPOT_REWARD_PERCENTAGES = Object.freeze([10, 5, 3]);
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
  fetch(request) { return openGameSocket(this, request, "fruit-jackpot"); }
  webSocketMessage(socket, message) { return handleGameMessage(this, socket, message); }
  webSocketClose() {}
  webSocketError() {}

  _notifyPhase(now) {
    const phaseKey = roundIdAt(now) + ":" + (now >= bettingEndAt(roundIdAt(now)));
    if (this._livePhaseKey === phaseKey) return;
    this._livePhaseKey = phaseKey;
    notifyGameChanged(this, "fruit-jackpot");
  }

  constructor(ctx, env) {
    super(ctx, env);
    this.env = env;
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

      CREATE INDEX IF NOT EXISTS idx_fruit_empty_history ON fruit_results(total_bet,round_id);
      CREATE TABLE IF NOT EXISTS fruit_jackpot_events (
        slot_id INTEGER PRIMARY KEY,
        opened_at INTEGER NOT NULL,
        pool_before INTEGER NOT NULL,
        pool_after INTEGER NOT NULL,
        winners_json TEXT NOT NULL DEFAULT '[]',
        paid INTEGER NOT NULL DEFAULT 0,
        result_round_id INTEGER
      );
      CREATE INDEX IF NOT EXISTS idx_fruit_jackpot_events_opened ON fruit_jackpot_events(opened_at DESC);
      CREATE TABLE IF NOT EXISTS fruit_result_outbox (
        user_id TEXT NOT NULL, round_id INTEGER NOT NULL, payload TEXT NOT NULL,
        PRIMARY KEY(user_id, round_id)
      );
      CREATE TABLE IF NOT EXISTS fruit_latest_results (
        user_id TEXT PRIMARY KEY, round_id INTEGER NOT NULL,
        payload TEXT NOT NULL, delivered INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS idx_fruit_result_delivery ON fruit_latest_results(delivered);
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
    this._ensureResultColumn(
      "top_winners_json",
      "TEXT NOT NULL DEFAULT '[]'",
    );
    try { this.ctx.storage.sql.exec("ALTER TABLE fruit_bets ADD COLUMN main_wallet INTEGER NOT NULL DEFAULT 0"); } catch (error) { const m=String(error?.message||"").toLowerCase(); if(!m.includes("duplicate")&&!m.includes("already exists")) throw error; }
    try { this.ctx.storage.sql.exec("ALTER TABLE fruit_bets ADD COLUMN room_id TEXT"); } catch (error) { const m=String(error?.message||"").toLowerCase(); if(!m.includes("duplicate")&&!m.includes("already exists")) throw error; }
    coldStorage.initGameRetention(this,"fruit");
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

  pruneHistory(now=Date.now()) {return coldStorage.pruneGameHistory(this,"fruit",now);}

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
      `SELECT id, user_id, fruit_key, amount, room_id, created_at, main_wallet
         FROM fruit_bets
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

  async _topWinnerProfiles(payouts) {
    const ranked = [...payouts.entries()]
      .filter(([, amount]) => Number(amount) > 0)
      .sort((a, b) => Number(b[1]) - Number(a[1]))
      .slice(0, 3);
    if (!ranked.length) return [];
    const directory = this.env?.APP_DIRECTORY ? mainDirectory(this) : null;
    const winners = [];
    for (const [userId, amount] of ranked) {
      let profile = null;
      if (directory) {
        try { profile = await directory.getUserById(userId); } catch {}
      }
      winners.push({
        user_id: userId,
        display_name: String(profile?.display_name || userId),
        avatar_data_url: profile?.avatar_data_url || null,
        winning_coins: Number(amount),
      });
    }
    return winners;
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

  _latestJackpotEvent() {
    const row = this.ctx.storage.sql.exec(
      "SELECT slot_id,opened_at,pool_before,pool_after,winners_json,paid,result_round_id FROM fruit_jackpot_events WHERE paid=1 ORDER BY slot_id DESC LIMIT 1",
    ).toArray()[0];
    if (!row) return null;
    let winners = [];
    try { winners = JSON.parse(String(row.winners_json || "[]")); } catch { winners = []; }
    return {
      slot_id: Number(row.slot_id), opened_at: Number(row.opened_at),
      pool_before: Number(row.pool_before), pool_after: Number(row.pool_after),
      jackpot_payout: Math.max(0, Number(row.pool_before) - Number(row.pool_after)),
      winners: Array.isArray(winners) ? winners : [],
      result_round_id: row.result_round_id == null ? null : Number(row.result_round_id),
    };
  }

  async _openDueJackpots(now = Date.now(), resultRoundId = null) {
    const closedSlot = Math.floor(now / JACKPOT_WINDOW_MS) - 1;
    let lastSlot = Number(this._meta("last_jackpot_slot", closedSlot));
    if (!Number.isFinite(lastSlot)) lastSlot = closedSlot;
    const lastToProcess = Math.min(closedSlot, lastSlot + 16);
    for (let slot = lastSlot + 1; slot <= lastToProcess; slot++) {
      let event = this.ctx.storage.sql.exec(
        "SELECT * FROM fruit_jackpot_events WHERE slot_id=? LIMIT 1", slot,
      ).toArray()[0];
      if (!event) {
        const start = slot * JACKPOT_WINDOW_MS;
        const end = start + JACKPOT_WINDOW_MS;
        const leaders = this.ctx.storage.sql.exec(
          `SELECT user_id, SUM(amount) AS total_bet, MIN(created_at) AS first_bet
             FROM fruit_bets
            WHERE created_at >= ? AND created_at < ?
            GROUP BY user_id
            ORDER BY total_bet DESC, first_bet ASC, user_id ASC
            LIMIT 3`,
          start, end,
        ).toArray();
        const poolBefore = Math.max(0, Number(this._meta("jackpot", "85763")));
        const rawRewards = leaders.map((row, index) => {
          const percent = JACKPOT_REWARD_PERCENTAGES[index];
          return {
            rank: index + 1, user_id: String(row.user_id), percent,
            bet_coins: Number(row.total_bet || 0),
            coins: Math.floor(poolBefore * percent / 100),
          };
        }).filter(item => item.coins > 0);
        const rewardMap = new Map(rawRewards.map(item => [item.user_id, item.coins]));
        const profiles = await this._topWinnerProfiles(rewardMap);
        const byId = new Map(profiles.map(item => [String(item.user_id), item]));
        const winners = rawRewards.map(item => ({
          ...item,
          display_name: String(byId.get(item.user_id)?.display_name || item.user_id),
          avatar_data_url: byId.get(item.user_id)?.avatar_data_url || null,
          winning_coins: item.coins,
        }));
        const payout = winners.reduce((sum, item) => sum + Number(item.coins || 0), 0);
        const poolAfter = Math.max(0, poolBefore - payout);
        this.ctx.storage.transactionSync(() => {
          this.ctx.storage.sql.exec(
            "INSERT INTO fruit_jackpot_events(slot_id,opened_at,pool_before,pool_after,winners_json,paid,result_round_id) VALUES(?,?,?,?,?,0,?)",
            slot, end, poolBefore, poolAfter, JSON.stringify(winners), resultRoundId,
          );
          this._setMeta("jackpot", poolAfter);
        });
        event = this.ctx.storage.sql.exec(
          "SELECT * FROM fruit_jackpot_events WHERE slot_id=? LIMIT 1", slot,
        ).toArray()[0];
      }
      let winners = [];
      try { winners = JSON.parse(String(event.winners_json || "[]")); } catch { winners = []; }
      if (Number(event.paid || 0) !== 1) {
        try {
          if (winners.length) {
            await mainDirectory(this).awardJackpotRewards(
              "fruit-jackpot:" + slot, winners.map(item => ({
                rank: Number(item.rank), user_id: String(item.user_id),
                coins: Number(item.coins || item.winning_coins || 0), percent: Number(item.percent),
              })),
            );
          }
          this.ctx.storage.sql.exec(
            "UPDATE fruit_jackpot_events SET paid=1,result_round_id=COALESCE(result_round_id,?) WHERE slot_id=?",
            resultRoundId, slot,
          );
        } catch (error) {
          console.error("Jackpot reward delivery will retry", String(error?.message || error));
          break;
        }
      }
      const payout = Math.max(0, Number(event.pool_before || 0) - Number(event.pool_after || 0));
      if (payout > 0 && resultRoundId != null) {
        this.ctx.storage.sql.exec(
          "UPDATE fruit_results SET jackpot_hit=1,jackpot_payout=?,top_winners_json=? WHERE round_id=?",
          payout, JSON.stringify(winners), resultRoundId,
        );
      }
      this._setMeta("last_jackpot_slot", slot);
      lastSlot = slot;
    }
  }
  async _ensureStarted(now = Date.now()) {
    const currentRound = roundIdAt(now);
    if (this._meta("started_round") === null) {
      this._setMeta("started_round", currentRound);
      this._setMeta("jackpot", 85763);
    }
    if (this._meta("last_jackpot_slot") === null) {
      this._setMeta("last_jackpot_slot", Math.floor(now / JACKPOT_WINDOW_MS) - 1);
    }
    await this._sync(now);
    this._notifyPhase(now);
  }

  async _sync(now = Date.now()) {
    const recoveryPhase = roundIdAt(now) + ":" + (now >= bettingEndAt(roundIdAt(now)));
    if (this._meta("main_wallet_mode") && this._mainRecoveryPhase !== recoveryPhase) {
      try {
        await recoverMainBets(this, "fruit", "fruit_jackpot");
        this._mainRecoveryPhase = recoveryPhase;
      } catch (error) {
        console.error("Funded bet recovery will retry", String(error?.message || error));
        await this.ctx.storage.setAlarm(now + 15000);
        return;
      }
    }
    const currentRound = roundIdAt(now);
    const startedRound = Number(this._meta("started_round", currentRound));
    const lastSettledRaw = this._meta("last_settled_round");
    let nextToSettle = lastSettledRaw === null
      ? startedRound
      : Number(lastSettledRaw) + 1;

    const eligible = now >= bettingEndAt(currentRound) ? currentRound : currentRound - 1;
    // Read overdue stake-bearing rounds directly after a long idle interval.
    // Never discard a bet, payout, ledger or settled financial result.
    const overdue = this.ctx.storage.sql.exec(
      "SELECT DISTINCT round_id FROM fruit_bets WHERE round_id >= ? AND round_id <= ? ORDER BY round_id LIMIT 101",
      nextToSettle, eligible,
    ).toArray();
    for (const row of overdue.slice(0, 100)) await this._settle(Number(row.round_id));
    if (overdue.length > 100) {
      this._setMeta("last_settled_round", Number(overdue[99].round_id));
      await this.ctx.storage.setAlarm(now + 1000);
      return;
    }
    for (let round = Math.max(nextToSettle, eligible - 6); round <= eligible; round++) {
      await this._settle(round);
    }
    if (nextToSettle <= eligible) this._setMeta("last_settled_round", eligible);
    await this._openDueJackpots(now, eligible >= 0 ? eligible : null);
    const pending = this.ctx.storage.sql.exec(
      "SELECT round_id FROM fruit_bets WHERE round_id > ? LIMIT 1", eligible,
    ).toArray().length > 0;
    await flushGameResults(this, "fruit");
    const deliveryPending = pendingGameResults(this, "fruit");
    const jackpotDeliveryPending = this.ctx.storage.sql.exec(
      "SELECT slot_id FROM fruit_jackpot_events WHERE paid=0 LIMIT 1",
    ).toArray().length > 0;
    const jackpotSlotStart = Math.floor(now / JACKPOT_WINDOW_MS) * JACKPOT_WINDOW_MS;
    const jackpotHasBets = this.ctx.storage.sql.exec(
      "SELECT id FROM fruit_bets WHERE created_at>=? AND created_at<? LIMIT 1",
      jackpotSlotStart, jackpotSlotStart + JACKPOT_WINDOW_MS,
    ).toArray().length > 0;
    const watching = (this.ctx.getWebSockets?.("game:fruit-jackpot") || []).length > 0;
    if (!watching && !pending && !deliveryPending && !jackpotDeliveryPending && !jackpotHasBets) {
      if (await this.ctx.storage.getAlarm() !== null) await this.ctx.storage.deleteAlarm();
      return;
    }

    const normalNextAlarm = (deliveryPending || jackpotDeliveryPending) && !watching && !pending ? now + 15000 :
      now < bettingEndAt(currentRound)
        ? bettingEndAt(currentRound)
        : roundEndAt(currentRound);
    const jackpotNextAlarm = jackpotHasBets ? jackpotSlotStart + JACKPOT_WINDOW_MS : Number.POSITIVE_INFINITY;
    const nextAlarm = Math.min(normalNextAlarm, jackpotNextAlarm);
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
    const bonusFruits = lucky11 ? randomDistinctFruits(4) : [];
    let winner = lucky11 ? bonusFruits[0] : weightedRandomFruit();
    if (!lucky11) {
      const previous = this.ctx.storage.sql.exec(
        "SELECT fruit_key FROM fruit_results WHERE round_id<? ORDER BY round_id DESC LIMIT 1", roundId,
      ).toArray()[0];
      if (previous && String(previous.fruit_key) === winner.key) {
        for (let attempt = 0; attempt < 8; attempt++) {
          const candidate = weightedRandomFruit();
          if (candidate.key !== String(previous.fruit_key)) { winner = candidate; break; }
        }
        if (winner.key === String(previous.fruit_key)) {
          const alternatives = FRUITS.filter(fruit => fruit.key !== String(previous.fruit_key));
          winner = alternatives[randomIndex(alternatives.length)];
        }
      }
    }
    const mode = lucky11
      ? "lucky_11_random_4"
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

    this.ctx.storage.transactionSync(() => {
    const settledAt = Date.now();
    for (const userId of payoutsByUser.keys()) {
      const payout = bets.filter(bet => bet.user_id === userId && !bet.main_wallet && winningKeys.has(bet.fruit_key))
        .reduce((sum, bet) => sum + bet.amount * FRUIT_BY_KEY.get(bet.fruit_key).multiplier, 0);
      if (!payout) continue;
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
    // Bounded cleanup runs once per new settlement, never once per viewer read.
    this.ctx.storage.sql.exec(
      "DELETE FROM fruit_results WHERE round_id IN (SELECT round_id FROM fruit_results WHERE total_bet=0 AND round_id<? ORDER BY round_id LIMIT 2)",
      roundId - 19,
    );
    saveGameResults(this, "fruit", "fruit_jackpot", roundId, bets, payoutsByUser, winner, bonusFruits);
    });
    const topWinners = await this._topWinnerProfiles(payoutsByUser);
    this.ctx.storage.sql.exec(
      "UPDATE fruit_results SET top_winners_json=? WHERE round_id=?",
      JSON.stringify(topWinners),
      roundId,
    );
    if (this.env?.APP_DIRECTORY) {
      const directory = this.env.APP_DIRECTORY.get(this.env.APP_DIRECTORY.idFromName("tinni-app-directory"));
      for (const [userId, payout] of payoutsByUser) {
        if (payout < 1000000) continue;
        const roomId = bets.find((bet) => bet.user_id === userId && bet.room_id)?.room_id;
        if (roomId) try { await directory.recordGameWinning(userId, roomId, "fruit_jackpot", payout); } catch (error) { console.error("Game winning notice failed", String(error?.message || error)); }
      }
    }

  }

  async ownerStats(userIdValue = "") {
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

    const archived=this.ctx.storage.sql.exec("SELECT * FROM game_history_totals WHERE id=1").toArray()[0]||{};
    const unique=this.ctx.storage.sql.exec("SELECT COUNT(*) AS n FROM (SELECT user_id FROM fruit_bets UNION SELECT user_id FROM game_history_players)").toArray()[0];
    let player = null;
    if (userId) {
      const mainWallet = await mainDirectory(this).mainGameWallet(userId,"fruit_jackpot",true);
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
        bet_count: Number(userBet.bet_count || 0)+Number(this.ctx.storage.sql.exec("SELECT bet_count FROM game_history_players WHERE user_id=?",userId).toArray()[0]?.bet_count||0),
        total_bet: Number(userBet.total_bet || 0)+Number(this.ctx.storage.sql.exec("SELECT total_bet FROM game_history_players WHERE user_id=?",userId).toArray()[0]?.total_bet||0),
        balance: Number(mainWallet.coins),
        today_winnings: Number(wallet?.today_winnings || 0),
        net_profit: Number(mainWallet.game_net_coins || 0),
      };
    }

    return {
      bet_count: Number(totals.bet_count || 0)+Number(archived.bet_count||0),
      total_bet: Number(totals.total_bet || 0)+Number(archived.total_bet||0),
      unique_players: Number(unique?.n||0),
      rounds: Number(resultTotals.rounds || 0)+Number(archived.rounds||0),
      total_payout: Number(resultTotals.total_payout || 0)+Number(archived.total_payout||0),
      house_net: Number(totals.total_bet || 0)+Number(archived.total_bet||0)-Number(resultTotals.total_payout || 0)-Number(archived.total_payout||0),
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
              special_kind, bonus_fruits_json, jackpot_hit, jackpot_payout,
              top_winners_json
         FROM fruit_results
        WHERE settled_at >= ${now - coldStorage.GAME_HISTORY_MS}
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
      let topWinners = [];
      try {
        const parsed = JSON.parse(String(row.top_winners_json || "[]"));
        if (Array.isArray(parsed)) topWinners = parsed.slice(0, 3);
      } catch {
        topWinners = [];
      }
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
        top_winners: topWinners,
        settled_at: Number(row.settled_at),
      };
    });

    const mainWallet = userId ? await mainDirectory(this).mainGameWallet(userId,"fruit_jackpot") : {coins:0,today_winnings:0};
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
          random_bonus_fruits: 4,
        },
        fruits: FRUITS,
      },
      jackpot: Number(this._meta("jackpot", "85763")),
      jackpot_config: {
        contribution_percent: JACKPOT_CONTRIBUTION_PERCENT,
        openings_per_hour: JACKPOT_OPENINGS_PER_HOUR,
        reward_percentages: JACKPOT_REWARD_PERCENTAGES,
        next_open_at: (Math.floor(now / JACKPOT_WINDOW_MS) + 1) * JACKPOT_WINDOW_MS,
      },
      jackpot_event: this._latestJackpotEvent(),
      last_bet_result: mainWallet.last_bet_result || lastGameResult(this, "fruit", userId),
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
    if (!Number.isInteger(amount) || !ALLOWED_BET_SET.has(amount)) throw new Error("Invalid bet amount");
    if (!/^[a-zA-Z0-9_-]{16,80}$/.test(requestId)) throw new Error("Invalid bet request ID");
    const id = "fruit_jackpot:" + userId + ":" + requestId;
    const prior = this.ctx.storage.sql.exec("SELECT user_id,fruit_key,amount,room_id FROM fruit_bets WHERE id=?", id).toArray()[0];
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
        id,user_id:userId,game_key:"fruit_jackpot",round_id:roundId,
        fruit_key:fruitKey,amount,room_id:roomId,
      });
      this.ctx.storage.sql.exec(
        "INSERT OR IGNORE INTO fruit_bets(id,round_id,user_id,fruit_key,amount,room_id,created_at,main_wallet) VALUES(?,?,?,?,?,?,?,1)",
        bet.id,bet.round_id,bet.user_id,bet.fruit_key,bet.amount,bet.room_id,bet.created_at,
      );

      const contribution = Math.floor(amount * JACKPOT_CONTRIBUTION_PERCENT / 100);
      if (contribution > 0) this._setMeta("jackpot", Number(this._meta("jackpot", "85763")) + contribution);
    });
    notifyGameChanged(this, "fruit-jackpot");
    return this.state(userId);
  }
}
