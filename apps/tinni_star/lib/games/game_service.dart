enum GameKind {
  fruitJackpot,
  fruitParty,
  ludo,
  uno,
  lucky777,
  blackjack,
  giftDraw,
  guessing,
}

enum GameSessionState { idle, open, bettingClosed, settling, result }

class GameDefinition {
  const GameDefinition({
    required this.kind,
    required this.title,
    this.roomOnly = true,
    this.requiresServerAuthority = false,
  });

  final GameKind kind;
  final String title;
  final bool roomOnly;
  final bool requiresServerAuthority;
}

class GameSession {
  GameSession({
    required this.roomId,
    required this.game,
    required this.openedBy,
  });

  final String roomId;
  final GameDefinition game;
  final String openedBy;
  GameSessionState state = GameSessionState.idle;
  int round = 0;

  void open() {
    if (roomId.isEmpty || openedBy.isEmpty) {
      throw StateError('roomId and openedBy are required');
    }
    state = GameSessionState.open;
  }

  void closeBetting() {
    if (state != GameSessionState.open) {
      throw StateError('Game is not accepting bets');
    }
    state = GameSessionState.bettingClosed;
  }

  void beginSettlement() {
    if (state != GameSessionState.bettingClosed) {
      throw StateError('Betting must close before settlement');
    }
    state = GameSessionState.settling;
  }

  void publishResult() {
    if (state != GameSessionState.settling) {
      throw StateError('Settlement must start before result');
    }
    round += 1;
    state = GameSessionState.result;
  }

  void nextRound() {
    if (state != GameSessionState.result) {
      throw StateError('Current round has no result');
    }
    state = GameSessionState.open;
  }
}

class GameService {
  GameService();

  static const List<GameDefinition> catalog = <GameDefinition>[
    GameDefinition(kind: GameKind.fruitJackpot, title: 'Fruit Jackpot', requiresServerAuthority: true),
    GameDefinition(kind: GameKind.fruitParty, title: 'Fruit Party', requiresServerAuthority: true),
    GameDefinition(kind: GameKind.ludo, title: 'Ludo', requiresServerAuthority: true),
    GameDefinition(kind: GameKind.uno, title: 'UNO', requiresServerAuthority: true),
    GameDefinition(kind: GameKind.lucky777, title: 'Lucky 777', requiresServerAuthority: true),
    GameDefinition(kind: GameKind.blackjack, title: 'Blackjack', requiresServerAuthority: true),
    GameDefinition(kind: GameKind.giftDraw, title: 'Gift Draw', requiresServerAuthority: true),
    GameDefinition(kind: GameKind.guessing, title: 'Guessing', requiresServerAuthority: true),
  ];

  final Map<String, GameSession> _sessions = <String, GameSession>{};

  GameDefinition definition(GameKind kind) =>
      catalog.firstWhere((item) => item.kind == kind);

  GameSession openRoomGame({
    required String roomId,
    required String userId,
    required GameKind kind,
  }) {
    final game = definition(kind);
    if (game.roomOnly && roomId.isEmpty) {
      throw StateError('This game can only open inside a room');
    }
    final session = GameSession(roomId: roomId, game: game, openedBy: userId)..open();
    _sessions[roomId] = session;
    return session;
  }

  GameSession? sessionForRoom(String roomId) => _sessions[roomId];

  void closeRoomGame(String roomId) {
    _sessions.remove(roomId);
  }
}
