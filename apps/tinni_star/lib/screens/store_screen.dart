import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../economy/economy.dart';
import '../ui/royal_theme.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int tab = 0;

  static const catalog = <StoreItem>[
    StoreItem(id: 'vehicle-star', name: 'Star Vehicle', price: 5000, type: 'Vehicle'),
    StoreItem(id: 'vehicle-royal', name: 'Royal Cruiser', price: 12000, type: 'Vehicle'),
    StoreItem(id: 'frame-gold', name: 'Golden Frame', price: 3500, type: 'Frame'),
    StoreItem(id: 'frame-neon', name: 'Neon Frame', price: 4500, type: 'Frame'),
    StoreItem(id: 'entry-wolf', name: 'Wolf Entry', price: 15000, type: 'Entry'),
    StoreItem(id: 'entry-phoenix', name: 'Phoenix Entry', price: 25000, type: 'Entry'),
    StoreItem(id: 'nameplate-royal', name: 'Royal Nameplate', price: 6000, type: 'Nameplate'),
    StoreItem(id: 'mic-glow', name: 'Mic Glow', price: 4200, type: 'Mic'),
  ];

  void _buy(StoreItem item) {
    final bought = widget.state.inventory.purchase(item);
    if (bought && item.type == 'Vehicle') {
      widget.state.identity.addVehicle(item.id);
    }
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
    final owned = catalog
        .where((item) => widget.state.inventory.owned.contains(item.id))
        .toList(growable: false);
    final items = tab == 0 ? catalog : owned;

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
