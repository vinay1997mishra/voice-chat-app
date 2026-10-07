import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';

test('Lucky HUD includes rare results beyond 32 units and shares one room timeline', async t => {
  const r = runtime(); t.after(r.close);
  const sender = await r.user(871), receiver = await r.user(872);
  const room = await r.directory.createRoom(sender.user_id, { title: 'Lucky visuals', seat_count: 12 });
  r.directory.ctx.storage.sql.exec('UPDATE app_wallets SET coins=2000000 WHERE user_id=?', sender.user_id);
  const presence = r.direct('ROOM_PRESENCE', room.id);
  const broadcasts = [];
  presence._broadcastRoomEvent = event => broadcasts.push(event);
  let roll = 0;
  r.directory._pickLuckyMultiplier = () => {
    const index = roll++ % 99;
    return index === 98 ? 1000 : index === 1 ? 20 : 0;
  };
  const response = await r.request('/gifts/send', sender.token,{request_id:crypto.randomUUID(),
    room_id: room.id, gift_id: 'lucky-neon-butterfly', quantity: 99,
    unit_price: 1, receiver_ids: [receiver.user_id], lucky_session_id: 'lucky-visual-test',
  });
  assert.equal(response.status, 201, JSON.stringify(response.data));
  const { lucky, visual_event: event, wallet } = response.data;
  assert.deepEqual(lucky.multiplier_counts, [
    { multiplier: 0, count: 97 }, { multiplier: 20, count: 1 }, { multiplier: 1000, count: 1 },
  ]);
  assert.equal(lucky.rebate_coins, 510000);
  assert.equal(wallet.coins, 2000000 - 49500 + 510000);
  assert.equal(event.unit_price, 500);
  assert.equal(event.sent_coins, 49500);
  assert.deepEqual(event.multiplier_counts, lucky.multiplier_counts);
  assert.deepEqual(event.receiver_ids, [receiver.user_id]);
  assert.equal(event.visual_duration_ms, 4900);
  assert.equal(event.ultra_win, true);
  assert.deepEqual(broadcasts.find(row => row.type === 'gift_sent').gift, event);
  assert.equal(event.visual_started_at >= event.server_time + 450, true);

  const next = await r.request('/gifts/send', sender.token,{request_id:crypto.randomUUID(),
    room_id: room.id, gift_id: 'lucky-neon-butterfly', quantity: 9,
    receiver_ids: [receiver.user_id], lucky_session_id: 'lucky-visual-test',
  });
  assert.equal(next.status, 201, JSON.stringify(next.data));
  assert.equal(next.data.visual_event.visual_started_at >= event.visual_started_at + event.visual_duration_ms, true);
  const active = presence.activeLuckyVisuals();
  assert.deepEqual(active.map(row => row.id), [event.id, next.data.visual_event.id]);
  assert.equal(new Set(active.map(row => row.id)).size, 2);
});

test('all 7999 independent units are retained compactly, including zero and configured maximum', t => {
  const r = runtime(); t.after(r.close);
  const config = { max_multiplier: 1000, multiplier_weights: { '750': 1 } };
  const result = r.directory._rollLuckyBatch(7999, config);
  assert.deepEqual(result.multiplier_counts, [{ multiplier: 750, count: 7999 }]);
  assert.equal(result.multiplier_sum, 750 * 7999);
  assert.equal(result.recent_multipliers.length, 32);
  const capped = r.directory._rollLuckyBatch(99, { max_multiplier: 50, multiplier_weights: { '1000': 1 } });
  assert.deepEqual(capped.multiplier_counts, [{ multiplier: 50, count: 99 }]);
  const zeros = r.directory._rollLuckyBatch(99, { max_multiplier: 1000, multiplier_weights: { '0': 1 } });
  assert.deepEqual(zeros.multiplier_counts, [{ multiplier: 0, count: 99 }]);
  assert.equal(zeros.multiplier_sum, 0);
});

test('Owner Lucky disable and banner controls remain authoritative', async t => {
  const r = runtime(); t.after(r.close);
  const sender = await r.user(873), receiver = await r.user(874);
  const room = await r.directory.createRoom(sender.user_id, { title: 'Lucky controls', seat_count: 12 });
  r.directory.ctx.storage.sql.exec('UPDATE app_wallets SET coins=1000000 WHERE user_id=?', sender.user_id);
  r.directory._setOwnerSetting('lucky_gift_config', {
    enabled: true, banners_enabled: false, max_multiplier: 1000, multiplier_weights: { '1000': 1 },
  });
  const data = { request_id:'lucky_controls_win', room_id: room.id, gift_id: 'lucky-neon-butterfly', quantity: 1, receiver_ids: [receiver.user_id] };
  const win = await r.request('/gifts/send', sender.token, data);
  assert.equal(win.status, 201, JSON.stringify(win.data));
  assert.equal(win.data.lucky.rebate_coins, 500000);
  assert.equal(win.data.visual_event.banners_enabled, false);
  r.directory._setOwnerSetting('lucky_gift_config', { enabled: false });
  const balance = r.directory.getWallet(sender.user_id).coins;
  const off = await r.request('/gifts/send', sender.token, {...data,request_id:'lucky_controls_off'});
  assert.equal(off.status, 400);
  assert.equal(r.directory.getWallet(sender.user_id).coins, balance);
});
