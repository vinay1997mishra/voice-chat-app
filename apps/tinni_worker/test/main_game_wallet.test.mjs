import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';

const fruits = ['lemon','raspberry','kiwi','plum','banana','strawberry','watermelon','cherry'];
async function setup(t,binding) {
  const r=runtime();t.after(r.close);
  const user=await r.user(1), other=await r.user(2);
  const room=await r.directory.createRoom(user.user_id,{title:'Main wallet',seat_count:12});
  const original=Date.now;let now=260000;Date.now=()=>now;t.after(()=>{Date.now=original;});
  r.directory._creditNormalWalletAuthorized(user.user_id,1000000);
  const game=r.direct(binding,'main-'+binding);
  const prefix=binding==='FRUIT_GAME'?'fruit':'party', key=binding==='FRUIT_GAME'?'fruit_jackpot':'fruit_party';
  return {r,user,other,room,game,prefix,key,advance(ms){now+=ms;}};
}
function peer(userId) {
  return {attachment:{userId},events:[],deserializeAttachment(){return this.attachment;},
    serializeAttachment(a){this.attachment=a;},send(raw){this.events.push(JSON.parse(raw));},close(){}};
}

for(const binding of ['FRUIT_GAME','FRUIT_PARTY']) {
  test(binding+' debits and wins in the main wallet after the game closes, with private reconnect receipt',async t=>{
    const s=await setup(t,binding),{r,user,other,room,game,key}=s;
    const first={user_id:user.user_id,room_id:room.id,fruit_key:'lemon',amount:5000,request_id:'main-wallet-request-0001'};
    await game.placeBet(first);
    await game.placeBet(first);
    assert.equal(r.directory.getWallet(user.user_id).coins,995000);
    for(const fruit of fruits.slice(1)) await game.placeBet({...first,fruit_key:fruit,request_id:'main-wallet-request-'+fruit});
    const before=r.directory.getWallet(user.user_id).coins;
    assert.equal(before,960000);
    assert.ok(await game.ctx.storage.getAlarm());
    // No game WebSocket is connected. Server alarms must still pay a funded round.
    s.advance(21001);await game.alarm();
    const result=(await game.state(user.user_id)).last_bet_result;
    assert.equal(result.outcome,'win');
    assert.equal(r.directory.getWallet(user.user_id).coins,before+result.winning_coins);
    const paid=r.directory.getWallet(user.user_id).coins;
    await game.alarm();await game.placeBet(first);
    assert.equal(r.directory.getWallet(user.user_id).coins,paid);
    assert.equal((await game.ownerStats(user.user_id)).player.balance,paid);
    const ledger=r.directory.ctx.storage.sql.exec("SELECT kind,coins_delta FROM wallet_transactions WHERE user_id=? AND kind IN ('game_bet','game_win')",user.user_id).toArray();
    assert.equal(ledger.filter(row=>row.kind==='game_bet').length,8);
    assert.equal(ledger.filter(row=>row.kind==='game_win').length,1);
    assert.equal(r.directory.mainGameWallet(user.user_id,key).today_winnings,result.winning_coins);
    const mine=peer(user.user_id), outsider=peer(other.user_id);
    await r.directory._sendAccountState(mine,mine.attachment);
    await r.directory._sendAccountState(outsider,outsider.attachment);
    assert.equal(mine.events.at(-1).game_results[0].id,result.id);
    assert.equal(mine.events.at(-1).game_results[0].wallet_type,'main');
    assert.equal(outsider.events.at(-1).game_results.length,0);
    await r.directory.webSocketMessage(outsider,JSON.stringify({type:'game_result_seen',game_key:key,round_id:10,user_id:user.user_id}));
    assert.equal(r.directory.pendingGameResults(user.user_id).length,1);
    await r.directory.webSocketMessage(mine,JSON.stringify({type:'game_result_seen',game_key:key,round_id:10}));
    assert.equal(r.directory.pendingGameResults(user.user_id).length,0);
  });

  test(binding+' recovers a funded bet when the local stake write fails',async t=>{
    const s=await setup(t,binding),{r,user,room,game,prefix}=s;
    game.ctx.storage.sql.exec("CREATE TRIGGER fail_bet BEFORE INSERT ON "+prefix+"_bets BEGIN SELECT RAISE(ABORT,'stake write failed'); END");
    await assert.rejects(()=>game.placeBet({
      user_id:user.user_id,room_id:room.id,fruit_key:'lemon',amount:5000,request_id:'crash-wallet-request-0001',
    }),/stake write failed/);
    assert.equal(r.directory.getWallet(user.user_id).coins,995000);
    assert.ok(await game.ctx.storage.getAlarm());
    game.ctx.storage.sql.exec('DROP TRIGGER fail_bet');
    s.advance(21001);await game.alarm();
    const result=(await game.state(user.user_id)).last_bet_result;
    assert.equal(result.bet_coins,5000);
    assert.equal(r.directory.getWallet(user.user_id).coins,995000+result.winning_coins);
    assert.equal(r.directory.pendingMainGameBets(s.key).length,0);
  });

  test(binding+' retains payout delivery after a lost response without double credit',async t=>{
    const s=await setup(t,binding),{r,user,room,game,prefix}=s;
    for(const fruit of fruits) await game.placeBet({
      user_id:user.user_id,room_id:room.id,fruit_key:fruit,amount:5000,request_id:'response-wallet-request-'+fruit,
    });
    const original=r.directory.recordGameResults.bind(r.directory);
    r.directory.recordGameResults=results=>{original(results);throw new Error('Simulated lost acknowledgment');};
    s.advance(21001);await game.alarm();
    const paid=r.directory.getWallet(user.user_id).coins;
    assert.ok(game.ctx.storage.sql.exec('SELECT * FROM '+prefix+'_result_outbox').toArray().length);
    assert.ok(await game.ctx.storage.getAlarm());
    r.directory.recordGameResults=original;
    s.advance(15000);await game.alarm();
    assert.equal(r.directory.getWallet(user.user_id).coins,paid);
    assert.equal(game.ctx.storage.sql.exec('SELECT * FROM '+prefix+'_result_outbox').toArray().length,0);
    const wins=r.directory.ctx.storage.sql.exec("SELECT id FROM wallet_transactions WHERE user_id=? AND kind='game_win'",user.user_id).toArray();
    assert.equal(wins.length,1);
    assert.equal(await game.ctx.storage.getAlarm(),null);
  });

  test(binding+' reports a loss without another debit when nobody watches',async t=>{
    const s=await setup(t,binding),{r,user,room,game}=s;
    await game.placeBet({user_id:user.user_id,room_id:room.id,fruit_key:'cherry',amount:5000,request_id:'losing-wallet-request-0001'});
    game._isLuckyRound=()=>false;
    const random=crypto.getRandomValues.bind(crypto);
    crypto.getRandomValues=array=>{array.fill(0);return array;};
    t.after(()=>{crypto.getRandomValues=random;});
    s.advance(21001);await game.alarm();
    const result=(await game.state(user.user_id)).last_bet_result;
    assert.equal(result.outcome,'lose');assert.equal(result.winning_coins,0);
    assert.equal(r.directory.getWallet(user.user_id).coins,995000);
    assert.equal(r.directory.pendingGameResults(user.user_id)[0].outcome,'lose');
    await game.alarm();assert.equal(r.directory.getWallet(user.user_id).coins,995000);
  });
}

