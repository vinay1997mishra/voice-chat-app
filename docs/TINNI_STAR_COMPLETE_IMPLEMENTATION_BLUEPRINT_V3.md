# TINNI STAR — CURRENT LOCKED BLUEPRINT

<!-- GLOBAL_CHANGE_LOCK_V1 -->
## 0. Authority and anti-regression lock

This file is the **only product-behavior source of truth** for Tinni Star.

- All older/legacy Tinni Star blueprints are retired and must not be used to restore layouts, functions, rules, or UI.
- The current app behavior plus the latest explicit user-confirmed rules are locked.
- If the user has not explicitly asked to change something, keep it exactly as it is.
- A new feature request is additive by default. Do not silently remove, replace, rename, resize, reorder, restyle, weaken, or revert an existing function.
- The **latest explicit user instruction wins** over any older note, branch, screenshot, test, comment, or implementation.
- Any intentional behavior change must update this file in the same change set.
- Old branches/cherry-picks/merges must never overwrite a newer confirmed behavior.
- Bug/build/security/performance/refactor work is allowed only when it preserves product behavior unless the user explicitly authorizes a behavior change.
- Current implemented behavior not individually repeated below is still locked by the current branch snapshot.

## 1. Main product surfaces

- Main navigation keeps Party, Discover, Message, and Mine.
- Party keeps room-focused Mine, Party, Events, and Country areas.
- Bottom Mine remains the user-profile surface and is separate from Party > Mine.
- Existing working buttons and navigation paths remain active; no dead/placeholder regression.

## 2. Party / Discover / room listing

- Rooms with **0 users do not appear in Party or New**.
- Zero-user rooms may appear only in Recent after the user has actually visited them.
- Room ordering prefers higher live users and real sending/receiving activity.
- EXP: 1 coin sent = 1 EXP; 1 coin received = 1 EXP, counted separately.
- Per-user room EXP bonus remains +500 per user where configured.
- Discover/list room DP is square and shows the room DP.
- Room-create DP choices appear only after tapping the DP control; Camera/Gallery remain available.
- Room-create DP supports crop/preview.
- In-room header DP is square so the full DP remains visible.
- Pull/down refresh remains manual where implemented; do not reintroduce unwanted automatic refresh.

## 3. Seat count and layout — LOCKED

Supported seat count remains every whole number from 8 through 42.

Row count:
- 8–10 seats → 2 rows.
- 11–15 seats → 3 rows.
- 16–24 seats → 4 rows.
- 25–30 seats → 5 rows.
- 31–36 seats → 6 rows.
- 37–42 seats → 7 rows.

High-capacity lock:
- **42 seats = 6 seats per row × 7 rows.**
- Old 7×6 / 7-seats-per-row layout is forbidden.
- 37–42 seat rooms must not exceed 6 seats in a row.
- Seat circles/DPs must stay visibly larger than the old high-density layout.
- Existing row order/pattern is preserved.
- Shorter rows are not stretched to fake equal width.
- Seat-to-seat gap stays visually equal; shorter rows may start at different X positions.
- Keep inner left/right margin so first/last seats do not touch screen edges.
- Rows are horizontally balanced against the row above.

Seat-count control:
- Owner can increase or decrease seat count.
- Admin can increase only; decrease controls remain hidden/blocked.
- Backend must reject Admin seat decreases.
- Changing Room Type must not silently reduce seat count.

## 4. Seat behavior and authority

- No seat may auto-open, auto-lock, auto-mute, auto-unmute, or auto-take.
- Owner/Admin tapping an empty seat keeps explicit Seat Mute / Seat Lock / Take Seat controls.
- Self DP/seat tap keeps centered Down / Leave Seat actions.
- Self-mute and room/seat-mute indicators remain visible on the seat.
- Owner seat is immune to Admin actions.
- Admin cannot control another Admin.
- Owner can control Admin/member seats.
- Apply Mic / Request Mode remains; it must be fixed when broken, not removed.
- Free Mic / Apply Mic behavior and server enforcement remain aligned with the current app.

## 5. Owner/Admin boundaries

- Only Owner sees add/remove Admin controls in the room member list.
- Owner may search by public ID to add Admin.
- UID/name-ID changes remain Owner Master Panel only.
- Owner-only room-wide controls must not leak to Admin.
- Admin moderation remains limited to the current allowed seat/user actions.
- UI hiding is not enough; permission boundaries must also be enforced server-side.

