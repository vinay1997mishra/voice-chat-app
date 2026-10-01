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
  /public_id TEXT/,
  "Rooms must have a public room ID separate from the stable internal room key",
);

assert.match(
  directory,
  /UPDATE app_rooms SET owner_id = \?, public_id = \?, updated_at = \? WHERE id = \?/,
  "ID change must keep the existing room and update only its owner/public ID",
);

assert.doesNotMatch(
  directory,
  /UPDATE app_rooms SET id = \?, owner_id = \?, updated_at = \? WHERE id = \?/,
  "ID change must not rename the internal room key or create a new room identity",
);

assert.match(
  directory,
  /public_id: row\.public_id \? String\(row\.public_id\) : String\(row\.id\)/,
  "Room APIs must expose the changed public room ID",
);

assert.match(
  directory,
  /for \(let depth = 0; depth < 12; depth \+= 1\)/,
  "Old auth sessions must follow chained public-ID migrations",
);

console.log("ID-change room preservation rules passed");
