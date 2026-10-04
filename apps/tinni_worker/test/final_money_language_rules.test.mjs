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
  /automatic_dollar_to_coin_conversion:\s*false/,
  "Automatic dollar-to-coin conversion must stay disabled",
);
assert.match(
  directory,
  /CREATE TABLE IF NOT EXISTS role_dollar_balances/,
  "Coin Seller and Merchant USD must use a separate persistent dollar balance",
);
assert.match(
  directory,
  /const HOST_TARGET_USD_CENTS = 160;/,
  "4,000,000 Host target must stay $1.60",
);
assert.match(
  directory,
  /agency_commission_percent: 10/,
  "Agency commission must stay 10%",
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
  /transferSettlement\([\s\S]{0,5200}credited_coins:\s*0/,
  "Hierarchy settlement dollars must never auto-credit recipient coins",
);
assert.match(
  directory,
  /recipientAfter = recipientBefore \+ usdCents/,
  "Coin Seller or Merchant settlement recipient must receive USD into its Dollar Wallet",
);
assert.match(
  directory,
  /Math\.floor\(Math\.max\(0, Number\(row\.eligible_coins \|\| 0\)\) \/ hostTargetCoins\) \*[\s\S]{0,120}hostTargetUsdCents/,
  "Agency/BD commission base must require completed Host targets",
);
assert.match(
  mine,
  /settlementTransfers\([\s\S]{0,180}senderRole: _role/,
  "Host, Agency and BD panels must load only their own role-scoped transfer history",
);
assert.match(
  mine,
  /Host sent \/ withdrawn dollar history/,
  "Host Panel must label Host dollar history explicitly",
);
assert.match(
  ownerPanel,
  /Agency and BD may transfer their own earned commission from \$10/,
  "Owner Panel must document the $10 Agency/BD transfer rule",
);
assert.match(
  ownerPanel,
  /No automatic dollar-to-coin conversion/,
  "Owner Panel must document that role dollars remain USD",
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
