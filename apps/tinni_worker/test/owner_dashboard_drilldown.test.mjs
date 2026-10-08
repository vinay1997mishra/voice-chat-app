import fs from "node:fs";
import assert from "node:assert/strict";

const html = fs.readFileSync(new URL("../../tinni_owner_panel/index.html", import.meta.url), "utf8");
const app = fs.readFileSync(new URL("../../tinni_owner_panel/app.js", import.meta.url), "utf8");
const index = fs.readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
const directory = fs.readFileSync(new URL("../src/app_directory.js", import.meta.url), "utf8");

assert.match(html, /data-dashboard-list="users"/, "Total IDs dashboard card must be tappable");
assert.match(html, /data-dashboard-list="rooms"/, "Total Rooms dashboard card must be tappable");
assert.match(html, /id="allUsersResult"/, "Users view must contain the all-ID list");
assert.match(html, /id="allRoomsResult"/, "Rooms view must contain the all-room list");
assert.match(app, /loadAllOwnerUsers/, "Owner Panel must load registered IDs from the dashboard");
assert.match(app, /loadAllOwnerRooms/, "Owner Panel must load created rooms from the dashboard");
assert.match(index, /\/api\/owner\/users\/all/, "Worker must expose paginated owner ID listing");
assert.match(index, /\/api\/owner\/rooms\/all/, "Worker must expose paginated owner room listing");
assert.match(directory, /ownerListUsersPage/, "Directory must page registered IDs safely");
assert.match(directory, /ownerListRoomsPage/, "Directory must page rooms safely");
assert.match(index, /getRoomPresenceStore\(env, String\(room\.id\)\)/, "Live room lookup must use stable internal room ID");
assert.match(app, /Choose theme image from phone/, "Room themes must support phone image import");
assert.match(app, /Choose banner image from phone/, "Banners must support phone image import");
assert.match(app, /uploadOwnerPanelImage/, "Owner panel must upload phone images");
assert.match(app, /Remove Theme/, "Room Theme Manager must expose an explicit remove button");
assert.match(index, /\/api\/owner\/panel-media/, "Worker must expose owner panel image upload");
assert.match(index, /owner-panel\/.*themes/, "Theme uploads must use R2 media storage");
assert.match(index, /owner-panel\/.*banners/, "Banner uploads must use R2 media storage");

console.log("Owner dashboard drill-down wiring passed");
