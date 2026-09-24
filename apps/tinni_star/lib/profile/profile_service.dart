import '../auth/auth_service.dart';

class ProfileState {
  const ProfileState({
    required this.userId,
    required this.nick,
    required this.country,
    required this.countryName,
    required this.flagEmoji,
    required this.age,
    required this.gender,
    this.signature = '',
    this.avatarDataUrl,
  });

  final String userId;
  final String nick;
  final String country;
  final String countryName;
  final String flagEmoji;
  final int age;
  final String gender;
  final String signature;
  final String? avatarDataUrl;

  ProfileState copyWith({
    String? nick,
    String? country,
    String? countryName,
    String? flagEmoji,
    int? age,
    String? gender,
    String? signature,
    String? avatarDataUrl,
  }) {
    return ProfileState(
      userId: userId,
      nick: nick ?? this.nick,
      country: country ?? this.country,
      countryName: countryName ?? this.countryName,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      signature: signature ?? this.signature,
      avatarDataUrl: avatarDataUrl ?? this.avatarDataUrl,
    );
  }
}

class ProfileService {
  ProfileState? _profile;

  ProfileState? get current => _profile;

  void loadFromAccount(TinniAccount account) {
    _profile = ProfileState(
      userId: account.userId,
      nick: account.displayName,
      country: account.countryCode,
      countryName: account.countryName,
      flagEmoji: account.flagEmoji,
      age: account.age,
      gender: account.gender,
      signature: account.signature,
      avatarDataUrl: account.avatarDataUrl,
    );
  }

  void clear() => _profile = null;
}
