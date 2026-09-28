import 'dart:convert';
import 'dart:io';

class RemoteWallet {
  const RemoteWallet({required this.coins, required this.diamonds, required this.banned, required this.updatedAt});
  final int coins;
  final int diamonds;
  final bool banned;
  final int updatedAt;
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

  Future<RemoteWallet> wallet(String token) async {
    final data = await _request('GET', '/wallet', token);
    final row = _map(data['wallet']);
    return RemoteWallet(
      coins: _asInt(row['coins']),
      diamonds: _asInt(row['diamonds']),
      banned: row['banned'] == true,
      updatedAt: _asInt(row['updated_at']),
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
    final data = text.trim().isEmpty ? <String, dynamic>{} : _map(jsonDecode(text));
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
