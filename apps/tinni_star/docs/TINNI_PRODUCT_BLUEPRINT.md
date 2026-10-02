# Tinni Chat / Tinni Star — Product Blueprint

This file is the source-of-truth screen/function map for the Android app. It is separate from the standalone platform Owner Web Panel.

## 1. Main navigation

Bottom navigation:

1. **Party**
2. **Discover**
3. **Message**
4. **Mine**

The platform Owner Panel is **not** shown in this navigation and is not bundled as an in-app control surface.

## 2. Party screen

Top swipe/tap sections:

- **Mine**
- **Party**
- **Events**
- **Country**

### Party > Mine

- My Room card
- Recent rooms are rooms the user actually visited
- Following rooms
- One room per user
- Room creator is the room owner
- Public user ID and that user's room ID are the same ID

### Party > Party

- Featured/banner area
- Game entry
- CP ranking entry
- Family entry
- Recommended rooms
- Popular/New filters
- Room cards with room identity and online count
- By default, Party shows rooms from the user's selected/profile country.
- The country selector stays in the **Country** tab, not on the Party page.
- When the user selects another country from the Country tab, Party switches to that selected country's rooms.

### Party > Events

- Activity cards
- Games
- Gift festival
- VIP activity
- Family/CP activities

### Party > Country

- Country filter with all supported countries.
- Every country entry shows flag + country name.
- Default country is the user's selected/profile country.
- Country-specific room list.
- Users may visit another country's Party rooms by selecting that country.

## 3. Create Room

Room creation contains:

- Room DP/photo
  - the Camera/Gallery choices appear **only after tapping the DP control**
- Room name
- Country
- Party mode
- Seat/mic count

Supported seat counts:

- 8–10 → 2 rows
- 11–15 → 3 rows
- 16–24 → 4 rows
- 25–30 → 5 rows
- 31–36 → 6 rows
- 37–42 → 7 rows

**Locked anti-regression rule:** 37–42 seat rooms use 7 rows, and a 42-seat room is exactly 6 seats × 7 rows. Do not restore the old 7 seats × 6 rows layout. High-capacity layouts must keep at most 6 seats on a row so seat circles stay visibly larger. Rows keep the existing balanced-distribution pattern for partial final rows.

The room belongs to the user who created it. Creating a room must never grant platform-owner privileges.

- Each user ID can create **exactly one room**.
- That room's **Room ID is exactly the same as the owner's User ID**.
- A second create-room attempt for the same user must not create another room; the existing room is returned/opened instead.

## 4. Room screen

Main room areas:

- Room title + ID
- Minimize and close controls
- Optional room notice/banner
- Mic mode indicator
- Seat count
- User coin balance
- Seat grid
- Room information/topic
- Room chat
- Bottom controls:
  - More
  - Chat
  - Mic
  - Gift
  - Seat

### Seat rules

- Seat open/lock/mute/unmute must never happen automatically.
- In **Apply Mic** mode, tapping a seat sends a request and waits for explicit approval.
- In **Free Mic** mode, tapping a free seat joins it.
- Lock/unlock is an explicit manual room-management action.
- Normal users cannot silently lock seats.
- Seat layouts resize as seat count increases.

### Room management

Room-owner/admin management is room-specific only. It is **not** the platform Owner Panel.

Room tools include:

- Sound
- Friends/Event room mode
- Launch/stop event
- Block/allow visual gift effects
- Hide/show notice
- Room theme
- Seat controls
- Lucky number
- Group PK
- Public/private room
- Public Screen
- Room Settings
- Report

### Background room behavior

Leaving the room screen to use another app should not automatically close the room session. The Android foreground-service and realtime adapter own that lifecycle.

## 5. Gift flow inside room

The gift panel contains a **horizontally swipeable recipient strip**.

