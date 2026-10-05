import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';

test('Fruit Party Lucky settles three distinct fruits once despite a notice failure', async t => {
  const r=runtime(); t.after(r.close);
  const user=await r.user(1);
  const room=await r.directory.createRoom(user.user_id,{title:'Lucky room',seat_count:12});
  await r.request('/room-presence/join',user.token,{room_id:room.id});
  const oldNow=Date.now; let now=260000; Date.now=()=>now; t.after(()=>{Date.now=oldNow;});
  const party=r.direct('FRUIT_PARTY','global-party');
  party._setMeta('lucky_window_id','0');
  party._setMeta('lucky_rounds_json','[10]');
  const fruits=['lemon','raspberry','kiwi','plum','banana','strawberry','watermelon','cherry'];
  for (const key of fruits) await party.placeBet({user_id:user.user_id,room_id:room.id,fruit_key:key,amount:100000});
  const before=party._wallet(user.user_id).balance;
  r.directory.recordGameWinning=async()=>{throw new Error('Simulated notice failure');};
  now+=21001;
  await Promise.all([party._settle(10),party._settle(10)]);
  const state=await party.state(user.user_id);
  const result=state.history[0];
  assert.equal(result.special_kind,'lucky11');
  assert.equal(result.bonus_fruits.length,3);
  assert.equal(new Set(result.bonus_fruits.map(x=>x.key)).size,3);
  const expected=result.bonus_fruits.reduce((sum,x)=>sum+x.multiplier*100000,0);
  assert.equal(result.total_payout,expected);
  assert.equal(state.wallet_balance,before+expected);
  await party._settle(10);
  assert.equal(party._wallet(user.user_id).balance,before+expected);
  assert.equal(party.ownerStats(user.user_id).player.balance,before+expected);
  await assert.rejects(()=>party.placeBet({user_id:user.user_id,room_id:room.id,fruit_key:'lemon',amount:5000}),/locked/);
});

test('failed settlement insert rolls back winnings and succeeds on retry', async t => {
  const r=runtime(); t.after(r.close);
  const party=r.direct('FRUIT_PARTY','atomic-party');
  party._setMeta('lucky_window_id','0'); party._setMeta('lucky_rounds_json','[10]');
  party._ensureWallet('atomic-user');
  for(const key of ['lemon','raspberry','kiwi','plum','banana','strawberry','watermelon','cherry']) {
    party.ctx.storage.sql.exec('INSERT INTO party_bets(id,round_id,user_id,fruit_key,amount,room_id,created_at) VALUES(?,?,?,?,?,?,?)',
      key,10,'atomic-user',key,5000,'test-room',Date.now());
  }
  const before=party._wallet('atomic-user').balance;
  party.ctx.storage.sql.exec("CREATE TRIGGER fail_result BEFORE INSERT ON party_results BEGIN SELECT RAISE(ABORT,'result write failed'); END");
  await assert.rejects(()=>party._settle(10),/result write failed/);
  assert.equal(party._wallet('atomic-user').balance,before);
  assert.equal(party.ctx.storage.sql.exec('SELECT round_id FROM party_results').toArray().length,0);
  party.ctx.storage.sql.exec('DROP TRIGGER fail_result');
  await party._settle(10);
  const result=party.ctx.storage.sql.exec('SELECT total_payout FROM party_results').one();
  assert.equal(party._wallet('atomic-user').balance,before+Number(result.total_payout));
});

test('Ludo uses four real profiles, rejects wrong turns and releases/rejoins colours', async t => {
  const r=runtime(); t.after(r.close);
  const players=await Promise.all([1,2,3,4,5].map(index=>r.user(index)));
  const room=await r.directory.createRoom(players[0].user_id,{title:'Ludo room',seat_count:12});
  for(const player of players) await r.request('/room-presence/join',player.token,{room_id:room.id});
  for(let index=0;index<players.length;index++) {
    const response=await r.request('/ludo/state?room_id='+room.id,players[index].token);
    assert.equal(response.status,200,JSON.stringify(response.data));
    assert.equal(response.data.player_color,['red','green','yellow','blue',null][index]);
  }
  const state=(await r.request('/ludo/state?room_id='+room.id,players[0].token)).data;
  assert.equal(state.players.length,4);
  assert.equal(state.players[0].display_name,players[0].display_name);
  const wrong=await r.request('/ludo/roll',players[1].token,{room_id:room.id});
  assert.equal(wrong.status,400); assert.match(wrong.data.error,/not your turn/);
  const rolled=await r.request('/ludo/roll',players[0].token,{room_id:room.id});
  assert.equal(rolled.status,200,JSON.stringify(rolled.data));
  const left=await r.request('/ludo/leave',players[0].token,{room_id:room.id});
  assert.equal(left.status,200);
  const joined=await r.request('/ludo/state?room_id='+room.id,players[4].token);
  assert.equal(joined.data.player_color,'red');
  assert.equal(joined.data.players.length,4);
  const forbiddenReset=await r.request('/ludo/reset',players[1].token,{room_id:room.id});
  assert.equal(forbiddenReset.status,400); assert.match(forbiddenReset.data.error,/Only the room owner/);
});

test('locked empty room gets voice credentials and owner controls without public discovery',async t=>{
  const r=runtime(); t.after(r.close);
  r.env.LIVEKIT_URL='wss://voice.example.test';
  r.env.LIVEKIT_API_KEY='test-api-key';r.env.LIVEKIT_API_SECRET='test-api-secret';
  const owner=await r.user(1);
  const room=await r.directory.createRoom(owner.user_id,{title:'Locked',seat_count:12});
  r.directory.ctx.storage.sql.exec('UPDATE app_rooms SET locked=1 WHERE id=?',room.id);
  assert.ok(!(await r.directory.listRooms()).some(x=>x.id===room.id));
  const credentials=await r.request('/livekit/token',owner.token,{room_id:room.id});
  assert.equal(credentials.status,200,JSON.stringify(credentials.data));
  const claims=JSON.parse(Buffer.from(credentials.data.token.split('.')[1],'base64url'));
  assert.equal(claims.sub,owner.user_id);assert.equal(claims.video.room,room.id);
  assert.equal(claims.video.canPublish,true);assert.equal(claims.video.canSubscribe,true);
  const mode=await r.request('/room-presence/mic-mode',owner.token,{room_id:room.id,mic_mode:'free'});
  assert.equal(mode.status,200,JSON.stringify(mode.data));
  await r.request('/room-presence/join',owner.token,{room_id:room.id});
  const locked=await r.request('/room-presence/seat-lock',owner.token,{room_id:room.id,seat_index:0,locked:true});
  assert.equal(locked.status,200,JSON.stringify(locked.data));
  const unlocked=await r.request('/room-presence/seat-lock',owner.token,{room_id:room.id,seat_index:0,locked:false});
  assert.equal(unlocked.status,200);
});
