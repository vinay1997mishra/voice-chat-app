import fs from "node:fs";
import assert from "node:assert/strict";

const directory = fs.readFileSync(
  new URL("../src/app_directory.js", import.meta.url),
  "utf8",
);
const ownerPanel = fs.readFileSync(
  new URL("../../tinni_owner_panel/app.js", import.meta.url),
  "utf8",
);
const mine = fs.readFileSync(
  new URL("../../tinni_star/lib/screens/mine_function_screens.dart", import.meta.url),
  "utf8",
);
const login = fs.readFileSync(
  new URL("../../tinni_star/lib/screens/login_screen.dart", import.meta.url),
  "utf8",
);
const localization = fs.readFileSync(
  new URL("../../tinni_star/lib/i18n/tinni_localization.dart", import.meta.url),
  "utf8",
);

assert.match(
  directory,
  /const COIN_SELLER_SETTLEMENT_COINS_PER_USD = 2220000;/,
  "Coin Seller settlement conversion must stay at $1 = 2,220,000 coins",
);
assert.match(
  directory,
  /const HOST_TARGET_USD_CENTS = 160;/,
  "4,000,000 Host target must stay $1.60",
);
assert.match(
  directory,
  /agency_commission_percent: 20/,
  "Agency commission must stay 20%",
);
assert.match(
  directory,
  /const AGENCY_BD_SETTLEMENT_MIN_USD_CENTS = 1000;/,
  "Agency/BD settlement transfer minimum must stay $10",
);
assert.match(
  directory,
  /const HOST_SETTLEMENT_MIN_USD_CENTS = 200;/,
  "Host settlement transfer minimum must stay $2",
);
assert.match(
  directory,
  /recipient\.role === "coin_seller"[\s\S]{0,900}COIN_SELLER_SETTLEMENT_COINS_PER_USD[\s\S]{0,900}_creditPrivilegedWalletAuthorized/,
  "Coin Seller settlement dollars must convert immediately into seller coins",
);
assert.match(
  directory,
  /Math\.floor\(Math\.max\(0, Number\(row\.eligible_coins \|\| 0\)\) \/ hostTargetCoins\) \*[\s\S]{0,120}hostTargetUsdCents/,
  "Agency/BD commission base must require completed Host targets",
);
assert.match(
  mine,
  /_role == 'host'[\s\S]{0,250}settlementTransfers/,
  "Only Host panel should load Host settlement transfer history",
);
assert.match(
  mine,
  /Host sent \/ withdrawn dollars/,
  "Host Panel must label Host dollar history explicitly",
);
assert.match(
  ownerPanel,
  /Agency and BD may transfer their own earned commission from \$10/,
  "Owner Panel must document the $10 Agency/BD transfer rule",
);
assert.match(
  ownerPanel,
  /\$1 = 2,220,000 seller coins/,
  "Owner Panel must document seller settlement conversion",
);

for (const language of [
  "Arabic",
  "Filipino (Tagalog)",
  "Chinese (Simplified)",
  "Chinese (Traditional)",
  "Korean",
]) {
  assert.ok(
    localization.includes("'" + language + "'"),
    "Missing supported language: " + language,
  );
}
assert.match(
  login,
  /Key\('create-id-language'\)/,
  "Create Tinni ID must expose language selection",
);
assert.match(
  mine,
  /const values = tinniSupportedLanguages;/,
  "Settings language picker must use the shared registry",
);

console.log("Final money, settlement privacy and language guards passed");
