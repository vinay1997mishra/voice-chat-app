import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/games/ludo_game.dart';
import 'package:tinni_star/games/game_service.dart';
import 'package:tinni_star/screens/games_screen.dart';

void main() {
  test('game framework enforces room sessions and round lifecycle', () {
    final games = GameService();
    final session = games.openRoomGame(
      roomId: 'room-1',
      userId: 'user-1',
      kind: GameKind.fruitParty,
    );
    expect(GameService.catalog, hasLength(6));
    expect(
      GameService.catalog.firstWhere((g) => g.kind == GameKind.ludo).requiresServerAuthority,
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

  testWidgets('Game Center opens real Ludo gameplay screen',
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

    expect(find.text('Ludo'), findsOneWidget);
    expect(find.text('UNO'), findsNothing);

    await tester.ensureVisible(find.text('Ludo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ludo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ludo-roll-dice')), findsOneWidget);

  });
}
