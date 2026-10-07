import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';
import { premiumGiftCatalog } from '../src/premium_gift_catalog.js';
test('all premium gifts charge authoritative prices and preserve exact recipient sets',{timeout:120000},async t=>{
 const r=runtime();t.after(r.close);
 const a=await r.user(501),b=await r.user(502),c=await r.user(503);
 const room=await r.directory.createRoom(a.user_id,{title:'Premium gifts',seat_count:12});
 r.directory.ctx.storage.sql.exec('UPDATE app_wallets SET coins = 2000000000 WHERE user_id = ?',a.user_id);
 let balance=2000000000;
 for(const [id,gift] of Object.entries(premiumGiftCatalog)) {
  const ids=id==='cp-invite'?[b.user_id]:[b.user_id,c.user_id];
  // Each case models a separate allowed send window, rather than a burst
  // of 319 gifts that intentionally hits production anti-spam protection.
  r.directory.ctx.storage.sql.exec('DELETE FROM security_action_windows WHERE user_id = ?',a.user_id);
  const result=await r.request('/gifts/send',a.token,{request_id:crypto.randomUUID(),
   room_id:room.id,gift_id:id,gift_name:'client tampered name',quantity:1,
   unit_price:1,receiver_ids:ids,
  });
  assert.equal(result.status,201,id+': '+JSON.stringify(result.data));
  balance-=gift.price*ids.length;
  assert.equal(result.data.wallet.coins,balance,id);
  assert.equal(result.data.transactions.length,ids.length,id);
  assert.deepEqual(new Set(result.data.transactions.map(tx=>tx.receiver_id)),new Set(ids),id);
 }
});
