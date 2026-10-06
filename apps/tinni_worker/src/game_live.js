// Only changes cross the socket; clocks and animations stay on the device.
export function gameSockets(store, gameKey, roomId = "") {
  return store.ctx.getWebSockets?.("game:" + gameKey + (roomId ? ":" + roomId : "")) || [];
}
export function notifyGameChanged(store, gameKey, roomId = "") {
  const payload = JSON.stringify({ type: "game_changed", game_key: gameKey, room_id: roomId });
  for (const socket of gameSockets(store, gameKey, roomId)) {
    try { socket.send(payload); } catch {}
  }
}
async function sendState(store, socket, attachment) {
  const state = attachment.gameKey === "ludo"
    ? store.ludoState(attachment.userId, attachment.roomId)
    : await store.state(attachment.userId);
  socket.send(JSON.stringify({ type: "game_state", game_key: attachment.gameKey, state }));
}
export async function openGameSocket(store, request, gameKey) {
  if ((request.headers.get("upgrade") || "").toLowerCase() !== "websocket") {
    return new Response("WebSocket required", { status: 426 });
  }
  const userId = String(request.headers.get("x-tinni-user-id") || "").trim();
  const roomId = gameKey === "ludo" ? String(request.headers.get("x-tinni-room-id") || "").trim() : "";
  if (!userId || (gameKey === "ludo" && !roomId)) return new Response("Unauthorized", { status: 401 });
  // Validate room admission before accepting a Ludo connection.
  if (gameKey === "ludo") store._requireActiveRoomUser(userId, roomId);
  const pair = new WebSocketPair();
  const expiresAt = Number(request.headers.get("x-tinni-session-expires") || 0);
  const attachment = { userId, roomId, gameKey, expiresAt };
  store.ctx.acceptWebSocket(pair[1], ["game:" + gameKey + (roomId ? ":" + roomId : "")]);
  pair[1].serializeAttachment(attachment);
  await sendState(store, pair[1], attachment);
  return new Response(null, { status: 101, webSocket: pair[0] });
}
export async function handleGameMessage(store, socket, message) {
  if (typeof message !== "string" || message.length > 256) return;
  let payload;
  try { payload = JSON.parse(message); } catch { return; }
  if (payload?.type !== "state") return;
  const attachment = socket.deserializeAttachment?.() || {};
  if (!attachment.userId || !attachment.gameKey) return;
  if (attachment.expiresAt && attachment.expiresAt <= Date.now()) {
    try { socket.close(1008, 'Session expired'); } catch {}
    return;
  }
  try { await sendState(store, socket, attachment); }
  catch {
    try { socket.close(1008, "Game session unavailable"); } catch {}
  }
}
