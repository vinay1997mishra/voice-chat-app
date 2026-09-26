import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../community/family_service.dart';
import '../moderation/user_safety_menu.dart';
import '../ui/royal_theme.dart';
import 'family_home_screen.dart';
import 'family_ranking_screen.dart';
import 'feature_center_screen.dart';
import 'gifts_screen.dart';
import 'vip_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final account = widget.state.auth.current;
    final identity = widget.state.identity;

    if (account == null) {
      return const Scaffold(
        body: Center(child: Text('Login required')),
      );
    }

    ImageProvider? avatar;
    final dataUrl = account.avatarDataUrl;
    if (dataUrl != null && dataUrl.startsWith('data:image/')) {
      try {
        avatar = MemoryImage(base64Decode(dataUrl.split(',').last));
      } catch (_) {
        avatar = null;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mine',
          style: TextStyle(
            color: RoyalPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          UserSafetyMenuButton(
            state: widget.state,
            targetUserId: account.userId,
            targetDisplayName: account.displayName,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          RoyalPanel(
            gradient: const LinearGradient(
              colors: [Color(0xFF302007), Color(0xFF090705)],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: RoyalPalette.deepGold,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? Text(
                          account.displayName.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName,
                        style: const TextStyle(
                          color: RoyalPalette.cream,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'ID ' +
                            account.userId +
                            ' • ' +
                            account.flagEmoji +
                            ' ' +
                            account.countryName,
                        style: const TextStyle(color: RoyalPalette.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account.age.toString() +
                            ' • ' +
                            (account.gender == 'male' ? 'Male' : 'Female'),
                        style: const TextStyle(
                          color: RoyalPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                      if (account.signature.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          account.signature,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (widget.state.family.exists) ...[
                        const SizedBox(height: 5),
                        _FamilyTagBadge(state: widget.state),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          _GoldBadge(
                            'VIP' + identity.vip.level.toString(),
                          ),
                          _GoldBadge(
                            'Noble ' + identity.noble.level.toString(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Coins',
                  value: widget.state.wallet.coins.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Diamonds',
                  value: widget.state.wallet.diamonds.toString(),
                ),
              ),
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
                color: FeaturePalette.vip,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VipScreen(state: widget.state),
                  ),
                ),
              ),
              _MineTile(
                icon: Icons.card_giftcard_rounded,
                label: 'Gift',
                color: FeaturePalette.gift,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GiftsScreen(state: widget.state),
                  ),
                ),
              ),
              _MineTile(
                icon: Icons.groups_rounded,
                label: 'Family',
                color: FeaturePalette.family,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => widget.state.family.exists
                        ? FamilyHomeScreen(state: widget.state)
                        : FamilyRankingScreen(state: widget.state),
                  ),
                ).then((_) => setState(() {})),
              ),
              _MineTile(
                icon: Icons.favorite_rounded,
                label: 'CP',
                color: FeaturePalette.cp,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeatureCenterScreen(state: widget.state),
                  ),
                ),
              ),
              _MineTile(
                icon: Icons.grid_view_rounded,
                label: 'More',
                color: FeaturePalette.social,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeatureCenterScreen(state: widget.state),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FamilyTagBadge extends StatelessWidget {
  const _FamilyTagBadge({required this.state});

  final TinniState state;

  Color get _color {
    switch (state.family.visualTier) {
      case FamilyVisualTier.emerald:
        return const Color(0xFF0E8A62);
      case FamilyVisualTier.sapphire:
        return const Color(0xFF155FA8);
      case FamilyVisualTier.amethyst:
        return const Color(0xFF833FB0);
      case FamilyVisualTier.royalGold:
        return const Color(0xFFD49B14);
      case FamilyVisualTier.bronze:
        return const Color(0xFF7A5515);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('profile-family-tag'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withValues(alpha: 0.68), _color],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RoyalPalette.gold),
      ),
      child: Text(
        (state.family.tag ?? 'Family') + ' • ' + state.family.levelLabel,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 9,
        ),
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
        style: const TextStyle(
          color: RoyalPalette.gold,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
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
          Text(
            value,
            style: const TextStyle(
              color: RoyalPalette.gold,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: RoyalPalette.muted),
          ),
        ],
      ),
    );
  }
}

class _MineTile extends StatelessWidget {
  const _MineTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      padding: const EdgeInsets.all(8),
      gradient: FeaturePalette.glow(color),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(
                color: color.withValues(alpha: 0.75),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.32),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 29),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
