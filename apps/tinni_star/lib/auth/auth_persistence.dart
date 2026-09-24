import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class AuthPersistence {
  AuthPersistence({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _userIdKey = 'tinni.auth.user_id';
  static const _emailKey = 'tinni.auth.email';
  static const _nameKey = 'tinni.auth.name';
  static const _ageKey = 'tinni.auth.age';
  static const _signatureKey = 'tinni.auth.signature';
  static const _countryCodeKey = 'tinni.auth.country_code';
  static const _countryNameKey = 'tinni.auth.country_name';
  static const _flagKey = 'tinni.auth.flag';
  static const _genderKey = 'tinni.auth.gender';
  static const _avatarKey = 'tinni.auth.avatar_data_url';
  static const _tokenKey = 'tinni.auth.token';

  final SharedPreferencesAsync _preferences;

  Future<void> save(TinniAccount account) async {
    await _preferences.setString(_userIdKey, account.userId);
    await _preferences.setString(_emailKey, account.email);
    await _preferences.setString(_nameKey, account.displayName);
    await _preferences.setInt(_ageKey, account.age);
    await _preferences.setString(_signatureKey, account.signature);
    await _preferences.setString(_countryCodeKey, account.countryCode);
    await _preferences.setString(_countryNameKey, account.countryName);
    await _preferences.setString(_flagKey, account.flagEmoji);
    await _preferences.setString(_genderKey, account.gender);
    if (account.avatarDataUrl == null || account.avatarDataUrl!.isEmpty) {
      await _preferences.remove(_avatarKey);
    } else {
      await _preferences.setString(_avatarKey, account.avatarDataUrl!);
    }
    await _preferences.setString(_tokenKey, account.authToken);
  }

  Future<bool> restore(AuthService auth) async {
    final userId = await _preferences.getString(_userIdKey);
    final email = await _preferences.getString(_emailKey);
    final name = await _preferences.getString(_nameKey);
    final age = await _preferences.getInt(_ageKey);
    final signature = await _preferences.getString(_signatureKey);
    final countryCode = await _preferences.getString(_countryCodeKey);
    final countryName = await _preferences.getString(_countryNameKey);
    final flag = await _preferences.getString(_flagKey);
    final gender = await _preferences.getString(_genderKey);
    final avatar = await _preferences.getString(_avatarKey);
    final token = await _preferences.getString(_tokenKey);

    if (userId == null ||
        userId.isEmpty ||
        email == null ||
        name == null ||
        age == null ||
        countryCode == null ||
        countryName == null ||
        flag == null ||
        gender == null ||
        token == null ||
        token.isEmpty) {
      return false;
    }

    auth.setAuthenticatedAccount(
      TinniAccount(
        userId: userId,
        email: email,
        displayName: name,
        age: age,
        signature: signature ?? '',
        countryCode: countryCode,
        countryName: countryName,
        flagEmoji: flag,
        gender: gender,
        avatarDataUrl: avatar,
        providers: const <LoginProvider>{LoginProvider.google},
        authToken: token,
      ),
    );
    return true;
  }

  Future<void> clear() async {
    for (final key in <String>[
      _userIdKey,
      _emailKey,
      _nameKey,
      _ageKey,
      _signatureKey,
      _countryCodeKey,
      _countryNameKey,
      _flagKey,
      _genderKey,
      _avatarKey,
      _tokenKey,
    ]) {
      await _preferences.remove(key);
    }
  }
}
