import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';
import 'fruit_jackpot_screen.dart';
import 'fruit_party_screen.dart';
import 'ludo_screen.dart';
import 'uno_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key, required this.state});

  final TinniState state;

  @override
  Widget build(BuildContext context) {
    final games = <(String, IconData, VoidCallback)>[
      (
        'Fruit Jackpot',
        Icons.local_florist_rounded,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FruitJackpotScreen(state: state),
          ),
        ),
      ),
      (
        'Fruit Party',
        Icons.celebration_rounded,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FruitPartyScreen(state: state),
          ),
        ),
      ),
      (
        'Ludo',
        Icons.grid_4x4_rounded,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LudoScreen()),
        ),
      ),
      (
        'UNO',
        Icons.style_rounded,
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
            onTap: game.$3,
            gradient: LinearGradient(
              colors: [
                RoyalPalette.panel2,
                index.isEven
                    ? const Color(0xFF261B05)
                    : const Color(0xFF17120A),
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
