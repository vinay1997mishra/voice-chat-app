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

### Party > Events

- Activity cards
- Games
- Gift festival
- VIP activity
- Family/CP activities

### Party > Country

- Country filter
- Country-specific room list

## 3. Create Room

Room creation contains:

- Room DP/photo
  - the Camera/Gallery choices appear **only after tapping the DP control**
- Room name
- Country
- Party mode
- Seat/mic count

Supported seat counts:

- 8, 9, 10 → 2 rows
- 12–18 → 3 rows
- 19–28 → 4 rows
- 29–35 → 5 rows
- 36–42 → 6 rows

Rows stay balanced; each row can differ by at most one seat.

The room belongs to the user who created it. Creating a room must never grant platform-owner privileges.

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
- Multiple recipients may be selected.
- Sending cost is multiplied by selected recipient count.
- Gift effects are routed to the effect queue when room effects are enabled.
- Production coin/diamond movement is server-authoritative.

## 6. Discover

- Search by room ID/name
- Search history
- Recommended/New/Country results
- Room opening and recent tracking

## 7. Message

- Private message list
- Friend/social message flow
- Production realtime delivery plugs into the IM adapter

## 8. Mine (profile)

This is the user's personal profile screen, separate from Party > Mine.

Contains:

- Profile identity
- Public ID
- VIP/Noble badges
- Coins
- Diamonds
- VIP
- Gifts
- Games
- Family
- CP
- More/settings

## 9. Games

Game Center includes:

- **Fruit Jackpot** — continuous timed fruit rounds with 5× / 10× / 20× / 40× multipliers, jackpot display and recent-result history
- **Ludo** — actual local playable board flow
- **UNO** — actual local playable card flow
- Lucky 777
- Blackjack
- Gift Draw
- Guessing

Online/multiplayer authority must be provided by the production game backend.

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
- Agency commissions
- BD targets/commission
- exit requests
- complaint timers
- automatic settlement/exchange rules
- minimum transfer rules

## 13. Wallets

User-facing wallets are separate from privileged treasury/inventory wallets.

- Normal User Wallet
- Coin Seller inventory wallet when that role is active
- Merchant wallet when that role is active

The **Owner Treasury Wallet exists only in the separate Owner Web Panel**, not in the Android app.

## 14. Standalone Owner Web Panel

The platform Owner Panel is a separate website under:

`apps/tinni_owner_panel/`

It is not a room-owner panel and is not shown inside the app.

It controls platform configuration, users, rooms, wallets, Host/Agency/BD policy, VIP, gifts, entries, frames, banners, custom panels and audit history after protected Owner APIs are connected.

## 15. Production boundaries

The following must be backed by real server/provider integrations before production launch:

- RTC audio
- realtime IM
- online presence
- production wallet/diamond accounting
- gift settlement
- recharge verification
- Host/Agency/BD settlement
- multiplayer games
- Fruit Jackpot round/result authority, aggregate bet exposure and settlement
- push notifications
- media/effect asset storage
- fraud/abuse controls
- protected platform-owner APIs

Local demo state must not be treated as production financial authority.
## Visual color and shine system

Tinni Star uses **black + gold as the app shell/background identity**, not as the default color for every function. Functional modules must keep their own semantic color so users can recognize actions quickly.

Semantic accents:
- CP / relationship / hearts / rings: pink/rose.
- VIP / Noble: progressive blue → violet → magenta, with higher-level legendary accents.
- Gifts/custom gifts: purple/magenta; CP gifts pink; crown/dragon/rank gifts amber.
- Family / seat-success / active mic: emerald green.
- Games: per-game color — Fruit Jackpot amber, Fruit Party pink, Ludo green, UNO red.
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