- Room users can be selected from the strip.
- Multiple recipients may be selected; only the selected real user IDs receive the gift/effect.
- **Selected-DP lock:** every selected recipient DP is visibly blurred/dimmed with a gold check/glow; unselected DPs remain normal and clear.
- **Send readiness lock:** Send becomes enabled immediately when a gift and at least one recipient are selected. It may disable only while that send request is actually in flight; no backend preflight may leave a valid Send button grey.
- Sending cost is multiplied by selected recipient count.
- Gift effects are routed to the effect queue when room effects are enabled.
- Production coin/diamond movement is server-authoritative.
- **Locked Lucky send UX:** once a valid Lucky gift Send is tapped, the gift panel closes immediately; the network request continues on the room screen.
- After a successful Lucky send, the room screen shows the bright Combo control with a visible 12-second countdown. Every successful Combo send restarts the 12-second window. Do not reintroduce the old behavior where the Lucky panel stays open and hides the Combo continuation.

## 6. Discover

- Search by room ID/name
- Search history
- Recommended/New/Country results
- Room opening and recent tracking

## 7. Message and notifications

- Private message list
- Friend/social message flow
- Production realtime delivery plugs into the IM adapter
- Push/in-app notifications are required for:
  - every new private message
  - incoming calls
  - missed calls
  - followed users coming online
  - coins received from a Coin Seller
  - room-owner commission credits, including the configured 10% commission on eligible total room gift sending
  - event/reward start notifications
  - event/reward ending notifications
  - other event-related reminders
- Event/reward notification campaigns may send up to 15 event-related notifications per day per user when applicable.

## 8. Mine / Me (personal profile) — REFERENCE VIDEO LOCKED

This is the user's **bottom-navigation personal Mine/Me page**. It is separate from **Party > Mine**, which remains the room-oriented area.

### 8.1 Visual target

The supplied reference videos are the visual target for this page. The final Tinni Star implementation must match the reference flow as closely as practical, including:

- the same vertical information order;
- compact top profile identity block;
- card proportions and row heights;
- icon placement;
- spacing and grouping;
- text hierarchy;
- VIP / Wealth card placement;
- list-chevron behavior;
- light profile-page background treatment;
- reference-style gold/yellow accent treatment.

Do not replace the reference layout with an unrelated generic settings/profile design. Functional labels listed below stay exactly as written unless the user explicitly changes them.

### 8.2 Top profile identity block

The top area contains:

- Profile DP/avatar, including equipped profile frame.
- Display name.
- Country flag.
- Public **UID**.
- User level badge.
- Family tag + Family level when the user belongs to a Family.
- Identity/VIP badge area where applicable.

Below the identity row, show live account statistics:

- **Follow** — real following count.
- **Fans** — real follower count.
- **Charm** — real lifetime received-gift value / Charm source.

These values must come from account/backend data and must not be hard-coded demo numbers.

### 8.3 Wallet / VIP / Wealth cards

Immediately below the account stats:

- **Wallet**
  - shows the user's current normal-wallet Coin balance;
  - opens the existing Wallet/Recharge surface;
  - must not mint or fabricate coins locally.
- **VIP**
  - shows current VIP state/level;
  - opens the real VIP page.
- **Wealth level**
  - shows the current Wealth level;
  - opens a dedicated Wealth Level page;
  - Wealth progress is based on the user's **real lifetime gift sending**;
  - level thresholds are data-driven and configurable from the Owner Panel;
  - the screen shows current level, lifetime sending and next configured threshold.

Charm and Wealth are separate concepts:
- **Wealth** = lifetime eligible gift sending.
- **Charm** = lifetime eligible gift receiving.

The backend is authoritative for both totals and resulting levels.

### 8.4 Mine menu — exact order

The Mine menu order is locked to:

1. **Medal of Honor**
2. **Custom Center**
3. **Shop**
4. **Props**
5. **Reward Records**
6. **Task**
7. **Host data**
8. **Family**
9. **CP Nest**
10. **Feedback**
11. **Setting**

Do not silently remove, rename, duplicate or reorder these entries.

### 8.5 Medal of Honor

