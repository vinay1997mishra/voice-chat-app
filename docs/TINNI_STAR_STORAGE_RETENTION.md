# Tinni Star storage policy

Game details: 15 days. Cleanup runs hourly in bounded batches; unfinished payouts are retained until acknowledged. Financial replay guards and aggregate wallet accounting are retained separately.

User DP: one current object per user. A replacement deletes a superseded key; inventory removes obsolete leftovers after ID changes. No DP-history archive is created.

Wallet history: financial source rows older than 30 days are compressed and verified in private R2 before SQL removal. Compact reference keys remain for repeat-payment protection. Historical API reads remain authenticated.

Messages: long, seen message payloads older than 30 days move into private R2; SQL keeps identity, timestamps, read state and access checks. Thread previews remain available without archive reads.

Application R2 capacity: media plus private archives have a conservative 7,000,000,000-byte upload budget. Inventory includes existing objects. New writes pause while inventory is incomplete or the budget would be exceeded. Current media and committed financial/chat archives are never deleted just to make room. Unrelated account buckets and monthly R2 operations still require Cloudflare usage monitoring.

Maintenance does not poll the app: one shared directory alarm checks game retention hourly; cold copying/inventory is daily, with bounded continuation after an incomplete scan. No new APK is required.
