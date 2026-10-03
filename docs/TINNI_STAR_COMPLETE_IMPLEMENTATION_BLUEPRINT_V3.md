# TINNI STAR — COMPLETE IMPLEMENTATION BLUEPRINT v3
## Single Source of Truth / Developer Handoff

**Purpose:** This is the one master specification to hand to a developer, coding agent, or technical team for building Tinni Star. It consolidates the YoHoo Star functional reconstruction, all Tinni Star requirements confirmed by screenshots/videos/conversation, architecture boundaries, data models, permissions, runtime rules, testing requirements, and unresolved reference items.

**Important implementation rule:** Build Tinni Star as a clean-room application. Reproduce product behavior and interaction patterns, but do not copy proprietary source code, protected assets, secrets, private APIs, signatures, or obfuscated implementation from another app.

**Status language used in this document:**
- **LOCKED** = user-confirmed behavior; implement exactly unless the user later changes it.
- **CLEAR AT FEATURE LEVEL** = feature family is known; exact visual details may still need reference assets/video.
- **VIDEO/ASSET NEEDED** = do not invent the final look or detailed UI state; keep architecture ready and wait for reference.

---

# PART I — PRODUCT BLUEPRINT

# Tinni Star × YoHoo Star — Merged Master Blueprint v2

Status: living product blueprint for Tinni Star.
Source basis:
1. YoHoo Star 2.03.116 screen/action/state blueprint.
2. Tinni Star screenshots and user-confirmed behavior.
3. User-confirmed room/seat/owner rules from reference videos.
4. Existing Tinni Star implementation direction.

## 1. Product topology

App Startup
→ Auth / Session
→ Main Shell
  → Party
    → Mine (room-focused)
    → Party
    → Events
    → Country
  → Discover
  → Message
  → Mine (profile-focused)

Voice Room is the central runtime domain and connects:
Room Session
→ Seat / Mic
→ Chat / Members
→ Gifts / Effects
→ Owner/Admin controls
→ KTV / Games
→ VIP / CP / Family
→ Moderation / Background / Reconnect

Important distinction:
- Party > Mine = room-focused.
- Bottom navigation > Mine = user-profile-focused.
These must never be treated as the same screen.

## 2. Party > Mine — LOCKED

Structure:
- My room
- Recents
- My followings

Rules:
- The user who creates a room becomes that room's Owner.
- My room shows the user's owned room.
- Recents shows rooms the user recently visited.
- My followings shows followed rooms.
- This screen is not the user profile screen.

## 3. Party > Party — LOCKED

Primary structure:
- Mine / Party / Events / Country top swipe tabs.
- Weekly CP / ranking banner.
- Game.
- CP Ranking.
- Family.
- Popular.
- New.
- Room cards / room list.
- Create Room.
- Search.
- VIP shortcut.

Navigation:
- Top tabs are touchable.
- Top tabs are horizontally swipeable.
- Visible feature cards must perform a real action, not placeholder-only taps.

New-room rule:
- New shows only rooms created in the last 15 days.
- createdAt must be stored for every room.
- Old rooms do not appear in New.

## 4. Party > Events — CLEAR AT STRUCTURE LEVEL

Expected families:
- Weekly CP.
- Game events.
- Gift festival/activity.
- VIP activity.
- Family activity.
- Birthday/party/activity flows from YoHoo blueprint.

Exact production event cards, timers, reward display and stage layouts still need runtime/video confirmation.

## 5. Party > Country — LOCKED AT CORE LEVEL

- Country selector.
- Rooms filtered by country.
- Same room card interaction as Party.
- Search fallback.
- Region/server feature gates may later be controlled by backend/remote config.

## 6. Bottom Mine / Profile — LOCKED

Profile-focused screen:
- Avatar.
- Nickname.
- UID.
- Country.
- Coins.
- Diamonds.
- VIP.
- Noble.
- Gift.
- Game.
- Family.
- CP.
- More.
- Edit profile.
- Account binding.
- Later: birthday, gender, signature, medals, vehicle/headwear, good-number identity, followers/fans, blacklist/report.

## 7. Room ownership — LOCKED

Room creation:
CREATE_ROOM(userId)
→ room.ownerId = userId
→ creator receives Owner role
→ Owner controls become available for that room only

Owner authority is split into two surfaces:

A. Room Settings / Room Management
- Room Information / Edit Room.
- Mic Mode.
- Seat count / seat behavior.
- Seat design / seat layout selection.
- Lock/unlock/mute empty seats.
- Manage admins where supported.
- Room Theme / Background.
- Room Level / Kickout List.
- Room activity controls where present.
- Other room-wide settings shown in the 4-box Room Settings panel.

Room Mode is NOT required as a separate Tinni Star setting unless a later reference explicitly confirms it.

B. User-specific moderation
- Kick Out is NOT a Room Settings item.
- Block/blacklist is NOT a Room Settings item.
- These actions appear only after the Owner/Admin taps a user's ID / avatar / occupied seat / user card and opens that user's action menu.
- User-specific mic actions also belong to that user context when applicable.

### Owner vs Admin permission boundary — LOCKED

Room Owner:
- Can open and change Room Settings.
- Can edit Room Information.
- Can change Mic Mode / seat count.
- Can choose Seat Design.
- Can change Room Theme / Background.
- Can view Room Level / Kickout List.
- Can Unkick users from Kickout List.
- Can perform user-specific moderation.
- Can lock/unlock seats.
- Can mute/unmute seats.
- Can remove users from seats.

Room Admin:
- CANNOT open/view the Kickout List.
- CANNOT Unkick a user.
- CANNOT change Room Settings.
- CANNOT edit Room Information.
- CANNOT change Mic Mode / seat count.
- CANNOT change Seat Design.
- CANNOT change Room Theme / Background.
- CANNOT change other room-wide settings.
- CAN Kick Out a user from the user-specific action menu.
- CAN invite any room user to an empty seat / mic.
- CAN accept or reject a user's Apply Mic request.
- CAN remove a user from a seat / send user down from mic.
- CAN lock/unlock seats.
- CAN mute/unmute seats.
- CAN directly take an empty seat / go on mic without submitting Apply Mic, even when the room is in Apply Mic mode.

All permission checks must also be enforced server-side; hiding a button in UI is not sufficient.

## 8. Room lifecycle — MERGED FROM YOHOO

OUTSIDE
→ PRECHECK
→ ROOM_METADATA
→ IM_JOIN
→ RTC_JOIN
→ AUDIENCE
→ optional seat/mic
→ chat/gift/KTV/game
→ minimize/background or leave

Reconnect:
CONNECTED
→ RECONNECTING
→ RESYNC_ROOM_SNAPSHOT
→ CONNECTED

Room UI must not use RTC alone as permanent room-state truth.

## 9. Seat row policy — LOCKED

Selectable seat count:
- Every whole-number seat count from 8 through 42 is supported.

Row-count rule:
- 8–10 seats → 2 rows.
- 11–15 seats → 3 rows.
- 16–24 seats → 4 rows.
- 25–30 seats → 5 rows.
- 31–42 seats → 6 rows.

Distribution:
- For layouts with 3 or more rows, every row above the final two rows must contain the same number of seats.
- The final two rows share all remaining seats as evenly as possible.
- If one seat remains after the split, the second-last row gets that extra seat.
- This keeps the upper block visually uniform while allowing the final two rows to use wider horizontal seat gaps.
- Examples:
  - 11 = 4+4+3
  - 13 = 5+4+4
  - 17 = 5+5+4+3
  - 21 = 6+6+5+4
  - 26 = 6+6+6+4+4
  - 27 = 6+6+6+5+4
  - 31 = 6+6+6+6+4+3
  - 32 = 6+6+6+6+4+4
  - 33 = 6+6+6+6+5+4
  - 37 = 7+7+7+7+5+4
  - 42 = 7+7+7+7+7+7

Visual rule:
- All rows use the same left and right working edges.
- Rows above the final two rows keep their normal equal seat count.
- Because the final two rows usually contain fewer seats, their seats are distributed across the same width with larger gaps.
- The leftmost and rightmost visual corners remain aligned to the same room-seat area.
- Lower seat counts use larger seat circles/frames.
- Higher seat counts use smaller seat circles/frames.
- Chat area must remain usable below seats.
- Minimum target: about 4 room-message lines visible above the typing/control bar.

## 10. Seat/Mic state — LOCKED CORE BEHAVIOR

### Mic Mode
Mic Mode contains both seat-count control and seat-entry policy.

Seat-count control:
- Owner can increase or decrease the number of seats/mics using the supported Tinni Star seat-count rules.

Free Mic:
- A normal user may enter the room and tap any empty, unlocked seat.
- If the seat is available, the user can sit on that seat directly.
- No Owner/Admin approval is required for the normal user in Free Mic mode.

Apply Mic:
- A normal user entering the room cannot directly occupy an empty seat.
- The user must Apply for Mic / request a seat.
- Owner or Admin receives the request.
- Owner/Admin accepts or rejects whether that user is allowed onto a seat.
- Only after approval is the user added to a seat.

Owner/Admin seat-control exception:
- Free Mic / Apply Mic restriction does not block Owner or Admin from taking an empty seat.
- When Owner/Admin taps an empty seat, the seat-action menu includes:
  - Seat Lock / Unlock
  - Seat Mute / Unmute
  - Go to Seat
- Go to Seat lets Owner/Admin occupy the empty seat directly.
- Owner/Admin does not need to submit an Apply Mic request for themself.
- Admin's authority here is limited to seat/mic moderation; it does not grant access to Room Settings.

Normal-user state:
AUDIENCE
→ [Free Mic: tap empty seat] → ON_SEAT
or
AUDIENCE
→ [Apply Mic: request] → MIC_REQUESTED
→ Owner/Admin ACCEPT → ON_SEAT
→ Owner/Admin REJECT → AUDIENCE

Seat state:
FREE
→ LOCKED / MUTED_BY_ROOM / OCCUPIED
→ unlock/unmute/release/move as permitted.

Other confirmed control families:
- cancel mic request.
- invite user to mic.
- remove user from mic.
- mute/unmute.
- lock/unlock.
- move/assign user where supported.

## 11. Seat Design / Seat Layout — LOCKED CONCEPT

- Tinni Star must ship with multiple seat designs/layout styles inside the app.
- Room Owner gets an option in Room Settings to choose the seat design used by that room.
- Changing seat design changes the visual presentation only; SeatState / MicState / permissions remain the same.
- The room must remember the selected seat design.
- Exact available designs, thumbnails, animation style and visual differences still need reference/video confirmation.

## 12. User seat identity/frame — PARTIALLY CLEAR

Reference requirement:
- Occupied seat shows the user's avatar/identity.
- Different users can have different seat/profile frames.
- Frame must render independently per user.
- Frame can coexist with mic state, user name and badges.
- VIP/Noble/medal/vehicle identity must not overwrite the user's chosen/entitled frame.

