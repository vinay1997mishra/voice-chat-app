import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';
import 'feature_center_screen.dart';

class CpRankingScreen extends StatefulWidget {
  const CpRankingScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<CpRankingScreen> createState() => _CpRankingScreenState();
}

class _CpRankingScreenState extends State<CpRankingScreen> {
  int _mainTab = 0;
  int _subTab = 0;

  static const _couples = [
    ('Aarav', 'Meera', 288000),
    ('Kabir', 'Riya', 196000),
    ('Arjun', 'Siya', 158000),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('cp-ranking-screen'),
      appBar: AppBar(
        title: const Text(
          'CP Ranking',
          style: TextStyle(
            color: RoyalPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          _tabs(
            const ['Ranking List', 'True Love Challenge', 'Reward'],
            _mainTab,
            (value) => setState(() => _mainTab = value),
            'cp-main',
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _mainTab == 0
                  ? _rankingList()
                  : _mainTab == 1
                      ? _challenge()
                      : _reward(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingList() {
    return ListView(
      key: const Key('cp-ranking-list'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        _tabs(
          const ['CP Ranking', 'CP Square'],
          _subTab,
          (value) => setState(() => _subTab = value),
          'cp-sub',
        ),
        const SizedBox(height: 12),
        RoyalPanel(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF4E1430),
              Color(0xFF1A0B18),
              Color(0xFF3A1857),
            ],
          ),
          accentColor: FeaturePalette.cp,
          child: Column(
            children: [
              const Text(
                'Top three last week',
                style: TextStyle(
                  color: RoyalPalette.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _couples.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _CoupleRankRow(
                    rank: i + 1,
                    userA: _couples[i].$1,
                    userB: _couples[i].$2,
                    score: _couples[i].$3,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RoyalPanel(
          accentColor: FeaturePalette.cp,
          gradient: FeaturePalette.glow(FeaturePalette.cp),
          child: Column(
            children: [
              const Text(
                'Not on the list',
                style: TextStyle(
                  color: RoyalPalette.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: RoyalPalette.deepGold,
                    child: Text(
                      'M',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Icon(
                        Icons.favorite_rounded,
                        color: FeaturePalette.cp,
                        size: 44,
                      ),
                    ),
                  ),
                  InkWell(
                    key: const Key('cp-bind-button'),
                    borderRadius: BorderRadius.circular(40),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FeatureCenterScreen(
                            state: widget.state,
                          ),
                        ),
                      );
                    },
                    child: const CircleAvatar(
                      radius: 30,
                      backgroundColor: RoyalPalette.panel2,
                      child: Icon(
                        Icons.add_rounded,
                        color: RoyalPalette.gold,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Bind with CP',
                style: TextStyle(
                  color: RoyalPalette.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _challenge() {
    return ListView(
      key: const Key('cp-true-love'),
      padding: const EdgeInsets.all(14),
      children: const [
        RoyalPanel(
          accentColor: FeaturePalette.cp,
          gradient: FeaturePalette.glow(FeaturePalette.cp),
          child: Column(
            children: [
              ShiningIcon(
                icon: Icons.favorite_border_rounded,
                color: FeaturePalette.cp,
                size: 40,
                boxSize: 64,
                glow: 0.48,
              ),
              SizedBox(height: 10),
              Text(
                'True Love Challenge',
                style: TextStyle(
                  color: RoyalPalette.cream,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Complete CP activities and build intimacy together.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RoyalPalette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reward() {
    return ListView(
      key: const Key('cp-reward'),
      padding: const EdgeInsets.all(14),
      children: const [
        RoyalPanel(
          accentColor: FeaturePalette.gift,
          gradient: FeaturePalette.glow(FeaturePalette.gift),
          child: Column(
            children: [
              ShiningIcon(
                icon: Icons.card_giftcard_rounded,
                color: FeaturePalette.gift,
                size: 40,
                boxSize: 64,
                glow: 0.48,
              ),
              SizedBox(height: 10),
              Text(
                'CP Rewards',
                style: TextStyle(
                  color: RoyalPalette.cream,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Ranking rewards and event rewards appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RoyalPalette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabs(
    List<String> labels,
    int selected,
    ValueChanged<int> onSelected,
    String prefix,
  ) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final label = labels[index].toLowerCase();
          final color = label.contains('reward')
              ? FeaturePalette.gift
              : label.contains('love') || label.contains('cp')
                  ? FeaturePalette.cp
                  : FeaturePalette.social;
          return ChoiceChip(
            key: Key(prefix + '-' + index.toString()),
            label: Text(labels[index]),
            selected: selected == index,
            selectedColor: color.withValues(alpha: 0.28),
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

class _CoupleRankRow extends StatelessWidget {
  const _CoupleRankRow({
    required this.rank,
    required this.userA,
    required this.userB,
    required this.score,
  });

  final int rank;
  final String userA;
  final String userB;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: FeaturePalette.glow(FeaturePalette.cp),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FeaturePalette.cp.withValues(alpha: 0.70),
        ),
        boxShadow: [
          BoxShadow(
            color: FeaturePalette.cp.withValues(alpha: 0.20),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: RoyalPalette.gold,
            child: Text(
              rank.toString(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 23,
            backgroundColor: RoyalPalette.panel2,
            child: Text(userA.characters.first),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: ShiningIcon(
              icon: Icons.favorite_rounded,
              color: FeaturePalette.cp,
              size: 15,
              boxSize: 28,
              glow: 0.30,
            ),
          ),
          CircleAvatar(
            radius: 23,
            backgroundColor: RoyalPalette.panel2,
            child: Text(userB.characters.first),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              userA + ' × ' + userB,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RoyalPalette.cream,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            score.toString(),
            style: const TextStyle(
              color: FeaturePalette.cpSoft,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
