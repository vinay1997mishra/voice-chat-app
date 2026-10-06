import test from 'node:test';
import assert from 'node:assert/strict';
import { rocketPolicy,rocketAllocation,rocketDraw } from '../src/rocket_rewards.js';
import { runtime } from './helpers/runtime.mjs';

test('ten levels use linear top rewards, growing recipient count and per-person caps',()=>{
 for(let level=1;level<=10;level++){
  const policy=rocketPolicy(level);
  assert.deepEqual(policy.topCoins,[400000*level,200000*level,100000*level]);
  assert.equal(policy.winners,50+(level-1)*20);
  const ranked=[{user_id:'a',sending:30},{user_id:'b',sending:20},{user_id:'c',sending:10}];
  const audience=Array.from({length:300},(_,i)=>'audience-'+i);
  const rewards=rocketDraw(level,ranked,audience,bound=>bound-1);
  assert.equal(rewards.length,policy.winners);
  assert.equal(new Set(rewards.map(r=>r.user_id)).size,rewards.length);
  assert.deepEqual(rewards.slice(0,3).map(r=>r.coins),policy.topCoins);
  const normal=rewards.slice(3);
  assert.equal(normal.filter(r=>r.coins>0).length,25);
  for(const reward of normal){
   assert.equal(Boolean(reward.coins),!Boolean(reward.frame_id));
   assert.equal(reward.medal,null);
   assert.ok(reward.coins <= (level>=6?30000:20000));
  }
 }
});
test('one gift crossing two rockets allocates contribution to each stage exactly',()=>{
 assert.deepEqual(rocketAllocation(7900000,15200000),[
  {level:1,value:100000,completed:true},
  {level:2,value:15000000,completed:true},
  {level:3,value:100000,completed:false}]);
 assert.deepEqual(rocketAllocation(1643000000,100),[]);
});
test('seven-second server window excludes late joins and payout is exactly once',async t=>{
 const r=runtime();t.after(r.close);
 const users=[];for(let i=0;i<55;i++) users.push(await r.user(800+i));
 const owner=users[0],room=await r.directory.createRoom(owner.user_id,{title:'Rocket rewards',seat_count:12});
 const d=r.directory,sql=d.ctx.storage.sql;
 d._ensureRocketRoom(room.id);
 const launch=100000;
 for(let i=0;i<3;i++) sql.exec('INSERT INTO rocket_contributions(room_id,level,user_id,sending) VALUES(?,1,?,?)',room.id,users[i].user_id,300-i*100);
 sql.exec('INSERT INTO rocket_completions(room_id,level,completed_at,historical) VALUES(?,1,?,0)',room.id,launch);
 for(let i=3;i<53;i++) d._captureRocketAudience(room.id,users[i].user_id,launch+6999);
 d._captureRocketAudience(room.id,users[53].user_id,launch+7000);
 d._captureRocketAudience(room.id,users[54].user_id,launch+7001);
 assert.equal(d.settleRocketLaunches(launch+6999),0);
 assert.equal(d.settleRocketLaunches(launch+7000),1);
 const rewards=sql.exec('SELECT * FROM rocket_rewards WHERE room_id=?',room.id).toArray();
 assert.equal(rewards.length,50);
 assert.equal(rewards.filter(x=>x.rank==null&&x.coins>0).length,25);
 assert.ok(!rewards.some(x=>x.user_id===users[53].user_id||x.user_id===users[54].user_id));
 for(let i=0;i<3;i++){
  const inv=d.inventoryState(users[i].user_id);
  assert.ok(inv.owned.some(x=>x.item_id==='rocket-l1-top'+(i+1)));
  assert.equal(d.getWallet(users[i].user_id).coins,[400000,200000,100000][i]);
  assert.ok(d.listUserMedals(users[i].user_id).some(m=>m.name==='Rocket 1'));
 }
 const ledger=sql.exec("SELECT COUNT(*) AS count FROM wallet_transactions WHERE kind='rocket_reward'").toArray()[0].count;
 assert.equal(d.settleRocketLaunches(launch+999999),0);
 assert.equal(sql.exec("SELECT COUNT(*) AS count FROM wallet_transactions WHERE kind='rocket_reward'").toArray()[0].count,ledger);
});

