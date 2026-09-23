import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../auth/auth_service.dart';
import '../ui/royal_theme.dart';
import 'feature_center_screen.dart';
import 'gifts_screen.dart';
import 'games_screen.dart';
import 'vip_screen.dart';
import 'owner_panel_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = widget.state.profile.profile;
    final identity = widget.state.identity;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mine', style: TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          RoyalPanel(
            gradient: const LinearGradient(colors: [Color(0xFF302007), Color(0xFF090705)]),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: RoyalPalette.deepGold,
                  child: Text(
                    profile.nick.characters.first,
                    style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nick,
                        style: const TextStyle(color: RoyalPalette.cream, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      Text('ID ' + profile.userId + ' • 🇮🇳', style: const TextStyle(color: RoyalPalette.muted)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          _GoldBadge('VIP' + identity.vip.level.toString()),
                          _GoldBadge('Noble ' + identity.noble.level.toString()),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: RoyalPalette.gold),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Coins', value: widget.state.wallet.coins.toString())),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: 'Diamonds', value: widget.state.wallet.diamonds.toString())),
            ],
          ),
          const SizedBox(height: 14),
          const GoldSectionTitle('Royal Center'),
          const SizedBox(height: 10),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 0.95,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            children: [
              _MineTile(
                icon: Icons.workspace_premium_rounded,
                label: 'VIP',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VipScreen(state: widget.state))),
              ),
              _MineTile(
                icon: Icons.card_giftcard_rounded,
                label: 'Gift',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GiftsScreen(state: widget.state))),
              ),
              _MineTile(
                icon: Icons.casino_rounded,
                label: 'Game',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamesScreen(state: widget.state))),
              ),
              _MineTile(
                icon: Icons.groups_rounded,
                label: 'Family',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeatureCenterScreen(state: widget.state),
                  ),
                ).then((_) => setState(() {})),
              ),
              _MineTile(
                icon: Icons.favorite_rounded,
                label: 'CP',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeatureCenterScreen(state: widget.state),
                  ),
                ).then((_) => setState(() {})),
              ),
              _MineTile(
                icon: Icons.grid_view_rounded,
                label: 'More',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FeatureCenterScreen(state: widget.state)),
                ).then((_) => setState(() {})),
              ),
              if (widget.state.ownerPanel.isOwner(widget.state.auth.current?.userId))
                _MineTile(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Owner',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OwnerPanelScreen(state: widget.state)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          RoyalPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: RoyalPalette.gold),
                  title: const Text('Edit profile'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    widget.state.profile.editNick('Tinni Star User');
                    widget.state.profile.editSignature('Welcome to Tinni Star');
                    setState(() {});
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link_rounded, color: RoyalPalette.gold),
                  title: const Text('Bind Google account'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    widget.state.auth.bind(LoginProvider.google);
                    final account = widget.state.auth.current;
                    if (account != null) {
                      await widget.state.authPersistence?.save(account);
                    }
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldBadge extends StatelessWidget {
  const _GoldBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: RoyalPalette.deepGold.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RoyalPalette.gold),
      ),
      child: Text(
        text,
        style: const TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w800, fontSize: 10),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, style: const TextStyle(color: RoyalPalette.muted)),
        ],
      ),
    );
  }
}

class _MineTile extends StatelessWidget {
  const _MineTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: RoyalPalette.gold, size: 31),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
