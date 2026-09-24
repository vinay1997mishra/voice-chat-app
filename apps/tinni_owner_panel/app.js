const API_BASE = window.location.origin;

const state = {
  treasury: 0,
  features: {
    voice_rooms: true,
    gifts: true,
    vip: true,
    games: true,
    host_system: true,
    agency_system: true,
    bd_system: true,
    coin_seller: true,
    merchant: true,
    banners: true,
    vehicle_entries: true,
    frames: true,
  },
  policies: {
    coins_per_usd: 2000000,
    diamonds_per_coin: 1,
    room_online_exp_per_minute: 50,
    room_online_daily_minutes_cap: 480,
    host_first_target_received_coins: 4000000,
    host_first_target_usd: 1.6,
    agency_commission_percent: 20,
    bd_target_1_usd: 500,
    bd_target_1_percent: 7,
    bd_target_2_usd: 1000,
    bd_target_2_percent: 10,
    minimum_transfer_usd: 2,
  },
  vips: Array.from({ length: 11 }, (_, i) => ({
    level: i + 1,
    name: `VIP ${i + 1}`,
    enabled: true,
    entry: i === 8 ? "Black Eagle + rider" : "Editable",
    frame: "Editable",
    price: 0,
  })),
};

const viewMeta = {
  dashboard: ["Dashboard", "Live platform overview and owner-only controls."],
  users: ["Users", "Search, investigate and override any user account."],
  rooms: ["Rooms", "Manage any room regardless of the user's additional role."],
  wallets: ["Wallets", "Normal, Coin Seller, Merchant and Owner Treasury controls."],
  hierarchy: ["BD / Agency / Host", "Relationship, portal, settlement and owner-override controls."],
  roles: ["Tags / Roles / Posts", "Multiple concurrent tags and posts per user ID."],
  vip: ["VIP", "Create new VIP levels and edit every function of old VIPs."],
  gifts: ["Gifts", "Create, edit, schedule, disable or remove gifts."],
  assets: ["Entries / Frames", "Vehicle, animal, 3D entry effects and frame catalog."],
  banners: ["Banners", "Schedule banners by start/end date and remove them manually."],
  games: ["Games", "Game status, bet controls and user profit/loss investigation."],
  policies: ["Policies", "Host, Agency, BD and economy configuration."],
  panels: ["Custom Panels", "Create separate staff panels and choose exact permissions."],
  audit: ["Audit Log", "Track every sensitive owner and staff action."],
};

const modules = [
  ["Users", "ID/device ban, invisible ID, locked-room bypass, public ID change"],
  ["Rooms", "Ban/unban, room name, DP, background, live room investigation"],
  ["Wallets", "Normal, Coin Seller, Merchant and Treasury management"],
  ["BD / Agency / Host", "Direct owner override, add/remove/move relationships"],
  ["Tags / Roles / Posts", "Multiple concurrent tags, roles and posts"],
  ["VIP", "Create new VIP and edit every existing VIP function"],
  ["Gifts", "Add/edit/remove gifts, price and animation assets"],
  ["Entries / Frames", "Vehicle, animal, 3D entries and all frame types"],
  ["Banners", "Schedule start/end time and manual removal"],
  ["Games", "Enable/disable, bet stats, user profit/loss"],
  ["Policies", "Host/Agency/BD targets, commissions, settlement rules"],
  ["Custom Panels", "Create 10–20+ panels with exact permissions"],
];

const hierarchyRules = [
  ["Host country", "Host can join only an Agency from the same country."],
  ["Settlement", "1–15 and 16–month end, using that country's local time."],
  ["Host target", "First target: 4,000,000 received coins = $1.60."],
  ["Agency commission", "20% of achieved Host target payout; no target = no commission."],
  ["BD target 1", "$500 combined agency target = 7% commission."],
  ["BD target 2", "$1,000 combined agency target = 10% commission."],
  ["Transfer minimum", "Host / Agency / BD dollar transfer minimum is $2."],
  ["Host exit days", "Manual owner removal/approval: 1st, 2nd, 16th, 17th."],
  ["Complaint exit", "Complaint timer: 1 month, then system auto-exit if unresolved."],
  ["Auto-exit rejoin", "48 hours to join another Agency before diamond auto-exchange."],
];

