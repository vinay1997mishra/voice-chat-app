import 'package:flutter/foundation.dart';

class AppOwnerControlsV08 extends ChangeNotifier {
  bool maintenanceMode = false;
  bool roomCreationEnabled = true;
  bool giftsEnabled = true;
  bool videoGiftsEnabled = true;
  bool threeDEffectsEnabled = true;
  bool giftAnimationsEnabled = true;
  bool gamesEnabled = true;
  bool ludoEnabled = true;
  bool unoEnabled = true;
  bool carromEnabled = true;
  bool luckyDiceEnabled = true;
  bool luckyWheelEnabled = true;
  bool privateMessagesEnabled = true;

  int ownerGiftSharePercent = 10;
  int diamondsPerCoin = 2;

  String announcement = 'Welcome to Voice Chat v0.8';

  final Set<String> globalAdminIds = <String>{'10000001'};
  final Set<String> bannedUserIds = <String>{};
  final Map<String, int> userVipLevels = <String, int>{
    '10000000': 11,
    '10000001': 5,
    '10000011': 3,
    '10000012': 2,
  };
  final List<String> openReports = <String>[
    'Aisha • Spam report',
    'Sam • Abusive-language report',
  ];
  final List<String> auditLog = <String>[
    'Owner controls initialized for v0.8',
  ];

  bool gameEnabled(String game) {
    if (!gamesEnabled) return false;
    return switch (game) {
      'Ludo' => ludoEnabled,
      'UNO' => unoEnabled,
      'Carrom' => carromEnabled,
      'Lucky Dice' => luckyDiceEnabled,
      'Lucky Wheel' => luckyWheelEnabled,
      _ => true,
    };
  }

  void setMaintenance(bool value) {
    maintenanceMode = value;
    _record('Maintenance mode ' + (value ? 'enabled' : 'disabled'));
  }

  void setRoomCreation(bool value) {
    roomCreationEnabled = value;
    _record('Room creation ' + (value ? 'enabled' : 'disabled'));
  }

  void setGifts(bool value) {
    giftsEnabled = value;
    _record('Gift sending ' + (value ? 'enabled' : 'disabled'));
  }

  void setVideoGifts(bool value) {
    videoGiftsEnabled = value;
    _record('Video gifts ' + (value ? 'enabled' : 'disabled'));
  }

  void setThreeDEffects(bool value) {
    threeDEffectsEnabled = value;
    _record('3D gift effects ' + (value ? 'enabled' : 'disabled'));
  }

  void setGiftAnimations(bool value) {
    giftAnimationsEnabled = value;
    _record('Gift animations ' + (value ? 'enabled' : 'disabled'));
  }

  void setGames(bool value) {
    gamesEnabled = value;
    _record('Game Center ' + (value ? 'enabled' : 'disabled'));
  }

  void setGame(String game, bool value) {
    switch (game) {
      case 'Ludo':
        ludoEnabled = value;
      case 'UNO':
        unoEnabled = value;
      case 'Carrom':
        carromEnabled = value;
      case 'Lucky Dice':
        luckyDiceEnabled = value;
      case 'Lucky Wheel':
        luckyWheelEnabled = value;
    }
    _record(game + ' ' + (value ? 'enabled' : 'disabled'));
  }

  void setPrivateMessages(bool value) {
    privateMessagesEnabled = value;
    _record('Private messages ' + (value ? 'enabled' : 'disabled'));
  }

  void setAnnouncement(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    announcement = clean;
    _record('Global announcement updated');
  }

  void setAdmin(String userId, bool value) {
    if (value) {
      globalAdminIds.add(userId);
    } else {
      globalAdminIds.remove(userId);
    }
    _record('Admin role ' + (value ? 'granted to ' : 'removed from ') + userId);
  }

  void setBanned(String userId, bool value) {
    if (value) {
      bannedUserIds.add(userId);
      globalAdminIds.remove(userId);
    } else {
      bannedUserIds.remove(userId);
    }
    _record('User ' + userId + (value ? ' banned' : ' unbanned'));
  }

  void setVip(String userId, int level) {
    userVipLevels[userId] = level.clamp(0, 11);
    _record('VIP for ' + userId + ' set to ' + level.clamp(0, 11).toString());
  }

  void setOwnerGiftSharePercent(int value) {
    ownerGiftSharePercent = value.clamp(0, 30);
    _record('Owner gift share set to ' + ownerGiftSharePercent.toString() + '%');
  }

  void setDiamondsPerCoin(int value) {
    diamondsPerCoin = value < 1 ? 1 : value;
    _record('Diamond conversion set to ' + diamondsPerCoin.toString() + ':1');
  }

  void resolveReport(String report) {
    openReports.remove(report);
    _record('Moderation report resolved: ' + report);
  }

  void clearBans() {
    bannedUserIds.clear();
    _record('All global bans cleared');
  }

  void _record(String message) {
    auditLog.insert(0, message);
    if (auditLog.length > 100) auditLog.removeLast();
    notifyListeners();
  }

  void refresh() => notifyListeners();
}

final appOwnerControlsV08 = AppOwnerControlsV08();