## 6. Room Type / consolidated room settings

- Room settings remain consolidated under Room Type where currently defined.
- Room lock exists in one place only: Room Type.
- Room password is **exactly 5 digits**.
- Public Screen ON → all users may type.
- Public Screen OFF → only Owner/Admin may type.
- Room background/themes remain inside Room Type.
- Existing requested mood backgrounds remain available, including sad, boring, happy, love, mountain view, alone, with-her, with-him and love-scene variants.
- Privacy Policy Agreement remains on a **white background**; do not apply the black/gold room theme to it.

## 6A. Room entry announcement / activity area — LOCKED

- The permanent Lucky result-history cards such as "Colorful Rose", "Magic Balloon", sender name, "Won X coins" and multiplier history must **not** stay stacked under the seats.
- Lucky result/history may exist in dedicated history/state surfaces, but it must not remain as a permanent room-screen overlay.
- The old "Ask your followers to support the room." strip is removed from the under-seat room area.
- The old automatic "System: Welcome to Tinni Star ✨" chat line is removed.
- Immediately on room entry, a permanent **Official announcement** card is shown under the seats / above live room chat, using a dark blue-grey card with yellow announcement text in the same visual spirit as the supplied reference.
- The official announcement remains visible as the fixed room-entry notice; normal live chat continues below it.
- Do not restore the removed Lucky result cards or old support/welcome text unless the user explicitly asks.

## 7. Room header / tools / music

- Header keeps left room DP + room name + room ID.
- Right side keeps member DPs / +N / Share behavior as currently implemented.
- Follow count style remains current.
- Floating Rocket and Game controls stay outside the 4-box tools panel.
- Duplicate Gift/Moderation/Effects/lock/theme entries must not be reintroduced.
- Music must stop when the room is exited.
- Music must also stop when the seat area is moved down as defined by current room behavior.
- Room sound/music must not continue unintentionally in another room/session.

## 8. Gift panel — current locked behavior

Categories remain:
- Normal
- Lucky
- CP
- Country
- Luxury

Gift panel:
- Wallet header shows **Total Coins**.
- Recipient strip is horizontally swipeable.
- One or multiple **real user IDs** may be selected.
- Fake `seat-N` gift-recipient IDs are forbidden.
- Selected DP is visibly **blurred/dimmed with gold check/glow**.
- Unselected DP stays normal/clear.
- Send becomes ready immediately when a gift and at least one recipient are selected.
- Send is disabled only while that send request is actually in flight, or when gift/recipient selection is missing.
- Normal and Lucky effects must target only selected receiver IDs.
- Multi-recipient sends fan out to every selected receiver seat.
- Unselected seats must never receive the visual gift effect.

## 9. Gift flight / realtime — LOCKED

- Backend remains authoritative for payment/delivery.
- After successful server acceptance, room realtime emits a canonical `gift_sent` event containing the exact selected real receiver IDs.
- Every connected room client renders the gift on the selected receiver seat(s).
- Gift must visibly travel/fly toward the selected DP/seat and land with impact feedback.
- Single recipient → one visible flight/impact.
- Multiple recipients → simultaneous fan-out to all selected seats.
- Do not revert to all-seat animation.
- Do not show a gift landing on a different seat than the selected receiver.

## 10. Lucky/Rebate gift — LOCKED

- Dedicated Lucky/Rebate category remains.
- Eligible Lucky gift may return coins to sender wallet up to 1000×.
- Continuous-send combo count and returned-coins total remain separate counters.
- Lucky quantity controls keep + and preset arrow.
- Presets remain: **9 / 21 / 51 / 99 / 199 / 599 / 899 / 2999 / 7999**.
- Selected recipient(s), selected Lucky gift, and chosen quantity persist into Combo.
- A valid Lucky Send closes the gift panel **immediately**; it must not stay open covering Combo.
- Successful Lucky send shows a clear room-screen Combo control.
- Combo shows a visible **12-second countdown**.
- Every successful Combo send restarts the 12-second window.
- If no Combo send occurs within the window, Combo disappears.
- Normal/non-Lucky sending ends an old Lucky Combo sequence.
- Lucky wallet/rebate state follows authoritative backend response.
- Lucky receiver social/diamond value remains 10% where currently configured.
- Non-Lucky receiver value remains 100% where currently configured.
- Seat received totals use credited receiver/ranking value, not raw gift cost.

