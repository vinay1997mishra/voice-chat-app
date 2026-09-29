import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../community/family_service.dart';
import '../identity/owner_tag.dart';
import '../infra/app_backend_service.dart';
import '../moderation/user_safety_menu.dart';
import '../ui/royal_theme.dart';
import '../ui/animated_avatar_frame.dart';
import 'family_home_screen.dart';
import 'family_ranking_screen.dart';
import 'feature_center_screen.dart';
import 'vip_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<OwnerTag> _ownerTags = <OwnerTag>[];
  final List<OwnerTag> _ownerMedals = <OwnerTag>[];

  @override
  void initState() {
    super.initState();
    _loadOwnerTags();
    _loadEconomyState();
  }

  Future<void> _loadEconomyState() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final wallet = await widget.state.backend.wallet(account.authToken);
      final vip = await widget.state.backend.vipMe(account.authToken);
      widget.state.wallet.applyRemote(wallet);
      widget.state.identity.setVipLevel(
        vip == null ? 0 : int.tryParse(vip['vip_level']?.toString() ?? '') ?? 0,
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _showSettlementTransfer() async {
    final account = widget.state.auth.current;
    if (account == null) return;

    final recipientController = TextEditingController();
    final amountController = TextEditingController(
      text: widget.state.wallet.withdrawableUsdCents >= 200 ? '2.00' : '',
    );
    SettlementRecipient? recipient;
    String? errorText;
    bool searching = false;
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> searchRecipient() async {
            final id = recipientController.text.trim();
            if (id.isEmpty) return;
            setDialogState(() {
              searching = true;
              errorText = null;
              recipient = null;
            });
            try {
              final value = await widget.state.backend.settlementRecipient(
                account.authToken,
                id,
              );
              if (!dialogContext.mounted) return;
              setDialogState(() => recipient = value);
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                errorText =
                    error.toString().replaceFirst('Bad state: ', '');
              });
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => searching = false);
              }
            }
          }

          Future<void> sendTransfer() async {
            final selected = recipient;
            if (selected == null) {
              setDialogState(() => errorText = 'Search and select a recipient first.');
              return;
            }
            final amount = double.tryParse(amountController.text.trim()) ?? 0;
            final cents = (amount * 100).round();
            if (cents < 200) {
              setDialogState(() => errorText = 'Minimum transfer is $2.00.');
              return;
            }
            setDialogState(() {
              sending = true;
              errorText = null;
            });
            try {
              final remote = await widget.state.backend.transferSettlement(
                account.authToken,
                recipientUserId: selected.userId,
                usdCents: cents,
              );
              widget.state.wallet.applyRemote(remote);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Transferred 
    final account = widget.state.auth.current;
    if (account == null) return;

    final client = HttpClient();
    try {
      final uri = widget.state.roomPresence.apiBase.replace(
        path: '/app-user/tags',
        queryParameters: <String, String>{'user_id': account.userId},
      );
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ' + account.authToken,
      );
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = body.trim().isEmpty ? null : jsonDecode(body);
      if (decoded is! Map) return;
      final rawTags = decoded['tags'];
      final tags = rawTags is List
          ? rawTags
              .whereType<Map>()
              .map(OwnerTag.fromMap)
              .where((tag) => tag.name.isNotEmpty)
              .toList(growable: false)
          : const <OwnerTag>[];
      final rawMedals = decoded['medals'];
      final medals = rawMedals is List
          ? rawMedals
              .whereType<Map>()
              .map(OwnerTag.fromMap)
              .where((medal) => medal.name.isNotEmpty)
              .toList(growable: false)
          : const <OwnerTag>[];
      if (!mounted) return;
      setState(() {
        _ownerTags
          ..clear()
          ..addAll(tags);
        _ownerMedals
          ..clear()
          ..addAll(medals);
      });
    } catch (_) {
      // Profile remains usable even if tag refresh fails.
    } finally {
      client.close(force: true);
    }
  }

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
            color: FeaturePalette.social,
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
            gradient: FeaturePalette.glow(FeaturePalette.social),
            accentColor: FeaturePalette.social,
            child: Row(
              children: [
                AnimatedAvatarFrame(
                  size: 92,
                  frameId: widget.state.inventory.equippedFrameId,
                  child: CircleAvatar(
                    backgroundColor: RoyalPalette.panel2,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? Text(
                            account.displayName.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: FeaturePalette.social,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
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
                      if (_ownerTags.isNotEmpty || _ownerMedals.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            for (final tag in _ownerTags)
                              _OwnerTagBadge(tag: tag),
                            for (final medal in _ownerMedals)
                              _OwnerTagBadge(
                                tag: medal,
                                medal: true,
                              ),
                          ],
                        ),
                      ],
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
                            color: FeaturePalette.vip,
                          ),
                          _GoldBadge(
                            'Noble ' + identity.noble.level.toString(),
                            color: FeaturePalette.rank,
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
                  color: FeaturePalette.wallet,
                ),
              ),
              if (widget.state.wallet.diamondWalletVisible) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Diamonds',
                    value: widget.state.wallet.diamonds.toString() +
                        '\n' +
                        widget.state.wallet.diamondUsdText,
                    color: FeaturePalette.diamond,
                  ),
                ),
              ],
            ],
          ),
          if (widget.state.wallet.isHost ||
              widget.state.wallet.isAgency ||
              widget.state.wallet.isBd) ...[
            const SizedBox(height: 10),
            RoyalPanel(
              gradient: FeaturePalette.glow(FeaturePalette.diamond),
              accentColor: FeaturePalette.diamond,
              child: Row(
                children: [
                  const ShiningIcon(
                    icon: Icons.currency_exchange_rounded,
                    color: FeaturePalette.diamond,
                    size: 24,
                    boxSize: 46,
                    glow: 0.36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Withdrawable ' +
                          widget.state.wallet.withdrawableUsdText +
                          (widget.state.wallet.diamondWalletVisible
                              ? '\n4M Diamonds = $1.70'
                              : '\nCommission settlement'),
                      style: const TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton(
                    key: const Key('wallet-settlement-transfer'),
                    onPressed: widget.state.wallet.canTransferSettlement
                        ? _showSettlementTransfer
                        : null,
                    child: const Text('Transfer'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          // CP is intentionally kept out of Mine. Open CP from its dedicated panel.
                    const GoldSectionTitle('Royal Center'),
          const SizedBox(height: 10),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            childAspectRatio: 1.15,
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

class _OwnerTagBadge extends StatelessWidget {
  const _OwnerTagBadge({
    required this.tag,
    this.medal = false,
  });

  final OwnerTag tag;
  final bool medal;

  Color get _color {
    final value = int.tryParse(tag.colorHex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0xFFD54F));
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      key: Key(
        (medal ? 'profile-owner-medal-' : 'profile-owner-tag-') + tag.name,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (medal) ...[
            Icon(
              Icons.workspace_premium_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            tag.name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
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
        border: Border.all(color: _color.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.35),
            blurRadius: 10,
          ),
        ],
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
  const _GoldBadge(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      gradient: FeaturePalette.glow(color),
      accentColor: color,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
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
      accentColor: color,
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
            child: ShiningIcon(
              icon: icon,
              color: color,
              size: 24,
              boxSize: 42,
              glow: 0.34,
            ),
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
 +
                          (cents / 100).toStringAsFixed(2) +
                          ' to ID ' +
                          selected.userId,
                    ),
                  ),
                );
              }
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                errorText =
                    error.toString().replaceFirst('Bad state: ', '');
                sending = false;
              });
            }
          }

          return AlertDialog(
            title: const Text('Transfer settlement'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Available: ' + widget.state.wallet.withdrawableUsdText,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: recipientController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Coin Seller / Merchant User ID',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: searching ? null : searchRecipient,
                    child: Text(searching ? 'Searching…' : 'Search ID'),
                  ),
                  if (recipient != null) ...[
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_rounded),
                      title: Text(recipient!.displayName),
                      subtitle: Text(
                        'ID ' +
                            recipient!.userId +
                            ' • ' +
                            recipient!.role.replaceAll('_', ' '),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'USD amount (minimum $2)',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: sending ? null : sendTransfer,
                child: Text(sending ? 'Sending…' : 'Confirm transfer'),
              ),
            ],
          );
        },
      ),
    );
    recipientController.dispose();
    amountController.dispose();
  }

  Future<void> _loadOwnerTags() async {
    final account = widget.state.auth.current;
    if (account == null) return;

    final client = HttpClient();
    try {
      final uri = widget.state.roomPresence.apiBase.replace(
        path: '/app-user/tags',
        queryParameters: <String, String>{'user_id': account.userId},
      );
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ' + account.authToken,
      );
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = body.trim().isEmpty ? null : jsonDecode(body);
      if (decoded is! Map) return;
      final rawTags = decoded['tags'];
      final tags = rawTags is List
          ? rawTags
              .whereType<Map>()
              .map(OwnerTag.fromMap)
              .where((tag) => tag.name.isNotEmpty)
              .toList(growable: false)
          : const <OwnerTag>[];
      final rawMedals = decoded['medals'];
      final medals = rawMedals is List
          ? rawMedals
              .whereType<Map>()
              .map(OwnerTag.fromMap)
              .where((medal) => medal.name.isNotEmpty)
              .toList(growable: false)
          : const <OwnerTag>[];
      if (!mounted) return;
      setState(() {
        _ownerTags
          ..clear()
          ..addAll(tags);
        _ownerMedals
          ..clear()
          ..addAll(medals);
      });
    } catch (_) {
      // Profile remains usable even if tag refresh fails.
    } finally {
      client.close(force: true);
    }
  }

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
            color: FeaturePalette.social,
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
            gradient: FeaturePalette.glow(FeaturePalette.social),
            accentColor: FeaturePalette.social,
            child: Row(
              children: [
                AnimatedAvatarFrame(
                  size: 92,
                  frameId: widget.state.inventory.equippedFrameId,
                  child: CircleAvatar(
                    backgroundColor: RoyalPalette.panel2,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? Text(
                            account.displayName.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: FeaturePalette.social,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
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
                      if (_ownerTags.isNotEmpty || _ownerMedals.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            for (final tag in _ownerTags)
                              _OwnerTagBadge(tag: tag),
                            for (final medal in _ownerMedals)
                              _OwnerTagBadge(
                                tag: medal,
                                medal: true,
                              ),
                          ],
                        ),
                      ],
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
                            color: FeaturePalette.vip,
                          ),
                          _GoldBadge(
                            'Noble ' + identity.noble.level.toString(),
                            color: FeaturePalette.rank,
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
                  color: FeaturePalette.wallet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Diamonds',
                  value: widget.state.wallet.diamonds.toString(),
                  color: FeaturePalette.diamond,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // CP is intentionally kept out of Mine. Open CP from its dedicated panel.
                    const GoldSectionTitle('Royal Center'),
          const SizedBox(height: 10),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            childAspectRatio: 1.15,
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

class _OwnerTagBadge extends StatelessWidget {
  const _OwnerTagBadge({
    required this.tag,
    this.medal = false,
  });

  final OwnerTag tag;
  final bool medal;

  Color get _color {
    final value = int.tryParse(tag.colorHex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0xFFD54F));
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      key: Key(
        (medal ? 'profile-owner-medal-' : 'profile-owner-tag-') + tag.name,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (medal) ...[
            Icon(
              Icons.workspace_premium_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            tag.name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
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
        border: Border.all(color: _color.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.35),
            blurRadius: 10,
          ),
        ],
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
  const _GoldBadge(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      gradient: FeaturePalette.glow(color),
      accentColor: color,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
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
      accentColor: color,
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
            child: ShiningIcon(
              icon: icon,
              color: color,
              size: 24,
              boxSize: 42,
              glow: 0.34,
            ),
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
