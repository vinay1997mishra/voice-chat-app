class ProfileState {
  const ProfileState({
    required this.userId,
    required this.nick,
    required this.country,
    this.signature = '',
    this.birthday,
    this.avatarPath,
    this.gender,
  });

  final String userId;
  final String nick;
  final String country;
  final String signature;
  final DateTime? birthday;
  final String? avatarPath;
  final String? gender;

  ProfileState copyWith({
    String? nick,
    String? country,
    String? signature,
    DateTime? birthday,
    String? avatarPath,
    String? gender,
  }) {
    return ProfileState(
      userId: userId,
      nick: nick ?? this.nick,
      country: country ?? this.country,
      signature: signature ?? this.signature,
      birthday: birthday ?? this.birthday,
      avatarPath: avatarPath ?? this.avatarPath,
      gender: gender ?? this.gender,
    );
  }
}

class ProfileService {
  ProfileState profile = const ProfileState(
    userId: '10000000',
    nick: 'Tinni User',
    country: 'IN',
  );

  void editNick(String nick) {
    final value = nick.trim();
    if (value.isNotEmpty) profile = profile.copyWith(nick: value);
  }

  void editSignature(String signature) {
    profile = profile.copyWith(signature: signature.trim());
  }

  void setBirthday(DateTime birthday) {
    profile = profile.copyWith(birthday: birthday);
  }

  void setAvatar(String path) {
    if (path.trim().isNotEmpty) profile = profile.copyWith(avatarPath: path);
  }

  void setGender(String gender) {
    profile = profile.copyWith(gender: gender);
  }
}
