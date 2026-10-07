# TINNI STAR — CURRENT LOCKED BLUEPRINT

<!-- GLOBAL_CHANGE_LOCK_V1 -->
## 0. Authority and anti-regression lock

This file is the **only product-behavior source of truth** for Tinni Star.

- All older/legacy Tinni Star blueprints are retired and must not be used to restore layouts, functions, rules, or UI.
- The current app behavior plus the latest explicit user-confirmed rules are locked.
- If the user has not explicitly asked to change something, keep it exactly as it is.
- If the user has not asked to change it, keep it as it is.
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
- Combo shows a visible **9-second countdown**.
- Every successful Combo send restarts the 9-second window.
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
- **V Official management is Owner Master Panel-only.** The Tinni Star APK/app must never expose create/apply/edit/remove V Official controls, V color controls, or the Officials management list. The app may only render the currently assigned V Official identity badge/position returned by the backend.
- V Official assignment requires a Position / Designation.
- V Official badge visual is circular with a **gold outer ring**, **silver V** in the center, premium/official shine, and the Position / Designation written in **gold**.
- Required V Official background presets: **Sky Blue, Light Green, Golden, Black, Red, Purple**. Existing normal custom-tag color choice remains available separately.
- One active V Official tag per user is updated/replaced when Owner assigns a new V Official designation/background; normal custom tags remain independent.
- Host and Agency identity tags are automatic from active backend hierarchy roles. Owner does not need to manually recreate Host/Agency tags.
- **Automatic Host / Agency identity tags are separate from V Official.** When a user becomes an active Host, backend identity data must expose exactly **Host** in **Sky Blue (#69C9FF)**. When a user becomes an active Agency, backend identity data must expose exactly **Agency** in **Sky Blue (#69C9FF)**. These automatic tags must never be converted into or prefixed with V Official.
- Profile must not show placeholder **Non-VIP** or **Incomplete** identity boxes. That area is for actual identity tags only.
- Profile tag area may show V Official + Position, automatic Host/Agency, and other current assigned identity tags with clean spacing/wrapping.
- Message/conversation identity header shows the same current identity tags where applicable.
- No Medal-management behavior is introduced by this Messages & Tags feature; existing medal surfaces remain separate.
- These identity rules are server-backed and must survive reinstall/reconnect.
- **Officials panel:** every active V Official appears in Messages & Tags → Officials. Each distinct Position / Designation gets its own page/tab automatically.
- Touching an Official ID opens its Owner-only full user detail/profile view. Each Official row provides Full Details/Open Profile, Edit Position and Remove Official.
- Main Owner user search also provides **Open ID / Full Profile** so any searched ID can open the same consolidated user view.
- Consolidated Owner user view includes Tinni Star profile/account, wallet, current identity tags/roles, current live room/seat when available, stored Tinni inbox/message history and stored Tinni call history.
- If that ID is currently in a live Tinni voice room, Owner profile view provides **Listen to Room — no mic**.
- Owner listening is strictly subscriber-only: its LiveKit grant has `canPublish=false` and `canPublishData=false`; the Owner Panel has no microphone/talk control in this mode.
- Listen-only token issuance is Owner-only, short-lived and written to the Owner audit log. It applies only to Tinni Star live-room audio, not phone calls, WhatsApp, device microphone history or other apps.

## 12. Profile / Mine / CP

### Mine/Profile anti-regression lock

- Bottom **Mine must not show Props** as a menu option.
- Bottom **Mine must not show Personal information / Profile Information** as a separate menu option. Profile editing remains available from the actual profile/edit flow, not as a duplicate Mine menu row.
- Bottom **Mine must not show Custom Center**.
- Bottom **Mine must not show Reward Records**.
- Public Profile **About me must not show My medal**.
- Keep a **permanent reserved tag space directly below the UID / ID area** so official/role/custom tags can appear without moving the rest of the profile layout.
- Long-pressing the visible **UID / ID number** on Mine, self profile, or Personal information copies the exact ID to the clipboard.
- After the long-press copy, a **floating confirmation** must appear saying **"Copied"**.
- A profile **cover photo is persistent** after it is uploaded. Refresh, reopening the profile, app restart/re-login, editing name/signature/avatar, or unrelated profile updates must not remove it.
- The cover can change only when the user deliberately uploads a replacement, or disappear only after the user deliberately chooses **Remove cover** and confirms it.
- Backend profile-media deletion requires an explicit removal confirmation; no automatic cleanup flow may delete the cover.
- **Guardian qualification is based on gifted coins, not points**: the #1 supporter in the active 30-day window becomes Guardian only after reaching **5,000,000 coins (5M)**.
- These rules are locked and must not be removed or reverted unless the user explicitly changes them.

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
- Center Lucky HUD shows the gift artwork, quantity, authoritative sent coins, total return and an animated revealed-return counter. Returns belong to the sender; Lucky room results are public, while Rocket received reward cards remain private.
- Multiplier bubbles play one at a time: 1–10× pop, 20–50× glow, 75–100× sparks, 200–250× burst, 500× premium, 750× giant, 1000× full-screen celebration. Owner banner flags and self effect settings remain authoritative.
- All independently rolled units, including 0× and wins after unit 32, are included in compact result counters. Up to 32 winning units show individually; larger batches group equal multipliers with an explicit result count. Nothing is rerolled by the client.
- The backend reserves ordered room presentation start times. Sender HTTP confirmation and realtime broadcasts share the same event ID, result data and start/duration. Late or resumed clients follow the common clock; completed events are not replayed.
- During Rocket or large Country presentations, Lucky uses a compact secondary position and suppresses full-screen bursts so those presentations remain readable.
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

- **User image safety is fail-closed and server-authoritative.** Any user-supplied image that can become public or visible to other users (including profile avatar, profile cover/life/travel media and room DP, plus future user-upload image surfaces) must pass the configured server-side image moderation check before it is written/published. If the moderation service is unavailable, errors, times out or returns an invalid verdict, the upload is rejected and the previous approved image remains unchanged.
- User image upload accepts only validated JPEG/PNG/static WebP with matching file signatures and current size limits. Animated WebP is rejected to reduce frame-based moderation bypass risk. Client-side checks alone are never sufficient.
- Moderation must reject content prohibited by Tinni Star safety rules or applicable law, including child sexual exploitation material, non-consensual sexual imagery, explicit sexual content where prohibited, terrorist/extremist propaganda where prohibited, graphic illegal abuse content and other configured illegal/prohibited image categories. A moderation result is a safety control, not a legal determination; uncertain cases may be held/rejected rather than auto-published.
- Rejected image bytes must not be published as user media. Logs/audit should retain only necessary event metadata/verdict references, not duplicate the rejected image unless a specifically required lawful evidence-retention process is implemented.
- Direct clients must not bypass moderation by supplying arbitrary external image URLs in place of an approved uploaded media object. Future user-image surfaces must reuse the same moderation gate.
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
- **Messages keeps two permanent platform rows above user chats:** **Tinni Official** first and **Activity** second. Tinni Official is a read-only system conversation backed by platform/owner messages, not a normal user account; it remains visible even before the first notice. Activity is a separate notification/activity inbox for rewards, events, role/account actions and other platform activity.
- **Friend relationship is strict mutual-follow:** User A following User B alone does **not** create a Friend relationship. A and B become Friends only when A follows B **and** B follows A. If either side unfollows, Friend status ends immediately.
- **Messaging is Friend-only:** until both users follow each other, neither user can send the other a normal text message or a photo. Non-friend conversation/history may remain readable where applicable, but the composer, Send action and Photo action stay locked. Backend enforcement is authoritative, so a modified client cannot bypass the rule.
- **Friend status updates in real time:** follow/unfollow changes push a message-socket friend-status event to both users so an open inbox/conversation locks or unlocks without requiring an app restart.
- **Friend inbox photo sharing:** Gallery/Camera photo send is available only to mutual friends. The backend independently re-checks mutual friendship before storing an image.
- **Inbox photo content lock:** message photos are stored as protected message media and may be fetched only by the sender or recipient. Chat-photo screening must reject images that visibly contain another app/service logo, app name, branded app interface/screenshot, external URL/domain/link, referral link/code, QR code, app-store link, or similar redirect material. The app never renders the protected media URL as chat text.
- **Minimum safety remains server-side:** private/friend status does not disable the baseline illegal/prohibited-image safety gate. If the required decision service is unavailable or uncertain, the image is not sent; plain text messaging remains unaffected.
- **Hierarchy invitations are actionable chat cards:** an active BD may invite a user to become an Agency and an active Agency may invite a same-country user to become a Host. The invitation appears in the normal private conversation with **Accept / Reject** actions. Acceptance must persist the backend relationship/role; UI-only acceptance is forbidden.
- **Host Center is a real role portal, not a placeholder:** it includes weekly rewards entry, Host identity, Agency relationship/join information, Contact/WhatsApp, Diamond points/exchange/transfer, Today/Yesterday/Last 7 days/Last 30 days/This month/custom filters, host performance metrics and settlement history. Values must come from server data; unavailable telemetry must not be fabricated.
- **Agency Center is a real role portal:** Agency owner identity/contact, weekly rewards, balances/settlement, Agency Data and Host Data views, the same period filters, linked Host list/performance, and Invite Host. Host-country eligibility remains enforced server-side.
- **BD Center is a real role portal:** BD identity/contact, weekly rewards/settlement data, BD/Agency data views, linked Agency performance/Host counts, the same period filters, and Invite Agency. BD calculations continue to use Tinni's existing combined-agency target/commission policy.
- **Reference-app UI does not override Tinni economy/policy:** Host/Agency/BD targets, commissions, settlement cycles, Diamond rules, Lucky 10% social value, and owner-controlled policy remain Tinni rules even when the reference interaction pattern is copied.
- **Coin Seller transfer credential is exactly a 4-digit numeric PIN.** Digits 0000 through 9999 are structurally valid choices subject to normal security/rate controls. Coin Seller setup, transfer verification, and email-OTP reset must reject non-numeric or non-4-digit credentials. Merchant credential rules remain separate.
- **Room Lock uses a server-generated 5-digit code.** When the room owner turns Lock on, backend generates, hashes/saves, and returns a random 5-digit room password. The owner's Room Lock control displays that code in the same lock setting area. Visitors use that code to enter. The room owner bypasses their own room password and can unlock without entering it. Turning Lock off invalidates/hides the displayed code.
- **CP reference conversion is fixed to the requested economies:** reference app 45,000 coins = USD 1; Tinni 2,000,000 coins = USD 1; scale factor 44.444...x. Reference CP Heart 1,000 becomes **44,444 Tinni coins** and reference CP Invite 50,000 becomes **2,222,222 Tinni coins**.
- **CP Invite** is the confession/invitation flow and may be sent only when neither side already has an active/pending CP flow. Active CP appears on the ID/Profile CP card with the two avatars, heart/CP identity, level/intimacy/day information, and an All my CP entry to the CP area.
- **CP/VS progress:** the latest CP + VS specification below supersedes legacy normalized intimacy, Lucky contribution, exchange bonus and decay rules.


## LOCKED — Owner Full ID drill-down and zero-default Staff Panels

- **View ID remains the first compact account summary.** Tapping **Full View** from that summary opens the selected user's **Full ID Dashboard** rather than replacing the compact summary.
- **Full ID Dashboard is drill-down based.** Profile/ID, wallet/VIP, room, verification, tags, hierarchy roles, inbox/history and other supported owner controls are grouped by function; a function is opened/tapped before its deeper detail/action surface is shown.
- **Identity tags must expose removal from the selected ID view** wherever the authenticated panel has the matching exact permission. Custom/V Official tags use the protected tag-removal API. Host/Agency/BD use hierarchy-role operations instead of merely hiding the badge.
- **Host / Agency / BD labels are actionable.** Tapping an active hierarchy role from View ID or Full View opens its full role dashboard. The role dashboard must be backed by server-authoritative hierarchy data, not client-only totals.
- **Agency drill-down** shows its active Hosts, each Host ID/name, received coins, target, target progress, remaining target where applicable, join time and aggregate Agency totals. It includes Host search and authorized Host removal. Tapping a Host ID/name opens that Host's compact ID view, from which **Full View** opens the Host's Full ID Dashboard.
- **BD drill-down** shows linked Agencies, each Agency's Host count and aggregate progress, and allows authorized unlink/removal operations. Tapping an Agency/user row drills into that ID.
- **Host drill-down** shows Host target/received/progress/remaining data plus the linked Agency and relevant wallet/settlement information.
- **Hierarchy investigation date ranges are fixed:** last 7 days, last 15 days, current month, last month, plus a custom From/To date range. All role totals/targets shown for these views must be calculated from backend records for the selected range.
- **Staff Panels start with zero selected functions.** Creating or activating a Staff Panel must not automatically grant, inherit or display any Owner function. The Owner explicitly selects each function.
- **Unselected Staff functions are hidden and server-blocked.** A function with no selected permission must not appear in the Staff navigation, dashboard, buttons or drill-down controls, and its protected API/action must reject access.
- **New future Owner functions never auto-inherit into existing or new Staff Panels.** Every new function requires its own explicit Staff permission before it can appear or work.
- **Hierarchy full-detail access is separately permissioned.** `users.full_dashboard` alone does not grant Host/Agency/BD drill-down to staff; `hierarchy.view_details` is also required, while mutation permissions such as Host removal remain separate.


## Owner Master Panel A-to-Z Full-ID drill-down — LOCKED

- Full User ID/Profile is not a static summary. Every active Host, Agency and BD role is a tappable identity control with a visible Remove action when the signed-in panel has the matching hierarchy permission.
- Host / Agency / BD role tap opens the server-authoritative role dashboard. Date investigation supports last 7 days, last 15 days, this month, last month and a custom inclusive date range.
- Agency drill-down shows its active Hosts with received coins, target, progress and joined time; Host ID/name opens that Host's Full ID/Profile and Host can be removed from the Agency from the same drill-down.
- BD drill-down shows linked Agencies and their Host totals/progress; linked Agency IDs remain drillable and may be unlinked only with the explicit Agency/BD-link permission.
- Custom/V Official/Coin Seller/Merchant and other stored identity tags are tappable. Their detail layer shows tag metadata; wallet-linked identities expose their privileged-wallet status and management action when permitted. Every removable stored tag has a visible Remove action.
- BD, Agency and Host automatic identities must all be returned from backend hierarchy state; the UI must not depend on a manually duplicated custom tag.
- Full ID Dashboard sections are themselves drill-down controls: profile/ID, wallet/VIP, hierarchy, verification, room, identity/tags, messages, calls and advanced per-ID investigation.
- Any user ID exposed inside a nested Full-ID record (message participants, call participants, live room users, hierarchy members) must be tappable and open that referenced user's Full User ID/Profile. The operator can continue drilling deeper instead of reaching a dead-end summary.
- Staff sub-panels receive none of these controls by default. Full-ID and hierarchy-detail access require explicit permissions, and every mutation remains server-authoritative and audit logged.


## Final Money & Language Lock

- Host first target: **4,000,000 eligible received coins = USD 1.60**.
- Agency commission: **10% of achieved Host target earnings**. A Host below 4,000,000 eligible coins in the settlement cycle contributes **zero Agency commission**.
- BD commission is calculated from the combined qualifying Host-target earnings under the BD's Agencies: **USD 500 = 7%**, **USD 1,000 = 10%**.
- Host dollar transfer minimum remains **USD 2**.
- Agency and BD transfer only their own earned commission and may transfer from **USD 10** to an active Coin Seller or Merchant.
- Host sent/withdrawn dollar history is visible only in the Host Panel. Agency/BD panels do not expose individual Host dollar transactions.
- Agency/BD percentage commission remains a **dollar balance** and is not converted into coins.
- Dollars received by a Coin Seller or Merchant stay in that role's **Dollar Wallet as USD**. No settlement receipt automatically credits coins.
- English remains the default language until the user chooses another language.
- Create Tinni ID and Settings > Language use the same supported-language registry: English, Hindi, Urdu, Arabic, Bengali, Malayalam, Filipino (Tagalog), Persian (Farsi), Kurdish, Baluchi, Chinese (Simplified), Chinese (Traditional), Korean.
- User-generated names, room text and numeric IDs are not auto-translated; unsupported UI strings fall back to English.


## Locked Room Rocket & Game Visuals

- The floating **Rocket** uses the approved realistic stealth-black design: matte/graphite metallic body, sharp glossy black nose, dark aerodynamic fins with restrained red accents, cyan/blue glass window, metallic steel nozzle, and white-hot/yellow/orange exhaust flame. The old emoji/cartoon/simple rocket icon must not return.
- The floating **Game** button uses the compact **black-and-white keyboard/keys logo**: six white keys with black keys, compressed/flat proportions, black outer body and white edging. The old purple/pink/controller/gamepad icon must not return.
- Rocket stays above Game in the room floating stack and both continue opening their existing Rocket/Game panels without changing gift, room, seat or game logic.


## Owner Wallet & Permanent Ledger Connection Lock

- Owner Panel **Company Dollars** is backed by Worker persistent storage, not a UI-only counter. It shows current company dollar balance and a permanent ledger with sender name/ID, sender wallet type, amount, before/after balance, transaction/reference and timestamp.
- **Company dollar deduction is Owner-only**, requires an explicit USD amount, writes a permanent ledger entry and is audit logged by the Worker route.
- Owner normal-user wallet controls can add/remove **Coins or Diamonds**. Coin Seller and Merchant wallet controls remain separate.
- Coin Seller/Merchant permanent wallet ledgers record Company/Owner credits, Owner debits, coin sends to users, settlement receipts, dollar transfers, and received dollars.
- User Wallet opens permanent **Coins History**, **Diamonds / conversion history**, **Coin Seller/Merchant wallet details**, **Received Dollars** and sent-dollar history through Worker APIs.
- Dollar transfer ledger is replay-safe through unique request IDs. Coin Seller dollar-transfer minimum remains **$300** and Merchant remains **$1000** for their role-wallet transfer flow.
- Latest settlement lock: Host minimum **$2**, Agency/BD minimum **$10**; Coin Seller/Merchant settlement receipts remain USD, and no role's dollar balance is automatically converted to coins.


## Empty-Seat Invite Flow — LOCKED

- Tapping an **empty seat** as Room Owner/Admin opens the seat controls and must include an **Invite** action in addition to the existing seat controls.
- Tapping **Invite** opens a dedicated invite panel locked to the exact tapped seat number. The invite cannot silently move to or target a different seat.
- The invite panel lists only users/admins who are **currently present inside that same room** and **not currently sitting on any seat**. Users outside the room and already-seated members must never appear in this panel.
- The current Owner/Admin who opened the panel is excluded from the invite candidate list; their own seat action remains **Take Seat**.
- The invite panel includes **ID-number search**. Search results are filtered only from the eligible in-room, off-seat candidate set; an ID that is not currently inside the room must not appear or become inviteable through search.
- Selecting a candidate sends the seat invite for the **same tapped seat only**. The backend remains authoritative and must reject the invite if the target left the room, took another seat, the selected seat became occupied, or the selected seat became locked before acceptance.
- Seat invites are delivered **immediately through the live room presence socket**. On Accept, the backend re-validates that the target is still inside the room, still off-seat, and that the exact invited seat is still unlocked, unoccupied and inside the room's current seat-count range; self-invites and out-of-range seat invites are rejected server-side.
- The invited member receives an on-screen confirmation dialog identifying the inviter role and exact seat: **“Owner invites you to Seat No. X.”** or **“Admin invites you to Seat No. X.”**, with Accept and Decline actions.
- Accept places that member on the invited seat only; Decline keeps them in the audience. This flow must not be replaced by a generic room-user search or by an invite that can target users outside the room.


## Room Session Availability — LOCKED

- Room backend/presence authentication is independent from microphone permission and LiveKit voice connectivity.
- Entering a room must activate the server-authoritative room session first so seats, invites, chat, gifts, moderation, Public Screen and other non-voice room controls remain usable even when microphone permission is denied or LiveKit is temporarily unavailable.
- A failed/partial room session must never be resumed as if healthy. Re-entering the same room must reconnect the backend session whenever its authenticated room session is inactive.
- Microphone permission failure may disable voice only; it must not produce a dead room where non-voice actions return `Room session is not active`.
- LiveKit failure may report voice unavailable, but must not tear down room presence/auth or disable the rest of the room.
- All app built-in room themes, including the full `mood-*` set exposed by the client, are backend-recognized built-ins and must not be rejected as unavailable/expired.


---

## Owner Master Panel — A-to-Z Detailed Blueprint — LOCKED

This section is the code-matched functional blueprint for the standalone **Tinni Star Owner Web Panel** and its protected Worker-backed controls. It is authoritative for Owner Panel behavior unless the Platform Owner explicitly changes a rule later.

### 1. Platform separation, authentication and authority

- The Owner Panel is a **separate web control center**, not a normal Android-app page and not a Room Owner/Admin tool.
- Normal users and room owners do not automatically receive Owner Panel access.
- Owner/staff login is authenticated by the Worker. Frontend code must never contain Owner passwords, API tokens, D1 credentials, signing secrets or equivalent privileged secrets.
- The main Platform Owner has unrestricted Owner Panel authority. Custom staff panels receive only permissions explicitly selected by the Owner.
- Every server-backed sensitive change must be authorized server-side and audit logged. Hiding a button in the UI is not authorization.
- The panel includes server-health status, Refresh, Logout, Quick Action and global search.
- Global search supports current user ID, old user ID and user lookup; user investigation must resolve ID changes without losing historical account relationships.
- Main navigation contains: **Dashboard, Notifications, Users, Call Verification, Messages & Tags, Rooms, Wallets, BD / Agency / Host, Roles / Posts, VIP, Gifts, Entries / Frames, Banners, Games, Policies, Custom Panels, Audit Log**.
- Main-Owner-only capabilities include Company-dollar manual deduction, Wallet Security Freeze removal, Owner notification inbox, friend-conversation deep inspection and Owner listen-only room access unless explicitly redesigned later.

### 2. Dashboard and master control center

The Dashboard is the first Owner overview and must show server-backed values for:

- Total registered users.
- Total created/active rooms as returned by Owner state.
- Sending Today / coins received activity.
- Owner Treasury coin balance.
- Owner Treasury wallet card, separate from the Owner's normal user wallet.
- **Add Coins** to Owner Treasury.
- **Send Coins** from Owner Treasury.
- **Master Feature Switches** loaded dynamically from server configuration. Each switch is a server master flag and can be changed only by a session with policy-edit authority.
- **A-to-Z Owner Controls** module launcher for Users, Call Verification, Messages & Tags, Rooms, Wallets, BD/Agency/Host, Roles/Posts, VIP, Gifts, Entries/Frames, Banners, Games, Policies and Custom Panels.

Feature flags are data-driven. New backend flags may appear automatically and should not need code edits merely to display ON/OFF status.

### 3. Notifications / complaint routing

- App complaints and platform alerts are routed to the **main Owner notification inbox**.
- Custom staff panels do not automatically receive Owner notifications.
- Show unread count and total loaded notification count.
- Each notification shows title, source user/system, target type/ID when present, exact timestamp and message.
- Complaint metadata may include screenshots/investigation context supplied by backend.
- Owner can **Mark read**, **Delete**, and **Refresh** notifications.
- Hierarchy **Exit Requests / Complaints** opens this notification/complaint workflow.

### 4. Users — search, investigation and Owner overrides

#### 4.1 Search result

Search accepts user ID, old ID, name or email where supported. Results show:

- Display name and current user ID.
- Old-ID match indicator when resolved through a previous ID.
- Gender and country.
- Verified / Unverified.
- Coins and Diamonds.
- ID ban status.
- Device access status.
- Invisible-ID status.
- Locked-room bypass status.
- VIP level.
- Email.
- Current identity tags.
- **Open ID / Full Profile** when Full Dashboard permission is active.

#### 4.2 Owner override actions

- ID Ban / Unban, with reason.
- Device Ban / Unban.
- Invisible ID ON/OFF.
- Locked-room Bypass ON/OFF.
- Change Public ID.
- Create Unique ID.
- Change Unique ID price/duration.
- VIP Add / Remove.
- Full ID Dashboard also exposes Change User Name and Change User DP.

#### 4.3 Unique ID

- Numeric Unique ID: 4–8 digits.
- Name ID: 3–20 letters/numbers/underscore and remains Owner-Master controlled.
- Coin price; 0 means free.
- Ownership duration days; 0 means permanent.
- Owner can change price and duration later.
- Public-ID changes must preserve relevant wallet, ledger, counterparty, history and identity references.

### 5. Full ID Dashboard — selected-user A-to-Z workspace

Opening **Full ID Dashboard** creates one consolidated Owner workspace for the selected ID. Every server change remains audit logged.

Header/summary includes:

- User DP, display name, user ID, gender, country and identity tags.
- Refresh ID.
- Email.
- Coins.
- Diamonds.
- VIP.
- ID Active/Banned.
- Device Active/Blocked.
- Verified Yes/No.
- Last seen.

#### 5.1 Profile / ID Control

Actions:

- Change Name.
- Change DP.
- Change Public ID.
- Ban / Unban ID.
- Device Ban / Unban.
- Invisible ON/OFF.
- Locked-room Bypass.

#### 5.2 Wallet / VIP

Shows:

- Coins.
- Diamonds.
- Withdrawable USD.
- Settlement/commission USD.
- Coin Seller wallet status/balance.
- Merchant wallet status/balance.

Actions:

- Normal Wallet.
- Coin Seller Wallet.
- Merchant Wallet.
- VIP Add / Remove.

#### 5.3 BD / Agency / Host

- Shows active hierarchy identities for the selected ID.
- BD Add / Remove.
- Agency Add / Remove.
- Add as Host.
- Remove Host.
- Clicking Host/Agency/BD identity opens role-specific full details when permitted.

#### 5.4 Call Verification

- Shows current Verified status.
- Direct Verify when unverified and authorized.
- Remove Verified when verified and authorized.

#### 5.5 Party Rooms / Current Room

Shows current room or owned room plus recent Party Room history:

- Current vs owned-room status.
- Room name.
- Room ID.
- DP set/not set.
- Background set/not set.
- Seat count.

Actions:

- Change Room Name.
- Change Room DP.
- Change Room Background.
- Room Ban / Unban.
- View Live Users / Seats.

Recent Party Room history shows room name/ID, owner identity, current marker and last-entered timestamp.

#### 5.6 Owner listen-only room audio

For the main Owner only, when the selected user is currently in a room:

- **Listen to Current Room — no mic** obtains a protected Owner listen token.
- Owner receives remote audio only.
- Owner microphone is never published.
- **Stop Listening** disconnects and clears attached audio.
- This remains an Owner investigation function, not an ordinary room feature.

#### 5.7 Tags / Identity

Identity detail can show:

- Tag label.
- Tag ID.
- Type/kind.
- Color.
- Background.
- Assigned timestamp.
- Full ID View jump.
- Role-linked wallet/role information where applicable.

#### 5.8 Inbox / Messages

- Full Dashboard shows stored Tinni messages.
- Authorized session can send a **Tinni Official** message to the selected ID.
- Main Owner gets **Open Friend Inbox / Conversations**.

Friend Inbox shows:

- Selected user identity.
- Conversation count.
- Peer DP/name/ID.
- Friend marker.
- Message count.
- Last message.
- Last-message timestamp.

Conversation detail shows:

- Both IDs.
- Sender per message.
- Message text.
- Exact timestamp.
- Seen state.
- Back to Inbox / Close.

Owner can send an **Official reply** while inspecting a friend conversation. The reply stays from **Tinni Official** and must never impersonate the friend/peer.

#### 5.9 Call History

Shows:

- Caller ID.
- Receiver ID.
- Media type.
- Call state.
- Created/updated timestamp.
- Nested IDs can be reopened for investigation.

#### 5.10 User Activity / Advanced

- Per-user Fruit Party investigation.
- Set per-user Price / Free / Validity.
- Remove per-user price override.
- User game detail exposes Fruit Party bets, payouts and net.

### 6. Call Verification

One section with three pages:

#### Verified IDs
- List all current Verified IDs.
- Search by ID/name.
- Authorized session can remove Verified.

#### Verification Requests
- Show pending verification requests.
- Three live photos/system result may be reviewed where provided.
- Owner/reviewer makes final approve/reject decision.

#### Direct Verify
- Search existing ID/name.
- Confirm account result.
- Optional Owner note.
- Directly attach Verified without camera verification when authorized.
- Direct Verify and Revoke are separate permissions.

### 7. Messages & Tags

#### User selection
- Search ID/name/email.
- Select only required users.
- Visible selected count.
- Clear Selected.
- Search row shows identity, country/gender, tags and **Open ID**.

#### Tinni Official messages
- Message UI limit: 2000 characters.
- **Send to Selected**.
- **Send to All Users**.
- Message appears as **Tinni Official**, not fake private-friend identity.

#### Custom User Tag
- Type any allowed tag name.
- Choose tag color.
- Apply to selected IDs.
- User-specific colored tags stay separate from reusable Roles/Posts definitions.

#### V Official
- Circular official badge.
- Gold ring.
- Silver V.
- Gold Position/Designation label.
- Owner enters Position/Designation.
- Background presets:
  - Sky Blue #69C9FF
  - Light Green #8FE6A8
  - Golden #D4A72C
  - Black #101010
  - Red #D93636
  - Purple #7B3DBB
- Apply V Official to selected IDs.

#### Officials directory
- Every V Official appears in Officials.
- Each Position/Designation has its own page/tab.
- Refresh reloads current server state.
- Official user can be opened for full ID details and permitted identity controls.

### 8. Rooms

Actions:

- Room Ban / Unban.
- Change Room Name.
- Change Room DP.
- Add / Remove Background.
- View Live Users / Seats.

Live-room investigation shows server-backed:

- Room ID.
- Owner ID.
- Room name.
- Country.
- Seat count.
- Online-now members.
- Mic mode.
- Locked status.
- Live users and seat state.

#### Room Theme Manager

Create global room theme with:

- Theme name.
- HTTPS image URL / approved image data.
- Coin price; 0 means free.
- Scheduled or Permanent duration.
- Start date/time; blank means now.
- End date/time for scheduled themes.
- Remove theme when authorized.
- List shows price and active time range.
- Sexual or political themes are blocked by policy.
- Panel persists room-theme price. Actual purchase/entitlement charging must remain server-authoritative and must not be invented only from this display field.

### 9. Wallets and Company ledger

#### Normal User Wallet
- Select Coins or Diamonds.
- Enter amount.
- Add / Remove.
- Normal coin-wallet Ban / Unban.

#### Coin Seller Wallet
- Create/activate.
- Add coins.
- Remove coins.
- Ban / Unban.

#### Merchant Wallet
- Create/activate.
- Add coins.
- Remove coins.
- Ban / Unban.

#### Owner Treasury
- Separate from Owner normal-user wallet.
- Add Treasury coins.
- Send Treasury coins to Normal, Coin Seller or Merchant wallet.
- Every movement is audit logged.
- Base coin-inventory valuation may remain **2,000,000 coins = $1** where applicable, but USD wallets are independent and must never auto-convert to or be derived from coin balances.

#### Company Dollars — Owner only
- Persistent current Company USD balance.
- Receives qualifying Coin Seller/Merchant transfers.
- Owner can manually deduct a positive USD amount and optional reason.
- Ledger columns:
  - Date/time.
  - Sender name/ID.
  - Sender wallet/type.
  - Amount.
  - Before balance.
  - After balance.
  - Transaction/reference ID.
- Incoming transfers and manual deductions remain permanent audit/ledger records.

Locked related rules:

- **No automatic dollar-to-coin conversion for Host, Agency, BD, Coin Seller or Merchant.**
- Host / Agency / BD earned dollars stay in their Dollar Wallet until manually sent.
- Host / Agency / BD Dollar Wallet opens by tapping the displayed dollar balance and contains transfer history plus **Send Dollars**.
- Host / Agency / BD recipient selector shows **Coin Sellers** and **Merchants** in separate active lists with name + ID.
- Host / Agency / BD may send dollars only to the selected active Coin Seller or Merchant.
- Host dollar transfer minimum: **$2**.
- Agency / BD dollar transfer minimum: **$10**.
- Coin Seller / Merchant receive these transfers as USD in their own Dollar Wallet; receiving dollars never credits coins automatically.
- Coin Seller role-wallet dollar transfer minimum: **$300**.
- Merchant role-wallet dollar transfer minimum: **$1000**.
- Coin Seller / Merchant may send Dollar Wallet funds to **Company** or **Cryptocurrency (USDT)**.
- USDT records store destination address and payout status. Actual blockchain broadcast requires configured payout-provider/wallet integration and must not be represented as completed before provider confirmation.
- Every transfer keeps sender/receiver identity and role where applicable, USD amount, exact time, transaction/reference ID and before/after balances.

### Latest Dollar Wallet Flow — LOCKED

This latest rule replaces every older note that automatically converted settlement dollars into Coin Seller coins.

- Host, Agency, BD, Coin Seller and Merchant each keep dollars as dollars.
- Host / Agency / BD: tap dollar balance → Dollar Wallet → Send Dollars.
- Host / Agency / BD Dollar Wallet shows active **Coin Sellers** and **Merchants** separately, each with display name and ID.
- Host / Agency / BD can send only to an active selected Coin Seller/Merchant.
- Coin Seller / Merchant receives the amount into a separate USD balance, with no automatic coin credit.
- Coin Seller / Merchant: tap Total Dollars → Dollar Wallet → Send Dollars.
- Coin Seller / Merchant destinations: **Company** or **Cryptocurrency (USDT)**.
- USDT screen/flow shows address input/scanner entry surface and records a payout request. On-chain execution remains pending until a configured crypto payout provider confirms it.
- Permanent ledger fields include sender ID/type, recipient ID/type or USDT address, USD amount, timestamp, transaction/reference ID, sender balance before/after, recipient balance before/after where an internal recipient exists, and payout status for crypto.

#### Wallet Security Freeze — Owner only
- Unexpected coin credits may be quarantined and freeze affected wallet.
- Owner selects User ID and wallet type: normal, Coin Seller or Merchant.
- Only Platform Owner can remove this freeze.

### 10. BD / Agency / Host hierarchy

Controls:

- Activate / Remove BD.
- Add Agency to any BD.
- Remove Agency from BD.
- BD Targets / Commission.
- Activate / Remove Agency.
- Add Host to any Agency.
- Remove Host with Owner override.
- Exit Requests / Complaints.

Current locked rules shown in panel:

- Host can join only same-country Agency.
- Settlement: **1–15** and **16–month end**, local country time.
- Host first target: **4,000,000 received coins = $1.60**.
- Agency commission: **10% of achieved Host target payout**; no achieved target = no commission.
- BD target 1: **$500 combined agency target = 7%**.
- BD target 2: **$1,000 combined agency target = 10%**.
- Host transfer minimum: **$2**.
- Agency/BD transfer minimum: **$10**.
- Coin Seller/Merchant settlement receipts remain **USD**; no automatic coin conversion occurs. Agency/BD commission also remains USD.
- Manual Host removal/approval dates shown: **1st, 2nd, 16th, 17th**.
- Complaint timer: **1 month**, then system auto-exit if unresolved.
- After auto-exit: **48-hour** join-another-Agency window before configured diamond auto-exchange behavior.

### 11. Host / Agency / BD full-detail dashboards

Requires Full ID Dashboard plus hierarchy-detail permission.

Date filters:

- 7 Days.
- 15 Days.
- This Month.
- Last Month.
- Custom From/To.

Common stats:

- Received coins.
- Diamonds earned.
- Settlement balance.
- Withdrawable USD.

Host additionally:

- Target.
- Target progress %.
- Remaining.
- Target payout.
- Private chats.
- Followers.
- Parent Agency.

Agency additionally:

- Hosts.
- Combined target.
- Combined target progress.
- Commission %.
- Searchable Host list.
- Host row: received coins, target, progress, joined time.
- Remove Host when authorized.

BD additionally:

- Agencies.
- Hosts.
- Combined target.
- Progress.
- Target 1 amount/percent.
- Target 2 amount/percent.
- Searchable Agency list.
- Agency row can show Host totals/progress.
- Remove Agency from BD when authorized.

Role dashboard can jump back to Full ID View and remove role according to current permission.

### 12. Roles / Posts

- Reusable definitions, separate from per-user colored tags.
- Create Name + Type: **Role** or **Post**.
- Existing items support **Edit, Disable/Enable, Remove** when authorized.
- Catalog stays extensible for future reusable role/post definitions.

### 13. VIP Manager

Create/Edit fields:

- VIP name.
- VIP level.
- Display order.
- Price / requirement.
- Validity days; 0 permanent.
- Badge asset/label.
- Profile frame.
- Seat frame.
- Vehicle/animal/3D entry.
- Entry animation asset.
- Entry audio asset.
- Requirements.
- Privileges.
- Permissions/benefits.
- Special effects.
- Country targeting.
- Effective from/until.

VIP list shows Level, Name, Status, Entry, Frame, Price and Actions.

Actions:

- Create new VIP.
- Edit existing VIP.
- Enable / Disable.
- Remove.
- Grant / Remove VIP from user.

VIP-required catalog items must honor effective active VIP from either Owner-granted VIP or active purchased VIP entitlement.

### 14. Gifts and Lucky Gift settings

Gift catalog supports:

- Add.
- Edit.
- Remove.
- Enable / Disable.
- Coin price.
- Validity.
- Asset/animation URL.
- Display order.
- Country targeting.
- Effective start/end scheduling.

New Gift additionally supports:

- Lucky/Rebate flag.
- Lucky emoji.
- Maximum multiplier.
- Big-win/high-win threshold.
- Host reward %.
- Charm/Wealth %.
- Prize-pool contribution %.

Global Lucky Gift settings:

- System enabled.
- Maximum multiplier.
- Rare/high-win threshold.
- Banner threshold.
- Ultra-banner threshold.
- Host reward %.
- Charm/Wealth %.
- Prize-pool %.
- Daily rank #1/#2/#3 share percentages; total cannot exceed 100%.
- Daily send cap; 0 unlimited.
- Country-specific banners ON/OFF.
- Testing mode.
- Event mode.
- Data-driven multiplier-weight JSON.

### 15. Entries / Frames / decorative catalogs

Separate Owner catalogs:

1. Vehicle / Animal / 3D Entries.
2. Profile Cards.
3. Rings.
4. Chat Bubbles.
5. Profile Backgrounds.
6. Frames.

Common fields/actions:

- Name.
- Asset URL.
- Coin price.
- Validity days; 0 permanent.
- Display order.
- Country codes; blank all.
- Effective from.
- Effective until.
- Edit.
- Enable / Disable.
- Remove.

Entry Effects additionally support **Assign VIP level; 0 = none**.

Frames additionally support **Assign VIP level**.

Catalog authorization is resolved by item kind; decorative item controls must not fall back to unrestricted generic permission.

### 16. Banner Scheduler

- Banner title.
- Banner image URL.
- Display order.
- Country targeting.
- Start date/time.
- Auto-removal/end date/time.
- Manual removal.
- Catalog enable/disable behavior where exposed.

### 17. Games

Covers Fruit Party server-recorded activity.

Summary:

- Total Bets.
- Total Bet Coins.
- Total Payout.
- Game Status.
- Min/Max bet display.

Controls:

- Enable / Disable Games.
- Bet Limits.
- User Betting Investigation.

Investigation:

- Party total bet/payout.
- House net.
- Unique recorded players.
- Selected user Party net.
- Selected user Party bet coins.

### 18. Policies & Economy Editor

Purpose: change supported rules without editing Worker code.

Controls:

- Create New Setting key/value.
- Edit existing policy.
- Global Pricing.
- Per-user Price / Free / Validity.
- Remove User Override.

Global Pricing includes:

- Direct call coins/min.
- Random call coins/min.
- Verified receiver diamond %.
- Default room-theme coins.
- CP connect coins.
- CP disconnect coins.
- Default frame coins.
- Default VIP coins.
- Unique ID purchase coins.
- Free User IDs.

Per-user override includes:

- User ID.
- Price key.
- Custom price coins; 0 free.
- Custom purchased validity days; blank item default, 0 permanent.
- Override expiry date/time; blank no expiry.

Price-key examples include call:direct, frame:<id>, vip:<id>, entry:<id>, vehicle:<id>, profile_card:<id>, and * where backend rules permit.

### 19. Custom Staff Panels

Owner can create **10–20+** separate staff panels.

Create fields:

- Panel name.
- Optional assigned User ID.
- Staff login Gmail/Email.
- Password.
- Confirm password.
- Minimum password length: 10 characters.
- Exact selected permissions.

Existing staff controls:

- Login Active / Disabled.
- Change Gmail / Password.
- Group **All** toggle.
- Individual permission toggles.
- Blank new-password field keeps current password.

Staff starts with no powers beyond permissions Owner enables. Server session permissions remain authoritative.

### 20. Exact staff permission matrix

#### Users
- users.search — Search/view user details.
- users.full_dashboard — Open Full ID Dashboard.
- users.edit_profile — Change user name/DP.
- users.ban_id — ID ban/unban.
- users.ban_device — Device ban/unban.
- users.invisible — Invisible ID.
- users.locked_room_bypass — Locked-room bypass.
- users.change_id — Change public ID.
- users.unique_id — Create/price Unique IDs.

#### Call Verification
- verification.view — View verification pages/status.
- verification.review — Approve/reject requests.
- verification.direct_verify — Direct Verify.
- verification.revoke — Remove Verified.

#### Messages & Tags
- messaging.search — Search IDs.
- messaging.send — Send Tinni Official messages.
- messaging.tags — Create/apply user tags.
- messaging.officials — View/manage V Official positions.

#### Rooms
- rooms.search — Search/view room.
- rooms.ban — Ban/unban.
- rooms.rename — Rename.
- rooms.dp — Change DP.
- rooms.background — Add/remove background.
- rooms.live_seats — View live users/seats.
- rooms.theme_view — View themes.
- rooms.theme_create — Add/schedule themes.
- rooms.theme_remove — Remove themes.

#### Wallets
- wallets.normal — Normal wallet.
- wallets.seller — Coin Seller wallet.
- wallets.merchant — Merchant wallet.
- wallets.treasury_send — Send Treasury coins.

#### BD / Agency / Host
- hierarchy.view_details — Full role details.
- hierarchy.bd_manage — Activate/remove BD.
- hierarchy.agency_manage — Activate/remove Agency.
- hierarchy.agency_bd_link — Link/unlink Agency under BD.
- hierarchy.host_manage — Add/remove Host.
- hierarchy.targets — Targets/commission.
- hierarchy.complaints — Exit requests/complaints.

#### Roles / Posts
- roles.view — View roles/posts.
- roles.manage — Create/edit/remove reusable roles/posts.

#### VIP
- vip.view — View VIP.
- vip.create — Create VIP.
- vip.edit — Edit VIP.
- vip.toggle — Enable/disable VIP.
- vip.grant_remove — Grant/remove VIP.

#### Gifts
- gifts.view — View catalog.
- gifts.create — Add gifts.
- gifts.edit — Edit gifts/Lucky settings.
- gifts.remove — Remove/disable gifts.

#### Entries / Frames
- assets.entries — Manage vehicle/animal/3D entries.
- assets.frames — Manage frames, Profile Cards, Rings, Chat Bubbles, Profile Backgrounds.

#### Banners
- banners.view — View.
- banners.create — Create/schedule.
- banners.remove — Remove.

#### Games
- games.view — View status/stats.
- games.toggle — Enable/disable.
- games.limits — Bet limits.
- games.investigate — User betting investigation.

#### Policies
- policies.view — View policies/economy.
- policies.create — Create settings.
- policies.edit — Edit rules/feature flags.
- policies.pricing — Pricing/free rules.

#### Audit
- audit.view — View audit log.
- audit.export — Export audit log.

### 21. Audit Log and privacy

UI includes:

- Panel Activity Records summary.
- Refresh.
- Record Privacy.
- Full Audit Log.
- Export.
- Delete All Records.

Record fields include:

- Date/time/year.
- Panel/session identity.
- Action.
- Target.
- Details.

Rules:

- Main Owner sees all records.
- Staff can see only its own activity when audit.view is granted.
- Export requires permission.
- **Only main Owner can delete audit records**.
- Delete All requires explicit confirmation.
- Export downloads server-backed JSON records.

### 22. Backend/API connection contract

Owner Panel functions must use protected Worker APIs rather than local-only fake success. Functional API families include:

- Owner state/dashboard.
- Owner action dispatcher.
- User search/full user detail.
- Friend inbox/conversation inspector.
- Tinni Official messages.
- Owner notifications.
- Tags/V Official/Officials.
- Room live investigation.
- Owner listen-only token.
- Game stats.
- Call verification.
- Owner catalog.
- Room themes.
- Staff panels.
- Audit log.
- Session and health.

A UI action must not claim success when its protected server action fails.

### 23. Owner Panel regression lock

Unless explicitly changed by Platform Owner:

- Owner Panel stays separate from normal Android user and Room Owner/Admin controls.
- Main Owner remains A-to-Z authority over supported server-configurable modules.
- Staff gets only explicitly assigned permissions.
- Owner-only investigation tools do not leak to ordinary staff.
- Full ID Dashboard retains profile, wallet, hierarchy, verification, room history, messaging, call history and advanced investigation.
- Friend-conversation replies remain **Tinni Official**, never friend impersonation.
- Listen-in remains listen-only with no Owner mic publication.
- Company Dollars and audit records remain persistent server records.
- Wallet/role/catalog changes remain server-authoritative and audit logged.
- Role/tag/VIP/gift/asset/banner/policy systems remain data-driven wherever backend supports that catalog type.
- More-specific locked hierarchy, wallet, settlement, pricing and safety rules elsewhere in this blueprint remain authoritative.


## Reconnection and seat recovery — October 4, 2026

- Room WebSocket handshakes have a 15-second deadline. A late handshake, old-room snapshot, or stale socket close must never replace or clear the current room connection.
- Switching rooms or login sessions closes the previous presence transport before opening its replacement. Closing/disposal invalidates pending connections and prevents new retries.
- Recovering the same presence snapshot still notifies room controls when connectivity or an error changes. Authoritative HTTP seat placement remains usable during WebSocket recovery.
- Fruit Party shares an in-flight state refresh, bound response/header/body waits, and refreshes disconnected state before a bet. Failed authentication/server responses display their actual error. Bet submissions are never automatically replayed after an ambiguous network failure.

## App entry and confirmed action recovery — October 5, 2026

- Render the app after local session restore; remote configuration refresh runs in the background.
- Shared backend connections, response headers and response bodies have bounded waits. A timed-out mutation must never be replayed automatically.
- Confirmed unauthorized account responses expire only the matching current session and reset authenticated navigation. Temporary network errors preserve the login.
- Gift Festival uses authenticated server gift transactions and a real current-room recipient; only confirmed transactions show success and update the server wallet.
- Gifts and random room draws are not automatically retried after an ambiguous response. A successful gift transaction remains successful when secondary room visual delivery fails.
- Retrying acquisition of the same occupied seat returns authoritative state without resetting that user's microphone.
- Successful Unique ID purchases immediately synchronize the authenticated account, profile and persisted identity. Purchase controls reject concurrent submissions.

- Unique ID and store catalogs use asynchronous Durable Object RPC methods; routes must await catalog/purchase results and must never access remote private storage.

## Fruit casino presentation and smooth controls — October 5, 2026

- Fruit Party opens from the bottom and occupies half the available screen. Room activity remains visible above the game.
- Both games use clear resolution-independent fruit artwork, legible fruit names/multipliers, gold casino chips, calm highlight transitions and distinct coordinated palettes.
- Keep all existing Fruit Party server bet denominations, multipliers, settlement and Lucky 11 rules authoritative and unchanged.
- Poll state only while the game is open and the app is active; refresh at round expiry, pause timers in the background and remove listeners/timers on close.
- Only one bet submission may be pending per panel. Disable fruit/chip submissions during that request, keep the chosen amount fixed and never replay an ambiguous bet automatically.
- Reflect wallet/bet/result changes only after server confirmation. History displays real settled server rounds.
- Respect reduced-motion preferences. On short displays scroll the board while preserving access to chips, balance, history, retry and close controls.


## 2026-10-05 — Room reliability, Fruit Party Lucky and live Ludo
- Room seat/mic actions use authoritative server responses even when WebSocket is unavailable. Same-seat acknowledgements preserve microphone intent; leaving a seat commits immediately. HTTP fallback includes personal invites and mute/seat force state.
- Retry status reflects failed room contact. A healthy HTTP fallback does not show a permanent reconnect warning. Voice failures show an actionable microphone message and recover automatically; notification/Bluetooth permissions remain optional for phone microphone audio.
- Fruit Party now has Lucky 11: 3–4 server-selected rounds per two-hour window, three distinct random winning fruits with their existing Party multipliers. Existing round timings, bet denominations, balances and normal weighted outcomes remain unchanged. Settlement and all payouts are atomic and cannot be repeated by failed secondary notices.
- Room Game Center exposes Ludo. Ludo opens at the bottom in half the screen, shows four matching colour positions with actual player DP/name and room microphone state, polls live turns, and releases players when the panel closes. Mic buttons use the existing real room seat admission, approval and audio publishing rules.
- Music playback start/resume returns immediately so pause, previous, next, stop and seat-down/exit controls stay responsive.

- Room comments use a bounded server history and idempotent HTTP fallback when WebSocket is unavailable; owner/admin clear scope is preserved. Room controls and voice credentials look up authorized locked/empty rooms directly instead of using public discovery filters.

- The comment fallback only delivers comments created after the current room entry; past comments are not shown to new entrants. Late responses from a previous room cannot overwrite the current room's seat/member state.

## Cinematic gift movies — October 5, 2026

- The canonical cinematic source is `tools/cinematic` on `tinnistar`. Model all 50 Normal, 20 CP and 249 Country catalog entries, plus all ten Rocket stages, as original animated 3D geometry with individually identified movie/poster assets.
- Preserve the stealth-black integrated Rocket, attached level-specific hardware, staged vertical nine-second liftoff, white-hot/amber flames, smoke and wrapped gift celebration. Preserve all ten server milestones, reward routing and historical-stage suppression.
- Keep existing price-based gift hold durations: 5 seconds below 200K, 6 at 200K, 7 at 1M and 8 at 5M. Display one scene for the confirmed gift event, then deliver from screen center to each selected recipient exactly once.
- Bundle verified silent H.264 movies for local Android playback. Pin source/ZIP/media hashes, validate complete catalog coverage before APK packaging, cap movie size, and keep a painted fallback for decoder failure or absent assets.
- Respect effects toggles, screen disposal and app background lifecycle; stop/dispose video controllers and prevent stale completion callbacks from delivering a later gift.
- Preserve all gift prices, recipient eligibility, Lucky quantities/combo rules, Host-only Diamonds, Lucky 10% value, normal 100% value, room/game controls and unrelated locked behavior.
- Publish review sheets and the immutable movie bundle from the same `tinnistar` workflow after every scene verifies; source changes are never evidence that movies rendered or played correctly on a real device.
- Gift and Rocket cinematic movies share one fair foreground lane so neither movie hides the other. Gift scenes respect both the master Effects toggle and the Gift Effects toggle.


### Cinematic Rocket and Country follow-up (2026-10-05)

The user's latest timing and privacy instructions supersede earlier general cinematic gift holds for Country gifts:

- Rocket's total sequence is nine foreground seconds. Show the screen countdown 9→1. During 9–2, the integrated Rocket stays on the launch pad while engine pressure, exhaust and smoke grow. Only at 1 (eight elapsed seconds) does it lift off; the nine-second sequence then ends.
- After that sequence, request only the signed-in user's actual awarded Rocket reward. Coins, animated frame and medal come from the server; no other user's received gift/reward is shown. The authenticated personal-reward endpoint ignores client-supplied user IDs. Public room ranking retains sender names and rank but excludes received reward metadata. Private cards last six foreground seconds and can be closed immediately. Non-winners receive no fabricated card; historical launches do not replay.
- Country gifts retain their ordinary national flag and its correct artwork/aspect ratio. Show that flag waving at the center for exactly two foreground seconds, then run the existing selected-recipient flight. Do not substitute landmarks or a generic flag. Other gift prices, durations, destinations and wallet rules remain unchanged.
- Keep the locked seven-second server audience eligibility/payout window, ten incremental Rocket thresholds, Lucky 10%/normal 100%, and Host-only diamonds. These changes concern presentation and authenticated reward reads.

- Country follow-up: show a large centered flag stage (96% screen width, 66% screen height), with natural wind ripples. After the two-second hold, shrink the flag during its flight to the exact selected receiver ID/DP.

## 2026-10-06 — Lucky HUD and nine-second Combo

- Every successful Lucky send renews the Combo to exactly nine seconds. Taps, failed requests and requests in flight do not renew the existing deadline. Nine seconds without a successful send hides the control.
- Same gift and the same receiver set within the active window retain the Lucky session and selected quantity. A different gift, different receiver set, expired window or non-Lucky send ends continuation.
- Center HUD and queued multiplier effects use the authenticated server result and shared room timeline. The Lucky RNG, maximum configured multiplier, prize pool, prices, sender payouts, recipient eligibility, Host-only Diamonds and Lucky 10% Rocket/social value continue to use their existing server rules.


## 2026-10-06 — Realtime without automatic page refresh
Latest user instruction: remove automatic page polling and unnecessary blinking; load pages on entry and allow pull-to-refresh. Preserve room entry, seats/emojis, frame/entry effects, voice, messages, wallet and DP updates.
- Authenticated hibernating game sockets deliver server state and coalesce change notifications; game mutations stay on validated HTTP actions.
- Existing inbox socket also delivers private wallet/profile state. Wallet invalidations contain no financial values; snapshots use the authenticated attachment identity.
- Incoming messages apply their supplied payload directly. Seen acknowledgements travel on the existing socket.
- Home polling removed. Visited tabs retain state; first entry is lazy, and later entry/pull refreshes explicitly. Profile changes no longer trigger reloads on every parent rebuild.
- Public room updates and room-member profile changes push to subscribed viewers. Voice continues through LiveKit.
- No unattended empty-game alarm chain; overdue stake-bearing rounds settle before a sparse recent-result history is rebuilt. Permanent bets, wallet and company records remain intact.
- Transient room-event retention reduced to 50; session revocation checks no longer write cleanup on every authenticated request.
- Free-tier request and SQL quotas remain distinct; this change does not guarantee unlimited users or report unconnected dashboard usage.

Build note: Android installs the existing hash-pinned released media using its immutable generation-source checkout, then validates the current app catalog. Renderer development no longer blocks an unrelated transport APK. Idle mic-wave motion stops when there is no voice activity.

Realtime refresh release: app version 0.5.49+68. Fruit boards and Ludo also support pull-to-refresh. Game connection disposal cancels a pending HTTP upgrade and its timer; the release has a regression for leaving during an unfinished connection.

## 2026-10-06 — One main coin wallet and bets after closing the game

Latest explicit user instruction: Fruit Party debits the user's main total Coins wallet, and credits winnings into that same wallet. Game or app closure must not cancel a funded bet.

- New bets use the main wallet and its coin guard, frozen/banned checks and permanent debit ledger. Separate historical game balances are retained for auditing; their old starting grants are never copied into spendable main coins.
- Every bet carries a unique request ID. Duplicate delivery cannot debit twice or create a second stake. A durable game alarm exists before funds are reserved, and games recover reserved stakes after interruption.
- Server round settlement saves its receipt and payout delivery queue atomically. Main wallet credits, guard updates, bet settlement markers and permanent winning ledger entries commit together. Failed delivery retries without a game viewer and cannot duplicate credits.
- The latest personal win/lose result arrives privately through the account socket, including after app reconnect, and remains available in game history. A seen acknowledgement suppresses later repeats. Public game invalidations never include another player's balance.
- Keep intentional game visuals, bet amounts, multipliers, Lucky selection and unrelated financial rules. Idle refresh remains disabled.

- Private wallet snapshots also include seller/merchant dollar balances, and open dollar/role balance views apply them directly without polling. Snapshot timestamps include role and settlement updates.

- Storage follow-up: keep the recent 20 empty-round results; trim an older backlog by at most two empty rows per new settlement. Indexed cleanup never runs per viewer read. Every stake-bearing result, bet and financial ledger stays permanent.


## 2026-10-06 — Private cold storage, 15-day game details and current DP only

Latest explicit instructions: save as much of the free SQL storage and daily request budget as practical; use R2 for suitable old user data; keep detailed game data for a maximum of 15 days; retain only the current DP.

- Old wallet transactions move to compressed, hash-verified objects in a separate private R2 bucket. A private SQL manifest and compact reference keys preserve readable history and prevent repeat credits. Balances and guards never depend on an R2 file. A failed copy never removes its source SQL rows.
- Private chat uses phone history in APK 0.5.50+69. Received messages and downloaded photos persist in account-scoped app files, merge with server deltas and remain available offline. Photos expire on the server after 10 days. Long chats retain their newest 500 messages on the server; excess messages older than 10 days are deleted with their message notifications. Short chats remain. A photo never downloaded to a phone cannot be recovered there after expiry.
- A daily archive job moves at most sixteen 256-row wallet batches and 64 current inline DPs, bounded by a 12-second copy budget. New inline signup DPs migrate immediately when storage is available. It never runs once per page visit or heartbeat.
- Completed detailed game rounds, stakes and personal results expire after 15 days. Hourly bounded cleanup preserves pending outbox payments, compact paid-bet replay protection and lifetime accounting totals. Game details are deleted rather than accumulated in R2. Heavy legacy backlogs are drained in bounded batches; reads exclude expired game history immediately.
- R2 inventory accounts for both application media and private archives. The application uses a conservative combined 7 GB upload budget, leaving headroom under the account-level 10 GB-month allowance. Uploads reserve bytes before writing, serialize replacement keys and reconcile failures. At the budget, new writes pause. This cannot guarantee that unrelated buckets or monthly operation usage incur no charge.
- Inventory deletes obsolete DP keys (including leftovers after public ID changes) and unreferenced failed archive staging objects. It preserves every current DP and every committed archive. Same-key DP uploads replace the previous bytes; current DPs use no-store responses. Verified inline current DPs become small URLs in SQL; historical DP copies are not archived.
- Expired login OTP/reset/session rows, grants, rate windows and ribbons receive bounded cleanup. Password credentials, financial balances stay intact; private chat follows the explicit retention policy.
- App Directory schema/catalog/backfill setup is versioned and runs once per schema version, preventing repeated full-user scans on hibernation wake. Future schema/catalog changes must bump APP_SCHEMA_VERSION.
- Release signed APK 0.5.50+69 for durable local private chat. Older APKs do not retain server-deleted history in persistent app files. No unrelated game visual, gift-provider or voice-flow redesign.

## 2026-10-06 — Sender DP identity and private profile navigation

- Room All messages show the sender DP first on the left. To its right, show the sender name with official identity tags beside it, then that sender's medals on the next row, then the message text underneath. Use the same ID-resolved sender for the DP, name, tags, medals and profile action.
- Every new room message automatically scrolls the list so the newest message body is visible, including after the reader has scrolled to older messages.
- Every private conversation message shows the sender DP alongside the body without repeating sender names; the private header name remains tappable.
- Resolve room DPs, identity tags and profile actions only by the message sender's stable User ID. Duplicate, changed or reserved display names such as You and System must never select another account.
- If a room sender has left, keep the message's known DP snapshot or a neutral placeholder; never infer the current user's DP from the sender name. Messages without a sender ID cannot borrow a live member's identity or open that member's profile.
- The private conversation header name opens that exact peer User ID's public profile. Current public DP/name changes use the existing authenticated profile WebSocket subscription; persisted phone chat history keeps message content and excludes DP copies.
- Release 0.5.52+71 retains the existing authenticated private-photo access, storage retention, wallet, gift and room behavior. Replacement anime movies and external provider/device validation remain pending; an APK build alone does not complete those dependencies.

## CP + VS final separation — October 6, 2026

Latest user specification: CP is a couple bond; VS is a rivalry. They coexist with separate relationships, gift categories, progress ledgers, levels, badges, rankings and themes. VS user-facing surfaces never use Partner.

- CP accepts/rejects a request and permits one active couple per account. VS accepts/rejects a challenge independently.
- CP progress comes only from paid CP gifts exchanged inside the accepted couple. VS progress comes only from paid VS gifts exchanged inside the accepted rivalry. Normal/Luxury/Lucky gifts never raise either.
- Eligible progress is the confirmed server coin value, including quantity and actual charged price. The economy reference is 2,000,000 coins; level requirements follow the existing pattern at 100x scale. Legacy progress is converted once at 100x; it remains a historical starting balance. New contributions have immutable category/progress/pair snapshots.
- Existing supplied code defines only the 200K legacy threshold, now 20M at 100x. Later thresholds must be supplied or set independently through cp_coin_thresholds and vs_coin_thresholds. The user's 3M/6M/12M/20M examples do not establish a complete level-number mapping; do not fabricate additional steps.
- Atomic server gifting verifies wallet, debits coins, records transactions and eligible progress, calculates levels and saves a sender-scoped idempotency receipt. Reusing an ID with different payload fails. Replays do not repeat room visuals or social credit.
- CP and VS rankings use persisted server relationship progress. Disconnect requires intentional UI confirmation and a matching current pair key; completed history is retained.
- CP uses red/pink/gold, hearts, bond entrance, particles and premium level evolution. VS uses black/red/purple/silver, VS clash, electricity, sparks and aggressive level evolution, with no hearts.
- Each page shows both identities, current level, total and next-level progress, start date and elapsed days. Profiles and room seats expose the relevant identity/level.
- Owner Panel has separate CP and VS sections with name, category, price, poster, MP4, order, preview and enable/disable. Videos upload only through the protected main-owner endpoint into managed R2 storage. Android never exposes upload/edit controls.
- The app refreshes approved catalogs without an APK rebuild. Media metadata travels with confirmed gift events. A bounded player failure or reduced-motion mode uses an independent lightweight visual and never alters wallet/progress.
- Premium cinematic assets are owner-provided; source work and automated tests cannot certify unuploaded videos or hardware decoding.


### Animated room seat emotes

The room Emoji & Emotes sheet has Normal (64), Panda (25) and Enemy (25) tabs. All 114 selections animate over the seated user's DP using the server-confirmed emote and expiry. Panda emotes have custom drawn panda faces, expressions and accessories; enemy emotes have dark smoke, flame, lightning, impact, clash, cracks or apocalypse effects. Enemy contains 12 male rivals, 12 female rivals and one combined male/female clash, with All/Male/Female filters and distinct custom face art. These are free seat reactions, independent of CP/VS gifts and progress.

One shared animation clock drives the picker previews. Effects pause in the background, on hidden routes and when reduced motion is enabled. Existing Unicode seat emoji expire after three seconds; panda-01..25 and enemy-01..25 expire after five seconds. Reselecting an emote restarts its display, seat leave clears it, and clients do not send animation frames over the network. Generic gift emoji fallbacks also animate; VS gift fallbacks retain their rivalry theme.

Normal face emojis use locally drawn animated expressions: blinking eyes, changing laugh mouths, moving tears, kisses, tongue reactions, blushing, surprise, angry brows, sleepy faces and animated hand gestures. Their appearance is an actual face reaction over the seat DP, rather than a chat text bubble. Non-face emojis use matching heart/flame/spark/confetti/gesture motion.
