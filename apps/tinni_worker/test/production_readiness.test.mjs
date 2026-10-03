import fs from "node:fs";
import assert from "node:assert/strict";

const index = fs.readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
const directory = fs.readFileSync(
  new URL("../src/app_directory.js", import.meta.url),
  "utf8",
);
const wranglerConfig = fs.readFileSync(
  new URL("../wrangler.jsonc", import.meta.url),
  "utf8",
);

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
  wranglerConfig,
  /"binding":\s*"EFFECT_MEDIA"[\s\S]{0,160}"bucket_name":\s*"tinni-star-effects"/,
  "Tinni Worker must bind the existing R2 media bucket for profile, room and inbox photos",
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
assert.match(
  index,
  /await enforceSignupAvatarSafety\(env, profile\)/,
  "Signup avatars must pass image safety before account creation",
);
assert.match(
  index,
  /Profile photo must be uploaded and safety-approved first/,
  "Direct profile avatar URL bypasses must be blocked",
);
assert.match(
  index,
  /Room photo must be uploaded and safety-approved first/,
  "Direct room DP URL bypasses must be blocked",
);
assert.match(
  index,
  /Custom room background must be uploaded and safety-approved first/,
  "User custom room backgrounds must use a moderated Tinni media asset",
);
assert.match(
  index,
  /url\.pathname === "\/room-theme-media"/,
  "User custom room backgrounds must have a dedicated moderated upload route",
);
assert.match(
  index,
  /url\.pathname === "\/message-media"/,
  "Direct-message photos must use the protected message media endpoint",
);
assert.match(
  index,
  /surface: "message_image"/,
  "Message photos must pass the dedicated chat-photo safety decision",
);
assert.match(
  index,
  /third_party_app_branding/,
  "Message photos must reject visible third-party app branding or interfaces",
);
assert.match(
  index,
  /external_link_or_qr/,
  "Message photos must reject external links, domains and QR codes",
);
assert.match(
  index,
  /Photos can only be sent to mutual friends/,
  "Message photo upload must reject non-friends before storage",
);
assert.match(
  directory,
  /messageKind === "image"[\s\S]{0,500}this\.areFriends\(fromUserId, toUserId\)/,
  "Message persistence must independently enforce mutual friendship for images",
);
assert.match(
  directory,
  /canAccessDirectMessageMedia\(userIdValue, messageIdValue\)/,
  "Stored message photos must only be readable by conversation participants",
);

console.log("Production readiness guards passed");

assert.match(
  index,
  /facebook_configured:\s*Boolean\(env\.FACEBOOK_APP_ID && env\.FACEBOOK_APP_SECRET\)/,
  "Facebook login must be available when Facebook credentials are configured",
);

console.log("Facebook login readiness guard passed");
