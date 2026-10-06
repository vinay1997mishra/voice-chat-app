import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';

async function fixture(t) {
  const r = runtime(); t.after(r.close);
  const a = await r.user(98001), b = await r.user(98002), c = await r.user(98003);
  const d = r.directory;
  const room = await d.createRoom(a.user_id, {title:'CP VS',seat_count:12});
  d._setOwnerSetting('cp_coin_thresholds', [2000000,3000000,6000000,12000000,20000000]);
  d._setOwnerSetting('vs_coin_thresholds', [2000000,3000000,6000000,12000000,20000000]);
  d.getWallet(a.user_id); d._creditNormalWalletAuthorized(a.user_id,100000000,'test_fixture');
  await r.request('/cp/request',a.token,{target_user_id:b.user_id});
  await r.request('/cp/respond',b.token,{accept:true});
  await r.request('/vs/request',a.token,{target_user_id:b.user_id});
  await r.request('/vs/respond',b.token,{accept:true});
  const send = (gift_id,request_id,receiver_id=b.user_id) => d.sendGift(a.user_id,{
    room_id:room.id,gift_id,quantity:1,receiver_ids:[receiver_id],request_id,
  });
  return {r,a,b,c,d,room,send};
}

test('gift retry is one debit, one progress entry and one level transition',async t=>{
  const {d,a,send}=await fixture(t);
  const before=d.getWallet(a.user_id).coins;
  const first=send('cp-infinity-love','retry_cp_0001');
  const retry=send('cp-infinity-love','retry_cp_0001');
  assert.equal(retry.replayed,true);
  assert.equal(first.transactions[0].id,retry.transactions[0].id);
  assert.equal(d.getWallet(a.user_id).coins,before-first.total_cost);
  assert.equal(d.cpState(a.user_id).intimacy,6100000);
  assert.equal(d.cpState(a.user_id).level,4);
  assert.equal(first.transactions[0].cp_progress,6100000);
  assert.equal(first.transactions[0].vs_progress,0);
  assert.equal(first.transactions[0].category,'cp');
  assert.equal(d.enemyState(a.user_id).rivalry,0);
  assert.equal(d.ctx.storage.sql.exec('SELECT COUNT(*) AS n FROM cp_gift_progress').one().n,1);
  assert.throws(()=>send('enemy-abyss-king','retry_cp_0001'),/different details/);
});

test('CP and VS remain independent and gifts to an unrelated user give zero pair progress',async t=>{
  const {d,a,c,send}=await fixture(t);
  send('cp-infinity-love','wrong_pair_0001',c.user_id);
  send('rose','normal_gift_0001');
  send('lucky-colorful-rose','lucky_gift_0001');
  assert.equal(d.cpState(a.user_id).intimacy,0);
  assert.equal(d.enemyState(a.user_id).rivalry,0);
  const gift=send('enemy-abyss-king','valid_vs_0001');
  assert.equal(gift.transactions[0].category,'vs');
  assert.equal(gift.transactions[0].vs_progress,4700000);
  assert.equal(d.enemyState(a.user_id).level,3);
  assert.equal(d.cpState(a.user_id).intimacy,0);
  assert.equal(d.vsRanking()[0].rivalry,4700000);
  assert.equal(d.cpRanking()[0].intimacy,0);
});

test('insufficient coins, disabled gifts and failed transactions cannot award progress',async t=>{
  const {d,a,send}=await fixture(t);
  d.ctx.storage.sql.exec("INSERT INTO owner_catalog(id,kind,name,data_json,enabled,created_at,updated_at) VALUES('cp-infinity-love','gift','Disabled','{}',0,1,1)");
  const before=d.getWallet(a.user_id).coins;
  assert.throws(()=>send('cp-infinity-love','disabled_cp_0001'),/unavailable/);
  assert.equal(d.getWallet(a.user_id).coins,before);
  assert.equal(d.cpState(a.user_id).intimacy,0);
  d.ctx.storage.sql.exec("DELETE FROM owner_catalog WHERE id='cp-infinity-love'");
  const original=d._recordCpGiftIntimacy;
  d._recordCpGiftIntimacy=()=>{throw new Error('forced progress write failure')};
  assert.throws(()=>send('cp-infinity-love','rollback_cp_0001'),/forced/);
  d._recordCpGiftIntimacy=original;
  assert.equal(d.getWallet(a.user_id).coins,before);
  assert.equal(d.ctx.storage.sql.exec('SELECT COUNT(*) AS n FROM gift_transactions').one().n,0);
  d.ctx.storage.sql.exec('UPDATE app_wallets SET coins=0 WHERE user_id=?',a.user_id);
  assert.throws(()=>send('cp-infinity-love','no_money_cp_0001'),/coins|frozen/);
  assert.equal(d.cpState(a.user_id).intimacy,0);
});

