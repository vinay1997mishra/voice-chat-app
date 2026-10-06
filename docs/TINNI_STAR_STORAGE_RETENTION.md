# Tinni Star storage policy

Game details: 15 days. Cleanup runs hourly in bounded batches; unfinished payouts are retained until acknowledged. Financial replay guards and aggregate wallet accounting remain separately.

User DP: one current object per user. Replacement and inventory remove obsolete objects, including leftovers after ID changes. No DP-history archive is created.

Wallet history: source rows older than 30 days are compressed and verified in private R2 before SQL removal. Compact reference keys prevent repeated payments. Historical reads remain authenticated. Financial archives are preserved when capacity fills.

Private chat: retain the newest 500 messages per conversation on the server. Excess messages become eligible for deletion after 10 days, so photos get their retention window first. Short conversations do not expire just because they are old. Hourly cleanup deletes bounded batches of excess SQL messages and their duplicated message notifications.

Chat photos: server access expires after 10 days; maintenance deletes the R2 objects. A photo record can remain among the newest 500 messages so a previously downloaded local copy still displays. Bucket inventory also removes expired photo objects and orphaned uploads.

Android version 0.5.50+69 stores received messages and downloaded photos in account-scoped application support files. Re-entry merges server messages with phone history rather than replacing it. WebSocket messages and successful sends are saved locally. Photos fetched in chat/inbox and newly received photos are downloaded once and reused offline, including the full-screen viewer. Sent photos are saved directly from their upload bytes. Photos that were never downloaded cannot be recovered after server expiry. Clearing app data, uninstalling, or changing phones removes access to that phone's history. The server does not back up deleted private chat. Old APKs do not provide this durable local history.

R2 budget: media and private archives have a combined conservative 7,000,000,000-byte upload cap. Inventory counts existing objects; uploads pause while inventory is incomplete or capacity would be exceeded. Expired photos and obsolete DPs free space; current DPs and financial history are retained. Unrelated account buckets and monthly operations still need usage monitoring; this is not an account-wide billing guarantee.

Maintenance uses shared Durable Object alarms, not app polling. Game/chat cleanup runs hourly, archive copying/inventory daily with bounded continuation. SQL deletion and R2 physical cleanup drain bounded backlogs, so eligibility is immediate but large existing backlogs can take more than one sweep.