const roles = ["Host", "Agency Owner", "BD", "Coin Seller", "Merchant", "Admin", "Super Admin", "Manager", "VIP", "Custom Post"];

const dialog = document.getElementById("actionDialog");
const dialogTitle = document.getElementById("dialogTitle");
const dialogHelp = document.getElementById("dialogHelp");
const dialogFields = document.getElementById("dialogFields");
const dialogSubmit = document.getElementById("dialogSubmit");
let pendingAction = null;

function pretty(key) {
  return key.split("_").map(x => x.charAt(0).toUpperCase() + x.slice(1)).join(" ");
}

function fmt(n) {
  return new Intl.NumberFormat("en-US").format(Number(n || 0));
}

function toast(message) {
  const el = document.getElementById("toast");
  el.textContent = message;
  el.classList.add("show");
  clearTimeout(toast.t);
  toast.t = setTimeout(() => el.classList.remove("show"), 2600);
}

function setView(name) {
  document.querySelectorAll(".view").forEach(v => v.classList.remove("active"));
  document.querySelectorAll(".nav-item").forEach(v => v.classList.remove("active"));
  document.getElementById(`view-${name}`)?.classList.add("active");
  document.querySelector(`[data-view="${name}"]`)?.classList.add("active");
  const [title, sub] = viewMeta[name] || [name, ""];
  document.getElementById("pageTitle").textContent = title;
  document.getElementById("pageSubtitle").textContent = sub;
  document.getElementById("sidebar").classList.remove("open");
}

