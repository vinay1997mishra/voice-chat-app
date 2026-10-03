const API_BASE = window.location.origin;

const state = {
  treasury: 0,
  features: {},
  policies: {},
  gameConfig: {},
  luckyGiftConfig: {},
  catalog: [],
  vips: [],
};

const viewMeta = {
  dashboard: ["Dashboard", "Live platform overview and owner-only controls."],
  notifications: ["Notifications", "Owner-only app complaints and platform alerts."],
  users: ["Users", "Search, investigate and override any user account."],
  verification: ["Call Verification", "Verified IDs, verification requests and direct Owner verification."],
  messaging: ["Messages & Tags", "Search/select users, send Official messages and apply custom colored tags."],
  rooms: ["Rooms", "Manage any room regardless of the user's additional role."],
  wallets: ["Wallets", "Normal, Coin Seller, Merchant and Owner Treasury controls."],
  hierarchy: ["BD / Agency / Host", "Relationship, portal, settlement and owner-override controls."],
  roles: ["Roles / Posts", "Reusable role and post definitions. User tags are managed in Messages & Tags."],
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
  ["Call Verification", "Verified IDs, requests and direct Owner verification"],
  ["Messages & Tags", "Bulk Official messages, selected IDs and custom colored tags"],
  ["Rooms", "Ban/unban, room name, DP, background, live room investigation"],
  ["Wallets", "Normal, Coin Seller, Merchant and Treasury management"],
  ["BD / Agency / Host", "Direct owner override, add/remove/move relationships"],
  ["Roles / Posts", "Reusable roles and posts"],
  ["VIP", "Create new VIP and edit existing VIP functions"],
  ["Gifts", "Add/edit/disable gifts, price and animation assets"],
  ["Entries / Frames", "Vehicle, animal, 3D entries and frame catalog"],
  ["Banners", "Schedule start/end time and disable banners"],
  ["Games", "Enable/disable, bet limits and stats"],
  ["Policies", "Host/Agency/BD targets, commissions, settlement rules"],
  ["Custom Panels", "Create staff panels with exact permissions"],
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
let currentSession = null;
const ownerSelectedUsers = new Map();
let ownerOfficials = [];
let ownerOfficialPosition = "";

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

const permissionByView = {
  users: "users",
  verification: "users",
  messaging: "users",
  rooms: "rooms",
  wallets: "wallets",
  hierarchy: "hierarchy",
  roles: "roles",
  vip: "vip",
  gifts: "gifts",
  assets: "assets",
  banners: "banners",
  games: "games",
  policies: "policies",
  audit: "audit",
};

const permissionByModule = {
  "Users": "users",
  "Call Verification": "users",
  "Messages & Tags": "users",
  "Rooms": "rooms",
  "Wallets": "wallets",
  "BD / Agency / Host": "hierarchy",
  "Roles / Posts": "roles",
  "VIP": "vip",
  "Gifts": "gifts",
  "Entries / Frames": "assets",
  "Banners": "banners",
  "Games": "games",
  "Policies": "policies",
};

const staffPermissionGroups = [
  {
    key: "users",
    label: "Users",
    items: [
      ["users.search", "Search / view user details"],
      ["users.ban_id", "ID ban / unban"],
      ["users.ban_device", "Device ban / unban"],
      ["users.invisible", "Invisible ID"],
      ["users.locked_room_bypass", "Locked-room bypass"],
      ["users.change_id", "Change public ID"],
      ["users.unique_id", "Create and price purchasable unique IDs"],
    ],
  },
  {
    key: "rooms",
    label: "Rooms",
    items: [
      ["rooms.search", "Search / view room details"],
      ["rooms.ban", "Room ban / unban"],
      ["rooms.rename", "Change room name"],
      ["rooms.dp", "Change room DP"],
      ["rooms.background", "Add / remove room background"],
      ["rooms.live_seats", "View live users / seats"],
      ["rooms.theme_view", "View room themes"],
      ["rooms.theme_create", "Add / schedule room themes"],
      ["rooms.theme_remove", "Remove room themes"],
    ],
  },
  {
    key: "wallets",
    label: "Wallets",
    items: [
      ["wallets.normal", "Manage normal user wallet"],
      ["wallets.seller", "Manage Coin Seller wallet"],
      ["wallets.merchant", "Manage Merchant wallet"],
      ["wallets.treasury_send", "Send Owner Treasury coins"],
    ],
  },
  {
    key: "hierarchy",
    label: "BD / Agency / Host",
    items: [
      ["hierarchy.bd_manage", "Activate / remove BD"],
      ["hierarchy.agency_manage", "Activate / remove Agency"],
      ["hierarchy.agency_bd_link", "Add / remove Agency under BD"],
      ["hierarchy.host_manage", "Add / remove Host"],
      ["hierarchy.targets", "Targets / commission controls"],
      ["hierarchy.complaints", "Exit requests / complaints"],
    ],
  },
  {
    key: "roles",
    label: "Tags / Roles / Posts",
    items: [
      ["roles.view", "View tags / roles / posts"],
      ["roles.manage", "Create / edit / remove tags, roles and posts"],
    ],
  },
  {
    key: "vip",
    label: "VIP",
    items: [
      ["vip.view", "View VIP settings"],
      ["vip.create", "Create VIP level"],
      ["vip.edit", "Edit VIP functions / properties"],
      ["vip.toggle", "Enable / disable VIP"],
      ["vip.grant_remove", "Grant / remove VIP from user"],
    ],
  },
  {
    key: "gifts",
    label: "Gifts",
    items: [
      ["gifts.view", "View gift catalog"],
      ["gifts.create", "Add gifts"],
      ["gifts.edit", "Edit gifts / prices / assets"],
      ["gifts.remove", "Remove / disable gifts"],
    ],
  },
  {
    key: "assets",
    label: "Entries / Frames",
    items: [
      ["assets.entries", "Manage vehicle / animal / 3D entries"],
      ["assets.frames", "Manage profile / seat / VIP frames"],
    ],
  },
  {
    key: "banners",
    label: "Banners",
    items: [
      ["banners.view", "View banners"],
      ["banners.create", "Create / schedule banners"],
      ["banners.remove", "Remove banners"],
    ],
  },
  {
    key: "games",
    label: "Games",
    items: [
      ["games.view", "View game status / stats"],
      ["games.toggle", "Enable / disable games"],
      ["games.limits", "Change bet limits"],
      ["games.investigate", "User betting investigation"],
    ],
  },
  {
    key: "policies",
    label: "Policies",
    items: [
      ["policies.view", "View policies / economy"],
      ["policies.create", "Create settings"],
      ["policies.edit", "Edit targets / commissions / rules"],
      ["policies.pricing", "Change all coin purchase rates, gifts, unique IDs and free rules"],
    ],
  },
  {
    key: "audit",
    label: "Audit Log",
    items: [
      ["audit.view", "View audit log"],
      ["audit.export", "Export audit log"],
    ],
  },
];

const actionPermission = {
  "user-search": "users.search",
  "user-ban": "users.ban_id",
  "device-ban": "users.ban_device",
  "user-invisible": "users.invisible",
  "locked-bypass": "users.locked_room_bypass",
  "id-change": "users.change_id",
  "unique-id-new": "users.unique_id",
  "unique-id-price": "users.unique_id",
  "room-ban": "rooms.ban",
  "room-name": "rooms.rename",
  "room-dp": "rooms.dp",
  "room-bg": "rooms.background",
  "room-live": "rooms.live_seats",
  "room-theme-new": "rooms.theme_create",
  "wallet-normal": "wallets.normal",
  "wallet-seller": "wallets.seller",
  "wallet-merchant": "wallets.merchant",
  "treasury-send": "wallets.treasury_send",
  "wallet-security-unfreeze": "__owner_only__",
  "bd-activate": "hierarchy.bd_manage",
  "agency-activate": "hierarchy.agency_manage",
  "agency-to-bd": "hierarchy.agency_bd_link",
  "agency-from-bd": "hierarchy.agency_bd_link",
  "host-add": "hierarchy.host_manage",
  "host-remove": "hierarchy.host_manage",
  "bd-target": "hierarchy.targets",
  "complaints": "hierarchy.complaints",
  "role-new": "roles.manage",
  "vip-new": "vip.create",
  "vip-grant": "vip.grant_remove",
  "gift-new": "gifts.create",
  "lucky-gift-config": "gifts.edit",
  "entry-new": "assets.entries",
  "profile-card-new": "assets.frames",
  "frame-new": "assets.frames",
  "banner-new": "banners.create",
  "game-switch": "games.toggle",
  "game-limits": "games.limits",
  "game-stats": "games.investigate",
  "policy-new": "policies.create",
  "policy-set": "policies.edit",
  "feature-set": "policies.edit",
  "pricing-set": "policies.pricing",
  "user-price-override-set": "policies.pricing",
  "user-price-override-remove": "policies.pricing",
  // Catalog permissions are resolved from the item's kind at click time.
  "catalog-toggle": "roles.manage",
  "catalog-edit": "roles.manage",
  "catalog-remove": "roles.manage",
  "audit-export": "audit.export",
};

function catalogPermission(item, operation) {
  const kind = String(item?.kind || "");
  if (kind === "vip") return operation === "toggle" ? "vip.toggle" : "vip.edit";
  if (kind === "gift") return operation === "remove" ? "gifts.remove" : (operation === "edit" ? "gifts.edit" : "gifts.remove");
  if (kind === "entry" || kind === "vehicle" || kind === "frame" || kind === "profile_card") return (kind === "entry" || kind === "vehicle") ? "assets.entries" : "assets.frames";
  if (kind === "banner") return operation === "remove" ? "banners.remove" : "banners.create";
  return "roles.manage";
}

function hasPermission(allowed, permission) {
  if (!permission) return false;
  const group = permission.split(".")[0];
  return allowed.has(group) || allowed.has(permission);
}

function hasGroupPermission(allowed, group) {
  return allowed.has(group) || [...allowed].some((permission) => permission.startsWith(group + "."));
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

async function updateStaffPanelPower(panelId, patch) {
  return api("/api/staff/panels/" + encodeURIComponent(panelId), {
    method: "PATCH",
    body: JSON.stringify(patch),
  });
}

async function loadStaffPanels() {
  const root = document.getElementById("customPanels");
  if (!root) return;
  try {
    const data = await api("/api/staff/panels");
    const panels = Array.isArray(data.panels) ? data.panels : [];
    if (panels.length === 0) {
      root.className = "empty-state";
      root.textContent = "No staff panels created yet.";
      return;
    }

    root.className = "staff-panel-list";
    root.innerHTML = panels.map(panel => {
      const activePermissions = new Set(panel.permissions || []);
      const panelId = escapeHtml(panel.id);
      return `
        <article class="staff-panel-card" data-staff-panel="${panelId}">
          <div class="staff-panel-head">
            <div class="staff-panel-identity">
              <strong>${escapeHtml(panel.name)}</strong>
              <small>${escapeHtml(panel.email)}</small>
              ${panel.assigned_user_id ? `<small>User ID: ${escapeHtml(panel.assigned_user_id)}</small>` : ""}
            </div>
            <div class="staff-panel-actions">
              <label class="staff-master-toggle">
                <input
                  type="checkbox"
                  data-staff-enabled
                  data-panel-id="${panelId}"
                  ${panel.enabled ? "checked" : ""}
                >
                <span>${panel.enabled ? "Login Active" : "Login Disabled"}</span>
              </label>
              <button
                type="button"
                class="staff-credentials-btn"
                data-staff-credentials
                data-panel-id="${panelId}"
                data-staff-email="${escapeHtml(panel.email)}"
              >Change Gmail / Password</button>
            </div>
          </div>

          <div class="staff-power-title">Powers / Permissions</div>
          <div class="staff-permission-groups">
            ${staffPermissionGroups.map(group => {
              const inherited = activePermissions.has(group.key);
              const allChildren = group.items.every(([key]) => inherited || activePermissions.has(key));
              return `
                <details class="staff-permission-group" open>
                  <summary>
                    <strong>${group.label}</strong>
                    <label class="staff-group-toggle" onclick="event.stopPropagation()">
                      <input
                        type="checkbox"
                        data-staff-group
                        data-panel-id="${panelId}"
                        data-group="${group.key}"
                        ${allChildren ? "checked" : ""}
                      >
                      <span>All</span>
                    </label>
                  </summary>
                  <div class="staff-power-grid">
                    ${group.items.map(([key, label]) => `
                      <label class="staff-power-toggle">
                        <input
                          type="checkbox"
                          data-staff-permission
                          data-panel-id="${panelId}"
                          data-permission="${key}"
                          ${inherited || activePermissions.has(key) ? "checked" : ""}
                        >
                        <span>${label}</span>
                      </label>
                    `).join("")}
                  </div>
                </details>
              `;
            }).join("")}
          </div>
        </article>
      `;
    }).join("");
  } catch (error) {
    root.className = "empty-state";
    root.textContent = error.message || "Unable to load staff panels.";
  }
}

function formatThemeTime(value) {
  if (value === null || value === undefined || value === "") return "";
  const date = new Date(Number(value));
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleString();
}

async function loadRoomThemes() {
  const root = document.getElementById('roomThemeList');
  if (!root) return;
  try {
    const data = await api('/api/room-themes');
    const themes = Array.isArray(data.themes) ? data.themes : [];
    if (themes.length === 0) {
      root.className = 'empty-state';
      root.textContent = 'No global room themes added from the panel yet.';
      return;
    }
    root.className = 'action-list';
    root.innerHTML = themes.map(theme => {
      const start = theme.starts_at ? formatThemeTime(theme.starts_at) : 'Immediately';
      const timing = theme.expires_at
        ? start + ' → ' + formatThemeTime(theme.expires_at)
        : start + ' → Permanent';
      return `
        <button type="button" data-room-theme-remove="${escapeHtml(theme.id)}">
          <strong>${escapeHtml(theme.name)}</strong>
          <span>Free global theme • ${escapeHtml(timing)} • tap to remove</span>
        </button>
      `;
    }).join('');
  } catch (error) {
    root.className = 'empty-state';
    root.textContent = error.message || 'Unable to load room themes.';
  }
}
function formatFullTimestamp(value) {
  const date = new Date(Number(value));
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleString(undefined, {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

function auditDetailsText(details) {
  if (!details || typeof details !== "object") return "";
  return Object.entries(details)
    .map(([key, value]) => {
      const rendered = typeof value === "object" && value !== null
        ? JSON.stringify(value)
        : String(value);
      return `${pretty(key.replaceAll(".", "_"))}: ${rendered}`;
    })
    .join(" • ");
}

async function loadCallVerifications() {
  const root = document.getElementById("callVerificationList");
  if (!root || currentSession?.role !== "owner") return;
  try {
    const data = await api("/api/call-verifications");
    const items = (Array.isArray(data.submissions) ? data.submissions : [])
      .filter((item) => item.status === "pending_owner");
    if (items.length === 0) {
      root.className = "empty-state";
      root.textContent = "No pending verification requests.";
      return;
    }

    root.className = "action-list";
    root.innerHTML = items.map((item) => {
      const photos = Array.isArray(item.photos) ? item.photos.slice(0, 3) : [];
      return `
        <article class="staff-panel-card">
          <div class="staff-panel-head">
            <div class="staff-panel-identity">
              <strong>${escapeHtml(item.display_name || item.user_id)}</strong>
              <small>ID ${escapeHtml(item.user_id)} • ${escapeHtml(item.gender || "")}</small>
              <small>${item.system_passed ? "System pre-check passed" : "System pre-check needs review"}</small>
            </div>
            <span class="badge">Pending Owner</span>
          </div>
          <div style="display:flex;gap:8px;overflow-x:auto;margin:10px 0">
            ${photos.map((src, index) => `
              <a href="${escapeHtml(src)}" target="_blank" rel="noopener">
                <img
                  src="${escapeHtml(src)}"
                  alt="Verification photo ${index + 1}"
                  style="width:132px;height:168px;object-fit:cover;border-radius:12px;border:1px solid #5a4a25"
                >
              </a>
            `).join("")}
          </div>
          <div class="table-actions">
            <button data-call-verify-approve="${escapeHtml(item.id)}">Approve Verified</button>
            <button data-call-verify-reject="${escapeHtml(item.id)}">Reject</button>
          </div>
        </article>
      `;
    }).join("");
  } catch (error) {
    root.className = "empty-state";
    root.textContent = error.message || "Unable to load verification requests.";
  }
}

async function loadVerifiedUsers(query = "") {
  const root = document.getElementById("verifiedUsersList");
  if (!root || currentSession?.role !== "owner") return;
  try {
    const data = await api("/api/owner/verified-users?q=" + encodeURIComponent(query));
    const users = Array.isArray(data.users) ? data.users : [];
    if (users.length === 0) {
      root.className = "empty-state";
      root.textContent = "No Verified IDs found.";
      return;
    }
    root.className = "action-list";
    root.innerHTML = users.map((user) => `
      <div class="panel" style="margin-top:10px">
        <div class="panel-head">
          <div>
            <strong>${escapeHtml(user.display_name || user.user_id)}</strong>
            <p>ID ${escapeHtml(user.user_id)} • ${escapeHtml(user.gender || "")}</p>
            <small>Verified: ${escapeHtml(formatFullTimestamp(user.call_verified_at))}</small>
          </div>
          <span class="badge gold">Verified</span>
        </div>
        <div class="button-row">
          <button type="button" class="btn secondary" data-call-verify-revoke="${escapeHtml(user.user_id)}">Remove Verified</button>
        </div>
      </div>
    `).join("");
  } catch (error) {
    root.className = "empty-state";
    root.textContent = error.message || "Unable to load Verified IDs.";
  }
}

function userTagHtml(tags) {
  const items = Array.isArray(tags) ? tags : [];
  return items.map((tag) => {
    const label = String(tag.designation || tag.name || "Tag");
    if (String(tag.kind || "") === "v_official") {
      const bg = String(tag.background_color || tag.color || "#69C9FF");
      return `<span class="owner-v-tag" style="--official-bg:${escapeHtml(bg)}"><i>V</i><b>${escapeHtml(label)}</b></span>`;
    }
    return `<span class="badge" style="border-color:${escapeHtml(tag.color || "#FFD54F")};color:${escapeHtml(tag.color || "#FFD54F")}">${escapeHtml(label)}</span>`;
  }).join(" ");
}

async function searchDirectVerifyUsers(query) {
  const root = document.getElementById("manualCallVerifyResults");
  if (!root) return;
  const value = String(query || "").trim();
  if (!value) {
    root.className = "empty-state";
    root.textContent = "Enter an ID or name first.";
    return;
  }
  try {
    const data = await api("/api/owner/users/search?q=" + encodeURIComponent(value) + "&limit=20");
    const users = Array.isArray(data.users) ? data.users : [];
    if (users.length === 0) {
      root.className = "empty-state";
      root.textContent = "No matching ID found.";
      return;
    }
    root.className = "action-list";
    root.innerHTML = users.map((user) => `
      <div class="panel" style="margin-top:10px">
        <div class="panel-head">
          <div>
            <strong>${escapeHtml(user.display_name || user.user_id)}</strong>
            <p>ID ${escapeHtml(user.user_id)} • ${escapeHtml(user.gender || "")} • ${escapeHtml(user.country_name || "")}</p>
            <div>${userTagHtml(user.tags)}</div>
          </div>
          <span class="badge ${user.call_verified ? "gold" : ""}">${user.call_verified ? "Verified" : "Not Verified"}</span>
        </div>
        <div class="button-row">
          ${user.call_verified
            ? `<button type="button" class="btn secondary" data-call-verify-revoke="${escapeHtml(user.user_id)}">Remove Verified</button>`
            : `<button type="button" class="btn primary" data-direct-verify-user="${escapeHtml(user.user_id)}">Verify This ID</button>`}
        </div>
      </div>
    `).join("");
  } catch (error) {
    root.className = "empty-state";
    root.textContent = error.message || "Unable to search IDs.";
  }
}

function renderOwnerSelectedCount() {
  const root = document.getElementById("ownerSelectedCount");
  if (root) root.textContent = ownerSelectedUsers.size + " selected";
}

async function searchOwnerMessagingUsers(query) {
  const root = document.getElementById("ownerUserSearchResults");
  if (!root) return;
  try {
    const data = await api("/api/owner/users/search?q=" + encodeURIComponent(String(query || "")) + "&limit=100");
    const users = Array.isArray(data.users) ? data.users : [];
    if (users.length === 0) {
      root.className = "empty-state";
      root.textContent = "No matching users.";
      return;
    }
    root.className = "action-list";
    root.innerHTML = users.map((user) => {
      const checked = ownerSelectedUsers.has(String(user.user_id));
      return `
        <div class="panel owner-search-user-row" style="margin-top:8px">
          <label class="owner-search-user-select">
            <input type="checkbox" data-owner-user-select="${escapeHtml(user.user_id)}" ${checked ? "checked" : ""}>
            <div style="flex:1">
              <strong>${escapeHtml(user.display_name || user.user_id)}</strong>
              <div class="muted">ID ${escapeHtml(user.user_id)} • ${escapeHtml(user.gender || "")} • ${escapeHtml(user.country_name || "")}</div>
              <div style="margin-top:4px">${userTagHtml(user.identity_tags || user.tags)}</div>
            </div>
          </label>
          <div class="button-row">
            <span class="badge ${user.call_verified ? "gold" : ""}">${user.call_verified ? "Verified" : "User"}</span>
            <button type="button" class="btn secondary" data-owner-open-profile="${escapeHtml(user.user_id)}">Open ID</button>
          </div>
        </div>
      `;
    }).join("");
  } catch (error) {
    root.className = "empty-state";
    root.textContent = error.message || "Unable to search users.";
  }
}

function officialBadgeHtml(item) {
  const bg = String(item?.background_color || "#69C9FF");
  return `<span class="owner-v-tag official-large" style="--official-bg:${escapeHtml(bg)}"><i>V</i><b>${escapeHtml(item?.designation || "Official")}</b></span>`;
}

function renderOfficials() {
  const tabs = document.getElementById("officialPositionTabs");
  const page = document.getElementById("officialPositionPage");
  if (!tabs || !page) return;

  const positions = [...new Set(
    ownerOfficials.map((item) => String(item.designation || "Official").trim()).filter(Boolean)
  )].sort((a, b) => a.localeCompare(b));

  if (!ownerOfficialPosition || !positions.includes(ownerOfficialPosition)) {
    ownerOfficialPosition = positions[0] || "";
  }

  tabs.innerHTML = positions.map((position) =>
    `<button type="button" class="official-position-tab ${position === ownerOfficialPosition ? "active" : ""}" data-official-position="${escapeHtml(position)}">${escapeHtml(position)}</button>`
  ).join("");

  const rows = ownerOfficials.filter(
    (item) => String(item.designation || "Official") === ownerOfficialPosition
  );
  if (!ownerOfficialPosition || rows.length === 0) {
    page.className = "empty-state";
    page.textContent = "No V Officials assigned yet.";
    return;
  }

  page.className = "action-list";
  page.innerHTML = rows.map((item) => `
    <div class="panel official-user-row" data-owner-open-profile="${escapeHtml(item.user_id)}">
      <div class="official-user-main">
        ${item.avatar_data_url
          ? `<img class="official-avatar" src="${escapeHtml(item.avatar_data_url)}" alt="">`
          : `<div class="official-avatar official-avatar-fallback">◎</div>`}
        <div>
          <strong>${escapeHtml(item.display_name || item.user_id)}</strong>
          <div class="muted">ID ${escapeHtml(item.user_id)} • ${escapeHtml(item.country_name || "")}</div>
          <div style="margin-top:7px">${officialBadgeHtml(item)}</div>
        </div>
      </div>
      <div class="button-row official-actions">
        <button type="button" class="btn primary" data-owner-open-profile="${escapeHtml(item.user_id)}">Full Details</button>
        <button type="button" class="btn secondary" data-owner-official-edit="${escapeHtml(item.user_id)}"
          data-tag-id="${escapeHtml(item.tag_id)}"
          data-designation="${escapeHtml(item.designation)}"
          data-background="${escapeHtml(item.background_color)}">Edit Position</button>
        <button type="button" class="btn secondary" data-owner-official-remove="${escapeHtml(item.user_id)}"
          data-tag-id="${escapeHtml(item.tag_id)}">Remove Official</button>
      </div>
    </div>
  `).join("");
}

async function loadOfficials(preferredPosition = "") {
  const page = document.getElementById("officialPositionPage");
  try {
    const data = await api("/api/owner/officials");
    ownerOfficials = Array.isArray(data.officials) ? data.officials : [];
    if (preferredPosition) ownerOfficialPosition = preferredPosition;
    renderOfficials();
  } catch (error) {
    if (page) {
      page.className = "empty-state";
      page.textContent = error.message || "Unable to load Officials.";
    }
  }
}

function ownerDetailRoleHtml(roles) {
  const items = Array.isArray(roles) ? roles.filter((item) => item.active !== false) : [];
  return items.length
    ? items.map((item) => `<span class="badge gold">${escapeHtml(item.role || "Role")}</span>`).join(" ")
    : '<span class="muted">No active hierarchy role</span>';
}

async function openOwnerUserProfile(userId) {
  const dialog = document.getElementById("ownerProfileDialog");
  const root = document.getElementById("ownerProfileContent");
  if (!dialog || !root) return;
  const requestedUserId = String(userId || "").trim();
  root.innerHTML = '<div class="empty-state">Loading full ID…</div>';
  root.dataset.ownerProfileUserId = requestedUserId;
  if (!dialog.open) dialog.showModal();

  try {
    const data = await api("/api/owner/user-detail?user_id=" + encodeURIComponent(requestedUserId));
    const detail = data.detail || {};
    const user = detail.user || {};
    const room = detail.current_room;
    const messages = Array.isArray(detail.messages) ? detail.messages : [];
    const calls = Array.isArray(detail.calls) ? detail.calls : [];
    const identityTags = Array.isArray(detail.identity_tags) ? detail.identity_tags : [];
    const currentVip = Number(detail.controls?.vip_level || 0);

    root.dataset.ownerProfileUserId = String(user.user_id || requestedUserId);
    root.innerHTML = `
      <div class="owner-profile-hero">
        ${user.avatar_data_url
          ? `<img src="${escapeHtml(user.avatar_data_url)}" alt="" class="owner-profile-avatar">`
          : '<div class="owner-profile-avatar owner-profile-avatar-fallback">◎</div>'}
        <div class="owner-profile-main-copy">
          <h2>${escapeHtml(user.display_name || user.user_id || "User")}</h2>
          <p>ID ${escapeHtml(user.user_id || "")} • ${escapeHtml(user.gender || "")} • ${escapeHtml(user.country_name || "")}</p>
          <div class="chips">${userTagHtml(identityTags)}</div>
        </div>
      </div>

      <div class="rule-grid owner-profile-grid">
        <div class="rule"><strong>Email</strong><span>${escapeHtml(user.email || "—")}</span></div>
        <div class="rule owner-control-rule">
          <div class="owner-control-head"><strong>Coins</strong><span>${fmt(detail.wallet?.coins || 0)}</span></div>
          <div class="owner-inline-control">
            <input type="number" min="1" step="1" inputmode="numeric" placeholder="Amount" data-owner-wallet-amount="coins">
            <button type="button" class="btn primary" data-owner-wallet-change data-user-id="${escapeHtml(user.user_id)}" data-asset="coins" data-operation="credit">+ Add</button>
            <button type="button" class="btn secondary" data-owner-wallet-change data-user-id="${escapeHtml(user.user_id)}" data-asset="coins" data-operation="debit">− Remove</button>
          </div>
        </div>
        <div class="rule owner-control-rule">
          <div class="owner-control-head"><strong>Diamonds</strong><span>${fmt(detail.wallet?.diamonds || 0)}</span></div>
          <div class="owner-inline-control">
            <input type="number" min="1" step="1" inputmode="numeric" placeholder="Amount" data-owner-wallet-amount="diamonds">
            <button type="button" class="btn primary" data-owner-wallet-change data-user-id="${escapeHtml(user.user_id)}" data-asset="diamonds" data-operation="credit">+ Add</button>
            <button type="button" class="btn secondary" data-owner-wallet-change data-user-id="${escapeHtml(user.user_id)}" data-asset="diamonds" data-operation="debit">− Remove</button>
          </div>
        </div>
        <div class="rule owner-control-rule">
          <div class="owner-control-head"><strong>VIP</strong><span>${currentVip || "None"}</span></div>
          <div class="owner-inline-control owner-vip-control">
            <input type="number" min="1" step="1" inputmode="numeric" placeholder="VIP level" data-owner-vip-level value="${currentVip || ""}">
            <button type="button" class="btn primary" data-owner-vip-change data-user-id="${escapeHtml(user.user_id)}" data-operation="grant">Add / Change</button>
            <button type="button" class="btn secondary" data-owner-vip-change data-user-id="${escapeHtml(user.user_id)}" data-operation="remove">Remove</button>
          </div>
        </div>
        <div class="rule"><strong>Roles</strong><span>${ownerDetailRoleHtml(detail.hierarchy)}</span></div>
        <div class="rule"><strong>Last seen</strong><span>${escapeHtml(formatFullTimestamp(detail.presence?.last_seen))}</span></div>
        <div class="rule"><strong>Current room</strong><span>${room ? escapeHtml(room.room_name + " • " + room.room_id) : "Not in a live room"}</span></div>
        <div class="rule"><strong>Seat</strong><span>${room ? (room.seat_index === null || room.seat_index === undefined ? "Audience" : "Seat " + (Number(room.seat_index) + 1)) : "—"}</span></div>
      </div>

      <div class="button-row owner-profile-actions" style="margin-top:12px">
        <button type="button" class="btn primary" data-owner-profile-fullview>Full View</button>
        ${room ? `<button type="button" class="btn secondary" data-owner-listen-room="${escapeHtml(room.room_id)}">Listen to Room — no mic</button>` : ""}
      </div>

      <div class="grid two owner-detail-sections">
        <section class="panel owner-inbox-card">
          <div class="panel-head">
            <div><h3>Inbox / Messages</h3><p>Open every conversation for this ID.</p></div>
            <div class="button-row">
              <span class="badge">${messages.length}</span>
              <button type="button" class="btn primary" data-owner-open-inbox="${escapeHtml(user.user_id)}">Open all inbox</button>
            </div>
          </div>
          <div class="owner-history-list">
            ${messages.length ? messages.slice(0, 8).map((message) => `
              <div class="owner-history-row">
                <strong>${escapeHtml(message.from_user_id)} → ${escapeHtml(message.to_user_id)}</strong>
                <span>${escapeHtml(message.text)}</span>
                <small>${escapeHtml(formatFullTimestamp(message.created_at))}</small>
              </div>
            `).join("") : '<div class="empty-state">No stored Tinni messages.</div>'}
          </div>
        </section>
        <section class="panel">
          <div class="panel-head"><h3>Call History</h3><span class="badge">${calls.length}</span></div>
          <div class="owner-history-list">
            ${calls.length ? calls.map((call) => `
              <div class="owner-history-row">
                <strong>${escapeHtml(call.caller_id)} → ${escapeHtml(call.receiver_id)}</strong>
                <span>${escapeHtml(call.media)} • ${escapeHtml(call.state)}</span>
                <small>${escapeHtml(formatFullTimestamp(call.updated_at || call.created_at))}</small>
              </div>
            `).join("") : '<div class="empty-state">No stored Tinni call history.</div>'}
          </div>
        </section>
      </div>

      <section id="ownerInboxBrowser" class="panel owner-inbox-browser" hidden></section>
    `;
  } catch (error) {
    root.innerHTML = `<div class="empty-state">${escapeHtml(error.message || "Unable to open ID.")}</div>`;
  }
}

async function loadOwnerInbox(userId) {
  const browser = document.getElementById("ownerInboxBrowser");
  if (!browser) return;
  browser.hidden = false;
  browser.innerHTML = '<div class="empty-state">Loading complete inbox…</div>';
  browser.scrollIntoView({ behavior: "smooth", block: "start" });

  try {
    const data = await api("/api/owner/user-inbox?user_id=" + encodeURIComponent(String(userId || "")));
    const threads = Array.isArray(data.threads) ? data.threads : [];
    const target = data.user || {};
    browser.innerHTML = `
      <div class="panel-head">
        <div>
          <h3>${escapeHtml(target.display_name || target.user_id || "User")} — All Inbox</h3>
          <p>ID ${escapeHtml(target.user_id || userId)} • ${threads.length} conversations</p>
        </div>
        <button type="button" class="btn secondary" data-owner-close-inbox>Close Inbox</button>
      </div>
      <div class="owner-thread-list">
        ${threads.length ? threads.map((thread) => `
          <button type="button" class="owner-thread-row"
            data-owner-open-thread
            data-owner-user-id="${escapeHtml(target.user_id || userId)}"
            data-peer-user-id="${escapeHtml(thread.user_id)}"
            data-peer-name="${escapeHtml(thread.display_name || thread.user_id)}">
            <div class="owner-thread-avatar">
              ${thread.avatar_data_url
                ? `<img src="${escapeHtml(thread.avatar_data_url)}" alt="">`
                : '<span>◎</span>'}
            </div>
            <div class="owner-thread-copy">
              <strong>${escapeHtml(thread.display_name || thread.user_id)}</strong>
              <small>ID ${escapeHtml(thread.user_id)}${thread.is_friend ? " • Friend" : ""}</small>
              <span>${escapeHtml(thread.last_message?.text || "No messages yet")}</span>
            </div>
            <div class="owner-thread-meta">
              <b>${fmt(thread.message_count || 0)}</b>
              <small>${thread.last_message?.created_at ? escapeHtml(formatFullTimestamp(thread.last_message.created_at)) : ""}</small>
            </div>
          </button>
        `).join("") : '<div class="empty-state">No friend or message conversations found.</div>'}
      </div>
    `;
  } catch (error) {
    browser.innerHTML = `<div class="empty-state">${escapeHtml(error.message || "Unable to load inbox.")}</div>`;
  }
}

async function loadOwnerConversation(userId, peerUserId, peerName = "") {
  const browser = document.getElementById("ownerInboxBrowser");
  if (!browser) return;
  browser.hidden = false;
  browser.innerHTML = '<div class="empty-state">Loading conversation…</div>';

  try {
    const data = await api(
      "/api/owner/user-conversation?user_id=" + encodeURIComponent(String(userId || "")) +
      "&peer_user_id=" + encodeURIComponent(String(peerUserId || "")) +
      "&limit=1000"
    );
    const messages = Array.isArray(data.messages) ? data.messages : [];
    const target = data.user || {};
    const peer = data.peer || {};
    const targetId = String(target.user_id || userId);
    browser.innerHTML = `
      <div class="panel-head">
        <div>
          <h3>${escapeHtml(target.display_name || targetId)} ↔ ${escapeHtml(peer.display_name || peerName || peerUserId)}</h3>
          <p>ID ${escapeHtml(targetId)} ↔ ID ${escapeHtml(peer.user_id || peerUserId)} • ${messages.length} messages</p>
        </div>
        <div class="button-row">
          <button type="button" class="btn secondary" data-owner-back-inbox="${escapeHtml(targetId)}">Back to Inbox</button>
          <button type="button" class="btn secondary" data-owner-close-inbox>Close</button>
        </div>
      </div>
      <div class="owner-conversation-list">
        ${messages.length ? messages.map((message) => {
          const fromTarget = String(message.from) === targetId;
          const senderName = fromTarget
            ? (target.display_name || targetId)
            : (peer.display_name || peer.user_id || peerUserId);
          return `
            <div class="owner-message-row ${fromTarget ? "from-target" : "from-peer"}">
              <strong>${escapeHtml(senderName)} <small>ID ${escapeHtml(message.from)}</small></strong>
              <span>${escapeHtml(message.text)}</span>
              <small>${escapeHtml(formatFullTimestamp(message.created_at))}${message.seen_at ? " • Seen" : ""}</small>
            </div>
          `;
        }).join("") : '<div class="empty-state">No messages in this conversation.</div>'}
      </div>
    `;
  } catch (error) {
    browser.innerHTML = `<div class="empty-state">${escapeHtml(error.message || "Unable to load conversation.")}</div>`;
  }
}

async function loadOwnerNotifications() {
  const root = document.getElementById("ownerNotifications");
  if (!root || currentSession?.role !== "owner") return;
  try {
    const data = await api("/api/owner/notifications");
    const items = Array.isArray(data.notifications) ? data.notifications : [];
    document.getElementById("notificationUnreadCount").textContent = String(data.unread_count || 0);
    document.getElementById("notificationTotalCount").textContent = String(items.length);

    if (items.length === 0) {
      root.className = "empty-state";
      root.textContent = "No owner notifications yet.";
      return;
    }

    root.className = "action-list";
    root.innerHTML = items.map((item) => {
      const source = item.source_user_id
        ? `${escapeHtml(item.source_display_name || "User")} • ID ${escapeHtml(item.source_user_id)}`
        : "System";
      const target = item.target_id
        ? ` • ${escapeHtml(item.target_type || "target")}: ${escapeHtml(item.target_id)}`
        : "";
      return `
        <div class="panel" style="margin-bottom:12px">
          <div class="panel-head">
            <div>
              <h3>${item.is_read ? "" : "● "}${escapeHtml(item.title)}</h3>
              <p>${source}${target} • ${escapeHtml(formatFullTimestamp(item.created_at))}</p>
            </div>
            <div class="button-row">
              ${item.is_read ? "" : `<button type="button" class="btn secondary" data-notification-read="${escapeHtml(item.id)}">Mark read</button>`}
              <button type="button" class="btn secondary" data-notification-delete="${escapeHtml(item.id)}">Delete</button>
            </div>
          </div>
          <p>${escapeHtml(item.message)}</p>
          ${Array.isArray(item.metadata?.screenshots) && item.metadata.screenshots.length
            ? `<div style="display:flex;gap:8px;overflow-x:auto;padding-top:8px">
                ${item.metadata.screenshots.slice(0, 5).map((src, index) => `
                  <a href="${escapeHtml(src)}" target="_blank" rel="noopener" title="Screenshot ${index + 1}">
                    <img
                      src="${escapeHtml(src)}"
                      alt="Report screenshot ${index + 1}"
                      style="width:88px;height:88px;object-fit:cover;border-radius:10px;border:1px solid #8f681e"
                    >
                  </a>
                `).join("")}
              </div>`
            : ""}
          ${item.type === "user_report" ? `
            <div class="button-row" style="margin-top:12px;flex-wrap:wrap">
              ${item.source_user_id ? `
                <button
                  type="button"
                  class="btn secondary"
                  data-official-message-user="${escapeHtml(item.source_user_id)}"
                  data-official-message-name="${escapeHtml(item.source_display_name || "Reporter")}"
                  data-official-message-kind="reporter"
                  data-official-message-report="${escapeHtml(item.id)}"
                >Message reporter</button>` : ""}
              ${item.target_id ? `
                <button
                  type="button"
                  class="btn secondary"
                  data-official-message-user="${escapeHtml(item.target_id)}"
                  data-official-message-name="${escapeHtml(item.metadata?.target_display_name || "Reported user")}"
                  data-official-message-kind="reported_user"
                  data-official-message-report="${escapeHtml(item.id)}"
                >Message reported ID</button>` : ""}
              <span class="badge gold">Sender: Tinni Official</span>
            </div>`
          : ""}
        </div>
      `;
    }).join("");
  } catch (error) {
    root.className = "empty-state";
    root.textContent = error.message || "Unable to load notifications.";
  }
}

async function loadAuditLog() {
  const table = document.getElementById("auditTable");
  const summaryRoot = document.getElementById("auditSummary");
  if (!table || !summaryRoot || !currentSession) return;

  try {
    const [recordsData, summaryData] = await Promise.all([
      api("/api/audit?limit=250"),
      api("/api/audit/summary"),
    ]);
    const records = Array.isArray(recordsData.records) ? recordsData.records : [];
    const byPanel = Array.isArray(summaryData.summary?.by_panel)
      ? summaryData.summary.by_panel
      : [];
    const byAction = Array.isArray(summaryData.summary?.by_action)
      ? summaryData.summary.by_action
      : [];

    summaryRoot.className = "";
    summaryRoot.innerHTML = byPanel.length === 0
      ? '<div class="empty-state">No panel activity recorded yet.</div>'
      : `
        <div class="chips">
          ${byPanel.map((item) => `<span class="chip">${escapeHtml(item.panel_name || item.panel_id || "Panel")}: ${Number(item.total_actions || 0)} actions</span>`).join("")}
        </div>
        ${byAction.length ? `<p class="muted" style="margin-top:12px">${byAction.slice(0, 12).map((item) => `${escapeHtml(pretty(item.action.replaceAll(".", "_")))}: ${Number(item.count || 0)}`).join(" • ")}</p>` : ""}
      `;

    const canDelete = recordsData.can_delete === true;
    const clearButton = document.getElementById("clearAuditBtn");
    if (clearButton) clearButton.hidden = !canDelete;

    if (records.length === 0) {
      table.innerHTML = '<tr><td colspan="6" class="muted">No audit records yet.</td></tr>';
      return;
    }

    table.innerHTML = records.map((record) => `
      <tr>
        <td>${escapeHtml(formatFullTimestamp(record.created_at))}</td>
        <td>
          <strong>${escapeHtml(record.panel_name || record.panel_id || "Panel")}</strong>
          <br><small>${escapeHtml(record.actor_email || "")}</small>
        </td>
        <td>${escapeHtml(pretty(String(record.action || "").replaceAll(".", "_")))}</td>
        <td>${escapeHtml(record.target_type || "—")}${record.target_id ? `<br><small>${escapeHtml(record.target_id)}</small>` : ""}</td>
        <td>${escapeHtml(auditDetailsText(record.details) || "—")}</td>
        <td>${canDelete ? `<button type="button" data-audit-delete="${escapeHtml(record.id)}">Delete</button>` : "Owner only"}</td>
      </tr>
    `).join("");
  } catch (error) {
    table.innerHTML = `<tr><td colspan="6" class="muted">${escapeHtml(error.message || "Unable to load audit records.")}</td></tr>`;
    summaryRoot.className = "empty-state";
    summaryRoot.textContent = error.message || "Unable to load audit summary.";
  }
}

function applySession(session) {
  currentSession = session;
  const owner = session.role === "owner";
  const allowed = new Set(session.permissions || []);

  document.querySelectorAll(".nav-item").forEach((button) => {
    const view = button.dataset.view;
    if (owner) {
      button.hidden = false;
      return;
    }
    const permission = permissionByView[view];
    button.hidden = !permission || !hasGroupPermission(allowed, permission);
  });

  document.querySelectorAll(".module-card").forEach((button) => {
    if (owner) {
      button.hidden = false;
      return;
    }
    const permission = permissionByModule[button.dataset.module];
    button.hidden = !permission || !hasGroupPermission(allowed, permission);
  });

  document.querySelectorAll("[data-action]").forEach((button) => {
    if (owner) {
      button.hidden = false;
      return;
    }
    const required = actionPermission[button.dataset.action];
    if (required) button.hidden = !hasPermission(allowed, required);
  });

  document.querySelectorAll("[data-vip-edit]").forEach((button) => {
    if (!owner) button.hidden = !hasPermission(allowed, "vip.edit");
  });
  document.querySelectorAll("[data-vip-toggle]").forEach((button) => {
    if (!owner) button.hidden = !hasPermission(allowed, "vip.toggle");
  });
  document.querySelectorAll("[data-policy-edit]").forEach((button) => {
    if (!owner) button.hidden = !hasPermission(allowed, "policies.edit");
  });

  const ownerChip = document.querySelector(".owner-chip div");
  if (ownerChip) {
    ownerChip.innerHTML = owner
      ? "<strong>Platform Owner</strong><small>Full owner access</small>"
      : `<strong>${escapeHtml(session.panelName || "Staff")}</strong><small>${escapeHtml(session.email || "")}</small>`;
  }

  const quickAction = document.getElementById("quickActionBtn");
  if (quickAction) quickAction.hidden = !owner && !hasPermission(allowed, "users.search");

  const clearAuditButton = document.getElementById("clearAuditBtn");
  if (clearAuditButton) clearAuditButton.hidden = !owner;

  if (owner) {
    document.body.classList.remove("auth-loading");
    document.body.classList.add("auth-ready");
    loadOwnerState();
    loadStaffPanels();
    loadRoomThemes();
    loadOwnerNotifications();
    loadOfficials();
    loadCallVerifications();
    loadVerifiedUsers();
    loadGameStats().catch(() => null);
    loadAuditLog();
    return;
  }

  if (hasPermission(allowed, "rooms.theme_view")) loadRoomThemes();
  if (hasPermission(allowed, "audit.view")) loadAuditLog();

  const firstAllowed = Object.keys(permissionByView).find((view) => hasGroupPermission(allowed, permissionByView[view]));
  if (firstAllowed) setView(firstAllowed);
  document.body.classList.remove("auth-loading");
  document.body.classList.add("auth-ready");
}

async function loadSession() {
  try {
    const session = await api("/auth/session");
    applySession(session);
  } catch {
    window.location.replace("/login");
  }
}

async function loadOwnerState() {
  if (currentSession?.role !== "owner") return;
  try {
    const data = await api("/api/owner/state");
    const serverState = data.state || {};
    state.features = serverState.features || {};
    state.policies = serverState.policies || {};
    state.gameConfig = serverState.game_config || {};
    state.luckyGiftConfig = serverState.lucky_gift_config || {};
    state.treasury = Number(serverState.treasury?.balance || 0);
    state.catalog = Array.isArray(serverState.catalog) ? serverState.catalog : [];
    state.vips = state.catalog
      .filter((item) => item.kind === "vip")
      .map((item) => ({
        id: item.id,
        level: Number(item.data?.level || 0),
        name: item.name,
        enabled: item.enabled === true,
        entry: String(item.data?.entry || ""),
        frame: String(item.data?.frame || ""),
        price: Number(item.data?.price || 0),
        data: { ...(item.data || {}) },
      }))
      .sort((a, b) => a.level - b.level);

    document.getElementById("statOnline").textContent = fmt(data.dashboard?.users || 0);
    document.getElementById("statRooms").textContent = fmt(data.dashboard?.active_rooms || 0);
    document.getElementById("statSending").textContent = fmt(data.dashboard?.sending_today || 0);

    renderFeatures();
    renderRoles();
    renderVips();
    renderPolicies();
    renderTreasury();
    renderOwnerCatalogs();
  } catch (error) {
    toast(error.message || "Unable to load Owner state.");
  }
}

function renderFeatures() {
  const root = document.getElementById("featureSwitches");
  if (!root) return;
  root.innerHTML = "";
  Object.entries(state.features).forEach(([key, value]) => {
    const row = document.createElement("div");
    row.className = "switch-row";
    row.innerHTML = `
      <div class="switch-copy"><strong>${pretty(key)}</strong><small>Server master feature flag</small></div>
      <label class="switch"><input type="checkbox" ${value ? "checked" : ""} data-feature="${escapeHtml(key)}"><span class="slider"></span></label>
    `;
    root.appendChild(row);
  });
}

function renderModules() {
  const root = document.getElementById("moduleGrid");
  if (!root) return;
  const icons = ["◎","✓","✉","▣","◫","⌘","✦","♛","◆","◉","▰","♟","⚙","▦"];
  root.innerHTML = modules.map(([name, sub], i) => `
    <button class="module-card" data-module="${escapeHtml(name)}">
      <span class="module-icon">${icons[i] || "◈"}</span>
      <b>${escapeHtml(name)}</b><small>${escapeHtml(sub)}</small>
    </button>
  `).join("");
}

function renderHierarchyRules() {
  const root = document.getElementById("hierarchyRules");
  if (!root) return;
  root.innerHTML = hierarchyRules.map(([a,b]) => `
    <div class="rule"><strong>${escapeHtml(a)}</strong><span>${escapeHtml(b)}</span></div>
  `).join("");
}

function renderRoles() {
  const root = document.getElementById("roleChips");
  if (!root) return;
  const items = state.catalog.filter((item) =>
    (item.kind === "role" || item.kind === "post") && item.enabled !== false
  );
  root.innerHTML = items.length
    ? items.map((item) => `
        <span class="chip">
          ${escapeHtml(item.name)}
          <button type="button" data-catalog-edit="${escapeHtml(item.id)}" title="Edit">Edit</button>
          <button type="button" data-catalog-toggle="${escapeHtml(item.id)}" data-next-enabled="false" title="Disable">Disable</button>
          <button type="button" data-catalog-remove="${escapeHtml(item.id)}" title="Remove">Remove</button>
        </span>
      `).join("")
    : '<span class="muted">No roles/posts yet.</span>';
}

function renderVips() {
  const root = document.getElementById("vipTable");
  if (!root) return;
  root.innerHTML = state.vips.map(v => `
    <tr>
      <td>${v.level}</td>
      <td>${escapeHtml(v.name)}</td>
      <td><span class="badge ${v.enabled ? "gold" : ""}">${v.enabled ? "Active" : "Off"}</span></td>
      <td>${escapeHtml(v.entry)}</td>
      <td>${escapeHtml(v.frame)}</td>
      <td>${fmt(v.price)}</td>
      <td class="table-actions">
        <button data-vip-edit="${escapeHtml(v.id)}">Edit</button>
        <button data-vip-toggle="${escapeHtml(v.id)}">${v.enabled ? "Disable" : "Enable"}</button>
        <button data-catalog-remove="${escapeHtml(v.id)}">Remove</button>
      </td>
    </tr>
  `).join("");
}

function renderPolicies() {
  const root = document.getElementById("policyList");
  if (!root) return;
  root.innerHTML = Object.entries(state.policies).map(([key, value]) => `
    <div class="policy-row">
      <div><strong>${escapeHtml(pretty(key))}</strong><small>Current value: ${escapeHtml(value)}</small></div>
      <button data-policy-edit="${escapeHtml(key)}">Edit</button>
    </div>
  `).join("");
}

function renderTreasury() {
  const balance = Number(state.treasury || 0);
  const wallet = document.getElementById("treasuryBalance");
  const stat = document.getElementById("statTreasury");
  if (wallet) wallet.textContent = fmt(balance);
  if (stat) stat.textContent = fmt(balance);
}

function renderCatalogList(rootId, kind, emptyText) {
  const root = document.getElementById(rootId);
  if (!root) return;
  const items = state.catalog.filter((item) => item.kind === kind);
  if (items.length === 0) {
    root.className = "empty-state";
    root.textContent = emptyText;
    return;
  }
  root.className = "action-list";
  root.innerHTML = items.map((item) => `
    <div class="panel" style="margin-top:10px">
      <div class="panel-head">
        <div>
          <strong>${escapeHtml(item.name)}</strong>
          <p class="muted">${escapeHtml(JSON.stringify(item.data || {}))}</p>
        </div>
        <span class="badge ${item.enabled ? "gold" : ""}">${item.enabled ? "Active" : "Off"}</span>
      </div>
      <div class="button-row">
        <button type="button" data-catalog-edit="${escapeHtml(item.id)}">Edit</button>
        <button type="button" data-catalog-toggle="${escapeHtml(item.id)}" data-next-enabled="${item.enabled ? "false" : "true"}">
          ${item.enabled ? "Disable" : "Enable"}
        </button>
        <button type="button" data-catalog-remove="${escapeHtml(item.id)}">Remove</button>
      </div>
    </div>
  `).join("");
}

function renderOwnerCatalogs() {
  renderCatalogList("giftCatalogList", "gift", "No gifts added from Owner Panel yet.");
  renderCatalogList("entryCatalogList", "entry", "No entry effects added yet.");
  renderCatalogList("frameCatalogList", "frame", "No frames added yet.");
  renderCatalogList("bannerCatalogList", "banner", "No banners added yet.");
}

function field(name, label, type = "text", placeholder = "", required = true) {
  if (type === "select") return "";
  return `<label><span>${label}</span><input name="${name}" type="${type}" placeholder="${placeholder}" ${required ? "required" : ""}></label>`;
}

function selectField(name, label, options) {
  return `<label><span>${label}</span><select name="${name}">${options.map(o => `<option value="${o[0]}">${o[1]}</option>`).join("")}</select></label>`;
}

function checkboxField(name, label, checked = false) {
  return `<label class="checkbox-field"><input name="${name}" type="checkbox" value="true" ${checked ? "checked" : ""}><span>${label}</span></label>`;
}

function openStaffCredentials(panelId, currentEmail) {
  pendingAction = "staff-credentials";
  dialogTitle.textContent = "Change Staff Gmail / Password";
  dialogHelp.textContent = "Change the staff login email, reset the password, or both. Leave the new password blank to keep the current password.";
  dialogFields.innerHTML =
    `<input type="hidden" name="panel_id" value="${escapeHtml(panelId)}">` +
    field("staff_email", "Staff login Gmail / Email", "email", "", true) +
    field("login_password", "New password (optional)", "password", "Minimum 10 characters", false) +
    field("confirm_password", "Confirm new password", "password", "Enter new password again", false);

  const emailInput = dialogFields.querySelector('[name="staff_email"]');
  if (emailInput) emailInput.value = currentEmail || "";
  dialog.showModal();
}

function staffPanelFields() {
  return field("name", "Panel name", "text", "Support Panel") +
    field("assigned_user_id", "Assign to user ID (optional)", "text", "10000001", false) +
    field("staff_email", "Staff login Gmail / Email", "email", "staff@example.com") +
    field("login_password", "Login password", "password", "Minimum 10 characters") +
    field("confirm_password", "Confirm password", "password", "Enter password again") +
    '<div class="dialog-section-title">Panel permissions — choose exact functions</div>' +
    staffPermissionGroups.map(group => `
      <details class="dialog-permission-group" open>
        <summary>
          <strong>${group.label}</strong>
          <label class="dialog-group-toggle" onclick="event.stopPropagation()">
            <input type="checkbox" data-dialog-permission-group data-group="${group.key}">
            <span>Select all</span>
          </label>
        </summary>
        <div class="dialog-permission-items">
          ${group.items.map(([key, label]) =>
            checkboxField("permission_" + key, label, false)
          ).join("")}
        </div>
      </details>
    `).join("");
}

function openAction(action, preset = {}) {
  pendingAction = action;
  dialogFields.innerHTML = "";
  dialogTitle.textContent = "Owner Action";
  dialogHelp.textContent = "This action is sent to the protected Tinni Owner backend and is audit logged.";

  const maps = {
    "treasury-add": ["Add Coins to Owner Treasury", field("amount","Coin amount","number","100000000")],
    "treasury-send": ["Send Owner Treasury Coins",
      field("user_id","Receiver user ID","text","10000001") +
      field("amount","Coin amount","number","2000000") +
      selectField("wallet_type","Receiver wallet",[["normal","Normal User Wallet"],["coin_seller","Coin Seller Wallet"],["merchant","Merchant Wallet"]])
    ],
    "wallet-security-unfreeze": ["Owner Security Unfreeze",
      field("user_id","User ID","text","10000001") +
      selectField("wallet_type","Wallet",[["normal","Normal User Wallet"],["coin_seller","Coin Seller Wallet"],["merchant","Merchant Wallet"]])
    ],
    "user-search": ["Search User", field("user_id","Current or old user ID","text","10000001")],
    "user-ban": ["ID Ban / Unban", field("user_id","User ID") + selectField("status","Action",[["ban","Ban"],["unban","Unban"]]) + field("reason","Reason")],
    "device-ban": ["Device Ban / Unban", field("user_id","User ID") + selectField("status","Action",[["ban","Ban device"],["unban","Unban device"]])],
    "user-invisible": ["Invisible ID", field("user_id","User ID") + selectField("status","Status",[["on","Invisible ON"],["off","Invisible OFF"]])],
    "locked-bypass": ["Locked-room Bypass", field("user_id","User ID") + selectField("status","Status",[["on","Allow bypass"],["off","Remove bypass"]])],
    "id-change": ["Change Public ID", field("user_id","Current user ID") + field("new_id","New public ID — Name ID assignment is Owner Master only")],
    "unique-id-new": ["Add Unique ID", field("public_id","Unique ID: 4-8 digits; Name ID (3-20 letters/numbers/_) is Owner Master only") + field("price_coins","Coin price (0 = free)","number","0") + field("duration_days","Ownership days (0 = permanent)","number","0")],
    "unique-id-price": ["Change Unique ID Price / Duration", field("public_id","Unique ID: 4-8 digits; Name ID is Owner Master only") + field("price_coins","New coin price (0 = free)","number","0") + field("duration_days","Ownership days (0 = permanent)","number","0")],
    "room-ban": ["Room Ban / Unban", field("room_id","Room ID") + selectField("status","Action",[["ban","Ban"],["unban","Unban"]])],
    "room-name": ["Change Room Name", field("room_id","Room ID") + field("room_name","New room name")],
    "room-dp": ["Change Room DP", field("room_id","Room ID") + field("asset_url","DP asset URL")],
    "room-bg": ["Room Background", field("room_id","Room ID") + field("asset_url","Background asset URL")],
    "room-theme-new": ["Add Room Theme",
      field("name","Theme name") +
      field("asset","Theme image HTTPS URL") +
      field("price_coins","Coin price (0 = free)","number","0") +
      selectField("duration_mode","Duration",[["scheduled","Set Date & Time"],["permanent","Permanent"]]) +
      field("starts_at","Start date/time (blank = now)","datetime-local") +
      field("ends_at","End date/time","datetime-local")
    ],
    "wallet-normal": ["Manage Normal Wallet", field("user_id","User ID") + selectField("asset","Balance",[["coins","Coins"],["diamonds","Diamonds"]]) + field("amount","Amount","number") + selectField("operation","Operation",[["credit","Add"],["debit","Remove"],["ban","Ban wallet (coins wallet)"],["unban","Unban wallet (coins wallet)"]])],
    "wallet-seller": ["Manage Coin Seller Wallet", field("user_id","User ID") + field("amount","Coin amount","number") + selectField("operation","Operation",[["create","Create/activate"],["credit","Add coins"],["debit","Remove coins"],["ban","Ban"],["unban","Unban"]])],
    "wallet-merchant": ["Manage Merchant Wallet", field("user_id","User ID") + field("amount","Coin amount","number") + selectField("operation","Operation",[["create","Create/activate"],["credit","Add coins"],["debit","Remove coins"],["ban","Ban"],["unban","Unban"]])],
    "bd-activate": ["BD Role", field("user_id","User ID") + selectField("operation","Operation",[["activate","Activate BD"],["remove","Remove BD"]])],
    "bd-target": ["BD Targets / Commission",
      field("target_1_usd","Target 1 USD","number",String(state.policies.bd_target_1_usd || 500)) +
      field("target_1_percent","Target 1 %","number",String(state.policies.bd_target_1_percent || 7)) +
      field("target_2_usd","Target 2 USD","number",String(state.policies.bd_target_2_usd || 1000)) +
      field("target_2_percent","Target 2 %","number",String(state.policies.bd_target_2_percent || 10))
    ],
    "agency-activate": ["Agency Role", field("user_id","User ID") + selectField("operation","Operation",[["activate","Activate Agency"],["remove","Remove Agency"]])],
    "agency-to-bd": ["Add Agency to BD", field("agency_owner_id","Agency owner ID") + field("bd_user_id","BD user ID")],
    "agency-from-bd": ["Remove Agency from BD", field("agency_owner_id","Agency owner ID") + field("bd_user_id","BD user ID")],
    "host-add": ["Add Host to Agency", field("host_user_id","Host user ID") + field("agency_owner_id","Agency owner ID")],
    "host-remove": ["Remove Host from Agency", field("host_user_id","Host user ID") + field("agency_owner_id","Agency owner ID")],
    "vip-grant": ["Grant / Remove VIP", field("user_id","User ID") + field("vip_level","VIP level","number") + selectField("operation","Operation",[["grant","Grant"],["remove","Remove"]])],
    "gift-new": ["Add New Gift",
      field("name","Gift name") +
      field("coin_price","Coin price","number") +
      checkboxField("lucky","Lucky / Rebate gift",false) +
      field("emoji","Lucky gift emoji","text","🎁",false) +
      field("max_multiplier","Maximum Lucky multiplier (max 1000×)","number","1000",false) +
      field("high_win_multiplier","Big-win banner from multiplier","number","200",false) +
      field("host_reward_percent","Lucky Host diamond % of normal gift","number","10",false) +
      field("charm_wealth_percent","Lucky Charm / Wealth % of normal gift","number","10",false) +
      field("prize_pool_percent","Prize pool contribution %","number","2",false) +
      field("duration_days","Validity days (0 = permanent)","number","0") +
      field("asset_url","Animation / asset URL","text","",false) +
      field("order","Display order","number","0") +
      field("countries","Country codes (comma separated, blank = all)","text","",false) +
      field("starts_at","Effective from","datetime-local","",false) +
      field("ends_at","Effective until","datetime-local","",false)
    ],
    "lucky-gift-config": ["Lucky Gift Global Settings",
      checkboxField("enabled","Lucky Gift system enabled", state.luckyGiftConfig.enabled !== false) +
      field("max_multiplier","Maximum multiplier","number",String(state.luckyGiftConfig.max_multiplier || 1000)) +
      field("high_win_multiplier","Rare/high-win effect from multiplier","number",String(state.luckyGiftConfig.high_win_multiplier || 200)) +
      field("banner_multiplier","Special banner from multiplier","number",String(state.luckyGiftConfig.banner_multiplier || 500)) +
      field("ultra_banner_multiplier","Ultra banner from multiplier","number",String(state.luckyGiftConfig.ultra_banner_multiplier || 1000)) +
      field("host_reward_percent","Lucky Host diamond % of normal gift","number",String(state.luckyGiftConfig.host_reward_percent ?? 10)) +
      field("charm_wealth_percent","Lucky Charm / Wealth % of normal gift","number",String(state.luckyGiftConfig.charm_wealth_percent ?? 10)) +
      field("prize_pool_percent","Prize pool contribution %","number",String(state.luckyGiftConfig.prize_pool_percent ?? 2)) +
      field("rank_share_1","Daily rank #1 share %","number",String(state.luckyGiftConfig.rank_shares?.[0] ?? 50)) +
      field("rank_share_2","Daily rank #2 share %","number",String(state.luckyGiftConfig.rank_shares?.[1] ?? 25)) +
      field("rank_share_3","Daily rank #3 share %","number",String(state.luckyGiftConfig.rank_shares?.[2] ?? 15)) +
      field("daily_send_cap","Daily Lucky send cap (0 = unlimited)","number",String(state.luckyGiftConfig.daily_send_cap || 0)) +
      checkboxField("banners_enabled","Country-specific Lucky banners enabled", state.luckyGiftConfig.banners_enabled !== false) +
      checkboxField("testing_mode","Testing mode", state.luckyGiftConfig.testing_mode === true) +
      checkboxField("event_mode","Event mode", state.luckyGiftConfig.event_mode === true) +
      field("multiplier_weights","Multiplier weights JSON","text",
        JSON.stringify(state.luckyGiftConfig.multiplier_weights || {
          "0":900000,"1":45000,"5":25000,"7":12000,"9":7000,"10":5000,"20":2500,"22":1800,
          "30":900,"50":450,"75":320,"100":250,"200":60,"250":20,"500":12,"750":5,"1000":3
        }))
    ],
    "profile-card-new": ["Add Profile Card", field("name","Profile card name") + field("asset_url","Profile card asset URL") + field("price","Coin price","number","0") + field("duration_days","Validity days (0 = permanent)","number","0") + field("order","Display order","number","0") + field("countries","Country codes (comma separated, blank = all)","text","",false) + field("starts_at","Effective from","datetime-local","",false) + field("ends_at","Effective until","datetime-local","",false)],
    "entry-new": ["Add Entry Effect", field("name","Entry name") + field("asset_url","Vehicle/animal/3D asset URL") + field("price","Coin price","number","0") + field("duration_days","Validity days (0 = permanent)","number","0") + field("vip_level","Assign VIP level","number") + field("order","Display order","number","0") + field("countries","Country codes (comma separated, blank = all)","text","",false) + field("starts_at","Effective from","datetime-local","",false) + field("ends_at","Effective until","datetime-local","",false)],
    "frame-new": ["Add Frame", field("name","Frame name") + field("asset_url","Frame asset URL") + field("price","Coin price","number","0") + field("duration_days","Validity days (0 = permanent)","number","0") + field("vip_level","Assign VIP level","number") + field("order","Display order","number","0") + field("countries","Country codes (comma separated, blank = all)","text","",false) + field("starts_at","Effective from","datetime-local","",false) + field("ends_at","Effective until","datetime-local","",false)],
    "banner-new": ["Schedule Banner", field("title","Banner title") + field("asset_url","Banner image URL") + field("order","Display order","number","0") + field("countries","Country codes (comma separated, blank = all)","text","",false) + field("starts_at","Start date/time","datetime-local") + field("ends_at","Auto-remove date/time","datetime-local")],
    "panel-new": ["Create Custom Panel + Staff Login", staffPanelFields()],
    "role-new": ["Create Role / Post", field("name","Name") + selectField("type","Type",[["role","Role"],["post","Post"]])],
    "vip-new": ["Create New VIP",
      field("name","VIP name","text","VIP 12") + field("level","VIP level","number","12") +
      field("order","Display order","number","12") + field("price","Price / requirement","number","0") +
      field("duration_days","Validity days (0 = permanent)","number","0") + field("badge","Badge asset / label","text","") +
      field("profile_frame","Profile frame","text","") + field("seat_frame","Seat frame","text","") +
      field("entry","Vehicle / animal / 3D entry","text","") + field("entry_asset","Entry animation asset","text","") +
      field("entry_audio","Entry audio asset","text","") + field("requirements","Requirements","text","") +
      field("starts_at","Effective from","datetime-local","",false) + field("ends_at","Effective until","datetime-local","",false)
    ],
    "vip-edit": ["Edit VIP",
      field("catalog_id","Catalog ID","hidden","") + field("name","VIP name") +
      field("level","VIP level","number") + field("order","Display order","number") +
      field("price","Price / requirement","number") + field("duration_days","Validity days (0 = permanent)","number") +
      field("badge","Badge asset / label") + field("profile_frame","Profile frame") + field("seat_frame","Seat frame") +
      field("entry","Vehicle / animal / 3D entry") + field("entry_asset","Entry animation asset") +
      field("entry_audio","Entry audio asset") + field("requirements","Requirements") +
      field("privileges","Privileges (comma separated)","text","",false) +
      field("permissions","Permissions / benefits (comma separated)","text","",false) +
      field("special_effects","Special effects (comma separated)","text","",false) +
      field("countries","Country codes (comma separated, blank = all)","text","",false) +
      field("starts_at","Effective from","datetime-local","",false) + field("ends_at","Effective until","datetime-local","",false)
    ],
    "game-switch": ["Game Master Switch",
      selectField("enabled","Status",[["true","Enable games"],["false","Disable games"]])
    ],
    "game-limits": ["Game Bet Limits",
      field("min_bet","Minimum bet","number",String(state.gameConfig.min_bet || 1)) +
      field("max_bet","Maximum bet","number",String(state.gameConfig.max_bet || 1000000))
    ],
    "game-stats": ["User Betting Investigation",
      field("user_id","User ID (blank = all users)","text","",false)
    ],
    "policy-new": ["Create New Setting", field("key","Setting key") + field("value","Value")],
    "user-price-override-set": ["Per-user Price / Free / Validity",
      field("user_id","User ID") +
      field("price_key","Price key (e.g. call:direct, frame:frame-1, vip:vip-1, entry:item-id, vehicle:item-id, profile_card:item-id, or *)") +
      field("price_coins","Custom price coins (0 = free)","number","0") +
      field("duration_days","Custom purchased validity days (blank = item default, 0 = permanent)","number","",false) +
      field("expires_at","Override rule expires at (blank = no expiry)","datetime-local","",false)
    ],
    "user-price-override-remove": ["Remove Per-user Price Override",
      field("user_id","User ID") + field("price_key","Price key")
    ],
    "pricing-set": ["Call / Theme / Frame / VIP Pricing",
      field("direct_call_coins","Direct call coins/min","number","400000") +
      field("random_call_coins","Random call coins/min","number","500000") +
      field("receiver_percent","Verified receiver diamond %","number","80") +
      field("room_theme_coins","Default room theme coins (0 = free)","number","10000000") +
      field("cp_connect_coins","CP connect coins (0 = free)","number","0") +
      field("cp_disconnect_coins","CP disconnect coins (0 = free)","number","0") +
      field("frame_default_coins","Default frame coins (0 = free)","number","0") +
      field("vip_default_coins","Default VIP coins (0 = free)","number","0") +
      field("unique_id_purchase_coins","Unique ID purchase coins (0 = free)","number","0") +
      field("free_user_ids","Free user IDs (comma separated)","text","",false)
    ],
  };

  const item = maps[action] || [pretty(action), field("target_id","Target user / room ID") + field("reason","Reason / details")];
  dialogTitle.textContent = item[0];
  dialogFields.innerHTML = item[1];
  Object.entries(preset).forEach(([k,v]) => {
    const el = dialogFields.querySelector(`[name="${k}"]`);
    if (!el) return;
    if (el.type === "checkbox") el.checked = v === true || String(v) === "true";
    else el.value = v;
  });
  if (action === "lucky-gift-config") {
    const config = state.luckyGiftConfig || {};
    const values = {
      max_multiplier: config.max_multiplier ?? 1000,
      high_win_multiplier: config.high_win_multiplier ?? 200,
      banner_multiplier: config.banner_multiplier ?? 500,
      ultra_banner_multiplier: config.ultra_banner_multiplier ?? 1000,
      host_reward_percent: config.host_reward_percent ?? 10,
      charm_wealth_percent: config.charm_wealth_percent ?? 10,
      prize_pool_percent: config.prize_pool_percent ?? 2,
      rank_share_1: config.rank_shares?.[0] ?? 50,
      rank_share_2: config.rank_shares?.[1] ?? 25,
      rank_share_3: config.rank_shares?.[2] ?? 15,
      daily_send_cap: config.daily_send_cap ?? 0,
      multiplier_weights: JSON.stringify(config.multiplier_weights || {
        "0":900000,"1":45000,"5":25000,"7":12000,"9":7000,"10":5000,"20":2500,"22":1800,
        "30":900,"50":450,"75":320,"100":250,"200":60,"250":20,"500":12,"750":5,"1000":3
      }),
    };
    Object.entries(values).forEach(([key, value]) => {
      const input = dialogFields.querySelector(`[name="${key}"]`);
      if (input) input.value = value;
    });
    for (const key of ["enabled","banners_enabled","testing_mode","event_mode"]) {
      const input = dialogFields.querySelector(`[name="${key}"]`);
      if (!input) continue;
      if (key === "enabled") input.checked = config.enabled !== false;
      if (key === "banners_enabled") input.checked = config.banners_enabled !== false;
      if (key === "testing_mode") input.checked = config.testing_mode === true;
      if (key === "event_mode") input.checked = config.event_mode === true;
    }
  }
  dialog.showModal();
}

async function renderUserInvestigation(users) {
  const root = document.getElementById("userDetails");
  if (!root) return;
  const items = Array.isArray(users) ? users : [];
  if (items.length === 0) {
    root.className = "empty-state";
    root.textContent = "No matching user found.";
    return;
  }
  root.className = "action-list";
  root.innerHTML = items.map((user) => `
    <div class="panel" style="margin-bottom:10px">
      <div class="panel-head">
        <div>
          <strong>${escapeHtml(user.display_name || user.user_id)}</strong>
          <p>ID ${escapeHtml(user.user_id)} • ${escapeHtml(user.gender || "")} • ${escapeHtml(user.country_name || "")}</p>
          ${user.previous_user_id ? `<small>Found through old ID: ${escapeHtml(user.previous_user_id)}</small>` : ""}
        </div>
        <span class="badge ${user.call_verified ? "gold" : ""}">${user.call_verified ? "Verified" : "Unverified"}</span>
      </div>
      <div class="rule-grid">
        <div class="rule"><strong>Coins</strong><span>${fmt(user.wallet?.coins || 0)}</span></div>
        <div class="rule"><strong>Diamonds</strong><span>${fmt(user.wallet?.diamonds || 0)}</span></div>
        <div class="rule"><strong>ID Ban</strong><span>${user.controls?.banned ? "Banned" : "Active"}</span></div>
        <div class="rule"><strong>Device Access</strong><span>${user.controls?.device_banned ? "Blocked" : "Active"}</span></div>
        <div class="rule"><strong>Invisible</strong><span>${user.controls?.invisible ? "ON" : "OFF"}</span></div>
        <div class="rule"><strong>Locked Bypass</strong><span>${user.controls?.locked_bypass ? "ON" : "OFF"}</span></div>
        <div class="rule"><strong>VIP</strong><span>${Number(user.controls?.vip_level || 0) || "None"}</span></div>
        <div class="rule"><strong>Email</strong><span>${escapeHtml(user.email || "—")}</span></div>
      </div>
      <div style="margin-top:8px">${userTagHtml(user.identity_tags || user.tags)}</div>
      <div class="button-row" style="margin-top:10px">
        <button type="button" class="btn primary" data-owner-open-profile="${escapeHtml(user.user_id)}">Open ID / Full Profile</button>
      </div>
    </div>
  `).join("");
}

function renderRoomInvestigation(result) {
  const root = document.getElementById("roomSearchResult");
  if (!root) return;
  const room = result?.room;
  const presence = result?.presence || {};
  const members = Array.isArray(presence.members) ? presence.members : [];
  if (!room) {
    root.className = "empty-state";
    root.textContent = "Room not found.";
    return;
  }
  root.className = "action-list";
  root.innerHTML = `
    <div class="rule-grid">
      <div class="rule"><strong>Room ID</strong><span>${escapeHtml(room.id)}</span></div>
      <div class="rule"><strong>Owner ID</strong><span>${escapeHtml(room.owner_id)}</span></div>
      <div class="rule"><strong>Name</strong><span>${escapeHtml(room.title)}</span></div>
      <div class="rule"><strong>Country</strong><span>${escapeHtml(room.country_name || "")}</span></div>
      <div class="rule"><strong>Seats</strong><span>${fmt(room.seat_count)}</span></div>
      <div class="rule"><strong>Online now</strong><span>${fmt(members.length)}</span></div>
      <div class="rule"><strong>Mic mode</strong><span>${escapeHtml(presence.mic_mode || "—")}</span></div>
      <div class="rule"><strong>Locked</strong><span>${room.locked ? "Yes" : "No"}</span></div>
    </div>
    <h3 style="margin-top:12px">Live Users / Seats</h3>
    ${members.length ? members.map((member) => `
      <div class="policy-row">
        <div>
          <strong>${escapeHtml(member.display_name || member.user_id)}</strong>
          <small>ID ${escapeHtml(member.user_id)} • Seat ${member.seat_index === null || member.seat_index === undefined ? "Audience" : escapeHtml(member.seat_index)}</small>
        </div>
        <span class="badge">${member.seat_index === null || member.seat_index === undefined ? "Audience" : "On seat"}</span>
      </div>
    `).join("") : '<div class="empty-state">No live users in this room right now.</div>'}
  `;
}

async function loadGameStats(userId = "") {
  const root = document.getElementById("gameStatsResult");
  try {
    const data = await api("/api/owner/game-stats?user_id=" + encodeURIComponent(String(userId || "").trim()));
    const totals = data.totals || {};
    const status = state.features.games !== false && state.gameConfig.enabled !== false;
    document.getElementById("gameTotalBets").textContent = fmt(totals.bet_count || 0);
    document.getElementById("gameTotalBetCoins").textContent = fmt(totals.total_bet || 0);
    document.getElementById("gameTotalPayout").textContent = fmt(totals.total_payout || 0);
    document.getElementById("gameStatusValue").textContent = status ? "ON" : "OFF";
    document.getElementById("gameLimitsValue").textContent =
      "Min " + fmt(state.gameConfig.min_bet || 0) + " • Max " + fmt(state.gameConfig.max_bet || 0);

    if (root) {
      const playerJackpot = data.jackpot?.player;
      const playerParty = data.party?.player;
      root.className = "action-list";
      root.innerHTML = `
        <div class="rule-grid">
          <div class="rule"><strong>Jackpot bets</strong><span>${fmt(data.jackpot?.total_bet || 0)}</span></div>
          <div class="rule"><strong>Jackpot payout</strong><span>${fmt(data.jackpot?.total_payout || 0)}</span></div>
          <div class="rule"><strong>Party bets</strong><span>${fmt(data.party?.total_bet || 0)}</span></div>
          <div class="rule"><strong>Party payout</strong><span>${fmt(data.party?.total_payout || 0)}</span></div>
          <div class="rule"><strong>House net</strong><span>${fmt(totals.house_net || 0)}</span></div>
          <div class="rule"><strong>Recorded players</strong><span>${fmt(totals.unique_players || 0)}</span></div>
        </div>
        ${data.user_id ? `
          <h3 style="margin-top:12px">ID ${escapeHtml(data.user_id)}</h3>
          <div class="rule-grid">
            <div class="rule"><strong>Jackpot net</strong><span>${fmt(playerJackpot?.net_profit || 0)}</span></div>
            <div class="rule"><strong>Party net</strong><span>${fmt(playerParty?.net_profit || 0)}</span></div>
            <div class="rule"><strong>Jackpot bet coins</strong><span>${fmt(playerJackpot?.total_bet || 0)}</span></div>
            <div class="rule"><strong>Party bet coins</strong><span>${fmt(playerParty?.total_bet || 0)}</span></div>
          </div>` : ""}
      `;
    }
    return data;
  } catch (error) {
    if (root) {
      root.className = "empty-state";
      root.textContent = error.message || "Unable to load game stats.";
    }
    throw error;
  }
}

async function runOwnerAction(action, data = {}) {
  const response = await api("/api/owner/action", {
    method: "POST",
    body: JSON.stringify({ action, data }),
  });
  await loadOwnerState();
  return response.result;
}

async function handleAction(action, data) {
  if (action === "staff-credentials") {
    const panelId = String(data.panel_id || "");
    const staffEmail = String(data.staff_email || "").trim().toLowerCase();
    const password = String(data.login_password || "");
    const confirmPassword = String(data.confirm_password || "");
    if (!staffEmail || !staffEmail.includes("@")) throw new Error("Enter a valid staff Gmail / Email.");
    if (password || confirmPassword) {
      if (password.length < 10) throw new Error("New password must be at least 10 characters.");
      if (password !== confirmPassword) throw new Error("New password and confirm password do not match.");
    }
    const patch = { staff_email: staffEmail };
    if (password) patch.password = password;
    await updateStaffPanelPower(panelId, patch);
    toast(password ? "Staff Gmail / password updated." : "Staff Gmail updated.");
    await loadStaffPanels();
    return;
  }

  if (action === "panel-new") {
    const password = String(data.login_password || "");
    const confirmPassword = String(data.confirm_password || "");
    if (password.length < 10) throw new Error("Staff password must be at least 10 characters.");
    if (password !== confirmPassword) throw new Error("Password and confirm password do not match.");
    const permissions = Object.entries(data)
      .filter(([key, value]) => key.startsWith("permission_") && value === "true")
      .map(([key]) => key.replace("permission_", ""));
    await api("/api/staff/panels", {
      method: "POST",
      body: JSON.stringify({
        name: String(data.name || "").trim(),
        assigned_user_id: String(data.assigned_user_id || "").trim(),
        staff_email: String(data.staff_email || "").trim().toLowerCase(),
        password,
        permissions,
      }),
    });
    toast("Staff panel created with login credentials.");
    await loadStaffPanels();
    return;
  }

  if (action === "call-verification-refresh") {
    await Promise.all([loadCallVerifications(), loadVerifiedUsers()]);
    toast("Call Verification refreshed.");
    return;
  }

  if (action === "room-theme-new") {
    const name = String(data.name || "").trim();
    const asset = String(data.asset || "").trim();
    const permanent = String(data.duration_mode || "scheduled") === "permanent";
    if (name.length < 2) throw new Error("Enter a theme name.");
    if (!asset.startsWith("https://") && !asset.startsWith("data:image/")) {
      throw new Error("Use an HTTPS image URL or image data URL.");
    }
    let startsAt = Date.now();
    if (data.starts_at) {
      const startDate = new Date(String(data.starts_at));
      if (Number.isNaN(startDate.getTime())) throw new Error("Select a valid start date/time.");
      startsAt = startDate.getTime();
    }
    let endsAt = null;
    if (!permanent) {
      if (!data.ends_at) throw new Error("Select an end date/time or choose Permanent.");
      const endDate = new Date(String(data.ends_at));
      if (Number.isNaN(endDate.getTime())) throw new Error("Select a valid end date/time.");
      endsAt = endDate.getTime();
      if (endsAt <= startsAt) throw new Error("End date/time must be after start date/time.");
    }
    await api("/api/room-themes", {
      method: "POST",
      body: JSON.stringify({ name, asset, permanent, starts_at: startsAt, ends_at: endsAt }),
    });
    toast(permanent ? "Permanent room theme added." : "Scheduled room theme added.");
    await loadRoomThemes();
    return;
  }

  if (action === "vip-edit") {
    const id = String(data.catalog_id || "").trim();
    if (!id) throw new Error("VIP catalog ID is missing");
    await api("/api/owner/catalog/" + encodeURIComponent(id), {
      method: "PATCH",
      body: JSON.stringify({
        name: String(data.name || "").trim(),
        data: {
          level: Number(data.level || 0), order: Number(data.order || data.level || 0),
          price: Number(data.price || 0), duration_days: Number(data.duration_days || 0),
          badge: String(data.badge || "").trim(), profile_frame: String(data.profile_frame || "").trim(),
          seat_frame: String(data.seat_frame || "").trim(), entry: String(data.entry || "").trim(),
          entry_asset: String(data.entry_asset || "").trim(), entry_audio: String(data.entry_audio || "").trim(),
          requirements: String(data.requirements || "").trim(),
          privileges: String(data.privileges || "").split(",").map(v => v.trim()).filter(Boolean),
          permissions: String(data.permissions || "").split(",").map(v => v.trim()).filter(Boolean),
          special_effects: String(data.special_effects || "").split(",").map(v => v.trim()).filter(Boolean),
          countries: String(data.countries || "").split(",").map(v => v.trim().toUpperCase()).filter(Boolean),
          starts_at: String(data.starts_at || "").trim() || null, ends_at: String(data.ends_at || "").trim() || null,
        },
      }),
    });
    await loadOwnerState();
    toast("VIP updated.");
    return;
  }

  if (action === "game-stats") {
    await loadGameStats(String(data.user_id || "").trim());
    toast(data.user_id ? "User game stats loaded." : "Game stats loaded.");
    return;
  }

  if (action === "room-live") {
    const roomId = String(data.target_id || data.room_id || "").trim();
    if (!roomId) throw new Error("Room ID is required.");
    const result = await api("/api/owner/room-live?room_id=" + encodeURIComponent(roomId));
    renderRoomInvestigation(result);
    toast("Live room data loaded.");
    return;
  }

  const payload = { ...data };
  if (action === "lucky-gift-config") {
    payload.enabled = String(data.enabled || "") === "true";
    payload.banners_enabled = String(data.banners_enabled || "") === "true";
    payload.testing_mode = String(data.testing_mode || "") === "true";
    payload.event_mode = String(data.event_mode || "") === "true";
    payload.max_multiplier = Math.max(1, Math.min(1000, Number(data.max_multiplier || 1000)));
    payload.high_win_multiplier = Math.max(1, Math.min(1000, Number(data.high_win_multiplier || 200)));
    payload.banner_multiplier = Math.max(1, Math.min(1000, Number(data.banner_multiplier || 500)));
    payload.ultra_banner_multiplier = Math.max(1, Math.min(1000, Number(data.ultra_banner_multiplier || 1000)));
    payload.host_reward_percent = Math.max(0, Math.min(100, Number(data.host_reward_percent || 0)));
    payload.charm_wealth_percent = Math.max(0, Math.min(100, Number(data.charm_wealth_percent || 0)));
    payload.prize_pool_percent = Math.max(0, Math.min(100, Number(data.prize_pool_percent || 0)));
    payload.rank_shares = [
      Math.max(0, Math.min(100, Number(data.rank_share_1 || 0))),
      Math.max(0, Math.min(100, Number(data.rank_share_2 || 0))),
      Math.max(0, Math.min(100, Number(data.rank_share_3 || 0))),
    ];
    if (payload.rank_shares.reduce((sum, value) => sum + value, 0) > 100) {
      throw new Error("Lucky ranking shares cannot total more than 100%.");
    }
    payload.daily_send_cap = Math.max(0, Math.floor(Number(data.daily_send_cap || 0)));
    try {
      const weights = JSON.parse(String(data.multiplier_weights || "{}"));
      if (!weights || typeof weights !== "object" || Array.isArray(weights)) {
        throw new Error("not an object");
      }
      payload.multiplier_weights = weights;
    } catch (_) {
      throw new Error("Multiplier weights must be valid JSON, for example {\"5\":25000,\"200\":60}.");
    }
    delete payload.rank_share_1;
    delete payload.rank_share_2;
    delete payload.rank_share_3;
  }
  if (["gift-new","entry-new","frame-new","banner-new"].includes(action)) {
    payload.order = Number(data.order || 0);
    if (action === "frame-new") payload.price = Math.max(0, Number(data.price || 0));
    if (action === "gift-new") {
      payload.coin_price = Math.max(0, Number(data.coin_price || 0));
      payload.lucky = String(data.lucky || "") === "true";
      payload.max_multiplier = Math.max(1, Math.min(1000, Number(data.max_multiplier || 1000)));
      payload.high_win_multiplier = Math.max(1, Math.min(1000, Number(data.high_win_multiplier || 200)));
      payload.host_reward_percent = Math.max(0, Math.min(100, Number(data.host_reward_percent || 10)));
      payload.charm_wealth_percent = Math.max(0, Math.min(100, Number(data.charm_wealth_percent || 10)));
      payload.prize_pool_percent = Math.max(0, Math.min(100, Number(data.prize_pool_percent || 2)));
      payload.emoji = String(data.emoji || "🎁").trim() || "🎁";
    }
    payload.countries = String(data.countries || "").split(",").map(v => v.trim().toUpperCase()).filter(Boolean);
  }
  if (action === "game-switch") payload.enabled = String(data.enabled) === "true";
  if (action === "game-limits") {
    payload.min_bet = Number(data.min_bet || 0);
    payload.max_bet = Number(data.max_bet || 0);
    if (payload.min_bet < 0 || payload.max_bet <= 0 || payload.max_bet < payload.min_bet) {
      throw new Error("Enter valid minimum and maximum bet limits.");
    }
  }
  if (action === "user-price-override-set") {
    payload.user_id = String(data.user_id || "").trim();
    payload.price_key = String(data.price_key || "").trim().toLowerCase();
    payload.price_coins = Math.max(0, Number(data.price_coins || 0));
    payload.duration_days = String(data.duration_days || "").trim() === "" ? null : Math.max(0, Number(data.duration_days));
    payload.expires_at = String(data.expires_at || "").trim() ? new Date(data.expires_at).getTime() : null;
    if (!payload.user_id || !payload.price_key) throw new Error("User ID and price key are required.");
  }
  if (action === "user-price-override-remove") {
    payload.user_id = String(data.user_id || "").trim();
    payload.price_key = String(data.price_key || "").trim().toLowerCase();
    if (!payload.user_id || !payload.price_key) throw new Error("User ID and price key are required.");
  }
  if (action === "pricing-set") {
    payload.direct_call_coins = Math.max(0, Number(data.direct_call_coins || 0));
    payload.random_call_coins = Math.max(0, Number(data.random_call_coins || 0));
    payload.receiver_percent = Math.max(0, Math.min(100, Number(data.receiver_percent || 0)));
    payload.room_theme_coins = Math.max(0, Number(data.room_theme_coins || 0));
  payload.cp_connect_coins = Math.max(0, Number(data.cp_connect_coins || 0));
  payload.cp_disconnect_coins = Math.max(0, Number(data.cp_disconnect_coins || 0));
    payload.frame_default_coins = Math.max(0, Number(data.frame_default_coins || 0));
    payload.vip_default_coins = Math.max(0, Number(data.vip_default_coins || 0));
    payload.unique_id_purchase_coins = Math.max(0, Number(data.unique_id_purchase_coins || 0));
    payload.free_user_ids = String(data.free_user_ids || "").split(",").map(v => v.trim()).filter(Boolean);
  }
  if (action === "room-theme-new") payload.price_coins = Math.max(0, Number(data.price_coins || 0));
  if (action === "policy-new" && !String(data.key || "").trim()) {
    throw new Error("Setting key is required.");
  }

  const result = await runOwnerAction(action, payload);
  if (action === "lucky-gift-config") {
    await loadOwnerState();
    toast("Lucky Gift settings updated.");
    return;
  }

  if (action === "user-search") {
    await renderUserInvestigation(result?.users || []);
  } else if (action === "room-live") {
    renderRoomInvestigation(result);
  } else if (action === "complaints") {
    setView("notifications");
    await loadOwnerNotifications();
  }

  toast(pretty(action) + " completed.");
}

document.getElementById("nav").addEventListener("click", e => {
  const btn = e.target.closest("[data-view]");
  if (btn) setView(btn.dataset.view);
});

document.getElementById("menuBtn").addEventListener("click", () => {
  document.getElementById("sidebar").classList.toggle("open");
});

document.getElementById("refreshBtn").addEventListener("click", async () => {
  await checkHealth();
  if (currentSession?.role === "owner") {
    await Promise.all([
      loadOwnerState(),
      loadOwnerNotifications(),
      loadCallVerifications(),
      loadVerifiedUsers(),
      loadStaffPanels(),
      loadRoomThemes(),
      loadAuditLog(),
    ]);
    toast("Owner Panel refreshed.");
    return;
  }
  if (hasPermission(new Set(currentSession?.permissions || []), "rooms.theme_view")) {
    await loadRoomThemes();
  }
  if (hasPermission(new Set(currentSession?.permissions || []), "audit.view")) {
    await loadAuditLog();
  }
  toast("Panel refreshed.");
});

document.getElementById("logoutBtn")?.addEventListener("click", async () => {
  await fetch("/auth/logout", { method: "POST" }).catch(() => null);
  window.location.replace("/login");
});

document.getElementById("quickActionBtn").addEventListener("click", () => {
  setView("users");
  document.getElementById("userSearchId")?.focus();
});

document.getElementById("globalSearch").addEventListener("keydown", async e => {
  if (e.key === "Enter" && e.target.value.trim()) {
    const value = e.target.value.trim();
    setView("users");
    document.getElementById("userSearchId").value = value;
    try {
      const result = await runOwnerAction("user-search", { user_id: value });
      await renderUserInvestigation(result?.users || []);
    } catch (error) {
      toast(error.message);
    }
  }
});

document.body.addEventListener("change", (event) => {
  const groupInput = event.target.closest("[data-dialog-permission-group]");
  if (!groupInput) return;
  const group = groupInput.dataset.group;
  const container = groupInput.closest(".dialog-permission-group");
  container?.querySelectorAll(`input[name^="permission_${group}."]`)
    .forEach((input) => { input.checked = groupInput.checked; });
});

document.body.addEventListener("change", async e => {
  const input = e.target.closest("[data-feature]");
  if (!input) return;
  input.disabled = true;
  try {
    await runOwnerAction("feature-set", {
      key: input.dataset.feature,
      enabled: input.checked,
    });
    toast(pretty(input.dataset.feature) + (input.checked ? " enabled." : " disabled."));
  } catch (error) {
    input.checked = !input.checked;
    toast(error.message);
  } finally {
    input.disabled = false;
  }
});

document.body.addEventListener("change", async (event) => {
  const ownerUserSelect = event.target.closest("[data-owner-user-select]");
  if (ownerUserSelect) {
    const userId = String(ownerUserSelect.dataset.ownerUserSelect || "");
    if (ownerUserSelect.checked) {
      ownerSelectedUsers.set(userId, true);
    } else {
      ownerSelectedUsers.delete(userId);
    }
    renderOwnerSelectedCount();
    return;
  }

  const enabledInput = event.target.closest("[data-staff-enabled]");
  if (enabledInput) {
    enabledInput.disabled = true;
    try {
      await updateStaffPanelPower(enabledInput.dataset.panelId, {
        enabled: enabledInput.checked,
      });
      toast(enabledInput.checked ? "Staff login enabled." : "Staff login disabled immediately.");
    } catch (error) {
      toast(error.message);
    } finally {
      await loadStaffPanels();
    }
    return;
  }

  const groupInput = event.target.closest("[data-staff-group]");
  if (groupInput) {
    const card = groupInput.closest("[data-staff-panel]");
    const group = groupInput.dataset.group;
    card.querySelectorAll(`[data-staff-permission][data-permission^="${group}."]`)
      .forEach((input) => { input.checked = groupInput.checked; });
    const permissions = [...card.querySelectorAll("[data-staff-permission]:checked")]
      .map((input) => input.dataset.permission);

    groupInput.disabled = true;
    try {
      await updateStaffPanelPower(groupInput.dataset.panelId, { permissions });
      toast(groupInput.checked ? pretty(group) + " — all functions enabled." : pretty(group) + " — all functions disabled.");
    } catch (error) {
      toast(error.message);
    } finally {
      await loadStaffPanels();
    }
    return;
  }

  const permissionInput = event.target.closest("[data-staff-permission]");
  if (permissionInput) {
    const card = permissionInput.closest("[data-staff-panel]");
    const permissions = [...card.querySelectorAll("[data-staff-permission]:checked")]
      .map((input) => input.dataset.permission);

    permissionInput.disabled = true;
    try {
      await updateStaffPanelPower(permissionInput.dataset.panelId, {
        permissions,
      });
      toast(
        permissionInput.checked
          ? pretty(permissionInput.dataset.permission) + " enabled."
          : pretty(permissionInput.dataset.permission) + " disabled."
      );
    } catch (error) {
      toast(error.message);
    } finally {
      await loadStaffPanels();
    }
  }
});

document.body.addEventListener("click", async e => {
  const profileClose = e.target.closest("[data-owner-profile-close]");
  if (profileClose) {
    const profileDialog = document.getElementById("ownerProfileDialog");
    profileDialog?.classList.remove("full-view");
    profileDialog?.close();
    return;
  }

  const fullViewButton = e.target.closest("[data-owner-profile-fullview]");
  if (fullViewButton) {
    const profileDialog = document.getElementById("ownerProfileDialog");
    if (!profileDialog) return;
    const enabled = profileDialog.classList.toggle("full-view");
    fullViewButton.textContent = enabled ? "Compact View" : "Full View";
    return;
  }

  const walletButton = e.target.closest("[data-owner-wallet-change]");
  if (walletButton) {
    const userId = String(walletButton.dataset.userId || "");
    const asset = String(walletButton.dataset.asset || "coins");
    const operation = String(walletButton.dataset.operation || "");
    const amountInput = document.querySelector(`[data-owner-wallet-amount="${asset}"]`);
    const amount = Math.floor(Number(amountInput?.value || 0));
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      toast("Enter a valid " + asset + " amount.");
      amountInput?.focus();
      return;
    }
    if (operation === "debit" && !confirm("Remove " + fmt(amount) + " " + asset + " from ID " + userId + "?")) {
      return;
    }
    walletButton.disabled = true;
    try {
      await runOwnerAction("wallet-normal", { user_id: userId, asset, operation, amount });
      toast((operation === "credit" ? "Added " : "Removed ") + fmt(amount) + " " + asset + ".");
      await openOwnerUserProfile(userId);
    } catch (error) {
      toast(error.message);
    } finally {
      walletButton.disabled = false;
    }
    return;
  }

  const vipButton = e.target.closest("[data-owner-vip-change]");
  if (vipButton) {
    const userId = String(vipButton.dataset.userId || "");
    const operation = String(vipButton.dataset.operation || "");
    const vipInput = document.querySelector("[data-owner-vip-level]");
    const vipLevel = Math.max(1, Math.floor(Number(vipInput?.value || 1)));
    if (operation === "remove" && !confirm("Remove VIP from ID " + userId + "?")) return;
    vipButton.disabled = true;
    try {
      await runOwnerAction("vip-grant", {
        user_id: userId,
        operation,
        vip_level: operation === "remove" ? 0 : vipLevel,
      });
      toast(operation === "remove" ? "VIP removed." : "VIP " + vipLevel + " added.");
      await openOwnerUserProfile(userId);
    } catch (error) {
      toast(error.message);
    } finally {
      vipButton.disabled = false;
    }
    return;
  }

  const openInboxButton = e.target.closest("[data-owner-open-inbox]");
  if (openInboxButton) {
    await loadOwnerInbox(openInboxButton.dataset.ownerOpenInbox);
    return;
  }

  const closeInboxButton = e.target.closest("[data-owner-close-inbox]");
  if (closeInboxButton) {
    const browser = document.getElementById("ownerInboxBrowser");
    if (browser) {
      browser.hidden = true;
      browser.innerHTML = "";
    }
    return;
  }

  const backInboxButton = e.target.closest("[data-owner-back-inbox]");
  if (backInboxButton) {
    await loadOwnerInbox(backInboxButton.dataset.ownerBackInbox);
    return;
  }

  const threadButton = e.target.closest("[data-owner-open-thread]");
  if (threadButton) {
    await loadOwnerConversation(
      threadButton.dataset.ownerUserId,
      threadButton.dataset.peerUserId,
      threadButton.dataset.peerName || "",
    );
    return;
  }

  const officialRefresh = e.target.closest("[data-owner-official-refresh]");
  if (officialRefresh) {
    await loadOfficials(ownerOfficialPosition);
    return;
  }

  const officialPositionButton = e.target.closest("[data-official-position]");
  if (officialPositionButton) {
    ownerOfficialPosition = String(officialPositionButton.dataset.officialPosition || "");
    renderOfficials();
    return;
  }

  const openProfileButton = e.target.closest("[data-owner-open-profile]");
  if (openProfileButton) {
    await openOwnerUserProfile(openProfileButton.dataset.ownerOpenProfile);
    return;
  }

  const editOfficialButton = e.target.closest("[data-owner-official-edit]");
  if (editOfficialButton) {
    const userId = String(editOfficialButton.dataset.ownerOfficialEdit || "");
    const current = String(editOfficialButton.dataset.designation || "");
    const designation = prompt("Edit Position / Designation", current);
    if (designation === null) return;
    if (!designation.trim()) { toast("Position cannot be empty."); return; }
    const background = String(editOfficialButton.dataset.background || "#69C9FF");
    try {
      await api("/api/owner/tags", {
        method: "POST",
        body: JSON.stringify({
          user_ids: [userId],
          name: "V Official",
          color: background,
          kind: "v_official",
          designation: designation.trim(),
          background_color: background,
        }),
      });
      toast("Official position updated.");
      await loadOfficials(designation.trim());
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const removeOfficialButton = e.target.closest("[data-owner-official-remove]");
  if (removeOfficialButton) {
    const userId = String(removeOfficialButton.dataset.ownerOfficialRemove || "");
    const tagId = String(removeOfficialButton.dataset.tagId || "");
    if (!confirm("Remove V Official from ID " + userId + "?")) return;
    try {
      await api("/api/owner/tags/" + encodeURIComponent(userId) + "/" + encodeURIComponent(tagId), {
        method: "DELETE",
      });
      toast("V Official removed.");
      await loadOfficials(ownerOfficialPosition);
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const verificationPageButton = e.target.closest("[data-verification-page]");
  if (verificationPageButton) {
    const page = verificationPageButton.dataset.verificationPage;
    document.querySelectorAll(".verification-page").forEach((item) => {
      item.hidden = item.id !== "verification-page-" + page;
    });
    document.querySelectorAll(".verification-tab").forEach((button) => {
      const active = button.dataset.verificationPage === page;
      button.classList.toggle("active", active);
      button.classList.toggle("primary", active);
      button.classList.toggle("secondary", !active);
    });
    if (page === "verified") await loadVerifiedUsers(document.getElementById("verifiedSearchInput")?.value || "");
    if (page === "requests") await loadCallVerifications();
    return;
  }

  const directSearchButton = e.target.closest("[data-call-verify-search]");
  if (directSearchButton) {
    await searchDirectVerifyUsers(document.getElementById("manualCallVerifySearch")?.value || "");
    return;
  }

  const directVerifyUser = e.target.closest("[data-direct-verify-user]")?.dataset.directVerifyUser;
  if (directVerifyUser) {
    const note = String(document.getElementById("manualCallVerifyNote")?.value || "").trim();
    if (!confirm("Verify ID " + directVerifyUser + " directly without camera verification?")) return;
    try {
      await api("/api/call-verifications/user/" + encodeURIComponent(directVerifyUser) + "/verify", {
        method: "POST",
        body: JSON.stringify({ note }),
      });
      toast("ID " + directVerifyUser + " verified by Owner.");
      await Promise.all([
        loadVerifiedUsers(),
        loadCallVerifications(),
        searchDirectVerifyUsers(document.getElementById("manualCallVerifySearch")?.value || directVerifyUser),
      ]);
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const ownerUserSearchButton = e.target.closest("[data-owner-user-search]");
  if (ownerUserSearchButton) {
    await searchOwnerMessagingUsers(document.getElementById("ownerUserSearchInput")?.value || "");
    return;
  }

  if (e.target.closest("[data-owner-user-clear]")) {
    ownerSelectedUsers.clear();
    renderOwnerSelectedCount();
    document.querySelectorAll("[data-owner-user-select]").forEach((input) => { input.checked = false; });
    toast("Selected IDs cleared.");
    return;
  }

  if (e.target.closest("[data-owner-message-selected]")) {
    const textValue = String(document.getElementById("ownerBulkMessage")?.value || "").trim();
    const ids = [...ownerSelectedUsers.keys()];
    if (!textValue) { toast("Write a message first."); return; }
    if (ids.length === 0) { toast("Select at least one ID."); return; }
    try {
      const result = await api("/api/owner/messages", {
        method: "POST",
        body: JSON.stringify({ text: textValue, user_ids: ids, all_users: false }),
      });
      toast("Official message sent to " + result.sent + " selected IDs.");
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  if (e.target.closest("[data-owner-message-all]")) {
    const textValue = String(document.getElementById("ownerBulkMessage")?.value || "").trim();
    if (!textValue) { toast("Write a message first."); return; }
    if (!confirm("Send this Tinni Official message to ALL app users?")) return;
    try {
      const result = await api("/api/owner/messages", {
        method: "POST",
        body: JSON.stringify({ text: textValue, all_users: true }),
      });
      toast("Official message sent to " + result.sent + " users.");
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  if (e.target.closest("[data-owner-tag-selected]")) {
    const name = String(document.getElementById("ownerTagName")?.value || "").trim();
    const color = String(document.getElementById("ownerTagColor")?.value || "#FFD54F");
    const ids = [...ownerSelectedUsers.keys()];
    if (!name) { toast("Write a tag name."); return; }
    if (ids.length === 0) { toast("Select at least one ID."); return; }
    try {
      const result = await api("/api/owner/tags", {
        method: "POST",
        body: JSON.stringify({ user_ids: ids, name, color }),
      });
      toast(result.name + " tag applied to " + result.tagged + " IDs.");
      await searchOwnerMessagingUsers(document.getElementById("ownerUserSearchInput")?.value || "");
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const vColorButton = e.target.closest("[data-v-color]");
  if (vColorButton) {
    const value = String(vColorButton.dataset.vColor || "#69C9FF");
    const select = document.getElementById("ownerVBackground");
    if (select) select.value = value;
    document.querySelectorAll("[data-v-color]").forEach((button) => {
      button.classList.toggle("active", button === vColorButton);
    });
    const preview = document.querySelector(".v-official-preview");
    if (preview) preview.style.setProperty("--v-bg", value);
    return;
  }

  if (e.target.closest("[data-owner-v-official-selected]")) {
    const designation = String(
      document.getElementById("ownerVDesignation")?.value || ""
    ).trim();
    const background = String(
      document.getElementById("ownerVBackground")?.value || "#69C9FF"
    );
    const ids = [...ownerSelectedUsers.keys()];
    if (!designation) { toast("Write or select a Position / Designation."); return; }
    if (ids.length === 0) { toast("Select at least one ID."); return; }
    try {
      const result = await api("/api/owner/tags", {
        method: "POST",
        body: JSON.stringify({
          user_ids: ids,
          name: "V Official",
          color: background,
          kind: "v_official",
          designation,
          background_color: background,
        }),
      });
      toast("V Official · " + designation + " applied to " + result.tagged + " IDs.");
      await loadOfficials(designation);
      await searchOwnerMessagingUsers(
        document.getElementById("ownerUserSearchInput")?.value || ""
      );
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const approveCallVerification = e.target.closest("[data-call-verify-approve]")?.dataset.callVerifyApprove;
  if (approveCallVerification) {
    try {
      await api(
        "/api/call-verifications/" + encodeURIComponent(approveCallVerification) + "/review",
        {
          method: "POST",
          body: JSON.stringify({ approve: true }),
        }
      );
      toast("Call ID verified. It stays verified until Owner removes Verified status.");
      await Promise.all([loadCallVerifications(), loadVerifiedUsers()]);
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const rejectCallVerification = e.target.closest("[data-call-verify-reject]")?.dataset.callVerifyReject;
  if (rejectCallVerification) {
    const note = prompt("Reject reason / note (optional)", "") || "";
    try {
      await api(
        "/api/call-verifications/" + encodeURIComponent(rejectCallVerification) + "/review",
        {
          method: "POST",
          body: JSON.stringify({ approve: false, note }),
        }
      );
      toast("Verification rejected. User should contact the Official Manager.");
      await loadCallVerifications();
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const revokeCallVerification = e.target.closest("[data-call-verify-revoke]")?.dataset.callVerifyRevoke;
  if (revokeCallVerification) {
    if (!confirm("Remove Verified status from this ID?")) return;
    const note = prompt("Reason (optional)", "") || "";
    try {
      await api(
        "/api/call-verifications/user/" + encodeURIComponent(revokeCallVerification) + "/revoke",
        {
          method: "POST",
          body: JSON.stringify({ note }),
        }
      );
      toast("Verified status removed. Verification will be required again.");
      await Promise.all([loadCallVerifications(), loadVerifiedUsers()]);
      const directQuery = document.getElementById("manualCallVerifySearch")?.value || "";
      if (directQuery) await searchDirectVerifyUsers(directQuery);
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const roomThemeRemove = e.target.closest('[data-room-theme-remove]')?.dataset.roomThemeRemove;
  if (roomThemeRemove) {
    if (!confirm('Remove this global room theme?')) return;
    try {
      await api('/api/room-themes/' + encodeURIComponent(roomThemeRemove), { method: 'DELETE' });
      toast('Room theme removed.');
      await loadRoomThemes();
    } catch (error) {
      toast(error.message);
    }
    return;
  }
  const credentialsButton = e.target.closest("[data-staff-credentials]");
  if (credentialsButton) {
    return openStaffCredentials(
      credentialsButton.dataset.panelId,
      credentialsButton.dataset.staffEmail
    );
  }

  const officialMessageButton = e.target.closest("[data-official-message-user]");
  if (officialMessageButton) {
    if (currentSession?.role !== "owner") {
      toast("Only the Owner can send Tinni Official messages.");
      return;
    }

    const targetUserId = officialMessageButton.dataset.officialMessageUser;
    const targetName = officialMessageButton.dataset.officialMessageName || "User";
    const recipientKind = officialMessageButton.dataset.officialMessageKind || "";
    const reportId = officialMessageButton.dataset.officialMessageReport || "";
    const message = prompt(
      "Send as Tinni Official to " + targetName + " (ID " + targetUserId + ")",
      ""
    );
    if (message === null) return;
    if (!message.trim()) {
      toast("Message cannot be empty.");
      return;
    }

    officialMessageButton.disabled = true;
    try {
      await api("/api/owner/official-message", {
        method: "POST",
        body: JSON.stringify({
          target_user_id: targetUserId,
          message: message.trim(),
          recipient_kind: recipientKind,
          report_id: reportId,
        }),
      });
      toast("Tinni Official message sent to ID " + targetUserId + ".");
    } catch (error) {
      toast(error.message);
    } finally {
      officialMessageButton.disabled = false;
    }
    return;
  }

  const notificationRead = e.target.closest("[data-notification-read]")?.dataset.notificationRead;
  if (notificationRead) {
    try {
      await api("/api/owner/notifications/" + encodeURIComponent(notificationRead), {
        method: "PATCH",
        body: JSON.stringify({ is_read: true }),
      });
      await loadOwnerNotifications();
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const notificationDelete = e.target.closest("[data-notification-delete]")?.dataset.notificationDelete;
  if (notificationDelete) {
    if (!confirm("Delete this notification?")) return;
    try {
      await api("/api/owner/notifications/" + encodeURIComponent(notificationDelete), {
        method: "DELETE",
      });
      await loadOwnerNotifications();
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const auditDelete = e.target.closest("[data-audit-delete]")?.dataset.auditDelete;
  if (auditDelete) {
    if (!confirm("Delete this audit record? Only the Owner can do this.")) return;
    try {
      await api("/api/audit/" + encodeURIComponent(auditDelete), { method: "DELETE" });
      await loadAuditLog();
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const catalogToggle = e.target.closest("[data-catalog-toggle]");
  if (catalogToggle) {
    const id = String(catalogToggle.dataset.catalogToggle || "");
    const enabled = String(catalogToggle.dataset.nextEnabled) === "true";
    try {
      await api("/api/owner/catalog/" + encodeURIComponent(id), {
        method: "PATCH",
        body: JSON.stringify({ enabled }),
      });
      await loadOwnerState();
      toast(enabled ? "Item enabled." : "Item disabled.");
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const catalogRemove = e.target.closest("[data-catalog-remove]")?.dataset.catalogRemove;
  if (catalogRemove) {
    const item = state.catalog.find((entry) => entry.id === catalogRemove);
    if (!item) { toast("Catalog item not found."); return; }
    if (currentSession?.role !== "owner" && !hasPermission(new Set(currentSession?.permissions || []), catalogPermission(item, "remove"))) { toast("Assigned permission required."); return; }
    if (!confirm("Permanently remove " + item.name + "?")) return;
    try {
      await runOwnerAction("catalog-remove", { id: catalogRemove });
      toast(item.name + " removed.");
    } catch (error) { toast(error.message); }
    return;
  }

  const catalogEdit = e.target.closest("[data-catalog-edit]")?.dataset.catalogEdit;
  if (catalogEdit) {
    const item = state.catalog.find((entry) => entry.id === catalogEdit);
    if (!item) { toast("Catalog item not found."); return; }
    if (currentSession?.role !== "owner" && !hasPermission(new Set(currentSession?.permissions || []), catalogPermission(item, "edit"))) { toast("Assigned permission required."); return; }
    const name = prompt("Name", item.name);
    if (name === null || !name.trim()) return;
    const data = { ...(item.data || {}) };

    if (item.kind === "role" || item.kind === "post") {
      // Name plus enable/disable/remove is the complete configurable surface for roles/posts today.
    } else if (item.kind === "gift") {
      const price = prompt("Coin price", String(data.coin_price || 0));
      if (price === null) return;
      const asset = prompt("Animation / asset URL", String(data.asset_url || ""));
      if (asset === null) return;
      data.coin_price = Math.max(0, Number(price || 0));
      data.asset_url = asset.trim();

      const lucky = confirm(
        "Enable Lucky / Rebate behavior for this gift?\n\nOK = Lucky gift\nCancel = Normal gift"
      );
      data.lucky = lucky;
      data.rebate = lucky;
      data.category = lucky ? "Lucky" : (data.category === "Lucky" ? "" : data.category || "");
      data.effect_kind = lucky ? "lucky" : (data.effect_kind === "lucky" ? "" : data.effect_kind || "");

      if (lucky) {
        const emoji = prompt("Lucky gift emoji", String(data.emoji || "🎁"));
        if (emoji === null) return;
        const maxMultiplier = prompt("Maximum multiplier (1–1000)", String(data.max_multiplier || 1000));
        if (maxMultiplier === null) return;
        const highWin = prompt("Big-win banner starts at multiplier", String(data.high_win_multiplier || 200));
        if (highWin === null) return;
        const hostPercent = prompt("Host reward % of normal gift", String(data.host_reward_percent ?? 10));
        if (hostPercent === null) return;
        const charmPercent = prompt("Charm / Wealth % of normal gift", String(data.charm_wealth_percent ?? 10));
        if (charmPercent === null) return;
        const poolPercent = prompt("Prize pool contribution %", String(data.prize_pool_percent ?? 2));
        if (poolPercent === null) return;
        data.emoji = emoji.trim() || "🎁";
        data.max_multiplier = Math.max(1, Math.min(1000, Number(maxMultiplier || 1000)));
        data.high_win_multiplier = Math.max(1, Math.min(1000, Number(highWin || 200)));
        data.host_reward_percent = Math.max(0, Math.min(100, Number(hostPercent || 10)));
        data.charm_wealth_percent = Math.max(0, Math.min(100, Number(charmPercent || 10)));
        data.prize_pool_percent = Math.max(0, Math.min(100, Number(poolPercent || 2)));
      }
    } else if (item.kind === "entry" || item.kind === "frame") {
      const asset = prompt("Asset URL", String(data.asset_url || ""));
      if (asset === null) return;
      const vipLevel = prompt("VIP level", String(data.vip_level || 0));
      if (vipLevel === null) return;
      data.asset_url = asset.trim();
      data.vip_level = Number(vipLevel || 0);
    } else if (item.kind === "banner") {
      const asset = prompt("Banner image URL", String(data.asset_url || ""));
      if (asset === null) return;
      data.asset_url = asset.trim();
    }

    if (["gift","entry","frame","banner"].includes(item.kind)) {
      const order = prompt("Display order", String(data.order || 0)); if (order === null) return;
      const countries = prompt("Country codes, comma separated (blank = all)", Array.isArray(data.countries) ? data.countries.join(", ") : ""); if (countries === null) return;
      const startsAt = prompt("Effective from (ISO/date-time, blank = none)", data.starts_at ? String(data.starts_at) : ""); if (startsAt === null) return;
      const endsAt = prompt("Effective until (ISO/date-time, blank = none)", data.ends_at ? String(data.ends_at) : ""); if (endsAt === null) return;
      data.order = Number(order || 0);
      data.countries = countries.split(",").map(v => v.trim().toUpperCase()).filter(Boolean);
      data.starts_at = startsAt.trim() || null; data.ends_at = endsAt.trim() || null;
    }

    try {
      await api("/api/owner/catalog/" + encodeURIComponent(catalogEdit), {
        method: "PATCH",
        body: JSON.stringify({ name: name.trim(), data }),
      });
      await loadOwnerState();
      toast("Catalog item updated.");
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const action = e.target.closest("[data-action]")?.dataset.action;
  if (action === "user-search") {
    const value = String(document.getElementById("userSearchId")?.value || "").trim();
    if (!value) { toast("Enter a user ID, old ID, name or email."); return; }
    try {
      const result = await runOwnerAction("user-search", { user_id: value });
      await renderUserInvestigation(result?.users || []);
    } catch (error) {
      toast(error.message);
    }
    return;
  }
  if (action === "call-verification-refresh") {
    await Promise.all([loadCallVerifications(), loadVerifiedUsers()]);
    toast("Call Verification refreshed.");
    return;
  }
  if (action === "complaints") {
    setView("notifications");
    await loadOwnerNotifications();
    return;
  }
  if (action === "notifications-refresh") {
    await loadOwnerNotifications();
    return;
  }
  if (action === "audit-refresh") {
    await loadAuditLog();
    return;
  }
  if (action === "audit-clear") {
    if (currentSession?.role !== "owner") {
      toast("Only the Owner can delete audit records.");
      return;
    }
    if (!confirm("Delete ALL audit records? This cannot be undone.")) return;
    try {
      await api("/api/audit", { method: "DELETE" });
      await loadAuditLog();
      toast("Audit records deleted.");
    } catch (error) {
      toast(error.message);
    }
    return;
  }
  if (action === "audit-export") {
    try {
      const data = await api("/api/audit?limit=500");
      const blob = new Blob([JSON.stringify(data.records || [], null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "tinni-panel-audit-" + new Date().toISOString().slice(0, 10) + ".json";
      link.click();
      URL.revokeObjectURL(url);
    } catch (error) {
      toast(error.message);
    }
    return;
  }
  if (action) return openAction(action);

  const moduleName = e.target.closest("[data-module]")?.dataset.module;
  if (moduleName) {
    const match = Object.entries(viewMeta).find(([,meta]) => meta[0] === moduleName);
    if (match) setView(match[0]);
  }

  const vipEdit = e.target.closest("[data-vip-edit]")?.dataset.vipEdit;
  if (vipEdit) {
    const vip = state.vips.find(v => v.id === vipEdit);
    if (!vip) { toast("VIP not found."); return; }
    openAction("vip-edit", {
      catalog_id: vip.id,
      name: vip.name,
      level: vip.level,
      price: vip.price,
      entry: vip.entry,
      frame: vip.frame,
      order: vip.data?.order ?? vip.level,
      duration_days: vip.data?.duration_days ?? 0,
      badge: vip.data?.badge || "", profile_frame: vip.data?.profile_frame || vip.data?.frame || "",
      seat_frame: vip.data?.seat_frame || "", entry_asset: vip.data?.entry_asset || "", entry_audio: vip.data?.entry_audio || "",
      requirements: vip.data?.requirements || "", privileges: (vip.data?.privileges || []).join(", "),
      permissions: (vip.data?.permissions || []).join(", "), special_effects: (vip.data?.special_effects || []).join(", "),
      countries: (vip.data?.countries || []).join(", "), starts_at: vip.data?.starts_at || "", ends_at: vip.data?.ends_at || "",
    });
    return;
  }

  const vipToggle = e.target.closest("[data-vip-toggle]")?.dataset.vipToggle;
  if (vipToggle) {
    const vip = state.vips.find(v => v.id === vipToggle);
    if (!vip) { toast("VIP not found."); return; }
    try {
      await api("/api/owner/catalog/" + encodeURIComponent(vip.id), {
        method: "PATCH",
        body: JSON.stringify({ enabled: !vip.enabled }),
      });
      await loadOwnerState();
      toast(vip.name + (!vip.enabled ? " enabled." : " disabled."));
    } catch (error) {
      toast(error.message);
    }
    return;
  }

  const policyKey = e.target.closest("[data-policy-edit]")?.dataset.policyEdit;
  if (policyKey) {
    const value = prompt("New value for " + pretty(policyKey), state.policies[policyKey]);
    if (value !== null && value !== "") {
      try {
        await runOwnerAction("policy-set", {
          key: policyKey,
          value: Number.isNaN(Number(value)) ? value : Number(value),
        });
        toast(pretty(policyKey) + " updated.");
      } catch (error) {
        toast(error.message);
      }
    }
    return;
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

document.getElementById("userSearchId")?.addEventListener("keydown", async e => {
  if (e.key !== "Enter") return;
  const value = e.target.value.trim();
  if (!value) return;
  try {
    const result = await runOwnerAction("user-search", { user_id: value });
    await renderUserInvestigation(result?.users || []);
  } catch (error) {
    toast(error.message);
  }
});

document.getElementById("verifiedSearchInput")?.addEventListener("keydown", async e => {
  if (e.key === "Enter") await loadVerifiedUsers(e.target.value.trim());
});

document.getElementById("manualCallVerifySearch")?.addEventListener("keydown", async e => {
  if (e.key === "Enter") await searchDirectVerifyUsers(e.target.value.trim());
});

document.getElementById("ownerUserSearchInput")?.addEventListener("keydown", async e => {
  if (e.key === "Enter") await searchOwnerMessagingUsers(e.target.value.trim());
});

renderFeatures();
renderModules();
renderHierarchyRules();
renderRoles();
renderVips();
renderPolicies();
renderTreasury();
checkHealth();
loadSession();
