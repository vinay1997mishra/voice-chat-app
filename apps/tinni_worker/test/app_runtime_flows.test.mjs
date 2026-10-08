import assert from 'node:assert/strict';
import test from 'node:test';
import { runtime } from './helpers/runtime.mjs';

test('authenticated app entry, core catalogs and social/profile reads use real SQLite stores', async t => {
  const r = runtime(); t.after(r.close);
  const a = await r.user(1);
  const room = await r.directory.createRoom(a.user_id, { title: 'Test room', seat_count: 12 });
  const paths = ['/app/me', '/wallet', '/account/preferences', '/profile-media',
    '/profile/trends', '/notifications', '/account/stats', '/tasks', '/account/identities', '/feedback',
    '/social/following', '/social/friends', '/social/blocked', '/social/blocked/details',
    '/messages/inbox', '/calls/incoming',
    '/wallet/coins/history', '/wallet/diamonds/history', 
    '/hierarchy/invites', '/vip/me', '/frames/catalog', '/cp', '/cp/ranking', '/family/list',
    '/store/catalog', '/inventory', '/vip/catalog', '/unique-ids/catalog',
    '/gifts/lucky/state', '/rooms', '/room-themes?room_id=' + room.id,
    '/rooms/follow?room_id=' + room.id, '/rooms/membership?room_id=' + room.id];
  for (const path of paths) {
    await t.test(path, async () => {
      const result = await r.request(path, a.token);
      assert.equal(result.status, 200, path + ': ' + JSON.stringify(result.data));
      if (path === '/store/catalog') assert.ok(Array.isArray(result.data.items));
      if (path === '/unique-ids/catalog') assert.ok(Array.isArray(result.data.unique_ids));
    });
  }
  const unauthorized = await r.request('/wallet');
  assert.equal(unauthorized.status, 401);
});

test('seat acquisition retries preserve the same seat and microphone state', async t => {
  const r = runtime(); t.after(r.close);
  const a = await r.user(1);
  const presence = r.direct('ROOM_PRESENCE', 'seat-test');
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
    r.objects.get('ROOM_PRESENCE:' + id).recordGift = () => { throw new Error('Simulated broadcast failure'); };
    return presence;
  };
  const sent = await r.request('/gifts/send', a.token, {
    request_id:'visual_failure_0001',
    room_id: room.id, gift_id: 'rose', gift_name: 'Rose', quantity: 1,
    unit_price: 100, receiver_ids: [b.user_id],
  });
  assert.equal(sent.status, 201, JSON.stringify(sent.data));
  assert.equal(sent.data.wallet.coins, 9900);
  assert.equal(sent.data.transactions.length, 1);
  const wallet = await r.request('/wallet', a.token);
  assert.equal(wallet.data.wallet.coins, 9900);
});

test('profile preferences, room following and direct messages persist through real routes', async t => {
  const r = runtime(); t.after(r.close);
  const a = await r.user(1), b = await r.user(2);
  const room = await r.directory.createRoom(a.user_id, { title: 'Action room', seat_count: 12 });
  const preferences = await r.request('/account/preferences', a.token, { language: 'Hindi' });
  assert.equal(preferences.status, 200, JSON.stringify(preferences.data));
  const reread = await r.request('/account/preferences', a.token);
  assert.equal(reread.data.preferences.language, 'Hindi');
  const followed = await r.request('/rooms/follow', b.token, { room_id: room.id, following: true });
  assert.equal(followed.status, 200, JSON.stringify(followed.data));
  const social = await r.request('/social/follow', a.token, { target_user_id: b.user_id, following: true });
  assert.equal(social.status, 200, JSON.stringify(social.data));
  const reciprocal = await r.request('/social/follow', b.token, { target_user_id: a.user_id, following: true });
  assert.equal(reciprocal.status, 200, JSON.stringify(reciprocal.data));
  const message = await r.request('/messages', a.token, { to_user_id: b.user_id, text: 'Hello from the flow test' });
  assert.equal(message.status, 201, JSON.stringify(message.data));
  const inbox = await r.request('/messages?peer_user_id=' + a.user_id, b.token);
  assert.equal(inbox.status, 200, JSON.stringify(inbox.data));
  assert.ok(inbox.data.messages.some(item => item.text === 'Hello from the flow test'));
});

test('store purchases return real inventory and do not charge twice for an owned item', async t => {
  const r = runtime(); t.after(r.close);
  const a = await r.user(1);
  const sql = r.directory.ctx.storage.sql;
  sql.exec('UPDATE app_wallets SET coins = 10000 WHERE user_id = ?', a.user_id);
  const now = Date.now();
  sql.exec('INSERT INTO owner_catalog (id,kind,name,data_json,enabled,created_at,updated_at) VALUES (?,?,?,?,1,?,?)',
    'test-entry', 'entry', 'Test Entry', JSON.stringify({ coin_price: 100 }), now, now);
  const catalog = await r.request('/store/catalog?kind=entry', a.token);
  assert.ok(catalog.data.items.some(item => item.id === 'test-entry'));
  const first = await r.request('/store/purchase', a.token, { kind: 'entry', item_id: 'test-entry' });
  assert.equal(first.status, 200, JSON.stringify(first.data));
  assert.equal(first.data.wallet.coins, 9900);
  const retry = await r.request('/store/purchase', a.token, { kind: 'entry', item_id: 'test-entry' });
  assert.equal(retry.status, 200, JSON.stringify(retry.data));
  assert.equal(retry.data.wallet.coins, 9900);
  assert.equal(retry.data.duplicate, true);
});

test('Unique ID purchase keeps the current login usable and preserves the owned room', async t => {
  const r = runtime(); t.after(r.close);
  const a = await r.user(1);
  const room = await r.directory.createRoom(a.user_id, { title: 'Identity room', seat_count: 12 });
  const sql = r.directory.ctx.storage.sql, now = Date.now();
  sql.exec('UPDATE app_wallets SET coins = 10000 WHERE user_id = ?', a.user_id);
  sql.exec('INSERT INTO owner_unique_ids (public_id,price_coins,enabled,created_at,updated_at) VALUES (?,100,1,?,?)',
    '8888', now, now);
  const purchase = await r.request('/unique-ids/purchase', a.token, { public_id: '8888' });
  assert.equal(purchase.status, 200, JSON.stringify(purchase.data));
  assert.equal(purchase.data.user.user_id, '8888');
  assert.equal(purchase.data.wallet.coins, 9900);
  const me = await r.request('/app/me', a.token);
  assert.equal(me.status, 200, JSON.stringify(me.data));
  assert.equal(me.data.user.user_id, '8888');
  const owned = await r.directory.findRoomByExactId(room.id);
  assert.equal(owned.id, room.id);
  assert.equal(owned.owner_id, '8888');
});
