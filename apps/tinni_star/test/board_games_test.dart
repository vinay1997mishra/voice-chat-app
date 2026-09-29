import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/games/ludo_game.dart';
import 'package:tinni_star/games/game_service.dart';
import 'package:tinni_star/games/uno_game.dart';
import 'package:tinni_star/screens/games_screen.dart';

void main() {
  test('game framework enforces room sessions and round lifecycle', () {
    final games = GameService();
    final session = games.openRoomGame(
      roomId: 'room-1',
      userId: 'user-1',
      kind: GameKind.fruitParty,
    );
    expect(GameService.catalog, hasLength(8));
    expect(
      GameService.catalog.firstWhere((g) => g.kind == GameKind.ludo).requiresServerAuthority,
      isFalse,
    );
    expect(
      GameService.catalog.firstWhere((g) => g.kind == GameKind.uno).requiresServerAuthority,
      isFalse,
    );
    expect(
      GameService.catalog.firstWhere((g) => g.kind == GameKind.fruitJackpot).requiresServerAuthority,
      isTrue,
    );
    expect(session.state, GameSessionState.open);
    session.closeBetting();
    session.beginSettlement();
    session.publishResult();
    expect(session.round, 1);
    session.nextRound();
    expect(session.state, GameSessionState.open);
    expect(
      () => games.openRoomGame(
        roomId: '', userId: 'user-1', kind: GameKind.lucky777,
      ),
      throwsStateError,
    );
  });

  test('Ludo creates four players with four tokens and valid dice', () {
    final game = LudoGame(random: Random(7));

    for (final player in LudoPlayer.values) {
      expect(game.tokens[player], hasLength(4));
      expect(game.tokens[player]!.every((token) => token.isHome), isTrue);
    }

    final dice = game.roll();
    expect(dice, inInclusiveRange(1, 6));
    expect(
      LudoGame.startOffsets.values.toSet(),
      hasLength(LudoPlayer.values.length),
    );
  });

  test('UNO starts with a complete 108-card deck distribution', () {
    final game = UnoGame(random: Random(11));

    expect(game.playerHand, hasLength(7));
    expect(game.botHand, hasLength(7));
    expect(game.discard, hasLength(1));
    expect(
      game.deck.length +
          game.playerHand.length +
          game.botHand.length +
          game.discard.length,
      108,
    );
    expect(game.topCard.color, isNot(UnoColor.wild));
  });

  testWidgets('Game Center opens real Ludo and UNO gameplay screens',
      (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: GamesScreen(state: state, roomId: 'test-room')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fruit Jackpot'), findsOneWidget);
    expect(find.text('Ludo'), findsOneWidget);
    expect(find.text('UNO'), findsOneWidget);

    await tester.ensureVisible(find.text('Ludo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ludo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ludo-roll-dice')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('UNO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UNO'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uno-player-hand')), findsOneWidget);
    expect(find.byKey(const Key('uno-draw-card')), findsOneWidget);
  });
}