Still VIDEO NEEDED:
- exact frame layers.
- frame ownership source.
- VIP vs purchased frame priority.
- owner/admin special frame behavior.
- animated vs static frame rules.

## 13. Room screen control map — CLEAR AT FEATURE LEVEL

Core:
- Room title/info.
- Owner/admin entry.
- minimize/back/leave.
- members.
- seat/mic.
- chat.
- gift.
- KTV.
- game.
- BGM/music.
- share.
- room theme.
- moderation.
- activities.

### Room Settings entry point — LOCKED
- The 4-box / grid icon in the room toolbar is the Room Settings button.
- Tapping that 4-box icon opens the room-wide Settings / Tools panel.
- This control must not be treated as a generic overflow menu.
- Kick Out / Block are not shown in this Room Settings panel.
- User-specific moderation is opened by tapping the target user's ID / avatar / occupied seat / user card.

Room chat and seat area must coexist without one covering the other.

## 13B. Room Information / Edit Room — LOCKED

Room Settings > Room Information has an Edit action.

Owner can edit:
- Room DP / room avatar.
- Room Name.
- Room Description.
- Room Member List.

Room Member List management:
- Owner can open the room member list from Room Information.
- Owner can remove a member from that room member list.
- This member-list removal control is separate from the immediate Kick Out action opened from a user's room ID/avatar/seat.

Changes should update the room metadata for other users after synchronization.

## 13C. Room Theme / Background — LOCKED BUSINESS RULE

Room Settings includes Room Theme / Background.

Built-in backgrounds:
- The app contains room wallpaper/background choices.
- Owner can select an available built-in room background subject to its entitlement/rules.

Custom uploaded background:
- Room Owner can upload a background/wallpaper of their choice where the feature permits.
- Custom room background is NOT free.
- It requires coins.
- The purchasable validity choices are:
  - 7 days
  - 10 days
  - 15 days
  - 30 days
  - Permanent
- Exact coin price for each duration is not yet locked.
- After purchase/activation, the chosen/uploaded wallpaper becomes the room wall/background for the purchased validity.
- Expiring backgrounds must have entitlement expiry state; Permanent does not expire.

Recommended entitlement model:
RoomBackgroundEntitlement {
  roomId
  backgroundId
  sourceType // built_in | owner_upload
  purchasedByUserId
  coinPrice
  activatedAt
  expiresAt? // null for permanent
  status
}

## 13A. Room Level / Kickout List — LOCKED FROM REFERENCE

Room Settings contains a Room Level / management area that includes Kickout List.

Kickout List is a room-level moderation history/audit surface, not the same thing as the user-specific Kick Out action.

Each active Kickout record must show:
- LEFT SIDE: kicked user's display name.
- LEFT SIDE: kicked user's user ID.
- LEFT SIDE: kick date.
- LEFT SIDE: kick time.
- LEFT SIDE: admin/moderator who performed the kick: display name.
- LEFT SIDE: admin/moderator who performed the kick: user ID.
- RIGHT SIDE: Unkick action.

Interaction split:
- To kick a user now: Owner/Admin taps that user's ID/avatar/occupied seat/user card, then uses the user-specific action menu.
- Kick duration selector appears during Kick Out with exactly these choices:
  - 2 hours
  - 12 hours
  - 48 hours
  - Permanent
- To review CURRENT active kickouts: Room Owner opens the 4-box Room Settings panel, then opens Kickout List.
- Admin cannot view/open Kickout List.
- Kickout List is not an immutable historical audit archive. It represents users who are currently under an active kickout.
- If an active kickout expires, its record should no longer be shown.
- Only Room Owner can tap Unkick.
- Admin cannot Unkick.
- If Room Owner taps Unkick, that user's entry and all kick-related information for that active restriction disappear from Kickout List.
- Kickout List itself cannot be manually cleared as a whole.

Data model recommendation:
RoomKickRecord {
  roomId
  targetUserId
  targetUserName
  kickedByUserId
  kickedByUserName
  kickedAt
  durationType // 2h | 12h | 48h | permanent
  expiresAt?  // null for permanent
  status      // active | expired | revoked
}

The backend should be authoritative for the active kickout state so reconnect/reinstall does not incorrectly restore or lose restrictions.

## 14. Member/user action sheet — LOCKED AT INTERACTION-ENTRY LEVEL

Entry rule:
- Kick/Block controls do not live in Room Settings.
- The Owner/Admin first taps a user's ID, avatar, occupied seat, or user card.
- That opens the user-specific action sheet.
- Only then are moderation actions such as Kick Out / Block exposed.

User action family:
- profile.
- follow/unfollow.
- private message.
- invite to mic.
- remove from mic.
- mute/ban mic.
- kick from room.
- room blacklist / block where applicable.
- user blacklist where applicable.
- report.

Visibility depends on current role and the target user.

Admin-visible moderation is intentionally limited:
- Kick Out user.
- Invite user to seat / mic.
- Accept or reject Apply Mic requests.
- Remove user from seat / send user down from mic.
- Seat lock/unlock.
- Seat mute/unmute.
- Directly take an empty seat / go on mic without Apply Mic.

Admin must not receive room-wide Settings controls or Kickout List/Unkick controls.

## 14A. Room Owner / Admin permission matrix — LOCKED

| Capability | Owner | Admin | Normal User |
|---|---:|---:|---:|
| Open/change Room Settings | YES | NO | NO |
| Edit room DP/name/description/member list | YES | NO | NO |
| Change Mic Mode / seat count | YES | NO | NO |
| Change Seat Design | YES | NO | NO |
| Change Room Theme / Background | YES | NO | NO |
| View Room Level / Kickout List | YES | NO | NO |
| Unkick active kickout | YES | NO | NO |
| Kick Out user | YES | YES | NO |
| Invite user to seat / mic | YES | YES | NO |
| Accept/reject Apply Mic request | YES | YES | NO |
| Remove another user from seat | YES | YES | NO |
| Lock / unlock seat | YES | YES | NO |
| Mute / unmute seat | YES | YES | NO |
| Directly take empty seat / go on mic without Apply Mic | YES | YES | ONLY WHEN FREE MIC |
| Apply Mic request in Apply Mic mode | NOT REQUIRED | NOT REQUIRED | REQUIRED |
| Change own self-scoped settings | YES | YES | YES |
| Personal Block / Unblock another user | YES | YES | YES |
| Remove user from own Blocklist | YES | YES | YES |

This matrix is authoritative for Tinni Star unless the owner later changes it.

## 14B. Normal user room controls — LOCKED

A normal user entering someone else's room receives only self-scoped room controls.

Normal-user rule:
- Any room setting shown while a user is inside SOMEONE ELSE'S room applies only to that user's own experience/session.
- Those controls must never modify that other room's owner-level configuration.
- To change the user's own room configuration, the user must enter/open THEIR OWN room and use Room Settings there.
- A normal user cannot change room-wide settings.
- A normal user cannot change another user's seat/mic state.
- A normal user cannot lock/unlock seats for others.
- A normal user cannot mute/unmute seats for others.
- A normal user cannot approve/reject Apply Mic requests.
- A normal user cannot invite other users to mic as a moderation action.
- A normal user cannot kickout or unkick users.
- A normal user cannot open the room Kickout List.
- A normal user cannot edit Room Information, Seat Design, Mic Mode, Room Theme/Background, or other Owner-only settings.

Examples of normal-user self-scoped controls may include:
- leave/minimize room
- self mute/unmute where permitted
- apply for mic / cancel own request
- go to seat directly when Free Mic permits
- leave own seat
- gift/chat/member/profile interactions
- personal audio/effect/display preferences shown in the room UI; effect toggles apply only to that user and never globally to the room

### Context rule: own room vs someone else's room — LOCKED
- Inside another user's room: visible personal settings are self-scoped only.
- Inside the user's own room: Owner-level Room Settings become available.
- A user's own Room Settings are not editable remotely from someone else's room.

### Blocklist navigation and UI — LOCKED

Exact navigation:
Bottom navigation > Mine / Profile
→ Setting
→ Blacklist

Mine/Profile screen:
- Contains a Setting entry.
- Setting opens the account/user settings screen.

Setting screen includes:
- Message notification
- Bind account
- Language settings
- About
- Feedback
- Privacy statement
- Sign out

Blacklist screen:
- Shows currently blocked users.
- Each row shows the blocked user's avatar/DP and display name on the LEFT.
- Each row shows a RIGHT-SIDE action button labeled "Move out".
- "Move out" removes that user from the Blacklist and therefore performs Unblock.
- After successful Move out/Unblock, that user must disappear from the Blacklist.
- If no blocked users remain, the list shows its empty/completed state.

This Blacklist is the same personal block state used by Block/Unblock on another user's profile/action surface.

### Personal Block / Unblock — LOCKED

Blocking another user is a personal social/privacy action, not a room-wide moderation action.

Block flow:
- User opens another user's ID/profile/action surface.
- User selects Block.
- The same action location changes to Unblock for that blocked user.

Unblock flow:
- User can unblock from the same user ID/profile/action surface where Block was originally performed.
- User can also open their own profile/account Blocklist and remove that blocked user from the Blocklist.
- Both paths must update the same underlying personal block state.

### Asymmetric block behavior — LOCKED

Example:
User A blocks User B.

After A blocks B:
- B CANNOT enter A's room.
- B CANNOT send a direct message to A.
- A CANNOT send a direct message to B.
- A CAN still enter B's room.
- The room-entry restriction applies to the blocked user trying to enter the blocker's room.
- The blocker is not automatically prevented from entering the blocked user's room.

Therefore:
- Messaging restriction is mutual while the block is active.
- Room-entry restriction is directional:
  blockedUser -> blocker's room = DENIED
  blocker -> blockedUser's room = ALLOWED

Unblock:
- Restores direct messaging eligibility according to the normal social/message rules.
- Restores the previously blocked user's ability to enter the blocker's room unless another independent room restriction exists.

Important distinction:
- Personal Block does NOT equal Room Kickout.
- Personal Block belongs to the acting user's own social/privacy state.
- Room Kickout belongs to Owner/Admin moderation state for that specific room.
- Personal Block affects access to the blocker's owned room plus mutual direct messaging.
- Room Kickout affects the target room only for the selected kick duration.

Recommended model:
UserBlockRelation {
  ownerUserId      // blocker
  blockedUserId
  blockedAt
  status // blocked | unblocked
}

Access rule:
canEnterRoom(viewerId, roomOwnerId):
  deny if UserBlockRelation(ownerUserId=roomOwnerId, blockedUserId=viewerId) is active

Direct-message rule:
canDirectMessage(a, b):
  deny if either active relation A->B or B->A exists

