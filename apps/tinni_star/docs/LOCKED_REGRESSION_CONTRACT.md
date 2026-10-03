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
- Coin Seller / Merchant histories are permanent backend/database ledgers.
- Zero Coin Seller balance displays as 00.
- Coin Seller dollar transfer minimum is $300.
- Merchant dollar transfer minimum is $1000.
- Coin Seller may send dollars to Merchant or Company; Merchant may send dollars to Company.
- Successful dollar transfer immediately debits sender balance and is replay-safe.
- Owner Panel keeps Company Dollars ledger and manual dollar deduction.
- Company ledger keeps sender type/name/ID, amount, timestamp, reference, before balance and after balance.

## Gift and room contracts
- Gift category bar keeps Normal, Lucky, CP, Country and Luxury.
- Lucky quantity selector keeps + and preset quantities 9/21/51/99/199/599/899/2999/7999.
- Popular and New must show only rooms with at least one currently live room member. A stale saved room count must never keep an empty room in these public feeds.
- Room comments keep identity/official tags inside the comment line; tags/medals must not appear beside seat names, in the old separate live-tag strip, or in the member-profile tag sections.
- Room comments automatically follow the newest message, and the latest readable comment-tag sizing stays preserved.
- The room Game Center keeps the reference-style floating game logo; the old duplicate Game tool must not return.
- Lucky Gift social/counting value is fixed at 10% for seat received value, Host diamonds, room ranking/room experience, Rocket progress and CP intimacy. Non-Lucky gifts count 100%.
- A non-Host recipient receives no diamonds; activating Host eligibility is required before gift diamonds can be credited.
- Rocket keeps 10 stages: 8M, 15M, 30M, 50M, 90M, 150M, 200M, 250M, 350M and 500M.
- User-created room names and comments are stored/displayed as entered, without automatic translation.
- Room public ID remains the owner User ID.

## Mine / profile
- Existing locked Mine menu/order and reference-video rules in TINNI_PRODUCT_BLUEPRINT.md remain authoritative.
- **Personal information** and **Props** are retired from the Mine menu and must not be re-added unless the Platform Owner explicitly requests them again.
- Owner web controls remain separate from the normal Android user app.

## Future additions
When a new Owner-approved function is added, add its durable rule to this contract or another referenced locked blueprint and add/extend a regression test in the same change.