async function api(path, options = {}) {
  const response = await fetch(API_BASE + path, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
  return data;
}

async function checkHealth() {
  const status = document.getElementById("apiStatus");
  try {
    const data = await api("/health");
    status.className = "api-status ok";
    status.innerHTML = "<i></i>" + (data.message || "Server online");
  } catch (e) {
    status.className = "api-status bad";
    status.innerHTML = "<i></i>Server unavailable";
  }
}

function renderFeatures() {
  const root = document.getElementById("featureSwitches");
  root.innerHTML = "";
  Object.entries(state.features).forEach(([key, value]) => {
    const row = document.createElement("div");
    row.className = "switch-row";
    row.innerHTML = `
      <div class="switch-copy"><strong>${pretty(key)}</strong><small>Master feature flag</small></div>
      <label class="switch"><input type="checkbox" ${value ? "checked" : ""} data-feature="${key}"><span class="slider"></span></label>
    `;
    root.appendChild(row);
  });
}

function renderModules() {
  const root = document.getElementById("moduleGrid");
  root.innerHTML = modules.map(([name, sub], i) => `
    <button class="module-card" data-module="${name}">
      <span class="module-icon">${["◎","▣","◫","⌘","✦","♛","◆","◉","▰","♟","⚙","▦"][i]}</span>
      <b>${name}</b><small>${sub}</small>
    </button>
  `).join("");
}

function renderHierarchyRules() {
  document.getElementById("hierarchyRules").innerHTML = hierarchyRules.map(([a,b]) => `
    <div class="rule"><strong>${a}</strong><span>${b}</span></div>
  `).join("");
}

function renderRoles() {
  document.getElementById("roleChips").innerHTML = roles.map(r => `<span class="chip">${r}</span>`).join("");
}

function renderVips() {
  const root = document.getElementById("vipTable");
  root.innerHTML = state.vips.map(v => `
    <tr>
      <td>${v.level}</td>
      <td>${v.name}</td>
      <td><span class="badge ${v.enabled ? "gold" : ""}">${v.enabled ? "Active" : "Off"}</span></td>
      <td>${v.entry}</td>
      <td>${v.frame}</td>
      <td>${fmt(v.price)}</td>
      <td class="table-actions"><button data-vip-edit="${v.level}">Edit</button><button data-vip-toggle="${v.level}">${v.enabled ? "Disable" : "Enable"}</button></td>
    </tr>
  `).join("");
}

function renderPolicies() {
  const root = document.getElementById("policyList");
  root.innerHTML = Object.entries(state.policies).map(([key, value]) => `
    <div class="policy-row">
      <div><strong>${pretty(key)}</strong><small>Current value: ${value}</small></div>
      <button data-policy-edit="${key}">Edit</button>
    </div>
  `).join("");
}

function renderTreasury() {
  document.getElementById("treasuryBalance").textContent = fmt(state.treasury);
  document.getElementById("statTreasury").textContent = fmt(state.treasury);
}

function field(name, label, type = "text", placeholder = "") {
  if (type === "select") return "";
  return `<label><span>${label}</span><input name="${name}" type="${type}" placeholder="${placeholder}" required></label>`;
}

function selectField(name, label, options) {
  return `<label><span>${label}</span><select name="${name}">${options.map(o => `<option value="${o[0]}">${o[1]}</option>`).join("")}</select></label>`;
}

function checkboxField(name, label, checked = false) {
  return `<label class="checkbox-field"><input name="${name}" type="checkbox" value="true" ${checked ? "checked" : ""}><span>${label}</span></label>`;
}

function staffPanelFields() {
  return field("name", "Panel name", "text", "Support Panel") +
    field("assigned_user_id", "Assign to user ID (optional)", "text", "10000001") +
    field("staff_email", "Staff login Gmail / Email", "email", "staff@example.com") +
    field("login_password", "Login password", "password", "Minimum 10 characters") +
    field("confirm_password", "Confirm password", "password", "Enter password again") +
    '<div class="dialog-section-title">Panel permissions</div>' +
    checkboxField("permission_users", "Users", true) +
    checkboxField("permission_rooms", "Rooms") +
    checkboxField("permission_wallets", "Wallets") +
    checkboxField("permission_hierarchy", "BD / Agency / Host") +
    checkboxField("permission_roles", "Tags / Roles / Posts") +
    checkboxField("permission_vip", "VIP") +
    checkboxField("permission_gifts", "Gifts") +
    checkboxField("permission_assets", "Entries / Frames") +
    checkboxField("permission_banners", "Banners") +
    checkboxField("permission_games", "Games") +
    checkboxField("permission_policies", "Policies") +
    checkboxField("permission_audit", "Audit Log");
}

function openAction(action, preset = {}) {
  pendingAction = action;
  dialogFields.innerHTML = "";
  dialogTitle.textContent = "Owner Action";
  dialogHelp.textContent = "This web panel will send protected commands to the Tinni backend once the owner API is connected.";

  const maps = {
    "treasury-add": ["Add Coins to Owner Treasury", field("amount","Coin amount","number","100000000")],
    "treasury-send": ["Send Owner Treasury Coins",
      field("user_id","Receiver user ID","text","10000001") +
      field("amount","Coin amount","number","2000000") +
      selectField("wallet_type","Receiver wallet",[["normal","Normal User Wallet"],["coin_seller","Coin Seller Wallet"],["merchant","Merchant Wallet"]])
    ],
    "user-search": ["Search User", field("user_id","Current or old user ID","text","10000001")],
    "user-ban": ["ID Ban / Unban", field("user_id","User ID") + selectField("status","Action",[["ban","Ban"],["unban","Unban"]]) + field("reason","Reason")],
    "device-ban": ["Device Ban / Unban", field("user_id","User ID") + selectField("status","Action",[["ban","Ban device"],["unban","Unban device"]])],
    "user-invisible": ["Invisible ID", field("user_id","User ID") + selectField("status","Status",[["on","Invisible ON"],["off","Invisible OFF"]])],
    "locked-bypass": ["Locked-room Bypass", field("user_id","User ID") + selectField("status","Status",[["on","Allow bypass"],["off","Remove bypass"]])],
    "id-change": ["Change Public ID", field("user_id","Current user ID") + field("new_id","New public ID")],
    "room-ban": ["Room Ban / Unban", field("room_id","Room ID") + selectField("status","Action",[["ban","Ban"],["unban","Unban"]])],
    "room-name": ["Change Room Name", field("room_id","Room ID") + field("room_name","New room name")],
    "room-dp": ["Change Room DP", field("room_id","Room ID") + field("asset_url","DP asset URL")],
    "room-bg": ["Room Background", field("room_id","Room ID") + field("asset_url","Background asset URL")],
    "wallet-normal": ["Manage Normal Wallet", field("user_id","User ID") + field("amount","Coin amount","number") + selectField("operation","Operation",[["credit","Add coins"],["debit","Remove coins"],["ban","Ban wallet"],["unban","Unban wallet"]])],
    "wallet-seller": ["Manage Coin Seller Wallet", field("user_id","User ID") + field("amount","Coin amount","number") + selectField("operation","Operation",[["create","Create/activate"],["credit","Add coins"],["debit","Remove coins"],["ban","Ban"],["unban","Unban"]])],
    "wallet-merchant": ["Manage Merchant Wallet", field("user_id","User ID") + field("amount","Coin amount","number") + selectField("operation","Operation",[["create","Create/activate"],["credit","Add coins"],["debit","Remove coins"],["ban","Ban"],["unban","Unban"]])],
    "bd-activate": ["BD Role", field("user_id","User ID") + selectField("operation","Operation",[["activate","Activate BD"],["remove","Remove BD"]])],
    "agency-activate": ["Agency Role", field("user_id","User ID") + selectField("operation","Operation",[["activate","Activate Agency"],["remove","Remove Agency"]])],
    "agency-to-bd": ["Add Agency to BD", field("agency_owner_id","Agency owner ID") + field("bd_user_id","BD user ID")],
    "agency-from-bd": ["Remove Agency from BD", field("agency_owner_id","Agency owner ID") + field("bd_user_id","BD user ID")],
    "host-add": ["Add Host to Agency", field("host_user_id","Host user ID") + field("agency_owner_id","Agency owner ID")],
    "host-remove": ["Remove Host from Agency", field("host_user_id","Host user ID") + field("agency_owner_id","Agency owner ID")],
    "vip-grant": ["Grant / Remove VIP", field("user_id","User ID") + field("vip_level","VIP level","number") + selectField("operation","Operation",[["grant","Grant"],["remove","Remove"]])],
    "gift-new": ["Add New Gift", field("name","Gift name") + field("coin_price","Coin price","number") + field("asset_url","Animation / asset URL")],
    "entry-new": ["Add Entry Effect", field("name","Entry name") + field("asset_url","Vehicle/animal/3D asset URL") + field("vip_level","Assign VIP level","number")],
    "frame-new": ["Add Frame", field("name","Frame name") + field("asset_url","Frame asset URL") + field("vip_level","Assign VIP level","number")],
    "banner-new": ["Schedule Banner", field("title","Banner title") + field("asset_url","Banner image URL") + field("starts_at","Start date/time","datetime-local") + field("ends_at","Auto-remove date/time","datetime-local")],
    "panel-new": ["Create Custom Panel + Staff Login", staffPanelFields()],
    "role-new": ["Create Tag / Role / Post", field("name","Name") + selectField("type","Type",[["tag","Tag"],["role","Role"],["post","Post"]])],
    "policy-new": ["Create New Setting", field("key","Setting key") + field("value","Value")],
  };

  const item = maps[action] || [pretty(action), field("target_id","Target user / room ID") + field("reason","Reason / details")];
  dialogTitle.textContent = item[0];
  dialogFields.innerHTML = item[1];
  Object.entries(preset).forEach(([k,v]) => {
    const el = dialogFields.querySelector(`[name="${k}"]`);
    if (el) el.value = v;
  });
  dialog.showModal();
}

async function handleAction(action, data) {
  if (action === "panel-new") {
    const password = String(data.login_password || "");
    const confirmPassword = String(data.confirm_password || "");
    if (password.length < 10) throw new Error("Staff password must be at least 10 characters.");
    if (password !== confirmPassword) throw new Error("Password and confirm password do not match.");

    const permissions = Object.entries(data)
      .filter(([key, value]) => key.startsWith("permission_") && value === "true")
      .map(([key]) => key.replace("permission_", ""));

    const payload = {
      name: String(data.name || "").trim(),
      assigned_user_id: String(data.assigned_user_id || "").trim(),
      staff_email: String(data.staff_email || "").trim().toLowerCase(),
      password,
      permissions,
    };

    await api("/api/staff/panels", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    toast("Staff panel created with login credentials.");
    return;
  }

  if (action === "treasury-add") {
    const amount = Number(data.amount || 0);
    if (amount <= 0) throw new Error("Enter a valid coin amount");
    state.treasury += amount;
    renderTreasury();
    toast(`${fmt(amount)} coins added to Owner Treasury preview`);
    return;
  }

  if (action === "treasury-send") {
    const amount = Number(data.amount || 0);
    if (amount <= 0 || amount > state.treasury) throw new Error("Treasury balance is not enough");
    state.treasury -= amount;
    renderTreasury();
    toast(`Preview transfer: ${fmt(amount)} coins → ${data.user_id} (${data.wallet_type})`);
    return;
  }

  // Owner APIs are intentionally not guessed. Until the protected backend routes exist,
  // the panel keeps the UI ready and refuses to pretend the server action succeeded.
  throw new Error("Owner API for this action is not connected yet");
}

document.getElementById("nav").addEventListener("click", e => {
  const btn = e.target.closest("[data-view]");
  if (btn) setView(btn.dataset.view);
});

document.getElementById("menuBtn").addEventListener("click", () => {
  document.getElementById("sidebar").classList.toggle("open");
});

document.getElementById("refreshBtn").addEventListener("click", () => {
  checkHealth();
  toast("Panel refreshed");
});

document.getElementById("logoutBtn")?.addEventListener("click", async () => {
  await fetch("/auth/logout", { method: "POST" }).catch(() => null);
  window.location.replace("/login");
});

document.getElementById("quickActionBtn").addEventListener("click", () => openAction("user-search"));

document.getElementById("globalSearch").addEventListener("keydown", e => {
  if (e.key === "Enter" && e.target.value.trim()) {
    setView("users");
    document.getElementById("userSearchId").value = e.target.value.trim();
    openAction("user-search", { user_id: e.target.value.trim() });
  }
});

document.body.addEventListener("change", e => {
  const input = e.target.closest("[data-feature]");
  if (!input) return;
  state.features[input.dataset.feature] = input.checked;
  toast(`${pretty(input.dataset.feature)} ${input.checked ? "enabled" : "disabled"} in panel preview`);
});

document.body.addEventListener("click", e => {
  const action = e.target.closest("[data-action]")?.dataset.action;
  if (action) return openAction(action);

  const moduleName = e.target.closest("[data-module]")?.dataset.module;
  if (moduleName) {
    const match = Object.entries(viewMeta).find(([,meta]) => meta[0] === moduleName);
    if (match) setView(match[0]);
  }

  const vipEdit = e.target.closest("[data-vip-edit]")?.dataset.vipEdit;
  if (vipEdit) {
    const vip = state.vips.find(v => v.level === Number(vipEdit));
    openAction("vip-edit", {
      target_id: `VIP ${vip.level}`,
      reason: `${vip.name} | Entry: ${vip.entry} | Frame: ${vip.frame}`
    });
  }

  const vipToggle = e.target.closest("[data-vip-toggle]")?.dataset.vipToggle;
  if (vipToggle) {
    const vip = state.vips.find(v => v.level === Number(vipToggle));
    vip.enabled = !vip.enabled;
    renderVips();
    toast(`${vip.name} ${vip.enabled ? "enabled" : "disabled"} in preview`);
  }

  const policyKey = e.target.closest("[data-policy-edit]")?.dataset.policyEdit;
  if (policyKey) {
    const value = prompt(`New value for ${pretty(policyKey)}`, state.policies[policyKey]);
    if (value !== null && value !== "") {
      state.policies[policyKey] = Number.isNaN(Number(value)) ? value : Number(value);
      renderPolicies();
      toast(`${pretty(policyKey)} changed in panel preview`);
    }
  }
});

document.getElementById("actionForm").addEventListener("submit", async e => {
  if (e.submitter?.value === "cancel") return;
  e.preventDefault();
  const data = Object.fromEntries(new FormData(e.currentTarget).entries());
  dialogSubmit.disabled = true;
  dialogSubmit.textContent = "Working…";
  try {
    await handleAction(pendingAction, data);
    dialog.close();
  } catch (err) {
    toast(err.message);
  } finally {
    dialogSubmit.disabled = false;
    dialogSubmit.textContent = "Confirm";
  }
});

document.getElementById("userSearchId").addEventListener("keydown", e => {
  if (e.key === "Enter") openAction("user-search", { user_id: e.target.value.trim() });
});

renderFeatures();
renderModules();
renderHierarchyRules();
renderRoles();
renderVips();
renderPolicies();
renderTreasury();
checkHealth();
