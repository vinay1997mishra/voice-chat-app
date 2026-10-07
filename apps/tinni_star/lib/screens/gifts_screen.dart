import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../economy/economy.dart';
import '../economy/enemy_gift_catalog.dart';
import '../economy/premium_gift_catalog.dart';
import '../effects/cinematic_video.dart';
import '../effects/effect_queue.dart';
import '../effects/gift_scene_overlay.dart';
import '../infra/app_backend_service.dart';
import 'store_screen.dart';
import '../ui/royal_theme.dart';
import '../ui/animated_emoji.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({
    super.key,
    required this.state,
    this.initialCategory = 'Popular',
  });
  final TinniState state;
  final String initialCategory;

  /// Use the same IDs, prices and art as the room's authoritative gift catalog.
  static List<GiftDefinition> catalogFor(String category) => switch (category) {
    'Normal' => PremiumGiftCatalog.normal,
    'Lucky' => GiftService.luckyCatalog,
    'CP' => PremiumGiftCatalog.cp,
    'VS' => EnemyGiftCatalog.gifts,
    'Country' => PremiumGiftCatalog.countries,
    'Luxury' => PremiumGiftCatalog.normal.where((gift) => gift.price >= 1000000).toList(growable: false),
    _ => [
      ...PremiumGiftCatalog.normal,
      ...PremiumGiftCatalog.cp,
      ...EnemyGiftCatalog.gifts,
      ...GiftService.luckyCatalog,
    ],
  };

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  late String category;
  bool sending = false;
  final _scenes=GiftSceneQueue();
  @override
  void dispose(){_scenes.dispose();super.dispose();}

  @override
  void initState() {
    super.initState();
    category = widget.initialCategory;
    _refreshCatalog();
  }

  Future<void> _refreshCatalog() async {
    try { await widget.state.refreshGiftCatalog(); if (mounted) setState(() {}); } catch (_) {}
  }

  Color _giftColor(GiftDefinition gift, int index) {
    final id = (gift.id + ' ' + gift.name).toLowerCase();
    if (category == 'VS' || id.startsWith('enemy-')) {
      return const Color(0xFFFF202D);
    }
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
      case 'VS':
        return const Color(0xFFFF202D);
      case 'Backpack':
        return FeaturePalette.backpack;
      case 'Normal':
        return FeaturePalette.social;
      default:
        return FeaturePalette.gift;
    }
  }

  List<GiftDefinition> get gifts => widget.state.gifts.catalogFor(category, GiftsScreen.catalogFor(category));

  Future<void> send(GiftDefinition gift) async {
    if (sending) return;
    final account = widget.state.auth.current;
    final session = widget.state.roomSession;
    final room = session.room;
    if (account == null || room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join a voice room and select a recipient to send a gift.')),
      );
      return;
    }
    final members = session.liveMembers.where((member) => member.userId != account.userId).toList();
    final recipient = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Send gift to'),
        children: [
          if (members.isEmpty) const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No other users are in this room yet.'),
          ),
          for (final member in members) SimpleDialogOption(
            onPressed: () => Navigator.pop(context, member.userId),
            child: Text(member.displayName),
          ),
        ],
      ),
    );
    if (!mounted || recipient == null || sending) return;
    setState(() => sending = true);
    try {
      final response = await session.sendGift(
        roomId: room.id, authToken: account.authToken,
        giftId: gift.id, giftName: gift.name, quantity: 1,
        unitPrice: gift.price, receiverIds: [recipient],
      );
      widget.state.applyConfirmedGiftRelationships(response);
      final transactions=response['transactions'] as List? ?? const [];
      final confirmedGift=transactions.isEmpty?gift:gift.withServerMetadata(Map<String,dynamic>.from(transactions.first as Map));
      _scenes.add(GiftSceneEvent(gift:confirmedGift,recipients:[recipient]));
      final wallet = response['wallet'];
      if (wallet is Map) {
        widget.state.wallet.applyRemote(RemoteWallet.fromServer(
          wallet.map((key, value) => MapEntry(key.toString(), value)),
        ));
      }
      widget.state.gifts.sent.insert(0, GiftTransaction(
        gift: gift, quantity: 1, senderId: account.userId,
        receiverIds: [recipient],
        totalCost: (response['total_cost'] as num?)?.toInt() ?? gift.price,
      ));
      widget.state.effects.enqueue(EffectRequest(
        id: 'gift-ui-${widget.state.gifts.sent.length}',
        kind: EffectKind.gift, asset: '${gift.effectKind}:${gift.id}', priority: 60,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${gift.name} sent.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.state.backend.userSafeError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'Popular',
      'Normal',
      'Lucky',
      'CP',
      'VS',
      'Country',
      'Luxury',
      'Backpack',
    ];
    final visibleGifts = gifts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '🪙 ' + widget.state.wallet.coins.toString(),
                style: const TextStyle(
                  color: FeaturePalette.wallet,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(children:[Column(
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
                  onSelected: (_) {
                    if (value == 'Backpack') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(state: widget.state)));
                    } else {
                      setState(() => category = value);
                    }
                  },
                );
              },
            ),
          ),
          Expanded(
            child: EmojiMotion(builder: (context, emojiMotion) => GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: visibleGifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.72,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (_, index) {
                final gift = visibleGifts[index];
                final color = _giftColor(gift, index);
                return RoyalPanel(
                  padding: const EdgeInsets.all(8),
                  gradient: FeaturePalette.glow(color),
                  accentColor: color,
                  onTap: sending ? null : () => send(gift),
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
                          child: ClipOval(
                            child: gift.posterUrl?.startsWith('https://')==true ? Image.network(
                              gift.posterUrl!,fit:BoxFit.contain,cacheWidth:240,
                              errorBuilder:(_,error,stackTrace)=>Center(child:AnimatedEmoji(emoji:gift.emoji,size:48,timeline:emojiMotion,
                                effect:gift.resolvedCategory=='vs'?EmojiEffect.fire:null)),
                            ) : Image.asset(
                              gift.artworkAsset ?? CinematicAssets.posterFor(gift.id),
                              key: ValueKey('gift-art-${gift.id}'),
                              fit: BoxFit.contain,
                              cacheWidth: 240,
                              errorBuilder: (_, error, stackTrace) => Center(
                                child: AnimatedEmoji(emoji:gift.emoji,size:48,timeline:emojiMotion,
                                  effect:gift.resolvedCategory=='vs'?EmojiEffect.fire:null),
                              ),
                            ),
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
                        style: const TextStyle(
                          color: FeaturePalette.wallet,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RoyalPalette.nearBlack,
                border: Border(
                  top: BorderSide(
                    color: FeaturePalette.backpack.withValues(alpha: 0.75),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: FeaturePalette.backpack.withValues(alpha: 0.16),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Row(
                children: [
                  ShiningIcon(
                    icon: Icons.backpack_rounded,
                    color: FeaturePalette.backpack,
                    size: 18,
                    boxSize: 34,
                    glow: 0.30,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Backpack',
                    style: TextStyle(
                      color: FeaturePalette.backpack,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Spacer(),
                  Text('Select gift and recipient', style: TextStyle(color: RoyalPalette.muted)),
                ],
              ),
            ),
          ),
        ],
      ),Positioned.fill(child:GiftSceneOverlay(queue:_scenes,onDelivered:(_){ }))]),
    );
  }
}