The same relation must drive:
1. Block/Unblock on the target user's profile/action sheet.
2. The user's own Blocklist screen at Mine/Profile > Setting > Blacklist, where "Move out" performs Unblock.
3. Blocked-user admission check for the blocker's owned room.
4. Direct-message eligibility.

## 15. Gifts — MERGED FROM YOHOO

Gift panel:
catalog
→ receiver selector
→ one/multiple receivers
→ quantity/combo
→ server validation
→ wallet transaction
→ room gift event
→ effect queue

Must support:
- categories.
- multi-recipient selector.
- horizontal/swipe user recipient row.
- quantity/combo.
- backpack/inventory.
- balance.
- insufficient-balance flow.
- full-screen/standard/banner effects.
- effect queue priorities.

Economy rule:
Backend is authoritative. Client UI never creates final balance truth.

## 16. Effect/identity layer — CLEAR ARCHITECTURALLY

Effects:
- SVGA.
- PAG.
- MP4.
- GIF.
- entry effects.
- gift effects.
- banner/rank notices.
- VIP/Noble identity.
- user frames.
- room theme.

Effect playback must be separate from financial transaction logic.

## 16A. Personal Effect Settings — LOCKED

Effect visibility/playback preferences are USER-SCOPED, not room-scoped.

Rule:
- Every user controls effects only for themself.
- If Room Owner turns an effect off, it is disabled only for the Owner's own view/device/session.
- Other users in the same room continue to see/play that effect according to their own personal settings.
- Room Owner cannot globally disable another user's effect playback through this personal Effects setting.
- Admin also controls effects only for themself.
- Normal users control effects only for themself.

Examples:
- User A disables gift effects → User A does not see those selected effects.
- User B in the same room still sees them if B has them enabled.
- Owner disables entry effects for self → other users still see entry effects unless they independently disable them.

Effect preferences should be stored per user/profile:
UserEffectPreferences {
  userId
  giftEffectsEnabled
  entryEffectsEnabled
  vipEffectsEnabled
  roomAnimationsEnabled
  otherEffectCategories...
}

Effect events are still broadcast/received normally; each client decides locally whether to render them based on that user's own preferences.

Important:
- Personal effect filtering must not alter gift payment, gift delivery, room state, rank, VIP state, or other users' rendering.
- This is a presentation preference only.


### Room 4-box Effects panel — LOCKED

The room 4-box / grid tools panel includes an **Effects** entry.
Opening Effects shows independent self-scoped toggles for:
- Gift Effects
- Lucky Gift Effect
- Gift Sound
- Gift Fly-in
- Car Effects
- Gift Bubble
- Rocket Draw Notice

Rules:
- Each option can be enabled/disabled independently.
- These controls affect only the current user's room-view/audio experience; they do not silently change another user's settings.
- The existing master Block Effects / Allow Effects control remains available as the overall visual-effect master switch.
- Hide Notice / Show Notice remains available as the general room-notice master switch.
- Gift, Lucky Gift, car/vehicle entry, gift bubble, and rocket effect playback must respect the corresponding toggle when their effect event is identified.
- Gift sound playback must respect Gift Sound and the room sound master control.



### Reference-style room toolbar / 4-box — LOCKED

The room 4-box must include these primary entries in this order:
1. Room Type
2. Cover
3. Music
4. Blacklist
5. Effects
6. Feedback
7. Lock / Unlock

Room Type opens a 3-tab panel:
- **Mic Types** — opens the Tinni seat-count/layout selector for the supported 8–42 seat system.
- **Mic Theme** — owner can select the room's persisted mic/seat visual theme.
- **Setting** — room mic-mode and related room-type controls.

Mic Theme built-in choices:
- Royal Gold
- Neon Blue
- Rose Glow

Cover:
- `Cover` is the **single 4-box entry** for room background/theme selection.
- It opens the Room Cover / Theme selector, including built-in and eligible custom/panel themes.
- The older separate `Room Theme` 4-box tile is removed to avoid duplication.

Blacklist:
- Opens the room blacklist list.
- Room owner can remove IDs from the blacklist.

Effects:
- Opens the Effects panel; the granular effect toggles stay inside this panel.
- Overall visual-effects and room-notice master switches also stay inside Effects, not as separate 4-box tiles.

Feedback:
- Opens the room feedback/report surface.

Room Lock — LATEST LOCKED RULE:
- Room Lock exists **only inside Room Type → Setting → Room Lock**.
- Do not show a separate Lock / Unlock tile in the 4-box/tools grid.
- Do not duplicate Room Lock in Room Setup or legacy Room Settings.
- Password is exactly **5 numeric digits**; any 00000–99999 value is valid, with existing failed-attempt protection preserved.
- VIP is **not required**; the room owner can lock their own room.
- Admin cannot change the room password/lock unless a future explicit owner rule says otherwise.

Top room bar:
- Share icon is visible beside the existing room actions.
- Power/exit icon remains visible and keeps the existing Minimize / Exit behavior.

Tinni-specific extra room tools may remain after these primary reference-style entries.



### Room Game entry placement — LOCKED

- **Game is not a 4-box tile.**
- The room shows a dedicated floating **purple game-controller** entry on the right side of the room, above the bottom room controls, matching the reference placement.
- Tapping the floating controller opens **Game Center**.
- Tinni Star keeps its own games inside Game Center; moving the entry does not remove Fruit Jackpot or Fruit Party.
- When a Tinni game panel is actively open, the floating controller entry is hidden so it does not cover gameplay.
- The floating Game icon uses the same purple/pink controller visual family as the reference video, while the rest of the room keeps Tinni Star branding.



### Reference room seat / floating game / room-info interaction — LOCKED

Tinni Star must match the approved reference interaction for these room surfaces while keeping Tinni's own seat-count and game rules.

**Seat visual**
- Unlocked empty seat: circular double-ring mic seat with purple glow and a white seat/chair symbol.
- Locked empty seat: the circular mic seat is replaced by a standalone gold lock icon.
- Under each seat show `No.<seat number>` for empty seats; occupied seats show the user's display name.
- Under the name/number show the small purple heart-count pill.
- Occupied seats show the user's DP/frame in the circular seat.
- Existing Tinni mute state remains functional; muted seats may additionally show the small red mic-off badge.
- Tinni seat capacities remain 8–42 and the approved row-distribution rule is unchanged.

**Seat tap — LATEST LOCKED RULE**
- Do **not** restore the old `Mic up / Lock mic / Confirm` panel.
- Owner/Admin normal tap on an empty seat opens the current Tinni controls:
  - `Seat Lock / Seat Unlock`
  - `Seat Mute / Seat Unmute`
  - `Take Seat`
- Owner/Admin tap on an occupied controllable seat uses the current moderation controls without reintroducing a second legacy panel.
- Self DP/seat tap shows the current self actions including Down / Leave Seat as defined by the latest room UI.
- Owner seat is immune to Admin control; Admin cannot control another Admin.
- Owner can control Admin/member seats.
- No seat may auto-open, auto-lock, auto-mute or auto-unmute.

**Floating Game + Rocket**
- Game remains outside the room 4-box.
- Right-side floating stack shows a small Rocket icon above a short progress indicator and the purple/pink Game controller below it.
- Game controller opens `Game Center`.
- Game Center shows a room/profile progress card, coin balance, an `All Games` grid, and Tinni's Fruit Jackpot / Fruit Party entries.
- Fruit Jackpot and Fruit Party active overlays use approximately **50% of screen height** per the latest approved room layout.
- Rocket opens the reference-style rocket event panel with a large rocket, milestone row, 0–100% progress area, rewards grid, Record/Help affordances, reset timer and close control.
- The floating stack hides while a Tinni game panel is actively open.

**Room-name tap**
- Tapping the room name opens the reference-style room info sheet showing:
  - room DP
  - room name
  - room ID
  - owner-only Room Setup button
  - Members count and entry
  - Notice
  - owner DP/name/ID
  - copy-owner-ID action
  - owner country flag where available
- Members opens `Room Members` with `Administrator` and `Members` tabs.

**Room Setup**
- Owner-only full page titled `Room Setup`.
- Editable room DP, Room Name and Notice.
- Room Name max 24 characters.
- Notice max 24 characters.
- Room Setup does **not** contain Room Lock / Public / Private controls.
- `Block List` opens the room blacklist.
- `Save` persists supported room fields through the backend.


## 17. VIP / Noble / Identity — CLEAR AT FEATURE LEVEL

- VIP levels.
- Noble levels.
- privileges.
- entry effects.
- nameplate.
- medals.
- headwear.
- vehicles.
- good-number/UID effects.
- user/seat frames.
- room halo/wave identity.

Exact entitlement/pricing/priority order still needs confirmation.

## 18. CP — CLEAR AT FEATURE LEVEL

NO_RELATION
→ COURTING
→ ACCEPT/REFUSE
→ CP_ACTIVE
→ intimacy/levels/rank/memories/ring/anniversary
→ disconnect flow

Still needs exact UI/runtime videos for:
- CP home.
- courting.
- ring store.
- heartbeat.
- disconnect dialogs.
- ranking cards.

## 19. Family — CLEAR AT FEATURE LEVEL

Family:
- create/join.
- Head.
- Deputy.
- Assistant.
- Member.
- family room.
- members.
- roles.
- tasks.
- sign-in.
- rank.
- lottery.
- wallet/records.
- family gifts/experience.

Exact permission matrix and UI still need confirmation.

## 20. KTV — CLEAR AT FEATURE LEVEL

- KTV mode.
- song search.
- local songs.
- queue.
- lead singer.
- chorus.
- cut song.
- delete song.
- give up singing.
- music + voice mix through RTC/media layer.

Exact singing sync, seat dependency and queue-control UI remain VIDEO NEEDED.

## 21. Games — CLEAR AT FRAMEWORK LEVEL

YoHoo-confirmed families:
- Lucky 777.
- Blackjack.
- Gift Draw.
- Guessing.
- settlement.
- rank/reward.
- Game Noble.

Tinni Star can additionally add Ludo/UNO as separate clean game modules.

Game economy/state must be server-authoritative.

## 22. Wallet / Store / Recharge — CLEAR ARCHITECTURALLY

- coin balance.
- diamond balance.
- transaction history.
- recharge.
- store.
- inventory.
- reward.
- identity/cosmetic purchases.
- Google Play Billing adapter for production.

## 23. Social / Message / Dynamic — CLEAR AT FEATURE LEVEL

- direct messages.
- friends.
- follow.
- blacklist / blocklist.
- Blocklist is user-owned personal social state.
- A blocked user can be removed either from that user's profile/action surface via Unblock or from the acting user's own Blocklist.
- user search.
- room search.
- recent rooms.
- favorites.
- Dynamic/Moments feed.
- like/comment/share.
- publish/review.
- room indicator in social feed.

