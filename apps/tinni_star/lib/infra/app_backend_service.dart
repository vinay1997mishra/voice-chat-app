import 'dart:convert';
import 'dart:io';

class RemoteRoleWallet {
  const RemoteRoleWallet({
    required this.balance,
    required this.banned,
    required this.securityFrozen,
    required this.freezeReason,
  });

  final int balance;
  final bool banned;
  final bool securityFrozen;
  final String freezeReason;
}

class RemoteWallet {
  const RemoteWallet({
    required this.coins,
    required this.diamonds,
    required this.banned,
    required this.updatedAt,
    this.diamondWalletVisible = false,
    this.isHost = false,
    this.isAgency = false,
    this.isBd = false,
    this.diamondUsdCents = 0,
    this.commissionUsdCents = 0,
    this.withdrawableUsdCents = 0,
    this.canTransferSettlement = false,
    this.securityFrozen = false,
    this.freezeReason = '',
    this.coinSellerWallet,
    this.merchantWallet,
  });

  final int coins;
  final int diamonds;
  final bool banned;
  final int updatedAt;
  final bool diamondWalletVisible;
  final bool isHost;
  final bool isAgency;
  final bool isBd;
  final int diamondUsdCents;
  final int commissionUsdCents;
  final int withdrawableUsdCents;
  final bool canTransferSettlement;
  final bool securityFrozen;
  final String freezeReason;
  final RemoteRoleWallet? coinSellerWallet;
  final RemoteRoleWallet? merchantWallet;
}

class RemoteNotification {
  const RemoteNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.read,
    this.sourceUserId,
    this.metadata = const <String, dynamic>{},
  });
  final String id;
  final String type;
  final String title;
  final String message;
  final int createdAt;
  final bool read;
  final String? sourceUserId;
  final Map<String, dynamic> metadata;
}

class SettlementRecipient {
  const SettlementRecipient({
    required this.userId,
    required this.displayName,
    required this.role,
    this.avatarDataUrl,
  });
  final String userId;
  final String displayName;
  final String role;
  final String? avatarDataUrl;
}

class RemoteCp {
  const RemoteCp({required this.userA, required this.userB, required this.state, required this.intimacy, required this.level, required this.requestedBy, required this.createdAt, this.ringId});
  final String userA;
  final String userB;
  final String state;
  final int intimacy;
  final int level;
  final String requestedBy;
  final int createdAt;
  final String? ringId;
}

class VipCatalogItem {
  const VipCatalogItem({required this.id, required this.name, required this.level, required this.enabled, required this.data});
  final String id;
  final String name;
  final int level;
  final bool enabled;
  final Map<String, dynamic> data;
  int get price => _asInt(data['price']);
  String get entry => data['entry']?.toString() ?? '';
  String get frame => data['frame']?.toString() ?? '';
  List<String> get privileges => _asStringList(data['privileges']);
}

class AppBackendService {
  AppBackendService({Uri? apiBase, HttpClient? httpClient})
      : apiBase = apiBase ?? Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  Future<List<RemoteNotification>> notifications(String token) async {
    final data = await _request('GET', '/notifications', token);
    final raw = data['notifications'];
    if (raw is! List) return const <RemoteNotification>[];
    return raw.whereType<Map>().map((item) {
      final row = _map(item);
      return RemoteNotification(
        id: row['id']?.toString() ?? '',
        type: row['type']?.toString() ?? 'general',
        title: row['title']?.toString() ?? 'Tinni Star',
        message: row['message']?.toString() ?? '',
        createdAt: _asInt(row['created_at']),
        read: row['read'] == true,
        sourceUserId: row['source_user_id']?.toString(),
        metadata: _map(row['metadata']),
      );
    }).where((item) => item.id.isNotEmpty).toList(growable: false);
  }

  Future<void> markNotificationRead(String token, String notificationId) async {
    await _request(
      'POST',
      '/notifications/read',
      token,
      body: {'notification_id': notificationId},
    );
  }

