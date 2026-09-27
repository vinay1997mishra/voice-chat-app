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

  static const List<int> levelExperienceThresholds = <int>[
    0,
    50000000,
    240000000,
    580000000,
    970000000,
    1300000000,
    1800000000,
    2500000000,
    3500000000,
    6000000000,
    15000000000,
  ];

  int get levelRequiredExperience =>
      levelExperienceThresholds[(level - 1).clamp(0, 10)];

  int? get nextLevelRequiredExperience =>
      level >= 11 ? null : levelExperienceThresholds[level];

  double get levelProgress {
    final next = nextLevelRequiredExperience;
    if (next == null) return 1.0;
    final current = levelRequiredExperience;
    final span = next - current;
    if (span <= 0) return 1.0;
    return ((experience - current) / span).clamp(0.0, 1.0);
  }

  void addExperience(int value) {
    if (value <= 0) return;
    experience += value;
    var resolvedLevel = 1;
    for (var i = 1; i < levelExperienceThresholds.length; i++) {
      if (experience >= levelExperienceThresholds[i]) {
        resolvedLevel = i + 1;
      } else {
        break;
      }
    }
    level = resolvedLevel;
  }

  /// Applies a received-coin event for a current family member.
  ///
  /// Receiving coins grants Family EXP at 1 EXP per coin. Sending coins does
  /// not call this method and therefore grants no Family EXP. A unique
  /// transaction id is counted only once.
  final Set<String> _countedReceivedTransactions = <String>{};

  bool recordCoinsReceived({
    required String transactionId,
    required String receiverUserId,
    required int coins,
  }) {
    if (transactionId.trim().isEmpty || coins <= 0) return false;
    if (!isMember(receiverUserId)) return false;
    if (!_countedReceivedTransactions.add(transactionId)) return false;
    addExperience(coins);
    final walletShare = coins ~/ 100;
    if (walletShare > 0) {
      deposit(walletShare);
    }
    records.add(
      receiverUserId +
          ' received ' +
          coins.toString() +
          ' coins; Family EXP +' +
          coins.toString() +
          '; wallet 1% +' +
          walletShare.toString(),
    );
    return true;
  }

  void deposit(int coins) {
    if (coins <= 0) return;
    walletCoins += coins;
    records.add('Family wallet +' + coins.toString());
  }
}