- Opens a real Medal of Honor page.
- Loads the user's active medals from backend/account identity data.
- Shows medal name and visual identity.
- Empty state is **No medals yet**, not a fake medal list.
- Owner-created/configured medals remain data-driven.

### 8.6 Custom Center

- Opens the existing personalization/customization center.
- This is the entry for profile/custom visual configuration supported by Tinni Star.
- It must not be a dead or placeholder tile.

### 8.7 Shop

- Opens the real Tinni Star Store.
- Store catalog remains data-driven.
- Reference-video behavior to preserve:
  - category-based browsing;
  - item cards;
  - item price;
  - duration/permanent status;
  - item preview;
  - Purchase/Send behavior where that catalog type supports it.
- Cosmetic/content catalog may include vehicle/entry effects, profile/card items, frames/rings, bubbles and future Owner Panel-configured catalog types.

### 8.8 Props

- Opens the user's owned Props/Inventory surface, not the Shop placeholder.
- Loads actual owned entitlements/inventory.
- Shows item name/type and owned state.
- Equippable props such as frames support **Use / Using** state through backend inventory/equip authority.
- Future prop types must use the same entitlement model rather than creating duplicate local-only inventories.

### 8.9 Reward Records

- Opens real reward/wallet history.
- Reads server wallet/reward transactions.
- Shows transaction title/note, date/time and Coin/Diamond delta.
- Positive and negative records are visually distinguishable.
- No fabricated local history may be shown.

### 8.10 Task

- Opens the real Task page.
- Task completion is derived from server-visible account activity.
- Task examples may include:
  - Complete your profile;
  - Follow 1 user;
  - Enter a Party room;
  - Send your first gift;
  - Join a Family.
- Completed tasks can claim the configured Coin reward once.
- Claiming is server-authoritative, writes the reward transaction and updates the wallet.
- A claimed task cannot be claimed again.
- Task definitions/rewards should remain extensible and Owner Panel-configurable as the production task system expands.

### 8.11 Host data

**Host data** must be a real role/settlement page, not an information placeholder.

It shows applicable real account data:

- current role: Host / Agency / BD / Not enrolled;
- Host Diamond balance where applicable;
- Diamond reference value;
- Agency/BD commission balance where applicable;
- withdrawable/transferable settlement value;
- settlement transfer action when the account is eligible;
- settlement transfer history;
- recipient ID / role / amount / timestamp for completed transfers.

Host/Agency/BD eligibility, balances, conversion rules and settlement authority stay server-side.

### 8.12 Family

- Opens the existing Family surface.
- If the user belongs to a Family, open the Family home.
- If the user has no Family, open the Family discovery/ranking/join path.
- Family tag/level on Mine must stay synchronized with the same Family account state.

### 8.13 CP Nest

- **CP Nest stays in Mine** as its own personal CP entry.
- It opens the real CP panel/screen.
- CP Request / Accept / Disconnect, CP Level, Intimacy, Memories and other personal CP functions live in the CP system.
- Public CP Ranking/Events may still appear in Party/Home where defined.
- Games do **not** move into Mine.

### 8.14 Feedback

- Opens a real Feedback page.
- User can select a category and submit a text report/request.
- Supported categories include General, Bug, Account, Room, Payment and Safety.
- Submitted feedback is stored server-side with status and timestamp.
- The user can view their own feedback history.
- Privacy/contact requests may use this Feedback route until an official Tinni Star legal/support contact is configured.

### 8.15 Setting — exact order

**Setting** opens a dedicated page with this exact order:

1. **Message notification**
2. **Bind account**
3. **Language settings**
4. **About Tinni Star**
5. **Feedback**
6. **Blocklist**
7. **Privacy statement**
8. **Sign out**

All entries must be actionable; this page must not contain dead placeholder rows.

#### Message notification

Persist account notification preferences for:

- **Voice**
- **Vibration**
- **Only receive floating screen in the room**

The preference must survive app restart/account reload and be available to the notification layer.

