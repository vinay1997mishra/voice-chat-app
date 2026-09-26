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

  Color _giftColor(GiftDefinition gift, int index) {
    final id = (gift.id + ' ' + gift.name).toLowerCase();
    if (id.contains('heart') || id.contains('ring') || category == 'CP') {
      return FeaturePalette.cp;
    }
    if (id.contains('dragon') || id.contains('crown')) {
      return FeaturePalette.rank;
    }
    if (id.contains('castle')) return FeaturePalette.vip;
    const colors = <Color>[
      FeaturePalette.gift,
      FeaturePalette.cp,
      FeaturePalette.vip,
      FeaturePalette.music,
      FeaturePalette.rocket,
      FeaturePalette.family,
    ];
    return colors[index % colors.length];
  }

  Color _categoryColor(String value) {
    switch (value) {
      case 'Luxury':
        return FeaturePalette.vip;
      case 'CP':
        return FeaturePalette.cp;
      case 'Backpack':
        return FeaturePalette.backpack;
      case 'Normal':
        return FeaturePalette.social;
      default:
        return FeaturePalette.gift;
    }
  }

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
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final value = categories[index];
                final color = _categoryColor(value);
                return ChoiceChip(
                  label: Text(value),
                  selected: category == value,
                  selectedColor: color.withValues(alpha: 0.28),
                  side: BorderSide(
                    color: category == value
                        ? color
                        : RoyalPalette.bronze,
                  ),
                  labelStyle: TextStyle(
                    color: category == value
                        ? color
                        : RoyalPalette.cream,
                    fontWeight: FontWeight.w800,
                  ),
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
                final color = _giftColor(gift, index);
                return RoyalPanel(
                  padding: const EdgeInsets.all(8),
                  gradient: FeaturePalette.glow(color),
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
                                color.withValues(alpha: 0.46),
                                RoyalPalette.panel,
                              ],
                            ),
                            border: Border.all(
                              color: color.withValues(alpha: 0.72),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.26),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Icon(
                            index.isEven
                                ? Icons.auto_awesome_rounded
                                : Icons.card_giftcard_rounded,
                            color: color,
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
