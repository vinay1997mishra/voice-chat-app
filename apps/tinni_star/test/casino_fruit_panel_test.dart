import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/screens/casino_fruit_panel.dart';
import 'package:tinni_star/ui/casino_fruit_art.dart';

class _Game extends ChangeNotifier {
  int balance = 50000;
  int mine = 0;
  int round = 1;
  Duration remaining = const Duration(seconds: 21);
  CasinoSnapshot snapshot() => CasinoSnapshot(
    connected: true, loading: false, bettingOpen: remaining > Duration.zero,
    spinning: false, remaining: remaining, spinRemaining: Duration.zero,
    roundDuration: 21000, round: round, balance: balance, mine: mine, winnings: 0,
    jackpot: 85763, history: const [],
    fruits: [
      for (final key in ['lemon', 'cherry', 'kiwi', 'strawberry',
        'watermelon', 'banana', 'raspberry', 'plum'])
        CasinoFruit(key: key, label: key[0].toUpperCase() + key.substring(1),
          multiplier: 5, bet: key == 'lemon' ? mine : 0),
    ],
  );
  void change() => notifyListeners();
}

Widget _harness(_Game game, {required String id, bool party = false,
  Future<void> Function()? refresh, Future<String?> Function(String, int)? bet,
  VoidCallback? close}) => RepaintBoundary(
    key: const Key('casino-preview-root'),
    child: MaterialApp(home: Scaffold(backgroundColor: const Color(0xFF100C1C),
      body: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: CasinoGameDock(child: CasinoFruitPanel(
          title: party ? 'Fruit Party' : 'Fruit Jackpot', gameId: id,
          party: party, source: game, snapshot: game.snapshot,
          refresh: refresh ?? () async {}, bet: bet ?? (_, _) async => null, onClose: close,
        )),
      ),
    )),
  );

void main() {
  for (final party in [false, true]) {
    for (final size in [const Size(360, 640), const Size(412, 892), const Size(640, 360)]) {
      testWidgets('casino bottom-half layout fits ' + size.toString() + ' party=' + party.toString(),
        (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final game = _Game();
        final id = party ? 'fruit-party' : 'fruit-jackpot';
        await tester.pumpWidget(_harness(game, id: id, party: party));
        await tester.pump(const Duration(milliseconds: 180));
        final surface = find.byKey(Key(id + '-casino-surface'));
        expect(tester.getSize(surface).height, closeTo(size.height / 2, .01));
        expect(tester.getBottomLeft(surface).dy, closeTo(size.height, .01));
        expect(tester.getTopLeft(surface).dy, closeTo(size.height / 2, .01));
        expect(find.byType(CasinoFruitArt), findsNWidgets(8));
        for (final amount in casinoBetAmounts) {
          expect(find.byKey(Key(id + '-chip-' + amount.toString())), findsOneWidget);
        }
        expect(tester.takeException(), isNull);

        // Export representative renders for review alongside the APK.
        if (size == const Size(360, 640)) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('casino-preview-root')));
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory('build/game_previews');
            await directory.create(recursive: true);
            await File(directory.path + '/' + id + '.png').writeAsBytes(
              bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        game.dispose();
      });
    }
  }

  testWidgets('a pending bet freezes its amount and rejects additional fruit taps', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = _Game();
    final pending = Completer<String?>();
    var calls = 0, amount = 0;
    await tester.pumpWidget(_harness(game, id: 'fruit-jackpot', bet: (fruit, value) {
      calls++; amount = value;
      return pending.future;
    }));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fruit-jackpot-chip-25000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('casino-fruit-lemon')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('casino-fruit-cherry')));
    await tester.tap(find.byKey(const Key('fruit-jackpot-chip-100000')));
    await tester.pump();
    expect(calls, 1);
    expect(amount, 25000);
    expect(game.balance, 50000);
    expect(game.mine, 0);
    game.balance = 25000; game.mine = 25000;
    pending.complete(null);
    game.change();
    await tester.pump();
    expect(find.byKey(const Key('fruit-jackpot-balance')), findsOneWidget);
    expect(find.text('25K'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('round expiry refreshes immediately and game close stops polling', (tester) async {
    final game = _Game();
    var requests = 0;
    await tester.pumpWidget(_harness(game, id: 'fruit-party', refresh: () async {
      requests++;
      if (game.remaining == Duration.zero) {
        game.round++;
        game.remaining = const Duration(seconds: 21);
        game.change();
      }
    }));
    await tester.pump();
    expect(requests, 1);
    game.remaining = Duration.zero;
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(requests, 2);
    expect(game.round, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 8));
    expect(requests, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(requests, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
    expect(requests, 3);
    game.dispose();
  });
}