## 24. Background room — CLEAR ARCHITECTURALLY

Required:
- minimize room.
- continue allowed RTC/media behavior.
- foreground service where Android requires it.
- persistent notification as required.
- audio focus.
- reconnect.
- resync room snapshot after network loss.

Android version/device restrictions must be handled honestly.

## 25. Unified RoomEvent model

Event types:
USER_JOIN
USER_LEAVE
SEAT_CHANGED
MIC_REQUESTED
MIC_APPROVED
MIC_REJECTED
MIC_MUTED
MIC_UNMUTED
USER_KICKED
USER_ROOM_BLACKLISTED
ROOM_INFO_CHANGED
CHAT_MESSAGE
GIFT_SENT
GIFT_COMBO
KTV_QUEUE_CHANGED
SINGING_STARTED
SINGING_STOPPED
GAME_STATE_CHANGED
ADMIN_CHANGED
FRAME_CHANGED
VIP_IDENTITY_CHANGED

## 26. Tinni Star service split

AuthService
DiscoveryService
RoomSession
RoomMembership
SeatManager
MicManager
RoomRolePolicy
RoomModeration
RoomMemberService
RTCAdapter
IMAdapter
GiftService
GiftRecipientSelector
EffectQueue
WalletService
RechargeService
StoreService
VIPService
NobleService
IdentityFrameService
CPService
FamilyService
KTVService
GameService
ActivityService
DynamicFeedService
BackgroundRoomService
ReconnectCoordinator
FeatureFlagService
AnamikaConnector
FunctionPackRuntime

## 27. Anamika / Function Pack boundary

Anamika can later:
- read diagnostics.
- identify active function pack/version.
- submit validated compatible pack.
- trigger rollback after owner approval policy.
- report health/error state.

Hot-updateable data/config examples:
- room rules.
- seat layout rules.
- gift catalog.
- feature flags.
- localization.
- declarative effects/assets.
- UI content/rules where schema permits.

APK/native update still required for:
- compiled Dart/native code.
- AndroidManifest permissions.
- RTC/IM native SDK upgrades.
- signing.
- foreground-service declarations.
- native libraries.

## 28. VIDEO NEEDED — exact behavior still not locked

Highest-priority reference gaps:
1. Exact seat-design catalog: every available design, thumbnail, animation and visual difference. Owner selection from Room Settings is now locked.
2. Occupied-seat layering: avatar, frame, name, mic state, owner/admin badge, VIP/Noble badge, speaking animation and lock icon order.
3. Individual user-frame system: where frame comes from, how selected/equipped, static vs animated, VIP/purchased/role priority.
4. Owner seat behavior: whether Owner has a fixed seat, special frame, crown/badge, auto-seat, and what happens when Owner leaves mic but stays in room.
5. Admin behavior: how Owner appoints/removes Admin, admin count limit, admin badge/frame, exact controls visible to Admin.
6. Room member list and member card: exact tabs, online/on-mic sorting, action menu and profile popup.
7. Remaining Room Settings options and their exact ordering. Room Information, Mic Mode, Seat Design, Room Theme/Background, Room Level and Kickout List behavior are now substantially locked.
8. Apply-Mic request UI details still needed: exact queue screen, request popup, timeout behavior and approval/rejection animation. Core Free Mic vs Apply Mic permissions are locked.
9. Seat lock/move UX: long-press/tap behavior, move user between seats, locked-seat appearance, reserved-seat behavior.
10. Gift panel exact interaction: recipient selection, multi-select, combo window, quantity selector, backpack, gift categories and effect preview.
11. Room entry/join effects: user entry banner/vehicle/animal/VIP frame sequence and priority when many users enter.
12. Room chat message types: normal text, system messages, gift messages, join notices, VIP notices, admin notices and clickable user names.
13. KTV exact UI: song queue, singer seat, chorus, lyrics, scoring, cut song and mic ownership.
14. Game launch inside room: overlay/full-screen/minigame panel, how room audio continues, settlement/reward UI.
15. CP screens: courting, CP home, ring, heartbeat, anniversary, disconnect and CP rank.
16. Family screens: home, member roles, family room, tasks/sign-in, rank, wallet and lottery.
17. VIP/Noble screens: exact level navigation, privilege detail, purchase/upgrade, equipped identity assets and room effects.
18. Wallet/recharge/store screens: exact coin product cards, purchase confirmation, inventory/equip flow and history.
19. Profile/user popup: all badges, frames, follow/friend/chat/report and owned-room/CP/family fields.
20. Background/minimize behavior: what remains visible/active when app goes background and exact return-to-room UI.

## 29. Confidence

Locked:
- main navigation split.
- Party top tabs.
- Party > Mine structure.
- creator = room Owner.
- seat-count row ranges.
- balanced row distribution.
- full-width seat rows.
- New = last 15 days.
- bottom Mine profile separation.
- core room/gift/chat/mic/service architecture.

Clear at feature level but not exact UI:
- moderation.
- VIP/Noble.
- CP.
- Family.
- KTV.
- Games.
- store/recharge.
- activities/ranks.
- member cards.
- effects/identity layers.

Still video-dependent:
- exact control placement.
- exact seat-design visuals/assets.
- exact frame compositing.
- exact remaining Room Settings option list. Owner/Admin/Normal User permission boundary is now substantially locked; personal Block/Unblock is separated from room Kickout moderation, and Effects settings are confirmed as per-user only.
- exact dialogs/animations.
- exact state transitions visible to users.


## Party reference video — LOCKED corrections

The latest Party reference video clarifies the three marked Party-page areas and supersedes the earlier incorrect Tinni Party UI in those positions.

### 1. Top-right Ranking entry
- Party top navigation remains: Mine / Party / Events / Country.
- To the right of these tabs is a Ranking/Leaderboard icon.
- Search remains beside it.
- The old Tinni-specific VIP/Create-Room app-bar controls must not occupy this reference position.
- Tapping Ranking opens the Ranking Center.

Ranking Center:
- top categories: Room / Send gifts / Charm / Game.
- default/reference view may open on Send gifts.
- period switcher: Daily / Weekly / Monthly list.
- visually emphasizes Top 1–3, then lower ranked entries.
- bottom/current-user row shows the user's own rank/score state.
- Room ranking entries can navigate to the corresponding room.

### 2. Large promotional/event banner
- The Party page has a large swipeable promotional banner directly below the top navigation.
- It is not a permanent static "Weekly CP" panel.
- Reference examples shown in video include Weekly Star, Lucky Draw, and The Great Navigator.
- Tinni Star must use original/licensed Tinni artwork and backend-configured promotions, not copied proprietary art.
- Banner tap opens the matching event/ranking/game destination.
- Promo content should be server/Owner-Panel configurable in production.

The reference video also shows a Weekly Sign-in flow:
- seven-day reward ladder.
- Sign in action.
- post-sign-in confirmation/reward.
- exact coin/reward amounts are backend/configuration data and must not be hard-coded from the reference.

### 3. Ranking shortcut row
Directly under the promo banner are three ranking shortcuts:
- Room
- CP Ranking
- Family

Correction:
- the first shortcut is Room, not Game.
- Game remains available through its own game/event surfaces.

Room shortcut:
- opens Ranking Center on the Room category.

CP Ranking shortcut:
- opens the dedicated CP Ranking screen.
- top sections: Ranking List / True Love Challenge / Reward.
- Ranking List includes CP Ranking / CP Square.
- shows top couples and the current user's "Not on the list" / Bind with CP state where applicable.

Family shortcut:
- opens the Family feature/ranking surface.


### Family ranking shortcut — CORRECTED
- The Party shortcut labeled Family must open a dedicated Family Ranking screen, not a generic Feature Center.
- Family Ranking is a distinct ranking destination.
- Tinni Star must support ranked family entries, Top 1–3 emphasis, lower ranked families, and the current user's/my-family ranking row.
- Ranking period switching should be data-driven/configurable (for example Daily / Weekly / Monthly) until the exact reference behavior is confirmed.
- Exact Family Ranking visual layout/tabs were not opened in the supplied reference video, so do not claim pixel parity yet.
- Once a Family Ranking reference video is supplied, update this section and UI without changing the dedicated navigation contract.

### Party list below shortcuts
- Popular / New selector remains below the three ranking shortcuts.
- Popular shows recommended/high-activity rooms.
- New follows the locked 15-day room-created rule.
- top three room cards are visually emphasized, followed by the normal room list.



## Family module — LOCKED FROM REFERENCE VIDEO

The supplied Family video confirms the Family shortcut opens a dedicated family ecosystem, not a generic feature hub.

### Family Ranking
- Title/reference concept: Top Families of the Month.
- Back navigation.
- Scope/filter control such as Local/Global.
- Ranked family rows contain:
  - numeric rank
  - family avatar/emblem
  - family name
  - country/flag
  - family tag/badge
  - family contribution/score
- Bottom actions when user has not joined a family:
  - Create
  - Join
- Selecting a family opens that family's detail/home page.
- Create opens a family creation flow.
- Join opens a family selection/join flow.
- Exact backend ranking score formula remains server/config driven.

### Family Home
Top tabs:
- Home
- Trends

Home contains:
- family announcement
- Top members of the family
  - Charm Star
  - Wealth Star
  - Active Star
- horizontally browsable Member list
- Family room card/list
- Join action when viewing a family the user has not joined

Family announcement:
- family management can update announcement according to family role policy.
- announcement is family-wide data, not personal-only state.

### Trends
- Family activity/history feed.
- Includes meaningful family events such as creation, joins, role changes, announcement updates, task/reward activity.
- Backend should provide persistent family event history in production.

### Member Manage
Top tabs:
- Member
- Admin

Member tab row contains:
- member avatar
- member name
- family role/badge
- contribution/value
- last-active status such as Today or Logged in N days ago

Admin tab:
- Family Leader shown prominently.
- Deputy Family Leader area.
- Deputy/admin positions are represented as member slots.
- Empty available slots show Add.
- Unavailable slots show Locked.
- Slot availability can depend on family level/policy.
- Family leader can appoint/remove deputy/admin roles according to server-authoritative role policy.

### Family Room
- Family home links to a dedicated family voice room.
- Family room uses the same core Voice Room engine and role/mic/seat system rather than duplicating RTC logic.
- Family membership/role may add family-specific badges and permissions, but Voice Room state remains shared architecture.

### Family Create / Join
Create requires at minimum:
- Family Name
- Family Tag
- creator becomes Family Leader

Join:
- user chooses an available family
- user joins as Member unless family policy requires approval
- exact approval/eligibility policy remains backend-configurable until further reference confirms it



## Family Tag / Family Level visual system — LOCKED

Family identity is visible on the user profile/ID and inside Family pages.