test('active CP is exclusive, progress does not decay and removal requires the current pair',async t=>{
  const {r,d,a,b,c,send}=await fixture(t);
  assert.throws(()=>d.cpRequest(a.user_id,c.user_id),/already active/);
  assert.throws(()=>d.cpRequest(c.user_id,b.user_id),/already active/);
  send('cp-infinity-love','no_decay_cp_0001');
  d.ctx.storage.sql.exec('UPDATE cp_relationships SET last_intimacy_at=?',Date.now()-30*86400000);
  assert.equal(d.cpState(a.user_id).intimacy,6100000);
  const bad=await r.request('/cp/disconnect',a.token,{confirmed:true,expected_pair:'old-pair'});
  assert.equal(bad.status,409);
  assert.equal(d.cpState(a.user_id).state,'accepted');
  const cp=d.cpState(a.user_id);
  const removed=await r.request('/cp/disconnect',a.token,{confirmed:true,expected_pair:cp.pair_key});
  assert.equal(removed.status,200);
  assert.equal(d.cpState(a.user_id),null);
  assert.equal(d.enemyState(a.user_id).state,'accepted');
  assert.equal(d.ctx.storage.sql.exec('SELECT COUNT(*) AS n FROM cp_gift_progress').one().n,1);
});

test('published owner CP/VS gifts are available without changing the app bundle',async t=>{
  const {r,d,a,send}=await fixture(t);
  const created=d.ownerAction('gift-new',{name:'Owner VS Movie',category:'vs',coin_price:3000000,
    animation_url:'https://test.local/media/gifts/vs/movie.mp4',poster_url:'https://test.local/media/gifts/vs/poster.png',effect_tier:'cinematic'});
  const catalog=await r.request('/gifts/catalog',a.token);
  assert.equal(catalog.status,200);
  assert.equal(catalog.data.gifts.find(x=>x.id===created.id).data.animation_url,'https://test.local/media/gifts/vs/movie.mp4');
  const gift=send(created.id,'owner_vs_movie_0001');
  assert.equal(gift.transactions[0].vs_progress,3000000);
  assert.equal(gift.transactions[0].animation_url,'https://test.local/media/gifts/vs/movie.mp4');
  d.ownerCatalogPatch(created.id,{enabled:false});
  assert.throws(()=>send(created.id,'owner_disabled_0001'),/unavailable/);
  const denied=await r.request('/api/owner/gift-media',a.token,{});
  assert.equal(denied.status,401);
});

test('only the main Owner can upload CP/VS MP4s and the managed 30 MB limit supports larger cinematics',async t=>{
  const r=runtime();t.after(r.close);
  const cookie=await r.ownerCookie();
  const form=new FormData();
  const bytes=new Uint8Array(5000000);
  bytes.set([0,0,0,24,102,116,121,112,105,115,111,109]);
  form.set('category','vs');form.set('kind','video');
  form.set('file',new Blob([bytes],{type:'video/mp4'}),'vs.mp4');
  const response=await r.fetch(new Request('https://test.local/api/owner/gift-media',{
    method:'POST',headers:{cookie},body:form,
  }));
  const result=await response.json();
  assert.equal(response.status,201,JSON.stringify(result));
  assert.match(result.url,/media\/gifts\/vs\//);
  assert.equal(r.mediaObjects.size,1);
  const invalid=new FormData();
  invalid.set('category','vs');invalid.set('kind','video');
  invalid.set('file',new Blob([new Uint8Array(20)],{type:'video/mp4'}),'bad.mp4');
  const rejected=await r.fetch(new Request('https://test.local/api/owner/gift-media',{method:'POST',headers:{cookie},body:invalid}));
  assert.equal(rejected.status,400);
  assert.equal(r.mediaObjects.size,1);
});
