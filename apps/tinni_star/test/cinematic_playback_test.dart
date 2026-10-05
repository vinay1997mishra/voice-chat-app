import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/economy/premium_gift_catalog.dart';
import 'package:tinni_star/effects/cinematic_video.dart';
import 'package:tinni_star/effects/cinematic_lane.dart';
import 'package:tinni_star/effects/gift_scene_overlay.dart';
import 'package:tinni_star/effects/rocket_launch.dart';
import 'package:tinni_star/ui/rocket_personal_reward.dart';

class _MissingMovieBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.endsWith('.mp4')) {
      return Future<ByteData>.error(StateError('Missing cinematic movie'));
    }
    return rootBundle.load(key);
  }
}

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
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _MissingMovieBundle(),
      child: MaterialApp(
        home: Scaffold(
          body: GiftSceneOverlay(queue: queue, onDelivered: delivered.add),
        ),
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

  testWidgets('gift and Rocket movies share one fair lane without overlap',
      (tester) async {
    final queue = GiftSceneQueue();
    final lane = CinematicLane();
    final completed = ValueNotifier<int?>(0);
    final delivered = <GiftSceneEvent>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Stack(
      fit: StackFit.expand,
      children: [
        GiftSceneOverlay(queue: queue, lane: lane, onDelivered: delivered.add),
        RocketLaunchOverlay(completed: completed, lane: lane),
      ],
    ))));
    queue.add(GiftSceneEvent(
      gift: PremiumGiftCatalog.normal.first, recipients: ['first'],
    ));
    await tester.pump();
    completed.value = 1;
    queue.add(GiftSceneEvent(
      gift: PremiumGiftCatalog.normal.first, recipients: ['second'],
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('gift-scene-rose')), findsOneWidget);
    expect(find.byKey(const Key('rocket-nine-second-launch')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(delivered.single.recipients, ['first']);
    expect(find.byKey(const ValueKey('gift-scene-rose')), findsNothing);
    expect(find.byKey(const ValueKey('launch-rocket-1')), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(find.byKey(const Key('rocket-nine-second-launch')), findsNothing);
    expect(find.byKey(const ValueKey('gift-scene-rose')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(delivered.map((e) => e.recipients.single), ['first', 'second']);
    await tester.pumpWidget(const SizedBox());
    completed.dispose();
    queue.dispose();
    lane.dispose();
  });
  test('received rewards require the exact viewer and launch', () {
    final payload = <String, dynamic>{
      'ok': true, 'level': 2,
      'reward': {'user_id': 'me', 'awarded': true, 'coins': 4321,
        'credited': true, 'frame_id': null, 'medal': null},
    };
    expect(RocketPersonalReward.fromResponse(payload, viewerId: 'other', level: 2), isNull);
    expect(RocketPersonalReward.fromResponse(payload, viewerId: 'me', level: 3), isNull);
    expect(RocketPersonalReward.fromResponse(payload, viewerId: 'me', level: 2)!.coins, 4321);
    expect(rocketCountdown(0), 9);
    expect(rocketCountdown(7 / 9), 2);
    expect(rocketCountdown(8 / 9), 1);
    expect(rocketHasLifted(7.999 / 9), false);
    expect(rocketHasLifted(8 / 9), true);
  });

  testWidgets('countdown holds the pad through 2, lifts at 1, then shows only own reward',
      (tester) async {
    final completed = ValueNotifier<int?>(0);
    var reads = 0;
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _MissingMovieBundle(),
      child: MaterialApp(home: Scaffold(body: RocketLaunchOverlay(
        completed: completed, viewerId: 'me',
        loadReward: (level) async {
          reads++;
          return RocketPersonalReward(userId: 'me', level: level,
            coins: 4321, credited: true);
        },
      ))),
    ));
    completed.value = 1;
    await tester.pump();
    await tester.pump();
    final rocket = find.byKey(const ValueKey('launch-rocket-1'));
    final pad = tester.getTopLeft(rocket);
    expect(find.text('9'), findsOneWidget);
    expect(reads, 0);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('2'), findsOneWidget);
    expect(tester.getTopLeft(rocket).dy, pad.dy);
    expect(find.text('BUILDING PRESSURE'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('LIFTOFF'), findsOneWidget);
    expect(reads, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getTopLeft(rocket).dy, lessThan(pad.dy));
    expect(find.byKey(const Key('rocket-personal-reward')), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(reads, 1);
    expect(find.text('4321 coins'), findsOneWidget);
    expect(find.byKey(const Key('rocket-nine-second-launch')), findsNothing);
    await tester.tap(find.byKey(const Key('rocket-personal-reward-close')));
    await tester.pump();
    expect(find.byKey(const Key('rocket-personal-reward')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    completed.dispose();
  });

  testWidgets('another user reward never appears even if a loader returns it',
      (tester) async {
    final completed = ValueNotifier<int?>(0);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RocketLaunchOverlay(
      completed: completed, viewerId: 'me',
      loadReward: (level) async => RocketPersonalReward(
        userId: 'someone-else', level: level, coins: 987654, credited: true),
    ))));
    completed.value = 1;
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(find.text('987654 coins'), findsNothing);
    expect(find.byKey(const Key('rocket-personal-reward')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    completed.dispose();
  });

  testWidgets('account change cancels a pending private reward read',
      (tester) async {
    final completed = ValueNotifier<int?>(0);
    final pending = Completer<RocketPersonalReward?>();
    Widget host(String viewer) => MaterialApp(home: Scaffold(
      body: RocketLaunchOverlay(completed: completed, viewerId: viewer,
        loadReward: (_) => pending.future),
    ));
    await tester.pumpWidget(host('first'));
    completed.value = 1;
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpWidget(host('second'));
    pending.complete(const RocketPersonalReward(
      userId: 'first', level: 1, coins: 12345, credited: true));
    await tester.pump();
    expect(find.text('12345 coins'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    completed.dispose();
  });

  testWidgets('ordinary country flag holds at center for two seconds then delivers once',
      (tester) async {
    final queue = GiftSceneQueue();
    final delivered = <GiftSceneEvent>[];
    final india = PremiumGiftCatalog.find('flag-in')!;
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _MissingMovieBundle(),
      child: MaterialApp(home: Scaffold(body: GiftSceneOverlay(
        queue: queue, onDelivered: delivered.add))),
    ));
    queue.add(GiftSceneEvent(gift: india, recipients: ['receiver']));
    await tester.pump();
    expect(find.text(india.name), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(delivered, isEmpty);
    expect(find.byKey(const ValueKey('gift-scene-flag-in')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(delivered.single.gift.id, 'flag-in');
    expect(delivered.single.recipients, ['receiver']);
    await tester.pump(const Duration(seconds: 5));
    expect(delivered.length, 1);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
  });

  testWidgets('queued Rocket cannot hide a shrinking country recipient flight',
      (tester) async {
    final queue = GiftSceneQueue(), lane = CinematicLane();
    final completed = ValueNotifier<int?>(0);
    final delivered = <GiftSceneEvent>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Stack(
      fit: StackFit.expand,
      children: [
        GiftSceneOverlay(queue: queue, lane: lane, onDelivered: delivered.add),
        RocketLaunchOverlay(completed: completed, lane: lane),
      ],
    ))));
    queue.add(GiftSceneEvent(
      gift: PremiumGiftCatalog.find('flag-in')!, recipients: ['receiver'],
    ));
    await tester.pump();
    final stage = tester.getSize(find.byKey(const Key('country-flag-large-center')));
    final viewport = tester.getSize(find.byType(Scaffold));
    expect(stage.height, greaterThan(viewport.height / 2));
    expect(stage.width, greaterThan(viewport.width * .9));
    completed.value = 1;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(delivered.single.recipients, ['receiver']);
    expect(find.byKey(const Key('rocket-nine-second-launch')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1449));
    expect(find.byKey(const Key('rocket-nine-second-launch')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(const Key('rocket-nine-second-launch')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
    lane.dispose();
    completed.dispose();
  });

}
