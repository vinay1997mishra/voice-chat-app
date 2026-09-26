import 'package:flutter/material.dart';

import '../games/uno_game.dart';
import '../ui/royal_theme.dart';

class UnoScreen extends StatefulWidget {
  const UnoScreen({super.key});

  @override
  State<UnoScreen> createState() => _UnoScreenState();
}

class _UnoScreenState extends State<UnoScreen> {
  late UnoGame game;

  @override
  void initState() {
    super.initState();
    game = UnoGame();
  }

  Color _color(UnoColor color) {
    switch (color) {
      case UnoColor.red:
        return const Color(0xFFE5484D);
      case UnoColor.yellow:
        return const Color(0xFFF2C94C);
      case UnoColor.green:
        return const Color(0xFF31B46C);
      case UnoColor.blue:
        return const Color(0xFF3C82F6);
      case UnoColor.wild:
        return const Color(0xFF171717);
    }
  }

  Future<UnoColor?> _chooseWildColor() {
    return showModalBottomSheet<UnoColor>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              for (final color in <UnoColor>[
                UnoColor.red,
                UnoColor.yellow,
                UnoColor.green,
                UnoColor.blue,
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, color),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 68,
                        decoration: BoxDecoration(
                          color: _color(color),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playCard(int index) async {
    if (index < 0 || index >= game.playerHand.length) return;
    final card = game.playerHand[index];
    if (!game.canPlay(card)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That card cannot be played now.')),
      );
      return;
    }

    UnoColor? selected;
    if (card.color == UnoColor.wild) {
      selected = await _chooseWildColor();
      if (selected == null) return;
    }

    if (game.playPlayerCard(index, chosenColor: selected)) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = game.topCard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UNO'),
        actions: [
          IconButton(
            tooltip: 'Restart',
            onPressed: () => setState(game.reset),
            icon: const ShiningIcon(
              icon: Icons.refresh_rounded,
              color: FeaturePalette.uno,
              size: 18,
              boxSize: 34,
              glow: 0.30,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'Bot • ${game.botHand.length} cards',
              style: const TextStyle(
                color: RoyalPalette.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0;
                      i < game.botHand.length.clamp(0, 8);
                      i++)
                    Transform.translate(
                      offset: Offset((i - 3.5) * 16, 0),
                      child: Transform.rotate(
                        angle: (i - 3.5) * .03,
                        child: const _UnoBackCard(),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            RoyalPanel(
              padding: const EdgeInsets.symmetric(vertical: 18),
              gradient: FeaturePalette.glow(_color(game.activeColor)),
              accentColor: _color(game.activeColor),
              child: Column(
                children: [
                  Text(
                    game.status,
                    style: TextStyle(
                      color: game.winner == null
                          ? RoyalPalette.cream
                          : _color(game.activeColor),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'DISCARD',
                            style: TextStyle(
                              color: RoyalPalette.muted,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 5),
                          _UnoCardView(
                            card: top,
                            color: _color(top.color),
                            highlighted: true,
                          ),
                        ],
                      ),
                      const SizedBox(width: 26),
                      Column(
                        children: [
                          const Text(
                            'ACTIVE COLOR',
                            style: TextStyle(
                              color: RoyalPalette.muted,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 11),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _color(game.activeColor),
                              border: Border.all(color: Colors.white70),
                              boxShadow: [
                                BoxShadow(
                                  color: _color(game.activeColor)
                                      .withValues(alpha: 0.55),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.palette_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const Key('uno-draw-card'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _color(game.activeColor),
                              foregroundColor: Colors.white,
                              shadowColor: _color(game.activeColor),
                              elevation: 5,
                            ),
                            onPressed: !game.playerTurn || game.winner != null
                                ? null
                                : () {
                                    game.drawForPlayer();
                                    setState(() {});
                                  },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Draw'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text(
                    'Your hand',
                    style: TextStyle(
                      color: RoyalPalette.cream,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${game.playerHand.length} cards',
                    style: const TextStyle(color: RoyalPalette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              key: const Key('uno-player-hand'),
              height: 132,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                scrollDirection: Axis.horizontal,
                itemCount: game.playerHand.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (_, index) {
                  final card = game.playerHand[index];
                  return GestureDetector(
                    onTap: game.playerTurn && game.canPlay(card)
                        ? () => _playCard(index)
                        : null,
                    child: _UnoCardView(
                      card: card,
                      color: _color(card.color),
                      highlighted: game.playerTurn && game.canPlay(card),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnoCardView extends StatelessWidget {
  const _UnoCardView({
    required this.card,
    required this.color,
    this.highlighted = false,
  });

  final UnoCard card;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 76,
      height: 112,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: highlighted ? color : Colors.white70,
          width: highlighted ? 3 : 1.5,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: color.withValues(alpha: .45),
                  blurRadius: 12,
                ),
              ]
            : const [],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 7,
            top: 5,
            child: Text(
              card.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Center(
            child: Transform.rotate(
              angle: -.24,
              child: Container(
                width: 54,
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: Text(
                  card.label,
                  style: TextStyle(
                    color: card.color == UnoColor.wild ? Colors.black : color,
                    fontSize: card.label.length > 2 ? 17 : 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnoBackCard extends StatelessWidget {
  const _UnoBackCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 66,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: const Color(0xFF151515),
        border: Border.all(color: FeaturePalette.uno),
      ),
      alignment: Alignment.center,
      child: const Text(
        'UNO',
        style: TextStyle(
          color: FeaturePalette.uno,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}
