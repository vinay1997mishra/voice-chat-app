import test from 'node:test';
import assert from 'node:assert/strict';
import {runtime} from './helpers/runtime.mjs';

function socket(userId) {
  let attachment={userId,expiresAt:Date.now()+60000};
  return {sent:[],closed:false,deserializeAttachment:()=>attachment,
    serializeAttachment:value=>{attachment=value;},
    send(text){this.sent.push(JSON.parse(text));},close(){this.closed=true;}};
}
test('chat profile snapshots and DP updates are public-only, subscribed and hibernation-safe',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1),b=await r.user(2),c=await r.user(3);
  const watcher=socket(a.user_id),other=socket(c.user_id);
  r.directory.ctx.getWebSockets=()=>[watcher,other];
  await r.directory.webSocketMessage(watcher,JSON.stringify({type:'subscribe_profiles',user_ids:[b.user_id]}));
  const snapshot=watcher.sent.at(-1);
  assert.equal(snapshot.type,'profiles_state');
  assert.equal(snapshot.users[0].user_id,b.user_id);
  assert.equal('email' in snapshot.users[0],false);
  assert.equal('wallet' in snapshot.users[0],false);
  const before=watcher.sent.length;
  await r.directory.webSocketMessage(watcher,JSON.stringify({type:'subscribe_profiles',user_ids:[b.user_id]}));
  assert.equal(watcher.sent.length,before);
  await r.directory.updateUserProfile(b.user_id,{display_name:'New Name',avatar_data_url:'https://test.local/media/current-dp'});
  const event=watcher.sent.findLast(event=>event.type==='profile_changed');
  assert.equal(event.user.display_name,'New Name');
  assert.equal(event.user.avatar_data_url,'https://test.local/media/current-dp');
  assert.equal('email' in event.user,false);
  assert.equal(other.sent.some(event=>event.type==='profile_changed'),false);
  await r.directory.webSocketMessage(watcher,JSON.stringify({type:'subscribe_profiles',user_ids:[]}));
  const count=watcher.sent.length;
  await r.directory.updateUserProfile(b.user_id,{display_name:'Another Name'});
  assert.equal(watcher.sent.length,count);
});
test('blocked and expired subscriptions receive no profile update',async t=>{
  const r=runtime();t.after(r.close);const a=await r.user(1),b=await r.user(2);
  const watcher=socket(a.user_id);
  r.directory.ctx.getWebSockets=()=>[watcher];
  await r.directory.webSocketMessage(watcher,JSON.stringify({type:'subscribe_profiles',user_ids:[b.user_id]}));
  r.directory.setBlocked(b.user_id,a.user_id,true);
  watcher.sent=[];
  await r.directory.updateUserProfile(b.user_id,{display_name:'Private blocked change'});
  assert.equal(watcher.sent.some(event=>event.type==='profile_changed'),false);
  r.directory.setBlocked(b.user_id,a.user_id,false);
  watcher.deserializeAttachment().expiresAt=Date.now()-1;
  await r.directory.updateUserProfile(b.user_id,{display_name:'Expired session change'});
  assert.equal(watcher.closed,true);
  assert.equal(watcher.sent.some(event=>event.type==='profile_changed'),false);
});
