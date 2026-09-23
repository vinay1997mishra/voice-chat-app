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
8, 9, 10,
12–18,
19–28,
29–35,
36–42.
11 is skipped.

Row-count rule:
- 8–10 seats → 2 rows.
- 12–18 seats → 3 rows.
- 19–28 seats → 4 rows.
- 29–35 seats → 5 rows.
- 36–42 seats → 6 rows.

Distribution:
- Seats are balanced across rows.
- Row-size difference should be at most 1.
- Examples:
  - 8 = 4+4
  - 9 = 5+4
  - 10 = 5+5
  - 12 = 4+4+4
  - 18 = 6+6+6
  - 19 = 5+5+5+4
  - 28 = 7+7+7+7
  - 29 = 6+6+6+6+5
  - 35 = 7×5
  - 36 = 6×6
  - 42 = 7×6

Visual rule:
- Every row uses the full available width from left edge to right edge.
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
- Remove user from seat / send user down from mic.
- Seat lock/unlock.
- Seat mute/unmute.
- Directly take an empty seat / go on mic without Apply Mic.

Admin must not receive room-wide Settings controls or Kickout List/Unkick controls.

## 14A. Room Owner / Admin permission matrix — LOCKED

| Capability | Owner | Admin |
|---|---:|---:|
| Open/change Room Settings | YES | NO |
| Edit room DP/name/description/member list | YES | NO |
| Change Mic Mode / seat count | YES | NO |
| Change Seat Design | YES | NO |
| Change Room Theme / Background | YES | NO |
| View Room Level / Kickout List | YES | NO |
| Unkick active kickout | YES | NO |
| Kick Out user | YES | YES |
| Remove user from seat | YES | YES |
| Lock / unlock seat | YES | YES |
| Mute / unmute seat | YES | YES |
| Directly take empty seat / go on mic without Apply Mic | YES | YES |

This matrix is authoritative for Tinni Star unless the owner later changes it.

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
- blacklist.
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
- exact remaining Room Settings option list. Owner/Admin permission boundary is now locked: Admin has no Room Settings/Kickout List/Unkick access and only limited seat + kick moderation.
- exact dialogs/animations.
- exact state transitions visible to users.
