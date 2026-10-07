import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/ui/animated_emoji.dart';
import 'package:tinni_star/ui/emoji_reaction_face.dart';

void main() {
  testWidgets('all 64 picker emojis animate on one shared clock', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: EmojiMotion(builder: (context, timeline) => Wrap(children: [
        for (final emoji in roomEmojis)
          AnimatedEmoji(emoji: emoji, size: 34, timeline: timeline),
      ])),
    )));
    expect(roomEmojis.toSet().length, 64);
    for (final emoji in roomEmojis) {
      if (reactionFaceEmojis.contains(emoji)) {
        expect(find.byKey(ValueKey('emoji-face-$emoji')), findsOneWidget);
      } else {
        expect(find.text(emoji), findsOneWidget);
      }
    }
    expect(find.byType(EmojiMotion), findsOneWidget);
    final before = tester.widget<Transform>(
      find.byKey(const ValueKey('emoji-motion-offset')).first,
    ).transform.clone();
    await tester.pump(const Duration(milliseconds: 400));
    final after = tester.widget<Transform>(
      find.byKey(const ValueKey('emoji-motion-offset')).first,
    ).transform;
    expect(after, isNot(before));
    expect(tester.hasRunningAnimations, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unknown future catalog emoji receives an animated fallback', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: AnimatedEmoji(emoji: '🦄'),
    )));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('🦄'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion and hidden routes stop clocks and resume safely', (tester) async {
    Widget subject({bool reduced = false, bool visible = true}) => MaterialApp(
      home: MediaQuery(data: MediaQueryData(disableAnimations: reduced),
        child: TickerMode(enabled: visible, child: const AnimatedEmoji(emoji: '🔥'))),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(subject(reduced: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('🔥'), findsOneWidget);
    await tester.pumpWidget(subject(visible: false));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('app background pauses effects and foreground resumes them', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AnimatedEmoji(emoji: '💃')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reselecting the same seat emote starts a fresh animation', (tester) async {
    Widget subject(int expiry) => MaterialApp(home: AnimatedEmoji(
      key: ValueKey('seat-emote-0-😂-$expiry'), emoji: '😂',
    ));
    await tester.pumpWidget(subject(100));
    await tester.pump(const Duration(milliseconds: 400));
    final moved = tester.widget<Transform>(find.byKey(
      const ValueKey('emoji-motion-offset'))).transform;
    expect(moved.getTranslation().y, lessThan(0));
    await tester.pumpWidget(subject(200));
    final restarted = tester.widget<Transform>(find.byKey(
      const ValueKey('emoji-motion-offset'))).transform;
    expect(restarted.getTranslation().y, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('rival gift override does not add romantic particles', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AnimatedEmoji(
      emoji: '🌹', effect: EmojiEffect.fire,
      timeline: AlwaysStoppedAnimation(.25),
    )));
    expect(find.text('🌹'), findsOneWidget);
    final offset = tester.widget<Transform>(find.byKey(
      const ValueKey('emoji-motion-offset'))).transform.getTranslation();
    // Rival sparks have the fire motion even when the glyph is a rose.
    expect(offset.y, lessThan(0));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
