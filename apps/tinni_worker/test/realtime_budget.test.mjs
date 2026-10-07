import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';
import { handleGameMessage, notifyGameChanged } from '../src/game_live.js';

function socket(attachment) {
  return { attachment, events: [], closed: false,
    deserializeAttachment() { return this.attachment; },
    serializeAttachment(value) { this.attachment = value; },
    send(raw) { this.events.push(JSON.parse(raw)); },
    close() { this.closed = true; },
  };
}

test('game snapshots use the socket identity and invalidations reveal no private wallet', async t => {
  const r = runtime(); t.after(r.close);
  const party = r.direct('FRUIT_PARTY', 'private-party');
  const alice = await r.user(1), bob = await r.user(2);
  r.directory._creditNormalWalletAuthorized(alice.user_id,12345);
  r.directory._creditNormalWalletAuthorized(bob.user_id,98765);
  const a = socket({userId:alice.user_id,gameKey:'fruit-party'});
  const b = socket({userId:bob.user_id,gameKey:'fruit-party'});
  await handleGameMessage(party,a,JSON.stringify({type:'state',user_id:'bob'}));
  await handleGameMessage(party,b,JSON.stringify({type:'state',user_id:'alice'}));
  assert.equal(a.events.at(-1).state.wallet_balance,12345);
  assert.equal(b.events.at(-1).state.wallet_balance,98765);
  party.ctx.getWebSockets = tag => tag === 'game:fruit-party' ? [a,b] : [];
  notifyGameChanged(party,'fruit-party');
  assert.deepEqual(a.events.at(-1),{type:'game_changed',game_key:'fruit-party',room_id:''});
  const exp = socket({userId:'alice',gameKey:'fruit-party',expiresAt:1});
  await handleGameMessage(party,exp,'{"type":"state"}');
  assert.equal(exp.closed,true); assert.equal(exp.events.length,0);
});

test('Ludo invalidations stay in the room where a move happened', () => {
  const a=socket({userId:'a'}), b=socket({userId:'b'});
  const store={ctx:{getWebSockets:tag=>tag==='game:ludo:room-a'?[a]:[b]}};
  notifyGameChanged(store,'ludo','room-a');
  assert.equal(a.events.length,1); assert.equal(b.events.length,0);
});

test('wallet changes push a private invalidation and read final state over the same socket',async t=>{
  const r=runtime();t.after(r.close);
  const a=await r.user(1), b=await r.user(2);
  const sa=socket({userId:a.user_id}), sb=socket({userId:b.user_id});
  r.directory.ctx.getWebSockets=tag=>tag==='message-user:'+a.user_id?[sa]:tag==='message-user:'+b.user_id?[sb]:[sa,sb];
  r.directory._creditNormalWalletAuthorized(a.user_id,12345);
  assert.equal(sb.events.length,0);
  assert.deepEqual(sa.events.at(-1),{type:'account_changed'});
  await r.directory.webSocketMessage(sa,JSON.stringify({type:'account_state',user_id:b.user_id}));
  assert.equal(sa.events.at(-1).user.user_id,a.user_id);
  assert.equal(sa.events.at(-1).wallet.coins,12345);
});

test('revocation reads filter expiration without issuing cleanup writes', t=>{
  const r=runtime();t.after(r.close);
  r.directory.revokeSession('live',Date.now()+10000);
  r.directory.revokeSession('expired',Date.now()-1);
  const exec=r.directory.ctx.storage.sql.exec;
  const writes=[];
  r.directory.ctx.storage.sql.exec=(query,...args)=>{
    if (/^(DELETE|INSERT|UPDATE)/i.test(query.trim())) writes.push(query);
    return exec(query,...args);
  };
  assert.equal(r.directory.isSessionRevoked('live'),true);
  assert.equal(r.directory.isSessionRevoked('expired'),false);
  assert.equal(writes.length,0);
});

