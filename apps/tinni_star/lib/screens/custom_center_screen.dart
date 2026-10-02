import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';
import 'store_screen.dart';
import 'unique_id_store_screen.dart';

class CustomCenterScreen extends StatefulWidget {
  const CustomCenterScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<CustomCenterScreen> createState() => _CustomCenterScreenState();
}

class _CustomCenterScreenState extends State<CustomCenterScreen> {
  bool loading = true;
  String? error;

  static const _items = <(String, String, IconData)>[
    ('Profile', 'profile_card', Icons.badge_rounded),
    ('Frame', 'frame', Icons.account_box_rounded),
    ('Car', 'vehicle', Icons.directions_car_filled_rounded),
    ('Entrance', 'entry', Icons.auto_awesome_rounded),
    ('Ring', 'ring', Icons.circle_outlined),
    ('Profile Background', 'profile_background', Icons.wallpaper_rounded),
    ('Bubble', 'bubble', Icons.chat_bubble_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final inventory =
          await widget.state.backend.inventory(account.authToken);
      widget.state.inventory.applyRemote(inventory);
      if (!mounted) return;
      setState(() {
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _openKind(String kind) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreScreen(
          state: widget.state,
          initialKind: kind,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('custom-center-screen'),
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        title: const Text(
          'Custom Center',
          style: TextStyle(
            color: FeaturePalette.store,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            RoyalPanel(
              gradient: FeaturePalette.glow(FeaturePalette.store),
              accentColor: FeaturePalette.store,
              child: Column(
                children: [
                  const ShiningIcon(
                    icon: Icons.auto_awesome_rounded,
                    color: FeaturePalette.store,
                    size: 34,
                    boxSize: 62,
                    glow: 0.44,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'My Style',
                    style: TextStyle(
                      color: RoyalPalette.cream,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.state.inventory.owned.length.toString() +
                        ' owned props',
                    style: const TextStyle(color: RoyalPalette.muted),
                  ),
                ],
              ),
            ),
            if (loading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 14),
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  key: Key('custom-center-' + item.$2),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openKind(item.$2),
                  child: RoyalPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        ShiningIcon(
                          icon: item.$3,
                          color: FeaturePalette.store,
                          size: 20,
                          boxSize: 38,
                          glow: 0.28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.$1,
                            style: const TextStyle(
                              color: RoyalPalette.cream,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          widget.state.inventory.equipped(item.$2) == null
                              ? 'Not using'
                              : 'Using',
                          style: TextStyle(
                            color:
                                widget.state.inventory.equipped(item.$2) == null
                                    ? RoyalPalette.muted
                                    : FeaturePalette.wallet,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: RoyalPalette.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            InkWell(
              key: const Key('custom-center-unique-id'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UniqueIdStoreScreen(state: widget.state),
                ),
              ),
              child: const RoyalPanel(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    ShiningIcon(
                      icon: Icons.numbers_rounded,
                      color: FeaturePalette.vip,
                      size: 20,
                      boxSize: 38,
                      glow: 0.28,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lucky / Unique ID',
                        style: TextStyle(
                          color: RoyalPalette.cream,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: RoyalPalette.muted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
