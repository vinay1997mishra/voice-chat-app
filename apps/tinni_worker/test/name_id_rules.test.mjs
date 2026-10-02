import fs from "node:fs";
import assert from "node:assert/strict";

const directory = fs.readFileSync(
  new URL("../src/app_directory.js", import.meta.url),
  "utf8",
);
const index = fs.readFileSync(
  new URL("../src/index.js", import.meta.url),
  "utf8",
);

assert.match(
  directory,
  /\^\[A-Za-z\]\[A-Za-z0-9_\]\{2,19\}\$/,
  "Owner-approved Name IDs must be supported",
);
assert.match(
  directory,
  /Name ID must be added from Owner Panel first/,
  "Arbitrary display names must not become IDs",
);
assert.match(
  index,
  /\/users\/exact-id/,
  "Exact public-ID lookup endpoint must exist",
);
assert.match(
  directory,
  /WHERE LOWER\(u\.user_id\) = LOWER\(\?\)/,
  "Exact Name ID search must match the user ID, not display name",
);

console.log("Name ID rules passed");
