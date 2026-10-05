import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';
import { countryDay } from '../src/country_clock.js';

test('country-local owner bonus credits one closed sending day exactly once; no sending means no repeated bonus',async t=>{
 let now=Date.parse('2026-10-05T18:29:00Z');t.mock.method(Date,'now',()=>now);
 const r=runtime();t.after(r.close);
 const receiver=await r.user(3000),owners=[];
 for(const [n,code] of [[3001,'IN'],[3002,'SA'],[3003,'US'],[3004,'NP']]){
  const owner=await r.user(n),room=await r.directory.createRoom(owner.user_id,{title:code,seat_count:12});
  r.directory.ctx.storage.sql.exec("UPDATE app_rooms SET country_code=? WHERE id=?",code,room.id);
  r.directory.getWallet(owner.user_id);
  r.directory._creditNormalWalletAuthorized(owner.user_id,100000,'test_fixture');
  const sent=await r.request('/gifts/send',owner.token,{room_id:room.id,gift_id:'rose',quantity:10,receiver_ids:[receiver.user_id]});
  assert.equal(sent.status,201,JSON.stringify(sent.data));
  const clock=countryDay(code,now);
  const stored=r.directory.ctx.storage.sql.exec('SELECT resets_at FROM room_gift_daily_clock WHERE room_id=?',room.id).toArray()[0];
  assert.equal(Number(stored.resets_at),clock.resets_at);
  owners.push({owner,room,code,deadline:clock.resets_at});
 }
 assert.equal(r.directory.settleRoomGiftOwnerShares(now).credited_coins,0);
 for(const item of [...owners].sort((a,b)=>a.deadline-b.deadline)){
  now=item.deadline;
  r.directory.settleRoomGiftOwnerShares(now);
  const credits=r.directory.ctx.storage.sql.exec("SELECT * FROM wallet_transactions WHERE user_id=? AND kind='room_gift_owner_share'",item.owner.user_id).toArray();
  assert.equal(credits.length,1);assert.equal(credits[0].coins_delta,100);
  assert.equal(r.directory.settleRoomGiftOwnerShares(now).credited_coins,0);
 }
 assert.equal(r.directory.settleRoomGiftOwnerShares(now+4*86400000).credited_coins,0);
 const item=owners[0];
 const sent=await r.request('/gifts/send',item.owner.token,{room_id:item.room.id,gift_id:'rose',quantity:20,receiver_ids:[receiver.user_id]});
 assert.equal(sent.status,201);
 now=countryDay(item.code,now).resets_at;
 assert.equal(r.directory.settleRoomGiftOwnerShares(now).credited_coins,200);
 assert.equal(r.directory.settleRoomGiftOwnerShares(now).credited_coins,0);
});

test('daily room EXP uses 2000 per present user, sending uses normal 100% and Lucky 10%, exits and midnight remove only their respective EXP',async t=>{
 let now=Date.parse('2026-10-05T18:29:00Z');t.mock.method(Date,'now',()=>now);
 const r=runtime();t.after(r.close);
 const owner=await r.user(3101),visitor=await r.user(3102);
 const room=await r.directory.createRoom(owner.user_id,{title:'Daily EXP',seat_count:12});
 r.directory.touchPresence(owner.user_id,room.id,1,false);
 r.directory.touchPresence(visitor.user_id,room.id,2,false);
 r.directory.getWallet(owner.user_id);
 r.directory._creditNormalWalletAuthorized(owner.user_id,100000,'test_fixture');
 for(const gift of ['rose','lucky-colorful-rose']){
  const sent=await r.request('/gifts/send',owner.token,{room_id:room.id,gift_id:gift,quantity:1,receiver_ids:[visitor.user_id]});
  assert.equal(sent.status,201,JSON.stringify(sent.data));
 }
 let summary=(await r.directory.listRooms()).find(x=>x.id===room.id);
 const expected=102; // Rose 100 + Lucky Colorful Rose 20 * 10%.
 assert.equal(summary.sending_exp,Number(expected));
 assert.equal(r.directory.roomGiftRanking(room.id,'day').ranking[0].sending,102);
 assert.equal(summary.active_user_exp,4000);
 assert.equal(summary.room_experience,4000+Number(expected));
 r.directory.clearPresence(visitor.user_id,room.id,1);
 summary=(await r.directory.listRooms()).find(x=>x.id===room.id);
 assert.equal(summary.room_experience,2000+Number(expected));
 now=Date.parse('2026-10-05T18:30:00Z');
 summary=(await r.directory.listRooms()).find(x=>x.id===room.id);
 assert.equal(summary.sending_exp,0);assert.equal(summary.room_experience,2000);
 assert.deepEqual(r.directory.roomGiftRanking(room.id,'day').ranking,[]);
});

test('seat-take infrastructure error returns a diagnostic reference and a retry never silently loses the seat',async t=>{
 const r=runtime();t.after(r.close);const owner=await r.user(3201);
 const room=await r.directory.createRoom(owner.user_id,{title:'Seat diagnostic',seat_count:12});
 const find=r.directory.findRoomByExactId.bind(r.directory);
 r.directory.findRoomByExactId=()=>{throw new Error('isolated infrastructure failure');};
 const failed=await r.request('/room-presence/seat-take',owner.token,{room_id:room.id,seat_index:0});
 assert.equal(failed.status,503);assert.equal(failed.data.retryable,true);
 assert.match(failed.data.incident_id,/^[a-f0-9-]{36}$/);
 r.directory.findRoomByExactId=find;
 const seated=await r.request('/room-presence/seat-take',owner.token,{room_id:room.id,seat_index:0});
 assert.equal(seated.status,200,JSON.stringify(seated.data));assert.equal(seated.data.seat_index,0);
 const heartbeat=await r.request('/room-presence/heartbeat',owner.token,{room_id:room.id,seat_index:null,mic_enabled:false});
 assert.equal(heartbeat.status,200);
 assert.equal(heartbeat.data.members.find(x=>x.user_id===owner.user_id).seat_index,0);
});
