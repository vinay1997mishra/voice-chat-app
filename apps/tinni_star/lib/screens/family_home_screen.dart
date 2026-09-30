import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../community/family_service.dart';
import '../ui/royal_theme.dart';

ImageProvider? _familyAvatar(String? value) {
  final source = value?.trim() ?? '';
  if (source.isEmpty) return null;
  if (source.startsWith('data:image/')) {
    try {
      return MemoryImage(base64Decode(source.split(',').last));
    } catch (_) {
      return null;
    }
  }
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return NetworkImage(source);
  }
  return null;
}

String _familyCompact(int value) {
  if (value >= 1000000000) {
    return (value / 1000000000).toStringAsFixed(1) + 'B';
  }
  if (value >= 1000000) {
    return (value / 1000000).toStringAsFixed(1) + 'M';
  }
  if (value >= 1000) {
    return (value / 1000).toStringAsFixed(1) + 'K';
  }
  return value.toString();
}

String _familyDate(dynamic value) {
  final ms = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  if (ms == null || ms <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

class FamilyWalletScreen extends StatefulWidget {
  const FamilyWalletScreen({
    super.key,
    required this.state,
    required this.familyName,
  });

  final TinniState state;
  final String familyName;

  @override
  State<FamilyWalletScreen> createState() => _FamilyWalletScreenState();
}

class _FamilyWalletScreenState extends State<FamilyWalletScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> transfers = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final results = await Future.wait<dynamic>([
        widget.state.backend.familyState(account.authToken),
        widget.state.backend.familyWalletTransfers(account.authToken),
        widget.state.backend.wallet(account.authToken),
      ]);
      widget.state.family.applyRemote(
        Map<String, dynamic>.from(results[0] as Map),
      );
      widget.state.wallet.applyRemote(results[2]);
      if (!mounted) return;
      setState(() {
        transfers = List<Map<String, dynamic>>.from(results[1] as List);
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

  Future<void> _sendCoins(FamilyMember member) async {
    final me = widget.state.auth.current;
    if (me == null || me.userId == member.userId) return;
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Send coins to ' + member.name),
        content: TextField(
          key: const Key('family-wallet-amount'),
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Coins',
            helperText:
                'Available: ' + widget.state.wallet.coins.toString() + ' coins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !mounted) return;

    try {
      await widget.state.backend.sendFamilyCoins(
        me.authToken,
        receiverUserId: member.userId,
        coins: amount,
      );
      final remote = await widget.state.backend.wallet(me.authToken);
      widget.state.wallet.applyRemote(remote);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            amount.toString() +
                ' coins sent to ' +
                member.name +
                '. Receiver Family EXP +' +
                amount.toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.state.auth.current?.userId;
    return Scaffold(
      key: const Key('family-wallet-screen'),
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        title: const Text(
          'Family Wallet',
          style: TextStyle(
            color: FeaturePalette.family,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  RoyalPanel(
                    key: const Key('family-wallet-balance'),
                    gradient: FeaturePalette.glow(FeaturePalette.wallet),
                    accentColor: FeaturePalette.wallet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.familyName,
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'My Coins: ' +
                              widget.state.wallet.coins.toString(),
                          style: const TextStyle(
                            color: FeaturePalette.wallet,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Family Bonus Wallet: ' +
                              widget.state.family.walletCoins.toString(),
                          style: const TextStyle(color: RoyalPalette.muted),
                        ),
                        Text(
                          'Monthly bonus: ' +
                              widget.state.family.monthlyWalletBonusPercent
                                  .toStringAsFixed(2) +
                              '% of eligible received coins',
                          style: const TextStyle(
                            color: RoyalPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const GoldSectionTitle('Send coins to Family members'),
                  const SizedBox(height: 8),
                  for (final member in widget.state.family.members)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: RoyalPanel(
                        key: Key('family-wallet-member-' + member.userId),
                        padding: const EdgeInsets.all(9),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 21,
                              backgroundImage:
                                  _familyAvatar(member.avatarDataUrl),
                              child: _familyAvatar(member.avatarDataUrl) == null
                                  ? Text(
                                      member.name.trim().isEmpty
                                          ? '?'
                                          : member.name
                                              .trim()[0]
                                              .toUpperCase(),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.name,
                                    style: const TextStyle(
                                      color: RoyalPalette.cream,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'ID ' +
                                        member.userId +
                                        ' • Received ' +
                                        _familyCompact(member.receivedCoins),
                                    style: const TextStyle(
                                      color: RoyalPalette.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (member.userId != me)
                              TextButton(
                                key: Key(
                                  'family-wallet-send-' + member.userId,
                                ),
                                onPressed: () => _sendCoins(member),
                                child: const Text('Send Coins'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const GoldSectionTitle('Transfer Records'),
                  const SizedBox(height: 8),
                  if (transfers.isEmpty)
                    const RoyalPanel(
                      child: Center(
                        child: Text(
                          'No Family Wallet transfers yet',
                          style: TextStyle(color: RoyalPalette.muted),
                        ),
                      ),
                    ),
                  for (final row in transfers)
                    ListTile(
                      leading: const Icon(
                        Icons.swap_horiz_rounded,
                        color: FeaturePalette.family,
                      ),
                      title: Text(
                        (row['sender_name']?.toString() ?? '') +
                            ' → ' +
                            (row['receiver_name']?.toString() ?? ''),
                        style: const TextStyle(color: RoyalPalette.cream),
                      ),
                      subtitle: Text(
                        _familyDate(row['created_at']),
                        style: const TextStyle(color: RoyalPalette.muted),
                      ),
                      trailing: Text(
                        _familyCompact(
                          (row['coins'] as num?)?.toInt() ?? 0,
                        ),
                        style: const TextStyle(
                          color: FeaturePalette.wallet,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({
    super.key,
    required this.state,
    this.previewName,
    this.previewTag,
    this.previewFamilyId,
  });

  final TinniState state;
  final String? previewName;
  final String? previewTag;
  final String? previewFamilyId;

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  bool loading = true;
  String? error;
  int tab = 0;
  Map<String, dynamic>? remoteFamily;
  List<Map<String, dynamic>> rawMembers = const <Map<String, dynamic>>[];

  bool get joined => widget.state.family.exists;
  String get familyName =>
      widget.state.family.name ?? widget.previewName ?? 'Family';
  String get familyTag => widget.state.family.tag ?? widget.previewTag ?? 'FM';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final data = await widget.state.backend.familyState(account.authToken);
      widget.state.family.applyRemote(data);
      final family = data['family'];
      final members = data['members'];
      if (!mounted) return;
      setState(() {
        remoteFamily = family is Map
            ? Map<String, dynamic>.from(family)
            : null;
        rawMembers = members is List
            ? members
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
            : const <Map<String, dynamic>>[];
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

  Future<void> _joinPreview() async {
    final account = widget.state.auth.current;
    final familyId = widget.previewFamilyId;
    if (account == null || familyId == null || familyId.isEmpty) return;
    try {
      await widget.state.backend.requestFamilyJoin(
        account.authToken,
        familyId: familyId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Family join request sent for Leader/Admin approval.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _checkIn() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final result =
          await widget.state.backend.familyCheckIn(account.authToken);
      await _load();
      if (!mounted) return;
      final already = result['already_checked_in'] == true;
      final exp = (result['exp_awarded'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            already
                ? 'Today\'s Family check-in is already complete.'
                : 'Family check-in complete. EXP +' + exp.toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _editNotice() async {
    final account = widget.state.auth.current;
    if (account == null || !joined) return;
    final controller = TextEditingController(text: widget.state.family.notice);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Family announcement'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: 'Write Family announcement',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      await widget.state.backend.updateFamilyNotice(
        account.authToken,
        notice: value,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.state.family.level;
    final exp = widget.state.family.experience;
    final next = widget.state.family.nextLevelRequiredExperience;
    final members = widget.state.family.members;

    return Scaffold(
      key: const Key('family-home-screen'),
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        title: Text(
          familyName,
          style: const TextStyle(
            color: FeaturePalette.family,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (joined)
            IconButton(
              key: const Key('family-member-manage-button'),
              tooltip: 'Member Manage',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyMemberManageScreen(
                    state: widget.state,
                    familyName: familyName,
                  ),
                ),
              ).then((_) => _load()),
              icon: const Icon(Icons.manage_accounts_rounded),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                children: [
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  RoyalPanel(
                    key: const Key('family-level-shell'),
                    gradient: FeaturePalette.glow(FeaturePalette.family),
                    accentColor: FeaturePalette.family,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor:
                                  FeaturePalette.family.withValues(alpha: 0.18),
                              child: const Icon(
                                Icons.shield_rounded,
                                size: 36,
                                color: FeaturePalette.family,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    familyName,
                                    style: const TextStyle(
                                      color: RoyalPalette.cream,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    key: const Key('family-level-tag'),
                                    familyTag + ' • Family Lv.' + level.toString(),
                                    style: const TextStyle(
                                      color: FeaturePalette.family,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    members.length.toString() +
                                        ' members • EXP ' +
                                        _familyCompact(exp),
                                    style: const TextStyle(
                                      color: RoyalPalette.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (joined)
                              IconButton(
                                key: const Key('family-level-open'),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FamilyLevelScreen(
                                      state: widget.state,
                                      familyName: familyName,
                                      familyTag: familyTag,
                                    ),
                                  ),
                                ).then((_) => _load()),
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: FeaturePalette.family,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: widget.state.family.levelProgress,
                          color: FeaturePalette.family,
                          backgroundColor: RoyalPalette.panel2,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            next == null
                                ? 'Max configured level'
                                : 'Next ' + _familyCompact(next) + ' EXP',
                            style: const TextStyle(
                              color: RoyalPalette.muted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _FamilyAction(
                          key: const Key('family-check-in'),
                          icon: Icons.event_available_rounded,
                          label: 'Daily Check-in',
                          onTap: joined ? _checkIn : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FamilyAction(
                          key: const Key('family-wallet-open'),
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Family Wallet',
                          onTap: joined
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FamilyWalletScreen(
                                        state: widget.state,
                                        familyName: familyName,
                                      ),
                                    ),
                                  ).then((_) => _load())
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FamilyTab(
                          label: 'Home',
                          selected: tab == 0,
                          onTap: () => setState(() => tab = 0),
                        ),
                      ),
                      Expanded(
                        child: _FamilyTab(
                          label: 'Trends',
                          selected: tab == 1,
                          onTap: () => setState(() => tab = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (tab == 0) ...[
                    GoldSectionTitle(
                      'Family Announcement',
                      trailing: joined
                          ? IconButton(
                              key: const Key('family-edit-announcement'),
                              onPressed: _editNotice,
                              icon: const Icon(
                                Icons.edit_rounded,
                                color: FeaturePalette.family,
                              ),
                            )
                          : null,
                    ),
                    RoyalPanel(
                      key: const Key('family-announcement'),
                      child: Text(
                        widget.state.family.notice.trim().isEmpty
                            ? 'Welcome to ' + familyName + ' ❤️'
                            : widget.state.family.notice,
                        style: const TextStyle(color: RoyalPalette.muted),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const GoldSectionTitle('Top members of the family'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _MemberStar(
                            title: 'Charm Star',
                            member: members.isEmpty ? null : members.first,
                            icon: Icons.favorite_rounded,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _MemberStar(
                            title: 'Wealth Star',
                            member: members.length > 1
                                ? members[1]
                                : (members.isEmpty ? null : members.first),
                            icon: Icons.diamond_rounded,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _MemberStar(
                            title: 'Active Star',
                            member: members.length > 2
                                ? members[2]
                                : (members.isEmpty ? null : members.first),
                            icon: Icons.local_fire_department_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const GoldSectionTitle('Member List'),
                    const SizedBox(height: 8),
                    if (members.isEmpty)
                      const RoyalPanel(
                        child: Text(
                          'No members to display',
                          style: TextStyle(color: RoyalPalette.muted),
                        ),
                      ),
                    for (final member in members)
                      _FamilyMemberRow(member: member),
                  ] else ...[
                    const GoldSectionTitle('Family Contribution'),
                    const SizedBox(height: 8),
                    for (var index = 0; index < members.length; index++)
                      ListTile(
                        leading: Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            color: FeaturePalette.family,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        title: Text(
                          members[index].name,
                          style: const TextStyle(color: RoyalPalette.cream),
                        ),
                        subtitle: Text(
                          _familyRoleLabel(members[index].role),
                          style: const TextStyle(color: RoyalPalette.muted),
                        ),
                        trailing: Text(
                          _familyCompact(members[index].receivedCoins),
                          style: const TextStyle(
                            color: FeaturePalette.wallet,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    RoyalPanel(
                      child: Text(
                        'Reference coin scale: 20,000 reference coins = '
                        '2,000,000 Tinni coins (100×) for coin-based Family '
                        'progression values.',
                        style: const TextStyle(
                          color: RoyalPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                  if (!joined && widget.previewFamilyId != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('family-join-button'),
                      onPressed: _joinPreview,
                      icon: const Icon(Icons.group_add_rounded),
                      label: const Text('Request to Join'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class FamilyLevelScreen extends StatefulWidget {
  const FamilyLevelScreen({
    super.key,
    required this.state,
    required this.familyName,
    required this.familyTag,
  });

  final TinniState state;
  final String familyName;
  final String familyTag;

  @override
  State<FamilyLevelScreen> createState() => _FamilyLevelScreenState();
}

class _FamilyLevelScreenState extends State<FamilyLevelScreen> {
  bool loading = true;
  Map<String, dynamic> family = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    final data = await widget.state.backend.familyState(account.authToken);
    widget.state.family.applyRemote(data);
    final raw = data['family'];
    if (!mounted) return;
    setState(() {
      family = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final level = (family['level'] as num?)?.toInt() ??
        widget.state.family.level;
    final exp = (family['experience'] as num?)?.toInt() ??
        widget.state.family.experience;
    final next = (family['next_threshold'] as num?)?.toInt();
    final basis =
        (family['monthly_bonus_basis_points'] as num?)?.toInt() ??
            widget.state.family.monthlyWalletBonusBasisPoints;

    return Scaffold(
      key: const Key('family-level-screen'),
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(title: const Text('Family Level')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                RoyalPanel(
                  gradient: FeaturePalette.glow(FeaturePalette.family),
                  accentColor: FeaturePalette.family,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: FeaturePalette.family,
                        size: 54,
                      ),
                      Text(
                        widget.familyTag + ' • LV.' + level.toString(),
                        style: const TextStyle(
                          color: RoyalPalette.cream,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'EXP ' + _familyCompact(exp),
                        style: const TextStyle(
                          color: FeaturePalette.family,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: widget.state.family.levelProgress,
                        color: FeaturePalette.family,
                        backgroundColor: RoyalPalette.panel2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                RoyalPanel(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Next level requirement',
                          style: TextStyle(color: RoyalPalette.cream),
                        ),
                        trailing: Text(
                          next == null ? 'MAX' : _familyCompact(next),
                          style: const TextStyle(
                            color: FeaturePalette.wallet,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Divider(color: RoyalPalette.deepGold),
                      ListTile(
                        title: const Text(
                          'Monthly Wallet Bonus',
                          style: TextStyle(color: RoyalPalette.cream),
                        ),
                        trailing: Text(
                          (basis / 100).toStringAsFixed(2) + '%',
                          style: const TextStyle(
                            color: FeaturePalette.family,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const RoyalPanel(
                  child: Text(
                    'Family EXP rule: receiving 1 Tinni coin through the '
                    'Family Wallet gives the Family +1 EXP. Sending coins '
                    'does not give the sender Family EXP. Daily check-in also '
                    'adds the configured Family EXP once per day.\n\n'
                    'Reference conversion for coin-based Family progression: '
                    '20,000 reference coins = 2,000,000 Tinni coins (100×).',
                    style: TextStyle(
                      color: RoyalPalette.muted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class FamilyMemberManageScreen extends StatefulWidget {
  const FamilyMemberManageScreen({
    super.key,
    required this.state,
    required this.familyName,
    this.members,
  });

  final TinniState state;
  final String familyName;
  final List<FamilyMember>? members;

  @override
  State<FamilyMemberManageScreen> createState() =>
      _FamilyMemberManageScreenState();
}

class _FamilyMemberManageScreenState extends State<FamilyMemberManageScreen> {
  bool loading = true;
  List<Map<String, dynamic>> requests = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final data = await widget.state.backend.familyState(account.authToken);
      widget.state.family.applyRemote(data);
      final raw = data['join_requests'];
      if (!mounted) return;
      setState(() {
        requests = raw is List
            ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
            : const <Map<String, dynamic>>[];
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _setAdmin(FamilyMember member, bool admin) async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      await widget.state.backend.setFamilyAdmin(
        account.authToken,
        userId: member.userId,
        admin: admin,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _remove(FamilyMember member) async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      await widget.state.backend.removeFamilyMember(
        account.authToken,
        userId: member.userId,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _resolve(Map<String, dynamic> request, bool approve) async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      await widget.state.backend.resolveFamilyJoin(
        account.authToken,
        userId: request['user_id']?.toString() ?? '',
        approve: approve,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.state.auth.current?.userId ?? '';
    final myMember = widget.state.family.memberById(me);
    final isLeader = myMember?.role == FamilyRole.head;
    final canReview = isLeader ||
        myMember?.role == FamilyRole.deputyHead;

    return Scaffold(
      key: const Key('family-member-manage-screen'),
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(title: const Text('Family Members')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (canReview && requests.isNotEmpty) ...[
                    const GoldSectionTitle('Join Requests'),
                    for (final request in requests)
                      ListTile(
                        title: Text(
                          request['display_name']?.toString() ??
                              request['user_id']?.toString() ??
                              'User',
                          style: const TextStyle(color: RoyalPalette.cream),
                        ),
                        subtitle: Text(
                          'ID ' + (request['user_id']?.toString() ?? ''),
                          style: const TextStyle(color: RoyalPalette.muted),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Approve',
                              onPressed: () => _resolve(request, true),
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Reject',
                              onPressed: () => _resolve(request, false),
                              icon: const Icon(
                                Icons.cancel_rounded,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(color: RoyalPalette.deepGold),
                  ],
                  const GoldSectionTitle('Members'),
                  for (final member in widget.state.family.members)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: _familyAvatar(member.avatarDataUrl),
                        child: _familyAvatar(member.avatarDataUrl) == null
                            ? Text(
                                member.name.isEmpty
                                    ? '?'
                                    : member.name[0].toUpperCase(),
                              )
                            : null,
                      ),
                      title: Text(
                        member.name,
                        style: const TextStyle(color: RoyalPalette.cream),
                      ),
                      subtitle: Text(
                        'ID ' +
                            member.userId +
                            ' • ' +
                            _familyRoleLabel(member.role),
                        style: const TextStyle(color: RoyalPalette.muted),
                      ),
                      trailing: member.userId == me ||
                              member.role == FamilyRole.head
                          ? null
                          : PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'admin') {
                                  _setAdmin(member, true);
                                } else if (value == 'member') {
                                  _setAdmin(member, false);
                                } else if (value == 'remove') {
                                  _remove(member);
                                }
                              },
                              itemBuilder: (_) => [
                                if (isLeader &&
                                    member.role != FamilyRole.deputyHead)
                                  const PopupMenuItem(
                                    value: 'admin',
                                    child: Text('Add Admin'),
                                  ),
                                if (isLeader &&
                                    member.role == FamilyRole.deputyHead)
                                  const PopupMenuItem(
                                    value: 'member',
                                    child: Text('Remove Admin'),
                                  ),
                                if (canReview &&
                                    member.role == FamilyRole.member)
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove Member'),
                                  ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _FamilyAction extends StatelessWidget {
  const _FamilyAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: FeaturePalette.family),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyTab extends StatelessWidget {
  const _FamilyTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? FeaturePalette.family.withValues(alpha: 0.20)
              : RoyalPalette.nearBlack,
          border: Border.all(
            color: selected ? FeaturePalette.family : RoyalPalette.deepGold,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? FeaturePalette.family : RoyalPalette.muted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MemberStar extends StatelessWidget {
  const _MemberStar({
    required this.title,
    required this.member,
    required this.icon,
  });

  final String title;
  final FamilyMember? member;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Column(
        children: [
          Icon(icon, color: FeaturePalette.family, size: 25),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          CircleAvatar(
            radius: 19,
            backgroundImage: _familyAvatar(member?.avatarDataUrl),
            child: _familyAvatar(member?.avatarDataUrl) == null
                ? Text(
                    member == null || member!.name.isEmpty
                        ? '?'
                        : member!.name[0].toUpperCase(),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _FamilyMemberRow extends StatelessWidget {
  const _FamilyMemberRow({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: _familyAvatar(member.avatarDataUrl),
        child: _familyAvatar(member.avatarDataUrl) == null
            ? Text(
                member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
              )
            : null,
      ),
      title: Text(
        member.name,
        style: const TextStyle(
          color: RoyalPalette.cream,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        'ID ' + member.userId + ' • ' + _familyRoleLabel(member.role),
        style: const TextStyle(color: RoyalPalette.muted),
      ),
      trailing: Text(
        _familyCompact(member.receivedCoins),
        style: const TextStyle(
          color: FeaturePalette.wallet,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _familyRoleLabel(FamilyRole role) {
  switch (role) {
    case FamilyRole.head:
      return 'Family Leader';
    case FamilyRole.deputyHead:
      return 'Family Admin';
    case FamilyRole.assistant:
      return 'Family Member';
    case FamilyRole.member:
      return 'Family Member';
  }
}