test('real gift launch is global, waits seven seconds, grants top frame and coins once',async t=>{
 const r=runtime();t.after(r.close);
 const a=await r.user(1001),b=await r.user(1002);
 const room=await r.directory.createRoom(a.user_id,{title:'Global launch',seat_count:12});
 r.directory.getWallet(a.user_id);
 r.directory._creditNormalWalletAuthorized(a.user_id,8000000,'test_fixture');
 const sent=await r.request('/gifts/send',a.token,{request_id:crypto.randomUUID(),room_id:room.id,gift_id:'hot-biryani',quantity:160,receiver_ids:[b.user_id]});
 assert.equal(sent.status,201,JSON.stringify(sent.data));
 assert.equal(sent.data.wallet.coins,0);
 const us=r.directory.countryRibbons('US'),inr=r.directory.countryRibbons('IN');
 const banner=us.find(row=>row.kind==='rocket_launch');
 assert.ok(banner);
 assert.ok(inr.some(row=>row.id===banner.id));
 assert.equal(banner.expires_at-banner.created_at,9000);
 assert.equal(r.directory.settleRocketLaunches(banner.created_at+6999),0);
 assert.equal(r.directory.settleRocketLaunches(banner.created_at+7000),1);
 assert.equal(r.directory.getWallet(a.user_id).coins,400000);
 r.directory.equipFrame(a.user_id,'rocket-l1-top1');
 assert.equal(r.directory.inventoryState(a.user_id).equipped_frame_id,'rocket-l1-top1');
 assert.throws(()=>r.directory.equipFrame(b.user_id,'rocket-l1-top1'),/not owned/);
 assert.equal(r.directory.settleRocketLaunches(banner.created_at+8000),0);
 assert.equal(r.directory.getWallet(a.user_id).coins,400000);
});

test('public ID change preserves rocket contribution, earned frame, medal and paid coin ledger',async t=>{
 const r=runtime();t.after(r.close);
 const a=await r.user(1101),room=await r.directory.createRoom(a.user_id,{title:'ID migration',seat_count:12});
 const d=r.directory,sql=d.ctx.storage.sql;
 d._ensureRocketRoom(room.id);
 sql.exec('INSERT INTO rocket_contributions(room_id,level,user_id,sending) VALUES(?,1,?,8000000)',room.id,a.user_id);
 sql.exec('INSERT INTO rocket_completions(room_id,level,completed_at,historical) VALUES(?,1,0,0)',room.id);
 d.settleRocketLaunches(7000);
 const old=a.user_id;
 d._changeUserId(old,'99999999');
 assert.equal(d.getWallet('99999999').coins,400000);
 assert.equal(d._rocketRanking(room.id,1)[0].user_id,'99999999');
 assert.ok(d.listUserMedals('99999999').some(m=>m.name==='Rocket 1'));
 assert.ok(d.inventoryState('99999999').owned.some(x=>x.item_id==='rocket-l1-top1'));
 assert.equal(sql.exec('SELECT COUNT(*) AS n FROM rocket_rewards WHERE user_id=?',old).toArray()[0].n,0);
});

test('authenticated personal Rocket reward never exposes another recipient', async t => {
 const r=runtime();t.after(r.close);
 const a=await r.user(2101),b=await r.user(2102),c=await r.user(2103);
 const d=r.directory,room=await d.createRoom(a.user_id,{title:'Private rewards',seat_count:12});
 d._ensureRocketRoom(room.id);
 const sql=d.ctx.storage.sql;
 sql.exec('INSERT INTO rocket_completions(room_id,level,completed_at,historical,settled_at) VALUES(?,1,0,0,1)',room.id);
 sql.exec('INSERT INTO rocket_rewards(room_id,level,user_id,rank,coins,frame_id,medal,credited,created_at) VALUES(?,1,?,1,400000,?,?,1,0)',
   room.id,a.user_id,'rocket-l1-top1','Rocket 1');
 sql.exec('INSERT INTO rocket_rewards(room_id,level,user_id,coins,frame_id,credited,created_at) VALUES(?,1,?,0,?,1,0)',
   room.id,b.user_id,'rocket-l1-member7');
 const path='/gifts/rocket-reward?room_id='+room.id+'&level=1';
 const first=await r.request(path,a.token);
 assert.equal(first.status,200);
 assert.equal(first.data.reward.user_id,a.user_id);
 assert.equal(first.data.reward.coins,400000);
 assert.equal(first.data.reward.medal,'Rocket 1');
 const second=await r.request(path+'&user_id='+a.user_id,b.token);
 assert.equal(second.status,200);
 assert.equal(second.data.reward.user_id,b.user_id);
 assert.equal(second.data.reward.coins,0);
 assert.equal(second.data.reward.frame_id,'rocket-l1-member7');
 assert.equal(second.data.reward.medal,null);
 const nonWinner=await r.request(path,c.token);
 assert.equal(nonWinner.data.settled,true);
 assert.equal(nonWinner.data.reward,null);
 assert.equal((await r.request(path)).status,401);
 for(const level of [0,11,1.5]){
   assert.equal((await r.request('/gifts/rocket-reward?room_id='+room.id+'&level='+level,a.token)).status,400);
 }
 const publicState=await r.request('/gifts/ranking?room_id='+room.id,a.token);
 const top=publicState.data.rocket_levels[0].top;
 assert.equal(top[0].user_id,a.user_id);
 for(const row of top) for(const field of ['coins','frame_id','medal','awarded']) {
   assert.equal(Object.hasOwn(row,field),false);
 }
 assert.equal(sql.exec('SELECT COUNT(*) AS n FROM rocket_rewards WHERE room_id=?',room.id).toArray()[0].n,2);
});
