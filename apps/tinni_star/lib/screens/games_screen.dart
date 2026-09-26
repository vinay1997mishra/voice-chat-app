import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';
import 'fruit_jackpot_screen.dart';
import 'fruit_party_screen.dart';
import 'ludo_screen.dart';
import 'uno_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({
    super.key,
    required this.state,
    this.onFruitJackpot,
    this.onFruitParty,
  });

  final TinniState state;
  final VoidCallback? onFruitJackpot;
  final VoidCallback? onFruitParty;

  @override
  Widget build(BuildContext context) {
    final games = <(String, IconData, Color, VoidCallback)>[
      (
        'Fruit Jackpot',
        Icons.local_florist_rounded,
        FeaturePalette.fruitJackpot,
        () {
          if (onFruitJackpot != null) {
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onFruitJackpot!();
            });
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FruitJackpotScreen(state: state),
            ),
          );
        },
      ),
      (
        'Fruit Party',
        Icons.celebration_rounded,
        FeaturePalette.fruitParty,
        () {
          if (onFruitParty != null) {
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onFruitParty!();
            });
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FruitPartyScreen(state: state),
            ),
          );
        },
      ),
      (
        'Ludo',
        Icons.grid_4x4_rounded,
        FeaturePalette.ludo,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LudoScreen()),
        ),
      ),
      (
        'UNO',
        Icons.style_rounded,
        FeaturePalette.uno,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UnoScreen()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Game Center')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
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
            onTap: game.$4,
            gradient: FeaturePalette.glow(game.$3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: game.$3.withValues(alpha: 0.16),
                    border: Border.all(
                      color: game.$3.withValues(alpha: 0.78),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: game.$3.withValues(alpha: 0.28),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Icon(game.$2, color: game.$3, size: 34),
                ),
                const SizedBox(height: 8),
                Text(
                  game.$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: RoyalPalette.cream,
                  ),
                ),
                const Text(
                  'Tap to play',
                  style: TextStyle(
                    fontSize: 11,
                    color: RoyalPalette.muted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
