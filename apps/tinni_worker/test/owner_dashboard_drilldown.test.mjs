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
assert.match(app, /Delete Theme/, "Room Theme Manager must expose an explicit delete button");
assert.match(index, /\/api\/owner\/panel-media/, "Worker must expose owner panel image upload");
assert.match(index, /owner-panel\/.*themes/, "Theme uploads must use R2 media storage");
assert.match(index, /owner-panel\/.*banners/, "Banner uploads must use R2 media storage");

console.log("Owner dashboard drill-down wiring passed");


assert.match(app, /100% fit target: 1080 × 1920 px \(9:16\)/, "Theme upload must show exact fit size");
assert.match(app, /100% fit target: 1080 × 508 px \(~2\.13:1\)/, "Banner upload must show exact fit size");
assert.match(app, /Crop \/ Fit Image/, "Theme and banner import must expose crop controls");
assert.match(app, /data-owner-crop-zoom/, "Crop editor must support zoom");
assert.match(app, /data-owner-crop-x/, "Crop editor must support horizontal positioning");
assert.match(app, /data-owner-crop-y/, "Crop editor must support vertical positioning");
assert.match(app, /Delete Theme/, "Existing themes must expose delete");
assert.match(app, /Delete Banner/, "Existing banners must expose delete");
assert.match(directory, /deletePanelRoomTheme\(themeIdValue\)/, "Theme deletion must be server-backed");
assert.match(directory, /UPDATE app_rooms SET theme_id='royal-dark'/, "Deleting an active theme must reset linked rooms");
