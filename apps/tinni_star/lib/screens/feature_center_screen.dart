import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';
import 'cp_disconnect_screen.dart';
import 'cp_screen.dart';
import 'family_home_screen.dart';
import 'family_ranking_screen.dart';
import 'recharge_screen.dart';
import 'sharing_screen.dart';
import 'store_screen.dart';
import 'vip_screen.dart';

class FeatureCenterScreen extends StatefulWidget {
  const FeatureCenterScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<FeatureCenterScreen> createState() => _FeatureCenterScreenState();
}

class _FeatureCenterScreenState extends State<FeatureCenterScreen> {
  void showText(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    setState(() {});
  }

  Color _featureColor(String title) {
    final value = title.toLowerCase();
    if (value.contains('cp')) return FeaturePalette.cp;
    if (value.contains('vip') || value.contains('noble')) {
      return FeaturePalette.vip;
    }
    if (value.contains('gift')) return FeaturePalette.gift;
    if (value.contains('family')) return FeaturePalette.family;
    if (value.contains('wallet') || value.contains('recharge')) {
      return FeaturePalette.wallet;
    }
    if (value.contains('store') || value.contains('inventory')) {
      return FeaturePalette.store;
    }
    if (value.contains('backpack') || value.contains('atlas')) {
      return FeaturePalette.backpack;
    }
    if (value.contains('dynamic') || value.contains('moment')) {
      return FeaturePalette.moments;
    }
    return FeaturePalette.social;
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final modules = <_FeatureAction>[
      _FeatureAction(
        'Wallet / Recharge',
        Icons.account_balance_wallet_rounded,
        () => _open(RechargeScreen(state: state)),
      ),
      _FeatureAction(
        'Store / Inventory',
        Icons.storefront_rounded,
        () => _open(StoreScreen(state: state)),
      ),
      _FeatureAction(
        'VIP / Noble',
        Icons.workspace_premium_rounded,
        () => _open(VipScreen(state: state)),
      ),
      _FeatureAction(
        'CP / Courting',
        Icons.favorite_rounded,
        () => _open(CpScreen(state: state)),
      ),
      _FeatureAction(
        'CP Disconnect Flow',
        Icons.heart_broken_rounded,
        () => _open(CpDisconnectScreen(state: state)),
      ),
      _FeatureAction(
        'Family',
        Icons.groups_rounded,
        () => _open(
          state.family.exists
              ? FamilyHomeScreen(state: state)
              : FamilyRankingScreen(state: state),
        ),
      ),
      _FeatureAction(
        'Gift Backpack / Atlas',
        Icons.backpack_rounded,
        () {
          final quantity = state.backpack.items['rose']?.quantity ?? 0;
          showText(
            quantity > 0
                ? 'Rose backpack: ' + quantity.toString()
                : 'Your gift backpack is empty.',
          );
        },
      ),
      _FeatureAction(
        'Dynamic / Moments',
        Icons.auto_awesome_motion_rounded,
        () {
          showText('Moments feed is available from the social home flow.');
        },
      ),
      _FeatureAction(
        'Birthday / Party',
        Icons.cake_rounded,
        () {
          showText('Birthday and party events are opened from active events.');
        },
      ),
      _FeatureAction(
        'Sharing',
        Icons.share_rounded,
        () => _open(SharingScreen(state: state)),
      ),
    ];

    return Scaffold(
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        title: const Text(
          'Feature Center',
          style: TextStyle(
            color: FeaturePalette.discover,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: modules.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.12,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (_, index) {
          final item = modules[index];
          final color = _featureColor(item.title);
          return Container(
            decoration: BoxDecoration(
              gradient: FeaturePalette.glow(color),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: 0.72),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 14,
                ),
              ],
            ),
            child: InkWell(
              key: Key(
                'feature-' +
                    item.title.toLowerCase().replaceAll(' ', '-').replaceAll('/', '-'),
              ),
              borderRadius: BorderRadius.circular(18),
              onTap: item.action,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShiningIcon(
                      icon: item.icon,
                      color: color,
                      size: 30,
                      boxSize: 50,
                      glow: 0.36,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeatureAction {
  const _FeatureAction(this.title, this.icon, this.action);
  final String title;
  final IconData icon;
  final VoidCallback action;
}
