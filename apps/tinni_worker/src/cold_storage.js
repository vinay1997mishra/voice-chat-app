// Private cold storage. R2 capacity is a conservative bucket budget, not an account billing promise.
export const DAY_MS = 86400000;
export const GAME_HISTORY_MS = 15 * DAY_MS;
export const CHAT_PHOTO_MS = 10 * DAY_MS;
export const CHAT_SERVER_MESSAGES = 500;
export const PRIVATE_PREFIX = "private-cold/";
export const R2_BYTE_LIMIT = 7_000_000_000;
const BATCH_ROWS = 256;
const encoder = new TextEncoder();
const rows = (store, query, ...args) => store.ctx.storage.sql.exec(query, ...args).toArray();
const one = (store, query, ...args) => rows(store, query, ...args)[0];
const exec = (store, query, ...args) => store.ctx.storage.sql.exec(query, ...args);

export function isPrivateStorageKey(key) {
  return String(key).startsWith(PRIVATE_PREFIX);
}
export function initColdStorage(store) {
  exec(store, `
    CREATE TABLE IF NOT EXISTS cold_batches(
      id INTEGER PRIMARY KEY,kind TEXT NOT NULL,user_id TEXT NOT NULL DEFAULT '',
      object_key TEXT NOT NULL UNIQUE,sha256 TEXT NOT NULL,size INTEGER NOT NULL,
      first_at INTEGER NOT NULL,last_at INTEGER NOT NULL,row_count INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_cold_batches_scope ON cold_batches(kind,user_id,last_at DESC);
    CREATE TABLE IF NOT EXISTS cold_wallet_references(
      user_id TEXT NOT NULL,reference_id TEXT NOT NULL,PRIMARY KEY(user_id,reference_id)
    );
    CREATE TABLE IF NOT EXISTS storage_budget(
      id INTEGER PRIMARY KEY CHECK(id=1),used_bytes INTEGER NOT NULL DEFAULT 0,
      known INTEGER NOT NULL DEFAULT 0,scanning INTEGER NOT NULL DEFAULT 0,
      cursor TEXT,scan_bytes INTEGER NOT NULL DEFAULT 0,scan_bucket INTEGER NOT NULL DEFAULT 0,reconciled_at INTEGER,
      next_run INTEGER NOT NULL,last_run INTEGER NOT NULL DEFAULT 0,next_sweep INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS media_write_leases(
      id TEXT PRIMARY KEY,object_key TEXT NOT NULL UNIQUE,size INTEGER NOT NULL,created_at INTEGER NOT NULL
    );
    CREATE TRIGGER IF NOT EXISTS cold_wallet_reference_guard BEFORE INSERT ON wallet_transactions
      WHEN NEW.reference_id IS NOT NULL AND EXISTS(
        SELECT 1 FROM cold_wallet_references WHERE user_id=NEW.user_id AND reference_id=NEW.reference_id
      )
      BEGIN SELECT RAISE(ABORT,'Wallet reference already recorded'); END;
    CREATE INDEX IF NOT EXISTS idx_wallet_transactions_age ON wallet_transactions(created_at);
    CREATE INDEX IF NOT EXISTS idx_direct_messages_unseen ON direct_messages(to_user_id,seen_at);
    CREATE INDEX IF NOT EXISTS idx_direct_messages_age ON direct_messages(created_at);
  `);
  try { exec(store,"ALTER TABLE direct_messages ADD COLUMN cold_batch_id INTEGER"); }
  catch(error) { if(!/duplicate|already exists/i.test(String(error))) throw error; }
  exec(store,"CREATE INDEX IF NOT EXISTS idx_direct_messages_cold_pending ON direct_messages(created_at) WHERE cold_batch_id IS NULL AND seen_at IS NOT NULL");
  try { exec(store,"ALTER TABLE direct_messages ADD COLUMN media_deleted_at INTEGER"); }
  catch(error) { if(!/duplicate|already exists/i.test(String(error))) throw error; }
  exec(store,`
    CREATE TABLE IF NOT EXISTS chat_retention_threads(
      peer_a TEXT NOT NULL,peer_b TEXT NOT NULL,next_check INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(peer_a,peer_b)
    );
    CREATE INDEX IF NOT EXISTS idx_chat_retention_due ON chat_retention_threads(next_check);
    CREATE INDEX IF NOT EXISTS idx_message_photo_expiry ON direct_messages(created_at)
      WHERE message_kind='image' AND media_deleted_at IS NULL;
    CREATE INDEX IF NOT EXISTS idx_notification_message_id ON user_notifications(json_extract(metadata_json,'$.message_id'))
      WHERE type='message';
    CREATE TRIGGER IF NOT EXISTS queue_chat_retention AFTER INSERT ON direct_messages
    BEGIN
      INSERT OR IGNORE INTO chat_retention_threads(peer_a,peer_b,next_check)
        VALUES(MIN(NEW.from_user_id,NEW.to_user_id),MAX(NEW.from_user_id,NEW.to_user_id),0);
    END;
    INSERT OR IGNORE INTO chat_retention_threads(peer_a,peer_b)
      SELECT MIN(from_user_id,to_user_id),MAX(from_user_id,to_user_id)
        FROM direct_messages GROUP BY MIN(from_user_id,to_user_id),MAX(from_user_id,to_user_id);
  `);
  exec(store,"INSERT OR IGNORE INTO storage_budget(id,next_run,next_sweep) VALUES(1,?,?)",Date.now()+10000,Date.now()+10000);
}
export function storageBudget(store) {
  const state=one(store,"SELECT * FROM storage_budget WHERE id=1");
  const limit=Math.min(R2_BYTE_LIMIT,Math.max(1,Number(store.env.R2_BYTE_LIMIT_BYTES)||R2_BYTE_LIMIT));
  return { ...state,limit_bytes:limit,write_blocked:!state?.known||!!state?.scanning||Number(state.used_bytes)>=limit };
}
export async function inventoryStorage(store, now=Date.now()) {
  const media=store.env.EFFECT_MEDIA,archives=store.env.USER_ARCHIVE;
  if(!media?.list||!archives?.list) return {ok:false,reason:"R2 inventory unavailable"};
  let state=one(store,"SELECT * FROM storage_budget WHERE id=1");
  const abandoned=rows(store,"SELECT id FROM media_write_leases WHERE created_at<?",now-3600000);
  if(abandoned.length) {
    exec(store,"DELETE FROM media_write_leases WHERE created_at<?",now-3600000);
    exec(store,"UPDATE storage_budget SET known=0 WHERE id=1");
  }
  if(one(store,"SELECT id FROM media_write_leases LIMIT 1")) return {ok:false,reason:"Upload in progress"};
  if(!state.scanning) {
    exec(store,"UPDATE storage_budget SET scanning=1,cursor=NULL,scan_bytes=0,scan_bucket=0 WHERE id=1");
    state={...state,scanning:1,cursor:null,scan_bytes:0,scan_bucket:0};
  }
  let cursor=state.cursor||undefined,total=Number(state.scan_bytes),bucketIndex=Number(state.scan_bucket);
  for(let page=0;page<20;page++) {
    const bucket=bucketIndex===0?media:archives;
    const listing=await bucket.list({limit:1000,...(cursor?{cursor}:{})});
    for(const object of listing.objects) {
      const match=bucketIndex===0?/^profiles\/([^/]+)\/avatar$/.exec(object.key):null;
      let obsolete=false;
      if(match&&Number(new Date(object.uploaded))<now-3600000) {
        const ownerId=store._resolveOwnerUserId(match[1]);
        const owner=one(store,"SELECT avatar_data_url FROM app_users WHERE user_id=?",ownerId);
        obsolete=!owner||mediaKey(store.env,owner.avatar_data_url)!==object.key;
        if(obsolete) {
          const base=store.env.PUBLIC_API_ORIGIN||"https://tinni-star-api.mishrajii7991.workers.dev";
          const references=rows(store,"SELECT avatar_data_url FROM app_users WHERE avatar_data_url LIKE ? OR avatar_data_url LIKE ?",base+"/media/"+encodeURIComponent(object.key)+"%",base+"/media/"+object.key+"%");
          if(references.some(row=>mediaKey(store.env,row.avatar_data_url)===object.key)) obsolete=false;
        }
      }
      if(bucketIndex===0&&object.key.startsWith("messages/")&&Number(new Date(object.uploaded))<now-CHAT_PHOTO_MS) obsolete=true;
      if(bucketIndex===1&&isPrivateStorageKey(object.key)&&Number(new Date(object.uploaded))<now-DAY_MS) {
        obsolete=!one(store,"SELECT id FROM cold_batches WHERE object_key=?",object.key);
      }
      if(obsolete) await bucket.delete(object.key);
      else total+=Number(object.size||0);
    }
    if(!listing.truncated) {
      if(bucketIndex===0) {bucketIndex=1;cursor=undefined;continue;}
      exec(store,"UPDATE storage_budget SET used_bytes=?,known=1,scanning=0,cursor=NULL,scan_bytes=0,scan_bucket=0,reconciled_at=? WHERE id=1",total,now);
      return {ok:true,used_bytes:total};
    }
    cursor=listing.cursor;
    if(!cursor) throw new Error("R2 inventory cursor missing");
  }
  exec(store,"UPDATE storage_budget SET cursor=?,scan_bytes=?,scan_bucket=? WHERE id=1",cursor||null,total,bucketIndex);
  return {ok:false,reason:"Inventory continuation",used_bytes:total};
}
export async function reserveMediaBudget(store, key, size, leaseId) {
  if(!Number.isSafeInteger(size)||size<1||size>4_000_000||!key||!leaseId) throw new Error("Invalid media reservation");
  let state=storageBudget(store);
  if(!state.known&&!state.scanning) {
    await store.ctx.blockConcurrencyWhile(()=>inventoryStorage(store));
    state=storageBudget(store);
  }
  if(state.write_blocked||Number(state.used_bytes)+size>state.limit_bytes) {
    throw new Error("Storage budget reached or inventory pending. Existing data is preserved; new uploads are paused.");
  }
  return store.ctx.storage.transactionSync(()=>{
    exec(store,"INSERT INTO media_write_leases(id,object_key,size,created_at) VALUES(?,?,?,?)",leaseId,key,size,Date.now());
    // Reserve the entire new object before I/O. Replacement space is released only after success.
    exec(store,"UPDATE storage_budget SET used_bytes=used_bytes+? WHERE id=1",size);
    return leaseId;
  });
}
export function completeMediaBudget(store, leaseId, replacedBytes=0) {
  const lease=one(store,"SELECT * FROM media_write_leases WHERE id=?",leaseId);
  if(!lease) return;
  store.ctx.storage.transactionSync(()=>{
    exec(store,"UPDATE storage_budget SET used_bytes=MAX(0,used_bytes-?) WHERE id=1",Math.max(0,Number(replacedBytes)||0));
    exec(store,"DELETE FROM media_write_leases WHERE id=?",leaseId);
  });
}
export function abortMediaBudget(store, leaseId, writeAttempted) {
  const lease=one(store,"SELECT * FROM media_write_leases WHERE id=?",leaseId);
  if(!lease) return;
  store.ctx.storage.transactionSync(()=>{
    if(writeAttempted) exec(store,"UPDATE storage_budget SET known=0,next_run=MIN(next_run,?) WHERE id=1",Date.now()+60000);
    else exec(store,"UPDATE storage_budget SET used_bytes=MAX(0,used_bytes-?) WHERE id=1",lease.size);
    exec(store,"DELETE FROM media_write_leases WHERE id=?",leaseId);
  });
}
function directory(env) {
  return env.APP_DIRECTORY.get(env.APP_DIRECTORY.idFromName("tinni-app-directory"));
}
export async function managedMediaPut(env,key,bytes,options) {
  const owner=directory(env),lease=crypto.randomUUID();
  await owner.reserveMediaBudget(key,bytes.byteLength,lease);
  let attempted=false;
  try {
    // A key lease serializes replacement uploads before this HEAD.
    const previous=await env.EFFECT_MEDIA.head(key);
    attempted=true;
    const object=await env.EFFECT_MEDIA.put(key,bytes,options);
    await owner.completeMediaBudget(lease,Number(previous?.size||0));
    return object;
  } catch(error) {
    try { await owner.abortMediaBudget(lease,attempted); } catch {}
    throw error;
  }
}
export async function putPrivateBatch(store,kind,userId,data) {
  const raw=encoder.encode(JSON.stringify({version:1,kind,rows:data}));
  const packed=new Uint8Array(await new Response(
    new Blob([raw]).stream().pipeThrough(new CompressionStream("gzip"))
  ).arrayBuffer());
  const digest=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",packed)),x=>x.toString(16).padStart(2,"0")).join("");
  const key=PRIVATE_PREFIX+kind+"/"+digest+".json.gz",lease=crypto.randomUUID();
  await reserveMediaBudget(store,key,packed.byteLength,lease);
  let attempted=false;
  try {
    const previous=await store.env.USER_ARCHIVE.head(key);
    attempted=true;
    await store.env.USER_ARCHIVE.put(key,packed,{httpMetadata:{contentType:"application/octet-stream"},
      customMetadata:{sha256:digest,kind}});
    const verified=await store.env.USER_ARCHIVE.get(key);
    if(!verified) throw new Error("Archive verification failed");
    const bytes=new Uint8Array(await verified.arrayBuffer());
    const actual=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",bytes)),x=>x.toString(16).padStart(2,"0")).join("");
    if(actual!==digest) throw new Error("Archive verification failed");
    completeMediaBudget(store,lease,Number(previous?.size||0));
    return {key,digest,size:packed.byteLength};
  } catch(error) {
    abortMediaBudget(store,lease,attempted);
    throw error;
  }
}
export async function readPrivateBatch(store,batch) {
  store._coldCache??=new Map();
  if(store._coldCache.has(batch.object_key)) return store._coldCache.get(batch.object_key);
  const object=await store.env.USER_ARCHIVE.get(batch.object_key);
  if(!object) throw new Error("Archived history temporarily unavailable");
  const bytes=new Uint8Array(await object.arrayBuffer());
  const digest=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",bytes)),x=>x.toString(16).padStart(2,"0")).join("");
  if(digest!==batch.sha256) throw new Error("Archived history integrity check failed");
  const parsed=JSON.parse(await new Response(new Blob([bytes]).stream()
    .pipeThrough(new DecompressionStream("gzip"))).text());
  if(parsed.version!==1||parsed.kind!==batch.kind||!Array.isArray(parsed.rows)) throw new Error("Invalid archive");
  if(store._coldCache.size>=8) store._coldCache.delete(store._coldCache.keys().next().value);
  store._coldCache.set(batch.object_key,parsed.rows);
  return parsed.rows;
}
export async function archiveWalletBatch(store,now=Date.now()) {
  const cutoff=now-30*DAY_MS;
  const candidate=one(store,"SELECT user_id FROM wallet_transactions WHERE created_at<? ORDER BY created_at LIMIT 1",cutoff);
  if(!candidate) return 0;
  const data=rows(store,"SELECT * FROM wallet_transactions WHERE user_id=? AND created_at<? ORDER BY created_at LIMIT ?",candidate.user_id,cutoff,BATCH_ROWS);
  const uploaded=await putPrivateBatch(store,"wallet",candidate.user_id,data);
  store.ctx.storage.transactionSync(()=>{
    exec(store,"INSERT INTO cold_batches(kind,user_id,object_key,sha256,size,first_at,last_at,row_count) VALUES('wallet',?,?,?,?,?,?,?)",
      candidate.user_id,uploaded.key,uploaded.digest,uploaded.size,data[0].created_at,data.at(-1).created_at,data.length);
    for(const row of data) {
      if(row.reference_id!==null) exec(store,"INSERT OR IGNORE INTO cold_wallet_references(user_id,reference_id) VALUES(?,?)",row.user_id,row.reference_id);
      exec(store,"DELETE FROM wallet_transactions WHERE id=?",row.id);
    }
  });
  return data.length;
}
export async function walletHistory(store,userId,limit=200,before=Number.MAX_SAFE_INTEGER) {
  limit=Math.max(1,Math.min(500,Number(limit)||200));
  before=Number(before)||Number.MAX_SAFE_INTEGER;
  let result=rows(store,"SELECT * FROM wallet_transactions WHERE user_id=? AND created_at<? ORDER BY created_at DESC,id DESC LIMIT ?",userId,before,limit);
  const batches=rows(store,"SELECT * FROM cold_batches WHERE kind='wallet' AND user_id=? AND first_at<? ORDER BY last_at DESC LIMIT 64",userId,before);
  for(const batch of batches) {
    if(result.length>=limit&&Number(batch.last_at)<Number(result.at(-1).created_at)) break;
    result.push(...(await readPrivateBatch(store,batch)).filter(row=>Number(row.created_at)<before));
    result.sort((a,b)=>Number(b.created_at)-Number(a.created_at)||String(b.id).localeCompare(String(a.id)));
    result=result.slice(0,limit);
  }
  return result;
}
// Long chats are removed from server storage; the app retains received history on the phone.
export async function cleanupPrivateChats(store,now=Date.now()) {
  const cutoff=now-CHAT_PHOTO_MS;
  let photos=0,messages=0;
  const expiredPhotos=rows(store,`SELECT id FROM direct_messages
    WHERE message_kind='image' AND media_deleted_at IS NULL AND created_at<?
    ORDER BY created_at LIMIT 512`,cutoff);
  for(const row of expiredPhotos) {
    await store.env.EFFECT_MEDIA?.delete("messages/"+row.id);
    exec(store,"UPDATE direct_messages SET media_deleted_at=? WHERE id=?",now,row.id);
    photos++;
  }
  const pending=rows(store,"SELECT * FROM chat_retention_threads WHERE next_check<=? ORDER BY next_check LIMIT 32",now);
  for(const thread of pending) {
    if(messages>=512) break;
    const a=store._resolveOwnerUserId(thread.peer_a)||thread.peer_a;
    const b=store._resolveOwnerUserId(thread.peer_b)||thread.peer_b;
    const boundary=one(store,`SELECT id,created_at FROM direct_messages
      WHERE (from_user_id=? AND to_user_id=?) OR (from_user_id=? AND to_user_id=?)
      ORDER BY created_at DESC,id DESC LIMIT 1 OFFSET ?`,a,b,b,a,CHAT_SERVER_MESSAGES-1);
    if(!boundary) {
      exec(store,"DELETE FROM chat_retention_threads WHERE peer_a=? AND peer_b=?",thread.peer_a,thread.peer_b);
      continue;
    }
    const expired=rows(store,`SELECT id,message_kind FROM direct_messages
      WHERE ((from_user_id=? AND to_user_id=?) OR (from_user_id=? AND to_user_id=?))
        AND created_at<? AND (created_at<? OR (created_at=? AND id<?))
      ORDER BY created_at,id LIMIT ?`,a,b,b,a,cutoff,boundary.created_at,boundary.created_at,boundary.id,512-messages);
    for(const row of expired) {
      // Delete the object before its authorizing SQL record; a failed deletion retries next sweep.
      if(row.message_kind==='image') await store.env.EFFECT_MEDIA?.delete("messages/"+row.id);
      store.ctx.storage.transactionSync(()=>{
        exec(store,"DELETE FROM user_notifications WHERE type='message' AND json_extract(metadata_json,'$.message_id')=?",row.id);
        exec(store,"DELETE FROM owner_panel_message_log WHERE message_id=?",row.id);
        exec(store,"DELETE FROM direct_messages WHERE id=?",row.id);
      });
      messages++;
    }
    const oldestExcess=one(store,`SELECT created_at FROM direct_messages
      WHERE (from_user_id=? AND to_user_id=?) OR (from_user_id=? AND to_user_id=?)
      ORDER BY created_at DESC,id DESC LIMIT 1 OFFSET ?`,a,b,b,a,CHAT_SERVER_MESSAGES);
    if(!oldestExcess) exec(store,"DELETE FROM chat_retention_threads WHERE peer_a=? AND peer_b=?",thread.peer_a,thread.peer_b);
    else exec(store,"UPDATE chat_retention_threads SET next_check=? WHERE peer_a=? AND peer_b=?",
      Math.max(now+3600000,Number(oldestExcess.created_at)+CHAT_PHOTO_MS+1),thread.peer_a,thread.peer_b);
  }
  return {deleted_photos:photos,deleted_messages:messages,server_messages_per_chat:CHAT_SERVER_MESSAGES};
}
export async function hydrateMessages(store,data) {
  const ids=[...new Set(data.map(row=>row.cold_batch_id).filter(Boolean))];
  const payloads=new Map();
  for(const id of ids) {
    const batch=one(store,"SELECT * FROM cold_batches WHERE id=?",id);
    if(!batch) throw new Error("Message archive index unavailable");
    for(const row of await readPrivateBatch(store,batch)) payloads.set(row.id,row);
  }
  return data.map(row=>{
    if(row.cold_batch_id&&!payloads.has(row.id)) throw new Error("Message archive record unavailable");
    return row.cold_batch_id?{...row,...payloads.get(row.id)}:row;
  });
}
export function walletReferenceExists(store,userId,referenceId) {
  return !!one(store,`SELECT id FROM wallet_transactions WHERE user_id=? AND reference_id=?
    UNION ALL SELECT reference_id AS id FROM cold_wallet_references WHERE user_id=? AND reference_id=? LIMIT 1`,
    userId,referenceId,userId,referenceId);
}
export function mediaKey(env,value) {
  try {
    const url=new URL(value),origin=new URL(env.PUBLIC_API_ORIGIN||"https://tinni-star-api.mishrajii7991.workers.dev").origin;
    return url.origin===origin&&url.pathname.startsWith("/media/")?decodeURIComponent(url.pathname.slice(7)):null;
  } catch {return null;}
}
export async function deleteOldAvatar(store,previous,next,userId) {
  const oldKey=mediaKey(store.env,previous),newKey=mediaKey(store.env,next);
  if(!oldKey||oldKey===newKey||!/^profiles\/[^/]+\/avatar$/.test(oldKey)) return false;
  // A current reference always wins over a stale cleanup request.
  const active=one(store,"SELECT avatar_data_url FROM app_users WHERE user_id=?",userId);
  if(active&&mediaKey(store.env,active.avatar_data_url)===oldKey) return false;
  await store.env.EFFECT_MEDIA?.delete(oldKey);
  return true;
}
export async function copyInlineAvatar(store,userId,dataUrl,now=Date.now()) {
  const match=/^data:(image\/(?:jpeg|png|webp));base64,([A-Za-z0-9+/=]+)$/.exec(dataUrl);
  if(!match) throw new Error("DP must be a JPEG, PNG or WebP image");
  const bytes=Uint8Array.from(atob(match[2]),char=>char.charCodeAt(0));
  const key="profiles/"+userId+"/avatar",lease=crypto.randomUUID();
  await reserveMediaBudget(store,key,bytes.byteLength,lease);
  let attempted=false;
  try {
    const previous=await store.env.EFFECT_MEDIA.head(key);
    attempted=true;
    await store.env.EFFECT_MEDIA.put(key,bytes,{httpMetadata:{contentType:match[1]},customMetadata:{user_id:userId,slot:"avatar",updated_at:String(now)}});
    const copied=await store.env.EFFECT_MEDIA.get(key);
    if(!copied||!safeBytesEqual(bytes,new Uint8Array(await copied.arrayBuffer()))) throw new Error("DP copy verification failed");
    completeMediaBudget(store,lease,Number(previous?.size||0));
    return (store.env.PUBLIC_API_ORIGIN||"https://tinni-star-api.mishrajii7991.workers.dev")+"/media/"+encodeURIComponent(key)+"?v="+now;
  } catch(error) {abortMediaBudget(store,lease,attempted);throw error;}
}
export async function moveInlineAvatar(store,now=Date.now(),userId=null) {
  const row=userId?one(store,"SELECT user_id,avatar_data_url FROM app_users WHERE user_id=? AND avatar_data_url LIKE 'data:image/%'",userId):one(store,"SELECT user_id,avatar_data_url FROM app_users WHERE avatar_data_url LIKE 'data:image/%' LIMIT 1");
  if(!row) return 0;
  const url=await copyInlineAvatar(store,row.user_id,row.avatar_data_url,now);
  exec(store,"UPDATE app_users SET avatar_data_url=? WHERE user_id=? AND avatar_data_url=?",url,row.user_id,row.avatar_data_url);
  exec(store,"UPDATE country_ribbons SET avatar_data_url=? WHERE user_id=?",url,row.user_id);
  store._notifyAccountChanged(row.user_id);
  store._notifyProfileChanged?.(row.user_id);
  const user=await store.getUserById(row.user_id);
  const presence=one(store,"SELECT room_id FROM app_user_presence WHERE user_id=?",row.user_id);
  if(presence?.room_id&&store.env.ROOM_PRESENCE) await store.env.ROOM_PRESENCE.get(store.env.ROOM_PRESENCE.idFromName(presence.room_id)).updateMemberProfile(user);
  return 1;
}
function safeBytesEqual(a,b) {return a.length===b.length&&a.every((value,index)=>value===b[index]);}
export function cleanupExpiredRows(store,now=Date.now()) {
  // Credentials remain durable. Only expired transient rows are eligible.
  const targets=[
    ["app_session_revocations","token_hash","expires_at",now],
    ["email_otp_requests","request_id","expires_at",now],
    ["facebook_login_requests","request_id","updated_at",now-DAY_MS],
    ["privileged_wallet_reset_requests","request_id","expires_at",now],
    ["room_access_grants","rowid","expires_at",now],
    ["security_action_windows","rowid","updated_at",now-DAY_MS],
    ["country_ribbons","id","expires_at",now],
    ["ribbon_live_delivery","id","expires_at",now],
  ];
  for(const [table,id,column,cutoff] of targets) exec(store,
    "DELETE FROM "+table+" WHERE "+id+" IN (SELECT "+id+" FROM "+table+" WHERE "+column+"<? LIMIT 128)",cutoff);
}
export async function runColdMaintenance(store,now=Date.now()) {
  const state=one(store,"SELECT * FROM storage_budget WHERE id=1");
  if(!state||Number(state.next_run)>now) return {ok:true,skipped:true};
  // This queue lock includes R2 verification and its SQL commit. ID changes and messages cannot race it.
  return store.ctx.blockConcurrencyWhile(async()=>{
    const current=one(store,"SELECT * FROM storage_budget WHERE id=1");
    if(Number(current.next_run)>now) return {ok:true,skipped:true};
    exec(store,"UPDATE storage_budget SET next_run=?,last_run=? WHERE id=1",now+DAY_MS,now);
    let archivedWallet=0,avatars=0;
    try {
      const inventory=await inventoryStorage(store,now);
      if(!inventory.ok) {
        exec(store,"UPDATE storage_budget SET next_run=? WHERE id=1",now+3600000);
        return inventory;
      }
      const deadline=Date.now()+12000;
      for(let batch=0;batch<16&&Date.now()<deadline;batch++) {
        const moved=await archiveWalletBatch(store,now);
        archivedWallet+=moved;
        if(!moved) break;
      }
      for(let image=0;image<64&&Date.now()<deadline;image++) {
        const moved=await moveInlineAvatar(store,now);
        avatars+=moved;
        if(!moved) break;
      }
    } catch(error) {
      console.error("Storage maintenance paused; source rows remain safe",String(error?.message||error));
    }
    cleanupExpiredRows(store,now);
    return {ok:true,archived_wallet_rows:archivedWallet,migrated_current_avatars:avatars};
  });
}
export function initGameRetention(store,prefix) {
  exec(store,`
    CREATE TABLE IF NOT EXISTS game_history_totals(id INTEGER PRIMARY KEY,bet_count INTEGER NOT NULL DEFAULT 0,total_bet INTEGER NOT NULL DEFAULT 0,rounds INTEGER NOT NULL DEFAULT 0,total_payout INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE IF NOT EXISTS game_history_players(user_id TEXT PRIMARY KEY,bet_count INTEGER NOT NULL DEFAULT 0,total_bet INTEGER NOT NULL DEFAULT 0);
    INSERT OR IGNORE INTO game_history_totals(id) VALUES(1);
  `);
  exec(store,"CREATE INDEX IF NOT EXISTS idx_"+prefix+"_result_expiry ON "+prefix+"_results(settled_at)");
  exec(store,"CREATE INDEX IF NOT EXISTS idx_"+prefix+"_outbox_round ON "+prefix+"_result_outbox(round_id)");
}
export function pruneGameHistory(store,prefix,now=Date.now()) {
  const cutoff=now-GAME_HISTORY_MS;
  const expired=rows(store,"SELECT round_id,total_payout FROM "+prefix+"_results r WHERE settled_at<? AND NOT EXISTS(SELECT 1 FROM "+prefix+"_result_outbox q WHERE q.round_id=r.round_id) ORDER BY round_id LIMIT 256",cutoff);
  store.ctx.storage.transactionSync(()=>{
    for(const result of expired) {
      const bets=rows(store,"SELECT user_id,COUNT(*) AS n,SUM(amount) AS amount FROM "+prefix+"_bets WHERE round_id=? GROUP BY user_id",result.round_id);
      for(const bet of bets) {
        exec(store,"INSERT INTO game_history_players(user_id,bet_count,total_bet) VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET bet_count=bet_count+excluded.bet_count,total_bet=total_bet+excluded.total_bet",bet.user_id,bet.n,bet.amount);
        exec(store,"UPDATE game_history_totals SET bet_count=bet_count+?,total_bet=total_bet+? WHERE id=1",bet.n,bet.amount);
      }
      exec(store,"UPDATE game_history_totals SET rounds=rounds+1,total_payout=total_payout+? WHERE id=1",result.total_payout);
      exec(store,"DELETE FROM "+prefix+"_bets WHERE round_id=?",result.round_id);
      exec(store,"DELETE FROM "+prefix+"_results WHERE round_id=?",result.round_id);
    }
    exec(store,"DELETE FROM "+prefix+"_latest_results WHERE json_extract(payload,'$.settled_at')<? AND NOT EXISTS(SELECT 1 FROM "+prefix+"_result_outbox q WHERE q.user_id="+prefix+"_latest_results.user_id)",cutoff);
  });
  return {ok:true,deleted_rounds:expired.length,retention_days:15};
}