#### Bind account

- Shows identities already linked to the current Tinni account.
- Google binding uses a verified Google ID token and must reject an identity already owned by another Tinni account.
- Email binding uses:
  - email/Gmail address;
  - email OTP verification;
  - a Tinni password of 8–128 characters;
  - duplicate-account protection.
- Binding adds a login identity to the **same Tinni user ID**; it must not silently create a second user.
- Facebook must not be shown as an active binding option unless Facebook login is deliberately re-enabled in the product.

#### Language settings

- Saves the user's Tinni Star language preference to the account.
- Supported choices currently include **English, Hindi and Urdu**.
- The selected preference must be used by localized screens as translations are implemented; it is not a device-only temporary toggle.

#### About Tinni Star

Shows Tinni Star product identity and current app version/build information. The page describes Tinni Star as the social live voice-room app, not another product.

#### Blocklist

- Loads the user's real server-side blocked-user list.
- Shows user identity.
- **Move out / Unblock** removes that block through the backend.
- Blocklist state must remain synchronized with messaging/room social safety behavior.

#### Privacy statement

Opens the real **Service Agreement & Privacy Policy** page described in the Privacy section of this blueprint. It must never be a blank placeholder.

#### Sign out

- Requires user confirmation.
- Revokes/logs out the session when network is available.
- Leaves/closes the active room session cleanly.
- Unregisters push for the signed-out account.
- Clears persisted local auth/profile state.
- Returns to the Login screen and prevents the previous authenticated Mine page from remaining in the navigation stack.

### 8.16 No-placeholder rule

For the Mine/Me flow, these are not acceptable final behaviors:

- No content yet for a function that is defined above;
- generic snackbars in place of the actual feature;
- a menu row that opens an unrelated page;
- hard-coded Follow/Fans/Charm/Wealth data;
- local-only fake reward/transaction history;
- local-only wallet mutation.

Every listed Mine entry must either open its real feature or show a truthful empty state backed by the real data source.

## 9. Games

Game Center includes:

- **Fruit Jackpot** — continuous timed fruit rounds with 5× / 10× / 20× / 40× multipliers, jackpot display and recent-result history
- **Ludo** — room-only server-authoritative multiplayer board flow; dice, turn, token movement, captures, winner state and restart authority are validated by the backend
- Lucky 777
- Blackjack
- Gift Draw
- Guessing

Online/multiplayer game authority is server-side; clients only render and request allowed actions.

## 10. VIP

VIP is data-driven in production.

The platform Owner Web Panel can:

- add new VIP levels
- edit every function of existing VIP levels
- enable/disable/remove/retire levels
- edit prices/requirements/duration
- edit badges
- edit profile/seat frames
- edit vehicle/animal/3D entry effects
- edit entry audio/animation/assets
- edit privileges
- reorder levels
- schedule availability
- target countries

The Android app reads and displays that configuration; it does not hardcode platform-owner controls.

## 11. Roles/tags/posts

Every account remains a normal user account first.

Additional roles/tags/posts can coexist on one ID, including:

- Host
- Agency Owner
- BD
- Coin Seller
- Merchant
- Admin
- Super Admin
- Manager
- VIP
- future custom tags/posts

## 12. Host / Agency / BD

The app exposes the applicable user portal when the backend reports the active relationship/role.

Production relationship and settlement rules are server-authoritative, including:

- same-country Host/Agency rule
- Host target cycles
- Each Agency's eligible target is the combined eligible target completed by all Hosts under that Agency.
- The Agency receives a 10% commission on that combined eligible Host target.
- The Agency Owner (the user ID that owns the Agency) is also a Host of that same Agency.
- An Agency Owner cannot join, transfer to, or act as a Host under another Agency while owning their Agency.
- BD target is calculated from the combined eligible target of all Agencies under that BD.
- BD commission is 7% when the combined Agency target reaches $500 and 10% when it reaches $1000.
- exit requests
- complaint timers
- automatic settlement/exchange rules
- minimum transfer rules

