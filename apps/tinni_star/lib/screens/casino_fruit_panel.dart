import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/casino_fruit_art.dart';

const casinoBetAmounts = <int>[5000, 25000, 100000, 500000, 2000000, 10000000];
const _board = <String?>['lemon', 'cherry', 'kiwi', 'strawberry', null,
  'watermelon', 'banana', 'raspberry', 'plum'];
const _track = <String>['lemon', 'cherry', 'kiwi', 'watermelon',
  'plum', 'raspberry', 'banana', 'strawberry'];
const _gold = Color(0xFFFFD580);
const _cream = Color(0xFFFFF2D4);

String casinoAmount(int value) {
  if (value >= 1000000) {
    final scaled = value / 1000000;
    return scaled.toStringAsFixed(scaled == scaled.roundToDouble() ? 0 : 1) + 'M';
  }
  if (value >= 100000) {
    final scaled = value / 100000;
    return scaled.toStringAsFixed(scaled == scaled.roundToDouble() ? 0 : 1) + 'L';
  }
  if (value >= 1000) {
    final scaled = value / 1000;
    return scaled.toStringAsFixed(scaled == scaled.roundToDouble() ? 0 : 1) + 'K';
  }
  return value.toString();
}

class CasinoFruit {
  const CasinoFruit({required this.key, required this.label, required this.multiplier, required this.bet});
  final String key;
  final String label;
  final int multiplier;
  final int bet;
}

class CasinoResult {
  const CasinoResult({required this.round, required this.fruit, this.lucky = false,
    this.bonus = const [], this.jackpot = false, required this.settledAt});
  final int round;
  final String fruit;
  final bool lucky;
  final List<String> bonus;
  final bool jackpot;
  final DateTime settledAt;
}

class CasinoSnapshot {
  const CasinoSnapshot({required this.connected, required this.loading,
    required this.bettingOpen, required this.spinning, required this.remaining,
    required this.spinRemaining, required this.roundDuration, required this.round,
    required this.balance, required this.mine, required this.winnings,
    required this.fruits, required this.history, this.jackpot, this.error});
  final bool connected;
  final bool loading;
  final bool bettingOpen;
  final bool spinning;
  final Duration remaining;
  final Duration spinRemaining;
  final int roundDuration;
  final int round;
  final int balance;
  final int mine;
  final int winnings;
  final List<CasinoFruit> fruits;
  final List<CasinoResult> history;
  final int? jackpot;
  final String? error;
}

/// Shared bottom-half placement for room and standalone game routes.
class CasinoGameDock extends StatelessWidget {
  const CasinoGameDock({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: FractionallySizedBox(heightFactor: .5, widthFactor: 1, child: child),
  );
}

class CasinoFruitPanel extends StatefulWidget {
  const CasinoFruitPanel({super.key, required this.title, required this.gameId,
    required this.source, required this.snapshot, required this.refresh,
    required this.bet, this.onClose, this.party = false});
  final String title;
  final String gameId;
  final Listenable source;
  final CasinoSnapshot Function() snapshot;
  final Future<void> Function() refresh;
  final Future<String?> Function(String fruit, int amount) bet;
  final VoidCallback? onClose;
  final bool party;

  @override
  State<CasinoFruitPanel> createState() => _CasinoFruitPanelState();
}

class _CasinoFruitPanelState extends State<CasinoFruitPanel> with WidgetsBindingObserver {
  Timer? _clock;
  Timer? _poll;
  Future<void>? _refreshFuture;
  int _selected = casinoBetAmounts.first;
  String? _pendingFruit;
  String _frame = '';
  bool _active = true;
  int _spinTick = 0;
  int _failures = 0;
  int? _refreshedBoundary;

