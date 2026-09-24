const state = {
  serverOffsetMs: 0,
  roundEnd: 0,
  bettingOpen: false,
  amount: 1000,
  userId: localStorage.getItem("tinni_fruit_demo_user") || ("demo-" + crypto.randomUUID().slice(0, 8)),
  lastState: null,
};

localStorage.setItem("tinni_fruit_demo_user", state.userId);
document.getElementById("userId").textContent = state.userId;

const compact = (value) => {
  const n = Number(value || 0);
  if (n >= 1_000_000_000) return (n / 1_000_000_000).toFixed(n % 1_000_000_000 ? 1 : 0) + "B";
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(n % 1_000_000 ? 1 : 0) + "M";
  if (n >= 1_000) return (n / 1_000).toFixed(n % 1_000 ? 1 : 0) + "K";
  return String(n);
};

async function fetchState() {
  const before = Date.now();
  const response = await fetch("/fruit-game/state?user_id=" + encodeURIComponent(state.userId), {
    cache: "no-store",
  });
  const data = await response.json();
  if (!response.ok || !data.ok) throw new Error(data.error || "Server state failed");
  const after = Date.now();
  const midpoint = before + ((after - before) / 2);
  state.serverOffsetMs = Number(data.server_time) - midpoint;
  state.roundEnd = Number(data.round.round_end);
  state.bettingOpen = Boolean(data.round.betting_open);
  state.lastState = data;
  render(data);
}

function render(data) {
  document.getElementById("status").className = "status ok";
  document.getElementById("status").textContent = "Server online";
  document.getElementById("jackpot").textContent = compact(data.jackpot);
  document.getElementById("roundId").textContent = "#" + data.round.round_id;
  document.getElementById("totalBet").textContent = compact(data.round.total_bet);
  document.getElementById("sync").textContent = Math.abs(Math.round(state.serverOffsetMs)) + "ms";

  const grid = document.getElementById("fruitGrid");
  grid.innerHTML = data.config.fruits.map((fruit) => {
    const mine = Number(data.my_bets?.[fruit.key] || 0);
    return `
      <button class="fruit" data-fruit="${fruit.key}" ${data.round.betting_open ? "" : "disabled"}>
        <span class="emoji">${fruit.emoji}</span>
        <span class="copy">
          <b>${fruit.label}</b>
          <small>×${fruit.multiplier}</small>
          <span class="mine">Mine: ${compact(mine)}</span>
        </span>
      </button>
    `;
  }).join("");

  const history = document.getElementById("history");
  history.innerHTML = data.history.length
    ? data.history.map((result, index) => `
        <div class="result ${index === 0 ? "new" : ""}">
          ${index === 0 ? '<div class="new-label">NEW</div>' : ""}
          <div class="emoji">${result.fruit?.emoji || "?"}</div>
          <b>×${result.fruit?.multiplier || "?"}</b>
          <small>#${result.round_id}</small>
        </div>
      `).join("")
    : '<span style="color:#aa9a70;font-size:12px">First server result will appear after the current 20-second round.</span>';

  const latest = data.history[0];
  document.getElementById("modeLabel").textContent = latest
    ? (latest.mode === "random_low_volume" ? "Low-user random" : "High-volume margin mode")
    : "";
}

function tick() {
  const serverNow = Date.now() + state.serverOffsetMs;
  const remaining = Math.max(0, state.roundEnd - serverNow);
  document.getElementById("countdown").textContent = (remaining / 1000).toFixed(1);
  const open = remaining > Number(state.lastState?.round?.bet_lock_ms || 3000);
  document.getElementById("phase").textContent = open ? "Betting" : "Locked";
  document.querySelectorAll(".fruit").forEach((button) => button.disabled = !open);
}

async function placeBet(fruitKey) {
  const message = document.getElementById("betMessage");
  try {
    const response = await fetch("/fruit-game/demo-bet", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        user_id: state.userId,
        fruit_key: fruitKey,
        amount: state.amount,
      }),
    });
    const data = await response.json();
    if (!response.ok || !data.ok) throw new Error(data.error || "Bet failed");
    state.serverOffsetMs = Number(data.server_time) - Date.now();
    state.roundEnd = Number(data.round.round_end);
    state.lastState = data;
    message.textContent = compact(state.amount) + " demo bet placed on server.";
    render(data);
  } catch (error) {
    message.textContent = error.message || "Bet failed.";
  }
}

document.getElementById("chips").addEventListener("click", (event) => {
  const button = event.target.closest("[data-amount]");
  if (!button) return;
  state.amount = Number(button.dataset.amount);
  document.querySelectorAll("[data-amount]").forEach((item) => item.classList.remove("active"));
  button.classList.add("active");
});

document.getElementById("fruitGrid").addEventListener("click", (event) => {
  const button = event.target.closest("[data-fruit]");
  if (button && !button.disabled) placeBet(button.dataset.fruit);
});

document.getElementById("refresh").addEventListener("click", () => fetchState().catch(() => {}));

setInterval(tick, 100);
setInterval(() => fetchState().catch(() => {
  document.getElementById("status").className = "status";
  document.getElementById("status").textContent = "Reconnecting…";
}), 2000);

fetchState().catch((error) => {
  document.getElementById("status").textContent = error.message || "Connection failed";
});
