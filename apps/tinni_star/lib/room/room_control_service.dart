enum RoomVisibility { publicRoom, privateRoom }

enum JoinPolicy { open, approval, adminOnly, inviteOnly }

enum MicMode { free, apply }

enum RoomRole { owner, host, admin, speaker, audience }

class RoomSettings {
  const RoomSettings({
    this.visibility = RoomVisibility.publicRoom,
    this.joinPolicy = JoinPolicy.open,
    this.micMode = MicMode.apply,
    this.onlyManagersCanSpeak = false,
    this.topic = '',
    this.backgroundId,
    this.bgmId,
  });

  final RoomVisibility visibility;
  final JoinPolicy joinPolicy;
  final MicMode micMode;
  final bool onlyManagersCanSpeak;
  final String topic;
  final String? backgroundId;
  final String? bgmId;

  RoomSettings copyWith({
    RoomVisibility? visibility,
    JoinPolicy? joinPolicy,
    MicMode? micMode,
    bool? onlyManagersCanSpeak,
    String? topic,
    String? backgroundId,
    String? bgmId,
  }) {
    return RoomSettings(
      visibility: visibility ?? this.visibility,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      micMode: micMode ?? this.micMode,
      onlyManagersCanSpeak:
          onlyManagersCanSpeak ?? this.onlyManagersCanSpeak,
      topic: topic ?? this.topic,
      backgroundId: backgroundId ?? this.backgroundId,
      bgmId: bgmId ?? this.bgmId,
    );
  }
}

class MicApplication {
  const MicApplication({
    required this.userId,
    required this.requestedSeat,
  });

  final String userId;
  final int requestedSeat;
}

class RoomControlService {
  RoomSettings settings = const RoomSettings();
  final Map<String, RoomRole> roles = <String, RoomRole>{};
  final Set<String> roomBlacklist = <String>{};
  final Set<String> invitedUsers = <String>{};
  final Set<String> micBans = <String>{};
  final Set<int> lockedSeats = <int>{};
  final Map<int, String> seatUsers = <int, String>{};
  final List<MicApplication> micApplications = <MicApplication>[];
  int? hostSeat;
  int? bossSeat;

  bool soundEnabled = true;
  bool effectsEnabled = true;
  bool noticesVisible = true;
  bool publicScreenEnabled = false;
  bool groupPkEnabled = false;
  bool eventActive = false;
  bool luckyNumberEnabled = false;
  int? luckyNumber;
  String themeId = 'royal-dark';

  void configureForRoom(String ownerUserId) {
    roles.clear();
    roomBlacklist.clear();
    invitedUsers.clear();
    micBans.clear();
    lockedSeats.clear();
    seatUsers.clear();
    micApplications.clear();
    hostSeat = null;
    bossSeat = null;
    roles[ownerUserId] = RoomRole.owner;
  }

  void setOwner(String userId) => roles[userId] = RoomRole.owner;

  void setAdmin(String userId, bool enabled) {
    if (enabled) {
      roles[userId] = RoomRole.admin;
    } else if (roles[userId] == RoomRole.admin) {
      roles[userId] = RoomRole.audience;
    }
  }

  bool canJoin(String userId) {
    if (roomBlacklist.contains(userId)) return false;
    switch (settings.joinPolicy) {
      case JoinPolicy.open:
        return true;
      case JoinPolicy.approval:
        return invitedUsers.contains(userId);
      case JoinPolicy.adminOnly:
        return roles[userId] == RoomRole.admin ||
            roles[userId] == RoomRole.owner;
      case JoinPolicy.inviteOnly:
        return invitedUsers.contains(userId);
    }
  }

  void invite(String userId) => invitedUsers.add(userId);

  void applyForMic(String userId, int seat) {
    if (micBans.contains(userId)) return;
    micApplications.removeWhere((item) => item.userId == userId);
    micApplications.add(
      MicApplication(userId: userId, requestedSeat: seat),
    );
  }

  bool approveMic(String userId) {
    final index =
        micApplications.indexWhere((item) => item.userId == userId);
    if (index < 0) return false;
    final application = micApplications.removeAt(index);
    if (lockedSeats.contains(application.requestedSeat) ||
        seatUsers.containsKey(application.requestedSeat)) {
      return false;
    }
    seatUsers[application.requestedSeat] = userId;
    roles[userId] = RoomRole.speaker;
    return true;
  }

  void rejectMic(String userId) {
    micApplications.removeWhere((item) => item.userId == userId);
  }

  void kickFromMic(String userId) {
    seatUsers.removeWhere((_, value) => value == userId);
    if (roles[userId] == RoomRole.speaker) {
      roles[userId] = RoomRole.audience;
    }
  }

  void banMic(String userId) {
    micBans.add(userId);
    kickFromMic(userId);
  }

  void unbanMic(String userId) => micBans.remove(userId);

  void kickFromRoom(String userId) {
    kickFromMic(userId);
    invitedUsers.remove(userId);
  }

  void blacklist(String userId) {
    roomBlacklist.add(userId);
    kickFromRoom(userId);
  }

  void unblacklist(String userId) => roomBlacklist.remove(userId);

  void toggleSeatLock(int seat) {
    if (!lockedSeats.add(seat)) lockedSeats.remove(seat);
  }

  void setHostSeat(int seat) => hostSeat = seat;
  void setBossSeat(int seat) => bossSeat = seat;

  bool toggleSound() => soundEnabled = !soundEnabled;
  bool toggleEffects() => effectsEnabled = !effectsEnabled;
  bool toggleNotices() => noticesVisible = !noticesVisible;
  bool togglePublicScreen() => publicScreenEnabled = !publicScreenEnabled;
  bool toggleGroupPk() => groupPkEnabled = !groupPkEnabled;
  bool toggleEvent() => eventActive = !eventActive;

  bool toggleLuckyNumber() {
    luckyNumberEnabled = !luckyNumberEnabled;
    if (!luckyNumberEnabled) luckyNumber = null;
    return luckyNumberEnabled;
  }

  void setLuckyNumber(int value) {
    if (value < 0) throw ArgumentError.value(value, 'value');
    luckyNumberEnabled = true;
    luckyNumber = value;
  }

  String cycleTheme() {
    const themes = <String>['royal-dark', 'night-blue', 'rose-gold'];
    final current = themes.indexOf(themeId);
    themeId = themes[(current + 1) % themes.length];
    return themeId;
  }

  bool canSpeak(String userId) {
    if (micBans.contains(userId)) return false;
    if (settings.onlyManagersCanSpeak) {
      return roles[userId] == RoomRole.owner ||
          roles[userId] == RoomRole.admin ||
          roles[userId] == RoomRole.host;
    }
    return roles[userId] == RoomRole.owner ||
        roles[userId] == RoomRole.admin ||
        roles[userId] == RoomRole.host ||
        roles[userId] == RoomRole.speaker;
  }
}
