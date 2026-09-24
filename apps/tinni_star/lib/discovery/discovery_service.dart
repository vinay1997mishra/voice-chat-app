import 'dart:convert';
import 'dart:io';

class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.title,
    required this.country,
    required this.online,
    this.countryName,
    this.flagEmoji,
    this.locked = false,
    this.activity = false,
    this.seatCount = 12,
    this.partyMode = 'Friends-making Party',
    this.createdAt,
    this.ownerId,
    this.photoPath,
  });

  final String id;
  final String title;
  final String country;
  final String? countryName;
  final String? flagEmoji;
  final int online;
  final bool locked;
  final bool activity;
  final int seatCount;
  final String partyMode;
  final DateTime? createdAt;
  final String? ownerId;
  final String? photoPath;

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
    String? countryName,
    String? flagEmoji,
    int? online,
    bool? locked,
    bool? activity,
    int? seatCount,
    String? partyMode,
    DateTime? createdAt,
    String? ownerId,
    String? photoPath,
  }) =>
      RoomSummary(
        id: id,
        title: title ?? this.title,
        country: country ?? this.country,
        countryName: countryName ?? this.countryName,
        flagEmoji: flagEmoji ?? this.flagEmoji,
        online: online ?? this.online,
        locked: locked ?? this.locked,
        activity: activity ?? this.activity,
        seatCount: seatCount ?? this.seatCount,
        partyMode: partyMode ?? this.partyMode,
        createdAt: createdAt ?? this.createdAt,
        ownerId: ownerId ?? this.ownerId,
        photoPath: photoPath ?? this.photoPath,
      );
}

class DiscoveryService {
  DiscoveryService({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  final List<RoomSummary> rooms = <RoomSummary>[];
  final List<String> searchHistory = <String>[];
  final List<String> recentRoomIds = <String>[];
  final Set<String> favorites = <String>{};
  final Set<String> followingRoomIds = <String>{};

  Future<void> syncRooms(String authToken) async {
    if (authToken.trim().isEmpty) {
      rooms.clear();
      return;
    }

    final request = await _httpClient.getUrl(apiBase.replace(path: '/rooms'));
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load rooms');
    }

    final rawRooms = data['rooms'];
    final parsed = rawRooms is List
        ? rawRooms
            .whereType<Map>()
            .map((row) => _roomFromServer(row))
            .whereType<RoomSummary>()
            .toList()
        : <RoomSummary>[];

    rooms
      ..clear()
      ..addAll(parsed);

    recentRoomIds.removeWhere((id) => !rooms.any((room) => room.id == id));
    favorites.removeWhere((id) => !rooms.any((room) => room.id == id));
    followingRoomIds.removeWhere((id) => !rooms.any((room) => room.id == id));
  }

  Future<RoomSummary> createRoomRemote({
    required String authToken,
    required String title,
    required int seatCount,
    required String partyMode,
    bool locked = false,
  }) async {
    if (authToken.trim().isEmpty) {
      throw StateError('Login session is required');
    }

    final request = await _httpClient.postUrl(apiBase.replace(path: '/rooms'));
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, dynamic>{
        'title': title.trim(),
        'seat_count': seatCount,
        'party_mode': partyMode,
        'locked': locked,
      }),
    );

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to create room');
    }

    final room = _roomFromServer(_asMap(data['room']));
    if (room == null) throw StateError('Server returned invalid room');

    rooms.removeWhere((item) => item.id == room.id);
    rooms.insert(0, room);
    return room;
  }

  RoomSummary? _roomFromServer(Map<dynamic, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final title = row['title']?.toString() ?? '';
    if (id.isEmpty || title.isEmpty) return null;

    final createdAtMs = _asInt(row['created_at']);
    return RoomSummary(
      id: id,
      title: title,
      country: row['country_code']?.toString() ?? '',
      countryName: row['country_name']?.toString(),
      flagEmoji: row['flag_emoji']?.toString(),
      online: _asInt(row['online']),
      locked: row['locked'] == true,
      seatCount: _asInt(row['seat_count'], fallback: 12),
      partyMode:
          row['party_mode']?.toString() ?? 'Friends-making Party',
      createdAt: createdAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : null,
      ownerId: row['owner_id']?.toString(),
    );
  }

  List<RoomSummary> recommend({String? country}) {
    final filtered = country == null
        ? rooms
        : rooms.where((room) => room.country == country).toList();
    final sorted = List<RoomSummary>.from(filtered)
      ..sort((a, b) {
        final onlineOrder = b.online.compareTo(a.online);
        if (onlineOrder != 0) return onlineOrder;
        return (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
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
    if (favorites.add(roomId)) {
      followingRoomIds.add(roomId);
    } else {
      favorites.remove(roomId);
      followingRoomIds.remove(roomId);
    }
  }

  List<RoomSummary> ownedRooms(String ownerId) =>
      rooms.where((room) => room.ownerId == ownerId).toList();

  List<RoomSummary> followedRooms() {
    final byId = <String, RoomSummary>{
      for (final room in rooms) room.id: room,
    };
    return followingRoomIds
        .map((id) => byId[id])
        .whereType<RoomSummary>()
        .toList();
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

  void clearHistory() => searchHistory.clear();
  void clearRecent() => recentRoomIds.clear();

  Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
    final body = await utf8.decoder.bind(response).join();
    if (body.trim().isEmpty) return <String, dynamic>{};
    return _asMap(jsonDecode(body));
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void dispose() => _httpClient.close(force: true);
}
