import test from 'node:test';
import assert from 'node:assert/strict';
import {runtime} from './helpers/runtime.mjs';
import {CHAT_PHOTO_MS} from '../src/cold_storage.js';

test('public media aliases cannot bypass private photo participant checks or expiry', async t => {
  const r = runtime();
  t.after(r.close);
  const sender = await r.user(1), recipient = await r.user(2), outsider = await r.user(3);
  const messageId = 'private-route-photo';
  r.directory.ctx.storage.sql.exec(
    "INSERT INTO direct_messages(id,from_user_id,to_user_id,text,message_kind,media_url,created_at) VALUES(?,?,?,'Photo','image',?,?)",
    messageId, sender.user_id, recipient.user_id,
    'https://test.local/message-media/' + messageId, Date.now(),
  );
  await r.env.EFFECT_MEDIA.put('messages/' + messageId, new Uint8Array([1, 2, 3]),
    {httpMetadata: {contentType: 'image/png'}});

  for (const path of [
    '/media/messages/' + messageId,
    '/media/' + encodeURIComponent('messages/' + messageId),
  ]) {
    assert.equal((await r.request(path)).status, 404);
    assert.equal((await r.request(path, recipient.token)).status, 404);
  }
  const privatePath = '/message-media/' + messageId;
  assert.equal((await r.request(privatePath)).status, 401);
  assert.equal((await r.request(privatePath, outsider.token)).status, 403);
  assert.equal((await r.request(privatePath, sender.token)).status, 200);
  assert.equal((await r.request(privatePath, recipient.token)).status, 200);

  r.directory.ctx.storage.sql.exec(
    'UPDATE direct_messages SET created_at=? WHERE id=?',
    Date.now() - CHAT_PHOTO_MS - 1000, messageId,
  );
  assert.equal((await r.request(privatePath, recipient.token)).status, 403);
  assert.equal((await r.request('/media/messages/' + messageId)).status, 404);

  const avatarKey = 'profiles/' + sender.user_id + '/avatar';
  await r.env.EFFECT_MEDIA.put(avatarKey, new Uint8Array([4, 5, 6]),
    {httpMetadata: {contentType: 'image/png'}});
  assert.equal((await r.request('/media/' + avatarKey)).status, 200);
});
