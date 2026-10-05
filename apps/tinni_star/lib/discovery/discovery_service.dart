import 'dart:convert';
import 'dart:io';

import '../infra/backend_http.dart';

class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.title,
    this.publicId,
    required this.country,
    required this.online,
    this.countryName,
    this.flagEmoji,
    this.locked = false,
    this.closed = false,
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
    this.themeId = 'royal-dark',
    this.themeAsset,
    this.seatThemeId = 'royal-gold',
    this.announcement = '',
    this.roomLevel = 1,
    this.roomExperience = 0,
    this.activeUserExp = 0,
    this.sendingExp = 0,
    this.receivingExp = 0,
    this.rocketLaunchLevel = 0,
    this.rocketLaunchedAt = 0,
    this.rocketPriorityUntil = 0,
  });

  final String id;
  final String title;
  final String? publicId;

  String get displayId =>
      publicId == null || publicId!.isEmpty ? id : publicId!;
  final String country;
  final String? countryName;
  final String? flagEmoji;
  final int online;
  final bool locked;
  final bool closed;
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
  final String themeId;
  final String? themeAsset;
  final String seatThemeId;
  final String announcement;
  final int roomLevel;
  final int roomExperience;
  final int activeUserExp;
  final int sendingExp;
  final int receivingExp;
  final int rocketLaunchLevel, rocketLaunchedAt, rocketPriorityUntil;

  int rocketPriorityAt(DateTime now) => rocketPriorityUntil > now.millisecondsSinceEpoch ? rocketLaunchLevel : 0;

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
    String? publicId,
    String? country,
    String? countryName,
    String? flagEmoji,
    int? online,
    bool? locked,
    bool? closed,
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
    String? themeId,
    String? themeAsset,
    String? seatThemeId,
    String? announcement,
    int? roomLevel,
    int? roomExperience,
    int? activeUserExp,
    int? sendingExp,
    int? receivingExp,
    int? rocketLaunchLevel,
    int? rocketLaunchedAt,
    int? rocketPriorityUntil,
  }) =>
      RoomSummary(
        id: id,
        title: title ?? this.title,
        publicId: publicId ?? this.publicId,
        country: country ?? this.country,
        countryName: countryName ?? this.countryName,
        flagEmoji: flagEmoji ?? this.flagEmoji,
        online: online ?? this.online,
        locked: locked ?? this.locked,
        closed: closed ?? this.closed,
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
        themeId: themeId ?? this.themeId,
        themeAsset: themeAsset ?? this.themeAsset,
        seatThemeId: seatThemeId ?? this.seatThemeId,
        announcement: announcement ?? this.announcement,
        roomLevel: roomLevel ?? this.roomLevel,
        roomExperience: roomExperience ?? this.roomExperience,
        activeUserExp: activeUserExp ?? this.activeUserExp,
        sendingExp: sendingExp ?? this.sendingExp,
        receivingExp: receivingExp ?? this.receivingExp,
        rocketLaunchLevel: rocketLaunchLevel ?? this.rocketLaunchLevel,
        rocketLaunchedAt: rocketLaunchedAt ?? this.rocketLaunchedAt,
        rocketPriorityUntil: rocketPriorityUntil ?? this.rocketPriorityUntil,
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
    this.roomPassword,
  });

  final bool allowed;
  final bool blocked;
  final int attemptsRemaining;
  final String? error;
  final String? roomPassword;
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
  String? lastGeneratedRoomPassword;

  final List<RoomSummary> rooms = <RoomSummary>[];
  final List<String> searchHistory = <String>[];
  final List<String> recentRoomIds = <String>[];
  final Set<String> favorites = <String>{};
  final Set<String> followingRoomIds = <String>{};

  bool applyRocketPriority(Map<String, dynamic> priority) {
    final id = priority['room_id']?.toString() ?? '';
    final index = rooms.indexWhere((room) => room.id == id);
    if (index < 0) return false;
    final incoming = (priority['launched_at'] as num?)?.toInt() ?? 0;
    final current = rooms[index];
    if (incoming < current.rocketLaunchedAt) return true;
    rooms[index] = current.copyWith(
      rocketLaunchLevel: (priority['level'] as num?)?.toInt() ?? 0,
      rocketLaunchedAt: incoming,
      rocketPriorityUntil: (priority['expires_at'] as num?)?.toInt() ?? 0,
    );
    return true;
  }

  Future<void> syncRooms(String authToken) async {
    if (authToken.trim().isEmpty) {
      rooms.clear();
      return;
    }

    final request = await openBackendRequest(_httpClient, 'GET', apiBase.replace(path: '/rooms'));
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');

    final response = await closeBackendRequest(request);
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

    final storedPhoto = await _storeRoomPhotoIfNeeded(
      authToken,
      photoDataUrl,
    );

    final request = await openBackendRequest(_httpClient, 'POST', apiBase.replace(path: '/rooms'));
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
        'photo_data_url': storedPhoto,
      }),
    );

    final response = await closeBackendRequest(request);
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

  Future<RoomSummary> updateRoomRemote({
    required String authToken,
    required String roomId,
    String? title,
    String? announcement,
    String? category,
    String? countryCode,
    String? countryName,
    String? flagEmoji,
    int? seatCount,
    String? partyMode,
    String? privacy,
    bool? closed,
    String? photoDataUrl,
    String? seatThemeId,
  }) async {
    if (authToken.trim().isEmpty) throw StateError('Login session is required');
    final storedPhoto = photoDataUrl == null
        ? null
        : await _storeRoomPhotoIfNeeded(authToken, photoDataUrl);
    final request = await openBackendRequest(_httpClient, 'PATCH', apiBase.replace(path: '/rooms/settings'));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    final body = <String, dynamic>{'room_id': roomId};
    if (title != null) body['title'] = title;
    if (announcement != null) body['announcement'] = announcement;
    if (category != null) body['category'] = category;
    if (countryCode != null) body['country_code'] = countryCode;
    if (countryName != null) body['country_name'] = countryName;
    if (flagEmoji != null) body['flag_emoji'] = flagEmoji;
    if (seatCount != null) body['seat_count'] = seatCount;
    if (partyMode != null) body['party_mode'] = partyMode;
    if (privacy != null) body['privacy'] = privacy;
    if (closed != null) body['closed'] = closed;
    if (storedPhoto != null) body['photo_data_url'] = storedPhoto;
    if (seatThemeId != null) body['seat_theme_id'] = seatThemeId;
    request.write(jsonEncode(body));
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) throw StateError(data['error']?.toString() ?? 'Unable to update room');
    final room = _roomFromServer(_asMap(data['room']));
    if (room == null) throw StateError('Server returned invalid room');
    final index = rooms.indexWhere((item) => item.id == room.id);
    if (index >= 0) {
      rooms[index] = room;
    } else {
      rooms.insert(0, room);
    }
    return room;
  }

  Future<void> setRoomInvite({
    required String authToken,
    required String roomId,
    required String targetUserId,
    required bool invited,
  }) async {
    if (authToken.trim().isEmpty) throw StateError('Login session is required');
    final request = await openBackendRequest(_httpClient, 'POST', apiBase.replace(path: '/rooms/invite'));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    request.write(jsonEncode(<String, dynamic>{'room_id': roomId, 'target_user_id': targetUserId, 'invited': invited}));
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) throw StateError(data['error']?.toString() ?? 'Unable to update room invite');
  }

  Future<RoomSummary> setRoomSeatCount({
    required String authToken,
    required String roomId,
    required int seatCount,
  }) async {
    if (authToken.trim().isEmpty) throw StateError('Login session is required');
    final request = await openBackendRequest(_httpClient, 'PATCH', 
      apiBase.replace(path: '/rooms/seat-count'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    request.write(jsonEncode(<String, dynamic>{
      'room_id': roomId,
      'seat_count': seatCount,
    }));
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to change room seats');
    }
    final room = _roomFromServer(_asMap(data['room']));
    if (room == null) throw StateError('Server returned invalid room');
    final index = rooms.indexWhere((item) => item.id == room.id);
    if (index >= 0) {
      rooms[index] = room;
    } else {
      rooms.insert(0, room);
    }
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

    final request = await openBackendRequest(_httpClient, 'POST', 
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
      }),
    );

    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    lastGeneratedRoomPassword = locked
        ? data['room_password']?.toString()
        : null;
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

  Future<RoomSummary> setRoomTheme({
    required String authToken,
    required String roomId,
    required String themeId,
    String? themeAsset,
  }) async {
    if (authToken.trim().isEmpty) {
      throw StateError('Login session is required');
    }

    final request = await openBackendRequest(_httpClient, 'POST', 
      apiBase.replace(path: '/rooms/theme'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, dynamic>{
        'room_id': roomId,
        'theme_id': themeId,
        'theme_asset': themeAsset,
      }),
    );

    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to change room theme',
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

    final request = await openBackendRequest(_httpClient, 'GET', 
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

    final response = await closeBackendRequest(request);
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
    int durationDays = 7,
    bool permanent = false,
  }) async {
    if (authToken.trim().isEmpty) {
      throw StateError('Login session is required');
    }

    final storedAsset = await _storeRoomThemePhotoIfNeeded(
      authToken,
      asset,
    );

    final request = await openBackendRequest(_httpClient, 'POST', 
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
        'asset': storedAsset,
        'policy_confirmed': policyConfirmed,
        'duration_days': durationDays,
        'permanent': permanent,
      }),
    );

    final response = await closeBackendRequest(request);
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

  Future<String> _storeRoomThemePhotoIfNeeded(
    String authToken,
    String value,
  ) async {
    final source = value.trim();
    if (source.isEmpty) {
      throw StateError('Room background image is required');
    }
    if (!source.startsWith('data:image/')) {
      return source;
    }

    final request = await openBackendRequest(_httpClient, 'POST', 
      apiBase.replace(path: '/room-theme-media'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(jsonEncode(<String, dynamic>{'data_url': source}));
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ??
            'Room background failed safety checks',
      );
    }
    final url = data['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw StateError('Server did not return approved room background URL');
    }
    return url;
  }

  Future<String?> _storeRoomPhotoIfNeeded(
    String authToken,
    String? value,
  ) async {
    final source = value?.trim();
    if (source == null || source.isEmpty || !source.startsWith('data:image/')) {
      return source;
    }

    final request = await openBackendRequest(_httpClient, 'POST', 
      apiBase.replace(path: '/room-media'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(jsonEncode(<String, dynamic>{'data_url': source}));
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to upload room photo',
      );
    }
    final url = data['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw StateError('Server did not return room photo URL');
    }
    return url;
  }

    Future<RoomAccessResult> getRoomAccessStatus({
    required String authToken,
    required String roomId,
  }) async {
    if (authToken.trim().isEmpty) {
      throw StateError('Login session is required');
    }

    final request = await openBackendRequest(_httpClient, 'GET', 
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

    final response = await closeBackendRequest(request);
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
      roomPassword: data['room_password']?.toString(),
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

    final request = await openBackendRequest(_httpClient, 'POST', 
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

    final response = await closeBackendRequest(request);
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
      publicId: row['public_id']?.toString(),
      country: row['country_code']?.toString() ?? '',
      countryName: row['country_name']?.toString(),
      flagEmoji: row['flag_emoji']?.toString(),
      online: _asInt(row['online'], fallback: _asInt(row['member_count'])),
      locked: row['locked'] == true,
      closed: row['closed'] == true,
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
      themeId: row['theme_id']?.toString() ?? 'royal-dark',
      themeAsset: row['theme_asset']?.toString(),
      seatThemeId: row['seat_theme_id']?.toString() ?? 'royal-gold',
      announcement: row['announcement']?.toString() ?? '',
      roomLevel: _asInt(row['room_level'], fallback: 1),
      roomExperience: _asInt(row['room_experience']),
      activeUserExp: _asInt(row['active_user_exp']),
      sendingExp: _asInt(row['sending_exp']),
      receivingExp: _asInt(row['receiving_exp']),
      rocketLaunchLevel: _asInt(row['rocket_launch_level']),
      rocketLaunchedAt: _asInt(row['rocket_launched_at']),
      rocketPriorityUntil: _asInt(row['rocket_priority_until']),
    );
  }

  List<RoomSummary> recommend({String? country, DateTime? now}) {
    final reference = now ?? DateTime.now();
    // Party must only show active, unlocked rooms. Empty rooms stay available
    // to Mine/Recent/Search but are hidden from the public Party feed.
    final visibleRooms =
        rooms.where((room) => !room.locked && room.online > 0).toList();
    final filtered = country == null
        ? visibleRooms
        : visibleRooms.where((room) => room.country == country).toList();
    final sorted = List<RoomSummary>.from(filtered)
      ..sort((a, b) {
        final aRocket = a.rocketPriorityAt(reference), bRocket = b.rocketPriorityAt(reference);
        final rocketOrder = bRocket.compareTo(aRocket);
        if (rocketOrder != 0) return rocketOrder;
        if (aRocket > 0 && bRocket > 0) {
          final launchOrder = b.rocketLaunchedAt.compareTo(a.rocketLaunchedAt);
          if (launchOrder != 0) return launchOrder;
        }
        final sendingOrder = b.sendingExp.compareTo(a.sendingExp);
        if (sendingOrder != 0) return sendingOrder;
        final expOrder = b.roomExperience.compareTo(a.roomExperience);
        if (expOrder != 0) return expOrder;
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
        .where(
          (room) =>
              !room.locked &&
              room.online > 0 &&
              room.createdWithin(maxAge, now: reference),
        )
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
          (room) => room.locked
              ? room.displayId == value
              : room.displayId == value ||
                  room.id == value ||
                  room.title.toLowerCase().contains(lower),
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
    final body = await readBackendResponse(response);
    final trimmed = body.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      return <String, dynamic>{};
    } on FormatException {
      final lower = trimmed.toLowerCase();
      if (lower.contains('error code: 1101')) {
        throw StateError(
          'Tinni Star server is temporarily unavailable. Please retry.',
        );
      }
      throw StateError(
        'Tinni Star server returned an invalid response. Please retry.',
      );
    }
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

  Future<Map<String, dynamic>> roomFollow({
    required String authToken,
    required String roomId,
  }) async {
    final request = await openBackendRequest(_httpClient, 'GET', apiBase.replace(
      path: '/rooms/follow',
      queryParameters: <String, String>{'room_id': roomId},
    ));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load room follow');
    }
    return data;
  }

  Future<Map<String, dynamic>> setRoomFollow({
    required String authToken,
    required String roomId,
    required bool following,
  }) async {
    final request = await openBackendRequest(_httpClient, 'POST', apiBase.replace(path: '/rooms/follow'));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    request.write(jsonEncode(<String, dynamic>{'room_id': roomId, 'following': following}));
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to update room follow');
    }
    return data;
  }

  Future<Map<String, dynamic>> roomMembership({
    required String authToken,
    required String roomId,
  }) async {
    final request = await openBackendRequest(_httpClient, 'GET', apiBase.replace(
      path: '/rooms/membership',
      queryParameters: <String, String>{'room_id': roomId},
    ));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load membership');
    }
    return data;
  }

  Future<Map<String, dynamic>> setRoomMembership({
    required String authToken,
    required String roomId,
    required bool member,
  }) async {
    final request = await openBackendRequest(_httpClient, 'POST', apiBase.replace(path: '/rooms/membership'));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    request.write(jsonEncode(<String, dynamic>{'room_id': roomId, 'member': member}));
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to update membership');
    }
    return data;
  }

  Future<Map<String, dynamic>> roomGiftRanking({
    required String authToken,
    required String roomId,
    required String period,
  }) async {
    final request = await openBackendRequest(_httpClient, 'GET', apiBase.replace(
      path: '/gifts/ranking',
      queryParameters: <String, String>{'room_id': roomId, 'period': period},
    ));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load sending ranking');
    }
    return data;
  }

  Future<Map<String, dynamic>> personalRocketReward({
    required String authToken,
    required String roomId,
    required int level,
  }) async {
    final request = await openBackendRequest(_httpClient, 'GET', apiBase.replace(
      path: '/gifts/rocket-reward',
      queryParameters: <String, String>{'room_id': roomId, 'level': '$level'},
    ));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load your Rocket reward');
    }
    return data;
  }

  Future<Map<String, dynamic>> luckyPouch({
    required String authToken,
    required String roomId,
  }) async {
    final request = await openBackendRequest(_httpClient, 'GET', apiBase.replace(
      path: '/lucky-pouch',
      queryParameters: <String, String>{'room_id': roomId},
    ));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load Lucky Pouch');
    }
    return data;
  }

  Future<Map<String, dynamic>> openLuckyPouch({
    required String authToken,
    required String roomId,
    required int users,
    required int coins,
  }) async {
    final request = await openBackendRequest(_httpClient, 'POST', apiBase.replace(path: '/lucky-pouch/open'));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    request.write(jsonEncode(<String, dynamic>{'room_id': roomId, 'users': users, 'coins': coins}));
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to open Lucky Pouch');
    }
    return data;
  }

  Future<Map<String, dynamic>> claimLuckyPouch({
    required String authToken,
    required String roomId,
  }) async {
    final request = await openBackendRequest(_httpClient, 'POST', apiBase.replace(path: '/lucky-pouch/claim'));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    request.write(jsonEncode(<String, dynamic>{'room_id': roomId}));
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to claim Lucky Pouch');
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> countryRibbons(String authToken) async {
    final request = await openBackendRequest(_httpClient, 'GET', apiBase.replace(path: '/ribbons'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final raw = data['ribbons'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((row) => row.map((k, v) => MapEntry(k.toString(), v))).toList();
  }

  void dispose() => _httpClient.close(force: true);
}