## 13. Wallets

User-facing wallets are separate from privileged treasury/inventory wallets.

- Normal User Wallet
- Coin Seller inventory wallet when that role is active
- Merchant wallet when that role is active
- Tinni Star does not use real-money in-app recharge as a user recharge flow.
- A newly created account starts with **0 Coins**. No automatic signup/start balance is granted.
- Normal User, Coin Seller and Merchant wallets may be funded/credited only through the protected **Owner Panel / authorized Staff Panel** wallet controls, or by an existing Coin Seller/Merchant transferring coins from their already-funded inventory wallet.
- A Coin Seller or Merchant may transfer existing inventory coins to any valid user ID, including their **own normal user wallet**.
- Coin Seller/Merchant transfers are redistribution only: the sender inventory balance is debited by the exact amount credited to the recipient normal wallet.
- Unexpected positive coin balance drift from any unrecognized source is not made available to the user. The unexpected amount is quarantined and the affected wallet enters a **security freeze**.
- While security-frozen, the app exposes no usable coin balance from that wallet and spending/transfer operations are blocked.
- Normal wallet ban/unban or Staff Panel controls do **not** remove a security freeze. Only the Platform Owner can remove the security freeze from the Owner Panel.
- All user-side purchases and paid actions use **Coins only**.
- Diamonds are not a purchase currency for users.
- Coins are used for VIP, gifts, frames, room themes/backgrounds, store/inventory items, game bets/paid game actions, CP/family paid items, entries/effects, and any other purchasable user feature unless the Owner Panel explicitly marks an item as free.
- Diamond earning/display is Host-only.
- An active Host under an Agency, including an Agency Owner acting as the Host of their own Agency, receives 1 Diamond for each 1 Coin received through eligible gifts.
- Diamond earning starts only from the exact time the user's Host status becomes active.
- Gifts/coins received before the user became an active Host are never converted into Diamonds later and are not backfilled retroactively.
- Users who are not an active Host do not receive or see a Diamond wallet/section even after receiving coins or gifts; their Wallet shows Coins only.
- For eligible Hosts, the Wallet shows the Diamond balance and, directly below it, the automatically calculated USD value.
- Current settlement reference: 4,000,000 Diamonds = $1.70, so the displayed USD value is calculated from that rate.
- At this rate, $2 is approximately 4,705,882 Diamonds (about 4.71M Diamonds).
- Host, Agency and BD balances become transferable when the withdrawable USD value reaches at least $2.
- Balances below $2 cannot be transferred.
- A **Transfer** action is shown in the Wallet beside/under the Diamond balance.
- Transfer opens a recipient search where the sender enters a User ID.
- Only a valid **Coin Seller** or **Merchant** account may be selected as the transfer recipient.
- Before transfer, the app must show the matched account identity/role and the amount for confirmation.
- The transfer is server-authoritative and must be recorded in wallet/settlement history.

The **Owner Treasury Wallet exists only in the separate Owner Web Panel**, not in the Android app.

## 14. Standalone Owner Web Panel

The platform Owner Panel is a separate website under:

`apps/tinni_owner_panel/`

It is not a room-owner panel and is not shown inside the app.

It controls platform configuration, users, rooms, wallets, Host/Agency/BD policy, VIP, gifts, entries, frames, banners, custom panels and audit history after protected Owner APIs are connected.

## 15. KTV / Music local storage

- Music/KTV songs added or downloaded by a user are stored in that phone's app-private local storage.
- The app does not depend on a permanent cloud song library for those user-added local tracks.
- When Tinni Star is uninstalled, its app-private music/song files are deleted with the app data.
- Reinstalling the app does not restore those locally stored songs automatically.
- The room Music list may contain up to 300 songs.

## 16. Production boundaries

The following must be backed by real server/provider integrations before production launch:

