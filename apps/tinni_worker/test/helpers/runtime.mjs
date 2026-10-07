import * as coldStorage from "../../src/cold_storage.js";
import { saveGameResults, lastGameResult, pendingGameResults, flushGameResults, fruitMultiplier, mainDirectory, recoverMainBets } from '../../src/game_results.js';
import { openGameSocket, handleGameMessage, notifyGameChanged } from '../../src/game_live.js';
import { countryDay } from '../../src/country_clock.js';
import { rocketPolicy, rocketAllocation, rocketDraw } from '../../src/rocket_rewards.js';
import { premiumGiftCatalog } from '../../src/premium_gift_catalog.js';
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
  return new Function('coldStorage', 'DurableObject', 'countryDay', 'premiumGiftCatalog', 'rocketPolicy', 'rocketAllocation', 'rocketDraw', 'openGameSocket', 'handleGameMessage', 'notifyGameChanged', 'saveGameResults', 'lastGameResult', 'pendingGameResults', 'flushGameResults', 'fruitMultiplier', 'mainDirectory', 'recoverMainBets', source(file) + '\nreturn ' + name)(coldStorage, DurableObject, countryDay, premiumGiftCatalog, rocketPolicy, rocketAllocation, rocketDraw, openGameSocket, handleGameMessage, notifyGameChanged, saveGameResults, lastGameResult, pendingGameResults, flushGameResults, fruitMultiplier, mainDirectory, recoverMainBets);
}
export function runtime({ legacyRoomSettings = false } = {}) {
  const databases = [];
  const objects = new Map();
  const mediaObjects=new Map(),archiveObjects=new Map();
  const metadata=(key,value)=>({key,size:value.bytes.byteLength,uploaded:new Date(value.updated_at),
    httpMetadata:value.options?.httpMetadata||{},customMetadata:value.options?.customMetadata||{},httpEtag:'"test-etag"'});
  function memoryBucket(mediaObjects) {return {
      async head(key) {const value=mediaObjects.get(key);return value?metadata(key,value):null;},
      async put(key,bytes,options={}) {
        const copied=new Uint8Array(bytes instanceof ArrayBuffer?bytes:bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength));
        mediaObjects.set(key,{bytes:copied,options,updated_at:Date.now()});
        return metadata(key,mediaObjects.get(key));
      },
      async get(key) {
        const value=mediaObjects.get(key);if(!value) return null;
        return {...metadata(key,value),body:new Blob([value.bytes]).stream(),
          arrayBuffer:async()=>value.bytes.slice().buffer,text:async()=>new TextDecoder().decode(value.bytes),
          writeHttpMetadata(headers){for(const [name,v] of Object.entries(value.options?.httpMetadata||{})) if(name==='contentType') headers.set('content-type',v);}
        };
      },
      async delete(keys) {for(const key of Array.isArray(keys)?keys:[keys]) mediaObjects.delete(key);},
      async list({cursor='',limit=1000}={}) {
        const keys=[...mediaObjects.keys()].sort().filter(key=>key>cursor),selected=keys.slice(0,limit);
        return {objects:selected.map(key=>metadata(key,mediaObjects.get(key))),truncated:keys.length>limit,cursor:selected.at(-1)};
      },
    };}
  const env = {SESSION_SECRET:"isolated-test-session-secret",EFFECT_MEDIA:memoryBucket(mediaObjects),USER_ARCHIVE:memoryBucket(archiveObjects)};

  const classes = {
    AppDirectoryStore: storeClass('app_directory.js', 'AppDirectoryStore'),
    RoomPresenceStore: storeClass('room_presence.js', 'RoomPresenceStore'),
    FruitGameStore: storeClass('fruit_game.js', 'FruitGameStore'),
    FruitPartyStore: storeClass('fruit_party.js', 'FruitPartyStore'),
  };
  function context(binding) {
    const db = new DatabaseSync(':memory:');
    databases.push(db);
    if (binding === 'ROOM_PRESENCE' && legacyRoomSettings) {
      db.exec(`CREATE TABLE room_runtime_settings(id INTEGER PRIMARY KEY,mic_mode TEXT NOT NULL DEFAULT 'apply',updated_at INTEGER NOT NULL);
        INSERT INTO room_runtime_settings(id,mic_mode,updated_at) VALUES(1,'free',17);`);
    }
    let alarm = null;
    return {
      storage: {
        transactionSync(fn) {
          db.exec('SAVEPOINT fixture_transaction');
          try {
            const value = fn();
            db.exec('RELEASE SAVEPOINT fixture_transaction');
            return value;
          } catch (error) {
            db.exec('ROLLBACK TO SAVEPOINT fixture_transaction');
            db.exec('RELEASE SAVEPOINT fixture_transaction');
            throw error;
          }
        },
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
        if (!objects.has(key)) objects.set(key, new classes[name](context(binding), env));
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
  const exports = new Function('coldStorage','DurableObject', ...Object.keys(classes),
    source('index.js').replace('export default', 'const worker =') +
    '\nreturn { worker, createSession, StaffAuthStore };')(coldStorage,DurableObject, ...Object.values(classes));
  const staff = new exports.StaffAuthStore(context('STAFF_AUTH'), env);
  env.STAFF_AUTH = {idFromName: value => value, get: () => new Proxy(staff,{
    get(object,property){const value=object[property];return typeof value==='function'?async (...args)=>value.apply(object,args):undefined;}
  })};
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
    }, env.SESSION_SECRET, 30 * 24 * 60 * 60 * 1000);
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
  return { env, directory, user, request, objects,mediaObjects,archiveObjects,
    fetch: request => exports.worker.fetch(request, env),
    ownerCookie: async () => {
      env.OWNER_EMAIL = 'owner@example.test';
      return 'tinni_owner_session=' + await exports.createSession({role:'owner',email:env.OWNER_EMAIL},env.SESSION_SECRET);
    },
    direct: (binding, id) => { env[binding].get(id); return objects.get(binding + ':' + id); },
    close: () => databases.forEach(db => db.close()) };
}
