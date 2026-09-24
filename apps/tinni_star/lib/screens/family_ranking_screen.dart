import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';

class FamilyRankingScreen extends StatefulWidget {
  const FamilyRankingScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<FamilyRankingScreen> createState() => _FamilyRankingScreenState();
}

class _FamilyRankingScreenState extends State<FamilyRankingScreen> {
  static const _periods = ['Daily', 'Weekly', 'Monthly'];
  int _period = 1;

  List<_FamilyRankItem> _items() {
    final multiplier = _period + 1;
    final currentFamily = widget.state.family.name ?? 'My Family';

    return [
      _FamilyRankItem(
        id: 'family-royal',
        name: 'Royal Family',
        tag: 'RF',
        score: 98000 * multiplier,
      ),
      _FamilyRankItem(
        id: 'family-star',
        name: 'Star Family',
        tag: 'SF',
        score: 76000 * multiplier,
      ),
      _FamilyRankItem(
        id: 'family-heart',
        name: 'Heart Family',
        tag: 'HF',
        score: 63000 * multiplier,
      ),
      _FamilyRankItem(
        id: 'family-tinni',
        name: currentFamily,
        tag: widget.state.family.tag ?? 'TS',
        score: (widget.state.family.experience + 42000) * multiplier,
        isMine: true,
      ),
      _FamilyRankItem(
        id: 'family-friends',
        name: 'Friends Club',
        tag: 'FC',
        score: 36000 * multiplier,
      ),
    ]..sort((a, b) => b.score.compareTo(a.score));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final mineIndex = items.indexWhere((item) => item.isMine);

    return Scaffold(
      key: const Key('family-ranking-screen'),
      appBar: AppBar(
        title: const Text(
          'Family Ranking',
          style: TextStyle(
            color: RoyalPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _periods.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) => ChoiceChip(
                key: Key('family-ranking-period-' + index.toString()),
                label: Text(_periods[index]),
                selected: _period == index,
                onSelected: (_) => setState(() => _period = index),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                RoyalPanel(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3A2600),
                      Color(0xFF0B0804),
                      Color(0xFF3A2600),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Top Families',
                        style: TextStyle(
                          color: RoyalPalette.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < items.take(3).length; i++) ...[
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: i == 0 ? 0 : 18),
                                child: Column(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.topCenter,
                                      children: [
                                        CircleAvatar(
                                          radius: i == 0 ? 38 : 31,
                                          backgroundColor: RoyalPalette.gold,
                                          child: CircleAvatar(
                                            radius: i == 0 ? 34 : 27,
                                            backgroundColor: RoyalPalette.panel,
                                            child: Text(
                                              items[i].tag,
                                              style: TextStyle(
                                                color: RoyalPalette.gold,
                                                fontWeight: FontWeight.w900,
                                                fontSize: i == 0 ? 20 : 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: -13,
                                          child: Icon(
                                            i == 0
                                                ? Icons.workspace_premium_rounded
                                                : Icons.emoji_events_rounded,
                                            color: RoyalPalette.gold,
                                            size: i == 0 ? 30 : 23,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      items[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: RoyalPalette.cream,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      items[i].score.toString(),
                                      style: const TextStyle(
                                        color: RoyalPalette.gold,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (i < 2) const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 3; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RoyalPanel(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text(
                              (i + 1).toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: RoyalPalette.gold,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          CircleAvatar(
                            radius: 23,
                            backgroundColor: RoyalPalette.deepGold,
                            child: Text(
                              items[i].tag,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              items[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: RoyalPalette.cream,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            items[i].score.toString(),
                            style: const TextStyle(
                              color: RoyalPalette.gold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                RoyalPanel(
                  key: const Key('family-my-ranking'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.groups_rounded,
                        color: RoyalPalette.gold,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'My family ranking',
                          style: TextStyle(
                            color: RoyalPalette.cream,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        mineIndex < 0
                            ? '--'
                            : '#' + (mineIndex + 1).toString(),
                        style: const TextStyle(
                          color: RoyalPalette.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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

class _FamilyRankItem {
  const _FamilyRankItem({
    required this.id,
    required this.name,
    required this.tag,
    required this.score,
    this.isMine = false,
  });

  final String id;
  final String name;
  final String tag;
  final int score;
  final bool isMine;
}
