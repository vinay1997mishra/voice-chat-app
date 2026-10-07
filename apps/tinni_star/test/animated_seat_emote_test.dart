import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/ui/animated_emoji.dart';
import 'package:tinni_star/ui/animated_seat_emote.dart';
import 'package:tinni_star/ui/seat_emote_catalog.dart';

void main() {
  testWidgets('25 panda and 25 enemy effects render unique art on a shared timeline', (tester) async {
    final catalog = [...pandaSeatEmotes, ...enemySeatEmotes];
    expect(pandaSeatEmotes.length, 25);
    expect(enemySeatEmotes.length, 25);
    expect(enemySeatEmotes.where((item) => item.enemyPersona == EnemyPersona.male).length, 12);
    expect(enemySeatEmotes.where((item) => item.enemyPersona == EnemyPersona.female).length, 12);
    expect(enemySeatEmotes.where((item) => item.enemyPersona == EnemyPersona.clash).length, 1);
    expect(catalog.map((item) => item.id).toSet().length, 50);
    expect(catalog.every((item) => item.id.length <= 16), isTrue);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: EmojiMotion(builder: (context, timeline) => Wrap(children: [
        for (final item in catalog)
          AnimatedSeatEmote(emote: item.id, size: 54, timeline: timeline),
      ])),
    )));
    for (final item in catalog) {
      expect(find.byKey(ValueKey('seat-emote-art-${item.id}')), findsOneWidget);
    }
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(EmojiMotion), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('panda and enemy remain visible with reduced motion and tiny seat sizes', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Wrap(children: [
        for (final id in ['panda-03','panda-25','enemy-02','enemy-25'])
          AnimatedSeatEmote(emote: id, size: 22),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    for (final id in ['panda-03','panda-25','enemy-02','enemy-25']) {
      expect(find.byKey(ValueKey('seat-emote-art-$id')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('legacy unicode emotes still render instead of exposing internal IDs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AnimatedSeatEmote(emote: '😂')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('emoji-face-😂')), findsOneWidget);
    expect(find.text('panda-01'), findsNothing);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
