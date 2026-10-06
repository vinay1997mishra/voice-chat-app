import test from 'node:test';
import assert from 'node:assert/strict';
import {runtime} from './helpers/runtime.mjs';
import * as cold from '../src/cold_storage.js';
import {flushGameResults} from '../src/game_results.js';

const sql=(r,q,...args)=>r.directory.ctx.storage.sql.exec(q,...args);
function walletRows(r,userId,age=40) {
  for(let i=0;i<5;i++) sql(r,
    "INSERT INTO wallet_transactions(id,user_id,kind,coins_delta,reference_id,note,created_at) VALUES(?,?,'credit',10,?,?,?)",
    'cold-wallet-'+i,userId,'reference-'+i,'old note '+i,Date.now()-age*cold.DAY_MS+i);
}
test('verified wallet archives shrink SQL and retain history, references and user-ID changes',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1),b=await r.user(2);
  walletRows(r,a.user_id);r.directory._creditNormalWalletAuthorized(a.user_id,1234);
  await cold.inventoryStorage(r.directory);
  assert.equal(await cold.archiveWalletBatch(r.directory),5);
  assert.equal(sql(r,"SELECT COUNT(*) n FROM wallet_transactions").one().n,0);
  assert.equal((await r.directory.walletTransactions(a.user_id)).length,5);
  assert.equal((await r.directory.walletTransactions(b.user_id)).length,0);
  assert.equal(r.directory.getWallet(a.user_id).coins,1234);
  assert.equal(cold.walletReferenceExists(r.directory,a.user_id,'reference-1'),true);
  assert.throws(()=>sql(r,"INSERT INTO wallet_transactions(id,user_id,kind,reference_id,created_at) VALUES('replay',?,'credit','reference-1',?)",a.user_id,Date.now()),/already recorded/);
  r.directory._changeUserId(a.user_id,'9876');
  assert.equal((await r.directory.walletTransactions('9876')).length,5);
  assert.equal(cold.walletReferenceExists(r.directory,'9876','reference-1'),true);
  const batch=sql(r,"SELECT object_key FROM cold_batches LIMIT 1").one();
  const exposed=await r.request('/media/'+encodeURIComponent(batch.object_key));
  assert.equal(exposed.status,404);
});
test('archive write or verification failure leaves every financial source row in SQL',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1);walletRows(r,a.user_id);
  await cold.inventoryStorage(r.directory);
  const get=r.env.USER_ARCHIVE.get;
  r.env.USER_ARCHIVE.get=async key=>key.startsWith(cold.PRIVATE_PREFIX)?null:get(key);
  await assert.rejects(cold.archiveWalletBatch(r.directory),/verification failed/);
  assert.equal(sql(r,"SELECT COUNT(*) n FROM wallet_transactions").one().n,5);
  assert.equal(sql(r,"SELECT COUNT(*) n FROM cold_batches").one().n,0);
});
test('missing archive produces an error instead of silently dropping wallet history',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1);walletRows(r,a.user_id);
  await cold.inventoryStorage(r.directory);await cold.archiveWalletBatch(r.directory);
  const key=sql(r,"SELECT object_key FROM cold_batches LIMIT 1").one().object_key;
  r.archiveObjects.delete(key);
  await assert.rejects(r.directory.walletTransactions(a.user_id),/temporarily unavailable/);
});
test('long chats trim to the newest 500 while short chats and recent excess messages survive',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1),b=await r.user(2),c=await r.user(3);
  const now=Date.now(),old=now-20*cold.DAY_MS;
  for(let i=0;i<520;i++) sql(r,"INSERT INTO direct_messages(id,from_user_id,to_user_id,text,created_at) VALUES(?,?,?,'old chat',?)",
    'long-'+String(i).padStart(4,'0'),i%2?a.user_id:b.user_id,i%2?b.user_id:a.user_id,old+i);
  sql(r,"INSERT INTO direct_messages(id,from_user_id,to_user_id,text,created_at) VALUES('short',?,?,'short remains',?)",a.user_id,c.user_id,old);
  const result=await cold.cleanupPrivateChats(r.directory,now);
  assert.equal(result.deleted_messages,20);
  assert.equal(sql(r,"SELECT COUNT(*) n FROM direct_messages WHERE id LIKE 'long-%'").one().n,500);
  assert.ok(sql(r,"SELECT id FROM direct_messages WHERE id='short'").toArray().length);
  for(let i=0;i<5;i++) sql(r,"INSERT INTO direct_messages(id,from_user_id,to_user_id,text,created_at) VALUES(?,?,?,'new',?)",'new-'+i,a.user_id,b.user_id,now+i);
  const latest=await r.directory.listDirectMessages(a.user_id,b.user_id,500);
  assert.equal(latest.at(-1).id,'new-4');
  // Excess younger than 10 days stays until its photos have had their full retention window.
  sql(r,"UPDATE direct_messages SET created_at=? WHERE id LIKE 'long-%'",now-cold.DAY_MS);
  assert.equal((await cold.cleanupPrivateChats(r.directory,now)).deleted_messages,0);
});
test('chat photos expire at 10 days even in short chats, without deleting their text record',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1),b=await r.user(2),now=Date.now();
  for(const [id,days] of [['old-photo',11],['new-photo',9]]) {
    sql(r,"INSERT INTO direct_messages(id,from_user_id,to_user_id,text,message_kind,media_url,created_at) VALUES(?,?,?,'Photo','image',?,?)",
      id,a.user_id,b.user_id,'https://test.local/message-media/'+id,now-days*cold.DAY_MS);
    await r.env.EFFECT_MEDIA.put('messages/'+id,new Uint8Array([1,2,3]),{});
  }
  assert.equal(r.directory.canAccessDirectMessageMedia(b.user_id,'old-photo'),false);
  assert.equal(r.directory.canAccessDirectMessageMedia(b.user_id,'new-photo'),true);
  const result=await cold.cleanupPrivateChats(r.directory,now);
  assert.equal(result.deleted_photos,1);
  assert.equal(r.mediaObjects.has('messages/old-photo'),false);
  assert.equal(r.mediaObjects.has('messages/new-photo'),true);
  assert.equal(sql(r,"SELECT COUNT(*) n FROM direct_messages").one().n,2);
});
test('capacity reservations serialize writes and stop before the conservative R2 budget',async t=>{
  const r=runtime();t.after(r.close);await cold.inventoryStorage(r.directory);
  r.env.R2_BYTE_LIMIT_BYTES=100;
  await r.directory.reserveMediaBudget('test/a',60,'lease-a');
  await assert.rejects(r.directory.reserveMediaBudget('test/b',60,'lease-b'),/Storage budget/);
  await assert.rejects(r.directory.reserveMediaBudget('test/a',10,'lease-c'),/UNIQUE/);
  r.directory.abortMediaBudget('lease-a',false);
  assert.equal(r.directory.storageStatus().used_bytes,0);
  await cold.managedMediaPut(r.env,'test/a',new Uint8Array(60),{});
  await assert.rejects(cold.managedMediaPut(r.env,'test/b',new Uint8Array(60),{}),/Storage budget/);
  assert.equal(r.mediaObjects.get('test/a').bytes.byteLength,60);
});
test('failed or abandoned upload is reconciled before further writes',async t=>{
  const r=runtime();t.after(r.close);await cold.inventoryStorage(r.directory);
  const put=r.env.EFFECT_MEDIA.put;
  r.env.EFFECT_MEDIA.put=async()=>{throw new Error('upload interrupted');};
  await assert.rejects(cold.managedMediaPut(r.env,'test/a',new Uint8Array(60),{}),/interrupted/);
  assert.equal(r.directory.storageStatus().known,0);
  r.env.EFFECT_MEDIA.put=put;
  await cold.inventoryStorage(r.directory);
  assert.equal(r.directory.storageStatus().used_bytes,0);
  await r.directory.reserveMediaBudget('test/b',60,'abandoned');
  sql(r,"UPDATE media_write_leases SET created_at=?",Date.now()-2*3600000);
  await cold.inventoryStorage(r.directory);
  assert.equal(r.directory.storageStatus().used_bytes,0);
  assert.equal(sql(r,"SELECT COUNT(*) n FROM media_write_leases").one().n,0);
});
test('only the current DP survives replacement, ID changes and inventory cleanup',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1);
  r.env.PUBLIC_API_ORIGIN='https://test.local';
  const oldKey='profiles/'+a.user_id+'/avatar',newKey='profiles/9876/avatar';
  await r.env.EFFECT_MEDIA.put(oldKey,new Uint8Array([1,2,3]),{});
  const old='https://test.local/media/'+encodeURIComponent(oldKey)+'?v=1';
  await r.directory.updateUserProfile(a.user_id,{avatar_data_url:old});
  r.directory._changeUserId(a.user_id,'9876');
  await r.env.EFFECT_MEDIA.put(newKey,new Uint8Array([4,5,6]),{});
  const current='https://test.local/media/'+encodeURIComponent(newKey)+'?v=2';
  await r.directory.updateUserProfile('9876',{avatar_data_url:current});
  assert.equal(r.mediaObjects.has(oldKey),false);
  assert.equal(r.mediaObjects.has(newKey),true);
  const orphan='profiles/1111/avatar';
  await r.env.EFFECT_MEDIA.put(orphan,new Uint8Array([9]),{});
  r.mediaObjects.get(orphan).updated_at=Date.now()-2*3600000;
  r.mediaObjects.get(newKey).updated_at=Date.now()-2*3600000;
  await cold.inventoryStorage(r.directory);
  assert.equal(r.mediaObjects.has(orphan),false);
  assert.equal(r.mediaObjects.has(newKey),true);
  assert.equal(r.directory.storageStatus().used_bytes,3);
});
test('a verified inline current DP becomes one R2 object and a small database URL',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1);
  sql(r,"UPDATE app_users SET avatar_data_url=? WHERE user_id=?", 'data:image/png;base64,AQID',a.user_id);
  await cold.inventoryStorage(r.directory);
  assert.equal(await cold.moveInlineAvatar(r.directory),1);
  const current=(await r.directory.getUserById(a.user_id)).avatar_data_url;
  assert.ok(current.startsWith('https://'));
  assert.deepEqual([...r.mediaObjects.get('profiles/'+a.user_id+'/avatar').bytes],[1,2,3]);
});
for(const [binding,prefix,key] of [['FRUIT_GAME','fruit','fruit_jackpot'],['FRUIT_PARTY','party','fruit_party']]) {
  test(binding+' expires 15-day details while preserving unpaid payouts and lifetime totals',async t=>{
    const r=runtime();t.after(r.close);const a=await r.user(1);
    const g=r.direct(binding,'retention');
    g._ensureWallet(a.user_id);
    for(const round of [1,2]) {
      g.ctx.storage.sql.exec('INSERT INTO '+prefix+'_bets(id,round_id,user_id,fruit_key,amount,created_at) VALUES(?,?,?,?,?,?)','bet-'+round,round,a.user_id,'lemon',5000,Date.now());
      await g._settle(round);
    }
    g.ctx.storage.sql.exec('UPDATE '+prefix+'_results SET settled_at=?',Date.now()-16*cold.DAY_MS);
    g.ctx.storage.sql.exec('DELETE FROM '+prefix+'_result_outbox WHERE round_id=1');
    const before=await g.ownerStats(a.user_id);
    const pruned=g.pruneHistory();
    assert.equal(pruned.deleted_rounds,1);
    assert.equal(g.ctx.storage.sql.exec('SELECT id FROM '+prefix+'_bets WHERE round_id=1').toArray().length,0);
    assert.equal(g.ctx.storage.sql.exec('SELECT id FROM '+prefix+'_bets WHERE round_id=2').toArray().length,1);
    const after=await g.ownerStats(a.user_id);
    for(const field of ['bet_count','total_bet','total_payout','house_net','rounds','unique_players']) assert.equal(after[field],before[field]);
    assert.equal(g.pruneHistory().deleted_rounds,0);
  });
}
test('main-game compaction prevents stale debit and payout replay, including lost acknowledgement',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1),now=Date.now();
  const id='fruit_party:'+a.user_id+':retained-request-id';
  sql(r,"INSERT INTO main_game_bets(id,user_id,game_key,round_id,fruit_key,amount,room_id,created_at,settled_at,winning_coins) VALUES(?,?,'fruit_party',1,'lemon',5000,'room',?,?,25000)",
    id,a.user_id,now-16*cold.DAY_MS,now-16*cold.DAY_MS);
  r.directory._creditNormalWalletAuthorized(a.user_id,90000);
  assert.equal(cold.pruneMainGameHistory(r.directory),1);
  const net=r.directory.mainGameWallet(a.user_id,'fruit_party',true).game_net_coins;
  assert.equal(net,20000);
  assert.throws(()=>r.directory.reserveMainGameBet({id,user_id:a.user_id,game_key:'fruit_party',round_id:Math.floor(now/26000),fruit_key:'lemon',amount:5000,room_id:'room'}),/older than retained/);
  const receipt={id:'old-result',user_id:a.user_id,game_key:'fruit_party',round_id:1,winning_coins:25000,bet_coins:5000,
    fruit_key:'lemon',settled_at:now-16*cold.DAY_MS,main_bets:[{id,winning_coins:25000}]};
  r.directory.recordGameResults([receipt]);r.directory.recordGameResults([receipt]);
  assert.equal(r.directory.getWallet(a.user_id).coins,90000);
  assert.equal(r.directory.pendingGameResults(a.user_id).length,0);
  assert.throws(()=>r.directory.recordGameResults([{...receipt,main_bets:[{id,winning_coins:30000}]}]),/identity mismatch/);
});
test('daily cold maintenance is bounded and repeated visits do not trigger archive work',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1);walletRows(r,a.user_id);
  const now=Date.now()+20000;
  const first=await cold.runColdMaintenance(r.directory,now);
  assert.equal(first.archived_wallet_rows,5);
  const count=r.mediaObjects.size;
  const next=await cold.runColdMaintenance(r.directory,now+1000);
  assert.equal(next.skipped,true);
  assert.equal(r.mediaObjects.size,count);
  assert.equal(r.directory.storageStatus().last_run,now);
});
test('rehydrating a directory skips catalog seeding and full user/wallet backfill scans',async t=>{
  const r=runtime();t.after(r.close);await r.user(1);
  const seen=[],original=r.directory.ctx.storage.sql.exec;
  r.directory.ctx.storage.sql.exec=(q,...args)=>{seen.push(q);return original(q,...args);};
  new r.directory.constructor(r.directory.ctx,r.env);
  await Promise.resolve();
  assert.equal(seen.some(q=>q.includes('INSERT OR IGNORE INTO owner_catalog')),false);
  assert.equal(seen.some(q=>q.includes('SELECT auth_provider, auth_subject, user_id')),false);
});

test('new inline signup DP is verified in R2 before inserting small SQL profile data',async t=>{
  const r=runtime();t.after(r.close);
  const input={auth_provider:'google',auth_subject:'signup-avatar',email:'avatar@example.test',
    display_name:'Avatar Test',age:25,signature:'',country_code:'IN',country_name:'India',
    flag_emoji:'🇮🇳',gender:'male',language:'English',avatar_data_url:'data:image/png;base64,AQIDBA=='};
  const account=await r.directory.createUser(input);
  assert.ok(account.avatar_data_url.includes('/media/'));
  assert.equal(sql(r,"SELECT avatar_data_url FROM app_users WHERE user_id=?",account.user_id).one().avatar_data_url,account.avatar_data_url);
  assert.deepEqual([...r.mediaObjects.get('profiles/'+account.user_id+'/avatar').bytes],[1,2,3,4]);
  r.env.R2_BYTE_LIMIT_BYTES=1;
  await assert.rejects(r.directory.createUser({...input,auth_subject:'over-budget-avatar',email:'other@example.test'}),/Storage budget/);
  assert.equal(sql(r,"SELECT COUNT(*) n FROM app_users WHERE email='other@example.test'").one().n,0);
});
