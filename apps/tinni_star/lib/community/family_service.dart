enum FamilyRole { head, deputyHead, assistant, member }

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
