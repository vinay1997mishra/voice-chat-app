# Tinni Star — Locked Regression Contract

This file defines features that must survive future updates. A feature may be changed or removed only after the Platform Owner explicitly changes the requirement.

## Change-safety rule
- New builds must preserve every previously accepted feature and behavior unless the Owner explicitly replaces it.
- New functions must be additive by default.
- Refactors must preserve the existing backend contract, UI entry point, ledger/history data and tests.
- CI regression tests must fail when a locked entry point or rule is accidentally removed.

## Language
- English is the default app language.
- One shared language registry powers both Create Tinni ID and Settings > Language.
- Supported languages: English, Hindi, Urdu, Arabic, Bengali, Malayalam, Filipino (Tagalog), Persian (Farsi), Kurdish, Baluchi, Chinese (Simplified), Chinese (Traditional), Korean.
- User-generated text is never auto-translated or transliterated. Display name/ID name, room name, room comments/chat, signature/bio and similar text stay exactly in the script/language entered by the user.
- Numeric User ID / Room ID stays unchanged.
- RTL languages keep RTL capability; unsupported/localized strings fall back to English.

## Wallet
- Coins and Diamonds are separate clickable wallet blocks.
- Coins History, Seller Received Coins, Diamonds conversion/history and role wallet detail screens remain present.
- Host / Agency / BD / Coin Seller / Merchant dollar balances are separate persistent USD balances and never auto-convert into coins.
- Host / Agency / BD dollar balance is clickable and opens Dollar Wallet with history plus Send Dollars.
- Host / Agency / BD can send dollars only to an active Coin Seller or Merchant selected from separate name + ID lists.
- Host dollar transfer minimum is $2; Agency / BD minimum is $10.
- Coin Seller / Merchant histories are permanent backend/database ledgers.
- Zero Coin Seller coin balance displays as 00.
- Coin Seller / Merchant Total Dollars opens Dollar Wallet and received-dollar history.
- Coin Seller dollar transfer minimum is $300.
- Merchant dollar transfer minimum is $1000.
- Coin Seller / Merchant dollar destinations are Company or Cryptocurrency (USDT), not another role wallet.
- USDT requests keep the address, amount, sender before/after balance, timestamp, reference and payout status. Actual blockchain broadcast requires configured payout-provider confirmation.
- Successful transfers immediately debit the sender USD and are replay-safe.
- Every Host/Agency/BD → Coin Seller/Merchant transfer keeps sender/receiver IDs and roles, USD amount, timestamp, transaction ID and sender/receiver before/after balances.
- Owner Panel keeps Company Dollars ledger and manual dollar deduction.
- Company ledger keeps sender type/name/ID, amount, timestamp, reference, before balance and after balance.

## Gift and room contracts
- Gift category bar keeps Normal, Lucky, CP, Country and Luxury.
- Lucky quantity selector keeps + and preset quantities 9/21/51/99/199/599/899/2999/7999.
- Popular and New must show only rooms with at least one currently live room member. A stale saved room count must never keep an empty room in these public feeds.
- Room comments show the sender DP on the left, the sender name with official tags beside it, that sender's medals underneath, and the message text below the medals. Resolve all identity fields and profile taps by sender User ID; duplicate or reserved names cannot borrow another account's DP, tags or medals. Tags/medals must not appear beside seat names, in the old separate live-tag strip, or in the member-profile tag sections.
- Room comments automatically follow the newest message, and the latest readable comment-tag sizing stays preserved.
- The room Game Center keeps the floating game logo; the old duplicate Game tool must not return.
- The floating Game logo is locked to a **compact black-and-white keyboard/keys design** with **6 white keys plus black keys** and a slightly compressed/flat shape. The old purple/pink controller icon must not return.
- Lucky Gift social/counting value is fixed at 10% for seat received value, Host diamonds, room ranking/room experience, Rocket progress and CP intimacy. Non-Lucky gifts count 100%.
- A non-Host recipient receives no diamonds; activating Host eligibility is required before gift diamonds can be credited.
- Rocket keeps 10 stages: 8M, 15M, 30M, 50M, 90M, 150M, 200M, 250M, 350M and 500M.
- The floating Rocket visual is locked to the approved **realistic stealth-black design**: matte/graphite metallic body, sharp glossy black nose, dark fins with red accents, cyan/blue glass window, steel nozzle, and white-hot/yellow/orange exhaust flame. The old pink/purple cartoon rocket icon must not return.
- User-created room names and comments are stored/displayed as entered, without automatic translation.
- Room public ID remains the owner User ID.
- The room must not show the old **“Ask your followers to support the room.”** topic/support banner.
- The room must not show the old floating Lucky-result/history card stack (for example repeated **Royal Treasure Box / Won ... coins / ...×** cards). Lucky gifts and combo logic remain functional; only that floating feed UI is removed.
- Seat layout maximum is locked to **6 seats per row × 7 rows** for 42 seats: 42 = 6+6+6+6+6+6+6.
- Seat counts 37–42 use 7 rows and keep the same balanced final-two-row distribution rule; 31–36 use 6 rows.

## Retired generic Feature Center
- The generic **Feature Center** screen is permanently retired from the Android app and must not be re-added unless the Platform Owner explicitly requests it.
- CP **Bind with CP** opens the dedicated CP flow only; it must never route to a generic feature menu.
- Home/Event shortcuts must route to their dedicated destinations (CP Ranking, Family Ranking, Gifts, VIP, Discover/Rankings) and must never recreate a generic Feature Center.

## Mine / profile
- Existing locked Mine menu/order and reference-video rules in TINNI_PRODUCT_BLUEPRINT.md remain authoritative.
- **Personal information** and **Props** are retired from the Mine menu and must not be re-added unless the Platform Owner explicitly requests them again.
- Owner web controls remain separate from the normal Android user app.

## Future additions
When a new Owner-approved function is added, add its durable rule to this contract or another referenced locked blueprint and add/extend a regression test in the same change.
