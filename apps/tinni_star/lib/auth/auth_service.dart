enum LoginProvider { google, facebook }

class TinniAccount {
  const TinniAccount({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.age,
    required this.signature,
    required this.countryCode,
    required this.countryName,
    required this.flagEmoji,
    required this.gender,
    required this.providers,
    required this.authToken,
    this.avatarDataUrl,
  });

  final String userId;
  final String email;
  final String displayName;
  final int age;
  final String signature;
  final String countryCode;
  final String countryName;
  final String flagEmoji;
  final String gender;
  final String? avatarDataUrl;
  final Set<LoginProvider> providers;
  final String authToken;

  static TinniAccount fromServer(
    Map<String, dynamic> user, {
    required String token,
  }) {
    return TinniAccount(
      userId: user['user_id']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      displayName: user['display_name']?.toString() ?? '',
      age: _asInt(user['age']),
      signature: user['signature']?.toString() ?? '',
      countryCode: user['country_code']?.toString() ?? '',
      countryName: user['country_name']?.toString() ?? '',
      flagEmoji: user['flag_emoji']?.toString() ?? '',
      gender: user['gender']?.toString() ?? '',
      avatarDataUrl: user['avatar_data_url']?.toString(),
      providers: <LoginProvider>{
        user['auth_provider']?.toString() == 'facebook'
            ? LoginProvider.facebook
            : LoginProvider.google,
      },
      authToken: token,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AuthService {
  TinniAccount? _current;

  TinniAccount? get current => _current;
  bool get isLoggedIn => _current != null;

  void setAuthenticatedAccount(TinniAccount account) {
    if (account.userId.isEmpty || account.authToken.isEmpty) {
      throw StateError('Authenticated user ID and token are required');
    }
    _current = account;
  }

  void forcedLogout() => _current = null;
  void deleteAccount() => _current = null;
}
