import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../identity/owner_tag.dart';
import '../i18n/tinni_localization.dart';
import '../infra/app_backend_service.dart';
import '../ui/animated_avatar_frame.dart';
import 'family_home_screen.dart';
import 'family_ranking_screen.dart';
import 'custom_center_screen.dart';
import 'vip_screen.dart';
import 'store_screen.dart';
import 'recharge_screen.dart';
import 'cp_screen.dart';
import 'privacy_policy_screen.dart';
import 'mine_function_screens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<OwnerTag> _ownerTags = <OwnerTag>[];
  final List<OwnerTag> _ownerMedals = <OwnerTag>[];
  Map<String, dynamic> _accountStats = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadOwnerTags();
    _loadEconomyState();
    _loadAccountStats();
  }

  Future<void> _loadAccountStats() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final stats = await widget.state.backend.accountStats(account.authToken);
      if (!mounted) return;
      setState(() => _accountStats = stats);
    } catch (_) {}
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
                errorText = error.toString().replaceFirst('Bad state: ', '');
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
              setDialogState(
                () => errorText = 'Search and select a recipient first.',
              );
              return;
            }
            final amount = double.tryParse(amountController.text.trim()) ?? 0;
            final cents = (amount * 100).round();
            if (cents < 200) {
              setDialogState(() => errorText = 'Minimum transfer is \$2.00.');
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
                      'Transferred \$' +
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
                errorText = error.toString().replaceFirst('Bad state: ', '');
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
                  Text('Available: ' + widget.state.wallet.withdrawableUsdText),
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
                      labelText: 'USD amount (minimum \$2)',
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

  ImageProvider? _mineAvatarProvider(String? value) {
    final source = value?.trim() ?? '';
    if (source.isEmpty) return null;
    if (source.startsWith('data:image/')) {
      try {
        return MemoryImage(base64Decode(source.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return NetworkImage(source);
    }
    return null;
  }

  void _openMineScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      if (mounted) setState(() {});
    });
  }


  Widget _mineMenuRow({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD21A),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33D8A900),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: const Color(0xFF5A4A12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF5C574F),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFBDB8AF),
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mineMenuGroup(List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F6D5A2A),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: rows),
    );
  }

  Widget _mineStatusCard({
    required Key key,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 60,
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFC400), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33D39A00),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: Colors.white70, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.state.auth.current;
    if (account == null) {
      return const Scaffold(
        body: Center(child: Text('Login required')),
      );
    }

    final language = widget.state.languagePreference.value;
    final avatar = _mineAvatarProvider(account.avatarDataUrl);
    final followCount = (_accountStats['following_count'] as num?)?.toInt() ??
        widget.state.social.following.length;
    final fansCount = (_accountStats['followers_count'] as num?)?.toInt() ?? 0;
    final charmPoints =
        (_accountStats['lifetime_received_coins'] as num?)?.toInt() ?? 0;
    final wealth = _accountStats['wealth'] is Map
        ? Map<String, dynamic>.from(_accountStats['wealth'] as Map)
        : const <String, dynamic>{};
    final wealthLevel = (wealth['level'] as num?)?.toInt() ?? 0;
    final vipLevel = widget.state.identity.vip.level;
    final profileBackgroundId =
        widget.state.inventory.equipped('profile_background');
    final profileBackgroundAsset = profileBackgroundId == null
        ? ''
        : widget.state.inventory.ownedDetails[profileBackgroundId]
                    ?['asset_url']
                ?.toString() ??
            '';
    final profileBackground =
        _mineAvatarProvider(profileBackgroundAsset);
    final ringId = widget.state.inventory.equipped('ring');
    final profileCardId = widget.state.inventory.equipped('profile_card');

    return Scaffold(
      key: const Key('reference-mine-screen'),
      backgroundColor: const Color(0xFFFFFBF4),
      body: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFE39B),
                Color(0xFFFFF5DB),
                Color(0xFFFFFBF4),
                Color(0xFFFFFBF4),
              ],
              stops: [0.0, 0.20, 0.36, 1.0],
            ),
            image: profileBackground == null
                ? null
                : DecorationImage(
                    image: profileBackground,
                    fit: BoxFit.cover,
                    opacity: 0.24,
                  ),
          ),
          child: ListView(
            key: const Key('reference-mine-list'),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            children: [
              Container(
                key: const Key('profile-active-card'),
                padding: EdgeInsets.all(profileCardId == null ? 0 : 9),
                decoration: profileCardId == null
                    ? null
                    : BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x33FFC928),
                            Color(0x22FFFFFF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFFC928),
                        ),
                      ),
                child: Row(
                  children: [
                  Container(
                    padding: EdgeInsets.all(ringId == null ? 0 : 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: ringId == null
                          ? null
                          : Border.all(
                              color: const Color(0xFFFFC928),
                              width: 2.4,
                            ),
                      boxShadow: ringId == null
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x66FFC928),
                                blurRadius: 12,
                              ),
                            ],
                    ),
                    child: AnimatedAvatarFrame(
                      size: 66,
                      frameId: widget.state.inventory.equippedFrameId,
                      child: CircleAvatar(
                      radius: 33,
                      backgroundColor: const Color(0xFF0F6F6D),
                      backgroundImage: avatar,
                      child: avatar == null
                          ? Text(
                              account.displayName.trim().isEmpty
                                  ? '?'
                                  : account.displayName
                                      .trim()
                                      .characters
                                      .first
                                      .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                account.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF433D34),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              account.flagEmoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'UID:' + account.userId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF777168),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5C5962),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Lv.0',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.state.family.exists) ...[
                          const SizedBox(height: 4),
                          Container(
                            key: const Key('profile-family-tag'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD665),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (widget.state.family.tag ?? 'FM') +
                                  ' • ' +
                                  widget.state.family.levelLabel,
                              style: const TextStyle(
                                color: Color(0xFF6E5200),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF6D5B00),
                    size: 23,
                  ),
                ],
              ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MineCountStat(
                    value: followCount.toString(),
                    label: tinniText(language, 'follow'),
                  ),
                  const _MineCountDivider(),
                  _MineCountStat(value: fansCount.toString(), label: tinniText(language, 'fans')),
                  const _MineCountDivider(),
                  _MineCountStat(value: charmPoints.toString(), label: tinniText(language, 'charm')),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                key: const Key('mine-wallet'),
                borderRadius: BorderRadius.circular(11),
                onTap: () => _openMineScreen(
                  RechargeScreen(state: widget.state),
                ),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF5A900), Color(0xFFFFD944)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFFD88900),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33D28A00),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 40,
                        color: Color(0xFFFFF0A4),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coins',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.state.wallet.coins.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE98D),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'First Recharge',
                              style: TextStyle(
                                color: Color(0xFF9E6900),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tinniText(language, 'wallet'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _mineStatusCard(
                    key: const Key('mine-vip-card'),
                    title: 'VIP',
                    subtitle: vipLevel > 0 ? 'VIP' + vipLevel.toString() : 'Not obtained',
                    colors: const [Color(0xFFB829E8), Color(0xFF6B2FC0)],
                    icon: Icons.workspace_premium_rounded,
                    onTap: () => _openMineScreen(
                      VipScreen(state: widget.state),
                    ),
                  ),
                  const SizedBox(width: 7),
                  _mineStatusCard(
                    key: const Key('mine-wealth-level-card'),
                    title: tinniText(language, 'wealth_level'),
                    subtitle: 'LV.' + wealthLevel.toString(),
                    colors: const [Color(0xFF24B85B), Color(0xFF087A38)],
                    icon: Icons.diamond_rounded,
                    onTap: () => _openMineScreen(
                      WealthLevelScreen(state: widget.state),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _mineMenuGroup([
                _mineMenuRow(
                  key: const Key('mine-medal-of-honor'),
                  icon: Icons.hexagon_rounded,
                  label: tinniText(language, 'medal_of_honor'),
                  onTap: () => _openMineScreen(
                    MedalOfHonorScreen(state: widget.state),
                  ),
                ),
                _mineMenuRow(
                  key: const Key('mine-custom-center'),
                  icon: Icons.design_services_rounded,
                  label: tinniText(language, 'custom_center'),
                  onTap: () => _openMineScreen(
                    CustomCenterScreen(state: widget.state),
                  ),
                ),
                _mineMenuRow(
                  key: const Key('mine-shop'),
                  icon: Icons.shopping_bag_rounded,
                  label: tinniText(language, 'shop'),
                  onTap: () => _openMineScreen(
                    StoreScreen(state: widget.state),
                  ),
                ),
                _mineMenuRow(
                  key: const Key('mine-props'),
                  icon: Icons.auto_awesome_rounded,
                  label: tinniText(language, 'props'),
                  onTap: () => _openMineScreen(
                    PropsScreen(state: widget.state),
                  ),
                ),
                _mineMenuRow(
                  key: const Key('mine-reward-records'),
                  icon: Icons.receipt_long_rounded,
                  label: tinniText(language, 'reward_records'),
                  onTap: () => _openMineScreen(
                    RewardRecordsScreen(state: widget.state),
                  ),
                ),
              ]),
              const SizedBox(height: 9),
              _mineMenuGroup([
                _mineMenuRow(
                  key: const Key('mine-task'),
                  icon: Icons.task_alt_rounded,
                  label: tinniText(language, 'task'),
                  onTap: () => _openMineScreen(
                    TaskScreen(state: widget.state),
                  ),
                ),
                _mineMenuRow(
                  key: const Key('mine-host-data'),
                  icon: Icons.monitor_heart_rounded,
                  label: tinniText(language, 'host_data'),
                  onTap: () => _openMineScreen(
                    HostDataScreen(
                      state: widget.state,
                      onTransfer: _showSettlementTransfer,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 9),
              _mineMenuGroup([
                _mineMenuRow(
                  key: const Key('mine-family'),
                  icon: Icons.home_work_rounded,
                  label: tinniText(language, 'family'),
                  onTap: () => _openMineScreen(
                    widget.state.family.exists
                        ? FamilyHomeScreen(state: widget.state)
                        : FamilyRankingScreen(state: widget.state),
                  ),
                ),
                _mineMenuRow(
                  key: const Key('mine-cp-nest'),
                  icon: Icons.favorite_rounded,
                  label: tinniText(language, 'cp_nest'),
                  onTap: () => _openMineScreen(
                    CpScreen(state: widget.state),
                  ),
                ),
              ]),
              const SizedBox(height: 9),
              _mineMenuGroup([
                _mineMenuRow(
                  key: const Key('mine-feedback'),
                  icon: Icons.chat_bubble_rounded,
                  label: tinniText(language, 'feedback'),
                  onTap: () => _openMineScreen(
                    FeedbackScreen(state: widget.state),
                  ),
                ),
                _mineMenuRow(
                  key: const Key('mine-setting'),
                  icon: Icons.settings_rounded,
                  label: tinniText(language, 'setting'),
                  onTap: () => _openMineScreen(
                    TinniSettingsScreen(state: widget.state),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _MineCountStat extends StatelessWidget {
  const _MineCountStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF514A41),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF898279),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _MineCountDivider extends StatelessWidget {
  const _MineCountDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: const Color(0xFFE2D8C4),
    );
  }
}


