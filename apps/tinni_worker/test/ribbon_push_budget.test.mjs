import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';

function socket(countryCode) {
  return { received: [], deserializeAttachment: () => ({countryCode}),
    send(value) { this.received.push(JSON.parse(value)); } };
}

test('country ribbons push only to eligible countries, Rocket broadcasts globally once',async t=>{
  const r=runtime();t.after(r.close);
  const a=await r.user(91001),b=await r.user(91002);
  const d=r.directory,room=await d.createRoom(a.user_id,{title:'Push',seat_count:12});
  const india=socket('IN'),us=socket('US'),legacy=socket('');
  d.ctx.getWebSockets=()=>[india,us,legacy];
  d.recordGameWinning(a.user_id,room.id,'fruit-party',1000000);
  assert.equal(india.received.length,1);
  assert.equal(us.received.length,0);
  d._publishCountryRibbons();
  assert.equal(india.received.length,1);
  d.getWallet(a.user_id);
  d._creditNormalWalletAuthorized(a.user_id,8000000,'test_fixture');
  const sent=await r.request('/gifts/send',a.token,{request_id:crypto.randomUUID(),room_id:room.id,gift_id:'hot-biryani',
    quantity:160,receiver_ids:[b.user_id]});
  assert.equal(sent.status,201,JSON.stringify(sent.data));
  assert.equal(sent.data.room_summary.lifetime_total,8000000);
  assert.ok(JSON.stringify(sent.data.room_summary).length<200);
  const ribbon=us.received.find(x=>x.ribbon.kind==='rocket_launch').ribbon;
  assert.equal(ribbon.room_priority.room_id,room.id);
  assert.equal(ribbon.room_priority.level,1);
  assert.equal(ribbon.expires_at-ribbon.created_at,9000);
  assert.equal(legacy.received.filter(x=>x.ribbon.kind==='rocket_launch').length,1);
  d._publishCountryRibbons();
  assert.equal(us.received.length,1);
  const presence=r.direct('ROOM_PRESENCE',room.id);
  const events=[];
  presence.ctx.getWebSockets=()=>[{deserializeAttachment:()=>({userId:b.user_id}),
    send:raw=>events.push(JSON.parse(raw))}];
  presence.recordGift({receivers:[],event:{id:'push-gift',sender_id:a.user_id,
    gift_id:'hot-biryani',receiver_ids:[b.user_id],room_summary:sent.data.room_summary}});
  assert.equal(events.find(x=>x.type==='gift_sent').gift.room_summary.lifetime_total,8000000);
});

test('delivery failure cannot rollback a paid gift and live long-stay audience stays eligible',async t=>{
  const r=runtime();t.after(r.close);
  const a=await r.user(92001),b=await r.user(92002);
  const d=r.directory,room=await d.createRoom(a.user_id,{title:'Long stay',seat_count:12});
  d.getWallet(a.user_id);d._creditNormalWalletAuthorized(a.user_id,8000000,'test_fixture');
  await r.request('/room-presence/join',b.token,{room_id:room.id});
  d.ctx.storage.sql.exec('UPDATE app_user_presence SET last_seen=0,room_socket_connected=1 WHERE user_id=?',b.user_id);
  d.ctx.getWebSockets=()=>[{deserializeAttachment:()=>({countryCode:'IN'}),
    send:()=>{throw new Error('closed socket');}}];
  const sent=await r.request('/gifts/send',a.token,{request_id:crypto.randomUUID(),room_id:room.id,gift_id:'hot-biryani',
    quantity:160,receiver_ids:[b.user_id]});
  assert.equal(sent.status,201,JSON.stringify(sent.data));
  assert.equal(sent.data.wallet.coins,0);
  assert.equal(d.ctx.storage.sql.exec('SELECT COUNT(*) AS n FROM rocket_audience WHERE room_id=? AND user_id=?',
    room.id,b.user_id).toArray()[0].n,1);
  const before=d.ctx.storage.sql.exec('SELECT COUNT(*) AS n FROM gift_transactions WHERE room_id=?',room.id).toArray()[0].n;
  assert.throws(()=>d.sendGift(a.user_id,{room_id:room.id,gift_id:'hot-biryani',quantity:1,receiver_ids:[b.user_id]}),/coins/);
  assert.equal(d.ctx.storage.sql.exec('SELECT COUNT(*) AS n FROM gift_transactions WHERE room_id=?',room.id).toArray()[0].n,before);
});