for(const [binding,prefix] of [['FRUIT_PARTY','party']]) {
  test(binding+' stops idle alarms but settles overdue bets without filling idle history',async t=>{
    const r=runtime();t.after(r.close);
    const game=r.direct(binding,'idle-test');
    const oldNow=Date.now;let now=260000;Date.now=()=>now;t.after(()=>{Date.now=oldNow;});
    await game.state('a');
    assert.equal(await game.ctx.storage.getAlarm(),null);
    game._ensureWallet('a');
    for(const fruit of ['lemon','cherry','kiwi','strawberry','watermelon','banana','raspberry','plum']) {
      game.ctx.storage.sql.exec('INSERT INTO '+prefix+'_bets(id,round_id,user_id,fruit_key,amount,created_at) VALUES(?,?,?,?,?,?)',
        fruit,10,'a',fruit,5000,now);
    }
    await game.state('a');
    assert.ok(await game.ctx.storage.getAlarm());
    const before=game._wallet('a').balance;
    now+=26000*10000;
    await game.alarm();
    const paid=game.ctx.storage.sql.exec('SELECT total_payout FROM '+prefix+'_results WHERE round_id=10').one();
    assert.equal(game._wallet('a').balance,before+Number(paid.total_payout));
    assert.ok(game.ctx.storage.sql.exec('SELECT round_id FROM '+prefix+'_results').toArray().length<=8);
    assert.equal(await game.ctx.storage.getAlarm(),null);
    await game.state('a');
    assert.equal(game._wallet('a').balance,before+Number(paid.total_payout));
  });
}

test('room DP and member DP push without changing seats or exposing locked rooms in discovery',async t=>{
  const r=runtime();t.after(r.close);
  const owner=await r.user(1), guest=await r.user(2);
  const room=await r.directory.createRoom(owner.user_id,{title:'Before',seat_count:12});
  await r.request('/room-presence/join',guest.token,{room_id:room.id});
  const presence=r.direct('ROOM_PRESENCE',room.id);
  const participant=socket({userId:guest.user_id});
  presence.ctx.getWebSockets=()=>[participant];
  const browser=socket({userId:owner.user_id,roomsSubscribed:true});
  r.directory.ctx.getWebSockets=()=>[browser];
  await r.directory.updateRoom(owner.user_id,room.id,{
    title:'After',photo_data_url:'https://media.example.test/room.jpg',
  });
  assert.equal(browser.events.at(-1).room.photo_data_url,'https://media.example.test/room.jpg');
  assert.equal(participant.events.at(-1).type,'room_details');
  assert.equal(participant.events.at(-1).room.title,'After');
  await r.directory.updateRoom(owner.user_id,room.id,{closed:true});
  assert.equal(browser.events.at(-1).room,null);
  await r.directory.updateUserProfile(guest.user_id,{avatar_data_url:'https://media.example.test/avatar.jpg'});
  const updated=participant.events.findLast(x=>x.type==='member_updated');
  assert.equal(updated.members.find(x=>x.user_id===guest.user_id).avatar_data_url,'https://media.example.test/avatar.jpg');
  assert.equal(updated.members.find(x=>x.user_id===guest.user_id).seat_index,null);
});

test('role dollar balances push privately through the same account snapshot',async t=>{
  const r=runtime();t.after(r.close);const user=await r.user(1);
  r.directory.ctx.storage.sql.exec("INSERT INTO owner_wallets(user_id,wallet_type,balance,banned,updated_at) VALUES(?,'merchant',0,0,?)",user.user_id,Date.now());
  const client=socket({userId:user.user_id});
  r.directory.ctx.getWebSockets=()=>[client];
  r.directory._creditRoleDollars(user.user_id,'merchant',12345);
  assert.equal(client.events.at(-1).type,'account_changed');
  await r.directory._sendAccountState(client,client.attachment);
  assert.equal(client.events.at(-1).wallet.merchant_wallet.usd_cents,12345);
});

for(const [binding,prefix] of [['FRUIT_PARTY','party']]) {
  test(binding+' bounds empty history while retaining financial results',async t=>{
    const r=runtime();t.after(r.close);const game=r.direct(binding,'history-budget');
    for(let round=1;round<=80;round++) {
      if(round===1) game.ctx.storage.sql.exec(
        'INSERT INTO '+prefix+'_bets(id,round_id,user_id,fruit_key,amount,room_id,created_at) VALUES(?,?,?,?,?,?,?)',
        'financial-bet',round,'a','lemon',5000,'room',Date.now(),
      );
      await game._settle(round);
    }
    const empty=game.ctx.storage.sql.exec('SELECT round_id FROM '+prefix+'_results WHERE total_bet=0').toArray();
    assert.ok(empty.length<=20);
    assert.equal(game.ctx.storage.sql.exec('SELECT round_id FROM '+prefix+'_results WHERE round_id=1 AND total_bet=5000').toArray().length,1);
    assert.equal(game.ctx.storage.sql.exec('SELECT id FROM '+prefix+'_bets WHERE id=?','financial-bet').toArray().length,1);
    const count=game.ctx.storage.sql.exec('SELECT COUNT(*) AS n FROM '+prefix+'_results').one().n;
    await game._settle(80);
    assert.equal(game.ctx.storage.sql.exec('SELECT COUNT(*) AS n FROM '+prefix+'_results').one().n,count);
  });
}
