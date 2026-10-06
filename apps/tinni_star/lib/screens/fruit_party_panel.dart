import 'package:flutter/material.dart';
import '../app/tinni_state.dart';
import '../games/fruit_party_game.dart';
import 'casino_fruit_panel.dart';

class FruitPartyPanel extends StatelessWidget {
  const FruitPartyPanel({super.key, required this.state, this.onClose});
  final TinniState state;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final game = state.fruitPartyRemote;
    return CasinoFruitPanel(
      title: 'Fruit Party',
      gameId: 'fruit-party',
      party: true,
      source: game,
      onClose: onClose,
      liveConnected: () => game.liveConnected,
      connectLive: () async {
        final account = state.auth.current;
        if (account != null) await game.connectLive(account.authToken);
      },
      disconnectLive: game.disconnectLive,
      snapshot: () => CasinoSnapshot(
        connected: game.connected, loading: game.loading,
        bettingOpen: game.bettingOpen, spinning: game.inResultSpin,
        remaining: game.remaining(), spinRemaining: game.resultSpinRemaining(),
        roundDuration: game.roundDurationMs, round: game.currentRoundId,
        balance: game.currentRoundId > 0 ? game.walletBalance : state.wallet.coins,
        mine: game.userTotalBet, winnings: game.todayWinnings,
        lastBetResult: game.lastBetResult,
        
        error: game.lastError == null ? null : state.backend.userSafeError(StateError(game.lastError!)),
        fruits: [for (final fruit in FruitPartyKind.values) CasinoFruit(
          key: fruit.name, label: fruit.label, multiplier: fruit.multiplier,
          bet: game.userBetForFruit(fruit),
        )],
        history: [for (final result in game.history) CasinoResult(
          round: result.roundId, fruit: result.fruit.name,
          lucky: result.lucky11, bonus: result.bonusFruits.map((fruit) => fruit.name).toList(),
          
          settledAt: result.settledAt,
        )],
      ),
      refresh: () async {
        final account = state.auth.current;
        if (account != null) { await game.sync(account.authToken); }
      },
      bet: (key, amount) async {
        final account = state.auth.current;
        if (account == null) { return 'Sign in to play.'; }
        final error = await game.placeBet(authToken: account.authToken,
          roomId: state.roomSession.room?.id ?? '',
          fruit: FruitPartyKind.values.firstWhere((fruit) => fruit.name == key),
          amount: amount);
        if (error == null && state.auth.current?.authToken == account.authToken) {
          state.wallet.coins = game.walletBalance;
        }
        return error;
      },
    );
  }
}
