import fs from "node:fs";
import assert from "node:assert/strict";

const index = fs.readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
const directory = fs.readFileSync(new URL("../src/app_directory.js", import.meta.url), "utf8");

assert.match(
  index,
  /Name ID can only be created or assigned from the Owner Master Panel/,
  "Name ID owner-only API guard is required",
);
assert.match(
  index,
  /filter\(\(row\) => \/\^\\d\{4,8\}\$\//,
  "User unique-ID catalog must expose numeric IDs only",
);
assert.match(
  directory,
  /Name ID cannot be purchased or claimed by a user/,
  "Direct self-service Name ID purchase must be blocked",
);

console.log("Owner-only Name ID rules passed");
