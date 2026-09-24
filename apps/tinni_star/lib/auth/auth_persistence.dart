import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class AuthPersistence {
  AuthPersistence({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _userIdKey = 'tinni.auth.user_id';
  static const _nameKey = 'tinni.auth.name';
  static const _countryKey = 'tinni.auth.country';
  static const _providersKey = 'tinni.auth.providers';

  final SharedPreferencesAsync _preferences;

  Future<void> save(TinniAccount account) async {
    await _preferences.setString(_userIdKey, account.userId);
    await _preferences.setString(_nameKey, account.displayName);
    await _preferences.setString(_countryKey, account.countryCode);
    await _preferences.setStringList(
      _providersKey,
      account.providers.map((provider) => provider.name).toList(),
    );
  }

  Future<String> getOrCreateUserId() async {
    final saved = await _preferences.getString(_userIdKey);
    if (saved != null && saved.trim().isNotEmpty) return saved;

    final random = Random.secure();
    final id = (10000000 + random.nextInt(90000000)).toString();
    await _preferences.setString(_userIdKey, id);
    return id;
  }

  Future<bool> restore(AuthService auth) async {
    final userId = await getOrCreateUserId();
    final name = await _preferences.getString(_nameKey);
    final country = await _preferences.getString(_countryKey);
    final providerNames = await _preferences.getStringList(_providersKey);
    if (name == null || country == null || providerNames == null || providerNames.isEmpty) {
      return false;
    }

    final providers = providerNames
        .map(
          (name) => LoginProvider.values.firstWhere(
            (provider) => provider.name == name,
            orElse: () => LoginProvider.phone,
          ),
        )
        .toSet();

    final first = providers.first;
    auth.loginDemo(
      userId: userId,
      displayName: name,
      countryCode: country,
      provider: first,
    );
    for (final provider in providers.skip(1)) {
      auth.bind(provider);
    }
    return true;
  }

  Future<void> clear() async {
    await _preferences.remove(_userIdKey);
    await _preferences.remove(_nameKey);
    await _preferences.remove(_countryKey);
    await _preferences.remove(_providersKey);
  }
}
