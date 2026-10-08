import assert from 'node:assert/strict';
import test from 'node:test';
import { runtime } from './helpers/runtime.mjs';

test('current and previous user/room IDs resolve through search routes', async t => {
  const r = runtime();
  t.after(r.close);

  const account = await r.user(1);
  const originalId = account.user_id;
  await r.directory.createRoom(originalId, {
    title: 'Searchable room',
    seat_count: 12,
  });

  const firstId = '87654321';
  const currentId = '87654322';
  r.directory._changeUserId(originalId, firstId);
  r.directory._changeUserId(firstId, currentId);

  for (const id of [originalId, firstId, currentId]) {
    const room = await r.request(
      '/rooms/search?id=' + encodeURIComponent(id),
      account.token,
    );
    assert.equal(room.status, 200, id + ': ' + JSON.stringify(room.data));
    assert.equal(room.data.room.public_id, currentId);

    const user = await r.request(
      '/users/exact-id?id=' + encodeURIComponent(id),
      account.token,
    );
    assert.equal(user.status, 200, id + ': ' + JSON.stringify(user.data));
    assert.equal(user.data.user.user_id, currentId);
  }
});
