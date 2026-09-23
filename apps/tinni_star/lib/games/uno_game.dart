import 'dart:math';

enum UnoColor { red, yellow, green, blue, wild }

enum UnoKind { number, skip, reverse, drawTwo, wild, wildDrawFour }

class UnoCard {
  const UnoCard({
    required this.color,
    required this.kind,
    this.number,
  });

  final UnoColor color;
  final UnoKind kind;
  final int? number;

  String get label {
    switch (kind) {
      case UnoKind.number:
        return number.toString();
      case UnoKind.skip:
        return 'SKIP';
      case UnoKind.reverse:
        return 'REV';
      case UnoKind.drawTwo:
        return '+2';
      case UnoKind.wild:
        return 'WILD';
      case UnoKind.wildDrawFour:
        return '+4';
    }
  }

  String get key => '${color.name}:${kind.name}:${number ?? -1}';
}

class UnoGame {
  UnoGame({Random? random}) : _random = random ?? Random() {
    reset();
  }

  final Random _random;
  final List<UnoCard> deck = <UnoCard>[];
  final List<UnoCard> discard = <UnoCard>[];
  final List<UnoCard> playerHand = <UnoCard>[];
  final List<UnoCard> botHand = <UnoCard>[];

  UnoColor activeColor = UnoColor.red;
  bool playerTurn = true;
  String status = 'Your turn';
  String? winner;

  UnoCard get topCard => discard.last;

  void reset() {
    deck
      ..clear()
      ..addAll(_buildDeck())
      ..shuffle(_random);
    discard.clear();
    playerHand.clear();
    botHand.clear();
    winner = null;
    playerTurn = true;
    status = 'Your turn';

    for (var i = 0; i < 7; i++) {
      playerHand.add(_drawOne());
      botHand.add(_drawOne());
    }

    UnoCard first;
    do {
      first = _drawOne();
      if (first.color == UnoColor.wild) deck.insert(0, first);
    } while (first.color == UnoColor.wild);

    discard.add(first);
    activeColor = first.color;
  }

  bool canPlay(UnoCard card) {
    if (winner != null) return false;
    if (card.color == UnoColor.wild) return true;
    if (card.color == activeColor) return true;

    final top = topCard;
    if (card.kind == UnoKind.number &&
        top.kind == UnoKind.number &&
        card.number == top.number) {
      return true;
    }
    return card.kind != UnoKind.number && card.kind == top.kind;
  }

  bool playPlayerCard(int index, {UnoColor? chosenColor}) {
    if (!playerTurn || winner != null) return false;
    if (index < 0 || index >= playerHand.length) return false;

    final card = playerHand[index];
    if (!canPlay(card)) return false;

    playerHand.removeAt(index);
    _place(card, chosenColor: chosenColor);
    if (playerHand.isEmpty) {
      winner = 'You';
      status = 'You win!';
      return true;
    }

    if (!_effectKeepsTurn(card)) {
      playerTurn = false;
      _botTurn();
    }
    return true;
  }

  void drawForPlayer() {
    if (!playerTurn || winner != null) return;
    final card = _drawOne();
    playerHand.add(card);
    status = 'You drew a card.';
    if (!canPlay(card)) {
      playerTurn = false;
      _botTurn();
    }
  }

  void _botTurn() {
    if (winner != null) return;

    var index = botHand.indexWhere(canPlay);
    if (index < 0) {
      botHand.add(_drawOne());
      index = botHand.indexWhere(canPlay);
      if (index < 0) {
        playerTurn = true;
        status = 'Bot drew. Your turn.';
        return;
      }
    }

    final card = botHand.removeAt(index);
    final color = card.color == UnoColor.wild ? _bestBotColor() : null;
    _place(card, chosenColor: color);

    if (botHand.isEmpty) {
      winner = 'Bot';
      status = 'Bot wins.';
      return;
    }

    if (_effectKeepsTurn(card)) {
      _botTurn();
      return;
    }

    playerTurn = true;
    status = 'Your turn.';
  }

  void _place(UnoCard card, {UnoColor? chosenColor}) {
    discard.add(card);
    activeColor = card.color == UnoColor.wild
        ? (chosenColor ?? UnoColor.red)
        : card.color;

    switch (card.kind) {
      case UnoKind.drawTwo:
        if (playerTurn) {
          _drawMany(botHand, 2);
        } else {
          _drawMany(playerHand, 2);
        }
        break;
      case UnoKind.wildDrawFour:
        if (playerTurn) {
          _drawMany(botHand, 4);
        } else {
          _drawMany(playerHand, 4);
        }
        break;
      case UnoKind.skip:
      case UnoKind.reverse:
      case UnoKind.number:
      case UnoKind.wild:
        break;
    }
  }

  bool _effectKeepsTurn(UnoCard card) {
    return card.kind == UnoKind.skip || card.kind == UnoKind.reverse;
  }

  UnoColor _bestBotColor() {
    final counts = <UnoColor, int>{
      UnoColor.red: 0,
      UnoColor.yellow: 0,
      UnoColor.green: 0,
      UnoColor.blue: 0,
    };
    for (final card in botHand) {
      if (counts.containsKey(card.color)) {
        counts[card.color] = counts[card.color]! + 1;
      }
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  void _drawMany(List<UnoCard> hand, int count) {
    for (var i = 0; i < count; i++) {
      hand.add(_drawOne());
    }
  }

  UnoCard _drawOne() {
    if (deck.isEmpty) {
      final top = discard.removeLast();
      deck
        ..addAll(discard)
        ..shuffle(_random);
      discard
        ..clear()
        ..add(top);
    }
    return deck.removeLast();
  }

  List<UnoCard> _buildDeck() {
    final cards = <UnoCard>[];
    for (final color in <UnoColor>[
      UnoColor.red,
      UnoColor.yellow,
      UnoColor.green,
      UnoColor.blue,
    ]) {
      cards.add(UnoCard(color: color, kind: UnoKind.number, number: 0));
      for (var n = 1; n <= 9; n++) {
        cards.add(UnoCard(color: color, kind: UnoKind.number, number: n));
        cards.add(UnoCard(color: color, kind: UnoKind.number, number: n));
      }
      for (var i = 0; i < 2; i++) {
        cards.add(UnoCard(color: color, kind: UnoKind.skip));
        cards.add(UnoCard(color: color, kind: UnoKind.reverse));
        cards.add(UnoCard(color: color, kind: UnoKind.drawTwo));
      }
    }
    for (var i = 0; i < 4; i++) {
      cards.add(
        const UnoCard(color: UnoColor.wild, kind: UnoKind.wild),
      );
      cards.add(
        const UnoCard(color: UnoColor.wild, kind: UnoKind.wildDrawFour),
      );
    }
    return cards;
  }
}
