
import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';

test('25 animated shop frames cover themes and charge 10k through 8m authoritative coins',async t=>{
 const r=runtime();t.after(r.close);
 const a=await r.user(1301),b=await r.user(1302),d=r.directory;
 const frames=d.frameCatalog('IN').filter(f=>f.id.startsWith('shop-frame-'));
 assert.equal(frames.length,25);
 assert.equal(new Set(frames.map(f=>f.id)).size,25);
 assert.equal(Math.min(...frames.map(f=>f.price)),10000);
 assert.equal(Math.max(...frames.map(f=>f.price)),8000000);
 for(const category of ['simple','funny','love','royal','nature'])
  assert.ok(frames.some(f=>f.data.category===category));
 d.getWallet(a.user_id);
 const funded=frames.reduce((total,frame)=>total+frame.price,0);
 d._creditNormalWalletAuthorized(a.user_id,funded,'test_fixture');
 let balance=funded;
 for(const frame of frames){
  assert.equal(frame.data.animated,true);
  assert.throws(()=>d.equipFrame(b.user_id,frame.id),/not owned/);
  const purchased=d.purchaseFrame(a.user_id,frame.id,'IN');
  balance-=frame.price;
  assert.equal(purchased.wallet.coins,balance);
  assert.ok(purchased.inventory.owned.some(x=>x.item_id===frame.id));
  const duplicate=d.purchaseFrame(a.user_id,frame.id,'IN');
  assert.equal(duplicate.duplicate,true);
  assert.equal(duplicate.wallet.coins,balance);
  assert.equal(d.equipFrame(a.user_id,frame.id).inventory.equipped_frame_id,frame.id);
 }
 assert.equal(balance,0);
 const row=d.ctx.storage.sql.exec("SELECT * FROM owner_catalog WHERE id=?",frames[0].id).toArray()[0];
 const data=JSON.parse(row.data_json);data.coin_price=12345;
 d.ctx.storage.sql.exec("UPDATE owner_catalog SET data_json=? WHERE id=?",JSON.stringify(data),row.id);
 assert.equal(d.frameCatalog('IN').find(f=>f.id===row.id).price,12345);
 d.ctx.storage.sql.exec("UPDATE owner_catalog SET enabled=0 WHERE id=?",row.id);
 assert.ok(!d.frameCatalog('IN').some(f=>f.id===row.id));
 assert.throws(()=>d.purchaseFrame(b.user_id,row.id,'IN'),/unavailable/);
});
