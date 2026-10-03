import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../relationship/cp_service.dart';
import '../ui/royal_theme.dart';
import 'cp_disconnect_screen.dart';
import 'cp_ranking_screen.dart';

class CpScreen extends StatefulWidget {
  const CpScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<CpScreen> createState() => _CpScreenState();
}

class _CpScreenState extends State<CpScreen> {
  bool loadingFriends = false;
  bool _syncingCp = false;
  Map<String, dynamic>? _partnerProfile;

  @override
  void initState() {
    super.initState();
    _syncCp();
    if (widget.state.social.friendProfiles.isEmpty) {
      _syncFriends();
    }
  }

  Future<void> _syncCp() async {
    final account = widget.state.auth.current;
    if (account == null || _syncingCp) return;
    _syncingCp = true;
    try {
      final remote = await widget.state.backend.cpState(account.authToken);
      widget.state.cp.applyRemote(remote, currentUserId: account.userId);

      final memories = await widget.state.backend.cpMemories(account.authToken);
      widget.state.cp.memories
        ..clear()
        ..addAll(memories);

      try {
        final inventory =
            await widget.state.backend.inventory(account.authToken);
        widget.state.inventory.applyRemote(inventory);
      } catch (_) {
        // CP Nest remains usable if the inventory refresh is unavailable.
      }

      Map<String, dynamic>? partner;
      if (remote != null && remote.state == 'accepted') {
        final partnerId =
            remote.userA == account.userId ? remote.userB : remote.userA;
        try {
          partner = await widget.state.backend.searchUserById(
            account.authToken,
            partnerId,
          );
        } catch (_) {
          partner = null;
        }
      }
      _partnerProfile = partner;
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the last known CP Nest state visible while network retries.
    } finally {
      _syncingCp = false;
    }
  }