## 11. Room-owner gift share

- 10% of eligible gift-box gifts sent in a room goes to the room-owner wallet as coins.
- Settlement remains daily at midnight as currently implemented.
- This owner share applies to gift-box gifts only unless explicitly changed later.

## 11A. Messages & Tags / V Official identity — LOCKED

- Owner Master Panel section name remains **Messages & Tags**. Do not rename it to Tags/Medals.
- Existing Custom User Tag remains available.
- Messages & Tags includes a separate **V Official Tag** assignment control for selected real User IDs.
- V Official assignment requires a Position / Designation.
- V Official badge visual is circular with a **gold outer ring**, **silver V** in the center, premium/official shine, and the Position / Designation written in **gold**.
- Required V Official background presets: **Sky Blue, Light Green, Golden, Black, Red, Purple**. Existing normal custom-tag color choice remains available separately.
- One active V Official tag per user is updated/replaced when Owner assigns a new V Official designation/background; normal custom tags remain independent.
- Host and Agency identity tags are automatic from active backend hierarchy roles. Owner does not need to manually recreate Host/Agency tags.
- Profile must not show placeholder **Non-VIP** or **Incomplete** identity boxes. That area is for actual identity tags only.
- Profile tag area may show V Official + Position, automatic Host/Agency, and other current assigned identity tags with clean spacing/wrapping.
- Message/conversation identity header shows the same current identity tags where applicable.
- No Medal-management behavior is introduced by this Messages & Tags feature; existing medal surfaces remain separate.
- These identity rules are server-backed and must survive reinstall/reconnect.

## 12. Profile / Mine / CP

- Profile header keeps UID with small overlapping copy icon.
- CP partner DP/details remain near the user DP.
- About Me keeps the decorative My CP card with both DPs/names and relationship duration/status.
- My CP card opens CP details including current CP Nest/intimacy/love-days/ring/memories/tasks/rules surfaces.
- Mine keeps Follow/Followers lists.
- Tapping a DP opens that user's profile.
- Other users' profiles must not show Edit.
- Existing Royal/black-gold profile, CP and Family visual direction remains unless explicitly changed.

## 13. Lucky visuals / premium effects

- Lucky gifts keep colorful artwork.
- Receiver-seat fly-in / pop / sparkle / impact remains.
- Higher multiplier results remain visually stronger where implemented.
- Effect toggles remain self-scoped where currently implemented; one user's personal effect setting must not silently disable another user's view.

## 14. Calls / privacy / verification

- Video calls keep screenshot/screen-recording prevention for both sides.
- If an attempt is detected, video auto-converts to audio and the other party receives the alert.
- Alert shows offender name + ID; offender does not receive that alert.
- Current call pricing/verified-girl economics remain unchanged unless explicitly updated.
- Verification keeps automatic checks plus Owner final 3-photo review and current Verified / Verified Req / Direct Verified control surfaces.

## 15. Games / floating controls

- Rocket/Game floating buttons remain outside the 4-box room tools.
- Current rocker/game positions and behavior remain.
- Lucky Fruits / Fruit Party current rules remain unless explicitly changed.
- Existing game height/placement fixes remain; do not restore old oversized layouts.

## 16. Storage / infrastructure

- Heavy permanent assets such as frames/profile cards/entry effects/backgrounds remain intended for R2 rather than D1 storage.
- Existing backend/realtime/RTC adapter boundaries remain.
- Server-authoritative economy, moderation, gifting, settlement and permission checks remain server-authoritative.

## 17. Build and regression policy

For every future intentional feature/layout change:
1. Change only what the user explicitly requested.
2. Preserve unrelated current behavior.
3. Update this canonical blueprint in the same commit/change set.
4. Add or update a regression test when mechanically testable.
5. Build/test after the function-level checkpoint when requested.
6. Do not recover an old behavior from legacy docs or an older branch.

**Final rule:** the current implementation + this latest blueprint are the baseline. Older blueprints are not valid input anymore.
