import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../economy/economy.dart';
import '../infra/app_backend_service.dart';
import '../ui/royal_theme.dart';
import 'unique_id_store_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({
    super.key,
    required this.state,
    this.initialKind,
  });
  final TinniState state;
  final String? initialKind;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreCategory {
  const _StoreCategory(this.label, this.kind, this.icon);
  final String label;
  final String kind;
  final IconData icon;
}

class _StoreScreenState extends State<StoreScreen> {
  static const _categories = <_StoreCategory>[
    _StoreCategory('Car', 'vehicle', Icons.directions_car_filled_rounded),
    _StoreCategory('Profile', 'profile_card', Icons.badge_rounded),
    _StoreCategory('Lucky', 'unique_id', Icons.numbers_rounded),
    _StoreCategory('Ring', 'ring', Icons.circle_outlined),
    _StoreCategory(
      'Profile Background',
      'profile_background',
      Icons.wallpaper_rounded,
    ),
    _StoreCategory('Entrance', 'entry', Icons.auto_awesome_rounded),
    _StoreCategory('Bubble', 'bubble', Icons.chat_bubble_rounded),
    _StoreCategory('Frame', 'frame', Icons.account_box_rounded),
  ];

  int _categoryIndex = 0;
  bool _inventoryOnly = false;
  bool _loading = true;
  String? _error;
  final Map<String, List<StoreItem>> _catalogs = <String, List<StoreItem>>{};

  String? get _token => widget.state.auth.current?.authToken;

  _StoreCategory get _category => _categories[_categoryIndex];

  @override
  void initState() {
    super.initState();
    final initialKind = widget.initialKind;
    if (initialKind != null) {
      final index = _categories.indexWhere((item) => item.kind == initialKind);
      if (index >= 0 && _categories[index].kind != 'unique_id') {
        _categoryIndex = index;
      }
    }
    _loadAll();
  }

