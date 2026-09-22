class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.title,
    required this.country,
    required this.online,
    this.locked = false,
    this.activity = false,
  });

  final String id;
  final String title;
  final String country;
  final int online;
  final bool locked;
  final bool activity;
}

class DiscoveryService {
  DiscoveryService({List<RoomSummary>? seed})
      : rooms = seed ??
            const [
              RoomSummary(
                id: '1524843',
                title: 'India Official Room',
                country: 'IN',
                online: 128,
              ),
              RoomSummary(
                id: '10000001',
                title: 'Night Party',
                country: 'IN',
                online: 86,
                activity: true,
              ),
              RoomSummary(
                id: '10000002',
                title: 'Music Club',
                country: 'US',
                online: 54,
              ),
            ];

  final List<RoomSummary> rooms;
  final List<String> searchHistory = <String>[];
  final List<String> recentRoomIds = <String>[];
  final Set<String> favorites = <String>{};

  List<RoomSummary> recommend({String? country}) {
    final filtered = country == null
        ? rooms
        : rooms.where((room) => room.country == country).toList();
    final sorted = List<RoomSummary>.from(filtered)
      ..sort((a, b) => b.online.compareTo(a.online));
    return sorted;
  }

  List<RoomSummary> search(String query) {
    final value = query.trim();
    if (value.isEmpty) return const [];
    searchHistory.remove(value);
    searchHistory.insert(0, value);
    final lower = value.toLowerCase();
    return rooms
        .where(
          (room) =>
              room.id == value || room.title.toLowerCase().contains(lower),
        )
        .toList();
  }

  void visit(String roomId) {
    recentRoomIds.remove(roomId);
    recentRoomIds.insert(0, roomId);
  }

  void toggleFavorite(String roomId) {
    if (!favorites.add(roomId)) favorites.remove(roomId);
  }

  void clearHistory() => searchHistory.clear();
  void clearRecent() => recentRoomIds.clear();
}
