import fs from "node:fs";
import assert from "node:assert/strict";

const directory = fs.readFileSync(new URL("../src/app_directory.js", import.meta.url), "utf8");
const ownerApp = fs.readFileSync(new URL("../../tinni_owner_panel/app.js", import.meta.url), "utf8");

assert.match(directory, /ownerUserDetail\(userIdValue\)/);
assert.match(directory, /ownerRoomLockDetails\(roomIdValue\)/);
assert.match(directory, /display_password/);
assert.match(directory, /current_room:/);
assert.match(directory, /recent_rooms:/);
assert.match(directory, /FROM app_recent_rooms rr/);
assert.match(directory, /FROM direct_messages d/);
assert.match(directory, /FROM app_calls/);

assert.match(ownerApp, /async function openOwnerFullDashboard\(userId\)/);
assert.match(ownerApp, /Inbox \/ Messages/);
assert.match(ownerApp, /Call History/);
assert.match(ownerApp, /Party Rooms \/ Current Room/);
assert.match(ownerApp, /Recent Party Rooms/);
assert.match(ownerApp, /Listen to Current Room — no mic/);
assert.match(ownerApp, /View Live Users \/ Seats/);
assert.match(ownerApp, /Normal Wallet/);
assert.match(ownerApp, /Locked Room Password/);
assert.match(ownerApp, /ownerRoomLock\.room_password/);
assert.match(ownerApp, /BD \/ Agency \/ Host/);

console.log("Full ID Dashboard message, Party Room and activity guards passed");