  Future<void> _loadAll() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Login required';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.state.backend.inventory(token),
        widget.state.backend.wallet(token),
        widget.state.backend.frameCatalog(token),
        widget.state.backend.storeCatalog(token, 'vehicle'),
        widget.state.backend.storeCatalog(token, 'profile_card'),
        widget.state.backend.storeCatalog(token, 'ring'),
        widget.state.backend.storeCatalog(token, 'profile_background'),
        widget.state.backend.storeCatalog(token, 'entry'),
        widget.state.backend.storeCatalog(token, 'bubble'),
      ]);
      widget.state.inventory.applyRemote(
        Map<String, dynamic>.from(results[0] as Map),
      );
      widget.state.wallet.applyRemote(results[1] as RemoteWallet);
      _catalogs['frame'] = _mapFrames(results[2] as List);
      _catalogs['vehicle'] = _mapCatalog(results[3] as List, 'vehicle', 'Car');
      _catalogs['profile_card'] =
          _mapCatalog(results[4] as List, 'profile_card', 'Profile');
      _catalogs['ring'] = _mapCatalog(results[5] as List, 'ring', 'Ring');
      _catalogs['profile_background'] = _mapCatalog(
        results[6] as List,
        'profile_background',
        'Profile Background',
      );
      _catalogs['entry'] =
          _mapCatalog(results[7] as List, 'entry', 'Entrance');
      _catalogs['bubble'] =
          _mapCatalog(results[8] as List, 'bubble', 'Bubble');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  List<StoreItem> _mapFrames(List raw) {
    return raw.whereType<Map>().map((rawRow) {
      final row = Map<String, dynamic>.from(rawRow);
      final data = row['data'] is Map
          ? Map<String, dynamic>.from(row['data'] as Map)
          : <String, dynamic>{};
      return StoreItem(
        id: row['id']?.toString() ?? '',
        name: row['name']?.toString() ?? 'Frame',
        price: (row['price'] as num?)?.toInt() ??
            (data['price'] as num?)?.toInt() ??
            (data['coin_price'] as num?)?.toInt() ??
            0,
        type: 'Frame',
        kind: 'frame',
        durationDays: (data['duration_days'] as num?)?.toInt() ?? 0,
        assetUrl: data['asset_url']?.toString() ?? '',
      );
    }).where((item) => item.id.isNotEmpty).toList(growable: false);
  }

  List<StoreItem> _mapCatalog(List raw, String kind, String type) {
    return raw.whereType<Map>().map((rawRow) {
      final row = Map<String, dynamic>.from(rawRow);
      final data = row['data'] is Map
          ? Map<String, dynamic>.from(row['data'] as Map)
          : <String, dynamic>{};
      return StoreItem(
        id: row['id']?.toString() ?? '',
        name: row['name']?.toString() ?? type,
        price: (row['price_coins'] as num?)?.toInt() ??
            (data['coin_price'] as num?)?.toInt() ??
            (data['price'] as num?)?.toInt() ??
            0,
        type: type,
        kind: kind,
        durationDays: (row['duration_days'] as num?)?.toInt() ??
            (data['duration_days'] as num?)?.toInt() ??
            0,
        assetUrl: data['asset_url']?.toString() ?? '',
      );
    }).where((item) => item.id.isNotEmpty).toList(growable: false);
  }

  List<StoreItem> get _visibleItems {
    final items = _catalogs[_category.kind] ?? const <StoreItem>[];
    if (!_inventoryOnly) return items;
    return items
        .where((item) => widget.state.inventory.owned.contains(item.id))
        .toList(growable: false);
  }

  String _validity(StoreItem item) =>
      item.permanent ? 'Permanent' : item.durationDays.toString() + ' day';

  IconData _iconFor(StoreItem item) {
    switch (item.kind) {
      case 'vehicle':
        return Icons.directions_car_filled_rounded;
      case 'profile_card':
        return Icons.badge_rounded;
      case 'ring':
        return Icons.circle_outlined;
      case 'profile_background':
        return Icons.wallpaper_rounded;
      case 'entry':
        return Icons.auto_awesome_rounded;
      case 'bubble':
        return Icons.chat_bubble_rounded;
      case 'frame':
        return Icons.account_box_rounded;
      default:
        return Icons.storefront_rounded;
    }
  }

  Future<void> _buy(StoreItem item) async {
    final token = _token;
    if (token == null) return;
    try {
      final result = item.kind == 'frame'
          ? await widget.state.backend.purchaseFrame(token, item.id)
          : await widget.state.backend.purchaseStoreItem(
              token,
              item.kind,
              item.id,
            );
      final inventory = result['inventory'];
      if (inventory is Map) {
        widget.state.inventory.applyRemote(
          Map<String, dynamic>.from(inventory),
        );
      }
      final wallet = await widget.state.backend.wallet(token);
      widget.state.wallet.applyRemote(wallet);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(item.name + ' added to Inventory.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _equip(StoreItem item) async {
    final token = _token;
    if (token == null) return;
    try {
      final result = item.kind == 'frame'
          ? await widget.state.backend.equipFrame(token, item.id)
          : await widget.state.backend.equipStoreItem(
              token,
              kind: item.kind,
              itemId: item.id,
            );
      final inventory = result['inventory'];
      if (inventory is Map) {
        widget.state.inventory.applyRemote(
          Map<String, dynamic>.from(inventory),
        );
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(item.name + ' is now active.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _remove(StoreItem item) async {
    final token = _token;
    if (token == null) return;
    try {
      final result = item.kind == 'frame'
          ? await widget.state.backend.equipFrame(token, null)
          : await widget.state.backend.equipStoreItem(
              token,
              kind: item.kind,
              itemId: null,
            );
      final inventory = result['inventory'];
      if (inventory is Map) {
        widget.state.inventory.applyRemote(
          Map<String, dynamic>.from(inventory),
        );
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _send(StoreItem item) async {
    final token = _token;
    if (token == null) return;
    final controller = TextEditingController();
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Send ' + item.name),
        content: TextField(
          key: const Key('store-send-user-id'),
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Recipient User ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(dialogContext, id);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (target == null || target.isEmpty || !mounted) return;
    try {
      await widget.state.backend.sendStoreItem(
        token,
        recipientUserId: target,
        kind: item.kind,
        itemId: item.id,
      );
      widget.state.wallet.applyRemote(await widget.state.backend.wallet(token));
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(item.name + ' sent to ID ' + target + '.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _preview(StoreItem item) async {
    final owned = widget.state.inventory.owned.contains(item.id);
    final equipped = widget.state.inventory.isEquipped(item.kind, item.id);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: RoyalPalette.nearBlack,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.assetUrl.startsWith('http'))
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    item.assetUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _previewIcon(item),
                  ),
                )
              else
                _previewIcon(item),
              const SizedBox(height: 14),
              Text(
                item.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RoyalPalette.cream,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _validity(item) + ' • ' + item.price.toString() + ' coins',
                style: const TextStyle(color: RoyalPalette.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!owned)
                    FilledButton(
                      key: const Key('store-preview-buy'),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _buy(item);
                      },
                      child: const Text('Purchase'),
                    ),
                  if (!owned)
                    OutlinedButton(
                      key: const Key('store-preview-send'),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _send(item);
                      },
                      child: const Text('Send'),
                    ),
                  if (owned && !equipped)
                    FilledButton(
                      key: const Key('store-preview-use'),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _equip(item);
                      },
                      child: const Text('Use'),
                    ),
                  if (owned && equipped)
                    OutlinedButton(
                      key: const Key('store-preview-remove'),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _remove(item);
                      },
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewIcon(StoreItem item) {
    return Container(
      height: 210,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: FeaturePalette.glow(FeaturePalette.store),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FeaturePalette.store),
      ),
      child: ShiningIcon(
        icon: _iconFor(item),
        color: FeaturePalette.store,
        size: 78,
        boxSize: 126,
        glow: 0.55,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_category.kind == 'unique_id') {
      // Keep Lucky/ID in the same category rail while using its secure
      // dedicated purchase flow.
    }

    return Scaffold(
      key: const Key('store-screen'),
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        title: const Text(
          'Shop',
          style: TextStyle(
            color: FeaturePalette.store,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'Coins ' + widget.state.wallet.coins.toString(),
                style: const TextStyle(
                  color: FeaturePalette.wallet,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 92,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              itemCount: _categories.length,
              itemBuilder: (_, index) {
                final item = _categories[index];
                final selected = index == _categoryIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    key: Key('store-category-' + item.kind),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (item.kind == 'unique_id') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UniqueIdStoreScreen(state: widget.state),
                          ),
                        );
                        return;
                      }
                      setState(() => _categoryIndex = index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? FeaturePalette.store.withValues(alpha: 0.18)
                            : RoyalPalette.nearBlack,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? FeaturePalette.store
                              : RoyalPalette.deepGold,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            item.icon,
                            color: selected
                                ? FeaturePalette.store
                                : RoyalPalette.muted,
                            size: 20,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected
                                  ? FeaturePalette.store
                                  : RoyalPalette.cream,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1, color: RoyalPalette.deepGold),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _category.label,
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      FilterChip(
                        label: const Text('My items'),
                        selected: _inventoryOnly,
                        onSelected: (value) =>
                            setState(() => _inventoryOnly = value),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _loading ? null : _loadAll,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                Expanded(
                  child: !_loading && _visibleItems.isEmpty
                      ? Center(
                          child: Text(
                            _inventoryOnly
                                ? 'No owned items in this category.'
                                : 'No ' +
                                    _category.label +
                                    ' items added yet.',
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: RoyalPalette.muted),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
                          itemCount: _visibleItems.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.82,
                            mainAxisSpacing: 9,
                            crossAxisSpacing: 9,
                          ),
                          itemBuilder: (_, index) {
                            final item = _visibleItems[index];
                            final owned =
                                widget.state.inventory.owned.contains(item.id);
                            final equipped = widget.state.inventory
                                .isEquipped(item.kind, item.id);
                            return InkWell(
                              key: Key('store-item-' + item.id),
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _preview(item),
                              child: RoyalPanel(
                                gradient:
                                    FeaturePalette.glow(FeaturePalette.store),
                                accentColor: equipped
                                    ? FeaturePalette.wallet
                                    : FeaturePalette.store,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ShiningIcon(
                                      icon: _iconFor(item),
                                      color: FeaturePalette.store,
                                      size: 28,
                                      boxSize: 52,
                                      glow: 0.34,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: RoyalPalette.cream,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _validity(item),
                                      style: const TextStyle(
                                        color: RoyalPalette.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      item.price.toString() + ' coins',
                                      style: const TextStyle(
                                        color: FeaturePalette.wallet,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      equipped
                                          ? 'Using'
                                          : owned
                                              ? 'Owned • Tap to preview'
                                              : 'Tap to preview',
                                      style: TextStyle(
                                        color: equipped
                                            ? FeaturePalette.wallet
                                            : RoyalPalette.muted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