User profile / ID:
- If the user belongs to a Family, show the Family Tag near the UID/profile identity area.
- Family Tag shows the family tag/name identity plus Family Level.
- Family Tag is separate from VIP/Noble badges.
- Opening Family from Mine goes to Family Home when the user already belongs to a family; otherwise it goes to Family Ranking/Join.

Family Level:
- Family has a persistent numeric level.
- Family experience/contribution increases the level using backend-configured progression.
- Family level changes the Family's visual identity:
  - Family page background/theme tier
  - Family Tag color/style
  - family badges/ornaments where configured
- Exact production level thresholds and color table must be data-driven and editable from Owner Panel/backend configuration.
- Use original/licensed Tinni family visual assets, not copied proprietary artwork.

Family pages:
- Member list, Family Leader/Deputy management, announcement, top members, Family Room and Trends appear after opening the Family.
- Member rows can show family tag/level identity together with role.

## Owner/Admin seat-tap behavior — LOCKED FIX

When the room is in Apply Mic mode:
- Normal user tapping an empty seat submits Apply Mic and does not occupy it until Owner/Admin approval.
- Room Owner NEVER needs Apply Mic permission for themself.
- Room Admin NEVER needs Apply Mic permission for themself.

When Owner/Admin taps an empty seat, open the seat control sheet immediately with:
- Seat Lock / Seat Unlock
- Seat Mute / Seat Unmute
- Take Seat

Take Seat:
- directly occupies the selected empty seat;
- does not create an Apply Mic request;
- works even when Mic Mode is Apply Mic.

Permission split:
- Owner can change room-wide settings.
- Admin can moderate seat/mic state and use Take Seat.
- Admin cannot change room-wide settings, open Kickout List, or Unkick.


---

# PART II — IMPLEMENTATION CONTRACT

## A. Non-negotiable product rules

1. Every visible button/control must perform a real action. No dead tap targets, fake toggles, or placeholder-only production controls.
2. Room creator becomes that room's Owner automatically.
3. Room-wide Owner settings and personal/self-scoped settings must never be mixed.
4. Admin is a limited moderator, not a room manager.
5. Block, Kickout, Seat/Mic moderation, and personal Effects settings are four distinct systems.
6. Economy, kickout state, room roles, entitlements, and purchases are server-authoritative in production.
7. RTC carries live audio. It must not be treated as permanent room metadata truth.
8. Reconnect must reload/resync authoritative room state.
9. Personal effect filtering is local/personal presentation logic only.
10. Native/core changes require an APK update. Function Packs may only update explicitly supported safe/config/data capabilities.
11. Preserve old working functions when updating a feature. Avoid duplicate registrations and duplicate Function Pack installations.
12. Production signing must remain stable so app updates install over previous versions.

## B. Recommended client architecture

Target client:
- Flutter/Dart.
- Android min SDK 24 unless product requirements change.
- Target current supported Android SDK used by the project.
- Responsive mobile-first portrait UI.
- Primary Tinni Star visual language: deep black/charcoal + rich gold. Reference screenshots may be used for structure but the shipped Tinni Star visual identity should be original.

Layering:

UI / Screens
→ Controllers / State
→ Domain Services
→ Repository / API adapters
→ RTC / IM / Billing / Storage adapters
→ Backend

Core domain modules:
- AuthService
- SessionService
- DiscoveryService
- RoomSession
- RoomMembership
- RoomRolePolicy
- RoomSettingsService
- RoomModeration
- RoomMemberService
- SeatManager
- MicManager
- RTCAdapter
- IMAdapter
- GiftService
- GiftRecipientSelector
- EffectQueue
- UserEffectPreferenceService
- WalletService
- RechargeService
- StoreService
- VIPService
- NobleService
- IdentityFrameService
- CPService
- FamilyService
- KTVService
- GameService
- ActivityService
- DynamicFeedService
- SocialGraphService
- BlockService
- BackgroundRoomService
- ReconnectCoordinator
- FeatureFlagService
- AnalyticsService
- AnamikaConnector
- FunctionPackRuntime

## C. Main navigation contract

Bottom navigation:
1. Party
2. Discover
3. Message
4. Mine

Party contains top swipe/tap pages:
1. Mine — room-focused
2. Party
3. Events
4. Country

Critical:
- Party > Mine is NOT profile.
- Bottom Mine IS profile/account.

## D. Core screen inventory

Minimum production screens/modules:
- Splash / startup
- Login methods
- Phone/auth verification
- Google/account binding as configured
- Profile setup
- Country/region selection
- Party shell
- Party > Mine
- Party > Party
- Party > Events
- Party > Country
- Search
- Discover
- Message inbox
- Private chat
- Bottom Mine/Profile
- Edit Profile
- Setting
- Blacklist
- Room create
- Voice Room
- Room members
- Room Information/Edit
- Mic Mode
- Seat Design
- Theme/Background
- Room Level
- Kickout List
- Apply Mic queue
- User profile/action sheet
- Gift panel
- Gift recipient selector
- Backpack/inventory
- Wallet/recharge/store
- VIP/Noble/Identity
- CP
- Family
- KTV
- Games
- Rank/Activity
- Feedback/About/Privacy

## E. Room creation contract

CREATE_ROOM(currentUser):
1. Validate authenticated user.
2. Create room metadata.
3. Set room.ownerId = currentUser.id.
4. Persist createdAt.
5. Assign Owner role.
6. Create/default seat configuration.
7. Create/default mic mode.
8. Create/default room theme/background.
9. Publish room snapshot.
10. Add room to Party > Mine > My room.

The Owner role is derived from room.ownerId, not from client-only local state.

## F. New-room discovery rule

Party > New:
- Include only rooms whose createdAt is within the last 15 days.
- Sort newest first unless later specified.
- A room older than 15 days must no longer appear in New.

## G. Seat-count algorithm

Supported counts:
8, 9, 10,
12–18,
19–28,
29–35,
36–42.

11 is not selectable. Legacy/invalid 11 normalizes to 12.

Rows:
- 8–10 → 2
- 12–18 → 3
- 19–28 → 4
- 29–35 → 5
- 36–42 → 6

Balanced distribution:
base = seatCount ~/ rows
extra = seatCount % rows
first extra rows receive one additional seat.

Examples:
- 8 → 4+4
- 9 → 5+4
- 10 → 5+5
- 12 → 4+4+4
- 18 → 6+6+6
- 19 → 5+5+5+4
- 28 → 7+7+7+7
- 29 → 6+6+6+6+5
- 35 → 7+7+7+7+7
- 36 → 6+6+6+6+6+6
- 42 → 7+7+7+7+7+7

UI:
- Rows span the full usable width.
- Seat diameter shrinks as columns increase.
- Seat area must not consume the full room screen.
- Keep room chat and typing controls usable.
- Target at least about four chat/message lines visible on typical phone layouts.

## H. Seat state model

Seat:
- FREE
- LOCKED
- MUTED_BY_ROOM
- OCCUPIED
- OCCUPIED_MUTED where applicable

User:
- AUDIENCE
- MIC_REQUESTED
- ON_SEAT
- SELF_MUTED
- ROOM_MUTED
- REMOVED_FROM_SEAT

Seat IDs remain stable across UI redraws and reconnect.

## I. Mic Mode contract

### Free Mic
Normal user:
- may tap an empty, unlocked seat;
- may take it directly;
- does not need approval.

### Apply Mic
Normal user:
- cannot directly take an empty seat;
- submits Apply Mic;
- request is visible to Owner/Admin;
- Owner/Admin can accept or reject;
- accepted user moves to a seat.

### Owner/Admin
- never need to Apply Mic for themselves;
- can directly take an empty seat;
- empty-seat action exposes:
  - Seat Lock/Unlock
  - Seat Mute/Unmute
  - Go to Seat

Owner/Admin can also:
- invite a user to seat/mic;
- accept/reject Apply Mic;
- remove a user from seat.

## J. Role permission matrix

| Capability | Owner | Admin | Normal User |
|---|---:|---:|---:|
| Change room-wide settings | YES | NO | NO |
| Edit room DP/name/description/member list | YES | NO | NO |
| Change Mic Mode / seat count | YES | NO | NO |
| Change Seat Design | YES | NO | NO |
| Change Theme/Background | YES | NO | NO |
| View Room Level | YES | NO | NO |
| View Kickout List | YES | NO | NO |
| Unkick | YES | NO | NO |
| Kick Out user | YES | YES | NO |
| Invite user to seat/mic | YES | YES | NO |
| Accept/reject Apply Mic | YES | YES | NO |
| Remove user from seat | YES | YES | NO |
| Seat Lock/Unlock | YES | YES | NO |
| Seat Mute/Unmute | YES | YES | NO |
| Directly take empty seat | YES | YES | FREE MIC only |
| Apply in Apply Mic mode | NOT REQUIRED | NOT REQUIRED | REQUIRED |
| Personal Block/Unblock | YES | YES | YES |
| Personal Effects settings | SELF ONLY | SELF ONLY | SELF ONLY |

Permission enforcement must exist on backend/server for authoritative actions.

## K. Room Settings contract

Entry:
- Room toolbar 4-box/grid icon.
- This is the Room Settings entry point.

Owner room-wide settings currently locked:
- Room Information
- Mic Mode
- Seat count
- Seat Design
- Room Theme/Background
- Room Level
- Kickout List
- other later-confirmed owner-only items

Do NOT expose Kick Out or personal Block as Room Settings actions.

Normal user visiting another room may see personal settings controls, but those affect only the current user. To change owner-level settings for their own room, the user must open their own room.

## L. Room Information/Edit

Owner can change:
- Room DP/avatar
- Room Name
- Room Description
- Room Member List

Room Member List:
- Owner can remove members through this management view.
- This is distinct from immediate Kick Out moderation.

## M. Seat Design

- App ships with selectable seat-design assets/styles.
- Owner chooses one for the room.
- Selection persists per room.
- Seat design changes rendering only.
- State/permissions/mic logic are shared across designs.
- Do not duplicate SeatManager per design.

## N. Room Theme / Background

App includes built-in room wallpapers/backgrounds.

Custom upload:
- Owner may upload a custom background where allowed.
- Paid with coins.
- Duration options:
  - 7 days
  - 10 days
  - 15 days
  - 30 days
  - Permanent
- Exact coin prices remain configuration/backend data.
- Expiring background entitlement must revert/fallback when expired.

Suggested entity:
RoomBackgroundEntitlement:
- id
- roomId
- backgroundId
- sourceType: built_in | owner_upload
- purchasedByUserId
- coinPrice
- activatedAt
- expiresAt nullable
- status

## O. Kickout lifecycle

Immediate Kick Out is initiated from the target user's ID/avatar/seat/user-action surface.

Kick duration choices:
- 2 hours
- 12 hours
- 48 hours
- Permanent

Owner and Admin may Kick Out.

Active Kickout List:
- accessible only by Room Owner;
- Admin cannot view it;
- Normal user cannot view it.

