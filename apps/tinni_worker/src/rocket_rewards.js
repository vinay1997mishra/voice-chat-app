export const rocketTargets = [8000000,15000000,30000000,50000000,90000000,150000000,200000000,250000000,350000000,500000000];

export function rocketPolicy(level) {
  if (!Number.isInteger(level) || level < 1 || level > 10) throw new Error("Invalid rocket level");
  return { level, winners: 50 + (level - 1) * 20, normalCoinWinners: 25,
    normalCoinMin: 2000, normalCoinMax: level >= 6 ? 30000 : 20000,
    topCoins: [400000 * level, 200000 * level, 100000 * level] };
}

export function rocketRandomInt(max) {
  if (!Number.isInteger(max) || max < 1 || max > 0x100000000) throw new Error("Invalid random bound");
  const sample = new Uint32Array(1);
  const limit = Math.floor(0x100000000 / max) * max;
  do { crypto.getRandomValues(sample); } while (sample[0] >= limit);
  return sample[0] % max;
}

export function rocketAllocation(total, amount) {
  if (!Number.isSafeInteger(total) || total < 0 || !Number.isSafeInteger(amount) || amount < 0)
    throw new Error("Invalid rocket contribution");
  let remaining = total, level = 1;
  while (level <= 10 && remaining >= rocketTargets[level - 1]) {
    remaining -= rocketTargets[level - 1]; level++;
  }
  const slices = [];
  while (amount > 0 && level <= 10) {
    const value = Math.min(amount, rocketTargets[level - 1] - remaining);
    slices.push({ level, value, completed: remaining + value === rocketTargets[level - 1] });
    amount -= value; remaining += value;
    if (remaining === rocketTargets[level - 1]) { level++; remaining = 0; }
  }
  return slices;
}

export function rocketDraw(level, ranked, candidates, randomInt = rocketRandomInt) {
  const policy = rocketPolicy(level);
  const top = ranked.filter(row => Number(row.sending) > 0).slice(0, 3);
  const seen = new Set(top.map(row => String(row.user_id)));
  const pool = [];
  for (const value of candidates) {
    const id = String(value);
    if (!id || seen.has(id)) continue;
    seen.add(id); pool.push(id);
  }
  for (let i = pool.length - 1; i > 0; i--) {
    const j = randomInt(i + 1); [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  const awards = top.map((row, index) => ({
    user_id: String(row.user_id), rank: index + 1, coins: policy.topCoins[index],
    frame_id: "rocket-l" + level + "-top" + (index + 1),
    medal: "Rocket " + level, sending: Number(row.sending),
  }));
  pool.slice(0, policy.winners - awards.length).forEach((user_id, index) => {
    const coins = index < policy.normalCoinWinners
      ? policy.normalCoinMin + randomInt(policy.normalCoinMax - policy.normalCoinMin + 1) : 0;
    awards.push({ user_id, rank: null, coins,
      frame_id: coins ? null : "rocket-l" + level + "-member" + (1 + randomInt(30)),
      medal: null, sending: 0 });
  });
  return awards;
}
