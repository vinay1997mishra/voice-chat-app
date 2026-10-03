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
assert.match(
  index,
  /image_moderation_configured:\s*Boolean\(env\.AI \|\| env\.IMAGE_MODERATION_URL\)/,
  "App config must report image moderation availability",
);
assert.match(
  index,
  /await enforceImageSafety\(env, \{[\s\S]*surface: "room_dp"/,
  "Room DP upload must pass server-side image moderation before storage",
);
assert.match(
  index,
  /await enforceImageSafety\(env, \{[\s\S]*surface: "profile_" \+ slot/,
  "Profile media upload must pass server-side image moderation before storage",
);
assert.match(
  index,
  /Image safety check is temporarily unavailable\. Upload blocked\./,
  "User image moderation must fail closed when the moderation service is unavailable",
);
assert.match(
  index,
  /Animated WebP images are not allowed/,
  "Animated WebP uploads must be rejected to avoid frame-based moderation bypass",
);
assert.match(
  index,
  /@cf\/cloudflare\/clef-flash/,
  "User image moderation must use the bound Cloudflare vision decision model",
);
assert.match(
  index,
  /images:\s*\[imageDataUrl\]/,
  "The moderation model must inspect the actual uploaded image bytes",
);

console.log("Production readiness guards passed");

assert.match(
  index,
  /facebook_configured:\s*Boolean\(env\.FACEBOOK_APP_ID && env\.FACEBOOK_APP_SECRET\)/,
  "Facebook login must be available when Facebook credentials are configured",
);

console.log("Facebook login readiness guard passed");
