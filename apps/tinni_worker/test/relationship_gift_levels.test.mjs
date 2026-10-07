import test from 'node:test';
import assert from 'node:assert/strict';
import { runtime } from './helpers/runtime.mjs';

test('CP and Enemy levels advance only from their own gift categories', async t => {
  const r = runtime();
  t.after(r.close);
  const a = await r.user(97001);
  const b = await r.user(97002);
  const d = r.directory;
  d._setOwnerSetting('cp_coin_thresholds', [6000000]);
  d._setOwnerSetting('vs_coin_thresholds', [6000000]);
  const room = await d.createRoom(a.user_id, {
    title: 'Relationship gifts',
    seat_count: 12,
  });
  const now = Date.now();

  d.ctx.storage.sql.exec(
    `INSERT INTO cp_relationships
      (user_a,user_b,state,intimacy,level,ring_id,requested_by,last_intimacy_at,
       decay_applied_days,cycle_started_at,created_at,updated_at)
     VALUES (?,?, 'accepted',0,1,NULL,?,?,0,?,?,?)`,
    a.user_id, b.user_id, a.user_id, now, now, now, now,
  );
  d.ctx.storage.sql.exec(
    `INSERT INTO enemy_relationships
      (user_a,user_b,state,rivalry,level,requested_by,last_rivalry_at,created_at,updated_at)
     VALUES (?,?, 'accepted',0,1,?,?,?,?)`,
    a.user_id, b.user_id, a.user_id, now, now, now,
  );

  d.getWallet(a.user_id);
  d._creditNormalWalletAuthorized(a.user_id, 30000000, 'test_fixture');

  d.sendGift(a.user_id, {
    room_id: room.id,
    gift_id: 'rose',
    quantity: 1,
    receiver_ids: [b.user_id],
  });
  assert.equal(d.cpState(a.user_id).intimacy, 0);
  assert.equal(d.enemyState(a.user_id).rivalry, 0);

  d.sendGift(a.user_id, {
    room_id: room.id,
    gift_id: 'cp-infinity-love',
    quantity: 2,
    receiver_ids: [b.user_id],
  });
  const cpAfter = d.cpState(a.user_id);
  assert.ok(cpAfter.intimacy >= 200000);
  assert.equal(cpAfter.level, 2);
  assert.equal(d.enemyState(a.user_id).rivalry, 0);

  assert.throws(
    () => d.cpUpdate(a.user_id, { action: 'intimacy', delta: 10000 }),
    /only be increased by CP gifts/,
  );

  const cpBeforeEnemyGift = d.cpState(a.user_id).intimacy;
  d.sendGift(a.user_id, {
    room_id: room.id,
    gift_id: 'enemy-abyss-king',
    quantity: 2,
    receiver_ids: [b.user_id],
  });
  const enemyAfter = d.enemyState(a.user_id);
  assert.ok(enemyAfter.rivalry >= 200000);
  assert.equal(enemyAfter.level, 2);
  assert.equal(d.cpState(a.user_id).intimacy, cpBeforeEnemyGift);
});

test('Enemy challenge requires acceptance and can be removed', async t => {
  const r = runtime();
  t.after(r.close);
  const a = await r.user(97101);
  const b = await r.user(97102);

  const requested = await r.request('/enemy/request', a.token, {
    target_user_id: b.user_id,
  });
  assert.equal(requested.status, 201, JSON.stringify(requested.data));
  assert.equal(requested.data.enemy.state, 'pending');

  const accepted = await r.request('/enemy/respond', b.token, {
    accept: true,
  });
  assert.equal(accepted.status, 200, JSON.stringify(accepted.data));
  assert.equal(accepted.data.enemy.state, 'accepted');

  const mine = await r.request('/enemy', a.token);
  assert.equal(mine.status, 200);
  assert.equal(mine.data.enemy.state, 'accepted');

  const unconfirmed = await r.request('/vs/disconnect', a.token, {});
  assert.equal(unconfirmed.status, 409);
  const relation = mine.data.enemy;
  const removed = await r.request('/vs/disconnect', a.token, {
    confirmed: true,
    expected_pair: relation.user_a + ':' + relation.user_b + ':' + relation.created_at,
  });
  assert.equal(removed.status, 200);
  assert.equal(removed.data.enemy, null);
});
