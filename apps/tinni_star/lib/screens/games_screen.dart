import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../games/game_service.dart';
import '../ui/royal_theme.dart';
import 'ludo_screen.dart';
import 'uno_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  int jackpot = 85763;

  void play(GameType type) {
    if (widget.state.games.active == null) {
      widget.state.games.start(type, const ['10000000']);
    }
    final result = widget.state.games.finish();
    widget.state.wallet.creditCoins(result.rewardCoins, 'Game reward');
    setState(() => jackpot += result.rewardCoins);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(type.name + ' reward +' + result.rewardCoins.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final games = [
      ('Ludo', Icons.grid_4x4_rounded, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LudoScreen()),
        );
      }),
      ('UNO', Icons.style_rounded, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UnoScreen()),
        );
      }),
      ('Lucky 777', Icons.casino_rounded, () => play(GameType.lucky777)),
      ('Blackjack', Icons.style_rounded, () => play(GameType.blackjack)),
      ('Gift Draw', Icons.card_giftcard_rounded, () => play(GameType.giftDraw)),
      ('Guessing', Icons.psychology_alt_rounded, () => play(GameType.guessing)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Game Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RoyalPanel(
            gradient: const LinearGradient(
              colors: [Color(0xFF241000), Color(0xFF4A2600), Color(0xFF130B04)],
            ),
            child: Column(
              children: [
                const Text(
                  'JACKPOT',
                  style: TextStyle(
                    color: RoyalPalette.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 34,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  jackpot.toString(),
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    3,
                    (index) => Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: RoyalPalette.black,
                        border: Border.all(color: RoyalPalette.gold),
                      ),
                      child: Icon(
                        [
                          Icons.monetization_on_rounded,
                          Icons.favorite_rounded,
                          Icons.diamond_rounded,
                        ][index],
                        color: RoyalPalette.gold,
                        size: 33,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const GoldSectionTitle('Room Games'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: games.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.12,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (_, index) {
              final game = games[index];
              return RoyalPanel(
                onTap: game.$3,
                gradient: LinearGradient(
                  colors: [
                    RoyalPalette.panel2,
                    index.isEven ? const Color(0xFF261B05) : const Color(0xFF17120A),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(game.$2, color: RoyalPalette.gold, size: 38),
                    const SizedBox(height: 8),
                    Text(
                      game.$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: RoyalPalette.cream,
                      ),
                    ),
                    const Text('Tap to play', style: TextStyle(fontSize: 11, color: RoyalPalette.muted)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
