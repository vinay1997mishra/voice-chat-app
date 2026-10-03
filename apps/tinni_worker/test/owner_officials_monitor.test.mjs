import fs from "node:fs";
import assert from "node:assert/strict";

const index = fs.readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
const directory = fs.readFileSync(new URL("../src/app_directory.js", import.meta.url), "utf8");
const ownerPanel = fs.readFileSync(
  new URL("../../tinni_owner_panel/app.js", import.meta.url),
  "utf8",
);
const ownerHtml = fs.readFileSync(
  new URL("../../tinni_owner_panel/index.html", import.meta.url),
  "utf8",
);

assert.match(directory, /listOfficials\(\)/, "Owner directory must list V Officials");
assert.match(directory, /ownerUserDetail\(userIdValue\)/, "Owner must have consolidated user detail");
assert.match(index, /\/api\/owner\/officials/, "Officials API must exist");
assert.match(index, /\/api\/owner\/user-detail/, "Full user profile API must exist");
assert.match(ownerHtml, /id="officialsPanel"/, "Messages & Tags must expose Officials panel");
assert.match(ownerPanel, /data-owner-open-profile/, "Search/Officials must open full ID profile");
assert.match(ownerPanel, /Edit Position/, "Official position must be editable");
assert.match(ownerPanel, /Remove Official/, "Official tag must be removable");

assert.match(index, /\/api\/owner\/listen-token/, "Owner listen-only token API must exist");
assert.match(
  index,
  /canPublish:\s*false,[\s\S]{0,120}canSubscribe:\s*true,[\s\S]{0,120}canPublishData:\s*false/,
  "Owner monitor token must be subscribe-only",
);
assert.match(index, /room\.listen_only\.start/, "Owner listening must be audit logged");
assert.match(ownerPanel, /Listen to Room — no mic/, "Owner profile must expose explicit listen-only control");
assert.match(ownerPanel, /microphone disabled/, "Owner listen UI must confirm microphone is disabled");

console.log("Owner Officials/full-profile/listen-only guards passed");
