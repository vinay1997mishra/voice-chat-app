import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../economy/economy.dart';

enum FruitKind {
  lemon('🍋', 'Lemon', 5),
  raspberry('🫐', 'Raspberry', 5),
  kiwi('🥝', 'Kiwi', 5),
  plum('🍑', 'Plum', 5),
  banana('🍌', 'Banana', 10),
  strawberry('🍓', 'Strawberry', 10),
  watermelon('🍉', 'Watermelon', 20),
  cherry('🍒', 'Cherry', 40);

  const FruitKind(this.emoji, this.label, this.multiplier);

  final String emoji;
  final String label;
  final int multiplier;
}

class FruitGameConfig {
  const FruitGameConfig({
    this.roundDuration = const Duration(seconds: 30),
    this.betLockBeforeResult = const Duration(seconds: 3),
    this.highVolumePlayerThreshold = 20,
    this.companyMarginPercent = 30,
    this.jackpotContributionPercent = 1,
    this.historyLimit = 20,
  });

  final Duration roundDuration;
  final Duration betLockBeforeResult;

  /// Demo threshold only. Production must receive this from protected
  /// server/Owner configuration instead of trusting the mobile client.
  final int highVolumePlayerThreshold;

  /// In high-volume mode the engine targets a payout at or below
  /// (100 - companyMarginPercent)% of the round stake.
  final int companyMarginPercent;
  final int jackpotContributionPercent;
  final int historyLimit;

  double get targetPayoutRatio => (100 - companyMarginPercent) / 100;
}

class FruitBet {
  const FruitBet({
    required this.userId,
    required this.fruit,
    required this.amount,
  });

  final String userId;
  final FruitKind fruit;
  final int amount;
}

enum FruitResultMode { randomLowVolume, marginTargetHighVolume }

class FruitRoundResult {
  const FruitRoundResult({
    required this.roundId,
    required this.fruit,
    required this.mode,
    required this.totalBet,
    required this.totalPayout,
    required this.companyRetained,
    required this.activePlayers,
    required this.settledAt,
    required this.marginTargetMet,
  });

  final int roundId;
  final FruitKind fruit;
  final FruitResultMode mode;
  final int totalBet;
  final int totalPayout;
  final int companyRetained;
  final int activePlayers;
  final DateTime settledAt;
  final bool marginTargetMet;
}

