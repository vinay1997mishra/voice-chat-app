import 'dart:convert';
import 'dart:io';

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
    this.roomId = 'active-room',
    this.onFruitJackpot,
    this.onFruitParty,
  });

  final TinniState state;
  final String roomId;
  final VoidCallback? onFruitJackpot;
  final VoidCallback? onFruitParty;

  void _showQuickGame(BuildContext context, String title, String gameKey, List<String> actions) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports_rounded, size: 54),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions.map((action) => FilledButton.tonal(
                onPressed: () async {
                  final result = await _playQuickGame(gameKey, action);
                  if (!sheetContext.mounted) return;
                  ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(result)));
                }, child: Text(action),
              )).toList(growable: false)),
              const SizedBox(height: 14),
              const Text('Result is generated and recorded by the Tinni Star server.'),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _playQuickGame(String gameKey, String action) async {
    final account = state.auth.current;
    if (account == null) return 'Login required.';
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('https://tinnistar-api.tinnistarchat.workers.dev/room-games/action'));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${account.authToken}');
      request.write(jsonEncode(<String, String>{'room_id': roomId, 'game_key': gameKey, 'action': action}));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) return data['error']?.toString() ?? 'Game request failed.';
      return '${data['result'] ?? action}';
    } catch (_) { return 'Server connection failed.'; } finally { client.close(force: true); }
  }

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
      (
        'Lucky Dice',
        Icons.casino_rounded,
        RoyalPalette.gold,
        () => _showQuickGame(context, 'Lucky Dice', 'lucky_dice', const ['1','2','3','4','5','6']),
      ),
      (
        'Lucky Wheel',
        Icons.track_changes_rounded,
        RoyalPalette.gold,
        () => _showQuickGame(context, 'Lucky Wheel', 'lucky_wheel', const ['Star','Crown','Rose','Diamond','Lion','Dragon']),
      ),
      (
        'Rock Paper Scissors',
        Icons.back_hand_rounded,
        RoyalPalette.gold,
        () => _showQuickGame(context, 'Rock Paper Scissors', 'rps', const ['Rock','Paper','Scissors']),
      ),
      (
        'Teen Patti',
        Icons.style_rounded,
        RoyalPalette.gold,
        () => _showQuickGame(context, 'Teen Patti', 'teen_patti', const ['Join Table','View Table']),
      ),
    ];

    return Scaffold(
      key: Key('room-game-center-' + roomId),
      appBar: AppBar(title: const Text('Room Game Panel')),
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
            accentColor: game.$3,
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
