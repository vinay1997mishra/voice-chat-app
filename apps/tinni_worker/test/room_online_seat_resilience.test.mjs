import fs from "node:fs";
import assert from "node:assert/strict";
import test from "node:test";

const index = fs.readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
const presence = fs.readFileSync(new URL("../src/room_presence.js", import.meta.url), "utf8");
const directory = fs.readFileSync(new URL("../src/app_directory.js", import.meta.url), "utf8");

test("seat actions self-heal a missing room membership", () => {
  assert.match(index, /async function ensureRoomPresenceMember\(/);
  assert.match(
    index,
    /room-presence\/seat-take"[\s\S]{0,1800}ensureRoomPresenceMember\([\s\S]{0,900}store\.takeSeat\(/,
  );
  assert.match(
    index,
    /room-presence\/live"[\s\S]{0,1800}ensureRoomPresenceMember\(/,
  );
});

test("room join and fallback heartbeat preserve mic state", () => {
  assert.match(index, /mic_enabled:\s*body\.mic_enabled === true/);
});

test("transient websocket loss keeps room membership instead of exiting", () => {
  assert.match(
    presence,
    /_markDirectorySocketDisconnected\([\s\S]{0,900}directory\.touchPresence\([\s\S]{0,300}false/,
  );
  assert.match(
    presence,
    /_handleSocketDisconnect\([\s\S]{0,1300}_markDirectorySocketDisconnected\(/,
  );
});

test("public room online count comes from live user presence", () => {
  const start = directory.indexOf("async listRooms()");
  const end = directory.indexOf("\n  _pruneRoomThemes(", start);
  assert.ok(start >= 0 && end > start);
  const listRooms = directory.slice(start, end);
  assert.match(listRooms, /FROM app_user_presence/);
  assert.match(listRooms, /room_socket_connected/);
  assert.match(listRooms, /last_seen >= \?/);
  assert.doesNotMatch(listRooms, /LEFT JOIN app_room_presence_counts/);
});