/// Local/demo model for the continuously running Fruit Jackpot game.
///
/// Production settlement and result authority must live on the server. The
/// mobile app may render a server round, submit bets and display settlement,
/// but must not be trusted as financial authority.
class FruitJackpotGameService extends ChangeNotifier {
  FruitJackpotGameService({
    required this.wallet,
    this.config = const FruitGameConfig(),
    Random? random,
    DateTime Function()? now,
    bool autoStart = true,
    this.initialJackpot = 85763,
  })  : _random = random ?? Random.secure(),
        _now = now ?? DateTime.now {
    _currentRoundId = _roundIdFor(_now());
    jackpot = initialJackpot;
    if (autoStart) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => sync());
    }
  }

  final WalletService wallet;
  final FruitGameConfig config;
  final Random _random;
  final DateTime Function() _now;
  final int initialJackpot;

  final Map<int, List<FruitBet>> _betsByRound = <int, List<FruitBet>>{};
  final List<FruitRoundResult> history = <FruitRoundResult>[];

  Timer? _timer;
  late int _currentRoundId;
  late int jackpot;
  int todayWinnings = 0;
  DateTime? _winningsDay;

  int get currentRoundId => _currentRoundId;

  DateTime get roundEndsAt => DateTime.fromMillisecondsSinceEpoch(
        (_currentRoundId + 1) * config.roundDuration.inMilliseconds,
      );

  Duration remaining([DateTime? at]) {
    final value = roundEndsAt.difference(at ?? _now());
    return value.isNegative ? Duration.zero : value;
  }

  bool get bettingOpen => remaining() > config.betLockBeforeResult;

  List<FruitBet> betsForRound([int? roundId]) =>
      List<FruitBet>.unmodifiable(_betsByRound[roundId ?? _currentRoundId] ?? const []);

  int totalBetForRound([int? roundId]) =>
      betsForRound(roundId).fold<int>(0, (sum, bet) => sum + bet.amount);

  int userBetForFruit(String userId, FruitKind fruit, {int? roundId}) {
    return betsForRound(roundId)
        .where((bet) => bet.userId == userId && bet.fruit == fruit)
        .fold<int>(0, (sum, bet) => sum + bet.amount);
  }

  int userTotalBet(String userId, {int? roundId}) {
    return betsForRound(roundId)
        .where((bet) => bet.userId == userId)
        .fold<int>(0, (sum, bet) => sum + bet.amount);
  }

  bool placeBet({
    required String userId,
    required FruitKind fruit,
    required int amount,
  }) {
    sync();
    if (userId.trim().isEmpty || amount <= 0 || !bettingOpen) return false;
    if (!wallet.spendCoins(amount, 'Fruit Jackpot: ${fruit.label}')) return false;

    final roundBets = _betsByRound.putIfAbsent(_currentRoundId, () => <FruitBet>[]);
    roundBets.add(FruitBet(userId: userId, fruit: fruit, amount: amount));

    final contribution = (amount * config.jackpotContributionPercent / 100).floor();
    if (contribution > 0) jackpot += contribution;
    notifyListeners();
    return true;
  }

  void sync([DateTime? at]) {
    final now = at ?? _now();
    final targetRound = _roundIdFor(now);
    if (targetRound <= _currentRoundId) return;

    while (_currentRoundId < targetRound) {
      _settleRound(
        _currentRoundId,
        DateTime.fromMillisecondsSinceEpoch(
          (_currentRoundId + 1) * config.roundDuration.inMilliseconds,
        ),
      );
      _currentRoundId += 1;
    }
    notifyListeners();
  }

  void _settleRound(int roundId, DateTime settledAt) {
    final bets = List<FruitBet>.from(_betsByRound.remove(roundId) ?? const []);
    final totalBet = bets.fold<int>(0, (sum, bet) => sum + bet.amount);
    final players = bets.map((bet) => bet.userId).toSet();

    final mode = players.length >= config.highVolumePlayerThreshold && totalBet > 0
        ? FruitResultMode.marginTargetHighVolume
        : FruitResultMode.randomLowVolume;

    final fruit = mode == FruitResultMode.randomLowVolume
        ? FruitKind.values[_random.nextInt(FruitKind.values.length)]
        : _selectHighVolumeResult(bets, totalBet);

    var totalPayout = 0;
    final payoutByUser = <String, int>{};
    for (final bet in bets.where((bet) => bet.fruit == fruit)) {
      final payout = bet.amount * fruit.multiplier;
      totalPayout += payout;
      payoutByUser.update(
        bet.userId,
        (value) => value + payout,
        ifAbsent: () => payout,
      );
    }

    // The local app has one demo wallet. In production each user payout is
    // settled independently by the backend wallet ledger.
    if (payoutByUser.isNotEmpty) {
      final localPayout = payoutByUser.values.fold<int>(0, (a, b) => a + b);
      wallet.creditCoins(localPayout, 'Fruit Jackpot win: ${fruit.label}');
      _resetDailyCounterIfNeeded(settledAt);
      todayWinnings += localPayout;
    } else {
      _resetDailyCounterIfNeeded(settledAt);
    }

    final retained = totalBet - totalPayout;
    final targetRetained = (totalBet * config.companyMarginPercent / 100).ceil();

    history.insert(
      0,
      FruitRoundResult(
        roundId: roundId,
        fruit: fruit,
        mode: mode,
        totalBet: totalBet,
        totalPayout: totalPayout,
        companyRetained: retained,
        activePlayers: players.length,
        settledAt: settledAt,
        marginTargetMet:
            mode == FruitResultMode.randomLowVolume || retained >= targetRetained,
      ),
    );
    if (history.length > config.historyLimit) {
      history.removeRange(config.historyLimit, history.length);
    }
  }

  FruitKind _selectHighVolumeResult(List<FruitBet> bets, int totalBet) {
    final targetPayout = (totalBet * config.targetPayoutRatio).floor();
    final payoutByFruit = <FruitKind, int>{
      for (final fruit in FruitKind.values) fruit: 0,
    };

    for (final bet in bets) {
      payoutByFruit[bet.fruit] =
          payoutByFruit[bet.fruit]! + (bet.amount * bet.fruit.multiplier);
    }

    final eligible = FruitKind.values
        .where((fruit) => payoutByFruit[fruit]! <= targetPayout)
        .toList();

    if (eligible.isEmpty) {
      final minimum = payoutByFruit.values.reduce(min);
      final safest = FruitKind.values
          .where((fruit) => payoutByFruit[fruit] == minimum)
          .toList();
      return safest[_random.nextInt(safest.length)];
    }

    // Keep the result as close as possible to the configured margin target,
    // instead of maximizing the retained amount. Randomness remains among
    // equally suitable fruit outcomes.
    final closestPayout = eligible
        .map((fruit) => payoutByFruit[fruit]!)
        .reduce(max);
    final closest = eligible
        .where((fruit) => payoutByFruit[fruit] == closestPayout)
        .toList();
    return closest[_random.nextInt(closest.length)];
  }

  int _roundIdFor(DateTime value) =>
      value.millisecondsSinceEpoch ~/ config.roundDuration.inMilliseconds;

  void _resetDailyCounterIfNeeded(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    if (_winningsDay != day) {
      _winningsDay = day;
      todayWinnings = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
