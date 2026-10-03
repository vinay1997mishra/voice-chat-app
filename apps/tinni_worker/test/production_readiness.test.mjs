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
  /facebook_configured:\s*Boolean\(env\.FACEBOOK_APP_ID && env\.FACEBOOK_APP_SECRET\)/,
  "Facebook login must be available when Facebook credentials are configured",
);

console.log("Facebook login readiness guard passed");


test("public room directory derives online count from live user presence", () => {
  const source = read("src/app_directory.js");
  const listStart = source.indexOf("async listRooms()");
  const listEnd = source.indexOf("_pruneRoomThemes(", listStart);
  assert.ok(listStart >= 0 && listEnd > listStart);
  const listRooms = source.slice(listStart, listEnd);
  assert.match(listRooms, /FROM app_user_presence/);
  assert.match(listRooms, /room_socket_connected/);
  assert.match(listRooms, /last_seen >= \?/);
  assert.match(listRooms, /Date\.now\(\) - 90000/);
  assert.doesNotMatch(listRooms, /LEFT JOIN app_room_presence_counts/);
});


test("Lucky Gift keeps 10 percent social value across room surfaces", () => {
  const source = read("src/app_directory.js");
  const sendStart = source.indexOf("sendGift(senderIdValue, input)");
  const sendEnd = source.indexOf("listRoomGifts(", sendStart);
  assert.ok(sendStart >= 0 && sendEnd > sendStart);
  const sendGift = source.slice(sendStart, sendEnd);
  assert.match(sendGift, /const socialValuePercent = isLucky \? 10 : 100/);
  assert.match(sendGift, /const receiverDiamonds = receiverIsHost \? socialValueCoins : 0/);
  assert.match(sendGift, /ranking_value: socialValueCoins/);
  assert.match(sendGift, /_recordRoomGiftSending\(room, roomSocialValue, now\)/);

  const listStart = source.indexOf("async listRooms()");
  const listEnd = source.indexOf("_pruneRoomThemes(", listStart);
  const listRooms = source.slice(listStart, listEnd);
  assert.match(listRooms, /LEFT JOIN lucky_gift_results l ON l\.transaction_id = g\.id/);
  assert.match(listRooms, /COALESCE\(l\.social_value_coins, g\.total_cost\)/);

  const rankingStart = source.indexOf("roomGiftRanking(");
  const rankingEnd = source.indexOf("createLuckyPouch(", rankingStart);
  const ranking = source.slice(rankingStart, rankingEnd);
  assert.match(ranking, /COALESCE\(l\.social_value_coins, g\.total_cost\)/);
});
