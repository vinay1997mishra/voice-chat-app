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
const ownerPanelApp = fs.readFileSync(
  new URL("../../tinni_owner_panel/app.js", import.meta.url),
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
  /!systemAction && !this\.areFriends\(fromUserId, toUserId\)/,
  "Normal text and image direct messages must require mutual friendship",
);
assert.match(
  directory,
  /type: "friend_status_changed"[\s\S]{0,180}peer_user_id:/,
  "Follow/unfollow must push realtime friend-status changes to message clients",
);
assert.match(
  directory,
  /JOIN app_follows b[\s\S]{0,220}b\.follower_id = a\.target_id[\s\S]{0,180}b\.target_id = a\.follower_id/,
  "Friend status must be derived from both users following each other",
);
assert.match(
  directory,
  /canAccessDirectMessageMedia\(userIdValue, messageIdValue\)/,
  "Stored message photos must only be readable by conversation participants",
);
assert.match(
  directory,
  /CREATE TABLE IF NOT EXISTS owner_panel_message_log/,
  "Owner-panel messages need a separate retention marker without deleting the user inbox record",
);
assert.match(
  directory,
  /Date\.now\(\) - \(48 \* 60 \* 60 \* 1000\)/,
  "Owner-panel message history must use a strict 48-hour visibility window",
);
assert.match(
  directory,
  /LEFT JOIN owner_panel_message_log opm[\s\S]{0,260}opm\.message_id IS NULL OR opm\.created_at >= \?/,
  "Only owner-panel-origin messages older than 48 hours may disappear from the panel view",
);
assert.match(
  directory,
  /INSERT OR REPLACE INTO owner_panel_message_log\(message_id,user_id,created_at\)/,
  "Sending from the Owner Panel must mark the message for panel-only 48-hour retention",
);

assert.match(
  index,
  /"hierarchy\.view_details"/,
  "Hierarchy drill-down must be an explicit staff permission rather than an inherited module permission",
);
assert.match(
  index,
  /url\.pathname === "\/api\/owner\/hierarchy-detail"[\s\S]{0,500}users\.full_dashboard[\s\S]{0,240}hierarchy\.view_details/,
  "Owner hierarchy-detail API must require both Full ID Dashboard and hierarchy-detail permissions",
);
assert.match(
  directory,
  /target_progress_percent/,
  "Host and Agency drill-down data must expose target progress for the selected date range",
);
assert.match(
  directory,
  /target_remaining_coins/,
  "Host drill-down data must expose remaining target coins",
);
assert.match(
  directory,
  /combined_target_progress_percent/,
  "Agency and BD drill-down data must expose combined target progress",
);

assert.match(
  directory,
  /role IN \('host','agency','bd'\)/,
  "Host, Agency and BD must all surface as automatic removable drill-down identity roles",
);
assert.match(
  ownerPanelApp,
  /data-owner-nested-user/,
  "Nested Owner Panel records must let the operator drill into the referenced user ID",
);
assert.match(
  ownerPanelApp,
  /ownerFullDashboardDialog"\)\?\.close\(\)[\s\S]{0,260}openOwnerUserProfile\(targetId\)/,
  "Nested ID drill-down must leave the current detail layer and open the referenced full profile",
);

assert.match(
  ownerPanelApp,
  /checkboxField\("permission_" \+ key, label, false\)/,
  "New Staff Panel permission checkboxes must default to OFF",
);
assert.match(
  ownerPanelApp,
  /No functions are active\. The Owner must enable functions individually\./,
  "A Staff Panel with zero permissions must show no automatic functions",
);
assert.match(
  ownerPanelApp,
  /\["7d","7 Days"\][\s\S]{0,260}\["15d","15 Days"\][\s\S]{0,260}\["month","This Month"\][\s\S]{0,260}\["last_month","Last Month"\][\s\S]{0,260}\["custom","Custom Date"\]/,
  "Owner hierarchy drill-down must expose week, 15-day, month, last-month and custom date ranges",
);
assert.match(
  ownerPanelApp,
  /data-owner-hierarchy-remove-host/,
  "Agency drill-down must expose authorized Host removal",
);
assert.match(
  ownerPanelApp,
  /data-owner-hierarchy-user/,
  "Hierarchy member IDs must drill back into the selected user's ID view",
);
assert.match(
  ownerPanelApp,
  /data-owner-tag-remove/,
  "Full ID views must expose tag removal controls when permission allows",
);

console.log("Production readiness guards passed");

assert.match(
  index,
  /facebook_configured:\s*Boolean\(env\.FACEBOOK_APP_ID && env\.FACEBOOK_APP_SECRET\)/,
  "Facebook login must be available when Facebook credentials are configured",
);

console.log("Facebook login readiness guard passed");
