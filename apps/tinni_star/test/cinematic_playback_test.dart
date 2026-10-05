import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/economy/premium_gift_catalog.dart';
import 'package:tinni_star/effects/cinematic_video.dart';
import 'package:tinni_star/effects/gift_scene_overlay.dart';
import 'package:tinni_star/effects/rocket_launch.dart';

void main() {
  test('only catalog gifts and the ten Rocket stages resolve to local movies', () {
    for (final gift in [
      ...PremiumGiftCatalog.normal,
      ...PremiumGiftCatalog.cp,
      ...PremiumGiftCatalog.countries,
    ]) {
      expect(CinematicAssets.movieFor(gift.id),
          'assets/cinematic/' + gift.id + '.mp4');
    }
    for (var level = 1; level <= 10; level++) {
      expect(CinematicAssets.movieFor('rocket-$level'),
          'assets/cinematic/rocket-$level.mp4');
    }
    expect(CinematicAssets.movieFor('rocket-11'), isNull);
    expect(CinematicAssets.movieFor('../../movie'), isNull);
    expect(CinematicAssets.movieFor('https://example.com/movie.mp4'), isNull);
  });

  testWidgets('missing movies keep fallback and deliver each recipient once',
      (tester) async {
    final queue = GiftSceneQueue();
    final delivered = <GiftSceneEvent>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GiftSceneOverlay(queue: queue, onDelivered: delivered.add),
      ),
    ));
    queue.add(GiftSceneEvent(
      gift: PremiumGiftCatalog.normal.first,
      recipients: ['a', 'b', 'a'],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('gift-scene-rose')), findsOneWidget);
    expect(find.byKey(const ValueKey('cinematic-video-rose')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(delivered.single.recipients, ['a', 'b']);
    await tester.pump(const Duration(seconds: 10));
    expect(delivered.length, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
  });

  testWidgets('effects off cancels active and queued gift scenes',
      (tester) async {
    final queue = GiftSceneQueue();
    final delivered = <GiftSceneEvent>[];
    Widget host(bool enabled) => MaterialApp(
      home: Scaffold(body: GiftSceneOverlay(
        queue: queue, enabled: enabled, onDelivered: delivered.add,
      )),
    );
    await tester.pumpWidget(host(true));
    for (var i = 0; i < 2; i++) {
      queue.add(GiftSceneEvent(
        gift: PremiumGiftCatalog.normal.first, recipients: ['a'],
      ));
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(host(false));
    await tester.pump(const Duration(seconds: 10));
    expect(delivered, isEmpty);
    expect(find.byKey(const ValueKey('gift-scene-rose')), findsNothing);
    await tester.pumpWidget(host(true));
    await tester.pump(const Duration(seconds: 10));
    expect(delivered, isEmpty);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
  });

  testWidgets('background time does not consume gift hold or deliver unseen',
      (tester) async {
    final queue = GiftSceneQueue();
    final delivered = <GiftSceneEvent>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: GiftSceneOverlay(queue: queue, onDelivered: delivered.add),
    )));
    queue.add(GiftSceneEvent(
      gift: PremiumGiftCatalog.normal.first, recipients: ['a'],
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(delivered, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(delivered.length, 1);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
  });

  testWidgets('all ten new Rocket milestones launch sequentially, no replay',
      (tester) async {
    final completed = ValueNotifier<int?>(0);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: RocketLaunchOverlay(completed: completed),
    )));
    completed.value = 10;
    await tester.pump();
    for (var level = 1; level <= 10; level++) {
      expect(find.byKey(ValueKey('launch-rocket-$level')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
    }
    expect(find.byKey(const Key('rocket-nine-second-launch')), findsNothing);
    completed.value = 10;
    await tester.pump();
    expect(find.byKey(const Key('rocket-nine-second-launch')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    completed.dispose();
  });

  testWidgets('Rocket effects off clears launches without replay on enable',
      (tester) async {
    final completed = ValueNotifier<int?>(0);
    Widget host(bool enabled) => MaterialApp(home: Scaffold(
      body: RocketLaunchOverlay(completed: completed, enabled: enabled),
    ));
    await tester.pumpWidget(host(true));
    completed.value = 2;
    await tester.pump();
    await tester.pumpWidget(host(false));
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpWidget(host(true));
    expect(find.byKey(const Key('rocket-nine-second-launch')), findsNothing);
    completed.value = 3;
    await tester.pump();
    expect(find.byKey(const ValueKey('launch-rocket-3')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    completed.dispose();
  });

  testWidgets('disposing a gift overlay cannot run a late delivery',
      (tester) async {
    final queue = GiftSceneQueue();
    final delivered = <GiftSceneEvent>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: GiftSceneOverlay(queue: queue, onDelivered: delivered.add),
    )));
    queue.add(GiftSceneEvent(
      gift: PremiumGiftCatalog.normal.first, recipients: ['a'],
    ));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(delivered, isEmpty);
    expect(tester.takeException(), isNull);
    queue.dispose();
  });
}
