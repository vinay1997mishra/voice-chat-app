import 'dart:convert';
import 'dart:io';

class GoogleProfileDraft {
  const GoogleProfileDraft({
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final String email;
  final String displayName;
  final String? photoUrl;
}

class AppLoginResult {
  const AppLoginResult({
    this.token,
    this.user,
    this.profileRequired = false,
    this.googleDraft,
  });

  final String? token;
  final Map<String, dynamic>? user;
  final bool profileRequired;
  final GoogleProfileDraft? googleDraft;
}

class AppAuthApi {
  AppAuthApi({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  Future<String?> loadGoogleServerClientId() async {
    final request = await _httpClient.getUrl(apiBase.replace(path: '/app-config'));
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to load app config');
    }
    final value = data['google_server_client_id']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<AppLoginResult> googleLogin({
    required String idToken,
    Map<String, dynamic>? profile,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/app-auth/google'),
    );
    request.headers.contentType = ContentType.json;
    final payload = <String, dynamic>{'id_token': idToken};
    if (profile != null) {
      payload['profile'] = profile;
    }
    request.write(jsonEncode(payload));

    final response = await request.close();
    final data = await _readJson(response);

    if (response.statusCode == 428 && data['profile_required'] == true) {
      final google = _asMap(data['google']);
      return AppLoginResult(
        profileRequired: true,
        googleDraft: GoogleProfileDraft(
          email: google['email']?.toString() ?? '',
          displayName: google['display_name']?.toString() ?? '',
          photoUrl: google['photo_url']?.toString(),
        ),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Google login failed');
    }

    return AppLoginResult(
      token: data['token']?.toString(),
      user: _asMap(data['user']),
    );
  }

  Future<Map<String, dynamic>> me(String token) async {
    final request = await _httpClient.getUrl(apiBase.replace(path: '/app/me'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Session expired');
    }
    return _asMap(data['user']);
  }

  Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
    final body = await utf8.decoder.bind(response).join();
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    return _asMap(decoded);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  void dispose() => _httpClient.close(force: true);
}
