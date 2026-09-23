import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';

class VipScreen extends StatefulWidget {
  const VipScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> {
  int selectedLevel = 1;

  @override
  Widget build(BuildContext context) {
    final current = widget.state.identity.vip.level;
    final progress = (widget.state.identity.vip.experience % 1000) / 1000;
    final privileges = [
      ('Mysterious invisibility', Icons.visibility_off_rounded),
      ('Refuse contact', Icons.shield_rounded),
      ('Room priority display', Icons.upgrade_rounded),
      ('Privileged gifts', Icons.card_giftcard_rounded),
      ('Microphone emoji', Icons.mic_rounded),
      ('VIP birthday gift', Icons.cake_rounded),
      ('Golden entry', Icons.auto_awesome_rounded),
      ('VIP nameplate', Icons.badge_rounded),
      ('Room halo', Icons.light_mode_rounded),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Privileges VIP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 12,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final level = index + 1;
                return ChoiceChip(
                  label: Text('VIP' + level.toString()),
                  selected: selectedLevel == level,
                  onSelected: (_) => setState(() => selectedLevel = level),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          RoyalPanel(
            gradient: const LinearGradient(
              colors: [Color(0xFF2B1A05), Color(0xFF0B0905), Color(0xFF34220A)],
            ),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 64, color: RoyalPalette.gold),
                Text(
                  'VIP ' + selectedLevel.toString(),
                  style: const TextStyle(
                    color: RoyalPalette.gold,
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'ROYAL PRIVILEGES',
                  style: TextStyle(color: RoyalPalette.muted, letterSpacing: 2.1),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: selectedLevel == current ? progress : 0,
                  color: RoyalPalette.gold,
                  backgroundColor: RoyalPalette.panel,
                ),
                const SizedBox(height: 6),
                Text(
                  'Current VIP ' + current.toString() + ' • XP ' + widget.state.identity.vip.experience.toString(),
                  style: const TextStyle(color: RoyalPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GoldSectionTitle('Privileges ' + selectedLevel.toString() + '/9'),
          const SizedBox(height: 10),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: privileges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.88,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (_, index) {
              final item = privileges[index];
              final unlocked = selectedLevel >= (index ~/ 2) + 1;
              return RoyalPanel(
                padding: const EdgeInsets.all(9),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      unlocked ? item.$2 : Icons.lock_rounded,
                      color: unlocked ? RoyalPalette.gold : RoyalPalette.muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.$1,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              widget.state.identity.gainVipExperience(1000);
              setState(() {});
            },
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Monthly top-up to VIP'),
          ),
        ],
      ),
    );
  }
}
