import 'package:flutter/foundation.dart';

enum OwnerControlGroup {
  dashboard,
  users,
  rooms,
  wallets,
  hierarchy,
  policies,
  content,
  games,
  system,
}

class OwnerAuditEntry {
  const OwnerAuditEntry({
    required this.action,
    required this.target,
    required this.details,
    required this.at,
  });

  final String action;
  final String target;
  final String details;
  final DateTime at;
}

class OwnerVipDefinition {
  OwnerVipDefinition({
    required this.level,
    required this.name,
    this.enabled = true,
    this.priceCoins = 0,
    this.durationDays = 30,
    this.entryName = '',
    this.frameName = '',
  });

  final int level;
  String name;
  bool enabled;
  int priceCoins;
  int durationDays;
  String entryName;
  String frameName;
}

class OwnerCustomPanel {
  OwnerCustomPanel({
    required this.id,
    required this.name,
    Set<String>? permissions,
    this.enabled = true,
  }) : permissions = permissions ?? <String>{};

  final String id;
  String name;
  bool enabled;
  final Set<String> permissions;
}

class OwnerPanelService extends ChangeNotifier {
  static const String ownerUserId = '10000000';

  int _treasuryCoins = 0;
  int get treasuryCoins => _treasuryCoins;

  final Map<String, bool> _featureFlags = <String, bool>{
    'voice_rooms': true,
    'gifts': true,
    'vip': true,
    'games': true,
    'host_system': true,
    'agency_system': true,
    'bd_system': true,
    'coin_seller': true,
    'merchant': true,
    'banners': true,
    'vehicle_entries': true,
    'frames': true,
  };

  Map<String, bool> get featureFlags => Map.unmodifiable(_featureFlags);

  final List<OwnerAuditEntry> _audit = <OwnerAuditEntry>[];
  List<OwnerAuditEntry> get audit => List.unmodifiable(_audit.reversed);

  final List<OwnerVipDefinition> _vips = <OwnerVipDefinition>[
    OwnerVipDefinition(level: 1, name: 'VIP 1'),
    OwnerVipDefinition(level: 2, name: 'VIP 2'),
    OwnerVipDefinition(level: 3, name: 'VIP 3'),
    OwnerVipDefinition(level: 4, name: 'VIP 4'),
    OwnerVipDefinition(level: 5, name: 'VIP 5'),
    OwnerVipDefinition(level: 6, name: 'VIP 6'),
    OwnerVipDefinition(level: 7, name: 'VIP 7'),
    OwnerVipDefinition(level: 8, name: 'VIP 8'),
    OwnerVipDefinition(level: 9, name: 'VIP 9'),
    OwnerVipDefinition(level: 10, name: 'VIP 10'),
    OwnerVipDefinition(level: 11, name: 'VIP 11'),
  ];

  List<OwnerVipDefinition> get vips => List.unmodifiable(_vips);

  final List<OwnerCustomPanel> _customPanels = <OwnerCustomPanel>[];
  List<OwnerCustomPanel> get customPanels => List.unmodifiable(_customPanels);

  final Map<String, num> policyValues = <String, num>{
    'coins_per_usd': 2000000,
    'diamonds_per_coin': 1,
    'room_online_exp_per_minute': 50,
    'room_online_daily_minutes_cap': 480,
    'host_first_target_received_coins': 4000000,
    'host_first_target_usd': 1.6,
    'agency_commission_percent': 20,
    'bd_target_1_usd': 500,
    'bd_target_1_percent': 7,
    'bd_target_2_usd': 1000,
    'bd_target_2_percent': 10,
    'minimum_transfer_usd': 2,
  };

  bool isOwner(String? userId) => userId == ownerUserId;

  void setFeature(String key, bool enabled) {
    _featureFlags[key] = enabled;
    _log('feature_toggle', key, enabled ? 'enabled' : 'disabled');
    notifyListeners();
  }

  void addTreasuryCoins(int amount) {
    if (amount <= 0) return;
    final before = _treasuryCoins;
    _treasuryCoins += amount;
    _log(
      'treasury_mint',
      'owner_treasury',
      'coins $before -> $_treasuryCoins (+$amount)',
    );
    notifyListeners();
  }

  bool debitTreasury({
    required int amount,
    required String receiverId,
    required String walletType,
  }) {
    if (amount <= 0 || amount > _treasuryCoins) return false;
    final before = _treasuryCoins;
    _treasuryCoins -= amount;
    _log(
      'treasury_send',
      receiverId,
      '$walletType +$amount; treasury $before -> $_treasuryCoins',
    );
    notifyListeners();
    return true;
  }

  void setPolicy(String key, num value) {
    final old = policyValues[key];
    policyValues[key] = value;
    _log('policy_change', key, '$old -> $value');
    notifyListeners();
  }

  void addVip({
    required String name,
    int priceCoins = 0,
    int durationDays = 30,
  }) {
    final next = _vips.isEmpty
        ? 1
        : _vips.map((e) => e.level).reduce((a, b) => a > b ? a : b) + 1;
    _vips.add(
      OwnerVipDefinition(
        level: next,
        name: name,
        priceCoins: priceCoins,
        durationDays: durationDays,
      ),
    );
    _log('vip_add', 'VIP $next', name);
    notifyListeners();
  }

  void updateVip(
    OwnerVipDefinition vip, {
    String? name,
    bool? enabled,
    int? priceCoins,
    int? durationDays,
    String? entryName,
    String? frameName,
  }) {
    if (name != null) vip.name = name;
    if (enabled != null) vip.enabled = enabled;
    if (priceCoins != null) vip.priceCoins = priceCoins;
    if (durationDays != null) vip.durationDays = durationDays;
    if (entryName != null) vip.entryName = entryName;
    if (frameName != null) vip.frameName = frameName;
    _log('vip_update', 'VIP ${vip.level}', vip.name);
    notifyListeners();
  }

  void removeVip(int level) {
    _vips.removeWhere((v) => v.level == level);
    _log('vip_remove', 'VIP $level', 'removed');
    notifyListeners();
  }

  void addCustomPanel({
    required String name,
    Set<String>? permissions,
  }) {
    final id = 'panel_${DateTime.now().microsecondsSinceEpoch}';
    _customPanels.add(
      OwnerCustomPanel(
        id: id,
        name: name,
        permissions: permissions,
      ),
    );
    _log('custom_panel_add', id, name);
    notifyListeners();
  }

  void setPanelPermission(
    OwnerCustomPanel panel,
    String permission,
    bool allowed,
  ) {
    if (allowed) {
      panel.permissions.add(permission);
    } else {
      panel.permissions.remove(permission);
    }
    _log(
      'panel_permission',
      panel.id,
      '$permission=$allowed',
    );
    notifyListeners();
  }

  void setPanelEnabled(OwnerCustomPanel panel, bool enabled) {
    panel.enabled = enabled;
    _log('panel_status', panel.id, enabled ? 'enabled' : 'disabled');
    notifyListeners();
  }

  void recordOwnerAction({
    required String action,
    required String target,
    required String details,
  }) {
    _log(action, target, details);
    notifyListeners();
  }

  void _log(String action, String target, String details) {
    _audit.add(
      OwnerAuditEntry(
        action: action,
        target: target,
        details: details,
        at: DateTime.now(),
      ),
    );
  }
}