  Future<Map<String, dynamic>> roomGameAction(
    String token, {
    required String roomId,
    required String gameKey,
    required String action,
  }) {
    return _request(
      'POST',
      '/room-games/action',
      token,
      body: {
        'room_id': roomId,
        'game_key': gameKey,
        'action': action,
      },
    );
  }

  Future<Map<String, dynamic>> ludoState(
    String token, {
    required String roomId,
  }) async {
    if (token.trim().isEmpty) throw StateError('Login session is required');
    final uri = apiBase.replace(
      path: '/ludo/state',
      queryParameters: {'room_id': roomId},
    );
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    final data = text.trim().isEmpty
        ? <String, dynamic>{}
        : _map(jsonDecode(text));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load Ludo');
    }
    return data;
  }

  Future<Map<String, dynamic>> ludoRoll(
    String token, {
    required String roomId,
  }) {
    return _request(
      'POST',
      '/ludo/roll',
      token,
      body: {'room_id': roomId},
    );
  }

  Future<Map<String, dynamic>> ludoMove(
    String token, {
    required String roomId,
    required int tokenIndex,
  }) {
    return _request(
      'POST',
      '/ludo/move',
      token,
      body: {'room_id': roomId, 'token_index': tokenIndex},
    );
  }

  Future<Map<String, dynamic>> ludoReset(
    String token, {
    required String roomId,
  }) {
    return _request(
      'POST',
      '/ludo/reset',
      token,
      body: {'room_id': roomId},
    );
  }

  Future<Map<String, dynamic>?> searchUserById(
    String token,
    String userId,
  ) async {
    final id = userId.trim();
    if (id.isEmpty) return null;
    if (token.trim().isEmpty) {
      throw StateError('Login session is required');
    }
    final uri = apiBase.replace(
      path: '/users/exact-id',
      queryParameters: <String, String>{'id': id},
    );
    final request = await _httpClient.getUrl(uri);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $token',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    Map<String, dynamic> data = <String, dynamic>{};
    if (text.trim().isNotEmpty) {
      try {
        data = _map(jsonDecode(text));
      } on FormatException {
        throw StateError(
          'Tinni Star server returned an invalid user search response.',
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to search user',
      );
    }
    final row = _map(data['user']);
    return row.isEmpty ? null : row;
  }

  Future<List<Map<String, dynamic>>> blockedProfiles(String token) async {
    final data = await _request('GET', '/social/blocked/details', token);
    final raw = data['blocked'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> startEmailAccountLink(
    String token, {
    required String email,
  }) async {
    return _request(
      'POST',
      '/account/link/email/start',
      token,
      body: <String, dynamic>{'email': email.trim()},
    );
  }

  Future<List<Map<String, dynamic>>> verifyEmailAccountLink(
    String token, {
    required String requestId,
    required String otp,
    required String password,
  }) async {
    final data = await _request(
      'POST',
      '/account/link/email/verify',
      token,
      body: <String, dynamic>{
        'request_id': requestId,
        'otp': otp.trim(),
        'password': password,
      },
    );
    final raw = data['identities'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map(_map).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> linkGoogleAccount(
    String token, {
    required String idToken,
  }) async {
    final data = await _request(
      'POST',
      '/account/link/google',
      token,
      body: <String, dynamic>{'id_token': idToken},
    );
    final raw = data['identities'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map(_map).toList(growable: false);
  }

  Future<void> logout(String token) async {
    await _request('POST', '/app/logout', token, body: const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> userTagsAndMedals(
    String token,
    String userId,
  ) async {
    if (token.trim().isEmpty) throw StateError('Login session is required');
    final uri = apiBase.replace(
      path: '/app-user/tags',
      queryParameters: <String, String>{'user_id': userId},
    );
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    final data = text.trim().isEmpty
        ? <String, dynamic>{}
        : _map(jsonDecode(text));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load medals');
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> tasks(String token) async {
    final data = await _request('GET', '/tasks', token);
    final raw = data['tasks'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> claimTask(
    String token,
    String taskId,
  ) async {
    return _request(
      'POST',
      '/tasks/claim',
      token,
      body: <String, dynamic>{'task_id': taskId},
    );
  }

  Future<Map<String, dynamic>> familyState(String token) async {
    return _request('GET', '/family', token);
  }

  Future<List<Map<String, dynamic>>> familyList(
    String token, {
    int limit = 100,
  }) async {
    final base = apiBase.replace(path: '/family/list');
    final uri = base.replace(
      queryParameters: <String, String>{'limit': limit.toString()},
    );
    if (token.trim().isEmpty) throw StateError('Login session is required');
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    Map<String, dynamic> data = <String, dynamic>{};
    if (text.trim().isNotEmpty) {
      try {
        data = _map(jsonDecode(text));
      } on FormatException {
        final responseBody = text.trim();
        if (responseBody.contains('error code: 1101')) {
          throw StateError(
            'Tinni Star server is temporarily unavailable (1101). Please pull to retry.',
          );
        }
        throw StateError(
          'Tinni Star server returned an invalid Family response.',
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load Families');
    }
    final raw = data['families'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> createFamily(
    String token, {
    required String name,
    required String tag,
  }) async {
    return _request(
      'POST',
      '/family/create',
      token,
      body: <String, dynamic>{'name': name.trim(), 'tag': tag.trim()},
    );
  }

  Future<void> requestFamilyJoin(
    String token, {
    required String familyId,
  }) async {
    await _request(
      'POST',
      '/family/join-request',
      token,
      body: <String, dynamic>{'family_id': familyId},
    );
  }

  Future<void> resolveFamilyJoin(
    String token, {
    required String userId,
    required bool approve,
  }) async {
    await _request(
      'POST',
      '/family/join-request/resolve',
      token,
      body: <String, dynamic>{'user_id': userId, 'approve': approve},
    );
  }

  Future<void> setFamilyAdmin(
    String token, {
    required String userId,
    required bool admin,
  }) async {
    await _request(
      'POST',
      '/family/admin',
      token,
      body: <String, dynamic>{'user_id': userId, 'admin': admin},
    );
  }

  Future<void> removeFamilyMember(
    String token, {
    required String userId,
  }) async {
    await _request(
      'POST',
      '/family/member/remove',
      token,
      body: <String, dynamic>{'user_id': userId},
    );
  }

  Future<void> leaveFamily(String token) async {
    await _request(
      'POST',
      '/family/leave',
      token,
      body: const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> familyCheckIn(String token) async {
    return _request(
      'POST',
      '/family/check-in',
      token,
      body: const <String, dynamic>{},
    );
  }

  Future<void> updateFamilyNotice(
    String token, {
    required String notice,
  }) async {
    await _request(
      'POST',
      '/family/notice',
      token,
      body: <String, dynamic>{'notice': notice},
    );
  }

  Future<Map<String, dynamic>> sendFamilyCoins(
    String token, {
    required String receiverUserId,
    required int coins,
  }) async {
    return _request(
      'POST',
      '/family/wallet/send',
      token,
      body: <String, dynamic>{
        'receiver_user_id': receiverUserId,
        'coins': coins,
      },
    );
  }

  Future<List<Map<String, dynamic>>> familyWalletTransfers(
    String token, {
    int limit = 100,
  }) async {
    final base = apiBase.replace(path: '/family/wallet/transfers');
    final uri = base.replace(
      queryParameters: <String, String>{'limit': limit.toString()},
    );
    if (token.trim().isEmpty) throw StateError('Login session is required');
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    final data = text.trim().isEmpty
        ? <String, dynamic>{}
        : _map(jsonDecode(text));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to load Family Wallet',
      );
    }
    final raw = data['transfers'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> accountStats(String token) async {
    final data = await _request('GET', '/account/stats', token);
    return _map(data['stats']);
  }

  Future<List<Map<String, dynamic>>> settlementTransfers(String token) async {
    final data = await _request('GET', '/wallet/settlement/transfers', token);
    final raw = data['transfers'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> accountPreferences(String token) async {
    final data = await _request('GET', '/account/preferences', token);
    return _map(data['preferences']);
  }

  Future<Map<String, dynamic>> updateAccountPreferences(
    String token,
    Map<String, dynamic> values,
  ) async {
    final data = await _request(
      'POST',
      '/account/preferences',
      token,
      body: values,
    );
    return _map(data['preferences']);
  }

  Future<List<Map<String, dynamic>>> accountIdentities(String token) async {
    final data = await _request('GET', '/account/identities', token);
    final raw = data['identities'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map(_map).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> feedbackHistory(String token) async {
    final data = await _request('GET', '/feedback', token);
    final raw = data['feedback'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> submitFeedback(
    String token, {
    required String category,
    required String message,
  }) async {
    final data = await _request(
      'POST',
      '/feedback',
      token,
      body: <String, dynamic>{
        'category': category,
        'message': message,
      },
    );
    return _map(data['feedback']);
  }

  Future<RemoteWallet> wallet(String token) async {
    final data = await _request('GET', '/wallet', token);
    final row = _map(data['wallet']);
    return RemoteWallet(
      coins: _asInt(row['coins']),
      diamonds: _asInt(row['diamonds']),
      banned: row['banned'] == true,
      updatedAt: _asInt(row['updated_at']),
      diamondWalletVisible: row['diamond_wallet_visible'] == true,
      isHost: row['is_host'] == true,
      isAgency: row['is_agency'] == true,
      isBd: row['is_bd'] == true,
      diamondUsdCents: _asInt(row['diamond_usd_cents']),
      commissionUsdCents: _asInt(row['commission_usd_cents']),
      withdrawableUsdCents: _asInt(row['withdrawable_usd_cents']),
      canTransferSettlement: row['can_transfer_settlement'] == true,
      securityFrozen: row['security_frozen'] == true,
      freezeReason: row['freeze_reason']?.toString() ?? '',
      coinSellerWallet: _roleWallet(row['coin_seller_wallet']),
      merchantWallet: _roleWallet(row['merchant_wallet']),
    );
  }

  Future<RemoteCp?> cpState(String token) async {
    final data = await _request('GET', '/cp', token);
    return _cp(data['cp']);
  }

  Future<RemoteCp> cpRequest(String token, String targetUserId) async {
    final data = await _request('POST', '/cp/request', token, body: {'target_user_id': targetUserId});
    final cp = _cp(data['cp']);
    if (cp == null) throw StateError('Server returned invalid CP');
    return cp;
  }

  Future<RemoteCp> cpRespond(String token, bool accept) async {
    final data = await _request('POST', '/cp/respond', token, body: {'accept': accept});
    final cp = _cp(data['cp']);
    if (cp == null) throw StateError('Server returned invalid CP');
    return cp;
  }

  Future<void> cpDisconnect(String token) async {
    await _request('POST', '/cp/disconnect', token, body: const {});
  }

  Future<RemoteCp> cpUpdate(String token, String action, Map<String, dynamic> values) async {
    final data = await _request('POST', '/cp/update', token, body: {'action': action, ...values});
    final cp = _cp(data['cp']);
    if (cp == null) throw StateError('Server returned invalid CP');
    return cp;
  }

  Future<List<String>> cpMemories(String token) async {
    final data = await _request('GET', '/cp/memories', token);
    final raw = data['memories'];
    if (raw is! List) return const [];
    return raw.map((value) => _map(value)['text']?.toString() ?? '').where((value) => value.isNotEmpty).toList(growable: false);
  }

  Future<void> cpAddMemory(String token, String text) async {
    await _request('POST', '/cp/memories', token, body: {'text': text});
  }

  Future<List<Map<String, dynamic>>> walletTransactions(String token) async {
    final data = await _request('GET', '/wallet/transactions', token);
    final raw = data['transactions'];
    if (raw is! List) return const [];
    return raw.map(_map).toList(growable: false);
  }

  Future<SettlementRecipient> settlementRecipient(
    String token,
    String userId,
  ) async {
    final base = apiBase.replace(path: '/wallet/settlement/recipient');
    final uri = base.replace(queryParameters: {'user_id': userId});
    if (token.trim().isEmpty) throw StateError('Login session is required');
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    final data = text.trim().isEmpty
        ? <String, dynamic>{}
        : _map(jsonDecode(text));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Recipient not found');
    }
    final row = _map(data['recipient']);
    return SettlementRecipient(
      userId: row['user_id']?.toString() ?? '',
      displayName: row['display_name']?.toString() ?? '',
      role: row['role']?.toString() ?? '',
      avatarDataUrl: row['avatar_data_url']?.toString(),
    );
  }

  Future<RemoteWallet> transferSettlement(
    String token, {
    required String recipientUserId,
    required int usdCents,
  }) async {
    final data = await _request(
      'POST',
      '/wallet/settlement/transfer',
      token,
      body: {
        'recipient_user_id': recipientUserId,
        'usd_cents': usdCents,
      },
    );
    final row = _map(data['wallet']);
    return RemoteWallet(
      coins: _asInt(row['coins']),
      diamonds: _asInt(row['diamonds']),
      banned: row['banned'] == true,
      updatedAt: _asInt(row['updated_at']),
      diamondWalletVisible: row['diamond_wallet_visible'] == true,
      isHost: row['is_host'] == true,
      isAgency: row['is_agency'] == true,
      isBd: row['is_bd'] == true,
      diamondUsdCents: _asInt(row['diamond_usd_cents']),
      commissionUsdCents: _asInt(row['commission_usd_cents']),
      withdrawableUsdCents: _asInt(row['withdrawable_usd_cents']),
      canTransferSettlement: row['can_transfer_settlement'] == true,
      securityFrozen: row['security_frozen'] == true,
      freezeReason: row['freeze_reason']?.toString() ?? '',
      coinSellerWallet: _roleWallet(row['coin_seller_wallet']),
      merchantWallet: _roleWallet(row['merchant_wallet']),
    );
  }

  Future<Map<String, dynamic>> transferCoins(
    String token, {
    required String recipientUserId,
    required int amountCoins,
    required String walletType,
  }) async {
    return _request(
      'POST',
      '/wallet/coins/transfer',
      token,
      body: {
        'recipient_user_id': recipientUserId,
        'amount_coins': amountCoins,
        'wallet_type': walletType,
      },
    );
  }

  Future<List<Map<String, dynamic>>> uniqueIdCatalog(String token) async {
    final data = await _request('GET', '/unique-ids/catalog', token);
    final raw = data['unique_ids'];
    if (raw is! List) return const [];
    return raw.map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> purchaseUniqueId(String token, String publicId) async {
    return _request('POST', '/unique-ids/purchase', token, body: {'public_id': publicId});
  }

  Future<List<Map<String, dynamic>>> storeCatalog(String token, String kind, {String country = ''}) async {
    final base = apiBase.replace(path: '/store/catalog');
    final uri = base.replace(queryParameters: {'kind': kind, if (country.isNotEmpty) 'country': country});
    if (token.trim().isEmpty) throw StateError('Login session is required');
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    Map<String, dynamic> data = <String, dynamic>{};
    if (text.trim().isNotEmpty) {
      try {
        data = _map(jsonDecode(text));
      } on FormatException {
        final body = text.trim();
        if (body.contains('error code: 1101')) {
          throw StateError(
            'Tinni Star server is temporarily unavailable (1101). Please retry.',
          );
        }
        throw StateError('Store server returned an invalid response.');
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load store');
    }
    final raw = data['items'];
    if (raw is! List) return const [];
    return raw.map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> purchaseStoreItem(String token, String kind, String itemId, {String country = ''}) async {
    return _request('POST', '/store/purchase', token, body: {'kind': kind, 'item_id': itemId, if (country.isNotEmpty) 'country': country});
  }

  Future<Map<String, dynamic>> equipStoreItem(
    String token, {
    required String kind,
    String? itemId,
  }) async {
    return _request(
      'POST',
      '/store/equip',
      token,
      body: <String, dynamic>{
        'kind': kind,
        'item_id': itemId,
      },
    );
  }

  Future<Map<String, dynamic>> sendStoreItem(
    String token, {
    required String recipientUserId,
    required String kind,
    required String itemId,
  }) async {
    return _request(
      'POST',
      '/store/send',
      token,
      body: <String, dynamic>{
        'recipient_user_id': recipientUserId,
        'kind': kind,
        'item_id': itemId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> frameCatalog(String token) async {
    final data = await _request('GET', '/frames/catalog', token);
    final raw = data['frames'];
    if (raw is! List) return const [];
    return raw.map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> inventory(String token) async {
    final data = await _request('GET', '/inventory', token);
    return _map(data['inventory']);
  }

  Future<Map<String, dynamic>> purchaseFrame(String token, String frameId) async {
    return _request('POST', '/frames/purchase', token, body: {'frame_id': frameId});
  }

  Future<Map<String, dynamic>> equipFrame(String token, String? frameId) async {
    return _request('POST', '/frames/equip', token, body: {'frame_id': frameId});
  }

  Future<Map<String, dynamic>?> vipMe(String token) async {
    final data = await _request('GET', '/vip/me', token);
    final value = data['vip'];
    return value == null ? null : _map(value);
  }

  Future<Map<String, dynamic>> vipPurchase(String token, String vipId) async {
    return _request('POST', '/vip/purchase', token, body: {'vip_id': vipId});
  }

  Future<List<VipCatalogItem>> vipCatalog(String token) async {
    final data = await _request('GET', '/vip/catalog', token);
    final raw = data['vip'];
    if (raw is! List) return const [];
    final items = <VipCatalogItem>[];
    for (final value in raw) {
      final row = _map(value);
      final details = _map(row['data']);
      final level = _asInt(details['level']);
      if (level <= 0) continue;
      items.add(VipCatalogItem(
        id: row['id']?.toString() ?? 'vip-$level',
        name: row['name']?.toString() ?? 'VIP $level',
        level: level,
        enabled: row['enabled'] != false,
        data: details,
      ));
    }
    items.sort((a, b) => a.level.compareTo(b.level));
    return List.unmodifiable(items);
  }

  Future<Map<String, dynamic>> _request(String method, String path, String token, {Map<String, dynamic>? body}) async {
    if (token.trim().isEmpty) throw StateError('Login session is required');
    final uri = apiBase.replace(path: path);
    final request = method == 'POST' ? await _httpClient.postUrl(uri) : await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    Map<String, dynamic> data = <String, dynamic>{};
    if (text.trim().isNotEmpty) {
      try {
        data = _map(jsonDecode(text));
      } on FormatException {
        final body = text.trim();
        if (body.contains('error code: 1101')) {
          throw StateError(
            'Tinni Star server is temporarily unavailable (1101). Please pull to retry.',
          );
        }
        throw StateError('Tinni Star server returned an invalid response.');
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Server request failed');
    }
    return data;
  }

  RemoteCp? _cp(dynamic value) {
    final row = _map(value);
    if (row.isEmpty) return null;
    final a = row['user_a']?.toString() ?? '';
    final b = row['user_b']?.toString() ?? '';
    if (a.isEmpty || b.isEmpty) return null;
    return RemoteCp(
      userA: a,
      userB: b,
      state: row['state']?.toString() ?? 'pending',
      intimacy: _asInt(row['intimacy']),
      level: _asInt(row['level'], fallback: 1),
      ringId: row['ring_id']?.toString(),
      requestedBy: row['requested_by']?.toString() ?? '',
      createdAt: _asInt(row['created_at']),
    );
  }

  void dispose() => _httpClient.close(force: true);
}

RemoteRoleWallet? _roleWallet(dynamic value) {
  final row = _map(value);
  if (row.isEmpty || row['active'] != true) return null;
  return RemoteRoleWallet(
    balance: _asInt(row['balance']),
    banned: row['banned'] == true,
    securityFrozen: row['security_frozen'] == true,
    freezeReason: row['freeze_reason']?.toString() ?? '',
  );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry(key.toString(), item));
  return <String, dynamic>{};
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList(growable: false);
}
