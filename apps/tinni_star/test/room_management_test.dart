import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/discovery/discovery_service.dart';

void main() {
  test('room discovery can create edit favorite and track recent rooms', () {
    final discovery = DiscoveryService();
    final room = discovery.createRoom(
      title: 'My Tinni Room',
      country: 'IN',
    );
    expect(discovery.rooms.first.id, room.id);

    expect(
      discovery.editRoom(
        room.id,
        title: 'My Updated Room',
        locked: true,
        activity: true,
      ),
      true,
    );
    final updated = discovery.rooms.firstWhere((item) => item.id == room.id);
    expect(updated.title, 'My Updated Room');
    expect(updated.locked, true);
    expect(updated.activity, true);

    discovery.toggleFavorite(room.id);
    discovery.visit(room.id);
    expect(discovery.favorites, contains(room.id));
    expect(discovery.recentRoomIds.first, room.id);
  });
}
