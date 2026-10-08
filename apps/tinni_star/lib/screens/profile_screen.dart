import 'enemy_screen.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/tinni_state.dart';
import '../identity/owner_tag.dart';
import '../i18n/tinni_localization.dart';
import '../infra/app_backend_service.dart';
import '../infra/backend_http.dart';
import '../ui/animated_avatar_frame.dart';
import '../ui/premium_effects.dart';
import 'family_home_screen.dart';
import 'family_ranking_screen.dart';
import 'vip_screen.dart';
import 'store_screen.dart';
import 'recharge_screen.dart';
import 'cp_screen.dart';
import 'privacy_policy_screen.dart';
import 'public_profile_screen.dart';
import 'guardian_screen.dart';
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
  bool _economyLoading = false;

  @override
  void initState() {
    super.initState();
    widget.state.realtimeChanges.addListener(_onLiveChanged);
    widget.state.pageEntries.addListener(_onPageEntered);
    _loadOwnerTags();
    _loadEconomyState();
    _loadAccountStats();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.realtimeChanges.removeListener(_onLiveChanged);
      oldWidget.state.pageEntries.removeListener(_onPageEntered);
      widget.state.realtimeChanges.addListener(_onLiveChanged);
      widget.state.pageEntries.addListener(_onPageEntered);
      _loadEconomyState();
      _loadAccountStats();
    }
  }

  void _onLiveChanged() { if (mounted) setState(() {}); }
  void _onPageEntered() { if (widget.state.pageEntries.value == 3) _refreshPage(); }
  Future<void> _refreshPage() async {
    await widget.state.refreshAuthenticatedAccount(force: true);
    await Future.wait([_loadEconomyState(), _loadAccountStats()]);
  }
  @override
  void dispose() {
    widget.state.realtimeChanges.removeListener(_onLiveChanged);
    widget.state.pageEntries.removeListener(_onPageEntered);
    super.dispose();
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
    if (account == null || _economyLoading) return;
    _economyLoading = true;
    try {
      final wallet = await widget.state.backend.wallet(account.authToken);
      final vip = await widget.state.backend.vipMe(account.authToken);
      widget.state.wallet.applyRemote(wallet);
      await _loadOwnerTags();
      widget.state.identity.setVipLevel(
        vip == null ? 0 : int.tryParse(vip['vip_level']?.toString() ?? '') ?? 0,
      );
      if (mounted) setState(() {});
    } catch (_) {
    } finally {
      _economyLoading = false;
    }
  }

  Future<void> _showSettlementTransfer(String senderRoleValue) async {
    final account = widget.state.auth.current;
    if (account == null) return;

    final senderRole = senderRoleValue.trim().toLowerCase();
    if (!const <String>{'host', 'agency', 'bd'}.contains(senderRole)) return;
    final minimumCents = senderRole == 'host' ? 200 : 1000;

    RemoteWallet liveWallet;
    Map<String, List<SettlementRecipient>> directory;
    try {
      final values = await Future.wait<dynamic>([
        widget.state.backend.wallet(account.authToken),
        widget.state.backend.settlementRecipients(account.authToken),
      ]);
      liveWallet = values[0] as RemoteWallet;
      directory =
          values[1] as Map<String, List<SettlementRecipient>>;
      widget.state.wallet.applyRemote(liveWallet);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.backend.userSafeError(error))),
      );
      return;
    }
    if (!mounted) return;

    var availableCents = liveWallet.withdrawableUsdCents;
    final amountController = TextEditingController(
      text: availableCents >= minimumCents
          ? (minimumCents / 100).toStringAsFixed(2)
          : '',
    );
    final searchController = TextEditingController();
    SettlementRecipient? selected;
    String searchText = '';
    String? errorText;
    bool sending = false;

    List<SettlementRecipient> filtered(String key) {
      final rows = directory[key] ?? const <SettlementRecipient>[];
      final q = searchText.trim().toLowerCase();
      if (q.isEmpty) return rows;
      return rows.where((item) {
        return item.userId.toLowerCase().contains(q) ||
            item.displayName.toLowerCase().contains(q);
      }).toList(growable: false);
    }

    Widget recipientSection(
      String title,
      List<SettlementRecipient> rows,
      StateSetter setDialogState,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No active IDs.'),
            )
          else
            for (final item in rows)
              Builder(
                builder: (_) {
                  final isSelected = selected?.role == item.role &&
                      selected?.userId == item.userId;
                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                    title: Text(item.displayName),
                    subtitle: Text(
                      'ID ' +
                          item.userId +
                          ' • ' +
                          (item.role == 'coin_seller'
                              ? 'Coin Seller'
                              : 'Merchant'),
                    ),
                    onTap: sending
                        ? null
                        : () => setDialogState(() {
                              selected = item;
                              errorText = null;
                            }),
                  );
                },
              ),
        ],
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> sendTransfer() async {
            final recipient = selected;
            if (recipient == null) {
              setDialogState(
                () => errorText = 'Select a Coin Seller or Merchant first.',
              );
              return;
            }
            final amount = double.tryParse(amountController.text.trim()) ?? 0;
            final cents = (amount * 100).round();
            if (cents < minimumCents) {
              setDialogState(
                () => errorText = 'Minimum ' +
                    senderRole.toUpperCase() +
                    ' transfer is \$' +
                    (minimumCents / 100).toStringAsFixed(2) +
                    '.',
              );
              return;
            }
            setDialogState(() {
              sending = true;
              errorText = null;
            });
            try {
              final refreshed =
                  await widget.state.backend.wallet(account.authToken);
              widget.state.wallet.applyRemote(refreshed);
              availableCents = refreshed.withdrawableUsdCents;
              if (cents > availableCents) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  sending = false;
                  errorText = 'Available ' +
                      senderRole.toUpperCase() +
                      ' dollar balance is only \$' +
                      (availableCents / 100).toStringAsFixed(2) +
                      '.';
                });
                return;
              }
              final remote = await widget.state.backend.transferSettlement(
                account.authToken,
                recipientUserId: recipient.userId,
                recipientRole: recipient.role,
                usdCents: cents,
                senderRole: senderRole,
              );
              widget.state.wallet.applyRemote(remote);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      senderRole.toUpperCase() +
                          ' sent \$' +
                          (cents / 100).toStringAsFixed(2) +
                          ' to ' +
                          (recipient.role == 'coin_seller'
                              ? 'Coin Seller'
                              : 'Merchant') +
                          ' ' +
                          recipient.displayName +
                          ' • ID ' +
                          recipient.userId,
                    ),
                  ),
                );
              }
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                errorText = widget.state.backend.userSafeError(error);
                sending = false;
              });
            }
          }

          final sellers = filtered('coin_sellers');
          final merchants = filtered('merchants');
          return AlertDialog(
            title: Text(senderRole.toUpperCase() + ' Dollar Wallet'),
            content: SizedBox(
              width: 440,
              height: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available: \$' +
                        (availableCents / 100).toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search name or ID',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setDialogState(() {
                      searchText = value;
                      selected = null;
                    }),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView(
                      children: [
                        recipientSection('Coin Sellers', sellers, setDialogState),
                        recipientSection('Merchants', merchants, setDialogState),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'USD amount (minimum \$' +
                          (minimumCents / 100).toStringAsFixed(0) +
                          ')',
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
              FilledButton.icon(
                onPressed: sending ? null : sendTransfer,
                icon: const Icon(Icons.attach_money_rounded),
                label: Text(sending ? 'Sending…' : 'Send Dollars'),
              ),
            ],
          );
        },
      ),
    );
    amountController.dispose();
    searchController.dispose();
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
      final request = await openBackendRequest(client, 'GET', uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ' + account.authToken,
      );
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await closeBackendRequest(request);
      final body = await readBackendResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = body.trim().isEmpty ? null : jsonDecode(body);
      if (decoded is! Map) return;
      final rawTags = decoded['identity_tags'] ?? decoded['tags'];
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

  Color _tagColor(String? raw, Color fallback) {
    final value = (raw ?? '').replaceFirst('#', '');
    if (value.length != 6) return fallback;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? fallback : Color(0xFF000000 | parsed);
  }

  Widget _mineIdentityTag(OwnerTag tag) {
    final designation = tag.designation.trim().isNotEmpty
        ? tag.designation.trim()
        : tag.name.trim();
    if (tag.kind == 'v_official') {
      final background = _tagColor(
        tag.backgroundColorHex,
        const Color(0xFF69C9FF),
      );
      return Container(
        key: const Key('mine-profile-v-official-tag'),
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: const Color(0xFF12100C),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF8C6500)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: background,
                border: Border.all(
                  color: const Color(0xFFD09A0A),
                  width: 1.7,
                ),
              ),
              child: const Text(
                'V',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              designation.isEmpty ? 'Official' : designation,
              style: const TextStyle(
                color: Color(0xFFD09A0A),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    final automatic = tag.kind == 'auto_role';
    final color = _tagColor(
      tag.colorHex,
      automatic ? const Color(0xFFD09A0A) : const Color(0xFFC18A00),
    );
    return Container(
      key: Key(
        'mine-profile-identity-tag-' +
            (designation.isEmpty ? 'tag' : designation.toLowerCase()),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0804),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        designation.isEmpty ? 'Tag' : designation,
        style: TextStyle(
          color: automatic ? const Color(0xFFD09A0A) : color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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

  Future<void> _copyUserId(String userId) async {
    await Clipboard.setData(ClipboardData(text: userId));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Copied'),
          duration: Duration(seconds: 2),
        ),
      );
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
                  color: const Color(0xFF171006),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8C6500),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x448C6500),
                      blurRadius: 7,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: const Color(0xFFC18A00),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFC18A00),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9C7000),
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
        color: const Color(0xE60A0804),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF5F4600),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x443D2A00),
            blurRadius: 10,
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
            gradient: LinearGradient(
              colors: [
                Color.lerp(const Color(0xFF050402), colors.first, 0.10)!,
                Color.lerp(const Color(0xFF100B03), colors.last, 0.08)!,
              ],
            ),
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
                        color: Color(0xFFD09A0A),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFAA7C08),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: const Color(0xFFC18A00), size: 30),
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
      backgroundColor: const Color(0xFF030201),
      body: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF050402),
                Color(0xFF090603),
                Color(0xFF020201),
                Color(0xFF000000),
              ],
              stops: [0.0, 0.24, 0.58, 1.0],
            ),
            image: profileBackground == null
                ? null
                : DecorationImage(
                    image: profileBackground,
                    fit: BoxFit.cover,
                    opacity: 0.08,
                  ),
          ),
          child: CustomPaint(
            painter: const _MineGoldenStarsPainter(),
            child: RefreshIndicator(
            onRefresh: _refreshPage,
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            key: const Key('reference-mine-list'),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            children: [
              InkWell(
                key: const Key('profile-active-card'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openMineScreen(
                  PublicProfileScreen(state: widget.state),
                ),
                child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: profileCardId == null
                        ? const [
                            Color(0xE60A0804),
                            Color(0xD9060503),
                          ]
                        : const [
                            Color(0xFF151006),
                            Color(0xFF090603),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: profileCardId == null
                        ? const Color(0xFF5F4600)
                        : const Color(0xFFC18A00),
                    width: profileCardId == null ? 1 : 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x443D2A00),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: PremiumProfileCardShell(
                    effectId: profileCardId,
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
                                color: Color(0xFFC18A00),
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
                                  color: Color(0xFFD09A0A),
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
                              child: GestureDetector(
                                key: const Key('mine-uid-long-press'),
                                behavior: HitTestBehavior.opaque,
                                onLongPress: () => _copyUserId(account.userId),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    'UID:' + account.userId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF9C7000),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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
                                color: const Color(0xFF0A0804),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF8C6500),
                                ),
                              ),
                              child: const Text(
                                'Lv.0',
                                style: TextStyle(
                                  color: Color(0xFFC18A00),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_ownerTags.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            key: const Key('mine-profile-identity-tags'),
                            spacing: 6,
                            runSpacing: 5,
                            children: [
                              for (final tag in _ownerTags.take(8))
                                _mineIdentityTag(tag),
                            ],
                          ),
                        ],
                        if (widget.state.family.exists) ...[
                          const SizedBox(height: 4),
                          Container(
                            key: const Key('profile-family-tag'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0804),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF8C6500),
                              ),
                            ),
                            child: Text(
                              (widget.state.family.tag ?? 'FM') +
                                  ' • ' +
                                  widget.state.family.levelLabel,
                              style: const TextStyle(
                                color: Color(0xFFC18A00),
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
                    color: Color(0xFFC18A00),
                    size: 23,
                  ),
                ],
              ),
                  ),
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
                      colors: [Color(0xFF120D04), Color(0xFF050402)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFF8C6500),
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
                        color: Color(0xFFC18A00),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coins',
                            style: TextStyle(
                              color: Color(0xFFAA7C08),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.state.wallet.coins.toString(),
                            style: const TextStyle(
                              color: Color(0xFFD09A0A),
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
                              color: const Color(0xFF0A0804),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF8C6500),
                              ),
                            ),
                            child: const Text(
                              'First Recharge',
                              style: TextStyle(
                                color: Color(0xFFAA7C08),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tinniText(language, 'wallet'),
                            style: TextStyle(
                              color: Color(0xFFD09A0A),
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
              ListTile(
                key:const Key('mine-vs-panel'),
                leading:const Icon(Icons.bolt_rounded,color:Color(0xFFFF3549)),
                title:Text('VS · Lv.${widget.state.vsRelationship?.level ?? 1}'),
                trailing:const Icon(Icons.chevron_right),
                onTap:()=>_openMineScreen(EnemyScreen(state:widget.state)),
              ),
              InkWell(
                key: const Key('mine-cp-panel'),
                borderRadius: BorderRadius.circular(11),
                onTap: () => _openMineScreen(
                  CpScreen(state: widget.state),
                ),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B0A14), Color(0xFF080304)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFFC18A00),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33C18A00),
                        blurRadius: 7,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 34,
                        color: Color(0xFFC18A00),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My CP',
                              style: TextStyle(
                                color: Color(0xFFD09A0A),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'CP Nest • intimacy • memories • details',
                              style: TextStyle(
                                color: Color(0xFFAA7C08),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFC18A00),
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
                  key: const Key('mine-my-guardian'),
                  icon: Icons.shield_rounded,
                  label: 'My Guardian',
                  onTap: () => _openMineScreen(
                    GuardianScreen(state: widget.state),
                  ),
                ),
                _mineMenuRow(
                  key: const Key('mine-medal-of-honor'),
                  icon: Icons.hexagon_rounded,
                  label: tinniText(language, 'medal_of_honor'),
                  onTap: () => _openMineScreen(
                    MedalOfHonorScreen(state: widget.state),
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
              ]),
              const SizedBox(height: 9),
              _mineMenuGroup([
                if (widget.state.wallet.isBd)
                  _mineMenuRow(
                    key: const Key('mine-bd-panel'),
                    icon: Icons.account_tree_rounded,
                    label: 'BD Panel',
                    onTap: () => _openMineScreen(
                      HostDataScreen(
                        state: widget.state,
                        roleLabel: 'BD',
                        onTransfer: () => _showSettlementTransfer('bd'),
                      ),
                    ),
                  ),
                if (widget.state.wallet.isAgency)
                  _mineMenuRow(
                    key: const Key('mine-agency-panel'),
                    icon: Icons.business_center_rounded,
                    label: 'Agency Panel',
                    onTap: () => _openMineScreen(
                      HostDataScreen(
                        state: widget.state,
                        roleLabel: 'Agency',
                        onTransfer: () => _showSettlementTransfer('agency'),
                      ),
                    ),
                  ),
                if (widget.state.wallet.isHost)
                  _mineMenuRow(
                    key: const Key('mine-host-panel'),
                    icon: Icons.monitor_heart_rounded,
                    label: 'Host Panel',
                    onTap: () => _openMineScreen(
                      HostDataScreen(
                        state: widget.state,
                        roleLabel: 'Host',
                        onTransfer: () => _showSettlementTransfer('host'),
                      ),
                    ),
                  ),
                _mineMenuRow(
                  key: const Key('mine-task'),
                  icon: Icons.task_alt_rounded,
                  label: tinniText(language, 'task'),
                  onTap: () => _openMineScreen(
                    TaskScreen(state: widget.state),
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
              color: Color(0xFFD09A0A),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9C7000),
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
      color: const Color(0xFF5F4600),
    );
  }
}



class _MineGoldenStarsPainter extends CustomPainter {
  const _MineGoldenStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 0; i < 96; i += 1) {
      final x = (((i * 47) % 997) / 997) * size.width;
      final y = (((i * 83) % 991) / 991) * size.height;
      final bright = i % 13 == 0;
      final radius = bright ? 1.65 : 0.55 + (i % 3) * 0.22;
      dotPaint.color = bright
          ? const Color(0xFFD9A514)
          : Color.fromARGB(
              105 + (i % 4) * 20,
              190,
              137,
              0,
            );
      canvas.drawCircle(Offset(x, y), radius, dotPaint);

      if (bright) {
        glowPaint.color = const Color(0x66D9A514);
        canvas.drawLine(
          Offset(x - 4.2, y),
          Offset(x + 4.2, y),
          glowPaint,
        );
        canvas.drawLine(
          Offset(x, y - 4.2),
          Offset(x, y + 4.2),
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MineGoldenStarsPainter oldDelegate) => false;
}