- RTC audio
- realtime IM
- online presence
- production wallet/diamond accounting
- gift settlement
- Host/Agency/BD settlement
- multiplayer games
- Fruit Jackpot round/result authority, aggregate bet exposure and settlement
- push notifications
- media/effect asset storage
- fraud/abuse controls, including server-side request-rate limits and temporary blocks for gift sending, settlement transfers, Coin Seller/Merchant coin transfers and game actions
- protected platform-owner APIs

Local demo state must not be treated as production financial authority.
## Visual color and shine system

Tinni Star uses **black + gold as the app shell/background identity**, not as the default color for every function. Functional modules must keep their own semantic color so users can recognize actions quickly.

Semantic accents:
- CP / relationship / hearts / rings: pink/rose.
- VIP / Noble: progressive blue → violet → magenta, with higher-level legendary accents.
- Gifts/custom gifts: purple/magenta; CP gifts pink; crown/dragon/rank gifts amber.
- Family / seat-success / active mic: emerald green.
- Games: per-game color — Fruit Jackpot amber, Fruit Party pink, Ludo green.
- Music/KTV/messages: cyan/teal.
- Social/follow/discover: blue.
- Wallet/coins: warm amber; diamonds: cyan.
- Store/inventory: coral; backpack: green.
- Rankings/trophies/crowns: amber/gold where premium rank context is intended.
- Mute/kick/report/danger: red.
- Emoji/emotes: bright orange-yellow.

Shine rule:
- Every functional accent must have a matching soft glow/halo, selected-state shine, colored border glow, or subtle feature gradient on the dark UI.
- Active/live states shine more strongly; disabled/locked states stay muted.
- A feature's glow must match its semantic color rather than falling back to generic gold.
- Reusable `FeaturePalette`, `ShiningIcon`, and semantic `RoyalPanel.accentColor` treatments are the implementation baseline for future modules.
- Gold remains appropriate for brand headings, royal framing, premium rank/crown contexts and the black/gold page shell.


## Tinni Star Privacy & Service Agreement

- Mine → Setting must contain **Privacy statement**.
- Privacy statement opens a real in-app page titled **Service Agreement & Privacy Policy**; it must not be a placeholder.
- The page has two switchable sections: **Service Agreement** and **Privacy Policy**.
- Privacy Policy must be written specifically for Tinni Star and cover account/profile data, rooms/chat/calls, verification material, device/diagnostic data, wallet/gift/purchase records, public profile visibility, service providers, retention, security, device permissions, user privacy choices/rights, age requirements, international processing, policy updates and in-app privacy contact.
- Service Agreement must cover account responsibility, rooms/chat/calls, virtual items/balances, purchases/refunds, safety/moderation, service availability, privacy-policy linkage, agreement updates and support contact.
- Do not publish invented legal contact information. Until an official legal/support email is configured, privacy/contact requests route through **Mine → Feedback**.
- Current policy effective date: **30 September 2026**. Any material future policy change must update the displayed effective date and the policy text.


### Family reference coin-scale rule — LOCKED

- The supplied Family reference uses a smaller coin denomination than Tinni Star.
- **20,000 reference coins = 2,000,000 Tinni coins.**
- Therefore every **coin-based Family progression / Family level / contribution target** copied from that reference is converted at **100×** into Tinni Star coins.
- Example conversions: 20K → 2M, 50K → 5M, 100K → 10M, 500K → 50M, 1M → 100M.
- The 100× conversion applies only to coin-denominated Family values. It does **not** multiply percentages, member limits, role counts, dates, durations or other non-coin values.
- If a source screenshot value is not legible, do not invent it. Keep the last explicitly locked Tinni threshold until the exact reference value is confirmed.
- Family Wallet transfer rule remains: **sender gets no Family EXP; receiver gives the Family 1 EXP per 1 Tinni coin received**.
- Daily Family check-in also adds the configured Family EXP once per day.
- Monthly Family Wallet bonus remains **L1 1.00% + 0.25 percentage point per level**, capped by the locked Family level rules.
