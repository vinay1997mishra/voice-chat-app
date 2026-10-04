import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract interface class PushAdapter {
  Future<void> register(String userId);
  Future<void> unregister();
}

abstract interface class AnalyticsAdapter {
  void event(String name, Map<String, Object?> properties);
}

abstract interface class CrashReporter {
  void record(Object error, StackTrace? stackTrace);
}

abstract interface class RemoteConfigAdapter {
  Future<Map<String, Object?>> fetch();
}

class LocalPushAdapter implements PushAdapter {
  String? registeredUserId;

  @override
  Future<void> register(String userId) async {
    if (userId.isEmpty) throw StateError('userId is required');
    registeredUserId = userId;
  }

  @override
  Future<void> unregister() async {
    registeredUserId = null;
  }
}

class LocalAnalyticsAdapter implements AnalyticsAdapter {
  final List<Map<String, Object?>> events = <Map<String, Object?>>[];

  @override
  void event(String name, Map<String, Object?> properties) {
    events.add({
      'name': name,
      'properties': Map<String, Object?>.unmodifiable(properties),
    });
  }
}

class LocalCrashReporter implements CrashReporter {
  final List<String> errors = <String>[];

  @override
  void record(Object error, StackTrace? stackTrace) {
    errors.add(error.toString());
  }
}

class LocalRemoteConfigAdapter implements RemoteConfigAdapter {
  final Map<String, Object?> values = <String, Object?>{
    'room_recommendation_enabled': true,
    'gift_effects_enabled': true,
    'ktv_enabled': true,
    'games_enabled': true,
  };

  @override
  Future<Map<String, Object?>> fetch() async =>
      Map<String, Object?>.unmodifiable(values);
}

class BackendAnalyticsAdapter implements AnalyticsAdapter {
  BackendAnalyticsAdapter({
    required this.tokenProvider,
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final String? Function() tokenProvider;
  final Uri apiBase;
  final HttpClient _httpClient;

  @override
  void event(String name, Map<String, Object?> properties) {
    final token = tokenProvider();
    if (token == null || token.trim().isEmpty || name.trim().isEmpty) return;
    unawaited(_send(name, properties, token));
  }

  Future<void> _send(
    String name,
    Map<String, Object?> properties,
    String token,
  ) async {
    try {
      final request = await _httpClient.postUrl(
        apiBase.replace(path: '/telemetry/analytics'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ' + token,
      );
      request.write(
        jsonEncode(<String, Object?>{
          'event_name': name,
          'properties': properties,
        }),
      );
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // Telemetry must never break the user flow.
    }
  }

  void dispose() {
    _httpClient.close(force: true);
  }
}

class BackendCrashReporter implements CrashReporter {
  BackendCrashReporter({
    required this.tokenProvider,
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final String? Function() tokenProvider;
  final Uri apiBase;
  final HttpClient _httpClient;

  @override
  void record(Object error, StackTrace? stackTrace) {
    final token = tokenProvider();
    if (token == null || token.trim().isEmpty) return;
    unawaited(_send(error, stackTrace, token));
  }

  Future<void> _send(
    Object error,
    StackTrace? stackTrace,
    String token,
  ) async {
    try {
      final request = await _httpClient.postUrl(
        apiBase.replace(path: '/telemetry/crash'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ' + token,
      );
      request.write(
        jsonEncode(<String, Object?>{
          'error': error.toString(),
          'stack': stackTrace?.toString() ?? '',
          'context': const <String, Object?>{
            'source': 'tinni_star_android',
          },
        }),
      );
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // Crash reporting must never trigger a second crash.
    }
  }

  void dispose() {
    _httpClient.close(force: true);
  }
}

class BackendRemoteConfigAdapter implements RemoteConfigAdapter {
  BackendRemoteConfigAdapter({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  @override
  Future<Map<String, Object?>> fetch() async {
    final request = await _httpClient.getUrl(
      apiBase.replace(path: '/app-config'),
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Remote config HTTP ${response.statusCode}');
    }
    dynamic decoded;
    if (raw.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        throw StateError(
          'Tinni Star server returned an invalid remote config. Please retry.',
        );
      }
    }
    if (decoded is! Map) return const <String, Object?>{};
    final remote = decoded['remote_config'];
    if (remote is! Map) return const <String, Object?>{};
    return Map<String, Object?>.unmodifiable(
      remote.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      ),
    );
  }

  void dispose() {
    _httpClient.close(force: true);
  }
}
