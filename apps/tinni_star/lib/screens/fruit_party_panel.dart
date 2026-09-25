import 'dart:async';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../games/fruit_party_game.dart';
import '../games/fruit_party_remote.dart';

class FruitPartyPanel extends StatefulWidget {
  const FruitPartyPanel({
    super.key,
    required this.state,
    this.onClose,
  });

  final TinniState state;
  final VoidCallback? onClose;

  @override
  State<FruitPartyPanel> createState() => _FruitPartyPanelState();
}

class _FruitPartyPanelState extends State<FruitPartyPanel> {
  static const _betAmounts = <int>[
    5000,
    25000,
    100000,
    500000,
    2000000,
    10000000,
  ];

  static const _board = <FruitPartyKind?>[
    FruitPartyKind.lemon,
    FruitPartyKind.cherry,
    FruitPartyKind.kiwi,
    FruitPartyKind.strawberry,
    null,
    FruitPartyKind.watermelon,
    FruitPartyKind.banana,
    FruitPartyKind.raspberry,
    FruitPartyKind.plum,
  ];

  static const _movingOrder = <FruitPartyKind>[
    FruitPartyKind.lemon,
    FruitPartyKind.cherry,
    FruitPartyKind.kiwi,
    FruitPartyKind.watermelon,
    FruitPartyKind.plum,
    FruitPartyKind.raspberry,
    FruitPartyKind.banana,
    FruitPartyKind.strawberry,
  ];

  Timer? _animationTimer;
  Timer? _serverTimer;
  int _tick = 0;
  int _selectedBet = 5000;

  FruitPartyRemoteService get game => widget.state.fruitPartyRemote;
  String get authToken => widget.state.auth.current!.authToken;

