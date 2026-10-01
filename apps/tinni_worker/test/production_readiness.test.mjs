import fs from "node:fs";
import assert from "node:assert/strict";

const index = fs.readFileSync(new URL("../src/index.js", import.meta.url), "utf8");

assert.match(
  index,
  /findUserByExactPublicId\(\s*targetUserId,?\s*\)/,
  "Room admin assignment must resolve only an exact public ID",
);
assert.doesNotMatch(
  index,
  /targetMatches = await getAppDirectoryStore\(env\)\.searchUsers/,
  "Room admin assignment must not use broad display-name search",
);
assert.match(
  index,
  /livekit_configured:\s*Boolean\(/,
  "App config must report LiveKit availability without exposing credentials",
);
assert.match(
  index,
  /effect_media_configured:\s*Boolean\(env\.EFFECT_MEDIA\)/,
  "App config must report R2 media binding availability",
);

console.log("Production readiness guards passed");

assert.match(
  index,
  /facebook_configured:\\s*Boolean\\(env\\.FACEBOOK_APP_ID && env\\.FACEBOOK_APP_SECRET\\)/,
  "Facebook login must be available when Facebook credentials are configured",
);

console.log("Facebook login readiness guard passed");
