import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { webcrypto } from 'node:crypto';
globalThis.crypto ??= webcrypto;

class DurableObject {
  constructor(ctx, env) { this.ctx = ctx; this.env = env; }
}
function source(file) {
  return readFileSync(new URL('../../src/' + file, import.meta.url), 'utf8')
    .replace(/^import .*;\r?\n/gm, '')
    .replace(/^export \{.*\};\r?\n/gm, '')
    .replace(/export (?=(?:async )?(?:class|function|const|let) )/g, '');
}
function storeClass(file, name) {
  return new Function('DurableObject', source(file) + '\nreturn ' + name)(DurableObject);
}
export function runtime() {
  const databases = [];
  const objects = new Map();
  const env = { SESSION_SECRET: 'isolated-test-session-secret',
    EFFECT_MEDIA: { head: async () => null } };
  const classes = {
    AppDirectoryStore: storeClass('app_directory.js', 'AppDirectoryStore'),
    RoomPresenceStore: storeClass('room_presence.js', 'RoomPresenceStore'),
    FruitGameStore: storeClass('fruit_game.js', 'FruitGameStore'),
    FruitPartyStore: storeClass('fruit_party.js', 'FruitPartyStore'),
  };
  function context() {
    const db = new DatabaseSync(':memory:');
    databases.push(db);
    let alarm = null;
    return {
      storage: {
        sql: {
          exec(query, ...bindings) {
            let rows = [];
            if (!bindings.length && query.trim().split(';').filter(x => x.trim()).length > 1) {
              db.exec(query);
            } else {
              const statement = db.prepare(query);
              const params = bindings.map(x => typeof x === 'boolean' ? Number(x) : x ?? null);
              if (statement.columns().length) rows = statement.all(...params);
              else statement.run(...params);
            }
            return { toArray: () => rows, one: () => {
              if (rows.length !== 1) throw new Error('Expected one row');
              return rows[0];
            }, [Symbol.iterator]: () => rows[Symbol.iterator]() };
          },
        },
        getAlarm: async () => alarm,
        setAlarm: async value => { alarm = value; },
        deleteAlarm: async () => { alarm = null; },
      },
      getWebSockets: () => [],
      acceptWebSocket: () => {},
      blockConcurrencyWhile: async fn => fn(),
    };
  }
  for (const [binding, name] of Object.entries({
    APP_DIRECTORY: 'AppDirectoryStore', ROOM_PRESENCE: 'RoomPresenceStore',
    FRUIT_GAME: 'FruitGameStore', FRUIT_PARTY: 'FruitPartyStore',
  })) {
    env[binding] = {
      idFromName: value => value,
      get(id) {
        const key = binding + ':' + id;
        if (!objects.has(key)) objects.set(key, new classes[name](context(), env));
        const target = objects.get(key);
        return new Proxy(target, {
          get(object, property) {
            const value = object[property];
            if (typeof value !== 'function') return undefined;
            return async (...args) => value.apply(object, args);
          },
        });
      },
    };
  }
  const exports = new Function('DurableObject', ...Object.keys(classes),
    source('index.js').replace('export default', 'const worker =') +
    '\nreturn { worker, createSession };')(DurableObject, ...Object.values(classes));
  env.APP_DIRECTORY.get('tinni-app-directory');
  const directory = objects.get('APP_DIRECTORY:tinni-app-directory');
  async function user(index) {
    const subject = 'test-subject-' + index;
    const account = await directory.createUser({
      auth_provider: 'google', auth_subject: subject,
      email: 'test-' + index + '@example.test', display_name: 'Test ' + index,
      age: 25, signature: '', country_code: 'IN', country_name: 'India',
      flag_emoji: '🇮🇳', gender: 'male', language: 'English',
    });
    const token = await exports.createSession({
      role: 'user', userId: account.user_id, provider: 'google', subject,
    }, env.SESSION_SECRET);
    return { ...account, token };
  }
  async function request(path, token, body, method = body === undefined ? 'GET' : 'POST') {
    const response = await exports.worker.fetch(new Request('https://test.local' + path, {
      method, headers: { ...(token ? { authorization: 'Bearer ' + token } : {}),
        'content-type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    }), env);
    const text = await response.text();
    let data;
    try { data = JSON.parse(text); } catch { data = { text }; }
    return { status: response.status, data };
  }
  return { env, directory, user, request, objects,
    direct: (binding, id) => { env[binding].get(id); return objects.get(binding + ':' + id); },
    close: () => databases.forEach(db => db.close()) };
}
