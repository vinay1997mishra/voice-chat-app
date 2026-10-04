import fs from "node:fs";
import assert from "node:assert/strict";

const directory = fs.readFileSync(new URL("../src/app_directory.js", import.meta.url), "utf8");
const index = fs.readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
const ownerApp = fs.readFileSync(new URL("../../tinni_owner_panel/app.js", import.meta.url), "utf8");
const ownerHtml = fs.readFileSync(new URL("../../tinni_owner_panel/index.html", import.meta.url), "utf8");
const client = fs.readFileSync(new URL("../../tinni_star/lib/infra/app_backend_service.dart", import.meta.url), "utf8");
const recharge = fs.readFileSync(new URL("../../tinni_star/lib/screens/recharge_screen.dart", import.meta.url), "utf8");
const walletScreens = fs.readFileSync(new URL("../../tinni_star/lib/screens/wallet_detail_screens.dart", import.meta.url), "utf8");

for (const table of [
  "privileged_wallet_transactions",
  "role_dollar_balances",
  "role_dollar_transfers",
  "company_dollar_balance",
  "company_dollar_ledger",
  "diamond_conversions",
]) {
  assert.ok(directory.includes("CREATE TABLE IF NOT EXISTS " + table), "Missing table " + table);
}

assert.match(directory, /_recordPrivilegedWalletTransaction\(\{/);
assert.match(directory, /kind: "company_credit"/);
assert.match(directory, /kind: "owner_debit"/);
assert.match(directory, /kind: "coins_sent"/);
assert.match(directory, /kind: "settlement_received"/);
assert.match(directory, /roleWalletDetail\(/);
assert.match(directory, /async transferRoleDollars\(/);
assert.match(directory, /company_dollars: this\._companyDollarState\(500\)/);
assert.match(directory, /case "company-dollar-deduct": return this\.ownerDeductCompanyDollars/);
assert.match(directory, /data\.asset \|\| "coins"/);
assert.match(directory, /automatic_dollar_to_coin_conversion:\s*false/,
  "Role dollars must never auto-convert to coins");
assert.match(directory, /total_usd_cents: guard\.security_frozen \? 0 : Math\.max\(0, Number\(dollarRow\?\.usd_cents \|\| 0\)\)/,
  "Coin Seller and Merchant Total Dollars must read the separate USD balance");

for (const route of [
  "/wallet/coins/history",
  "/wallet/diamonds/history",
  "/wallet/diamonds/convert",
  "/wallet/role-detail",
  "/wallet/role-dollars/transfer",
  "/wallet/settlement/recipients",
]) {
  assert.ok(index.includes(route), "Missing Worker route " + route);
}
assert.match(index, /"company-dollar-deduct":"__owner_only__"/);

assert.match(ownerHtml, /id="companyDollarBalance"/);
assert.match(ownerHtml, /id="companyDollarLedger"/);
assert.match(ownerApp, /companyDollars: \{ usd_cents: 0, ledger: \[\] \}/);
assert.match(ownerApp, /function renderCompanyDollars\(\)/);
assert.match(ownerApp, /"company-dollar-deduct": "__owner_only__"/);
assert.match(ownerApp, /selectField\("asset","Balance",\[\["coins","Coins"\],\["diamonds","Diamonds"\]\]\)/);

for (const method of [
  "coinsHistory",
  "diamondsHistory",
  "convertDiamonds",
  "roleWalletDetail",
  "transferRoleDollars",
]) {
  assert.ok(client.includes(method + "("), "Missing mobile backend method " + method);
}
assert.match(recharge, /import 'wallet_detail_screens\.dart';/);
assert.match(recharge, /CoinsHistoryScreen/);
assert.match(recharge, /DiamondsWalletScreen/);
assert.match(recharge, /RoleWalletDetailScreen/);
assert.match(walletScreens, /class CoinsHistoryScreen/);
assert.match(walletScreens, /class DiamondsWalletScreen/);
assert.match(walletScreens, /class RoleWalletDetailScreen/);
assert.match(walletScreens, /class ReceivedDollarsScreen/);

console.log("Owner wallet, Company dollars and permanent ledger integration guards passed");
