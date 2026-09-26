import 'dart:convert';
import 'dart:io';

class AppAuthConfig {
  const AppAuthConfig({
    required this.googleServerClientId,
    required this.facebookConfigured,
    required this.emailOtpConfigured,
  });

  final String? googleServerClientId;
  final bool facebookConfigured;
  final bool emailOtpConfigured;
}

class AuthProfileDraft {
  const AuthProfileDraft({
    required this.provider,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final String provider;
  final String email;
  final String displayName;
  final String? photoUrl;
}

class AppLoginResult {
  const AppLoginResult({
    this.token,
    this.user,
    this.profileRequired = false,
    this.draft,
  });

  final String? token;
  final Map<String, dynamic>? user;
  final bool profileRequired;
  final AuthProfileDraft? draft;
}

class EmailOtpStartResult {
  const EmailOtpStartResult({
    required this.requestId,
    required this.email,
  });

  final String requestId;
  final String email;
}

class EmailOtpVerifyResult {
  const EmailOtpVerifyResult({
    required this.setupToken,
    required this.email,
    required this.profileRequired,
  });

  final String setupToken;
  final String email;
  final bool profileRequired;
}

class FacebookStartResult {
  const FacebookStartResult({
    required this.requestId,
    required this.authUrl,
  });

  final String requestId;
  final Uri authUrl;
}

class FacebookPollResult {
  const FacebookPollResult({
    required this.status,
    this.login,
    this.requestId,
  });

  final String status;
  final AppLoginResult? login;
  final String? requestId;

  bool get pending => status == 'pending';
}

class AppAuthApi {
  AppAuthApi({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinnistar-api.tinnistarchat.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  Future<AppAuthConfig> loadConfig() async {
    final request = await _httpClient.getUrl(
      apiBase.replace(path: '/app-config'),
    );
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to load app config',
      );
    }

    final google = data['google_server_client_id']?.toString().trim();
    return AppAuthConfig(
      googleServerClientId:
          google == null || google.isEmpty ? null : google,
      facebookConfigured: data['facebook_configured'] == true,
      emailOtpConfigured: data['email_otp_configured'] == true,
    );
  }

  Future<String?> loadGoogleServerClientId() async {
    return (await loadConfig()).googleServerClientId;
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
        draft: AuthProfileDraft(
          provider: 'google',
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

  Future<FacebookStartResult> startFacebookLogin() async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/app-auth/facebook/start'),
    );
    request.headers.contentType = ContentType.json;
    request.write('{}');

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Facebook login is unavailable',
      );
    }

    final requestId = data['request_id']?.toString() ?? '';
    final authUrl = data['auth_url']?.toString() ?? '';
    if (requestId.isEmpty || authUrl.isEmpty) {
      throw StateError('Facebook login response is incomplete');
    }

    return FacebookStartResult(
      requestId: requestId,
      authUrl: Uri.parse(authUrl),
    );
  }

  Future<FacebookPollResult> pollFacebookLogin(String requestId) async {
    final request = await _httpClient.getUrl(
      apiBase.replace(
        path: '/app-auth/facebook/status',
        queryParameters: <String, String>{'request_id': requestId},
      ),
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close();
    final data = await _readJson(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Facebook login failed',
      );
    }

    final status = data['status']?.toString() ?? 'pending';
    if (status == 'complete') {
      return FacebookPollResult(
        status: status,
        login: AppLoginResult(
          token: data['token']?.toString(),
          user: _asMap(data['user']),
        ),
      );
    }

    if (status == 'profile_required') {
      final provider = _asMap(data['provider']);
      return FacebookPollResult(
        status: status,
        requestId: data['request_id']?.toString() ?? requestId,
        login: AppLoginResult(
          profileRequired: true,
          draft: AuthProfileDraft(
            provider: 'facebook',
            email: provider['email']?.toString() ?? '',
            displayName: provider['display_name']?.toString() ?? '',
            photoUrl: provider['photo_url']?.toString(),
          ),
        ),
      );
    }

    return FacebookPollResult(status: status);
  }

  Future<AppLoginResult> completeFacebookLogin({
    required String requestId,
    required Map<String, dynamic> profile,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/app-auth/facebook/complete'),
    );
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(<String, dynamic>{
        'request_id': requestId,
        'profile': profile,
      }),
    );

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Facebook profile creation failed',
      );
    }

    return AppLoginResult(
      token: data['token']?.toString(),
      user: _asMap(data['user']),
    );
  }

  Future<EmailOtpStartResult> startEmailOtp(String email) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/app-auth/email/start'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(<String, dynamic>{'email': email.trim()}));

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to send email OTP',
      );
    }

    return EmailOtpStartResult(
      requestId: data['request_id']?.toString() ?? '',
      email: data['email']?.toString() ?? email.trim(),
    );
  }

  Future<EmailOtpVerifyResult> verifyEmailOtp({
    required String requestId,
    required String otp,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/app-auth/email/verify'),
    );
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(<String, dynamic>{
        'request_id': requestId,
        'otp': otp.trim(),
      }),
    );

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'OTP verification failed',
      );
    }

    return EmailOtpVerifyResult(
      setupToken: data['setup_token']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      profileRequired: data['profile_required'] == true,
    );
  }

  Future<AppLoginResult> completeEmailPassword({
    required String setupToken,
    required String password,
    Map<String, dynamic>? profile,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/app-auth/email/complete'),
    );
    request.headers.contentType = ContentType.json;
    final payload = <String, dynamic>{
      'setup_token': setupToken,
      'password': password,
    };
    if (profile != null) payload['profile'] = profile;
    request.write(jsonEncode(payload));

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to save Tinni password',
      );
    }

    return AppLoginResult(
      token: data['token']?.toString(),
      user: _asMap(data['user']),
    );
  }

  Future<AppLoginResult> emailPasswordLogin({
    required String email,
    required String password,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/app-auth/email/login'),
    );
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(<String, dynamic>{
        'email': email.trim(),
        'password': password,
      }),
    );

    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Email login failed',
      );
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
