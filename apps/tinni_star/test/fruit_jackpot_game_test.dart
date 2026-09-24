import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/economy/economy.dart';
import 'package:tinni_star/games/fruit_jackpot_game.dart';

class _FixedRandom implements Random {
  const _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => value % max;
}

void main() {
  test('low-volume fruit result stays random and independent of the placed bet', () {
    var now = DateTime(2026, 9, 24, 12);
    final wallet = WalletService(coins: 10000);
    final game = FruitJackpotGameService(
      wallet: wallet,
      config: const FruitGameConfig(
        roundDuration: Duration(seconds: 30),
        highVolumePlayerThreshold: 20,
      ),
      random: const _FixedRandom(7),
      now: () => now,
      autoStart: false,
    );

    expect(
      game.placeBet(
        userId: '10000000',
        fruit: FruitKind.lemon,
        amount: 1000,
      ),
      isTrue,
    );

    now = now.add(const Duration(seconds: 31));
    game.sync(now);

    expect(game.history, isNotEmpty);
    expect(game.history.first.mode, FruitResultMode.randomLowVolume);
    expect(game.history.first.fruit, FruitKind.cherry);
    expect(game.history.first.totalPayout, 0);
    expect(wallet.coins, 9000);
  });

  test('high-volume mode targets 30 percent retained from total round bets', () {
    var now = DateTime(2026, 9, 24, 12);
    final wallet = WalletService(coins: 5000);
    final game = FruitJackpotGameService(
      wallet: wallet,
      config: const FruitGameConfig(
        roundDuration: Duration(seconds: 30),
        highVolumePlayerThreshold: 1,
        companyMarginPercent: 30,
      ),
      random: const _FixedRandom(0),
      now: () => now,
      autoStart: false,
    );

    const bets = <FruitKind, int>{
      FruitKind.lemon: 140,
      FruitKind.raspberry: 172,
      FruitKind.kiwi: 172,
      FruitKind.plum: 172,
      FruitKind.banana: 86,
      FruitKind.strawberry: 86,
      FruitKind.watermelon: 43,
      FruitKind.cherry: 129,
    };

    for (final entry in bets.entries) {
      expect(
        game.placeBet(
          userId: '10000000',
          fruit: entry.key,
          amount: entry.value,
        ),
        isTrue,
      );
    }

    expect(game.totalBetForRound(), 1000);

    now = now.add(const Duration(seconds: 31));
    game.sync(now);

    final result = game.history.first;
    expect(result.mode, FruitResultMode.marginTargetHighVolume);
    expect(result.fruit, FruitKind.lemon);
    expect(result.totalBet, 1000);
    expect(result.totalPayout, 700);
    expect(result.companyRetained, 300);
    expect(result.marginTargetMet, isTrue);
    expect(wallet.coins, 4700);
  });

  test('rounds advance without waiting for any user bet', () {
    var now = DateTime(2026, 9, 24, 12);
    final game = FruitJackpotGameService(
      wallet: WalletService(),
      config: const FruitGameConfig(roundDuration: Duration(seconds: 10)),
      random: const _FixedRandom(2),
      now: () => now,
      autoStart: false,
    );

    final firstRound = game.currentRoundId;
    now = now.add(const Duration(seconds: 11));
    game.sync(now);

    expect(game.currentRoundId, firstRound + 1);
    expect(game.history, hasLength(1));
    expect(game.history.first.totalBet, 0);
    expect(game.history.first.fruit, FruitKind.kiwi);
  });
}
