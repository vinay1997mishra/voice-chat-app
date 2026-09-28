import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../infra/app_backend_service.dart';
import '../ui/royal_theme.dart';
import 'recharge_screen.dart';

class VipScreen extends StatefulWidget {
  const VipScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> {
  int selectedLevel = 1;
  bool loadingCatalog = true;
  String? catalogError;
  List<VipCatalogItem> catalog = const <VipCatalogItem>[];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final account = widget.state.auth.current;
    if (account == null) {
      if (mounted) setState(() => loadingCatalog = false);
      return;
    }
    try {
      final values = await widget.state.backend.vipCatalog(account.authToken);
      if (!mounted) return;
      setState(() {
        catalog = values;
        loadingCatalog = false;
        catalogError = null;
        if (values.isNotEmpty && !values.any((item) => item.level == selectedLevel)) {
          selectedLevel = values.first.level;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingCatalog = false;
        catalogError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  VipCatalogItem? get selectedItem {
    for (final item in catalog) {
      if (item.level == selectedLevel) return item;
    }
    return null;
  }

  Color _vipColor(int level) {
    const colors = <Color>[
      Color(0xFF4FC3F7),
      Color(0xFF42A5F5),
      Color(0xFF5C6BC0),
      Color(0xFF7E57C2),
      Color(0xFFAB47BC),
      Color(0xFFEC407A),
      Color(0xFFFF7043),
      Color(0xFFFFA726),
      Color(0xFFFFCA28),
      Color(0xFF26C6DA),
      Color(0xFF00C853),
      Color(0xFFE040FB),
    ];
    return colors[(level - 1).clamp(0, colors.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.state.identity.vip.level;
    final progress = (widget.state.identity.vip.experience % 1000) / 1000;
    final fallbackPrivileges = [
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
              itemCount: catalog.isEmpty ? 11 : catalog.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final level = catalog.isEmpty ? index + 1 : catalog[index].level;
                final color = _vipColor(level);
                return ChoiceChip(
                  label: Text('VIP' + level.toString()),
                  selected: selectedLevel == level,
                  selectedColor: color.withValues(alpha: 0.28),
                  side: BorderSide(
                    color: selectedLevel == level
                        ? color
                        : RoyalPalette.bronze,
                  ),
                  labelStyle: TextStyle(
                    color: selectedLevel == level
                        ? color
                        : RoyalPalette.cream,
                    fontWeight: FontWeight.w800,
                  ),
                  onSelected: (_) => setState(() => selectedLevel = level),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (context) {
              final color = _vipColor(selectedLevel);
              return RoyalPanel(
                gradient: FeaturePalette.glow(color),
                accentColor: color,
                child: Column(
                  children: [
                    ShiningIcon(
                      icon: Icons.workspace_premium_rounded,
                      size: 46,
                      boxSize: 72,
                      color: color,
                      glow: 0.48,
                    ),
                    Text(
                      selectedItem?.name ?? ('VIP ' + selectedLevel.toString()),
                      style: TextStyle(
                        color: color,
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
                      color: color,
                      backgroundColor: RoyalPalette.panel,
                    ),
                const SizedBox(height: 6),
                Text(
                  'Current VIP ' + current.toString() + ' • XP ' + widget.state.identity.vip.experience.toString(),
                  style: const TextStyle(color: RoyalPalette.muted),
                ),
                  ],
                ),
              );
            },
          ),
          if (loadingCatalog) const LinearProgressIndicator(),
          if (catalogError != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(catalogError!, style: const TextStyle(color: Colors.redAccent)),
          ),
          if (selectedItem != null && selectedItem!.entry.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Entry: ' + selectedItem!.entry, style: const TextStyle(color: RoyalPalette.muted)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('vip-monthly-topup-button'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RechargeScreen(state: widget.state),
                ),
              ).then((_) {
                if (mounted) setState(() {});
              });
            },
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Monthly top-up to VIP'),
          ),
          const SizedBox(height: 18),
          GoldSectionTitle('Privileges ' + selectedLevel.toString() + '/9'),
          const SizedBox(height: 10),
          Builder(builder: (context) {
            final remotePrivileges = selectedItem?.privileges ?? const <String>[];
            final privileges = remotePrivileges.isEmpty
                ? fallbackPrivileges
                : remotePrivileges.map((name) => (name, Icons.workspace_premium_rounded)).toList();
            return GridView.builder(
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
              final color = _vipColor(selectedLevel);
              return RoyalPanel(
                padding: const EdgeInsets.all(9),
                gradient: unlocked ? FeaturePalette.glow(color) : null,
                accentColor: unlocked ? color : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShiningIcon(
                      icon: unlocked ? item.$2 : Icons.lock_rounded,
                      color: unlocked ? color : RoyalPalette.muted,
                      size: 20,
                      boxSize: 38,
                      glow: unlocked ? 0.32 : 0.06,
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
          );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
