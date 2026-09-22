enum EntitlementType {
  vehicle,
  headwear,
  medal,
  roomTheme,
  ring,
  gift,
  goodNumber,
}

class Entitlement {
  const Entitlement({
    required this.id,
    required this.type,
    required this.expiresAt,
    this.equipped = false,
  });

  final String id;
  final EntitlementType type;
  final DateTime? expiresAt;
  final bool equipped;

  bool isExpired(DateTime now) =>
      expiresAt != null && !expiresAt!.isAfter(now);

  Entitlement copyWith({
    DateTime? expiresAt,
    bool? equipped,
  }) =>
      Entitlement(
        id: id,
        type: type,
        expiresAt: expiresAt ?? this.expiresAt,
        equipped: equipped ?? this.equipped,
      );
}

class EntitlementService {
  final Map<String, Entitlement> items = <String, Entitlement>{};

  void grant(Entitlement entitlement) {
    items[entitlement.id] = entitlement;
  }

  bool renew(String id, Duration extension, DateTime now) {
    final item = items[id];
    if (item == null || extension <= Duration.zero) return false;
    final base = item.expiresAt != null && item.expiresAt!.isAfter(now)
        ? item.expiresAt!
        : now;
    items[id] = item.copyWith(expiresAt: base.add(extension));
    return true;
  }

  bool equip(String id, DateTime now) {
    final item = items[id];
    if (item == null || item.isExpired(now)) return false;
    for (final entry in items.entries.toList()) {
      if (entry.value.type == item.type && entry.value.equipped) {
        items[entry.key] = entry.value.copyWith(equipped: false);
      }
    }
    items[id] = item.copyWith(equipped: true);
    return true;
  }
}
