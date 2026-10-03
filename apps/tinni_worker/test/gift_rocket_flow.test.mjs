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
const roomPresence = fs.readFileSync(
  new URL("../src/room_presence.js", import.meta.url),
  "utf8",
);
const roomScreen = fs.readFileSync(
  new URL("../../tinni_star/lib/screens/room_screen.dart", import.meta.url),
  "utf8",
);

assert.match(
  directory,
  /const socialValuePercent = isLucky \? 10 : 100;/,
  "Lucky social value must remain 10% and every non-Lucky gift must remain 100%",
);
assert.match(
  directory,
  /const receiverIsHost = this\._isActiveHost\(receiverId\);\s*const receiverDiamonds = receiverIsHost \? socialValueCoins : 0;/,
  "Gift Diamonds must remain Host-only while using the same Lucky 10% / normal 100% social value",
);
assert.match(
  directory,
  /SUM\(COALESCE\(l\.social_value_coins, g\.total_cost\)\) AS sending/,
  "Room gift ranking must count Lucky at its 10% social value and non-Lucky at 100%",
);
assert.match(
  directory,
  /"cp-heart": \{ name: "My Heart", price: 44444, category: "cp" \}/,
  "CP heart gift must remain server-supported",
);
assert.match(
  directory,
  /"cp-invite": \{ name: "CP Invite", price: 2222222, category: "cp", cp_invite: true \}/,
  "CP Invite must remain server-supported at the locked Tinni price",
);
assert.match(
  directory,
  /"country-pride": \{ name: "Country Pride", price: 100, category: "country" \}/,
  "Country gift must remain server-supported",
);
assert.match(
  index,
  /tx\?\.ranking_value \?\?\s*tx\?\.social_value_coins \?\?\s*tx\?\.receiver_diamonds \?\?\s*tx\?\.total_cost \?\?\s*0/,
  "Seat/ranking totals must prefer the authoritative social gift value before any fallback",
);
assert.doesNotMatch(
  index,
  /const coins = Number\(tx\?\.total_cost/,
  "Seat totals must never regress to raw gift cost",
);

assert.match(
  roomScreen,
  /const giftCategories = <String>\[\s*'Normal',\s*'Lucky',\s*'CP',\s*'Country',\s*'Luxury',\s*\];/,
  "Gift box must expose only Normal, Lucky, CP, Country and Luxury",
);
assert.match(
  roomScreen,
  /'Total Coins  ' \+\s*widget\.state\.wallet\.coins\.toString\(\)/,
  "Gift send bar must show the wallet total coins",
);
assert.match(
  roomScreen,
  /Key\('lucky-quantity-plus'\)/,
  "Lucky quantity must have a dedicated + button",
);
assert.match(
  roomScreen,
  /Key\('lucky-quantity-presets'\)/,
  "Lucky quantity must have a separate preset arrow",
);
for (const value of [9, 21, 51, 99, 199, 599, 899, 2999, 7999]) {
  assert.match(
    roomScreen,
    new RegExp("\\n\\s*" + value + ","),
    "Lucky preset " + value + " must remain available",
  );
}
assert.match(
  roomScreen,
  /Timer\(const Duration\(seconds: 12\)/,
  "Lucky Combo must expire after 12 seconds of inactivity",
);
assert.match(
  roomScreen,
  /A tap\/send inside the 12-second Combo window counts as activity\.[\s\S]{0,600}_luckyComboExpiryTimer\?\.cancel\(\);[\s\S]{0,220}_luckyComboCountdownTimer\?\.cancel\(\);[\s\S]{0,220}_luckyComboEpoch\+\+;/,
  "Touching/sending Combo must pause both old 12-second timers while the request is in flight",
);
assert.match(
  roomScreen,
  /_resetLuckyComboState\(\);/,
  "A non-Lucky send must end the previous Lucky consecutive-send Combo",
);
assert.match(
  roomScreen,
  /_luckyComboQuantity = quantity;/,
  "Combo must preserve the chosen Lucky quantity",
);
assert.match(
  roomScreen,
  /if \(sheetContext\.mounted\) \{\s*Navigator\.pop\(sheetContext\);\s*\}\s*await _sendLuckyGift\(/,
  "Lucky send tap must close the gift panel immediately before awaiting the server",
);
assert.match(
  roomScreen,
  /Key\('lucky-combo-countdown'\)/,
  "Lucky Combo must visibly show its 12-second countdown on the room screen",
);
assert.match(
  roomScreen,
  /_selectedGiftRecipients\.contains\(recipient\.\$1\)/,
  "Recipient strip must bind selection to real user IDs",
);
assert.match(
  roomScreen,
  /if \(selected\) \{[\s\S]{0,220}_selectedGiftRecipients\.remove\(recipient\.\$1\)[\s\S]{0,180}\} else \{[\s\S]{0,120}_selectedGiftRecipients\.add\(recipient\.\$1\)/,
  "Gift panel must support multiple selected real recipient IDs",
);
assert.doesNotMatch(
  roomScreen,
  /Gift sending is single-target/,
  "Gift recipient selection must not regress to single-target-only behavior",
);
assert.match(
  roomScreen,
  /ui\.ImageFilter\.blur\([\s\S]{0,120}sigmaX: selected \? 2\.4 : 0,[\s\S]{0,120}sigmaY: selected \? 2\.4 : 0/,
  "Selected recipient DP must blur while unselected DPs remain normal",
);
assert.match(
  roomScreen,
  /Key\('room-gift-send-button'\)[\s\S]{0,260}onPressed: selectedGift == null \|\|\s*_selectedGiftRecipients\.isEmpty \|\|\s*giftSendInFlight/,
  "Send must become ready from local gift+recipient selection without waiting on server state",
);
assert.match(
  roomScreen,
  /receiverIds: selectedRecipients,/,
  "Gift API calls must send only the selected recipient snapshot",
);
assert.match(
  index,
  /receiver_ids: visualReceiverIds/,
  "Gift send route must publish the exact selected real receiver IDs for room animation",
);
assert.match(
  roomPresence,
  /type: "gift_sent"[\s\S]{0,1000}receiver_ids: receiverIds/,
  "Room presence websocket must broadcast recipient-targeted gift visual events",
);
assert.match(
  roomScreen,
  /latestGiftVisualEvent[\s\S]{0,1800}_luckyAnimationReceiverIds[\s\S]{0,600}event\.receiverIds/,
  "Room clients must fan Lucky visual effects only to the broadcast selected receiver IDs",
);
assert.match(
  roomScreen,
  /seatDiameter \* 6\.2 - arc/,
  "Lucky gift flight must visibly travel from below the room toward each selected seat",
);
assert.match(
  roomScreen,
  /quantity: _luckyComboQuantity,/,
  "Combo repeat must resend the preserved quantity",
);
assert.match(
  roomScreen,
  /_seatGiftEffectReceiverIds\.contains\(authoritativeSeatUserId\)/,
  "Normal gift effect must target only selected recipient seats",
);
assert.match(
  roomScreen,
  /_luckyAnimationReceiverIds\.contains\(authoritativeSeatUserId\)/,
  "Lucky gift effect must target only selected recipient seats",
);
assert.doesNotMatch(
  roomScreen,
  /'seat-'\s*\+\s*\(index \+ 1\)\.toString\(\)/,
  "Gift recipients must never use fake seat IDs",
);
assert.match(
  roomScreen,
  /color: Colors\.black,[\s\S]{0,250}Icons\.sports_esports_rounded,[\s\S]{0,120}color: Colors\.white/,
  "Floating Game button must stay black with a white game remote",
);
assert.match(
  roomScreen,
  /Key\('room-rocket-floating-button'\)/,
  "Rocket floating action must remain present",
);

assert.doesNotMatch(
  roomScreen,
  /lucky-live-feed-overlay|_buildLuckyFeedOverlay|_refreshLuckyFeed/,
  "Permanent Lucky result cards must not reappear under the seats",
);
assert.doesNotMatch(
  roomScreen,
  /Ask your followers to support the room\./,
  "Old support/topic prompt must not reappear behind gift/result UI",
);
assert.match(
  roomScreen,
  /Key\('room-official-announcement'\)/,
  "Room must show the permanent official announcement on entry",
);

console.log("Gift, Lucky Combo, recipient, diamond ranking, Rocket and Game guards passed");