  @override
  void initState() {
    super.initState();
    _sync();
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) {
        if (mounted) setState(() => _tick += 1);
      },
    );
    _serverTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _sync(),
    );
  }

  Future<void> _sync() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    await game.sync(account.authToken);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _serverTimer?.cancel();
    super.dispose();
  }

  int get _secondsLeft {
    final ms = game.remaining().inMilliseconds;
    if (ms <= 0) return 0;
    return ((ms + 999) ~/ 1000).clamp(0, 21).toInt();
  }

  FruitPartyKind get _movingFruit {
    final roundMs = game.roundDurationMs <= 0 ? 21000 : game.roundDurationMs;
    final remainingMs = game.remaining().inMilliseconds.clamp(0, roundMs);
    final elapsedMs = roundMs - remainingMs;
    final interval = remainingMs <= 5000 ? 80 : 220;
    return _movingOrder[(elapsedMs ~/ interval) % _movingOrder.length];
  }

  FruitPartyRoundResult? get _latest =>
      game.history.isEmpty ? null : game.history.first;

  bool _fresh(FruitPartyRoundResult? result) {
    if (result == null) return false;
    final age = DateTime.now().difference(result.settledAt.toLocal()).inSeconds;
    return age >= 0 && age < 21;
  }

  String _compact(int value) {
    if (value >= 10000000 && value % 1000000 == 0) {
      return '${value ~/ 1000000}M';
    }
    if (value >= 1000000) {
      final n = value / 1000000;
      return '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)}M';
    }
    if (value >= 100000) {
      final n = value / 100000;
      return '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)}L';
    }
    if (value >= 1000) return '${value ~/ 1000}K';
    return value.toString();
  }

  String _betLabel(int value) {
    switch (value) {
      case 5000:
        return '5K';
      case 25000:
        return '25K';
      case 100000:
        return '1L';
      case 500000:
        return '5L';
      case 2000000:
        return '2M';
      case 10000000:
        return '10M';
      default:
        return _compact(value);
    }
  }

  Future<void> _placeBet(FruitPartyKind fruit) async {
    final error = await game.placeBet(
      authToken: authToken,
      fruit: fruit,
      amount: _selectedBet,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    final latestFresh = _fresh(latest);
    final luckyActive = latestFresh && latest?.isLucky11 == true;
    final bonusFruits = luckyActive
        ? latest!.bonusFruits.toSet()
        : const <FruitPartyKind>{};
    final frameBlink = (_tick ~/ 7).isEven;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 480;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.fromLTRB(8, tight ? 6 : 8, 8, 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF15115A),
                Color(0xFF08132E),
                Color(0xFF25103E),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: frameBlink
                  ? const Color(0xFFFFD95B)
                  : const Color(0xFFB63CFF),
              width: frameBlink ? 2.4 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: (frameBlink
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFF8B2CFF))
                    .withValues(alpha: 0.42),
                blurRadius: frameBlink ? 18 : 10,
                spreadRadius: frameBlink ? 1.5 : 0,
              ),
            ],
          ),
          child: Column(
            children: [
              _PartyHeader(
                secondsLeft: _secondsLeft,
                compact: tight,
                onClose: widget.onClose,
              ),
              SizedBox(height: tight ? 4 : 6),
              Expanded(
                child: Stack(
                  children: [
                    GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _board.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                        childAspectRatio: 1.43,
                      ),
                      itemBuilder: (context, index) {
                        final fruit = _board[index];
                        if (fruit == null) {
                          return _PartyLucky11Tile(
                            active: luckyActive,
                            tick: _tick,
                          );
                        }

                        final mine = game.userBetForFruit(fruit);
                        final moving = game.bettingOpen &&
                            fruit == _movingFruit;
                        final bonus = bonusFruits.contains(fruit);
                        final winner = latestFresh &&
                            latest?.isLucky11 != true &&
                            latest?.fruit == fruit;

                        return _PartyFruitTile(
                          fruit: fruit,
                          myBet: mine,
                          moving: moving,
                          bonus: bonus,
                          winner: winner,
                          compact: tight,
                          onTap: game.bettingOpen
                              ? () => _placeBet(fruit)
                              : null,
                        );
                      },
                    ),
                    if (luckyActive)
                      Positioned(
                        left: 4,
                        right: 4,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: LinearGradient(
                                colors: (_tick ~/ 2).isEven
                                    ? const [
                                        Color(0x00FF42D9),
                                        Color(0xFFFF42D9),
                                        Color(0xFFFFD84D),
                                        Color(0x00FF42D9),
                                      ]
                                    : const [
                                        Color(0x00FFD84D),
                                        Color(0xFF57E7FF),
                                        Color(0xFFFF42D9),
                                        Color(0x00FFD84D),
                                      ],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xAAFF42D9),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (luckyActive) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: LinearGradient(
                      colors: (_tick ~/ 3).isEven
                          ? const [
                              Color(0xFF5C0B82),
                              Color(0xFFB6128D),
                              Color(0xFF4A1B8C),
                            ]
                          : const [
                              Color(0xFF4A1B8C),
                              Color(0xFFE08720),
                              Color(0xFF5C0B82),
                            ],
                    ),
                  ),
                  child: Text(
                    'LUCKY 11 • 3 EXTRA: ${latest!.bonusFruits.map((f) => f.emoji).join('  ')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
              SizedBox(height: tight ? 4 : 6),
              SizedBox(
                height: tight ? 29 : 33,
                child: Row(
                  children: [
                    for (var index = 0;
                        index < _betAmounts.length;
                        index++) ...[
                      Expanded(
                        child: _PartyBetButton(
                          label: _betLabel(_betAmounts[index]),
                          selected: _selectedBet == _betAmounts[index],
                          onTap: () => setState(
                            () => _selectedBet = _betAmounts[index],
                          ),
                        ),
                      ),
                      if (index != _betAmounts.length - 1)
                        const SizedBox(width: 4),
                    ],
                  ],
                ),
              ),
              SizedBox(height: tight ? 3 : 5),
              Row(
                children: [
                  Expanded(
                    child: _PartyFooterStat(
                      label: 'Mine',
                      value: _compact(game.userTotalBet),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    flex: 2,
                    child: _PartyResultStrip(history: game.history),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _PartyFooterStat(
                      label: 'Today Win',
                      value: _compact(game.todayWinnings),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PartyHeader extends StatelessWidget {
  const _PartyHeader({
    required this.secondsLeft,
    required this.compact,
    this.onClose,
  });

  final int secondsLeft;
  final bool compact;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.celebration_rounded,
          color: Color(0xFFFFD54F),
          size: 22,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: compact ? 5 : 7,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF5514A6),
                  Color(0xFF1D3FA2),
                  Color(0xFF8A1A75),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFD54F),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66FFD54F),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Text(
              'FRUIT PARTY',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFFF1A7),
                fontSize: compact ? 15 : 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          constraints: const BoxConstraints(minWidth: 58),
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF250844),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF4FD8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FF4FD8),
                blurRadius: 9,
              ),
            ],
          ),
          child: Text(
            '${secondsLeft}s',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFFFE8FF),
              fontSize: compact ? 15 : 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (onClose != null) ...[
          const SizedBox(width: 2),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Close game',
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 20,
            ),
          ),
        ],
      ],
    );
  }
}

class _PartyFruitTile extends StatelessWidget {
  const _PartyFruitTile({
    required this.fruit,
    required this.myBet,
    required this.moving,
    required this.bonus,
    required this.winner,
    required this.compact,
    this.onTap,
  });