Each active row:
LEFT:
- kicked user's name
- kicked user's ID
- kick date
- kick time
- moderator/admin name
- moderator/admin ID

RIGHT:
- Unkick button

Only Owner can Unkick.

List semantics:
- Shows current active kickouts only.
- Expired kickout disappears.
- Unkicked user disappears.
- List cannot be manually bulk-cleared.
- Backend maintains authoritative active restriction state.

Suggested entity:
RoomKickRecord:
- id
- roomId
- targetUserId
- targetUserNameSnapshot
- kickedByUserId
- kickedByUserNameSnapshot
- kickedAt
- durationType
- expiresAt nullable
- status: active | expired | revoked

Admission rule must check active kickout before joining.

## P. Personal Block / Unblock

Personal social block is NOT room Kickout.

Entry:
- target user's profile/action surface → Block.
- If already blocked, same location shows Unblock.

Alternative Unblock:
Mine/Profile → Setting → Blacklist → target row → Move out.

Blacklist row:
LEFT:
- avatar
- display name
RIGHT:
- Move out

Move out = Unblock and row disappears.

### Directional room rule
If A blocks B:
- B cannot enter A's owned room.
- A can still enter B's room.

### Mutual messaging rule
If either A blocks B or B blocks A:
- A cannot DM B.
- B cannot DM A.

Unblock restores normal eligibility unless another independent restriction exists.

Suggested entity:
UserBlockRelation:
- blockerUserId
- blockedUserId
- blockedAt
- status

Room admission:
deny if active block exists where roomOwnerId is blocker and joiningUserId is blocked.

DM permission:
deny if active relation exists in either direction.

## Q. Normal-user settings scope

Inside someone else's room:
- settings shown to a normal user are self-scoped.
- user cannot modify owner settings.
- user cannot modify other users' seat/mic state.

To change their own room:
- user opens their own room;
- uses Owner Room Settings there.

## R. Personal Effects settings

Effects preferences are per-user only.

Examples:
- Owner disables Gift Effects → only Owner stops rendering them.
- Other room users continue seeing them according to their own settings.
- Admin/normal user behavior is identical: self only.

Possible preference groups:
- gift effects
- entry effects
- VIP/Noble effects
- room animations
- other effect categories

Incoming effect events still exist. Rendering decision is local/personal.

Never let Effects toggle:
- cancel a paid gift;
- alter balances;
- change room state;
- suppress other users' clients.

## S. Gift transaction contract

Flow:
1. Open Gift panel.
2. Load catalog + balance + inventory.
3. Select gift.
4. Select one or multiple recipients.
5. Recipient avatar row must support horizontal swipe/scroll.
6. Select quantity/combo.
7. Server quotes/validates.
8. If insufficient balance → recharge/store path.
9. On server success → wallet state updates.
10. Emit room GiftEvent.
11. EffectQueue renders according to each user's personal effect preferences.

Backend is the source of financial truth.

Gift effects may use Tinni-owned licensed/original assets in supported engines such as SVGA/PAG/MP4/GIF.

## T. Room event envelope

RoomEvent:
- eventId
- roomId
- sequence/version
- type
- senderId
- targetIds
- timestamp
- payload

Core types:
- USER_JOIN
- USER_LEAVE
- ROOM_INFO_CHANGED
- ADMIN_CHANGED
- SEAT_CHANGED
- MIC_REQUESTED
- MIC_APPROVED
- MIC_REJECTED
- MIC_MUTED
- MIC_UNMUTED
- USER_KICKED
- USER_UNKICKED
- CHAT_MESSAGE
- GIFT_SENT
- GIFT_COMBO
- KTV_QUEUE_CHANGED
- SINGING_STARTED
- SINGING_STOPPED
- GAME_STATE_CHANGED
- FRAME_CHANGED
- VIP_IDENTITY_CHANGED

On reconnect:
- do not replay blindly from stale local state;
- fetch authoritative room snapshot;
- reconcile sequence/version;
- then resume incremental events.

### T.1 Realtime room presence / seat DP delivery — LATEST LOCKED RULE

- Room entry performs one authoritative presence join/snapshot.
- After join, use one authenticated hibernating Durable Object WebSocket for room presence.
- **Do not poll room presence every second.**
- In the healthy realtime path there is **no recurring application-level HTTP heartbeat and no recurring application-level WebSocket keepalive message**.
- Transport health uses protocol-level WebSocket ping only; protocol ping must not be converted back into Worker/DO application messages.
- An actively connected room WebSocket is authoritative proof that the user remains in the room, even if the stored `last_seen` timestamp is old.
- App Directory online state is socket-driven: WebSocket connect marks the room session connected; socket close/error clears it unless a replacement socket for the same user is already active.
- A stale old socket close must never clear a newer replacement connection.
- If realtime disconnects, the client retries with exponential backoff instead of a 2-second infinite reconnect loop.
- HTTP heartbeat is emergency fallback only while realtime is unavailable, currently every **5 minutes**.
- Disconnected room membership keeps a **30-minute recovery grace** so temporary background/network gaps do not immediately remove the user or seat state.
- Android active-room background mode continues to use the existing `START_STICKY` foreground voice-room service.
- Seat take/leave, mic-state change, mute/unmute, lock/unlock, admin/permission change and user join/leave must push immediately through realtime state updates.
- A DP must appear automatically when presence/seat state arrives; tapping the seat must never be required to make the DP appear.
- Keep stable seat identity and stable avatar providers/cache. Never clear a valid DP to blank while applying a state update.
- Reuse the last valid/cached DP until a replacement image is decoded/available.
- Update only the changed seat/member state where possible; avoid timer-driven full-room clear/rebuild cycles.
- On reconnect, reconcile authoritative server state before resuming incremental updates.
- Realtime request budget is a product requirement: new room features must reuse the existing live channel or meaningful user-action requests rather than adding periodic REST polling.
- Normal Android backgrounding must not eject a user from the room merely because the app is no longer foregrounded. Force-stop, device reboot, process death or prolonged network loss are separate failure cases and require reconnect/rejoin recovery rather than false claims of guaranteed uninterrupted execution.

## U. RTC / IM separation

RTC adapter:
- join/leave voice channel
- publish local mic
- mute/unmute local audio
- remote subscription
- music/media mixing
- network callbacks

IM adapter:
- room/group chat
- direct messaging
- presence/events
- custom room event transport where appropriate

Backend:
- roles/permissions
- room metadata
- kickout
- block
- wallet/economy
- gift transaction
- entitlement
- persistence

Do not use IM messages as the sole source of permanent economy truth.

## V. Background/minimized room

Required architecture:
- room may be minimized/restored;
- Android foreground service where required;
- proper microphone/audio permissions;
- persistent notification where platform requires it;
- audio focus handling;
- reconnect handling;
- room state resync on return.

Do not claim background microphone support across all Android/OEM versions until tested on real devices.

## W. Mine / Me / Profile / Setting — REFERENCE VIDEO LOCKED

Bottom **Mine/Me** is the user's personal account surface and is separate from **Party > Mine**.

### W.1 Reference-video visual target

The supplied reference videos are the visual source for the Mine page. Final UI must preserve the same overall composition, order and interaction pattern rather than replacing it with a generic profile page. Match the reference as closely as practical for:

- top DP/name/UID identity block;
- Follow / Fans / Charm statistics row;
- Wallet card;
- VIP and Wealth cards;
- grouped menu rows;
- icon location, chevrons, spacing, row height and card proportions;
- light Mine-page surface with Tinni gold/yellow accents.

Exact functional labels and menu order are product-locked unless the user explicitly changes them.

### W.2 Top identity and stats

Show real account data:

- DP/avatar + equipped profile frame;
- display name;
- country flag;
- public UID;
- user level;
- Family tag + Family level when applicable;
- active identity/VIP indicator;
- **Follow** = real following count;
- **Fans** = real follower count;
- **Charm** = real lifetime eligible gift receiving.

Do not hard-code these counters.

### W.3 Wallet, VIP and Wealth

- **Wallet** shows the real normal-wallet Coin balance and opens the real wallet/recharge surface.
- **VIP** shows current VIP status/level and opens the real VIP page.
- **Wealth level** is calculated from real lifetime eligible gift sending and opens a dedicated Wealth page.
- Wealth level thresholds are data-driven/Owner-Panel configurable.
- Charm and Wealth remain separate: receiving drives Charm; sending drives Wealth.

### W.4 Mine menu exact order

1. Medal of Honor
2. Custom Center
3. Shop
4. Props
5. Reward Records
6. Task
7. Host data
8. Family
9. CP Nest
10. Feedback
11. Setting

Each row opens a real function; no defined row may terminate at a generic placeholder.

### W.5 Function behavior

- **Medal of Honor**: backend-driven user medals with truthful empty state.
- **Custom Center**: existing personalization/customization center.
- **Shop**: real data-driven store with category browsing, preview, price, duration/permanent state, Purchase/Send where supported.
- **Props**: owned inventory/entitlements with real equip/use state.
- **Reward Records**: server wallet/reward transaction history with date/time and Coin/Diamond delta.
- **Task**: server-derived task completion, one-time reward claim and wallet transaction write.
- **Host data**: real Host/Agency/BD role, diamonds, commission, withdrawable value, settlement transfer and transfer history.
- **Family**: Family home when joined; Family discovery/ranking/join flow when not joined.
- **CP Nest**: personal CP entry remains in Mine and opens real CP functions.
- **Feedback**: category + message submission stored server-side, with user's own feedback history.

Games remain room-only and do not move into Mine.

### W.6 Setting exact order

1. Message notification
2. Bind account
3. Language settings
4. About Tinni Star
5. Feedback
6. Blocklist
7. Privacy statement
8. Sign out

Required behaviors:

- **Message notification** persists Voice, Vibration and Only receive floating screen in the room preferences.
- **Bind account** shows linked identities; Google linking uses verified Google identity; Email linking uses OTP + 8–128 character Tinni password and must bind to the same Tinni user ID.
- Facebook binding stays hidden unless Facebook login is deliberately re-enabled.
- **Language settings** saves the account preference; current choices include English, Hindi and Urdu.
- **About Tinni Star** shows real Tinni Star identity/version information.
- **Blocklist** loads real blocked users and supports Move out / Unblock through the backend.
- **Privacy statement** opens the real Service Agreement & Privacy Policy page.
- **Sign out** confirms, closes active room session, unregisters push, clears persisted auth/profile state and returns to Login.

### W.7 Privacy / Service Agreement

