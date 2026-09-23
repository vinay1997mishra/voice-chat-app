import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/discovery/discovery_service.dart';

void main() {
  test('New contains only rooms created within the last 15 days', () {
    final now = DateTime(2026, 9, 23, 10);
    final service = DiscoveryService(
      seed: [
        RoomSummary(
          id: 'new-1',
          title: 'New 1',
          country: 'IN',
          online: 1,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        RoomSummary(
          id: 'new-15',
          title: 'New 15',
          country: 'IN',
          online: 1,
          createdAt: now.subtract(const Duration(days: 15)),
        ),
        RoomSummary(
          id: 'old-16',
          title: 'Old 16',
          country: 'IN',
          online: 1,
          createdAt: now.subtract(const Duration(days: 16)),
        ),
      ],
    );

    final rooms = service.newRooms(now: now);
    expect(rooms.map((room) => room.id), ['new-1', 'new-15']);
  });

  test('newly created room receives creation timestamp', () {
    final service = DiscoveryService(seed: const []);
    final before = DateTime.now();
    final room = service.createRoom(
      title: 'Fresh Room',
      country: 'IN',
      seatCount: 40,
    );
    final after = DateTime.now();

    expect(room.seatCount, 40);
    expect(room.createdAt, isNotNull);
    expect(room.createdAt!.isBefore(before), false);
    expect(room.createdAt!.isAfter(after), false);
  });
}
