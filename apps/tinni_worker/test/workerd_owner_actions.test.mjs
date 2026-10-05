import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildSync } from 'esbuild';
import { Miniflare } from 'miniflare';


test('owner actions persist through real SQLite/RPC and require the owner session', { timeout: 60000 }, async t => {
  const folder = mkdtempSync(join(tmpdir(), 'tinni-owner-workerd-'));
  const scriptPath = join(folder, 'entry.mjs');
  buildSync({
    entryPoints: [new URL('./helpers/workerd-entry.mjs', import.meta.url).pathname],
    outfile: scriptPath, bundle: true, format: 'esm', platform: 'browser',
    external: ['cloudflare:workers'],
  });
  const secret = 'isolated-owner-secret';
  const email = 'owner@example.test';
  const mf = new Miniflare({
    rootPath: folder, modulesRoot: folder,
    modules: true, scriptPath, compatibilityDate: '2025-08-29',
    bindings: { SESSION_SECRET: secret, OWNER_EMAIL: email },
    r2Buckets: ['EFFECT_MEDIA'],
    durableObjects: Object.fromEntries([
      ['APP_DIRECTORY','AppDirectoryStore'], ['ROOM_PRESENCE','RoomPresenceStore'],
      ['FRUIT_GAME','FruitGameStore'], ['FRUIT_PARTY','FruitPartyStore'],
      ['STAFF_AUTH','StaffAuthStore'],
    ].map(([binding,className]) => [binding,{className,useSQLite:true}])),
  });
  t.after(async () => { await mf.dispose(); rmSync(folder,{recursive:true,force:true}); });
  function token(role, tokenEmail = email) {
    const payload = Buffer.from(JSON.stringify({role, email: tokenEmail, exp: Date.now()+600000})).toString('base64url');
    return payload+'.'+createHmac('sha256',secret).update(payload).digest('base64url');
  }
  const cookie = 'tinni_owner_session=' + token('owner');
  async function request(path, body, sessionCookie = cookie) {
    const response = await mf.dispatchFetch('https://test.local'+path, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { cookie: sessionCookie, 'content-type':'application/json' },
      ...(body === undefined ? {} : {body:JSON.stringify(body)}),
    });
    return {status:response.status, data:await response.json()};
  }
  async function action(name, data) {
    const result = await request('/api/owner/action', {action:name,data});
    assert.equal(result.status, 200, name+': '+JSON.stringify(result.data));
    assert.equal(result.data.ok,true,name);
    return result.data;
  }
  const seed = await mf.dispatchFetch('https://test.local/__fixture/user', {
    method:'POST',body:JSON.stringify({index:101,createRoom:true,markRecent:true}),
  });
  const {user,room} = await seed.json();
  const uid = user.user_id;
  const rid = room.id;
  for (const deniedCookie of ['', 'tinni_owner_session='+token('user'),
    'tinni_owner_session='+token('owner','intruder@example.test')]) {
    const denied = await request('/api/owner/action', {
      action:'wallet-normal',data:{user_id:uid,operation:'credit',amount:1000},
    }, deniedCookie);
    assert.ok(denied.status===401 || denied.status===403, JSON.stringify(denied));
  }

  const named = await action('user-name',{user_id:uid,display_name:'Final Player'});
  assert.equal(named.result.display_name,'Final Player');
  await action('user-dp',{user_id:uid,asset_url:'https://example.test/player.png'});
  for (const name of ['user-ban','device-ban']) {
    await action(name,{user_id:uid,status:'ban'});
    await action(name,{user_id:uid,status:'unban'});
  }
  for (const name of ['user-invisible','locked-bypass']) {
    await action(name,{user_id:uid,status:'on'});
    await action(name,{user_id:uid,status:'off'});
  }
  await action('vip-grant',{user_id:uid,vip_level:2,operation:'grant'});
  await action('vip-grant',{user_id:uid,operation:'remove'});
  const numeric = await action('unique-id-new',{public_id:'876543',price_coins:500,duration_days:7});
  assert.equal(numeric.result.id_type,'number');
  const nameId = await action('unique-id-new',{public_id:'FinalStar',price_coins:500});
  assert.equal(nameId.result.id_type,'name');
  await action('unique-id-price',{public_id:'876543',price_coins:750,duration_days:30});
  await action('room-name',{room_id:rid,room_name:'Final Room'});
  await action('room-dp',{room_id:rid,asset_url:'https://example.test/room.png'});
  await action('room-bg',{room_id:rid,asset_url:'https://example.test/background.png'});
  await action('room-ban',{room_id:rid,status:'ban'});
  await action('room-ban',{room_id:rid,status:'unban'});

  for (const [asset,amount] of [['coins',1000],['diamonds',100]]) {
    const credited=await action('wallet-normal',{user_id:uid,asset,operation:'credit',amount});
    assert.equal(credited.result[asset],amount);
    const debited=await action('wallet-normal',{user_id:uid,asset,operation:'debit',amount:10});
    assert.equal(debited.result[asset],amount-10);
  }
  for (const name of ['wallet-seller','wallet-merchant']) {
    await action(name,{user_id:uid,operation:'create',amount:0});
    await action(name,{user_id:uid,operation:'credit',amount:1000});
    await action(name,{user_id:uid,operation:'debit',amount:10});
    await action(name,{user_id:uid,operation:'ban',amount:0});
    await action(name,{user_id:uid,operation:'unban',amount:0});
  }
  await action('treasury-add',{amount:5000});
  const beforeTreasury = (await request('/api/owner/state')).data.state.treasury.balance;
  const failedSend = await request('/api/owner/action', {
    action:'treasury-send',data:{user_id:'no-such-user',wallet_type:'normal',amount:100},
  });
  assert.equal(failedSend.status,400);
  assert.equal((await request('/api/owner/state')).data.state.treasury.balance,beforeTreasury,
    'A rejected recipient must not debit treasury');
  const sent=await action('treasury-send',{user_id:uid,wallet_type:'normal',amount:100});
  assert.equal(sent.result.treasury.balance,beforeTreasury-100);
  assert.equal(sent.result.wallet.coins,1090);

  const hierarchyUsers=[];
  for (const index of [102,103,104]) {
    const response=await mf.dispatchFetch('https://test.local/__fixture/user',{
      method:'POST',body:JSON.stringify({index}),
    });
    hierarchyUsers.push((await response.json()).user.user_id);
  }
  const [bd,agency,host]=hierarchyUsers;
  await action('bd-activate',{user_id:bd,operation:'activate'});
  await action('agency-activate',{user_id:agency,operation:'activate'});
  await action('agency-to-bd',{agency_owner_id:agency,bd_user_id:bd});
  await action('host-add',{host_user_id:host,agency_owner_id:agency});
  await action('host-remove',{host_user_id:host,agency_owner_id:agency});
  await action('agency-from-bd',{agency_owner_id:agency});
  await action('agency-activate',{user_id:agency,operation:'remove'});
  await action('bd-activate',{user_id:bd,operation:'remove'});

  for (const kind of ['vip','entry','vehicle','frame','ring','bubble','profile-background','profile-card','banner','role']) {
    const created=await action(kind+'-new',{
      name:'Final '+kind,title:'Final '+kind,level:1,asset_url:'https://example.test/asset.png',
    });
    assert.ok(created.result.id,kind);
    await action('catalog-remove',{id:created.result.id});
  }
  await action('lucky-gift-config',{enabled:true});
  await action('user-price-override-set',{user_id:uid,price_key:'cp_connect_coins',price_coins:500,duration_days:7});
  await action('user-price-override-remove',{user_id:uid,price_key:'cp_connect_coins'});
  await action('feature-set',{key:'final_verified_feature',enabled:true});
  await action('policy-set',{key:'final_verified_policy',value:123});
  await action('game-switch',{enabled:true});
  await action('game-limits',{min_bet:5000,max_bet:10000000});
  const gift = await action('gift-new',{name:'Final Test Gift',coin_price:500,category:'Normal'});
  const giftId=gift.result.id;
  assert.ok(giftId);
  await action('catalog-toggle',{id:giftId,enabled:false});
  await action('catalog-edit',{id:giftId,patch:{name:'Updated Final Gift'}});
  await action('catalog-remove',{id:giftId});

  const read = await request('/api/owner/state');
  assert.equal(read.status,200,JSON.stringify(read.data));
  assert.equal(read.data.state.features.final_verified_feature,true);
  assert.equal(read.data.state.policies.final_verified_policy,123);
  assert.equal(read.data.state.game_config.min_bet,5000);
  const detail=await request('/api/owner/user-detail?user_id='+encodeURIComponent(uid));
  assert.equal(detail.status,200,JSON.stringify(detail.data));
  assert.equal(detail.data.detail.user.display_name,'Final Player');
  assert.equal(detail.data.detail.recent_rooms[0].room_id,rid);
  assert.ok(detail.data.detail.recent_rooms[0].last_entered_at>0);
});
