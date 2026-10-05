import worker from '../../src/index.js';
export { StaffAuthStore, AppDirectoryStore, RoomPresenceStore, FruitGameStore, FruitPartyStore } from '../../src/index.js';
export default {
  async fetch(request, env, ctx) {
    if (new URL(request.url).pathname === '/__fixture/user') {
      const body = await request.json();
      const directory = env.APP_DIRECTORY.get(env.APP_DIRECTORY.idFromName('tinni-app-directory'));
      const user = await directory.createUser({
        auth_provider: 'google', auth_subject: 'workerd-' + body.index,
        email: 'workerd-' + body.index + '@example.test',
        display_name: 'Player ' + body.index, age: 25, country_code: 'IN',
        country_name: 'India', flag_emoji: '🇮🇳', gender: 'male', language: 'English',
      });
      const room = body.createRoom
        ? await directory.createRoom(user.user_id, { title: 'Workerd room', seat_count: 12 })
        : null;
      if (room && body.markRecent) await directory.markRecentRoom(user.user_id, room.id);
      return Response.json({ user, room });
    }
    return worker.fetch(request, env, ctx);
  },
};
