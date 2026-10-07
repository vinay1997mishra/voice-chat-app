// One latest receipt per player. Financial bet/result history stays in the game tables.
export function saveGameResults(store, prefix, gameKey, roundId, bets, payouts, winner, bonusFruits) {
  const totals = new Map();
  for (const bet of bets) totals.set(bet.user_id, (totals.get(bet.user_id) || 0) + bet.amount);
  for (const [userId, totalBet] of totals) {
    const winnings = payouts.get(userId) || 0;
    const winningKeys = new Set(
      bonusFruits.length ? bonusFruits.map((fruit) => fruit.key) : [winner.key],
    );
    const userBets = bets.filter((bet) => bet.user_id === userId).map((bet) => {
      const winningCoins = winningKeys.has(bet.fruit_key)
        ? bet.amount * fruitMultiplier(gameKey, bet.fruit_key)
        : 0;
      return {
        id: bet.id,
        fruit_key: bet.fruit_key,
        bet_coins: bet.amount,
        winning_coins: winningCoins,
        outcome: winningCoins > 0 ? 'win' : 'lose',
      };
    });
    const result = {
      id: gameKey + ':' + roundId + ':' + userId, user_id: userId, game_key: gameKey,
      round_id: roundId, outcome: winnings > 0 ? 'win' : 'lose',
      bet_coins: totalBet, winning_coins: winnings, net_coins: winnings - totalBet,
      fruit_key: winner.key, bonus_fruits: bonusFruits.map(fruit => fruit.key),
      bets: userBets,
      wallet_balance: bets.some(bet => bet.user_id === userId && bet.main_wallet) ? 0 : store._wallet(userId).balance, settled_at: Date.now(),
      main_bets: userBets.filter((item) => bets.some((bet) => bet.id === item.id && bet.main_wallet)).map((item) => ({
        id: item.id, winning_coins: item.winning_coins,
      })),
    };
    store.ctx.storage.sql.exec(
      'INSERT OR IGNORE INTO ' + prefix + '_result_outbox(user_id,round_id,payload) VALUES(?,?,?)',
      userId, roundId, JSON.stringify(result),
    );
    store.ctx.storage.sql.exec(
      'INSERT INTO ' + prefix + '_latest_results(user_id,round_id,payload,delivered) VALUES(?,?,?,0) ' +
      'ON CONFLICT(user_id) DO UPDATE SET round_id=excluded.round_id,payload=excluded.payload,delivered=0 ' +
      'WHERE excluded.round_id > ' + prefix + '_latest_results.round_id',
      userId, roundId, JSON.stringify(result),
    );
  }
}
export function lastGameResult(store, prefix, userId) {
  const row = store.ctx.storage.sql.exec(
    'SELECT payload FROM ' + prefix + '_latest_results WHERE user_id=? LIMIT 1', userId,
  ).toArray()[0];
  return row ? JSON.parse(row.payload) : null;
}
export function pendingGameResults(store, prefix) {
  if (!store.env?.APP_DIRECTORY) return false;
  return store.ctx.storage.sql.exec(
    'SELECT user_id FROM ' + prefix + '_result_outbox LIMIT 1',
  ).toArray().length > 0;
}
export async function flushGameResults(store, prefix) {
  if (!store.env?.APP_DIRECTORY) return;
  const rows = store.ctx.storage.sql.exec(
    'SELECT user_id,round_id,payload FROM ' + prefix + '_result_outbox LIMIT 500',
  ).toArray();
  if (!rows.length) return;
  try {
    const directory = store.env.APP_DIRECTORY.get(store.env.APP_DIRECTORY.idFromName('tinni-app-directory'));
    await directory.recordGameResults(rows.map(row => JSON.parse(row.payload)));
    store.ctx.storage.transactionSync(() => {
      for (const row of rows) store.ctx.storage.sql.exec(
        'DELETE FROM ' + prefix + '_result_outbox WHERE user_id=? AND round_id=?',
        row.user_id, row.round_id,
      );
    });
  } catch (error) { console.error('Game result delivery will retry', String(error?.message || error)); }
}

export function fruitMultiplier(gameKey, key) {
  const values = gameKey === 'fruit_jackpot'
    ? {lemon:5,raspberry:5,kiwi:5,plum:5,banana:10,strawberry:10,watermelon:20,cherry:40}
    : {lemon:5,raspberry:5,kiwi:5,plum:5,banana:10,strawberry:15,watermelon:25,cherry:45};
  return values[key] || 0;
}
export function mainDirectory(store) {
  if (!store.env?.APP_DIRECTORY) throw new Error('Main wallet is unavailable');
  return store.env.APP_DIRECTORY.get(store.env.APP_DIRECTORY.idFromName('tinni-app-directory'));
}
export async function recoverMainBets(store, prefix, gameKey) {
  let cursor = "";
  while (true) {
    const bets = await mainDirectory(store).pendingMainGameBets(gameKey,cursor);
    store.ctx.storage.transactionSync(() => {
      for (const bet of bets) store.ctx.storage.sql.exec(
        'INSERT INTO ' + prefix + '_bets(id,round_id,user_id,fruit_key,amount,room_id,created_at,main_wallet) VALUES(?,?,?,?,?,?,?,1) ' +
        'ON CONFLICT(id) DO UPDATE SET user_id=excluded.user_id',
        bet.id,bet.round_id,bet.user_id,bet.fruit_key,bet.amount,bet.room_id,bet.created_at,
      );
    });
    if (bets.length < 500) break;
    cursor = bets.at(-1).id;
  }
}