- Privacy statement is not a placeholder.
- Page title: **Service Agreement & Privacy Policy**.
- Two switchable sections: **Service Agreement** and **Privacy Policy**.
- Policy is written for Tinni Star and covers account/profile data, rooms/chat/calls, verification material, device/diagnostic information, wallet/gifts/purchases, public visibility, providers, retention, security, permissions, rights, age requirements, international processing, policy updates and contact route.
- Until an official legal/support contact is configured, privacy/contact requests route through **Mine → Feedback**.
- Current effective date: **30 September 2026**.

### W.8 No-placeholder / server-authority rule

For the Mine flow, do not use fake local balances, fake stats, fake reward history, hard-coded Fans/Charm/Wealth values, unrelated destination pages or generic No content yet pages for functions defined above. Empty states are allowed only when they truthfully represent empty server-backed data.


## X. Social graph

Support:
- follow/unfollow
- friends/application if enabled
- followers/fans
- private chat
- blacklist/block
- room search
- user search
- recent rooms
- followed rooms
- dynamic/moments if enabled

Party > Mine:
- My room
- Recents
- My followings

## Y. VIP / Noble / Identity

Feature families:
- VIP levels
- Noble levels
- medals
- identity badges
- custom frames
- seat/profile frames
- nameplates
- headwear
- vehicle/entry effects
- good-number/UID effects
- room/voice-wave identity

Architecture requirement:
- identity entitlement is separate from seat state.
- frame renderer composes per user.
- user's equipped frame must not be globally overwritten by another user's setting.

Exact visual catalog/pricing remains content/config and may require more reference.

## Z. CP / Family / KTV / Games

CP:
- courting/request
- accept/refuse
- active CP
- intimacy/levels
- ring
- memories/anniversary
- rank
- heartbeat
- disconnect

Family:
- create/join
- Head
- Deputy
- Assistant
- Member
- family room
- members/roles
- tasks/sign-in
- rank
- lottery
- wallet/records

KTV:
- song search
- local song source where supported
- queue
- lead singer
- chorus
- cut/delete song
- give up singing
- RTC/media mix

Games:
- game center framework
- Lucky 777
- Blackjack
- Gift Draw
- Guessing
- server-configurable games
- Tinni may add Ludo/UNO as its own modules
- settlement/rewards server-authoritative

---

# PART III — BACKEND / DATA MODEL BLUEPRINT

## 1. Core entities

User:
- id
- displayName
- avatarUrl
- country/region
- language
- profile fields
- createdAt
- account status

Room:
- id
- ownerId
- name
- description
- avatarUrl
- country
- createdAt
- seatCount
- micMode
- seatDesignId
- backgroundId
- level
- state/version

RoomRole:
- roomId
- userId
- role: OWNER | ADMIN | MEMBER
- assignedAt
- assignedBy

RoomSeat:
- roomId
- seatId
- index
- locked
- roomMuted
- occupantUserId nullable
- version

MicRequest:
- id
- roomId
- userId
- createdAt
- status
- handledBy
- handledAt

RoomKickRecord:
- fields defined above

UserBlockRelation:
- fields defined above

UserEffectPreferences:
- per-user effect flags

RoomBackgroundEntitlement:
- fields defined above

GiftCatalogItem:
- id
- category
- price
- effectAsset
- availability
- metadata

GiftTransaction:
- id
- senderId
- roomId
- giftId
- recipientIds
- quantity
- totalPrice
- status
- createdAt

Wallet:
- userId
- balances
- version

WalletTransaction:
- id
- userId
- type
- amount
- referenceId
- createdAt

UserEntitlement:
- userId
- type
- itemId
- activatedAt
- expiresAt
- equipped

## 2. Suggested API families

Auth:
- POST /auth/login
- POST /auth/refresh
- POST /auth/logout

Users:
- GET /users/{id}
- PATCH /users/me
- GET /users/me/blocklist
- POST /users/{id}/block
- DELETE /users/{id}/block

Rooms:
- POST /rooms
- GET /rooms/{id}
- PATCH /rooms/{id}
- GET /rooms/new
- GET /rooms/recent
- GET /rooms/following
- POST /rooms/{id}/join
- POST /rooms/{id}/leave

Room roles:
- GET /rooms/{id}/roles
- POST /rooms/{id}/admins/{userId}
- DELETE /rooms/{id}/admins/{userId}

Seats/mic:
- GET /rooms/{id}/seats
- PATCH /rooms/{id}/seats/config
- POST /rooms/{id}/mic-requests
- GET /rooms/{id}/mic-requests
- POST /rooms/{id}/mic-requests/{requestId}/accept
- POST /rooms/{id}/mic-requests/{requestId}/reject
- POST /rooms/{id}/seats/{seatId}/occupy
- POST /rooms/{id}/seats/{seatId}/release
- POST /rooms/{id}/seats/{seatId}/lock
- POST /rooms/{id}/seats/{seatId}/unlock
- POST /rooms/{id}/seats/{seatId}/mute
- POST /rooms/{id}/seats/{seatId}/unmute

Kickout:
- POST /rooms/{id}/kickouts
- GET /rooms/{id}/kickouts/active  // OWNER only
- DELETE /rooms/{id}/kickouts/{kickoutId} // OWNER only

Room appearance:
- PATCH /rooms/{id}/seat-design
- POST /rooms/{id}/backgrounds/purchase
- POST /rooms/{id}/backgrounds/upload

Gifts:
- GET /gifts/catalog
- POST /gifts/quote
- POST /gifts/send

Wallet:
- GET /wallet
- GET /wallet/transactions
- POST /recharge/create
- POST /recharge/verify

These are clean Tinni API recommendations, not copied endpoints.

## 3. Authorization rules

Every mutable endpoint must check:
- authenticated user
- room membership if required
- role capability
- target constraints
- active kickout/block rules
- version/sequence where concurrent state matters

Never rely solely on client-side hidden buttons.

---

# PART IV — TEST / ACCEPTANCE BLUEPRINT

## 1. Unit tests

Required:
- seat count normalization
- row distribution
- row-count boundaries
- full-width seat math helper
- 15-day New filter
- role capability matrix
- Free Mic vs Apply Mic logic
- Owner/Admin bypass of Apply Mic
- kick duration expiry
- Unkick owner-only
- Block directional room-entry rule
- Block mutual-DM rule
- personal Effects isolation
- room background entitlement expiry

## 2. Widget/UI tests

Required:
- Party top tabs tap + swipe
- Party > Mine shows My room/Recents/My followings
- Bottom Mine remains profile
- Create Room creator becomes owner
- 4-box icon opens Room Settings for Owner
- Admin does not receive Owner Room Settings
- Admin can seat lock/mute/invite/approve/remove/kick
- normal user personal settings are self-scoped
- Apply Mic request acceptance/rejection
- Kickout List field layout + right-side Unkick
- Blacklist row + Move out
- effects toggle changes only current user's rendering
- gift recipient horizontal scrolling
- room chat remains visible under seat area

## 3. Integration tests

Required:
- join room → RTC + IM + snapshot
- leave room cleans RTC/IM state
- reconnect resync
- block admission denial
- kickout admission denial + expiry
- admin moderation authorization
- gift send updates wallet + event
- background entitlement activation/expiry
- profile blacklist sync with target action sheet

## 4. Android device tests

At minimum:
- Android 11
- Android 14
- current Android target device available to team

Verify:
- install/update using stable signing
- microphone permission
- Bluetooth/audio routing
- background/minimized room
- foreground service notification
- screen rotation policy if portrait locked
- low-memory recovery
- reconnect after Wi-Fi/mobile switch
- app resume after background
- no 15–30 second unintended app exit

## 5. Production acceptance criteria

A build is not "complete" unless:
- analyze/lint passes;
- automated tests pass;
- signed release APK builds;
- same-signature update installs over previous release;
- no known dead buttons;
- Owner/Admin/Normal permissions match matrix;
- room create/join/leave works;
- seat/mic modes work;
- kickout/block rules work;
- settings scope is correct;
- gift/economy paths are server-authoritative;
- background behavior has been device-tested;
- crash/analytics hooks are configured;
- secrets are not embedded in source.

---

# PART V — IMPLEMENTATION ORDER

Recommended order:

1. Auth/session/profile
2. Main navigation
3. Party discovery + Mine/Party/Events/Country
4. Room create + ownership
5. Room snapshot/session
6. Seat layout engine
7. Free Mic / Apply Mic
8. Owner/Admin role policy
9. Room Settings
10. Kickout + Unkick
11. Personal Block/Blacklist
12. RTC integration
13. IM/chat integration
14. Background/reconnect
15. Gifts + recipient selector
16. Wallet/recharge/store
17. Effect engine + personal Effect settings
18. Seat/user frame system
19. VIP/Noble
20. CP
21. Family
22. KTV
23. Games
24. Activities/ranks/dynamic
25. Anamika connector + Function Pack hardening
26. production security, analytics, performance, release validation

---

# PART VI — ANAMIKA / FUNCTION PACK CONTRACT

Tinni Star may connect to Anamika later.

Allowed Function Pack-style updates only for capabilities explicitly designed as data/config/plugin-safe, such as:
- localization
- feature flags
- declarative room rules
- seat-layout config
- gift catalog metadata
- effect asset/config references
- safe UI content/config

APK update required for:
- compiled Dart logic not designed as data-driven plugin logic
- AndroidManifest changes
- new Android permissions
- native SDK/library changes
- RTC/IM native integrations
- foreground-service declarations
- signing
- native executable/library changes

Update safety:
1. Validate pack schema.
2. Validate hash/signature.
3. Check compatibility range.
4. Stage pack.
5. Test/health-check.
6. Activate atomically.
7. Keep previous known-good version.
8. Roll back on failure.
9. Do not duplicate already-installed pack versions.
10. Suggest deletion of old versions only after the new version is proven stable; deletion remains owner-controlled.

---

# PART VII — CURRENT REFERENCE GAPS / DO NOT INVENT

The architecture is ready, but the following visual/behavior details should be filled from additional user references before claiming pixel/interaction parity:

1. Exact seat-design catalog and final visual assets.
2. Exact per-user frame composition/layer priority.
3. Owner/Admin visual badge/frame treatment.
4. Admin appointment/removal UI and exact admin-count rules.
5. Remaining Room Settings entries and exact order.
6. Apply Mic queue/popup animation details.
7. Seat lock/move animations and long-press/tap details.
8. Exact Gift panel visual hierarchy/combo timing.
9. Entry/VIP effect visual catalog.
10. Room chat system-message visual styles.
11. Exact CP screens.
12. Exact Family screens.
13. Exact KTV screens/synchronization.
14. Exact Game presentation/settlement screens.
15. Exact VIP/Noble pricing/privilege screens.
16. Exact Wallet/recharge product UI and pricing.
17. Exact background upload coin prices.
18. Exact room-level progression formula.
19. Exact room/member list sorting rules.
20. Exact production backend/provider credentials and secrets.

Developer rule:
- implement the confirmed architecture and state boundaries now;
- isolate unresolved parts behind configuration/interfaces;
- never guess financial values, permission rules, or irreversible server behavior.