  Future<void> _syncFriends() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    setState(() => loadingFriends = true);
    try {
      await widget.state.social.syncFriends(account.authToken);
    } catch (_) {
      // Keep the locally known friend list usable if the network is unavailable.
    }
    if (mounted) setState(() => loadingFriends = false);
  }

  Future<void> _requestCp(String friendId) async {
    final account = widget.state.auth.current;
    if (account == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CP Invite'),
        content: const Text(
          'Send a confession invitation to become CP? '
          'CP Invite costs 2,222,222 Tinni coins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final remote =
          await widget.state.backend.cpRequest(account.authToken, friendId);
      widget.state.cp.applyRemote(remote, currentUserId: account.userId);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _respond(bool accept) async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final remote = await widget.state.backend.cpRespond(account.authToken, accept);
      widget.state.cp.applyRemote(remote, currentUserId: account.userId);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _addMemory() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add CP Memory'),
        content: TextField(
          controller: controller,
          maxLength: 120,
          decoration: const InputDecoration(hintText: 'Write a memory'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      await widget.state.backend.cpAddMemory(account.authToken, value);
      final memories = await widget.state.backend.cpMemories(account.authToken);
      widget.state.cp.memories
        ..clear()
        ..addAll(memories);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  ImageProvider? _avatarProvider(String? value) {
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

  int _loveDays(DateTime startedAt) {
    final start = DateTime(startedAt.year, startedAt.month, startedAt.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final value = today.difference(start).inDays + 1;
    return value < 1 ? 1 : value;
  }

  String _dateText(DateTime value) {
    return value.day.toString().padLeft(2, '0') +
        '/' +
        value.month.toString().padLeft(2, '0') +
        '/' +
        value.year.toString();
  }


  Future<void> _showRingCabinet() async {
    final account = widget.state.auth.current;
    final cp = widget.state.cp.relationship;
    if (account == null || cp == null) return;

    final rings = widget.state.inventory.ownedDetails.entries
        .where((entry) => entry.value['item_kind']?.toString() == 'ring')
        .toList(growable: false);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF100812),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ring Cabinet',
                style: TextStyle(
                  color: FeaturePalette.cpSoft,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cp.ringId == null
                    ? 'Choose an owned CP ring'
                    : 'Equipped CP ring: ' + cp.ringId!,
                style: const TextStyle(color: RoyalPalette.muted),
              ),
              const SizedBox(height: 12),
              if (rings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No owned rings yet. Rings purchased or granted to this account will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: RoyalPalette.muted),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final entry = rings[index];
                      final row = entry.value;
                      final selected = cp.ringId == entry.key;
                      final asset = _avatarProvider(
                        row['asset_url']?.toString(),
                      );
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: selected
                                ? FeaturePalette.cp
                                : RoyalPalette.bronze,
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2A1027),
                          backgroundImage: asset,
                          child: asset == null
                              ? const Icon(
                                  Icons.diamond_rounded,
                                  color: FeaturePalette.cpSoft,
                                )
                              : null,
                        ),
                        title: Text(
                          row['name']?.toString() ?? entry.key,
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          entry.key,
                          style: const TextStyle(color: RoyalPalette.muted),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: FeaturePalette.cp,
                              )
                            : const Icon(
                                Icons.chevron_right_rounded,
                                color: FeaturePalette.cpSoft,
                              ),
                        onTap: selected
                            ? null
                            : () async {
                                try {
                                  final remote =
                                      await widget.state.backend.cpUpdate(
                                    account.authToken,
                                    'ring',
                                    <String, dynamic>{'ring_id': entry.key},
                                  );
                                  widget.state.cp.applyRemote(
                                    remote,
                                    currentUserId: account.userId,
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  if (mounted) setState(() {});
                                } catch (error) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error
                                            .toString()
                                            .replaceFirst('Bad state: ', ''),
                                      ),
                                    ),
                                  );
                                }
                              },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMemories() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF100812),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'CP Memories',
                      style: TextStyle(
                        color: FeaturePalette.cpSoft,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _addMemory();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (widget.state.cp.memories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'No CP memories yet.',
                    style: TextStyle(color: RoyalPalette.muted),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.state.cp.memories.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: Color(0x333D243A),
                      height: 1,
                    ),
                    itemBuilder: (_, index) => ListTile(
                      leading: const Icon(
                        Icons.favorite_rounded,
                        color: FeaturePalette.cp,
                      ),
                      title: Text(
                        widget.state.cp.memories[index],
                        style: const TextStyle(color: RoyalPalette.cream),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTasksAndRules() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF100812),
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 22),
            children: const [
              Text(
                'CP Rules',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FeaturePalette.cpSoft,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12),
              _CpRuleTile(
                icon: Icons.favorite_rounded,
                title: 'How to become CP',
                subtitle:
                    'Invite a friend from CP Planet/Profile, or send the CP Invite confession gift in a room. CP Invite costs 2,222,222 Tinni coins.',
              ),
              _CpRuleTile(
                icon: Icons.card_giftcard_rounded,
                title: 'Gift intimacy',
                subtitle:
                    'Regular gifts count at 100% of normalized intimacy. Lucky gifts count only 10%. If both CP partners exchange gifts on the same day, eligible gift intimacy gets a 1.2× daily exchange multiplier.',
              ),
              _CpRuleTile(
                icon: Icons.mic_rounded,
                title: 'Sweet mic task',
                subtitle:
                    'Being on mic together: every completed 5 minutes = 200 intimacy points.',
              ),
              _CpRuleTile(
                icon: Icons.workspace_premium_rounded,
                title: 'CP level cycle',
                subtitle:
                    'When intimacy reaches the next level threshold, the level updates and a new 7-day cycle begins. Lv.1 → Lv.2 starts at 200K intimacy.',
              ),
              _CpRuleTile(
                icon: Icons.timelapse_rounded,
                title: 'Maintain / decay',
                subtitle:
                    'If no intimacy is gained for 3 consecutive days, from day 4 intimacy decreases by 5% per day until activity resumes.',
              ),
              _CpRuleTile(
                icon: Icons.visibility_rounded,
                title: 'CP card display',
                subtitle:
                    'The active connected CP relationship is shown on the ID/Profile CP card. Other/non-active CP records stay inside the CP list.',
              ),
              _CpRuleTile(
                icon: Icons.currency_exchange_rounded,
                title: 'Tinni CP conversion',
                subtitle:
                    'Reference app: 45,000 coins = USD 1. Tinni: 2,000,000 coins = USD 1. CP Heart is scaled to 44,444 coins and CP Invite to 2,222,222 coins.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.state.auth.current;
    final cp = widget.state.cp.relationship;
    final friends = widget.state.social.friendProfiles;

    return Scaffold(
      key: const Key('cp-screen'),
      appBar: AppBar(
        title: const Text(
          'CP / Courting',
          style: TextStyle(
            color: FeaturePalette.cp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async { await _syncCp(); await _syncFriends(); },
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            if (cp != null) ...[
              Builder(
                builder: (context) {
                  final partnerId =
                      cp.userA == account?.userId ? cp.userB : cp.userA;
                  final partnerName =
                      _partnerProfile?['display_name']?.toString() ??
                          partnerId;
                  final partnerAvatar = _avatarProvider(
                    _partnerProfile?['avatar_data_url']?.toString(),
                  );
                  final myAvatar = _avatarProvider(account?.avatarDataUrl);
                  final days = _loveDays(cp.startedAt);
                  final progress = cp.level <= 1
                      ? (cp.intimacy / 200000).clamp(0.0, 1.0)
                      : 1.0;

                  return Column(
                    children: [
                      Container(
                        key: const Key('cp-nest-hero'),
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF3C112C),
                              Color(0xFF6E214E),
                              Color(0xFF1A0B1A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: FeaturePalette.cp.withValues(alpha: 0.82),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  FeaturePalette.cp.withValues(alpha: 0.24),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFFFFD766),
                                  size: 17,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'CP NEST',
                                  style: TextStyle(
                                    color: FeaturePalette.cpSoft,
                                    fontSize: 20,
                                    letterSpacing: 2.2,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFFFFD766),
                                  size: 17,
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: _CpPersonAvatar(
                                    image: myAvatar,
                                    name: account?.displayName ?? 'You',
                                    userId: account?.userId ?? '',
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 5),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.favorite_rounded,
                                        color: FeaturePalette.cp,
                                        size: 38,
                                      ),
                                      Text(
                                        'LOVE',
                                        style: TextStyle(
                                          color: FeaturePalette.cpSoft,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: _CpPersonAvatar(
                                    image: partnerAvatar,
                                    name: partnerName,
                                    userId: partnerId,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _CpNestPill(
                                  icon: Icons.favorite_rounded,
                                  text: days.toString() + ' Love Days',
                                ),
                                _CpNestPill(
                                  icon: Icons.workspace_premium_rounded,
                                  text: 'CP Lv.' + cp.level.toString(),
                                ),
                                _CpNestPill(
                                  icon: Icons.auto_awesome_rounded,
                                  text: cp.intimacy.toString() + ' Intimacy',
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: const Color(0x55220D20),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  FeaturePalette.cp,
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            if (cp.level <= 1)
                              Text(
                                (200000 - cp.intimacy).clamp(0, 200000).toString() +
                                    ' intimacy needed for Lv.2',
                                style: const TextStyle(
                                  color: FeaturePalette.cpSoft,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'Together since ' + _dateText(cp.startedAt),
                              style: const TextStyle(
                                color: Color(0xFFE7A6CC),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (cp.ringId != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x44220D20),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0x99FFD766),
                                  ),
                                ),
                                child: Text(
                                  '💍 ' + cp.ringId!,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD766),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        key: const Key('cp-nest-actions'),
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 9,
                        crossAxisSpacing: 9,
                        childAspectRatio: 0.92,
                        children: [
                          _CpNestAction(
                            icon: Icons.favorite_rounded,
                            label: 'Intimacy',
                            subtitle: 'Gift / Mic',
                            onTap: _showTasksAndRules,
                          ),
                          _CpNestAction(
                            icon: Icons.diamond_rounded,
                            label: 'Ring Cabinet',
                            subtitle: cp.ringId == null ? 'Choose' : 'Equipped',
                            onTap: _showRingCabinet,
                          ),
                          _CpNestAction(
                            icon: Icons.photo_album_rounded,
                            label: 'Memories',
                            subtitle: widget.state.cp.memories.length.toString(),
                            onTap: _showMemories,
                          ),
                          _CpNestAction(
                            icon: Icons.rule_rounded,
                            label: 'Tasks / Rules',
                            subtitle: 'View',
                            onTap: _showTasksAndRules,
                          ),
                          _CpNestAction(
                            icon: Icons.emoji_events_rounded,
                            label: 'CP Ranking',
                            subtitle: 'Ranking',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CpRankingScreen(state: widget.state),
                                ),
                              );
                            },
                          ),
                          _CpNestAction(
                            icon: Icons.heart_broken_rounded,
                            label: 'Disconnect',
                            subtitle: 'CP',
                            danger: true,
                            onTap: () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CpDisconnectScreen(
                                    state: widget.state,
                                  ),
                                ),
                              );
                              await _syncCp();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      RoyalPanel(
                        accentColor: FeaturePalette.cp,
                        gradient: FeaturePalette.glow(FeaturePalette.cp),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite_border_rounded,
                              color: FeaturePalette.cp,
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.state.cp.memories.isEmpty
                                    ? 'Create your first CP memory together.'
                                    : widget.state.cp.memories.first,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: RoyalPalette.cream,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _showMemories,
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                color: FeaturePalette.cpSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ] else if (widget.state.cp.state == CourtingState.pending) ...[
              RoyalPanel(
                gradient: FeaturePalette.glow(FeaturePalette.cp),
                accentColor: FeaturePalette.cp,
                child: Column(
                  children: [
                    const Text(
                      'CP request pending',
                      style: TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From ' +
                          (widget.state.cp.sender ?? '-') +
                          ' to ' +
                          (widget.state.cp.receiver ?? '-'),
                      style: const TextStyle(color: RoyalPalette.muted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _respond(false),
                            child: const Text('Refuse'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _respond(true),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              const GoldSectionTitle('Choose a friend for CP'),
              const SizedBox(height: 8),
              if (loadingFriends)
                const Center(child: CircularProgressIndicator())
              else if (friends.isEmpty)
                const RoyalPanel(
                  child: Text(
                    'No mutual friends available yet. CP requests can only be sent to friends.',
                    style: TextStyle(color: RoyalPalette.muted),
                  ),
                )
              else
                for (final friend in friends)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RoyalPanel(
                      gradient: FeaturePalette.glow(FeaturePalette.cp),
                      accentColor: FeaturePalette.cp,
                      child: Row(
                        children: [
                          CircleAvatar(
                            child: Text(
                              friend.name.isEmpty
                                  ? '?'
                                  : friend.name.characters.first.toUpperCase(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  friend.name,
                                  style: const TextStyle(
                                    color: RoyalPalette.cream,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'ID ' + friend.id,
                                  style: const TextStyle(
                                    color: RoyalPalette.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => _requestCp(friend.id),
                            child: const Text('Invite'),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CpPersonAvatar extends StatelessWidget {
  const _CpPersonAvatar({
    required this.image,
    required this.name,
    required this.userId,
  });

  final ImageProvider? image;
  final String name;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFD766),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FF4FA3),
                blurRadius: 13,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFF2B1025),
            backgroundImage: image,
            child: image == null
                ? Text(
                    initial.toUpperCase(),
                    style: const TextStyle(
                      color: FeaturePalette.cpSoft,
                      fontWeight: FontWeight.w900,
                      fontSize: 25,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: RoyalPalette.cream,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        Text(
          'ID ' + userId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFD790B8),
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

class _CpNestPill extends StatelessWidget {
  const _CpNestPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x44220D20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FeaturePalette.cp.withValues(alpha: 0.48),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: FeaturePalette.cpSoft, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: FeaturePalette.cpSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CpNestAction extends StatelessWidget {
  const _CpNestAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent =
        danger ? const Color(0xFFFF6A7A) : FeaturePalette.cp;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.17),
              const Color(0xFF120A12),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.46),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShiningIcon(
              icon: icon,
              color: accent,
              size: 22,
              boxSize: 38,
              glow: 0.34,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: RoyalPalette.cream,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent.withValues(alpha: 0.92),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CpRuleTile extends StatelessWidget {
  const _CpRuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ShiningIcon(
        icon: icon,
        color: FeaturePalette.cp,
        size: 19,
        boxSize: 36,
        glow: 0.32,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: RoyalPalette.cream,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: RoyalPalette.muted,
          fontSize: 11,
        ),
      ),
    );
  }
}