  @override
  void initState() {
    super.initState();
    widget.source.addListener(_onServerChanged);
    WidgetsBinding.instance.addObserver(this);
    _startClock();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant CasinoFruitPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      oldWidget.source.removeListener(_onServerChanged);
      widget.source.addListener(_onServerChanged);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _clock?.cancel();
    _poll?.cancel();
    if (_active) {
      _startClock();
      unawaited(_refresh());
    }
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted || !_active) { return; }
      final view = widget.snapshot();
      if (!view.connected) { return; }
      _spinTick++;
      final seconds = _seconds(view.spinning ? view.spinRemaining : view.remaining);
      final moving = _moving(view);
      final result = _revealed(view)?.round;
      final frame = '$seconds:$moving:$result';
      if (frame != _frame) {
        _frame = frame;
        setState(() {});
      }
      // Refresh the authoritative phase as soon as a round expires.
      if (view.remaining == Duration.zero && !view.spinning && !_waiting && _refreshedBoundary != view.round) {
        _refreshedBoundary = view.round;
        unawaited(_refresh());
      }
    });
  }

  bool get _waiting => _refreshFuture != null;
  void _onServerChanged() {
    if (mounted && _active) setState(() {});
  }

  Future<void> _refresh() {
    final pending = _refreshFuture;
    if (pending != null) { return pending; }
    if (!mounted || !_active) { return Future<void>.value(); }
    final operation = _runRefresh();
    _refreshFuture = operation;
    return operation.whenComplete(() {
      if (identical(_refreshFuture, operation)) { _refreshFuture = null; }
    });
  }

  Future<void> _runRefresh() async {
    _poll?.cancel();
    try {
      await widget.refresh();
    } catch (_) {
      // The remote service retains the actual error for the status/retry UI.
    } finally {
      if (mounted && _active) {
        _failures = widget.snapshot().connected ? 0 : (_failures + 1).clamp(1, 3).toInt();
        setState(() {});
        _poll = Timer(Duration(seconds: _failures == 0 ? 2 : 2 + _failures * 2),
          () => unawaited(_refresh()));
      }
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _poll?.cancel();
    widget.source.removeListener(_onServerChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _seconds(Duration value) => math.max(0, (value.inMilliseconds + 999) ~/ 1000);
  String? _moving(CasinoSnapshot view) {
    if (!view.connected || (!view.bettingOpen && !view.spinning)) { return null; }
    final tick = view.spinning ? _spinTick
      : math.max(0, view.roundDuration - view.remaining.inMilliseconds) ~/ 300;
    return _track[tick % _track.length];
  }

  CasinoResult? _revealed(CasinoSnapshot view) {
    if (view.spinning || view.history.isEmpty) { return null; }
    final latest = view.history.first;
    final age = DateTime.now().difference(latest.settledAt).inMilliseconds;
    return age >= 0 && age < 8000 ? latest : null;
  }

  Future<void> _place(CasinoFruit fruit) async {
    if (_pendingFruit != null || !widget.snapshot().bettingOpen) { return; }
    final amount = _selected;
    setState(() => _pendingFruit = fruit.key);
    try {
      final error = await widget.bet(fruit.key, amount);
      if (!mounted) { return; }
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      } else {
        unawaited(HapticFeedback.selectionClick());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bet response interrupted. Refresh your balance before retrying.')),
        );
      }
    } finally {
      if (mounted) { setState(() => _pendingFruit = null); }
    }
  }

  void _history(CasinoSnapshot view) {
    showModalBottomSheet<void>(
      context: context, showDragHandle: true, backgroundColor: const Color(0xFF19112A),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(widget.title + ' • Recent results', style: const TextStyle(color: _gold,
              fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (view.history.isEmpty) const Text('No settled rounds yet.',
              style: TextStyle(color: _cream)),
            for (final result in view.history.take(20)) ListTile(
              leading: CasinoFruitArt(fruitKey: result.fruit, size: 36),
              title: Text(result.lucky ? 'Lucky 11 • three bonus fruits' : result.fruit,
                style: const TextStyle(color: _cream)),
              subtitle: Text('Round ' + result.round.toString(),
                style: const TextStyle(color: Colors.white60)),
              trailing: result.jackpot ? const Icon(Icons.stars_rounded, color: _gold) : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.snapshot();
    final result = _revealed(view);
    final moving = _moving(view);
    final seconds = _seconds(view.spinning ? view.spinRemaining : view.remaining);
    final disabledMotion = MediaQuery.disableAnimationsOf(context);
    final status = _pendingFruit != null ? 'Submitting bet…'
      : !view.connected ? (view.loading ? 'Connecting…' : view.error ?? 'Connection interrupted • Tap retry')
      : view.spinning ? 'RESULT SPIN'
      : view.bettingOpen ? 'BETTING OPEN' : 'NEXT ROUND';
    return RepaintBoundary(
      key: Key(widget.gameId + '-casino-surface'),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: widget.party
                ? const [Color(0xFF143833), Color(0xFF0B1D29), Color(0xFF251039)]
                : const [Color(0xFF341735), Color(0xFF171129), Color(0xFF290F20)]),
            border: Border.all(color: const Color(0xFFB79251), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x50260739), blurRadius: 18,
              offset: Offset(0, -5))],
          ),
          child: Column(
            children: [
              SizedBox(height: 44, child: Row(
                children: [
                  Container(width: 34, height: 34,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: const Color(0xFF513647), border: Border.all(color: _gold)),
                    child: Icon(widget.party ? Icons.casino_rounded : Icons.diamond_rounded,
                      color: _gold, size: 21)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(widget.title.toUpperCase(), maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _cream, fontSize: 14,
                          fontWeight: FontWeight.w900, letterSpacing: .7)),
                      Text(view.jackpot == null ? 'Pick your fruit • choose your chip'
                        : 'JACKPOT  ' + casinoAmount(view.jackpot!),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _gold, fontSize: 10,
                          fontWeight: FontWeight.w700)),
                    ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF100D1D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6F5668))),
                    child: Text(view.connected ? seconds.toString().padLeft(2, '0') + 's' : '—',
                      style: const TextStyle(color: _gold, fontSize: 17,
                        fontFeatures: [FontFeature.tabularFigures()], fontWeight: FontWeight.w900))),
                  IconButton(key: Key(widget.gameId + '-close'), tooltip: 'Close game',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded, color: _cream, size: 20)),
                ],
              )),
              SizedBox(height: 22, child: Row(children: [
                Icon(view.connected ? Icons.circle : Icons.wifi_off_rounded,
                  size: 8, color: view.connected ? const Color(0xFF86EFC6) : _gold),
                const SizedBox(width: 5),
                Expanded(child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _cream, fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: .4))),
                if (result?.jackpot == true) const Text('JACKPOT WIN!',
                  style: TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.w900)),
                IconButton(key: Key(widget.gameId + '-refresh'), tooltip: 'Refresh game',
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 22),
                  onPressed: _waiting ? null : () => unawaited(_refresh()),
                  icon: Icon(Icons.refresh_rounded, size: 16, color: _waiting ? Colors.white38 : _gold)),
              ])),
              const SizedBox(height: 4),
              Expanded(child: LayoutBuilder(builder: (context, constraints) {
                final height = math.max(168.0, constraints.maxHeight);
                final cellHeight = (height - 10) / 3;
                return SingleChildScrollView(
                  key: Key(widget.gameId + '-board-scroll'),
                  child: SizedBox(height: height, child: GridView.builder(
                    key: Key(widget.gameId + '-board'), padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(), itemCount: _board.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 5, mainAxisSpacing: 5,
                      childAspectRatio: ((constraints.maxWidth - 10) / 3) / cellHeight),
                    itemBuilder: (context, index) {
                      final key = _board[index];
                      if (key == null) {
                        return _RoundTile(
                          spinning: view.spinning, lucky: result?.lucky == true,
                          round: view.round, seconds: seconds, party: widget.party);
                      }
                      final fruit = view.fruits.firstWhere((fruit) => fruit.key == key);
                      final bonus = result?.bonus.contains(key) == true;
                      return _FruitTile(
                        fruit: fruit, moving: moving == key, bonus: bonus,
                        winner: result?.fruit == key && result?.lucky != true,
                        pending: _pendingFruit == key, disableMotion: disabledMotion,
                        onTap: view.bettingOpen && _pendingFruit == null
                          ? () => unawaited(_place(fruit)) : null,
                      );
                    },
                  )),
                );
              })),
              const SizedBox(height: 6),
              SizedBox(height: 36, child: Row(children: [
                for (var index = 0; index < casinoBetAmounts.length; index++) ...[
                  Expanded(child: _Chip(
                    key: Key(widget.gameId + '-chip-' + casinoBetAmounts[index].toString()),
                    label: casinoAmount(casinoBetAmounts[index]),
                    selected: _selected == casinoBetAmounts[index],
                    disableMotion: disabledMotion,
                    onTap: _pendingFruit != null ? null
                      : () => setState(() => _selected = casinoBetAmounts[index]))),
                  if (index < casinoBetAmounts.length - 1) const SizedBox(width: 4),
                ],
              ])),
              const SizedBox(height: 4),
              SizedBox(height: 26, child: Row(children: [
                const Icon(Icons.toll_rounded, color: _gold, size: 15),
                const SizedBox(width: 4),
                Expanded(child: Text(casinoAmount(view.balance),
                  key: Key(widget.gameId + '-balance'),
                  style: const TextStyle(color: _cream, fontSize: 11, fontWeight: FontWeight.w800))),
                Text('Bet ' + casinoAmount(view.mine) + '  •  Win ' + casinoAmount(view.winnings),
                  style: const TextStyle(color: Color(0xFFD6C5D0), fontSize: 9)),
                IconButton(key: Key(widget.gameId + '-history'), tooltip: 'Recent results',
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 26),
                  onPressed: () => _history(view),
                  icon: const Icon(Icons.history_rounded, color: _gold, size: 18)),
              ])),
            ],
          ),
        ),
      ),
    );
  }
}

