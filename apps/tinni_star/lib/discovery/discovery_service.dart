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
    this.photoDataUrl,
    this.ownerName,
    this.ownerAvatarDataUrl,
    this.ownerFlagEmoji,
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
  final String? photoDataUrl;
  final String? ownerName;
  final String? ownerAvatarDataUrl;
  final String? ownerFlagEmoji;

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
    String? photoDataUrl,
    String? ownerName,
    String? ownerAvatarDataUrl,
    String? ownerFlagEmoji,
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
        photoDataUrl: photoDataUrl ?? this.photoDataUrl,
        ownerName: ownerName ?? this.ownerName,
        ownerAvatarDataUrl:
            ownerAvatarDataUrl ?? this.ownerAvatarDataUrl,
        ownerFlagEmoji: ownerFlagEmoji ?? this.ownerFlagEmoji,
      );
}

class RoomThemeRecord {
  const RoomThemeRecord({
    required this.id,
    required this.name,
    required this.asset,
    required this.source,
    required this.priceCoins,
    required this.createdAt,
    this.expiresAt,
    this.roomId,
  });

  final String id;
  final String name;
  final String asset;
  final String source;
  final int priceCoins;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? roomId;

  bool get isPanelTheme => source == 'panel';
  bool get isUserTheme => source == 'user';
}

class RoomThemeCatalog {
  const RoomThemeCatalog({
    required this.userPriceCoins,
    required this.userDurationDays,
    required this.themes,
  });

  final int userPriceCoins;
  final int userDurationDays;
  final List<RoomThemeRecord> themes;
}

class RoomAccessResult {
  const RoomAccessResult({
    required this.allowed,
    required this.blocked,
    required this.attemptsRemaining,
    this.error,
  });

  final bool allowed;
  final bool blocked;
  final int attemptsRemaining;
  final String? error;
}

class DiscoveryService {
  DiscoveryService({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinnistar-api.tinnistarchat.workers.dev'),
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
    String? photoDataUrl,
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
        'photo_data_url': photoDataUrl,
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

  Future<RoomSummary> setRoomLock({
    required String authToken,
    required String roomId,
    required bool locked,
    String? password,
  }) async {
    if (authToken.trim().isEmpty) {
      throw StateError('Login session is required');
    }

    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/rooms/lock'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, dynamic>{
        'room_id': roomId,
        'locked': locked,
        'password': locked ? password : null,
      }),
    );

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to change room lock',
      );
    }

    final room = _roomFromServer(_asMap(data['room']));
    if (room == null) {
      throw StateError('Server returned invalid room');
    }

    final index = rooms.indexWhere((item) => item.id == room.id);
    if (index >= 0) {
      rooms[index] = room;
    } else {
      rooms.insert(0, room);
    }
    return room;
  }

  Future<RoomThemeCatalog> fetchRoomThemes({
    required String authToken,
    required String roomId,
  }) async {
    if (authToken.trim().isEmpty) {
      throw StateError('Login session is required');
    }

    final request = await _httpClient.getUrl(
      apiBase.replace(
        path: '/room-themes',
        queryParameters: <String, String>{'room_id': roomId},
      ),
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to load room themes',
      );
    }

    final rawThemes = data['themes'];
    final themes = rawThemes is List
        ? rawThemes
            .whereType<Map>()
            .map(_roomThemeFromServer)
            .whereType<RoomThemeRecord>()
            .toList()
        : <RoomThemeRecord>[];

    return RoomThemeCatalog(
      userPriceCoins: _asInt(
        data['user_price_coins'],
        fallback: 10000000,
      ),
      userDurationDays: _asInt(
        data['user_duration_days'],
        fallback: 7,
      ),
      themes: List<RoomThemeRecord>.unmodifiable(themes),
    );
  }

  Future<RoomThemeRecord> createRoomTheme({
    required String authToken,
    required String roomId,
    required String name,
    required String asset,
    required bool policyConfirmed,
  }) async {
    if (authToken.trim().isEmpty) {
      throw StateError('Login session is required');
    }

    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/room-themes'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, dynamic>{
        'room_id': roomId,
        'name': name.trim(),
        'asset': asset,
        'policy_confirmed': policyConfirmed,
      }),
    );

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to add room theme',
      );
    }

    final theme = _roomThemeFromServer(_asMap(data['theme']));
    if (theme == null) {
      throw StateError('Server returned invalid room theme');
    }
    return theme;
  }

    Future<RoomAccessResult> getRoomAccessStatus({
    required String authToken,
    required String roomId,
  }) async {
    if (authToken.trim().isEmpty) {
      throw StateError('Login session is required');
    }

    final request = await _httpClient.getUrl(
      apiBase.replace(
        path: '/rooms/access',
        queryParameters: <String, String>{'room_id': roomId},
      ),
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode >= 500) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to check room access',
      );
    }

    return RoomAccessResult(
      allowed: data['allowed'] == true,
      blocked: data['blocked'] == true,
      attemptsRemaining: _asInt(data['attempts_remaining']),
      error: data['error']?.toString(),
    );
  }

    Future<RoomAccessResult> verifyRoomPassword({
    required String authToken,
    required String roomId,
    required String password,
  }) async {
    if (authToken.trim().isEmpty) {
      throw StateError('Login session is required');
    }

    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/rooms/access'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, dynamic>{
        'room_id': roomId,
        'password': password,
      }),
    );

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode >= 500) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to verify room password',
      );
    }

    return RoomAccessResult(
      allowed: data['allowed'] == true,
      blocked: data['blocked'] == true,
      attemptsRemaining: _asInt(data['attempts_remaining']),
      error: data['error']?.toString(),
    );
  }

  RoomThemeRecord? _roomThemeFromServer(Map<dynamic, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final name = row['name']?.toString() ?? '';
    final asset = row['asset']?.toString() ?? '';
    if (id.isEmpty || name.isEmpty || asset.isEmpty) return null;

    final createdAtMs = _asInt(row['created_at']);
    final expiresAtMs = row['expires_at'] == null
        ? 0
        : _asInt(row['expires_at']);

    return RoomThemeRecord(
      id: id,
      name: name,
      asset: asset,
      source: row['source']?.toString() ?? 'user',
      priceCoins: _asInt(row['price_coins']),
      roomId: row['room_id']?.toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtMs > 0 ? createdAtMs : DateTime.now().millisecondsSinceEpoch,
      ),
      expiresAt: expiresAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
          : null,
    );
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
      photoDataUrl: row['photo_data_url']?.toString(),
      ownerName: row['owner_name']?.toString(),
      ownerAvatarDataUrl: row['owner_avatar_data_url']?.toString(),
      ownerFlagEmoji: row['owner_flag_emoji']?.toString(),
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
