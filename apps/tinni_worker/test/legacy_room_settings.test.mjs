import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';

test('original room settings migrate before new-column INSERT and all controls work for owner 1000', async t => {
 const r=runtime({legacyRoomSettings:true});t.after(r.close);
 const owner=await r.user(4000),guest=await r.user(4001);
 r.directory._changeUserId(owner.user_id,'1000');
 const room=await r.directory.createRoom('1000',{title:'Existing room',seat_count:12});
 assert.equal(room.id,'1000');
 const presence=r.direct('ROOM_PRESENCE',room.id);
 const migrated=presence.ctx.storage.sql.exec('SELECT * FROM room_runtime_settings WHERE id=1').toArray()[0];
 assert.equal(migrated.mic_mode,'free');
 assert.equal(migrated.updated_at,17);
 assert.equal(migrated.public_screen_enabled,0);
 assert.equal(migrated.comments_clear_version,0);
 assert.equal(migrated.owner_comments_clear_version,0);
 async function act(path,user,body){
  const response=await r.request(path,user.token,body);
  assert.ok(response.status>=200&&response.status<300,path+': '+JSON.stringify(response));
  return response.data;
 }
 await act('/room-presence/join',owner,{room_id:room.id});
 await act('/room-presence/join',guest,{room_id:room.id});
 const seated=await act('/room-presence/seat-take',owner,{room_id:room.id,seat_index:0});
 assert.equal(seated.members.find(x=>x.user_id==='1000').seat_index,0);
 await act('/room-presence/seat-lock',owner,{room_id:room.id,seat_index:2,locked:true});
 assert.ok(presence.lockedSeats().includes(2));
 await act('/room-presence/seat-lock',owner,{room_id:room.id,seat_index:2,locked:false});
 assert.ok(!presence.lockedSeats().includes(2));
 await act('/room-presence/seat-take',guest,{room_id:room.id,seat_index:1});
 await act('/room-presence/seat-mute',owner,{room_id:room.id,seat_index:1,muted:true});
 assert.equal((await presence.state(guest.user_id)).self_mic_muted,true);
 await act('/room-presence/seat-mute',owner,{room_id:room.id,seat_index:1,muted:false});
 assert.equal((await presence.state(guest.user_id)).self_mic_muted,false);
 await act('/room-presence/public-screen',owner,{room_id:room.id,enabled:true});
 assert.equal(presence.publicScreenEnabled(),true);
 await act('/room-presence/clear-comments',owner,{room_id:room.id});
 await act('/room-presence/public-screen',owner,{room_id:room.id,enabled:false});
 await act('/room-presence/mic-mode',owner,{room_id:room.id,mic_mode:'apply'});
 assert.equal(presence.micMode(),'apply');
});
