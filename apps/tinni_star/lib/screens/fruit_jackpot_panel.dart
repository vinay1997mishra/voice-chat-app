import 'package:flutter/material.dart';
import '../app/tinni_state.dart';
import '../games/fruit_jackpot_game.dart';
import 'casino_fruit_panel.dart';

class FruitJackpotPanel extends StatelessWidget {
  const FruitJackpotPanel({super.key, required this.state, this.onClose});
  final TinniState state;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final game = state.fruitJackpotRemote;
    return CasinoFruitPanel(
      title: 'Fruit Jackpot',
      gameId: 'fruit-jackpot',
      party: false,
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
        jackpot: game.jackpot,
        error: game.lastError == null ? null : state.backend.userSafeError(StateError(game.lastError!)),
        fruits: [for (final fruit in FruitKind.values) CasinoFruit(
          key: fruit.name, label: fruit.label, multiplier: fruit.multiplier,
          bet: game.userBetForFruit(fruit),
        )],
        history: [for (final result in game.history) CasinoResult(
          round: result.roundId, fruit: result.fruit.name,
          lucky: result.isLucky11, bonus: result.bonusFruits.map((fruit) => fruit.name).toList(), jackpot: result.jackpotHit,
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
          fruit: FruitKind.values.firstWhere((fruit) => fruit.name == key),
          amount: amount);
        if (error == null && state.auth.current?.authToken == account.authToken) {
          state.wallet.coins = game.walletBalance;
        }
        return error;
      },
    );
  }
}
