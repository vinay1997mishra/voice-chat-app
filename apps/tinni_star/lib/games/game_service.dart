enum GameType { lucky777, blackjack, giftDraw, guessing }

class GameRound {
  const GameRound({
    required this.type,
    required this.players,
    required this.rewardCoins,
    required this.state,
  });

  final GameType type;
  final List<String> players;
  final int rewardCoins;
  final String state;

  GameRound copyWith({String? state}) => GameRound(
        type: type,
        players: players,
        rewardCoins: rewardCoins,
        state: state ?? this.state,
      );
}

class GameService {
  GameRound? active;
  final List<GameRound> history = <GameRound>[];

  GameRound start(GameType type, List<String> players) {
    if (players.isEmpty) throw StateError('At least one player is required');
    if (active != null) throw StateError('A game is already running');
    active = GameRound(
      type: type,
      players: List<String>.unmodifiable(players),
      rewardCoins: _rewardFor(type),
      state: 'running',
    );
    return active!;
  }

  GameRound finish() {
    final round = active;
    if (round == null) throw StateError('No active game');
    final completed = round.copyWith(state: 'settled');
    history.insert(0, completed);
    active = null;
    return completed;
  }

  int _rewardFor(GameType type) {
    switch (type) {
      case GameType.lucky777:
        return 777;
      case GameType.blackjack:
        return 500;
      case GameType.giftDraw:
        return 300;
      case GameType.guessing:
        return 200;
    }
  }
}
