import assert from 'node:assert/strict';
import test from 'node:test';
import { runtime } from './helpers/runtime.mjs';

test('authenticated app entry, core catalogs and social/profile reads use real SQLite stores', async t => {
  const r = runtime(); t.after(r.close);
  const a = await r.user(1);
  const room = await r.directory.createRoom(a.user_id, { title: 'Test room', seat_count: 12 });
  const paths = ['/app/me', '/wallet', '/account/preferences', '/profile-media',
    '/profile/trends', '/notifications', '/cp', '/cp/ranking', '/families',
    '/store/catalog', '/store/inventory', '/vip/catalog', '/unique-id/catalog',
    '/gifts/lucky/state', '/rooms', '/rooms/themes',
    '/rooms/follow?room_id=' + room.id, '/rooms/membership?room_id=' + room.id];
  for (const path of paths) {
    const result = await r.request(path, a.token);
    assert.equal(result.status, 200, path + ': ' + JSON.stringify(result.data));
  }
  const unauthorized = await r.request('/wallet');
  assert.equal(unauthorized.status, 401);
});

test('seat acquisition retries preserve the same seat and microphone state', async t => {
  const r = runtime(); t.after(r.close);
  const a = await r.user(1);
  const presence = r.env.ROOM_PRESENCE.get('seat-test');
  await presence.join({ user_id: a.user_id, room_id: 'seat-test', display_name: a.display_name });
  const first = await presence.takeSeat({ user_id: a.user_id, seat_index: 1, privileged: true });
  assert.equal(first.seat_index, 1);
  presence.ctx.storage.sql.exec('UPDATE room_members SET mic_enabled = 1 WHERE user_id = ?', a.user_id);
  const retry = await presence.takeSeat({ user_id: a.user_id, seat_index: 1, privileged: true });
  assert.equal(retry.seat_index, 1);
  const row = presence.ctx.storage.sql.exec('SELECT seat_index, mic_enabled FROM room_members WHERE user_id = ?', a.user_id).one();
  assert.equal(row.mic_enabled, 1);
  assert.throws(() => presence.takeSeat({ user_id: a.user_id, seat_index: 2, privileged: true }), /Leave your current seat/);
});

test('a committed gift stays successful when room visual delivery fails', async t => {
  const r = runtime(); t.after(r.close);
  const a = await r.user(1), b = await r.user(2);
  const room = await r.directory.createRoom(a.user_id, { title: 'Gift room', seat_count: 12 });
  r.directory.ctx.storage.sql.exec('UPDATE app_wallets SET coins = 10000 WHERE user_id = ?', a.user_id);
  const getPresence = r.env.ROOM_PRESENCE.get.bind(r.env.ROOM_PRESENCE);
  r.env.ROOM_PRESENCE.get = id => {
    const presence = getPresence(id);
    presence.recordGift = () => { throw new Error('Simulated broadcast failure'); };
    return presence;
  };
  const sent = await r.request('/gifts/send', a.token, {
    room_id: room.id, gift_id: 'rose', gift_name: 'Rose', quantity: 1,
    unit_price: 100, receiver_ids: [b.user_id],
  });
  assert.equal(sent.status, 201, JSON.stringify(sent.data));
  assert.equal(sent.data.wallet.coins, 9900);
  assert.equal(sent.data.transactions.length, 1);
  const wallet = await r.request('/wallet', a.token);
  assert.equal(wallet.data.wallet.coins, 9900);
});
