import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/discovery/discovery_service.dart';

void main() {
  test('New contains only rooms created within the last 15 days', () {
    final now = DateTime(2026, 9, 23, 10);
    final service = DiscoveryService();
    service.rooms.addAll([
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
    ]);

    final rooms = service.newRooms(now: now);
    expect(rooms.map((room) => room.id), ['new-1', 'new-15']);
  });

  test('fresh server room is classified as new', () {
    final now = DateTime.now();
    final room = RoomSummary(
      id: '91000001',
      title: 'Fresh Room',
      country: 'IN',
      online: 1,
      seatCount: 12,
      createdAt: now,
      ownerId: '91000001',
    );

    expect(
      room.createdWithin(const Duration(days: 15), now: now),
      isTrue,
    );
  });
}
