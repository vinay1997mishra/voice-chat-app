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
- **CP intimacy rules:** regular gifts use 100% of the normalized reference-coin intimacy value; Lucky gifts use 10%; same-day mutual CP gifting gives the eligible gift a 1.2x exchange multiplier; known first level threshold is Lv.1 -> Lv.2 at 200K intimacy; level-cycle duration is 7 days; after 3 consecutive days without intimacy, decay starts on day 4 at 5% per day until activity resumes. Do not invent later level thresholds that were not supplied; keep later thresholds owner-configurable.


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
- Dollars received by a Coin Seller convert immediately into the seller coin wallet at **USD 1 = 2,220,000 coins**. This special settlement conversion does not change the normal Tinni base economy constant used elsewhere.
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
- Latest settlement lock remains unchanged: Agency/BD transfer minimum **$10**; Coin Seller settlement receipts convert immediately at **$1 = 2,220,000 seller coins**; Agency/BD commission remains dollars.


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
