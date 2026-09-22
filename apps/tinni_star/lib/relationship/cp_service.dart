enum CourtingState { none, pending, accepted, refused, timedOut }

class CpRelationship {
  const CpRelationship({
    required this.userA,
    required this.userB,
    required this.startedAt,
    this.intimacy = 0,
    this.level = 1,
    this.ringId,
  });

  final String userA;
  final String userB;
  final DateTime startedAt;
  final int intimacy;
  final int level;
  final String? ringId;

  CpRelationship addIntimacy(int value) {
    final next = intimacy + value;
    return CpRelationship(
      userA: userA,
      userB: userB,
      startedAt: startedAt,
      intimacy: next,
      level: 1 + (next ~/ 1000),
      ringId: ringId,
    );
  }

  CpRelationship withRing(String ringId) => CpRelationship(
        userA: userA,
        userB: userB,
        startedAt: startedAt,
        intimacy: intimacy,
        level: level,
        ringId: ringId,
      );
}

class CpService {
  CourtingState state = CourtingState.none;
  String? sender;
  String? receiver;
  CpRelationship? relationship;
  final List<String> memories = <String>[];

  void request({required String from, required String to}) {
    if (relationship != null || state == CourtingState.pending) {
      throw StateError('CP flow already active');
    }
    sender = from;
    receiver = to;
    state = CourtingState.pending;
  }

  void respond({required bool accept}) {
    if (state != CourtingState.pending || sender == null || receiver == null) {
      throw StateError('No pending courting request');
    }
    state = accept ? CourtingState.accepted : CourtingState.refused;
    if (accept) {
      relationship = CpRelationship(
        userA: sender!,
        userB: receiver!,
        startedAt: DateTime.now(),
      );
    }
  }

  void addIntimacy(int value) {
    final cp = relationship;
    if (cp == null || value <= 0) return;
    relationship = cp.addIntimacy(value);
  }

  void selectRing(String ringId) {
    final cp = relationship;
    if (cp == null) return;
    relationship = cp.withRing(ringId);
  }

  void addMemory(String text) {
    if (relationship != null && text.trim().isNotEmpty) {
      memories.insert(0, text.trim());
    }
  }

  void disconnect() {
    relationship = null;
    state = CourtingState.none;
    sender = null;
    receiver = null;
  }
}
