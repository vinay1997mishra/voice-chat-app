enum LoginProvider { phone, google, facebook }

class TinniAccount {
  const TinniAccount({
    required this.userId,
    required this.displayName,
    required this.countryCode,
    required this.providers,
  });

  final String userId;
  final String displayName;
  final String countryCode;
  final Set<LoginProvider> providers;

  TinniAccount bind(LoginProvider provider) => TinniAccount(
        userId: userId,
        displayName: displayName,
        countryCode: countryCode,
        providers: {...providers, provider},
      );
}

class AuthService {
  TinniAccount? _current;

  TinniAccount? get current => _current;
  bool get isLoggedIn => _current != null;

  TinniAccount loginDemo({
    String displayName = 'Tinni User',
    String countryCode = 'IN',
    LoginProvider provider = LoginProvider.phone,
  }) {
    _current = TinniAccount(
      userId: '10000000',
      displayName: displayName,
      countryCode: countryCode,
      providers: {provider},
    );
    return _current!;
  }

  void bind(LoginProvider provider) {
    final account = _current;
    if (account == null) throw StateError('Not logged in');
    _current = account.bind(provider);
  }

  void forcedLogout() => _current = null;
  void deleteAccount() => _current = null;
}
