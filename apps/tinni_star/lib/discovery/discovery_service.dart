class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.title,
    required this.country,
    required this.online,
    this.locked = false,
    this.activity = false,
    this.seatCount = 12,
    this.partyMode = 'Friends-making Party',
    this.createdAt,
  });

  final String id;
  final String title;
  final String country;
  final int online;
  final bool locked;
  final bool activity;
  final int seatCount;
  final String partyMode;
  final DateTime? createdAt;

  bool createdWithin(
    Duration age, {
    DateTime? now,
  }) {
    final created = createdAt;
    if (created == null) return false;
    final reference = now ?? DateTime.now();
    final cutoff = reference.subtract(age);
    return !created.isBefore(cutoff) && !created.isAfter(reference);
  }

  RoomSummary copyWith({
    String? title,
    String? country,
    int? online,
    bool? locked,
    bool? activity,
    int? seatCount,
    String? partyMode,
    DateTime? createdAt,
  }) =>
      RoomSummary(
        id: id,
        title: title ?? this.title,
        country: country ?? this.country,
        online: online ?? this.online,
        locked: locked ?? this.locked,
        activity: activity ?? this.activity,
        seatCount: seatCount ?? this.seatCount,
        partyMode: partyMode ?? this.partyMode,
        createdAt: createdAt ?? this.createdAt,
      );
}

class DiscoveryService {
  DiscoveryService({List<RoomSummary>? seed})
      : rooms = List<RoomSummary>.from(seed ?? _defaultRooms());

  final List<RoomSummary> rooms;
  final List<String> searchHistory = <String>[];
  final List<String> recentRoomIds = <String>[];
  final Set<String> favorites = <String>{};
  int _nextRoomId = 20000000;

  static List<RoomSummary> _defaultRooms() {
    final now = DateTime.now();
    return [
      RoomSummary(
        id: '1524843',
        title: 'India Official Room',
        country: 'IN',
        online: 128,
        activity: true,
        seatCount: 12,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      RoomSummary(
        id: '10000001',
        title: 'Golden Hearts Party',
        country: 'IN',
        online: 86,
        activity: true,
        seatCount: 15,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      RoomSummary(
        id: '10000002',
        title: 'Royal Music Club',
        country: 'US',
        online: 54,
        seatCount: 10,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      RoomSummary(
        id: '10000003',
        title: 'Dil Se Friends',
        country: 'IN',
        online: 44,
        seatCount: 12,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      RoomSummary(
        id: '10000004',
        title: 'Night Kings',
        country: 'IN',
        online: 24,
        seatCount: 8,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ];
  }

  RoomSummary createRoom({
    required String title,
    required String country,
    bool locked = false,
    int seatCount = 12,
    String partyMode = 'Friends-making Party',
  }) {
    final value = title.trim();
    if (value.isEmpty) throw StateError('Room title is required');
    final room = RoomSummary(
      id: (_nextRoomId++).toString(),
      title: value,
      country: country,
      online: 1,
      locked: locked,
      seatCount: seatCount,
      partyMode: partyMode,
      createdAt: DateTime.now(),
    );
    rooms.insert(0, room);
    return room;
  }

  bool editRoom(
    String roomId, {
    String? title,
    bool? locked,
    bool? activity,
    int? seatCount,
    String? partyMode,
  }) {
    final index = rooms.indexWhere((room) => room.id == roomId);
    if (index < 0) return false;
    rooms[index] = rooms[index].copyWith(
      title: title?.trim().isEmpty == true ? null : title,
      locked: locked,
      activity: activity,
      seatCount: seatCount,
      partyMode: partyMode,
    );
    return true;
  }

  List<RoomSummary> recommend({String? country}) {
    final filtered = country == null
        ? rooms
        : rooms.where((room) => room.country == country).toList();
    final sorted = List<RoomSummary>.from(filtered)
      ..sort((a, b) => b.online.compareTo(a.online));
    return sorted;
  }

  List<RoomSummary> newRooms({
    Duration maxAge = const Duration(days: 15),
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final values = rooms
        .where((room) => room.createdWithin(maxAge, now: reference))
        .toList()
      ..sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(
          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    return values;
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
