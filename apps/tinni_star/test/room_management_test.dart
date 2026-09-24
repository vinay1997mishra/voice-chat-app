import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/discovery/discovery_service.dart';

void main() {
  test('room discovery can edit favorite and track real rooms', () {
    final discovery = DiscoveryService();
    const room = RoomSummary(
      id: '91000001',
      title: 'My Tinni Room',
      country: 'IN',
      online: 1,
      ownerId: '91000001',
    );
    discovery.rooms.add(room);

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
