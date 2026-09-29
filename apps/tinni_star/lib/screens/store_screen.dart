import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../economy/economy.dart';
import '../infra/app_backend_service.dart';
import '../ui/royal_theme.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int tab = 0;
  bool _syncing = false;
  List<StoreItem>? _remoteFrames;
  List<StoreItem>? _remoteStore;

  static const catalog = <StoreItem>[
    StoreItem(id: 'vehicle-star', name: 'Star Vehicle', price: 5000, type: 'Vehicle'),
    StoreItem(id: 'vehicle-royal', name: 'Royal Cruiser', price: 12000, type: 'Vehicle'),
    StoreItem(id: 'frame-royal-gold', name: 'Royal Gold', price: 3500, type: 'Frame'),
    StoreItem(id: 'frame-princess', name: 'Princess', price: 3800, type: 'Frame'),
    StoreItem(id: 'frame-diamond-blue', name: 'Diamond Blue', price: 4200, type: 'Frame'),
    StoreItem(id: 'frame-dragon', name: 'Dragon', price: 5200, type: 'Frame'),
    StoreItem(id: 'frame-vip', name: 'VIP', price: 6000, type: 'Frame'),
    StoreItem(id: 'frame-couple', name: 'Couple', price: 4000, type: 'Frame'),
    StoreItem(id: 'frame-crystal', name: 'Crystal', price: 4300, type: 'Frame'),
    StoreItem(id: 'frame-rose', name: 'Rose', price: 3900, type: 'Frame'),
    StoreItem(id: 'frame-tinni-star', name: 'Tinni Star', price: 4500, type: 'Frame'),
    StoreItem(id: 'frame-angel', name: 'Angel', price: 5000, type: 'Frame'),
    StoreItem(id: 'frame-panther', name: 'Panther', price: 5200, type: 'Frame'),
    StoreItem(id: 'frame-butterfly', name: 'Butterfly', price: 4200, type: 'Frame'),
    StoreItem(id: 'frame-fire', name: 'Fire', price: 4800, type: 'Frame'),
    StoreItem(id: 'frame-ocean', name: 'Ocean', price: 4400, type: 'Frame'),
    StoreItem(id: 'frame-music', name: 'Music', price: 4100, type: 'Frame'),
    StoreItem(id: 'frame-love', name: 'Love', price: 4000, type: 'Frame'),
    StoreItem(id: 'frame-car', name: 'Car', price: 5500, type: 'Frame'),
    StoreItem(id: 'frame-swan', name: 'Swan', price: 4700, type: 'Frame'),
    StoreItem(id: 'frame-nature', name: 'Nature', price: 3900, type: 'Frame'),
    StoreItem(id: 'frame-galaxy', name: 'Galaxy', price: 5200, type: 'Frame'),
    StoreItem(id: 'entry-wolf', name: 'Wolf Entry', price: 15000, type: 'Entry'),
    StoreItem(id: 'entry-phoenix', name: 'Phoenix Entry', price: 25000, type: 'Entry'),
    StoreItem(id: 'nameplate-royal', name: 'Royal Nameplate', price: 6000, type: 'Nameplate'),
    StoreItem(id: 'mic-glow', name: 'Mic Glow', price: 4200, type: 'Mic'),
  ];

  String? get _token => widget.state.auth.current?.authToken;

  @override
  void initState() {
    super.initState();
    _syncInventory();
  }

  Future<void> _syncInventory() async {
    final token = _token;
    if (token == null || token.isEmpty || _syncing) return;
    _syncing = true;
    try {
      final results = await Future.wait([
        widget.state.backend.inventory(token),
        widget.state.backend.frameCatalog(token),
        widget.state.backend.wallet(token),
        widget.state.backend.storeCatalog(token, 'vehicle'),
        widget.state.backend.storeCatalog(token, 'entry'),
        widget.state.backend.storeCatalog(token, 'profile_card'),
      ]);
      widget.state.inventory.applyRemote(results[0] as Map<String, dynamic>);
      widget.state.wallet.applyRemote(results[2] as RemoteWallet);
      final remote = results[1] as List<Map<String, dynamic>>;
      _remoteFrames = remote.map((row) {
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
        );
      }).where((item) => item.id.isNotEmpty).toList(growable: false);
      final storeRows = <Map<String, dynamic>>[
        ...(results[3] as List<Map<String, dynamic>>),
        ...(results[4] as List<Map<String, dynamic>>),
        ...(results[5] as List<Map<String, dynamic>>),
      ];
      _remoteStore = storeRows.map((row) {
        final kind = row['kind']?.toString() ?? '';
        final type = kind == 'profile_card'
            ? 'Profile Card'
            : kind == 'entry'
                ? 'Entry'
                : 'Vehicle';
        return StoreItem(
          id: row['id']?.toString() ?? '',
          name: row['name']?.toString() ?? type,
          price: (row['price_coins'] as num?)?.toInt() ?? 0,
          type: type,
        );
      }).where((item) => item.id.isNotEmpty).toList(growable: false);
    } catch (_) {
      // Keep the built-in catalog available when the backend is temporarily offline.
    } finally {
      _syncing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _useFrame(StoreItem item) async {
    final token = _token;
    var equipped = false;
    if (token != null && token.isNotEmpty) {
      try {
        final result = await widget.state.backend.equipFrame(token, item.id);
        widget.state.inventory.applyRemote(
          Map<String, dynamic>.from(result['inventory'] as Map),
        );
        equipped = widget.state.inventory.equippedFrameId == item.id;
      } catch (_) {}
    } else {
      equipped = widget.state.inventory.equipFrame(item.id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          equipped
              ? item.name + ' frame is now active.'
              : 'This frame is not in your Inventory.',
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _removeFrame() async {
    final token = _token;
    if (token != null && token.isNotEmpty) {
      try {
        final result = await widget.state.backend.equipFrame(token, null);
        widget.state.inventory.applyRemote(
          Map<String, dynamic>.from(result['inventory'] as Map),
        );
      } catch (_) {
        return;
      }
    } else {
      widget.state.inventory.removeFrame();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avatar frame removed.')),
    );
    setState(() {});
  }

  Future<void> _buy(StoreItem item) async {
    var bought = false;
    final token = _token;
    if (token != null && token.isNotEmpty) {
      try {
        final Map<String, dynamic> result;
        if (item.type == 'Frame') {
          result = await widget.state.backend.purchaseFrame(token, item.id);
        } else {
          final kind = item.type == 'Profile Card'
              ? 'profile_card'
              : item.type.toLowerCase();
          result = await widget.state.backend.purchaseStoreItem(token, kind, item.id);
        }
        widget.state.inventory.applyRemote(
          Map<String, dynamic>.from(result['inventory'] as Map),
        );
        final wallet = Map<String, dynamic>.from(result['wallet'] as Map);
        widget.state.wallet.applyRemote(RemoteWallet(
          coins: (wallet['coins'] as num?)?.toInt() ?? widget.state.wallet.coins,
          diamonds: (wallet['diamonds'] as num?)?.toInt() ?? widget.state.wallet.diamonds,
          banned: wallet['banned'] == true,
          updatedAt: (wallet['updated_at'] as num?)?.toInt() ?? 0,
        ));
        bought = widget.state.inventory.owned.contains(item.id);
      } catch (_) {}
    }
    if (bought && item.type == 'Vehicle') {
      widget.state.identity.addVehicle(item.id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          bought
              ? item.name + ' added to Inventory.'
              : widget.state.inventory.owned.contains(item.id)
                  ? 'Already owned.'
                  : 'Not enough coins.',
        ),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dynamicCatalog = <StoreItem>[
      ...?_remoteStore,
      if (_remoteFrames != null && _remoteFrames!.isNotEmpty)
        ..._remoteFrames!
      else
        ...catalog.where((item) => item.type == 'Frame'),
    ];
    final owned = dynamicCatalog
        .where((item) => widget.state.inventory.owned.contains(item.id))
        .toList(growable: false);
    final items = tab == 0 ? dynamicCatalog : owned;

    return Scaffold(
      key: const Key('store-screen'),
      appBar: AppBar(
        title: const Text(
          'Store / Inventory',
          style: TextStyle(
            color: FeaturePalette.store,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Store'),
                    selected: tab == 0,
                    onSelected: (_) => setState(() => tab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text('Inventory (' + owned.length.toString() + ')'),
                    selected: tab == 1,
                    onSelected: (_) => setState(() => tab = 1),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Coins ' + widget.state.wallet.coins.toString(),
                style: const TextStyle(
                  color: FeaturePalette.wallet,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Inventory is empty.',
                      style: TextStyle(color: RoyalPalette.muted),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.92,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final isOwned =
                          widget.state.inventory.owned.contains(item.id);
                      return RoyalPanel(
                        gradient: FeaturePalette.glow(FeaturePalette.store),
                        accentColor: FeaturePalette.store,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const ShiningIcon(
                              icon: Icons.storefront_rounded,
                              color: FeaturePalette.store,
                              size: 28,
                              boxSize: 52,
                              glow: 0.36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: RoyalPalette.cream,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              item.type,
                              style: const TextStyle(
                                color: RoyalPalette.muted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.price.toString() + ' coins',
                              style: const TextStyle(
                                color: FeaturePalette.wallet,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (item.type == 'Frame' && isOwned)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FilledButton(
                                    onPressed:
                                        widget.state.inventory.equippedFrameId ==
                                                item.id
                                            ? null
                                            : () => _useFrame(item),
                                    child: Text(
                                      widget.state.inventory.equippedFrameId ==
                                              item.id
                                          ? 'Using'
                                          : 'Use',
                                    ),
                                  ),
                                  if (widget.state.inventory.equippedFrameId ==
                                      item.id) ...[
                                    const SizedBox(width: 6),
                                    TextButton(
                                      onPressed: _removeFrame,
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ],
                              )
                            else
                              FilledButton(
                                onPressed: isOwned || tab == 1
                                    ? null
                                    : () => _buy(item),
                                child: Text(isOwned ? 'Owned' : 'Buy'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