test('a zero main wallet gets no free game coins and simultaneous games cannot overspend it',async t=>{
  const s=await setup(t,'FRUIT_GAME'),{r,user,other,room,game}=s;
  assert.equal((await game.state(other.user_id)).wallet_balance,0);
  await assert.rejects(()=>game.placeBet({
    user_id:other.user_id,room_id:room.id,fruit_key:'lemon',amount:5000,request_id:'empty-wallet-request-0001',
  }),/not enough/);
  r.directory._debitNormalWalletAuthorized(user.user_id,900000);
  const party=r.direct('FRUIT_PARTY','simultaneous');
  const outcomes=await Promise.allSettled([game,party].map((store,index)=>store.placeBet({
    user_id:user.user_id,room_id:room.id,fruit_key:'lemon',amount:100000,request_id:'parallel-wallet-request-'+index,
  })));
  assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);
  assert.equal(r.directory.getWallet(user.user_id).coins,0);
  assert.equal(r.directory.getWallet(user.user_id).security_frozen,false);
});

test('funded games follow an Owner-changed public ID without losing winnings',async t=>{
  const s=await setup(t,'FRUIT_PARTY'),{r,user,room,game}=s;
  for(const fruit of fruits) await game.placeBet({
    user_id:user.user_id,room_id:room.id,fruit_key:fruit,amount:5000,request_id:'changing-wallet-request-'+fruit,
  });
  const newId='98765';r.directory._changeUserId(user.user_id,newId);
  s.advance(21001);await game.alarm();
  const receipt=r.directory.pendingGameResults(newId)[0];
  assert.equal(receipt.user_id,newId);
  assert.equal(r.directory.getWallet(newId).coins,960000+receipt.winning_coins);
  assert.equal((await game.state(newId)).last_bet_result.id,receipt.id);
});

