import { DurableObject } from "cloudflare:workers";

export const ROUND_MS = 20000;
export const BET_LOCK_MS = 3000;
export const HIGH_VOLUME_PLAYER_THRESHOLD = 20;
export const COMPANY_MARGIN_PERCENT = 30;
export const DEMO_START_BALANCE = 10000000;

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

function randomIndex(length) {
  if (length <= 1) return 0;
  const values = new Uint32Array(1);
  const ceiling = Math.floor(0x100000000 / length) * length;
  do {
    crypto.getRandomValues(values);
  } while (values[0] >= ceiling);
  return values[0] % length;
}

function roundIdAt(timeMs) {
  return Math.floor(timeMs / ROUND_MS);
}

function roundStartAt(roundId) {
  return roundId * ROUND_MS;
}

function roundEndAt(roundId) {
  return (roundId + 1) * ROUND_MS;
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
      DEMO_START_BALANCE,
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
    while (nextToSettle < currentRound && processed < 100) {
      await this._settle(nextToSettle);
      this._setMeta("last_settled_round", nextToSettle);
      nextToSettle += 1;
      processed += 1;
    }

    const nextAlarm = roundEndAt(currentRound);
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
    const highVolume = players.size >= HIGH_VOLUME_PLAYER_THRESHOLD && totalBet > 0;
    const mode = highVolume ? "margin_target_high_volume" : "random_low_volume";

    let winner;
    if (!highVolume) {
      winner = FRUITS[randomIndex(FRUITS.length)];
    } else {
      const targetPayout = Math.floor(
        totalBet * (100 - COMPANY_MARGIN_PERCENT) / 100,
      );
      const payoutByFruit = new Map(FRUITS.map((fruit) => [fruit.key, 0]));

      for (const bet of bets) {
        const fruit = FRUIT_BY_KEY.get(bet.fruit_key);
        if (!fruit) continue;
        payoutByFruit.set(
          fruit.key,
          payoutByFruit.get(fruit.key) + bet.amount * fruit.multiplier,
        );
      }

      const eligible = FRUITS.filter(
        (fruit) => payoutByFruit.get(fruit.key) <= targetPayout,
      );

      let candidates;
      if (eligible.length === 0) {
        const minimum = Math.min(
          ...FRUITS.map((fruit) => payoutByFruit.get(fruit.key)),
        );
        candidates = FRUITS.filter(
          (fruit) => payoutByFruit.get(fruit.key) === minimum,
        );
      } else {
        const closest = Math.max(
          ...eligible.map((fruit) => payoutByFruit.get(fruit.key)),
        );
        candidates = eligible.filter(
          (fruit) => payoutByFruit.get(fruit.key) === closest,
        );
      }

      winner = candidates[randomIndex(candidates.length)];
    }

    const payoutsByUser = new Map();
    for (const bet of bets) {
      if (bet.fruit_key !== winner.key) continue;
      const payout = bet.amount * winner.multiplier;
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

    const winnerStake = bets
      .filter((bet) => bet.fruit_key === winner.key)
      .reduce((sum, bet) => sum + bet.amount, 0);
    const totalPayout = winnerStake * winner.multiplier;
    const retained = totalBet - totalPayout;
    const targetRetained = Math.ceil(
      totalBet * COMPANY_MARGIN_PERCENT / 100,
    );
    const marginTargetMet = !highVolume || retained >= targetRetained;

    this.ctx.storage.sql.exec(
      `INSERT INTO fruit_results
        (round_id, fruit_key, mode, total_bet, total_payout, company_retained,
         active_players, margin_target_met, settled_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      roundId,
      winner.key,
      mode,
      totalBet,
      totalPayout,
      retained,
      players.size,
      marginTargetMet ? 1 : 0,
      settledAt,
    );
  }

  async state(userIdValue = "") {
    const now = Date.now();
    await this._ensureStarted(now);

    const roundId = roundIdAt(now);
    const endAt = roundEndAt(roundId);
    const remainingMs = Math.max(0, endAt - now);
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
              company_retained, active_players, margin_target_met, settled_at
         FROM fruit_results
        ORDER BY round_id DESC
        LIMIT 20`,
    ).toArray().map((row) => {
      const fruit = FRUIT_BY_KEY.get(String(row.fruit_key));
      return {
        round_id: Number(row.round_id),
        fruit,
        mode: String(row.mode),
        total_bet: Number(row.total_bet),
        total_payout: Number(row.total_payout),
        company_retained: Number(row.company_retained),
        active_players: Number(row.active_players),
        margin_target_met: Number(row.margin_target_met) === 1,
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
        round_end: endAt,
        remaining_ms: remainingMs,
        round_duration_ms: ROUND_MS,
        betting_open: remainingMs > BET_LOCK_MS,
        bet_lock_ms: BET_LOCK_MS,
        total_bet: bets.reduce((sum, bet) => sum + bet.amount, 0),
        active_players: new Set(bets.map((bet) => bet.user_id)).size,
      },
      config: {
        high_volume_player_threshold: HIGH_VOLUME_PLAYER_THRESHOLD,
        company_margin_percent: COMPANY_MARGIN_PERCENT,
        fruits: FRUITS,
      },
      jackpot: Number(this._meta("jackpot", "85763")),
      wallet_balance: wallet.balance,
      today_winnings: wallet.today_winnings,
      my_bets: myBets,
      history,
    };
  }

  async placeDemoBet(input) {
    const now = Date.now();
    await this._ensureStarted(now);

    const userId = String(input?.user_id || "").trim();
    const fruitKey = String(input?.fruit_key || "").trim();
    const amount = Number(input?.amount || 0);
    const roundId = roundIdAt(now);
    const remainingMs = roundEndAt(roundId) - now;

    if (!userId) throw new Error("user_id is required");
    if (!FRUIT_BY_KEY.has(fruitKey)) throw new Error("Invalid fruit");
    if (!Number.isInteger(amount) || amount <= 0) {
      throw new Error("Amount must be a positive integer");
    }
    if (remainingMs <= BET_LOCK_MS) {
      throw new Error("Betting is locked for this round");
    }

    this._ensureWallet(userId, now);
    const wallet = this._wallet(userId, now);
    if (wallet.balance < amount) {
      throw new Error("Not enough server test coins");
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