---

# PART VIII — HANDOFF CHECKLIST

When giving this blueprint to a developer/AI coding agent, instruct them to:

- Treat this file as the primary product specification.
- Do not remove existing working Tinni Star functions unless explicitly requested.
- Do not merge Party > Mine with Bottom Mine.
- Do not give Admin Owner permissions.
- Do not confuse Block with Kickout.
- Do not make Effects toggles room-global.
- Do not allow normal users to change another room's settings.
- Do not allow Admin to view Kickout List or Unkick.
- Do allow Admin to invite/approve mic, remove from seat, seat lock/unlock, seat mute/unmute, kickout, and directly take empty seat.
- Do enforce all authoritative permissions on backend.
- Keep UI responsive across supported seat counts.
- Keep the app clean-room and use original/licensed Tinni assets.
- Build and test a signed release before declaring a version complete.

**End of Tinni Star Complete Implementation Blueprint v3**
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


### Current room 4-box contents — LOCKED

The room 4-box must contain these active entries only:
- Room Type
- Music
- Effects
- Lock / Unlock
- Lucky Bag
- Sound On / Off
- Lucky Number
- Group PK
- Public Screen / Screen On
- Report

The following older 4-box entries are removed and must not be re-added as duplicate tiles:
- Blacklist
- Seat Requests / invite-mode request tile
- Gift
- Feedback
- Moderation
- Friends Mode / Event Mode
- Launch Event / Stop Event
- separate Room Theme

Game / Rocket stay outside the 4-box.


- Seat invitation logic may remain in the room, but it is not a 4-box tile.


### Room Settings single-entry rule — LOCKED

- There is **no separate Settings tile** in the room 4-box.
- All room setting controls live in **Room Type → Setting**.
- Room Type → Setting contains:
  - Room Seats
  - Free mic
  - Only managers can speak
- The old standalone Room Settings sheet is removed.
- Room Type keeps its Mic Types and Mic Theme tabs; the Setting tab is the single settings surface.



### Room Type Cover placement — LOCKED

- `Cover` is not a separate 4-box tile.
- `Room Type` contains four tabs:
  - Mic Types
  - Cover
  - Mic Theme
  - Setting
- `Room Type → Cover` opens the existing `Room Cover / Theme` selector.
- Only the room owner can change the room cover/theme.
- The old standalone `Cover` and old standalone `Room Theme` 4-box entries must not return.



### Public Screen typing rule — LOCKED

- `Public Screen ON`: every user in the room can use the typing/chat area, unless that individual ID is chat-banned by room moderation.
- `Public Screen OFF`: only the **Room Owner** and **Room Admins** can type/send in the room typing area.
- Normal users, seated users, hosts/family roles, and audience users do not gain typing permission while Public Screen is off unless they are also Room Owner/Admin.
- When Public Screen is off for a normal user, the typing field is disabled and shows `Owner/Admin only`.
- The existing per-user chat-ban remains stronger than Public Screen permission: a chat-banned Owner/Admin cannot type until the ban is removed.



### Reference room visual adoption — LOCKED

The main Tinni room adopts the supplied reference-video room flow without changing the current 4-box/settings rules:

- Top-left room identity uses a compact rounded pill with **Room DP + Room Name + Room ID**.
- Top-right keeps **Share** and **Power / Minimize / Exit** controls.
- A trophy-style **room Ranking** pill opens an in-room bottom panel instead of navigating to the old full Ranking Center.
- Room Ranking uses **Daily / Weekly / Monthly** tabs, a dark-purple reference-style sheet, contributor rows, and a fixed current-user row at the bottom.
- The top member-count pill opens the existing room-member surface.
- Empty unlocked seats keep the reference circular glowing seat look; locked empty seats show the standalone gold lock.
- Every seat keeps the **No.X** label and heart/intimacy pill.
- A red mic-off badge appears on the seat when that seat is room-muted, presence-muted, or the seated user has **Self Mute** enabled.
- **Rocket** stays above **Game** in the right-side floating stack with the small progress bar between them.
- Rocket and Game remain outside the 4-box.
- LP/Game country ribbons use reference-style gold-edged room banners while preserving existing LP-first / game-next priority and country targeting.

Do **not** add or duplicate Room Settings, Blocklist, Cover, Lock, Seat Requests, Game, Rocket, or other room controls in the 4-box. The previously locked 4-box structure and Room Type → Cover / Setting placement remain unchanged.



### Blueprint sync state — 0.5.22+40

This blueprint is synchronized with the current Tinni Star room implementation at app version `0.5.22+40`.

Canonical current room rules:
- 4-box has exactly: Room Type, Music, Effects, Lock / Unlock, Lucky Bag, Sound On / Off, Lucky Number, Group PK, Public Screen / Screen On, Report.
- Blacklist and Seat Requests are **not** 4-box tiles.
- Room Type contains Mic Types, Cover, Mic Theme, Setting.
- Room Type → Setting contains Room Seats, Free mic, Only managers can speak.
- Room Type → Cover opens Room Cover / Theme.
- Room Lock exists only as the 4-box Lock / Unlock entry and uses exactly 5 numeric digits; no VIP requirement.
- Public Screen ON allows all non-chat-banned room users to type; OFF allows only Room Owner/Admin.
- Reference room visuals are adopted for Room DP + Name + ID, in-room Daily/Weekly/Monthly ranking, seat styling, self-mute mic-off badge, right-side Rocket/Game stack, and LP/Game ribbons.
- Game and Rocket remain outside the 4-box.
- Existing Room Setup / Block List behavior must not be duplicated into the 4-box.



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

## Owner Master Panel — V Official management anti-regression lock

- **V Official management is Owner Master Panel-only.**
- **Automatic Host / Agency identity tags are separate from V Official.** When a user becomes an active Host, backend identity data must expose exactly **Host** in **Sky Blue (#69C9FF)**. When a user becomes an active Agency, backend identity data must expose exactly **Agency** in **Sky Blue (#69C9FF)**. These automatic tags must never be converted into or prefixed with V Official.
- The Tinni Star APK/app must never expose controls to create, apply, edit, remove, recolor, or list/manage V Official assignments.
- The APK/app may only render the V Official identity badge/position returned by the backend for a user.
- Owner Master Panel → **Messages & Tags** must keep a dedicated **V Official Tag** control with Position / Designation, the six background presets **Sky Blue, Light Green, Golden, Black, Red, Purple**, **Apply V Official to Selected**, and the **Officials** management list.
- Every active V Official must be manageable from the Owner Master Panel, including edit position and remove official.
- These rules must not be moved into the app or removed by future merges, refactors, APK rebuilds, or UI cleanups unless the owner explicitly changes this rule.

## Gift economy, selected-seat animation, and Rocket anti-regression lock

- Gift delivery animation must originate from the **center of the room screen** and travel to the **selected recipient ID/seat DP**. It must not fly from a fixed screen corner.
- **Lucky Gift social value is fixed at 10%** of the charged gift value. That same 10% is the only amount added to the recipient seat received-value display, room gift ranking, and Rocket progress.
- Every gift that is **not Lucky** contributes **100%** of its charged value to the recipient seat received-value display, room gift ranking, and Rocket progress.
- Gift Diamonds are **Host-only**. A recipient who is not an active Host receives **0 Diamonds** from gifting. Once the recipient is an active Host, normal gifts credit **100% Diamonds** and Lucky Gifts credit **10% Diamonds**.
- Host eligibility must be checked server-side at gift-send time. Client UI labels do not grant Diamond eligibility.
- Rocket has exactly **10 sequential stages**. The amount required to complete each stage is: **1 = 8M, 2 = 15M, 3 = 30M, 4 = 50M, 5 = 90M, 6 = 150M, 7 = 200M, 8 = 250M, 9 = 350M, 10 = 500M**.
- Rocket uses the same server-derived social gift value as room ranking: Lucky = 10%, all other gifts = 100%. Do not maintain a second conflicting gift-value formula in the client.
## Room tags, Mine hierarchy, seller PIN, auto room-lock and CP anti-regression lock

- **Room identity tags are comment-only.** Do not render Host, Agency, V Official, custom, or other identity tags on room seats, beside seat DPs, as a room-wide tag strip, or inside the room mini/full member profile. Tags remain visible on the normal user ID/Profile surface. Inside a live room, a user's active identity tag may appear only in the comment/message area beside that user's name, with a clearly readable pill slightly larger than the previous room-comment text treatment. When a user enters the room, append an automatic comment-area entry line using the same active tag + name presentation; do not create a separate room tag banner.
- **Room comments auto-follow the newest message.** When the visible comment area is full and a new message/comment is appended, the room message list automatically scrolls to its newest item. The user must not need to manually drag the list to reveal the new comment.
- **Mine hierarchy order is fixed:** BD Panel first, Agency Panel immediately below it, Host Panel immediately below Agency. Each panel is visible only while its corresponding backend role is active.
- **Agency activation is automatic on the client surface:** as soon as backend hierarchy state reports Agency active, the same refresh must expose both the Sky Blue Agency identity tag and the Agency Panel. No separate manual tag assignment is required.
- **Coin Seller transfer credential is exactly a 4-digit numeric PIN.** Digits 0000 through 9999 are structurally valid choices subject to normal security/rate controls. Coin Seller setup, transfer verification, and email-OTP reset must reject non-numeric or non-4-digit credentials. Merchant credential rules remain separate.
- **Room Lock uses a server-generated 5-digit code.** When the room owner turns Lock on, backend generates, hashes/saves, and returns a random 5-digit room password. The owner's Room Lock control displays that code in the same lock setting area. Visitors use that code to enter. The room owner bypasses their own room password and can unlock without entering it. Turning Lock off invalidates/hides the displayed code.
- **CP reference conversion is fixed to the requested economies:** reference app 45,000 coins = USD 1; Tinni 2,000,000 coins = USD 1; scale factor 44.444...x. Reference CP Heart 1,000 becomes **44,444 Tinni coins** and reference CP Invite 50,000 becomes **2,222,222 Tinni coins**.
- **CP Invite** is the confession/invitation flow and may be sent only when neither side already has an active/pending CP flow. Active CP appears on the ID/Profile CP card with the two avatars, heart/CP identity, level/intimacy/day information, and an All my CP entry to the CP area.
- **CP intimacy rules:** regular gifts use 100% of the normalized reference-coin intimacy value; Lucky gifts use 10%; same-day mutual CP gifting gives the eligible gift a 1.2x exchange multiplier; known first level threshold is Lv.1 -> Lv.2 at 200K intimacy; level-cycle duration is 7 days; after 3 consecutive days without intimacy, decay starts on day 4 at 5% per day until activity resumes. Do not invent later level thresholds that were not supplied; keep later thresholds owner-configurable.

