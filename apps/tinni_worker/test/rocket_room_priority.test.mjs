
import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';
test('higher rocket launch outranks experience, ties use recent launch and expiry uses country midnight',async t=>{
 let now=Date.parse('2026-10-05T18:29:00Z');
 t.mock.method(Date,'now',()=>now);
 const r=runtime();t.after(r.close);const users=[];
 for(let i=0;i<3;i++) users.push(await r.user(1600+i));
 const rooms=[];
 for(const user of users) rooms.push(await r.directory.createRoom(user.user_id,{title:'Priority '+user.user_id,seat_count:12}));
 const d=r.directory;
 d.ctx.storage.sql.exec(`INSERT INTO gift_transactions(id,room_id,sender_id,receiver_id,gift_id,gift_name,quantity,unit_price,total_cost,created_at) VALUES('experience-fixture',?,?,?,'rose','Rose',1,999999999,999999999,?)`,rooms[0].id,users[0].user_id,users[1].user_id,now);
 d.ctx.storage.sql.exec("UPDATE app_rooms SET country_code='SA' WHERE id=?",rooms[1].id);
 d._boostRocketRoom(rooms[0].id,4,now);
 d._boostRocketRoom(rooms[1].id,9,now);
 d._boostRocketRoom(rooms[2].id,9,now+100);
 let sorted=await d.listRooms();
 assert.deepEqual(sorted.slice(0,3).map(x=>x.id),[rooms[2].id,rooms[1].id,rooms[0].id]);
 assert.equal(sorted[0].rocket_launch_level,9);
 d._boostRocketRoom(rooms[1].id,1,now+200);
 assert.equal(d.ctx.storage.sql.exec('SELECT level FROM rocket_room_boosts WHERE room_id=?',rooms[1].id).toArray()[0].level,9);
 now=Date.parse('2026-10-05T18:30:00Z');
 sorted=await d.listRooms();
 assert.equal(sorted[0].id,rooms[1].id);
 assert.equal(sorted.find(x=>x.id===rooms[0].id).rocket_launch_level,0);
 assert.equal(sorted.find(x=>x.id===rooms[2].id).rocket_launch_level,0);
 now=Date.parse('2026-10-05T21:00:00Z');
 assert.ok((await d.listRooms()).every(x=>x.rocket_launch_level===0));
});
test('only a completed launch boosts a room, independently in every room',async t=>{
 const r=runtime();t.after(r.close);
 const a=await r.user(1701),b=await r.user(1702);
 const ra=await r.directory.createRoom(a.user_id,{title:'First',seat_count:12});
 const rb=await r.directory.createRoom(b.user_id,{title:'Second',seat_count:12});
 for(const [sender,room,receiver] of [[a,ra,b],[b,rb,a]]){
  r.directory.getWallet(sender.user_id);
  r.directory._creditNormalWalletAuthorized(sender.user_id,8000000,'test_fixture');
  const partial=await r.request('/gifts/send',sender.token,{room_id:room.id,gift_id:'hot-biryani',quantity:159,receiver_ids:[receiver.user_id]});
  assert.equal(partial.status,201);
  assert.equal((await r.directory.listRooms()).find(x=>x.id===room.id).rocket_launch_level,0);
  const launch=await r.request('/gifts/send',sender.token,{room_id:room.id,gift_id:'hot-biryani',quantity:1,receiver_ids:[receiver.user_id]});
  assert.equal(launch.status,201);
  assert.equal((await r.directory.listRooms()).find(x=>x.id===room.id).rocket_launch_level,1);
 }
});
