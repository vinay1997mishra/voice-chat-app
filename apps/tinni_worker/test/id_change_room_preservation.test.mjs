import fs from "node:fs";
import assert from "node:assert/strict";

const directory = fs.readFileSync(new URL("../src/app_directory.js", import.meta.url), "utf8");

assert.match(
  directory,
  /const ownerId = this\._resolveOwnerUserId\(ownerIdValue\);/,
  "Room creation must resolve migrated user IDs before checking ownership",
);

assert.match(
  directory,
  /UPDATE app_rooms SET id = \?, owner_id = \?, updated_at = \? WHERE id = \?/,
  "Existing owner room must be renamed instead of creating a new room",
);

for (const table of [
  "app_recent_rooms",
  "app_user_presence",
  "app_room_presence_counts",
  "room_realtime_events",
  "gift_transactions",
  "room_follows",
  "room_memberships",
  "ludo_room_sessions",
]) {
  assert.match(
    directory,
    new RegExp("\\[\\\"" + table + "\\\",\\\"room_id\\\"\\]"),
    table + " must migrate to the new room ID",
  );
}

assert.match(
  directory,
  /for \(let depth = 0; depth < 12; depth \+= 1\)/,
  "Old auth sessions must follow chained public-ID migrations",
);

console.log("ID-change room preservation rules passed");
