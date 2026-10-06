# Realtime request and storage budget

## Requested behaviour
Load once when entering a page, allow pull-to-refresh, and apply real events without reloading the page. Do not run idle HTTP polling. Preserve intentional entry/frame/gift effects and voice; remove fruit-board chase flashing.

## Transport
The existing authenticated inbox Durable Object socket carries direct messages, account invalidations, private wallet/profile snapshots and optional public room updates. Fruit games and Ludo have authenticated game sockets which use hibernating connections. Only changed state causes debounced socket reads; countdowns use the device clock. Bets, transfers, payments, rolls and moves retain existing server validation and ledger rules. Network reconnection uses capped exponential backoff. Voice stays on LiveKit.

Home no longer performs its two-minute HTTP refresh. Production fruit panels and Ludo no longer perform their two-second state polling: this removes 1,800 repeated HTTP state reads per player-hour while a game remains open. Entry, explicit refresh and real user actions still generate requests. Room fallback recovery is sparse and only used when its existing live connection is unavailable.

## Storage
Stop empty-game alarm chains when there are no connected game viewers or pending stakes. Catch up overdue bet-bearing rounds directly after idle time; never skip or delete a financial bet or settled payout. Retain at most seven newly generated empty historical rounds after idle periods. Existing financial history is retained. The temporary room realtime event buffer keeps 50 entries per room rather than 500. Revocation lookup filters expiry without a DELETE on every authentication; revocation mutation still cleans expired records.

## Quotas and verification
Cloudflare Workers Free has 100,000 requests/day. Durable Object Free requests, SQL row reads/writes, storage and active duration have separate accounting. Hibernation reduces idle duration; WebSocket messages and reconnection are not unlimited. The documented 5 GB here is Durable Object SQL storage, not a combined quota for all Cloudflare products. Consult the account dashboard for actual usage: no Cloudflare dashboard credentials were available in this session.

Sources: https://developers.cloudflare.com/workers/platform/limits/ and https://developers.cloudflare.com/durable-objects/platform/pricing/

Regression checks cover private identity scoping, per-room game notifications, no idle panel HTTP reads, real socket handshakes, wallet push, revocation read-only behaviour, overdue settlement and idle alarms. Release packaging must continue to validate the independently pinned gift-media bundle.

## Closing a funded game
Both Fruit games now use the main Coins wallet. Funded stakes keep their server alarm and recover after interrupted reservation delivery. Winning credits and their permanent audit entries are replay-safe. Pending payout delivery retries without viewers; it is removed after acknowledgment. Latest personal results use two bounded account rows per user and the existing private socket, rather than polling or an ever-growing notification feed. Historical financial records remain intact.

Empty-result history converges to the latest 20 rounds. Indexed pruning removes at most two old zero-stake rows per actual new settlement, avoiding an unrestricted cleanup write burst. Stake-bearing results and permanent financial records are retained.
