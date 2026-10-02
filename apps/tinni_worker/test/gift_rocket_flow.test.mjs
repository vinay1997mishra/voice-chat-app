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
const roomScreen = fs.readFileSync(
  new URL("../../tinni_star/lib/screens/room_screen.dart", import.meta.url),
  "utf8",
);

assert.match(
  directory,
  /const receiverDiamondPercent = isLucky \? 10 : 100;/,
  "Lucky receivers must get 10% diamonds and every non-Lucky gift must get 100%",
);
assert.match(
  directory,
  /SUM\(COALESCE\(l\.social_value_coins, g\.total_cost\)\) AS sending/,
  "Room gift ranking must count Lucky at its 10% social value and non-Lucky at 100%",
);
assert.match(
  directory,
  /"heart-ring": \{ name: "Heart Ring", price: 1800, category: "cp" \}/,
  "CP gift must remain server-supported",
);
assert.match(
  directory,
  /"country-pride": \{ name: "Country Pride", price: 100, category: "country" \}/,
  "Country gift must remain server-supported",
);
assert.match(
  index,
  /tx\?\.receiver_diamonds \?\? tx\?\.ranking_value \?\? 0/,
  "Seat received totals must use credited diamonds, not raw gift coins",
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
  /_luckyComboExpiryTimer\?\.cancel\(\);\s*_luckyComboExpiryTimer = null;\s*_luckyComboEpoch\+\+;/,
  "Touching/sending Combo must pause the old 12-second expiry while the request is in flight",
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
  /if \(sent && sheetContext\.mounted\) \{\s*Navigator\.pop\(sheetContext\);\s*\}/,
  "Successful Lucky send must close the gift panel before Combo continues on the room screen",
);
assert.match(
  roomScreen,
  /_selectedGiftRecipients\s*\.\.clear\(\)\s*\.\.add\(recipient\.\$1\);/,
  "Tapping a recipient DP must replace the previous target instead of accumulating seat recipients",
);
assert.match(
  roomScreen,
  /receiverIds: selectedRecipients,/,
  "Gift API calls must send only the selected recipient snapshot",
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

console.log("Gift, Lucky Combo, recipient, diamond ranking, Rocket and Game guards passed");
