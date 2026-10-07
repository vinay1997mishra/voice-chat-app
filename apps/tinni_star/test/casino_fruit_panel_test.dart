import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/screens/casino_fruit_panel.dart';
import 'package:tinni_star/ui/casino_fruit_art.dart';

class _Game extends ChangeNotifier {
  _Game({this.party = false});
  final bool party;
  List<CasinoResult> history = [];
  int balance = 50000;
  int mine = 0;
  int round = 1;
  bool spinning = false;
  Map<String, dynamic>? lastBetResult;
  Duration remaining = const Duration(seconds: 21);
  CasinoSnapshot snapshot() => CasinoSnapshot(
    connected: true, loading: false, bettingOpen: !spinning && remaining > Duration.zero,
    spinning: spinning, remaining: remaining,
    spinRemaining: spinning ? const Duration(seconds: 5) : Duration.zero,
    roundDuration: 21000, round: round, balance: balance, mine: mine, winnings: 0,
    jackpot: party ? null : 85763, history: history, lastBetResult: lastBetResult,
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
  VoidCallback? close, Future<void> Function()? connectLive, VoidCallback? disconnectLive,
  bool Function()? liveConnected}) => RepaintBoundary(
    key: const Key('casino-preview-root'),
    child: MaterialApp(home: Scaffold(backgroundColor: const Color(0xFF100C1C),
      body: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: CasinoGameDock(child: CasinoFruitPanel(
          title: party ? 'Fruit Party' : 'Fruit Jackpot', gameId: id,
          party: party, source: game, snapshot: game.snapshot,
          connectLive: connectLive, disconnectLive: disconnectLive, liveConnected: liveConnected,
          refresh: refresh ?? () async {}, bet: bet ?? (_, _) async => null, onClose: close,
        )),
      ),
    )),
  );

