enum FamilyRole { head, deputyHead, assistant, member }

enum FamilyVisualTier { bronze, emerald, sapphire, amethyst, royalGold }

class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.name,
    required this.role,
    this.avatarDataUrl,
    this.receivedCoins = 0,
  });

  final String userId;
  final String name;
  final FamilyRole role;
  final String? avatarDataUrl;
  final int receivedCoins;

  FamilyMember withRole(FamilyRole role) => FamilyMember(
        userId: userId,
        name: name,
        role: role,
        avatarDataUrl: avatarDataUrl,
        receivedCoins: receivedCoins,
      );
}

class FamilyJoinRequest {
  const FamilyJoinRequest({
    required this.userId,
    required this.name,
  });

  final String userId;
  final String name;
}

class FamilyService {
  String? name;
  String? tag;
  String notice = '';
  int level = 1;
  int experience = 0;
  int walletCoins = 0;
  final List<FamilyMember> members = <FamilyMember>[];
  final List<FamilyJoinRequest> pendingJoinRequests = <FamilyJoinRequest>[];
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

  void clearRemote() {
    name = null;
    tag = null;
    notice = '';
    level = 1;
    experience = 0;
    walletCoins = 0;
    members.clear();
    pendingJoinRequests.clear();
  }

  void applyRemote(Map<String, dynamic> payload) {
    final rawFamily = payload['family'];
    if (rawFamily is! Map) {
      clearRemote();
      return;
    }
    final family = Map<String, dynamic>.from(rawFamily);
    name = family['name']?.toString();
    tag = family['tag']?.toString();
    notice = family['notice']?.toString() ?? '';
    experience = (family['experience'] as num?)?.toInt() ?? 0;
    level = (family['level'] as num?)?.toInt() ?? 1;
    walletCoins = (family['wallet_coins'] as num?)?.toInt() ?? 0;

    final rawMembers = payload['members'];
    members
      ..clear()
      ..addAll(
        rawMembers is List
            ? rawMembers.whereType<Map>().map((raw) {
                final row = Map<String, dynamic>.from(raw);
                final roleName = row['role']?.toString().toLowerCase() ?? '';
                final role = roleName == 'leader'
                    ? FamilyRole.head
                    : roleName == 'admin'
                        ? FamilyRole.deputyHead
                        : FamilyRole.member;
                return FamilyMember(
                  userId: row['user_id']?.toString() ?? '',
                  name: row['display_name']?.toString() ??
                      row['user_id']?.toString() ??
                      'Member',
                  role: role,
                  avatarDataUrl: row['avatar_data_url']?.toString(),
                  receivedCoins:
                      (row['received_coins'] as num?)?.toInt() ?? 0,
                );
              }).where((member) => member.userId.isNotEmpty)
            : const <FamilyMember>[],
      );

    final rawRequests = payload['join_requests'];
    pendingJoinRequests
      ..clear()
      ..addAll(
        rawRequests is List
            ? rawRequests.whereType<Map>().map((raw) {
                final row = Map<String, dynamic>.from(raw);
                return FamilyJoinRequest(
                  userId: row['user_id']?.toString() ?? '',
                  name: row['display_name']?.toString() ??
                      row['user_id']?.toString() ??
                      'User',
                );
              }).where((request) => request.userId.isNotEmpty)
            : const <FamilyJoinRequest>[],
      );
  }

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

  FamilyMember? memberById(String userId) {
    for (final member in members) {
      if (member.userId == userId) return member;
    }
    return null;
  }

  bool isLeader(String userId) => memberById(userId)?.role == FamilyRole.head;

  bool isAdmin(String userId) =>
      memberById(userId)?.role == FamilyRole.deputyHead;

  bool canReviewJoinRequests(String actorUserId) =>
      isLeader(actorUserId) || isAdmin(actorUserId);

  bool canRemoveMember({
    required String actorUserId,
    required String targetUserId,
  }) {
    if (actorUserId == targetUserId) return false;
    final actor = memberById(actorUserId);
    final target = memberById(targetUserId);
    if (actor == null || target == null) return false;
    if (actor.role == FamilyRole.head) {
      return target.role != FamilyRole.head;
    }
    if (actor.role == FamilyRole.deputyHead) {
      return target.role == FamilyRole.member ||
          target.role == FamilyRole.assistant;
    }
    return false;
  }

  bool requestToJoin(FamilyJoinRequest request) {
    if (!exists || request.userId.trim().isEmpty || request.name.trim().isEmpty) {
      return false;
    }
    if (isMember(request.userId)) return false;
    if (pendingJoinRequests.any((item) => item.userId == request.userId)) {
      return false;
    }
    pendingJoinRequests.add(request);
    records.add(request.name + ' requested to join');
    return true;
  }

  bool approveJoinRequest({
    required String actorUserId,
    required String userId,
  }) {
    if (!canReviewJoinRequests(actorUserId)) return false;
    final index =
        pendingJoinRequests.indexWhere((request) => request.userId == userId);
    if (index < 0) return false;
    final request = pendingJoinRequests.removeAt(index);
    join(FamilyMember(
      userId: request.userId,
      name: request.name,
      role: FamilyRole.member,
    ));
    records.add(request.name + ' join request approved');
    return true;
  }

  bool rejectJoinRequest({
    required String actorUserId,
    required String userId,
  }) {
    if (!canReviewJoinRequests(actorUserId)) return false;
    final index =
        pendingJoinRequests.indexWhere((request) => request.userId == userId);
    if (index < 0) return false;
    final request = pendingJoinRequests.removeAt(index);
    records.add(request.name + ' join request rejected');
    return true;
  }

  bool removeMemberAs({
    required String actorUserId,
    required String targetUserId,
  }) {
    if (!canRemoveMember(
      actorUserId: actorUserId,
      targetUserId: targetUserId,
    )) {
      return false;
    }
    removeMember(targetUserId);
    return true;
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

  /// Monthly Family Wallet bonus by level: L1 1.00%, +0.25% each level,
  /// capped at L11 3.50%.
  int get monthlyWalletBonusBasisPoints => 100 + ((level - 1).clamp(0, 10) * 25);

  double get monthlyWalletBonusPercent => monthlyWalletBonusBasisPoints / 100.0;

  int monthlyWalletBonusFor(int baseCoins) {
    if (baseCoins <= 0) return 0;
    return (baseCoins * monthlyWalletBonusBasisPoints) ~/ 10000;
  }

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
    records.add(
      receiverUserId +
          ' received ' +
          coins.toString() +
          ' coins; Family EXP +' +
          coins.toString(),
    );
    return true;
  }

  void deposit(int coins) {
    if (coins <= 0) return;
    walletCoins += coins;
    records.add('Family wallet +' + coins.toString());
  }
}
