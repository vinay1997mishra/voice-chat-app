# Tinni Star Wallet & Language Blueprint

This file is a locked regression contract. Future updates must preserve these rules unless the Platform Owner explicitly changes them.

## Default language
- Tinni Star opens in English by default.
- Hindi, Urdu or another supported UI language appears only after the user selects it in Language Settings or selects it while creating the Tinni ID.
- Create Tinni ID and Settings use the same central supported-language registry.
- Supported languages include English, Hindi, Urdu, Arabic, Bengali, Malayalam, Filipino (Tagalog), Persian (Farsi), Kurdish, Baluchi, Chinese (Simplified), Chinese (Traditional) and Korean.
- User-generated content is not auto-translated or transliterated. Display name, room name, room comments/chat, signature/bio and similar text stay exactly as entered.
- Numeric User ID / Room ID is never translated.

## Normal wallet
- Coins and Diamonds are separate clickable wallet blocks.
- Coins History shows current balance, sent gifts, gift name, recipient name/ID, coins and exact date/time.
- Coins Received shows Coin Seller/Merchant source name/ID, amount and date/time.
- Diamonds shows current diamonds, Convert and permanent conversion history.
- Wallet histories are backend/database records, not temporary local-only lists.

## Coin Seller / Merchant wallets
- Zero Coin Seller balance displays as 00.
- Role-wallet card opens a detailed wallet.
- Detail page shows Total Coins and Total Dollars.
- Total Dollars opens Received Dollars with sender name/ID, date/time, amount and total received.
- Company credit/transfer and sent transactions remain permanently queryable.
- Coin Seller dollar-transfer minimum is $300.
- Merchant dollar-transfer minimum is $1000.
- Coin Seller may send dollars to an active Merchant or Company.
- Merchant may send dollars to Company.
- A successful dollar transfer immediately debits the sender so the same available dollars cannot be reused.
- Failed transfers do not debit.
- Completed transfers are replay-safe through a unique request ID.
- Fixed privileged-wallet value is 2,000,000 coins = $1.

## Company dollars / Owner Master Panel
- Company receives Coin Seller/Merchant dollar transfers into a permanent Company ledger.
- Owner sees sender type, sender name, sender ID, amount, exact date/time, transaction/reference ID, before balance and after balance.
- Owner can manually enter a dollar amount and deduct it after confirmation.
- Incoming Company dollar transfers and Owner deductions are permanent ledger/audit records.

## Gift counting
- Lucky Gift social/counting value is 10%.
- Non-Lucky gifts count 100%.
- Lucky Gift 10% applies to seat received value, Host diamonds, room ranking/room experience, Rocket progress and CP intimacy.
- Non-Host recipients receive no gift diamonds until Host is active.

## ID changes
- User ID changes must preserve/migrate wallet, dollar, diamond-conversion, sender/recipient/counterparty and Company-ledger references so history is not lost.