void main() {
  testWidgets('live game reads once on entry, accepts push, and refreshes only on user request', (tester) async {
    final game = _Game();
    var reads = 0, connects = 0, disconnects = 0;
    await tester.pumpWidget(_harness(game, id: 'fruit-party', party: true,
      refresh: () async { reads++; },
      connectLive: () async { connects++; },
      disconnectLive: () { disconnects++; },
      liveConnected: () => true,
    ));
    await tester.pump();
    expect(reads, 1);
    expect(connects, 1);
    await tester.pump(const Duration(minutes: 2));
    expect(reads, 1);
    game.balance = 76543;
    game.change();
    await tester.pump();
    expect(find.text('76.5K'), findsWidgets);
    await tester.tap(find.byKey(const Key('fruit-party-refresh')));
    await tester.pump();
    expect(reads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(disconnects, 1);
    game.dispose();
  });

  testWidgets('disconnected live socket falls back to state refresh', (tester) async {
    final game = _Game();
    var reads = 0;
    var live = false;
    await tester.pumpWidget(_harness(
      game,
      id: 'fruit-jackpot',
      connectLive: () async {},
      liveConnected: () => live,
      refresh: () async {
        reads++;
        if (reads == 2) {
          game.spinning = true;
          game.remaining = Duration.zero;
          game.history = [
            CasinoResult(
              round: 1,
              fruit: 'cherry',
              settledAt: DateTime.now().toUtc(),
            ),
          ];
          game.change();
        }
      },
    ));
    await tester.pump();
    expect(reads, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(reads, greaterThanOrEqualTo(2));
    expect(find.byKey(const Key('fruit-jackpot-floating-result')), findsOneWidget);
    expect(find.byTooltip('Round 1 • cherry'), findsOneWidget);

    live = true;
    game.change();
    await tester.pump();
    final readsWhenLive = reads;
    await tester.pump(const Duration(seconds: 5));
    expect(reads, readsWhenLive);
    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  test('latest seven results sort by round and remove repeated snapshots', () {
    final rows = [for (var round = 1; round <= 10; round++)
      CasinoResult(round: round, fruit: 'lemon', settledAt: DateTime(2026))];
    final recent = recentCasinoResults([...rows, rows.last, rows[8]]);
    expect(recent.map((row) => row.round), [10, 9, 8, 7, 6, 5, 4]);
  });

  for (final party in [false, true]) {
    testWidgets('latest result replaces oldest while seven slots remain party=$party', (tester) async {
      final game = _Game(party: party);
      final id = party ? 'fruit-party' : 'fruit-jackpot';
      game.history = [for (var round = 1; round <= 7; round++)
        CasinoResult(round: round, fruit: 'lemon', settledAt: DateTime(2026))];
      await tester.pumpWidget(_harness(game, id: id, party: party));
      await tester.pump();
      for (var slot = 0; slot < 7; slot++) {
        expect(find.byKey(Key(id + '-recent-slot-$slot')), findsOneWidget);
      }
      expect(find.byTooltip('Round 7 • lemon'), findsOneWidget);
      game.history.insert(0, CasinoResult(round: 8, fruit: 'cherry', settledAt: DateTime(2026)));
      game.change();
      await tester.pump();
      expect(find.byTooltip('Round 8 • cherry'), findsOneWidget);
      expect(find.byTooltip('Round 1 • lemon'), findsNothing);
      expect(find.byTooltip('Round 2 • lemon'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      game.dispose();
    });
  }

  for (final party in [false, true]) {
    for (final size in [const Size(360, 640), const Size(412, 892), const Size(640, 360)]) {
      testWidgets('casino bottom-half layout fits ' + size.toString() + ' party=' + party.toString(),
        (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final game = _Game(party: party);
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

  testWidgets('settled result floats during result spin and lists every personal bet', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = _Game();
    game.spinning = true;
    game.remaining = Duration.zero;
    game.history = [
      CasinoResult(
        round: 1,
        fruit: 'cherry',
        settledAt: DateTime.now().toUtc(),
        topWinners: const [
          {'user_id': '1001', 'display_name': 'Alice', 'winning_coins': 100000},
          {'user_id': '1002', 'display_name': 'Bob', 'winning_coins': 50000},
        ],
      ),
    ];
    game.lastBetResult = {
      'round_id': 1,
      'bet_coins': 30000,
      'winning_coins': 100000,
      'outcome': 'win',
      'bets': [
        {'fruit_key': 'lemon', 'bet_coins': 5000, 'winning_coins': 0, 'outcome': 'lose'},
        {'fruit_key': 'cherry', 'bet_coins': 25000, 'winning_coins': 100000, 'outcome': 'win'},
      ],
    };
    await tester.pumpWidget(_harness(game, id: 'fruit-jackpot'));
    await tester.pump();
    expect(find.byKey(const Key('fruit-jackpot-floating-result')), findsOneWidget);
    expect(find.textContaining('LAST RESULT'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.textContaining('5K → LOSE'), findsOneWidget);
    expect(find.textContaining('25K → +1L'), findsOneWidget);

    await tester.tap(find.byKey(const Key('fruit-jackpot-history')));
    await tester.pumpAndSettle();
    expect(find.textContaining('lemon • Bet 5K'), findsOneWidget);
    expect(find.textContaining('cherry • Bet 25K'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('same-round server bets keep floating BET and WIN nonzero while receipt catches up', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = _Game();
    game.spinning = true;
    game.remaining = Duration.zero;
    game.mine = 25000;
    game.history = [
      CasinoResult(
        round: 1,
        fruit: 'lemon',
        settledAt: DateTime.now().toUtc(),
      ),
    ];
    game.lastBetResult = null;
    await tester.pumpWidget(_harness(game, id: 'fruit-jackpot'));
    await tester.pump();
    expect(find.byKey(const Key('fruit-jackpot-floating-result')), findsOneWidget);
    expect(find.text('BET 25K • WIN 1.3L'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('rapid intentional taps each submit and appear immediately', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = _Game();
    final pending = Completer<String?>();
    var calls = 0;
    await tester.pumpWidget(_harness(game, id: 'fruit-jackpot', bet: (fruit, value) {
      calls++;
      return pending.future;
    }));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fruit-jackpot-chip-25000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('casino-fruit-lemon')));
    await tester.tap(find.byKey(const Key('casino-fruit-lemon')));
    await tester.pump();
    expect(calls, 2);
    expect(find.textContaining('50K coins'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fruit-jackpot-chip-100000')));
    await tester.pump();
    pending.complete(null);
    game.balance = 0; game.mine = 50000; game.change();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('a cached board submits a bet immediately even while refresh is pending', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = _Game();
    final refresh = Completer<void>();
    var bets = 0;
    await tester.pumpWidget(_harness(game, id: 'fruit-jackpot',
      refresh: () => refresh.future,
      bet: (_, _) async { bets++; return null; }));
    await tester.pump();
    await tester.tap(find.byKey(const Key('casino-fruit-lemon')));
    await tester.pump();
    expect(bets, 1);
    refresh.complete();
    await tester.pump();
    expect(bets, 1);
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