  final FruitPartyKind fruit;
  final int myBet;
  final bool moving;
  final bool bonus;
  final bool winner;
  final bool compact;
  final VoidCallback? onTap;

  static String _tinyCompact(int value) {
    if (value >= 1000000) {
      final n = value / 1000000;
      return '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)}M';
    }
    if (value >= 100000) {
      final n = value / 100000;
      return '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)}L';
    }
    if (value >= 1000) return '${value ~/ 1000}K';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = moving || bonus || winner;
    final highlight = bonus
        ? const Color(0xFFFFD54F)
        : winner
            ? const Color(0xFF6DFFB2)
            : const Color(0xFF54D7FF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: EdgeInsets.all(compact ? 3 : 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF142D48),
                Color(0xFF0A162B),
                Color(0xFF291142),
              ],
            ),
            border: Border.all(
              color: highlighted ? highlight : const Color(0xFF6E3A9A),
              width: highlighted ? 2.3 : 1.1,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: highlight.withValues(alpha: 0.75),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    fruit.emoji,
                    style: TextStyle(fontSize: compact ? 24 : 29),
                  ),
                  Text(
                    '${fruit.multiplier}×',
                    style: TextStyle(
                      color: const Color(0xFFFFEEBD),
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (myBet > 0)
                    Text(
                      'Bet ${_tinyCompact(myBet)}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFFB8B8D6),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (bonus)
                const Positioned(
                  top: 0,
                  right: 1,
                  child: Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFD54F),
                    size: 15,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartyLucky11Tile extends StatelessWidget {
  const _PartyLucky11Tile({
    required this.active,
    required this.tick,
  });

  final bool active;
  final int tick;

  @override
  Widget build(BuildContext context) {
    final phase = (tick ~/ 2).isEven;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: active
                  ? (phase
                      ? const [
                          Color(0xFFFF31C6),
                          Color(0xFF8E24FF),
                          Color(0xFFFF9E2D),
                        ]
                      : const [
                          Color(0xFFFFC83D),
                          Color(0xFFE31BFF),
                          Color(0xFF3A53FF),
                        ])
                  : const [
                      Color(0xFF6C126E),
                      Color(0xFF3A145E),
                      Color(0xFF9A3A13),
                    ],
            ),
            border: Border.all(
              color:
                  active ? const Color(0xFFFFF080) : const Color(0xFFFF52E5),
              width: active ? 2.4 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (active
                        ? const Color(0xFFFF46DB)
                        : const Color(0xFF8E24FF))
                    .withValues(alpha: active ? 0.9 : 0.45),
                blurRadius: active ? 19 : 9,
                spreadRadius: active ? 2 : 0,
              ),
            ],
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'LUCKY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '11',
                  style: TextStyle(
                    color: Color(0xFFFFF0A3),
                    fontSize: 27,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '3 extra',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (active) ...[
          Positioned(
            left: 8,
            right: 8,
            bottom: -7,
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: phase
                    ? const Color(0xFFFFD54F)
                    : const Color(0xFFFF3FD1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xCCFF3FD1),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -5,
            top: 9,
            bottom: 9,
            child: Container(
              width: 5,
              color: phase
                  ? const Color(0xFF58E7FF)
                  : const Color(0xFFFFD54F),
            ),
          ),
          Positioned(
            right: -5,
            top: 9,
            bottom: 9,
            child: Container(
              width: 5,
              color: phase
                  ? const Color(0xFFFFD54F)
                  : const Color(0xFFFF4FD8),
            ),
          ),
        ],
      ],
    );
  }
}

class _PartyBetButton extends StatelessWidget {
  const _PartyBetButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFFFC13A), Color(0xFFFF6B2D)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF2856DA), Color(0xFF7622C5)],
                  ),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFF098)
                  : const Color(0xFF835AFF),
            ),
          ),
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PartyFooterStat extends StatelessWidget {
  const _PartyFooterStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF161633),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF4B3C77)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFAAA7C8),
              fontSize: 7,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyResultStrip extends StatelessWidget {
  const _PartyResultStrip({required this.history});

  final List<FruitPartyRoundResult> history;

  @override
  Widget build(BuildContext context) {
    final recent = history.take(6).toList();
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF11162C),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF4B3C77)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_rounded,
            size: 12,
            color: Color(0xFFACA6C9),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: recent.isEmpty
                ? const Text(
                    'Results',
                    style: TextStyle(
                      color: Color(0xFF8883A9),
                      fontSize: 8,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final result in recent)
                        Text(
                          result.isLucky11 ? '⑪' : result.fruit.emoji,
                          style: TextStyle(
                            fontSize: result.isLucky11 ? 15 : 13,
                            color: result.isLucky11
                                ? const Color(0xFFFFD54F)
                                : null,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
