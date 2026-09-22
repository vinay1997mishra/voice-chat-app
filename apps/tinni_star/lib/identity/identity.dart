class VipState {
  const VipState({this.level = 0, this.experience = 0});
  final int level;
  final int experience;

  VipState addExperience(int value) {
    final xp = experience + value;
    final nextLevel = (xp ~/ 1000).clamp(0, 12);
    return VipState(level: nextLevel, experience: xp);
  }
}

class NobleState {
  const NobleState({this.level = 0});
  final int level;

  NobleState upgrade() => NobleState(level: (level + 1).clamp(0, 6));
}

class IdentityService {
  VipState vip = const VipState();
  NobleState noble = const NobleState();
  final Set<String> medals = <String>{};
  final Set<String> vehicles = <String>{};
  String? goodNumber;

  void gainVipExperience(int value) {
    if (value > 0) vip = vip.addExperience(value);
  }

  void upgradeNoble() => noble = noble.upgrade();
  void addMedal(String id) => medals.add(id);
  void addVehicle(String id) => vehicles.add(id);
  void equipGoodNumber(String value) => goodNumber = value;
}
