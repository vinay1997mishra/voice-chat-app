import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildSync } from 'esbuild';
import { Miniflare } from 'miniflare';

for (const legacy of [false,true]) {
test('real Workers RPC: '+(legacy ? 'legacy settings migration, ' : '')+'room entry, seat controls and WebSocket acknowledgement', { timeout: 60000 }, async t => {
  const folder = mkdtempSync(join(tmpdir(), 'tinni-workerd-'));
  const scriptPath = join(folder, 'entry.mjs');
  buildSync({
    entryPoints: [new URL('./helpers/workerd-entry.mjs', import.meta.url).pathname],
    outfile: scriptPath, bundle: true, format: 'esm', platform: 'browser',
    external: ['cloudflare:workers'],
  });
  const secret = 'isolated-workerd-secret';
  const mf = new Miniflare({
    rootPath: folder, modulesRoot: folder,
    modules: true, scriptPath, compatibilityDate: '2025-08-29',
    bindings: { SESSION_SECRET: secret },
    r2Buckets: ['EFFECT_MEDIA'],
    durableObjects: Object.fromEntries([
      ['APP_DIRECTORY','AppDirectoryStore'], ['ROOM_PRESENCE',legacy ? 'LegacyRoomPresenceStore' : 'RoomPresenceStore'],
      ['FRUIT_GAME','FruitGameStore'], ['FRUIT_PARTY','FruitPartyStore'],
      ['STAFF_AUTH','StaffAuthStore'],
    ].map(([binding,className]) => [binding,{className,useSQLite:true}])),
  });
  t.after(async () => { await mf.dispose(); rmSync(folder,{recursive:true,force:true}); });
  async function seed(index,createRoom=false) {
    const response = await mf.dispatchFetch('https://test.local/__fixture/user', {
      method:'POST', body:JSON.stringify({index,createRoom}),
    });
    assert.equal(response.status,200,await response.clone().text());
    const data = await response.json();
    const payload = Buffer.from(JSON.stringify({
      role:'user',userId:data.user.user_id,provider:'google',subject:'workerd-'+index,
      exp:Date.now()+600000,
    })).toString('base64url');
    return {...data,token:payload+'.'+createHmac('sha256',secret).update(payload).digest('base64url')};
  }
  async function action(path,user,body) {
    const response = await mf.dispatchFetch('https://test.local'+path,{
      method:body===undefined?'GET':'POST',
      headers:{authorization:'Bearer '+user.token,'content-type':'application/json'},
      ...(body===undefined?{}:{body:JSON.stringify(body)}),
    });
    const text = await response.text();
    assert.ok(response.status>=200&&response.status<300,path+': '+response.status+' '+text);
    return JSON.parse(text);
  }
  const owner=await seed(1,true), guest=await seed(2);
  const roomId=owner.room.id;
  await action('/room-presence/join',owner,{room_id:roomId});
  const joinedGuest = await action('/room-presence/join',guest,{room_id:roomId});
  assert.equal(joinedGuest.seat_count,12);
  await action('/room-presence/mic-mode',owner,{room_id:roomId,mic_mode:'free'});
  const taken=await action('/room-presence/seat-take',guest,{room_id:roomId,seat_index:1});
  assert.equal(taken.members.find(x=>x.user_id===guest.user.user_id).seat_index,1);
  await action('/room-presence/heartbeat',guest,{room_id:roomId,seat_index:1,mic_enabled:true});
  const retry=await action('/room-presence/seat-take',guest,{room_id:roomId,seat_index:1});
  assert.equal(retry.members.find(x=>x.user_id===guest.user.user_id).mic_enabled,true);
  const wsResponse=await mf.dispatchFetch(
    'https://test.local/room-presence/live?room_id='+roomId+'&auth_token='+encodeURIComponent(guest.token),
    {headers:{Upgrade:'websocket',authorization:'Bearer '+guest.token}},
  );
  if (wsResponse.status !== 101) assert.fail(await wsResponse.text());
  const socket=wsResponse.webSocket;
  socket.accept();
  t.after(()=>{try {socket.close();} catch (_) {}});
  const messages=[];
  socket.addEventListener('message',event=>messages.push(JSON.parse(event.data)));
  socket.send(JSON.stringify({type:'seat_state',seat_index:1,mic_enabled:true}));
  await new Promise(resolve=>setTimeout(resolve,100));
  const state=await action('/room-presence/state?room_id='+roomId,guest);
  assert.equal(state.members.find(x=>x.user_id===guest.user.user_id).seat_index,1);
  assert.equal(state.members.find(x=>x.user_id===guest.user.user_id).mic_enabled,true);
  // Delayed audience heartbeat and socket state cannot evict a seated user.
  for (let i=0;i<2;i++) {
    const stale=await action('/room-presence/heartbeat',guest,{room_id:roomId,seat_index:null,mic_enabled:false});
    assert.equal(stale.members.find(x=>x.user_id===guest.user.user_id).seat_index,1);
  }
  socket.send(JSON.stringify({type:'seat_state',seat_index:null,mic_enabled:false}));
  await new Promise(resolve=>setTimeout(resolve,100));
  assert.equal((await action('/room-presence/state?room_id='+roomId,guest)).members.find(x=>x.user_id===guest.user.user_id).seat_index,1);
  socket.close();
  await action('/room-presence/seat-lock',owner,{room_id:roomId,seat_index:2,locked:true});
  assert.ok((await action('/room-presence/state?room_id='+roomId,guest)).locked_seats.includes(2));
  await action('/room-presence/seat-lock',owner,{room_id:roomId,seat_index:2,locked:false});
  await action('/room-presence/seat-mute',owner,{room_id:roomId,seat_index:1,muted:true});
  assert.equal((await action('/room-presence/state?room_id='+roomId,guest)).self_mic_muted,true);
  await action('/room-presence/seat-mute',owner,{room_id:roomId,seat_index:1,muted:false});
  assert.equal((await action('/room-presence/state?room_id='+roomId,guest)).self_mic_muted,false);
  await action('/room-presence/seat-leave',guest,{room_id:roomId});
  assert.equal((await action('/room-presence/state?room_id='+roomId,guest)).members.find(x=>x.user_id===guest.user.user_id).seat_index,null);
  await action('/room-presence/mic-mode',owner,{room_id:roomId,mic_mode:'apply'});
  await action('/room-presence/seat-request',guest,{room_id:roomId,seat_index:2});
  await action('/room-presence/seat-request/resolve',owner,{room_id:roomId,target_user_id:guest.user.user_id,approved:true});
  assert.equal((await action('/room-presence/state?room_id='+roomId,guest)).self_forced_seat_index,2);
  await action('/room-presence/seat-leave',guest,{room_id:roomId});
  await action('/room-presence/seat-invite',owner,{room_id:roomId,target_user_id:guest.user.user_id,seat_index:3});
  assert.equal((await action('/room-presence/state?room_id='+roomId,guest)).pending_seat_invite.seat_index,3);
  const accepted = await action('/room-presence/seat-invite/respond',guest,{room_id:roomId,accepted:true});
  assert.equal(accepted.seat_index,3);
  const acceptedAgain = await action('/room-presence/seat-invite/respond',guest,{room_id:roomId,accepted:true});
  assert.equal(acceptedAgain.seat_index,3);
  await action('/room-presence/public-screen',owner,{room_id:roomId,enabled:true});
  assert.equal((await action('/room-presence/state?room_id='+roomId,guest)).public_screen_enabled,true);
  const comment=await action('/room-presence/comment',guest,{room_id:roomId,text:'HTTP fallback comment',client_event_id:'comment-1'});
  const repeatedComment=await action('/room-presence/comment',guest,{room_id:roomId,text:'HTTP fallback comment',client_event_id:'comment-1'});
  assert.equal(comment.message.id,repeatedComment.message.id);
  assert.equal((await action('/room-presence/state?room_id='+roomId,owner)).chat_messages.length,1);
  await action('/room-presence/clear-comments',owner,{room_id:roomId});
  assert.equal((await action('/room-presence/state?room_id='+roomId,guest)).chat_messages.length,0);
  await action('/room-presence/public-screen',owner,{room_id:roomId,enabled:false});
  assert.equal((await action('/room-presence/state?room_id='+roomId,guest)).public_screen_enabled,false);
  await action('/room-presence/seat-leave',guest,{room_id:roomId});
  const again = await action('/room-presence/seat-take',owner,{room_id:roomId,seat_index:0});
  assert.equal(again.members.find(x=>x.user_id===owner.user.user_id).seat_index,0);
});

}
