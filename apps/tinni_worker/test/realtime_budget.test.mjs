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
  party._ensureWallet('alice'); party._ensureWallet('bob');
  party.ctx.storage.sql.exec('UPDATE party_wallets SET balance=12345 WHERE user_id=?', 'alice');
  party.ctx.storage.sql.exec('UPDATE party_wallets SET balance=98765 WHERE user_id=?', 'bob');
  const a = socket({userId:'alice',gameKey:'fruit-party'});
  const b = socket({userId:'bob',gameKey:'fruit-party'});
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

for(const [binding,prefix] of [['FRUIT_GAME','fruit'],['FRUIT_PARTY','party']]) {
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
