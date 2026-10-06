import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildSync } from 'esbuild';
import { Miniflare } from 'miniflare';

test('real Workers sockets push private account state and all game states without HTTP polling', {timeout:60000}, async t => {
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
      ['APP_DIRECTORY','AppDirectoryStore'], ['ROOM_PRESENCE','RoomPresenceStore'],
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
  await action('/room-presence/join',owner,{room_id:owner.room.id});
  await action('/room-presence/join',guest,{room_id:owner.room.id});
  async function connect(path,user) {
    const response=await mf.dispatchFetch('https://test.local'+path,{
      headers:{Upgrade:'websocket',authorization:'Bearer '+user.token,
        'x-tinni-user-id':owner.user.user_id},
    });
    assert.equal(response.status,101,response.status===101?'':await response.text());
    const events=[];
    const socket=response.webSocket;
    socket.addEventListener('message',event=>events.push(JSON.parse(event.data)));
    socket.accept();
    t.after(()=>{try{socket.close();}catch{}});
    return {socket,events};
  }
  async function until(predicate) {
    const end=Date.now()+5000;
    while(!predicate()&&Date.now()<end) await new Promise(resolve=>setTimeout(resolve,20));
    assert.ok(predicate(),'expected socket event not delivered');
  }
  const account=await connect('/messages/live',guest);
  await until(()=>account.events.some(x=>x.type==='account_state'));
  assert.equal(account.events.find(x=>x.type==='account_state').user.user_id,guest.user.user_id);
  for(const path of ['/fruit-game/live','/fruit-party/live','/ludo/live?room_id='+owner.room.id]) {
    const live=await connect(path,guest);
    await until(()=>live.events.some(x=>x.type==='game_state'));
    live.socket.send(JSON.stringify({type:'state',user_id:owner.user.user_id}));
    await until(()=>live.events.filter(x=>x.type==='game_state').length>=2);
    if(path.startsWith('/ludo')) assert.equal(live.events.at(-1).state.player_color,'red');
  }
  const forbidden=await mf.dispatchFetch('https://test.local/ludo/live?room_id=missing',{
    headers:{Upgrade:'websocket',authorization:'Bearer '+guest.token},
  });
  assert.equal(forbidden.status,403);
  account.socket.send(JSON.stringify({type:'subscribe_rooms',enabled:true}));
  await until(()=>account.events.some(x=>x.type==='rooms_snapshot'));
  assert.ok(account.events.find(x=>x.type==='rooms_snapshot').rooms.some(x=>x.id===owner.room.id));
});