class _FruitTile extends StatelessWidget {
  const _FruitTile({required this.fruit, required this.moving, required this.bonus,
    required this.winner, required this.pending, required this.disableMotion, this.onTap});
  final CasinoFruit fruit;
  final bool moving, bonus, winner, pending, disableMotion;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final active = moving || bonus || winner;
    final accent = bonus ? _gold : winner ? const Color(0xFF71E5B0) : const Color(0xFFD8A2FF);
    return Semantics(
      button: true, enabled: onTap != null,
      label: fruit.label + ', ' + fruit.multiplier.toString() + ' times, bet ' + fruit.bet.toString(),
      child: Material(color: Colors.transparent,
        child: InkWell(key: Key('casino-fruit-' + fruit.key),
          borderRadius: BorderRadius.circular(12), onTap: onTap,
          child: AnimatedContainer(duration: disableMotion ? Duration.zero : const Duration(milliseconds: 140),
            padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: active ? const [Color(0xFFFFFFFF), Color(0xFFFFE2A8)]
                  : const [Color(0xFFFFF9EC), Color(0xFFEDE1CD)]),
              border: Border.all(color: active ? accent : const Color(0xFFBBA481), width: 1.5),
              boxShadow: active ? [BoxShadow(color: accent.withValues(alpha: .35), blurRadius: 7)] : const []),
            child: LayoutBuilder(builder: (context, constraints) => Column(children: [
              Expanded(child: Center(child: CasinoFruitArt(fruitKey: fruit.key,
                size: math.min(constraints.maxWidth * .75, math.max(18.0, constraints.maxHeight - 22))))),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text(fruit.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF403045), fontSize: 9, fontWeight: FontWeight.w800))),
                const SizedBox(width: 3),
                Text(fruit.multiplier.toString() + '×',
                  style: const TextStyle(color: Color(0xFF8B481B), fontSize: 9, fontWeight: FontWeight.w900)),
              ]),
              SizedBox(height: 9, child: Text(pending ? 'Sending…'
                : fruit.bet > 0 ? casinoAmount(fruit.bet) + ' coins' : '',
                maxLines: 1, style: const TextStyle(color: Color(0xFF725848),
                  fontSize: 7, fontWeight: FontWeight.w700))),
            ])),
          ),
        ),
      ),
    );
  }
}

