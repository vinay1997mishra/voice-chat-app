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

## Dollar wallets and role-wallet transfers
- No Host, Agency, BD, Coin Seller or Merchant dollar balance is automatically converted into coins.
- Host / Agency / BD keep earned dollars in a persistent Dollar Wallet. Tapping the dollar balance opens the Dollar Wallet with balance, transfer history and Send Dollars.
- Host / Agency / BD Send Dollars lists active Coin Sellers and active Merchants in separate sections. Each row shows name and ID; only an active selected role-wallet can receive the transfer.
- Host minimum dollar transfer is $2. Agency / BD minimum dollar transfer is $10.
- Coin Seller / Merchant receive Host / Agency / BD transfers as USD in their own Dollar Wallet; receiving dollars must not change their coin balance.
- Zero Coin Seller coin balance displays as 00.
- Coin Seller / Merchant role-wallet detail keeps Total Coins and a separate Total Dollars / Dollar Wallet block.
- Dollar Wallet shows current available USD, permanent received history and Send Dollars.
- Coin Seller dollar-transfer minimum is $300.
- Merchant dollar-transfer minimum is $1000.
- Coin Seller / Merchant may send their Dollar Wallet balance to Company or create a Cryptocurrency (USDT) payout request.
- USDT flow stores the destination USDT address and payout status. Actual blockchain broadcast requires the configured crypto payout provider/wallet integration; the app must not falsely report an on-chain transfer before that provider confirms it.
- A successful Company transfer immediately debits sender USD so the same dollars cannot be reused. A USDT payout request reserves/debits the requested USD and remains traceable by status.
- Failed transfers do not debit.
- Replay-safe transfer requests use a unique request ID.
- Coin inventory valuation may still use 2,000,000 coins = $1 where applicable, but USD balances are independent and are never derived from or automatically converted into coin balances.

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
