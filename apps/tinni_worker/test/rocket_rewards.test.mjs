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