class _RoundTile extends StatelessWidget {
  const _RoundTile({required this.spinning, required this.lucky, required this.round,
    required this.seconds, required this.party});
  final bool spinning, lucky, party;
  final int round, seconds;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(colors: [Color(0xFF664044), Color(0xFF31233E)]),
      border: Border.all(color: _gold, width: 1.5)),
    child: LayoutBuilder(builder: (context, constraints) => FittedBox(
      fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.all(4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(lucky ? Icons.auto_awesome_rounded : Icons.casino_rounded, color: _gold, size: 21),
          Text(lucky ? 'LUCKY 11' : spinning ? 'RESULT' : party ? 'FRUIT PARTY' : 'JACKPOT',
            style: const TextStyle(color: _cream, fontSize: 9, fontWeight: FontWeight.w900)),
          Text(lucky ? '3 bonus fruits' : round > 0 ? 'ROUND ' + round.toString() : 'LIVE ROUNDS',
            style: const TextStyle(color: Color(0xFFE6C8A6), fontSize: 7)),
        ]),
      ),
    )),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.selected,
    required this.disableMotion, this.onTap});
  final String label;
  final bool selected, disableMotion;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true, selected: selected, enabled: onTap != null, label: label + ' coins',
    child: Material(color: Colors.transparent, child: InkWell(
      borderRadius: BorderRadius.circular(18), onTap: onTap,
      child: AnimatedContainer(
        duration: disableMotion ? Duration.zero : const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: selected
            ? const [Color(0xFFFFE9AA), Color(0xFFECAF4E)]
            : const [Color(0xFF40324E), Color(0xFF251B34)]),
          border: Border.all(color: selected ? _cream : const Color(0xFF947451), width: 1.5)),
        child: Text(label, maxLines: 1,
          style: TextStyle(color: selected ? const Color(0xFF432A28) : _gold,
            fontSize: 11, fontWeight: FontWeight.w900)),
      ),
    )),
  );
}
