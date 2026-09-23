import 'dart:math';

enum LudoPlayer { red, green, yellow, blue }

class LudoToken {
  const LudoToken({
    required this.player,
    required this.index,
    this.progress = -1,
  });

  final LudoPlayer player;
  final int index;

  /// -1 = home, 0..51 = shared track, 52..57 = home lane/finish.
  final int progress;

  bool get isHome => progress < 0;
  bool get isFinished => progress >= 57;

  LudoToken copyWith({int? progress}) => LudoToken(
        player: player,
        index: index,
        progress: progress ?? this.progress,
      );
}

class LudoGame {
  LudoGame({Random? random}) : _random = random ?? Random() {
    tokens = {
      for (final player in LudoPlayer.values)
        player: List<LudoToken>.generate(
          4,
          (index) => LudoToken(player: player, index: index),
          growable: false,
        ),
    };
  }

  final Random _random;
  late final Map<LudoPlayer, List<LudoToken>> tokens;

  LudoPlayer currentPlayer = LudoPlayer.red;
  int? rolled;
  String status = 'Red starts. Roll the dice.';
  LudoPlayer? winner;

  static const Map<LudoPlayer, int> startOffsets = {
    LudoPlayer.red: 0,
    LudoPlayer.green: 13,
    LudoPlayer.yellow: 26,
    LudoPlayer.blue: 39,
  };

  int roll() {
    if (winner != null) return rolled ?? 1;
    if (rolled != null) return rolled!;
    final value = _random.nextInt(6) + 1;
    rolled = value;
    status = '${currentPlayer.name.toUpperCase()} rolled $value.';
    if (movableTokenIndexes().isEmpty) {
      _finishTurn();
    }
    return value;
  }

  List<int> movableTokenIndexes() {
    final dice = rolled;
    if (dice == null || winner != null) return const [];
    final list = tokens[currentPlayer]!;
    final values = <int>[];
    for (var i = 0; i < list.length; i++) {
      final token = list[i];
      if (token.isFinished) continue;
      if (token.isHome) {
        if (dice == 6) values.add(i);
        continue;
      }
      if (token.progress + dice <= 57) values.add(i);
    }
    return values;
  }

  bool move(int tokenIndex) {
    final dice = rolled;
    if (dice == null || winner != null) return false;
    final movable = movableTokenIndexes();
    if (!movable.contains(tokenIndex)) return false;

    final playerTokens = List<LudoToken>.from(tokens[currentPlayer]!);
    final token = playerTokens[tokenIndex];
    final nextProgress = token.isHome ? 0 : token.progress + dice;
    playerTokens[tokenIndex] = token.copyWith(progress: nextProgress);
    tokens[currentPlayer] = playerTokens;

    if (nextProgress < 52) {
      _captureAt(sharedTrackIndex(currentPlayer, nextProgress));
    }

    if (playerTokens.every((item) => item.isFinished)) {
      winner = currentPlayer;
      status = '${currentPlayer.name.toUpperCase()} wins!';
      rolled = null;
      return true;
    }

    status =
        '${currentPlayer.name.toUpperCase()} moved token ${tokenIndex + 1}.';
    _finishTurn(keepTurn: dice == 6);
    return true;
  }

  int sharedTrackIndex(LudoPlayer player, int progress) {
    if (progress < 0 || progress >= 52) return -1;
    return (startOffsets[player]! + progress) % 52;
  }

  void _captureAt(int sharedIndex) {
    if (sharedIndex < 0) return;
    const safe = <int>{0, 8, 13, 21, 26, 34, 39, 47};
    if (safe.contains(sharedIndex)) return;

    for (final opponent in LudoPlayer.values) {
      if (opponent == currentPlayer) continue;
      final opponentTokens = List<LudoToken>.from(tokens[opponent]!);
      var changed = false;
      for (var i = 0; i < opponentTokens.length; i++) {
        final token = opponentTokens[i];
        if (token.progress < 0 || token.progress >= 52) continue;
        if (sharedTrackIndex(opponent, token.progress) == sharedIndex) {
          opponentTokens[i] = token.copyWith(progress: -1);
          changed = true;
        }
      }
      if (changed) tokens[opponent] = opponentTokens;
    }
  }

  void _finishTurn({bool keepTurn = false}) {
    final previousRoll = rolled;
    rolled = null;
    if (winner != null) return;
    if (keepTurn && previousRoll == 6) {
      status = '${currentPlayer.name.toUpperCase()} gets another roll.';
      return;
    }
    currentPlayer = LudoPlayer.values[
        (LudoPlayer.values.indexOf(currentPlayer) + 1) %
            LudoPlayer.values.length];
    status = '${currentPlayer.name.toUpperCase()} turn.';
  }

  void reset() {
    for (final player in LudoPlayer.values) {
      tokens[player] = List<LudoToken>.generate(
        4,
        (index) => LudoToken(player: player, index: index),
        growable: false,
      );
    }
    currentPlayer = LudoPlayer.red;
    rolled = null;
    winner = null;
    status = 'Red starts. Roll the dice.';
  }
}
