import 'dart:async';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../games/fruit_jackpot_game.dart';
import '../ui/royal_theme.dart';

class FruitJackpotScreen extends StatefulWidget {
  const FruitJackpotScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<FruitJackpotScreen> createState() => _FruitJackpotScreenState();
}

class _FruitJackpotScreenState extends State<FruitJackpotScreen> {
  static const _betAmounts = <int>[500, 1000, 10000, 100000];

  Timer? _ticker;
  int _selectedBet = 1000;

  FruitJackpotGameService get game => widget.state.fruitJackpot;
  String get userId => widget.state.auth.current?.userId ?? '10000000';

  @override
  void initState() {
    super.initState();
    game.sync();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      game.sync();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _compact(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toString();
  }

  String _countdown() {
    final remaining = game.remaining();
    final seconds = remaining.inMilliseconds / 1000;
    return seconds <= 0 ? '0.0' : seconds.toStringAsFixed(1);
  }

  void _placeBet(FruitKind fruit) {
    final placed = game.placeBet(
      userId: userId,
      fruit: fruit,
      amount: _selectedBet,
    );

    if (!placed) {
      final message = !game.bettingOpen
          ? 'Betting locked for this round.'
          : 'Not enough coins for this bet.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    setState(() {});
  }

  void _showRules() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fruit Jackpot Rules'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rounds run continuously on their own timer. Place a bet before the lock period. The winning fruit pays the shown multiplier.',
              ),
              const SizedBox(height: 14),
              for (final fruit in FruitKind.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(fruit.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(fruit.label)),
                      Text(
                        '${fruit.multiplier}×',
                        style: const TextStyle(
                          color: RoyalPalette.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              const Text(
                'The production version must use the server as the round, result and wallet authority.',
                style: TextStyle(fontSize: 12, color: RoyalPalette.muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latest = game.history.isEmpty ? null : game.history.first;
    final bettingOpen = game.bettingOpen;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fruit Jackpot'),
        actions: [
          IconButton(
            key: const Key('fruit-jackpot-rules'),
            tooltip: 'Rules',
            onPressed: _showRules,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        children: [
          RoyalPanel(
            key: const Key('fruit-jackpot-header'),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF190900),
                Color(0xFF4B2100),
                Color(0xFF160D03),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'JACKPOT',
                  style: TextStyle(
                    color: RoyalPalette.gold,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _compact(game.jackpot),
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _RoundStat(
                        label: 'Round',
                        value: '#${game.currentRoundId}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RoundStat(
                        label: bettingOpen ? 'Betting' : 'Locked',
                        value: _countdown(),
                        emphasized: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RoundStat(
                        label: 'Coins',
                        value: _compact(widget.state.wallet.coins),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (latest != null)
            RoyalPanel(
              key: const Key('fruit-jackpot-latest-result'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: RoyalPalette.deepGold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(latest.fruit.emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${latest.fruit.label}  ×${latest.fruit.multiplier}',
                      style: const TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '#${latest.roundId}',
                    style: const TextStyle(
                      color: RoyalPalette.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          if (latest != null) const SizedBox(height: 14),
          const GoldSectionTitle('Choose Fruit'),
          const SizedBox(height: 10),
          GridView.builder(
            key: const Key('fruit-jackpot-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: FruitKind.values.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.48,
            ),
            itemBuilder: (context, index) {
              final fruit = FruitKind.values[index];
              final mine = game.userBetForFruit(userId, fruit);
              final isLastWinner = latest?.fruit == fruit;
              return RoyalPanel(
                key: Key('fruit-bet-${fruit.name}'),
                onTap: bettingOpen ? () => _placeBet(fruit) : null,
                gradient: LinearGradient(
                  colors: isLastWinner
                      ? const [Color(0xFF4B3500), Color(0xFF1A1200)]
                      : const [RoyalPalette.panel2, RoyalPalette.panel],
                ),
                child: Row(
                  children: [
                    Text(fruit.emoji, style: const TextStyle(fontSize: 38)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fruit.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RoyalPalette.cream,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${fruit.multiplier}× WIN',
                            style: const TextStyle(
                              color: RoyalPalette.gold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (mine > 0)
                            Text(
                              'Mine: ${_compact(mine)}',
                              style: const TextStyle(
                                color: RoyalPalette.muted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          GoldSectionTitle(
            'Bet Amount',
            trailing: Text(
              'Mine ${_compact(game.userTotalBet(userId))}',
              style: const TextStyle(
                color: RoyalPalette.muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            key: const Key('fruit-jackpot-bet-amounts'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in _betAmounts)
                ChoiceChip(
                  label: Text(_compact(amount)),
                  selected: _selectedBet == amount,
                  onSelected: (_) => setState(() => _selectedBet = amount),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniInfo(
                  label: 'Total Bet',
                  value: _compact(game.totalBetForRound()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniInfo(
                  label: 'Today Win',
                  value: _compact(game.todayWinnings),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const GoldSectionTitle('Recent Results'),
          const SizedBox(height: 8),
          SizedBox(
            key: const Key('fruit-jackpot-results'),
            height: 82,
            child: game.history.isEmpty
                ? const Center(
                    child: Text(
                      'First result will appear after this round.',
                      style: TextStyle(color: RoyalPalette.muted),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: game.history.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final result = game.history[index];
                      return Container(
                        width: 72,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: RoyalPalette.panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: index == 0
                                ? RoyalPalette.gold
                                : RoyalPalette.bronze,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (index == 0)
                              const Text(
                                'NEW',
                                style: TextStyle(
                                  color: RoyalPalette.gold,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            Text(
                              result.fruit.emoji,
                              style: const TextStyle(fontSize: 25),
                            ),
                            Text(
                              '${result.fruit.multiplier}×',
                              style: const TextStyle(
                                color: RoyalPalette.cream,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            bettingOpen
                ? 'Tap any fruit to place the selected bet. The round continues even if nobody bets.'
                : 'Result phase — next round starts automatically.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RoyalPalette.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundStat extends StatelessWidget {
  const _RoundStat({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasized ? RoyalPalette.gold : RoyalPalette.bronze,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: RoyalPalette.muted, fontSize: 10),
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                color: emphasized ? RoyalPalette.gold : RoyalPalette.cream,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: RoyalPalette.muted, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
