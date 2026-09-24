import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/games/ludo_game.dart';
import 'package:tinni_star/games/uno_game.dart';
import 'package:tinni_star/screens/games_screen.dart';

void main() {
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
      MaterialApp(home: GamesScreen(state: state)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fruit Jackpot'), findsOneWidget);
    expect(find.text('Ludo'), findsOneWidget);
    expect(find.text('UNO'), findsOneWidget);

    await tester.tap(find.text('Ludo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ludo-roll-dice')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('UNO'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('uno-player-hand')), findsOneWidget);
    expect(find.byKey(const Key('uno-draw-card')), findsOneWidget);
  });
}
