import fs from "node:fs";
import assert from "node:assert/strict";

const index = fs.readFileSync(new URL("../src/index.js", import.meta.url), "utf8");

assert.match(
  index,
  /if \(url\.pathname === "\/profile-media" && request\.method === "DELETE"\)[\s\S]{0,1700}body\.confirm_remove !== true/,
  "Profile media delete must require explicit confirmation",
);
assert.match(
  index,
  /profiles\/" \+ userId \+ "\/" \+ slot/,
  "Profile media must stay in the stable per-user/per-slot R2 key until replaced or explicitly deleted",
);
assert.match(
  index,
  /removed_explicitly:\s*true/,
  "Profile media delete response must mark deliberate removal",
);

console.log("Profile cover persistence guards passed");
