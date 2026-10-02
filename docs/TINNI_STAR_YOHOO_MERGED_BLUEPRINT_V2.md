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
- 31–36 seats → 6 rows.
- 37–42 seats → 7 rows.

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
  - 42 = 6+6+6+6+6+6+6

Visual rule:
- All rows use the same left and right working edges.
- Rows above the final two rows keep their normal equal seat count.
- Because the final two rows usually contain fewer seats, their seats are distributed across the same width with larger gaps.
- The leftmost and rightmost visual corners remain aligned to the same room-seat area.
- Lower seat counts use larger seat circles/frames.
- Higher seat counts use smaller seat circles/frames, but 37–42 must never return to the old 7-column/6-row layout.
- **Anti-regression lock:** a 42-seat room is always 6 columns × 7 rows. Maximum 6 seats per row for 37–42 keeps the seats visibly larger while preserving the existing row-order/pattern.
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

Lock / Unlock:
- Uses the existing owner-only password room flow.
- Password is exactly 5 numeric digits; any 00000–99999 value is valid, and the existing failed-attempt rules remain unchanged.
- VIP is **not required** to set or use a room password; any room owner can lock their own room with an exact 5-digit password.
- Room lock is exposed **only** from the 4-box `Lock / Unlock` tile; duplicate lock controls are removed from Room Type, Room Setup, and legacy Room Settings.

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

**Seat tap**
- Owner/Admin normal tap on a seat opens the reference-style bottom panel with:
  - `Mic up`
  - `Lock mic`
  - `Confirm`
- Long press keeps the advanced Tinni seat controls so existing moderation functions are not removed.

**Floating Game + Rocket**
- Game remains outside the room 4-box.
- Right-side floating stack shows a small Rocket icon above a short progress indicator and the purple/pink Game controller below it.
- Game controller opens `Game Center`.
- Game Center shows a room/profile progress card, coin balance, an `All Games` grid, and Tinni's Fruit Jackpot / Fruit Party entries.
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



### Blueprint sync state — 0.5.23+41

This blueprint is synchronized with the current Tinni Star room implementation at app version `0.5.23+41`.

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




### Build stabilization sync — 0.5.23+41

The successful Tinni Star `0.5.23+41` APK build keeps all previously locked room behavior and adds the following stability/layout fixes:

- Reference seat rows reserve extra vertical label space so the stack **seat/avatar or lock → No.X/name → heart pill → optional tag/medal** does not overflow.
- The seat-count rules remain unchanged: every count **8–42** stays supported with the existing fixed row-distribution policy.
- The exact **5-digit room password** rule is unchanged. The password dialogs now use local value state instead of a disposable text controller, preventing disposed-controller failures during modal close/reopen transitions.
- Opening **Room Type → Cover**, room tools, **Room Setup**, and **Room Members** after closing another modal uses a short transition delay so sheets/pages do not collide during route animation.
- Removed 4-box entries remain removed: Gift, Feedback, Moderation, Friends/Event Mode, Launch/Stop Event, Blacklist, Seat Requests, standalone Cover/Room Theme, and standalone Settings.
- Hidden legacy helper methods may remain in source only for compatibility, but they are not exposed as 4-box tiles and must not reappear in the room UI.
- The current 4-box remains exactly: **Room Type, Music, Effects, Lock / Unlock, Lucky Bag, Sound On / Off, Lucky Number, Group PK, Public Screen / Screen On, Report**.
- Room Type remains exactly: **Mic Types, Cover, Mic Theme, Setting**.
- Room Type → Setting remains: **Room Seats, Free mic, Only managers can speak**.
- The reference-style room visuals and flows remain unchanged: **Room DP + Name + ID**, in-room **Daily / Weekly / Monthly Ranking**, seat self-mute red mic-off badge, right-side **Rocket above Game**, and LP/Game ribbons.

