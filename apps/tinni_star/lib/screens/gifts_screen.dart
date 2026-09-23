import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../economy/economy.dart';
import '../effects/effect_queue.dart';
import '../ui/royal_theme.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  String category = 'Popular';

  List<GiftDefinition> get gifts => const [
        GiftDefinition(id: 'gold-dragon', name: 'Golden Dragon', price: 5000, effectKind: 'mp4'),
        GiftDefinition(id: 'royal-crown', name: 'Royal Crown', price: 2500, effectKind: 'pag'),
        GiftDefinition(id: 'star-castle', name: 'Star Castle', price: 12000, effectKind: 'mp4'),
        GiftDefinition(id: 'heart-ring', name: 'Heart Ring', price: 1800, effectKind: 'svga'),
        ...GiftService.catalog,
      ];

  void send(GiftDefinition gift) {
    final tx = widget.state.gifts.send(
      gift: gift,
      quantity: 1,
      maxCombo: 1000,
      senderId: '10000000',
      receiverIds: const ['room-owner'],
    );
    if (tx != null) {
      widget.state.effects.enqueue(
        EffectRequest(
          id: 'gift-ui-' + widget.state.gifts.sent.length.toString(),
          kind: EffectKind.gift,
          asset: gift.effectKind + ':' + gift.id,
          priority: 60,
        ),
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx == null ? 'Insufficient coins.' : gift.name + ' sent.')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['Popular', 'Normal', 'Luxury', 'CP', 'Backpack'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '🪙 ' + widget.state.wallet.coins.toString(),
                style: const TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final value = categories[index];
                return ChoiceChip(
                  label: Text(value),
                  selected: category == value,
                  onSelected: (_) => setState(() => category = value),
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: gifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.72,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (_, index) {
                final gift = gifts[index];
                return RoyalPanel(
                  padding: const EdgeInsets.all(8),
                  onTap: () => send(gift),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                RoyalPalette.gold.withValues(alpha: 0.32),
                                RoyalPalette.panel,
                              ],
                            ),
                          ),
                          child: Icon(
                            index.isEven ? Icons.auto_awesome_rounded : Icons.card_giftcard_rounded,
                            color: RoyalPalette.gold,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        gift.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RoyalPalette.cream,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '🪙 ' + gift.price.toString(),
                        style: const TextStyle(color: RoyalPalette.gold, fontSize: 10),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: RoyalPalette.nearBlack,
                border: Border(top: BorderSide(color: RoyalPalette.deepGold)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.backpack_rounded, color: RoyalPalette.gold),
                  SizedBox(width: 8),
                  Text('Backpack'),
                  Spacer(),
                  Text('Tap any gift to send', style: TextStyle(color: RoyalPalette.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
