enum FamilyRole { head, deputyHead, assistant, member }

enum FamilyVisualTier { bronze, emerald, sapphire, amethyst, royalGold }

class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.name,
    required this.role,
  });

  final String userId;
  final String name;
  final FamilyRole role;

  FamilyMember withRole(FamilyRole role) => FamilyMember(
        userId: userId,
        name: name,
        role: role,
      );
}

class FamilyService {
  String? name;
  String? tag;
  String notice = '';
  int level = 1;
  int experience = 0;
  int walletCoins = 0;
  final List<FamilyMember> members = <FamilyMember>[];
  final List<String> records = <String>[];

  bool get exists => name != null;

  FamilyVisualTier get visualTier {
    if (level >= 20) return FamilyVisualTier.royalGold;
    if (level >= 10) return FamilyVisualTier.amethyst;
    if (level >= 6) return FamilyVisualTier.sapphire;
    if (level >= 3) return FamilyVisualTier.emerald;
    return FamilyVisualTier.bronze;
  }

  String get levelLabel => 'Lv.' + level.toString();

  bool isMember(String userId) =>
      members.any((member) => member.userId == userId);

  FamilyMember? get head {
    for (final member in members) {
      if (member.role == FamilyRole.head) return member;
    }
    return null;
  }

  List<FamilyMember> get deputies => members
      .where((member) => member.role == FamilyRole.deputyHead)
      .toList();

  void create({
    required String familyName,
    required String familyTag,
    required FamilyMember head,
  }) {
    if (exists) throw StateError('Family already exists');
    name = familyName.trim();
    tag = familyTag.trim();
    members.add(head.withRole(FamilyRole.head));
    records.add('Family created');
  }

  void join(FamilyMember member) {
    if (!exists) throw StateError('Family does not exist');
    if (members.any((item) => item.userId == member.userId)) return;
    members.add(member.withRole(FamilyRole.member));
    records.add(member.name + ' joined');
  }

  void joinExisting({
    required String familyName,
    required String familyTag,
    required FamilyMember member,
  }) {
    if (exists) throw StateError('Already joined a family');
    name = familyName.trim();
    tag = familyTag.trim();
    members.add(member.withRole(FamilyRole.member));
    notice = 'Welcome ' + familyName.trim() + ' members ❤️';
    records.add(member.name + ' joined ' + familyName.trim());
  }

  void updateNotice(String value) {
    notice = value.trim();
    records.add('Family announcement updated');
  }

  void removeMember(String userId) {
    final index = members.indexWhere((member) => member.userId == userId);
    if (index < 0) return;
    if (members[index].role == FamilyRole.head) {
      throw StateError('Family leader cannot be removed');
    }
    final removed = members.removeAt(index);
    records.add(removed.name + ' removed');
  }

  void appoint(String userId, FamilyRole role) {
    if (role == FamilyRole.head) {
      throw StateError('Head transfer requires a dedicated flow');
    }
    final index = members.indexWhere((member) => member.userId == userId);
    if (index < 0) return;
    members[index] = members[index].withRole(role);
    records.add(members[index].name + ' role changed');
  }

  void addExperience(int value) {
    if (value <= 0) return;
    experience += value;
    level = 1 + experience ~/ 5000;
  }

  void deposit(int coins) {
    if (coins <= 0) return;
    walletCoins += coins;
    records.add('Family wallet +' + coins.toString());
  }
}