test('failed payouts survive newer rounds and settle all main-wallet credits after recovery',async t=>{
  const s=await setup(t,'FRUIT_PARTY'),{r,user,room,game}=s;
  const deliver=r.directory.recordGameResults.bind(r.directory);
  r.directory.recordGameResults=()=>{throw new Error('Temporary payout outage');};
  for(const fruit of fruits) await game.placeBet({
    user_id:user.user_id,room_id:room.id,fruit_key:fruit,amount:5000,request_id:'outage-first-request-'+fruit,
  });
  s.advance(21001);await game.alarm();s.advance(5000);
  for(const fruit of fruits) await game.placeBet({
    user_id:user.user_id,room_id:room.id,fruit_key:fruit,amount:5000,request_id:'outage-second-request-'+fruit,
  });
  s.advance(21001);await game.alarm();
  const rows=game.ctx.storage.sql.exec('SELECT payload FROM party_result_outbox').toArray();
  assert.equal(rows.length,2);
  const winnings=rows.reduce((sum,row)=>sum+JSON.parse(row.payload).winning_coins,0);
  r.directory.recordGameResults=deliver;s.advance(15000);await game.alarm();
  assert.equal(r.directory.getWallet(user.user_id).coins,920000+winnings);
  assert.equal(game.ctx.storage.sql.exec('SELECT payload FROM party_result_outbox').toArray().length,0);
});
test('Fruit Jackpot adds seven percent and opens eight hourly slots with 10-5-3 rewards',async t=>{
  const s=await setup(t,'FRUIT_GAME'),{r,user,room,game}=s;
  const second=await r.user(2), third=await r.user(3);
  r.directory._creditNormalWalletAuthorized(second.user_id,1000000);
  r.directory._creditNormalWalletAuthorized(third.user_id,1000000);
  await game.placeBet({user_id:user.user_id,room_id:room.id,fruit_key:'lemon',amount:100000,request_id:'jackpot-rank-one-0001'});
  await game.placeBet({user_id:second.user_id,room_id:room.id,fruit_key:'banana',amount:25000,request_id:'jackpot-rank-two-0002'});
  await game.placeBet({user_id:third.user_id,room_id:room.id,fruit_key:'cherry',amount:5000,request_id:'jackpot-rank-three-003'});
  let state=await game.state(user.user_id);
  assert.equal(state.jackpot,94863);
  assert.equal(state.jackpot_config.contribution_percent,7);
  assert.equal(state.jackpot_config.openings_per_hour,8);
  s.advance(190001);
  await game.alarm();
  state=await game.state(user.user_id);
  const event=state.jackpot_event;
  assert.ok(event,JSON.stringify(state));
  assert.equal(event.pool_before,94863);
  assert.deepEqual(event.winners.map(x=>x.percent),[10,5,3]);
  assert.deepEqual(event.winners.map(x=>x.user_id),[user.user_id,second.user_id,third.user_id]);
  assert.deepEqual(event.winners.map(x=>x.winning_coins),[9486,4743,2845]);
  assert.equal(event.pool_after,77789);
  const ledger=r.directory.ctx.storage.sql.exec("SELECT user_id,coins_delta FROM wallet_transactions WHERE kind='jackpot_win' ORDER BY coins_delta DESC").toArray();
  assert.deepEqual(ledger.map(x=>Number(x.coins_delta)),[9486,4743,2845]);
  await game.alarm();
  const ledgerAgain=r.directory.ctx.storage.sql.exec("SELECT id FROM wallet_transactions WHERE kind='jackpot_win'").toArray();
  assert.equal(ledgerAgain.length,3);
});
