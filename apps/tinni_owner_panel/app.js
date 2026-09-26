const API_BASE = window.location.origin;

const state = {
  treasury: 0,
  features: {},
  policies: {},
  gameConfig: {},
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
  "entry-new": "assets.entries",
  "frame-new": "assets.frames",
  "banner-new": "banners.create",
  "game-switch": "games.toggle",
  "game-limits": "games.limits",
  "game-stats": "games.investigate",
  "policy-new": "policies.create",
  "audit-export": "audit.export",
};

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
  const panel = document.getElementById("callVerificationPanel");
  if (!root || !panel) return;
  if (currentSession?.role !== "owner") {
    panel.hidden = true;
    return;
  }
  panel.hidden = false;

  try {
    const data = await api("/api/call-verifications");
    const items = Array.isArray(data.submissions) ? data.submissions : [];
    if (items.length === 0) {
      root.className = "empty-state";
      root.textContent = "No call verification submissions yet.";
      return;
    }

    root.className = "action-list";
    root.innerHTML = items.map((item) => {
      const photos = Array.isArray(item.photos) ? item.photos.slice(0, 3) : [];
      const verified = item.call_verified === true;
      const pending = item.status === "pending_owner";
      return `
        <article class="staff-panel-card">
          <div class="staff-panel-head">
            <div class="staff-panel-identity">
              <strong>${escapeHtml(item.display_name || item.user_id)}</strong>
              <small>ID ${escapeHtml(item.user_id)} • ${escapeHtml(item.gender || "")}</small>
              <small>${item.system_passed ? "System pre-check passed" : "System pre-check needs review"}</small>
            </div>
            <span class="badge ${verified ? "gold" : ""}">${verified ? "Verified" : escapeHtml(item.call_verification_status || item.status)}</span>
          </div>
          <div style="display:flex;gap:8px;overflow-x:auto;margin:10px 0">
            ${photos.map((src, index) => `
              <img
                src="${escapeHtml(src)}"
                alt="Verification photo ${index + 1}"
                style="width:132px;height:168px;object-fit:cover;border-radius:12px;border:1px solid #5a4a25"
              >
            `).join("")}
          </div>
          <div class="table-actions">
            ${pending ? `<button data-call-verify-approve="${escapeHtml(item.id)}">Approve Verified</button><button data-call-verify-reject="${escapeHtml(item.id)}">Reject</button>` : ""}
            ${verified ? `<button data-call-verify-revoke="${escapeHtml(item.user_id)}">Remove Verified</button>` : ""}
          </div>
        </article>
      `;
    }).join("");
  } catch (error) {
    root.className = "empty-state";
    root.textContent = error.message || "Unable to load call verification reviews.";
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

  const callVerificationPanel = document.getElementById("callVerificationPanel");
  if (callVerificationPanel) callVerificationPanel.hidden = !owner;

  if (owner) {
    document.body.classList.remove("auth-loading");
    document.body.classList.add("auth-ready");
    loadStaffPanels();
    loadRoomThemes();
    loadOwnerNotifications();
    loadCallVerifications();
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
    "room-theme-new": ["Add Free Room Theme",
      field("name","Theme name") +
      field("asset","Theme image HTTPS URL") +
      selectField("duration_mode","Duration",[["scheduled","Set Date & Time"],["permanent","Permanent"]]) +
      field("starts_at","Start date/time (blank = now)","datetime-local") +
      field("ends_at","End date/time","datetime-local")
    ],
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
  if (action === "staff-credentials") {
    const panelId = String(data.panel_id || "");
    const staffEmail = String(data.staff_email || "").trim().toLowerCase();
    const password = String(data.login_password || "");
    const confirmPassword = String(data.confirm_password || "");

    if (!staffEmail || !staffEmail.includes("@")) {
      throw new Error("Enter a valid staff Gmail / Email.");
    }
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
    await loadStaffPanels();
    return;
  }

  if (action === "call-verification-refresh") {
    await loadCallVerifications();
    toast("Call verification reviews refreshed.");
    return;
  }

  if (action === 'room-theme-new') {
    const name = String(data.name || '').trim();
    const asset = String(data.asset || '').trim();
    const durationMode = String(data.duration_mode || 'scheduled');
    const permanent = durationMode === 'permanent';

    if (name.length < 2) throw new Error('Enter a theme name.');
    if (!asset.startsWith('https://') && !asset.startsWith('data:image/')) {
      throw new Error('Use an HTTPS image URL or image data URL.');
    }

    let startsAt = Date.now();
    if (data.starts_at) {
      const startDate = new Date(String(data.starts_at));
      if (Number.isNaN(startDate.getTime())) throw new Error('Select a valid start date/time.');
      startsAt = startDate.getTime();
    }

    let endsAt = null;
    if (!permanent) {
      if (!data.ends_at) throw new Error('Select an end date/time or choose Permanent.');
      const endDate = new Date(String(data.ends_at));
      if (Number.isNaN(endDate.getTime())) throw new Error('Select a valid end date/time.');
      endsAt = endDate.getTime();
      if (endsAt <= startsAt) throw new Error('End date/time must be after start date/time.');
    }

    await api('/api/room-themes', {
      method: 'POST',
      body: JSON.stringify({
        name,
        asset,
        permanent,
        starts_at: startsAt,
        ends_at: endsAt,
      }),
    });
    toast(
      permanent
        ? 'Permanent room theme added from Owner Panel.'
        : 'Scheduled room theme added from Owner Panel.'
    );
    await loadRoomThemes();
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
  if (currentSession?.role === "owner" || hasPermission(new Set(currentSession?.permissions || []), "rooms.theme_view")) {
    loadRoomThemes();
  }
  if (currentSession?.role === "owner") {
    loadOwnerNotifications();
    loadCallVerifications();
  }
  if (currentSession?.role === "owner" || hasPermission(new Set(currentSession?.permissions || []), "audit.view")) {
    loadAuditLog();
  }
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

document.body.addEventListener("change", (event) => {
  const groupInput = event.target.closest("[data-dialog-permission-group]");
  if (!groupInput) return;
  const group = groupInput.dataset.group;
  const container = groupInput.closest(".dialog-permission-group");
  container?.querySelectorAll(`input[name^="permission_${group}."]`)
    .forEach((input) => { input.checked = groupInput.checked; });
});

document.body.addEventListener("change", e => {
  const input = e.target.closest("[data-feature]");
  if (!input) return;
  state.features[input.dataset.feature] = input.checked;
  toast(`${pretty(input.dataset.feature)} ${input.checked ? "enabled" : "disabled"} in panel preview`);
});

document.body.addEventListener("change", async (event) => {
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
  const manualVerifyButton = e.target.closest("[data-call-verify-manual]");
  if (manualVerifyButton) {
    const userId = String(document.getElementById("manualCallVerifyUserId")?.value || "").trim();
    const note = String(document.getElementById("manualCallVerifyNote")?.value || "").trim();
    if (!userId) {
      toast("Enter a User ID.");
      return;
    }
    manualVerifyButton.disabled = true;
    try {
      await api("/api/call-verifications/user/" + encodeURIComponent(userId) + "/verify", {
        method: "POST",
        body: JSON.stringify({ note }),
      });
      toast("ID " + userId + " verified by Owner.");
      document.getElementById("manualCallVerifyUserId").value = "";
      document.getElementById("manualCallVerifyNote").value = "";
      await loadCallVerifications();
    } catch (error) {
      toast(error.message);
    } finally {
      manualVerifyButton.disabled = false;
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
      await loadCallVerifications();
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
      await loadCallVerifications();
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

  const action = e.target.closest("[data-action]")?.dataset.action;
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
loadSession();
