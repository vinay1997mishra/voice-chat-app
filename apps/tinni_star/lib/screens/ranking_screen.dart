import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../ui/royal_theme.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({
    super.key,
    required this.state,
    this.initialTab = 1,
  });

  final TinniState state;
  final int initialTab;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  static const _tabs = ['Room', 'Send gifts', 'Charm', 'Game'];
  static const _periods = ['Daily', 'Weekly', 'Monthly list'];

  late int _tab;
  int _period = 0;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, _tabs.length - 1);
  }

  List<_RankItem> _items() {
    final rooms = widget.state.discovery.recommend();
    if (_tab == 0) {
      return rooms
          .map(
            (room) => _RankItem(
              id: room.id,
              name: room.title,
              subtitle: room.country == 'IN'
                  ? '🇮🇳 India'
                  : '🌐 ' + room.country,
              score: room.online * (_period + 1) * 100,
              room: room,
            ),
          )
          .toList();
    }

    return rooms
        .asMap()
        .entries
        .map(
          (entry) => _RankItem(
            id: entry.value.ownerId ?? entry.value.id,
            name: 'Tinni User ' + (entry.key + 1).toString(),
            subtitle: _tab == 1
                ? 'Gift contribution'
                : _tab == 2
                    ? 'Charm points'
                    : 'Game points',
            score: (rooms.length - entry.key) * 12500 * (_period + 1),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final accent = <Color>[
      FeaturePalette.social,
      FeaturePalette.gift,
      FeaturePalette.cp,
      FeaturePalette.games,
    ][_tab];
    return Scaffold(
      key: const Key('ranking-screen'),
      appBar: AppBar(
        title: const Text(
          'Ranking Center',
          style: TextStyle(
            color: RoyalPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          _RankTabs(
            labels: _tabs,
            selected: _tab,
            onSelected: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: 8),
          _RankTabs(
            labels: _periods,
            selected: _period,
            compact: true,
            onSelected: (index) => setState(() => _period = index),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              children: [
                if (items.isNotEmpty)
                  _TopRankPodium(
                    items: items.take(3).toList(),
                    accent: accent,
                    onTap: (item) {
                      final room = item.room;
                      if (room == null) return;
                      Navigator.pop(context, room);
                    },
                  ),
                const SizedBox(height: 12),
                for (var i = 3; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RoyalPanel(
                      padding: const EdgeInsets.all(10),
                      onTap: items[i].room == null
                          ? null
                          : () => Navigator.pop(context, items[i].room),
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
                              items[i].name.characters.first.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  items[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: RoyalPalette.cream,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  items[i].subtitle,
                                  style: const TextStyle(
                                    color: RoyalPalette.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.monetization_on_rounded,
                            color: RoyalPalette.gold,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _compact(items[i].score),
                            style: const TextStyle(
                              color: RoyalPalette.gold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                RoyalPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: RoyalPalette.deepGold,
                        child: Text(
                          'M',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'My ranking',
                          style: TextStyle(
                            color: RoyalPalette.cream,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '--',
                        style: TextStyle(
                          color: RoyalPalette.muted,
                          fontWeight: FontWeight.w800,
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

  String _compact(int value) {
    if (value >= 1000000) {
      return (value / 1000000).toStringAsFixed(1) + 'M';
    }
    if (value >= 1000) {
      return (value / 1000).toStringAsFixed(1) + 'K';
    }
    return value.toString();
  }
}

class _RankItem {
  const _RankItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.score,
    this.room,
  });

  final String id;
  final String name;
  final String subtitle;
  final int score;
  final RoomSummary? room;
}

class _RankTabs extends StatelessWidget {
  const _RankTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 42 : 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final label = labels[index].toLowerCase();
          final color = compact
              ? FeaturePalette.rank
              : label.contains('gift')
                  ? FeaturePalette.gift
                  : label.contains('charm')
                      ? FeaturePalette.cp
                      : label.contains('game')
                          ? FeaturePalette.games
                          : FeaturePalette.social;
          return ChoiceChip(
            key: Key(
              'ranking-tab-' +
                  index.toString() +
                  '-' +
                  (compact ? 'period' : 'type'),
            ),
            label: Text(labels[index]),
            selected: selected == index,
            selectedColor: color.withValues(alpha: 0.30),
            side: BorderSide(
              color: selected == index ? color : RoyalPalette.bronze,
            ),
            labelStyle: TextStyle(
              color: selected == index ? color : RoyalPalette.cream,
              fontWeight: FontWeight.w800,
            ),
            onSelected: (_) => onSelected(index),
          );
        },
      ),
    );
  }
}

class _TopRankPodium extends StatelessWidget {
  const _TopRankPodium({
    required this.items,
    required this.accent,
    required this.onTap,
  });

  final List<_RankItem> items;
  final Color accent;
  final ValueChanged<_RankItem> onTap;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      gradient: FeaturePalette.glow(accent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: InkWell(
                onTap: items[i].room == null ? null : () => onTap(items[i]),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: i == 0 ? 0 : 22,
                    bottom: 6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Builder(
                            builder: (context) {
                              final medal = i == 0
                                  ? const Color(0xFFFFD54F)
                                  : i == 1
                                      ? const Color(0xFFC5D0DA)
                                      : const Color(0xFFCD7F32);
                              return Container(
                                width: i == 0 ? 78 : 62,
                                height: i == 0 ? 78 : 62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: medal, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: medal.withValues(alpha: 0.55),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  backgroundColor: RoyalPalette.panel,
                                  child: Text(
                                    items[i].name.characters.first.toUpperCase(),
                                    style: TextStyle(
                                      color: medal,
                                      fontSize: i == 0 ? 27 : 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            top: -13,
                            child: Icon(
                              i == 0
                                  ? Icons.workspace_premium_rounded
                                  : Icons.emoji_events_rounded,
                              color: i == 0
                                  ? const Color(0xFFFFD54F)
                                  : i == 1
                                      ? const Color(0xFFC5D0DA)
                                      : const Color(0xFFCD7F32),
                              size: i == 0 ? 30 : 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        items[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: RoyalPalette.cream,
                          fontWeight: FontWeight.w900,
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
            ),
            if (i != items.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