export function initMainGameRetention(store) {
  exec(store,`
    CREATE TABLE IF NOT EXISTS settled_game_receipts(
      id TEXT PRIMARY KEY,user_id TEXT NOT NULL,game_key TEXT NOT NULL,round_id INTEGER NOT NULL,winning_coins INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS main_game_lifetime(
      user_id TEXT NOT NULL,game_key TEXT NOT NULL,net_coins INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(user_id,game_key)
    );
    CREATE INDEX IF NOT EXISTS idx_main_game_settled_age ON main_game_bets(settled_at);
  `);
}
export function pruneMainGameHistory(store,now=Date.now()) {
  const cutoff=now-GAME_HISTORY_MS;
  const data=rows(store,"SELECT * FROM main_game_bets WHERE settled_at IS NOT NULL AND settled_at<? ORDER BY settled_at LIMIT 512",cutoff);
  store.ctx.storage.transactionSync(()=>{
    for(const row of data) {
      exec(store,"INSERT INTO settled_game_receipts(id,user_id,game_key,round_id,winning_coins) VALUES(?,?,?,?,?)",
        row.id,row.user_id,row.game_key,row.round_id,row.winning_coins);
      exec(store,"INSERT INTO main_game_lifetime(user_id,game_key,net_coins) VALUES(?,?,?) ON CONFLICT(user_id,game_key) DO UPDATE SET net_coins=net_coins+excluded.net_coins",
        row.user_id,row.game_key,Number(row.winning_coins)-Number(row.amount));
      exec(store,"DELETE FROM main_game_bets WHERE id=?",row.id);
    }
    exec(store,"DELETE FROM latest_game_results WHERE json_extract(payload,'$.settled_at')<?",cutoff);
  });
  return data.length;
}
export async function sweepGameRetention(store,now=Date.now()) {
  const state=one(store,"SELECT next_sweep FROM storage_budget WHERE id=1");
  if(Number(state?.next_sweep)>now) return {skipped:true};
  exec(store,"UPDATE storage_budget SET next_sweep=? WHERE id=1",now+3600000);
  const pruned=pruneMainGameHistory(store,now);
  try { await cleanupPrivateChats(store,now); }
  catch(error) {console.error("Private chat cleanup will retry",String(error?.message||error));}
  for(const [binding,id] of [["FRUIT_GAME","tinni-fruit-game-global"],["FRUIT_PARTY","tinni-fruit-party-global"]]) {
    if(!store.env[binding]) continue;
    try {await store.env[binding].get(store.env[binding].idFromName(id)).pruneHistory(now);}
    catch(error) {console.error("Game retention will retry",String(error?.message||error));}
  }
  return {pruned_main_bets:pruned};
}
