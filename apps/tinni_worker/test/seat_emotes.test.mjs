import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';

async function fixture(t) {
  const r = runtime(); t.after(r.close);
  const owner = await r.user(99101), viewer = await r.user(99102);
  const room = await r.directory.createRoom(owner.user_id, {title:'Seat emotes',seat_count:12});
  for (const user of [owner, viewer]) {
    const joined = await r.request('/room-presence/join', user.token, {room_id:room.id});
    assert.equal(joined.status,200,JSON.stringify(joined.data));
  }
  const taken = await r.request('/room-presence/seat-take', owner.token, {room_id:room.id,seat_index:0});
  assert.equal(taken.status,200,JSON.stringify(taken.data));
  return {r,owner,viewer,room,presence:r.direct('ROOM_PRESENCE',room.id)};
}

test('all 25 panda and 25 enemy emotes synchronize through the real seat API', async t => {
  const {r,owner,viewer,room} = await fixture(t);
  for (const group of ['panda','enemy']) {
    for (let n=1;n<=25;n++) {
      const emote=group+'-'+String(n).padStart(2,'0');
      const response=await r.request('/room-presence/emote',owner.token,{room_id:room.id,seat_index:0,emote});
      assert.equal(response.status,200,JSON.stringify(response.data));
      const state=await r.request('/room-presence/state?room_id='+room.id,viewer.token);
      const member=state.data.members.find(x=>x.user_id===owner.user_id);
      assert.equal(member.seat_emote,emote);
      assert.equal(member.seat_emote_until-response.data.server_time,5000);
    }
  }
});

test('normal emoji expiry stays three seconds and seat leave clears a pack effect', async t => {
  const {r,owner,room,presence} = await fixture(t);
  const normal=await r.request('/room-presence/emote',owner.token,{room_id:room.id,seat_index:0,emote:'😂'});
  assert.equal(normal.status,200);
  let member=normal.data.members.find(x=>x.user_id===owner.user_id);
  assert.equal(member.seat_emote_until-normal.data.server_time,3000);
  assert.equal(presence._members(member.seat_emote_until+1).find(x=>x.user_id===owner.user_id).seat_emote,null);
  await r.request('/room-presence/emote',owner.token,{room_id:room.id,seat_index:0,emote:'panda-01'});
  const left=await r.request('/room-presence/seat-leave',owner.token,{room_id:room.id});
  assert.equal(left.status,200);
  member=left.data.members.find(x=>x.user_id===owner.user_id);
  assert.equal(member.seat_emote,null);
});

test('pack IDs reject invalid entries and unseated users cannot send effects', async t => {
  const {r,owner,viewer,room} = await fixture(t);
  for (const emote of ['panda-00','panda-26','enemy-00','enemy-99','panda-fake']) {
    const rejected=await r.request('/room-presence/emote',owner.token,{room_id:room.id,seat_index:0,emote});
    assert.equal(rejected.status,400,JSON.stringify(rejected.data));
  }
  const denied=await r.request('/room-presence/emote',viewer.token,{room_id:room.id,seat_index:0,emote:'enemy-25'});
  assert.equal(denied.status,400,JSON.stringify(denied.data));
  const stale=await r.request('/room-presence/emote',owner.token,{room_id:room.id,seat_index:1,emote:'panda-25'});
  assert.equal(stale.status,400,JSON.stringify(stale.data));
});
