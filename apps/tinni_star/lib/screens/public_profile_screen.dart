import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';
import 'guardian_screen.dart';
import 'cp_screen.dart';
import 'personal_profile_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, String?> media = const <String, String?>{};
  Map<String, dynamic> stats = const <String, dynamic>{};
  Map<String, dynamic> guardian = const <String, dynamic>{};
  List<Map<String, dynamic>> identityTags = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> trends = const <Map<String, dynamic>>[];
  Map<String, dynamic>? cpPartnerProfile;
  bool loading = true;
  bool posting = false;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ImageProvider? _provider(String? value) {
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

  Future<dynamic> _safeProfileLoad(Future<dynamic> request) async {
    try {
      return await request;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;

    final results = await Future.wait<dynamic>([
      _safeProfileLoad(widget.state.backend.profileMedia(account.authToken)),
      _safeProfileLoad(widget.state.backend.accountStats(account.authToken)),
      _safeProfileLoad(widget.state.backend.guardianState(account.authToken)),
      _safeProfileLoad(
        widget.state.backend.userTagsAndMedals(
          account.authToken,
          account.userId,
        ),
      ),
      _safeProfileLoad(widget.state.backend.profileTrends(account.authToken)),
      _safeProfileLoad(widget.state.backend.cpState(account.authToken)),
    ]);

    if (!mounted) return;

    final mediaResult = results[0];
    final statsResult = results[1];
    final guardianResult = results[2];
    final tagResult = results[3];
    final trendsResult = results[4];
    final cpResult = results.length > 5 ? results[5] : null;

    widget.state.cp.applyRemote(
      cpResult,
      currentUserId: account.userId,
    );
    Map<String, dynamic>? partnerProfile;
    final relationship = widget.state.cp.relationship;
    if (relationship != null) {
      final partnerId = relationship.userA == account.userId
          ? relationship.userB
          : relationship.userA;
      final partnerResult = await _safeProfileLoad(
        widget.state.backend.searchUserById(
          account.authToken,
          partnerId,
        ),
      );
      if (partnerResult is Map) {
        partnerProfile = Map<String, dynamic>.from(partnerResult);
      }
    }

    final tagData = tagResult is Map
        ? Map<String, dynamic>.from(tagResult)
        : const <String, dynamic>{};
    final rawIdentityTags = tagData['identity_tags'];

    setState(() {
      if (mediaResult is Map) {
        media = Map<String, String?>.from(mediaResult);
      }
      if (statsResult is Map) {
        stats = Map<String, dynamic>.from(statsResult);
      }
      if (guardianResult is Map) {
        guardian = Map<String, dynamic>.from(guardianResult);
      }
      if (tagResult is Map) {
        identityTags = rawIdentityTags is List
            ? rawIdentityTags
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false)
            : const <Map<String, dynamic>>[];
      }
      if (trendsResult is List) {
        trends = List<Map<String, dynamic>>.from(
          trendsResult.whereType<Map>().map(
                (row) => Map<String, dynamic>.from(row),
              ),
        );
      }
      cpPartnerProfile = partnerProfile;
      loading = false;
    });
  }

  Future<void> _openEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalProfileScreen(state: widget.state),
      ),
    );
    if (!mounted) return;
    setState(() => loading = true);
    await _load();
  }

  Future<void> _addTrend() async {
    final account = widget.state.auth.current;
    if (account == null || posting) return;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Trend'),
        content: TextField(
          key: const Key('profile-trend-text'),
          controller: controller,
          maxLength: 500,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Share something on your profile…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || !mounted) return;
    setState(() => posting = true);
    try {
      final row = await widget.state.backend.addProfileTrend(
        account.authToken,
        text,
      );
      if (!mounted) return;
      setState(() {
        trends = <Map<String, dynamic>>[row, ...trends];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => posting = false);
    }
  }

  String _dateText(dynamic value) {
    final ms = (value as num?)?.toInt() ?? 0;
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: RoyalPalette.gold,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: RoyalPalette.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.state.auth.current;
    if (account == null) {
      return const Scaffold(body: Center(child: Text('Login required')));
    }

    final cover = _provider(media['cover']);
    final avatar = _provider(account.avatarDataUrl);
    final following = (stats['following_count'] as num?)?.toInt() ?? 0;
    final fans = (stats['followers_count'] as num?)?.toInt() ?? 0;
    final wealth = stats['wealth'] is Map
        ? Map<String, dynamic>.from(stats['wealth'] as Map)
        : const <String, dynamic>{};
    final charm = stats['charm'] is Map
        ? Map<String, dynamic>.from(stats['charm'] as Map)
        : const <String, dynamic>{};
    final wealthLevel = (wealth['level'] as num?)?.toInt() ?? 0;
    final charmLevel = (charm['level'] as num?)?.toInt() ?? 0;
    final guardianRow = guardian['guardian'] is Map
        ? Map<String, dynamic>.from(guardian['guardian'] as Map)
        : null;

    return Scaffold(
      key: const Key('public-profile-screen'),
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(account.displayName),
        actions: [
          IconButton(
            key: const Key('public-profile-edit'),
            onPressed: _openEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 26),
          children: [
            SizedBox(
              height: 238,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    bottom: 58,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: RoyalPalette.panel,
                        image: cover == null
                            ? null
                            : DecorationImage(
                                image: cover,
                                fit: BoxFit.cover,
                              ),
                        gradient: cover == null
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF0B291F),
                                  Color(0xFF06130F),
                                ],
                              )
                            : null,
                      ),
                      child: cover == null
                          ? const Center(
                              child: Icon(
                                Icons.landscape_rounded,
                                color: RoyalPalette.deepGold,
                                size: 58,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 138,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: RoyalPalette.black,
                        border: Border.all(
                          color: RoyalPalette.gold,
                          width: 1.4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: RoyalPalette.panel2,
                        backgroundImage: avatar,
                        child: avatar == null
                            ? Text(
                                account.displayName.isEmpty
                                    ? '?'
                                    : account.displayName.characters.first
                                        .toUpperCase(),
                                style: const TextStyle(
                                  color: RoyalPalette.gold,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 101,
                    right: 14,
                    top: 181,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            account.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RoyalPalette.cream,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          account.flagEmoji,
                          style: const TextStyle(fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 101,
                    top: 208,
                    child: GestureDetector(
                      key: const Key('public-profile-uid-long-press'),
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () => _copyUserId(account.userId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'UID: ${account.userId}',
                          style: const TextStyle(
                            color: RoyalPalette.muted,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              key: const Key('profile-identity-tags'),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 38),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 9,
                    children: [
                      for (final tag in identityTags)
                        _ProfileIdentityTag(tag: tag),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: RoyalPanel(
                padding: const EdgeInsets.symmetric(vertical: 12),
                accentColor: RoyalPalette.deepGold,
                child: Row(
                  children: [
                    _stat('Follow', following.toString()),
                    _stat('Fans', fans.toString()),
                    _stat('Wealth', wealthLevel.toString()),
                    _stat('Charm', charmLevel.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                account.signature.trim().isEmpty
                    ? 'This user has not written a signature yet.'
                    : account.signature,
                style: const TextStyle(
                  color: RoyalPalette.muted,
                  height: 1.35,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _ProfileTabButton(
                    label: 'About me',
                    selected: tab == 0,
                    onTap: () => setState(() => tab = 0),
                  ),
                  const SizedBox(width: 18),
                  _ProfileTabButton(
                    label: 'Trends',
                    selected: tab == 1,
                    onTap: () => setState(() => tab = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (tab == 0)
              _buildAboutMe(
                guardianRow: guardianRow,
                accountName: account.displayName,
              )
            else
              _buildTrends(),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCpProfileCard() {
    final account = widget.state.auth.current;
    final cp = widget.state.cp.relationship;
    if (account == null) return const SizedBox.shrink();

    final myAvatar = _provider(account.avatarDataUrl);
    String partnerName = '?';
    ImageProvider? partnerAvatar;
    var subtitle = 'Invite a CP • 2,222,222 coins';
    var levelText = 'CP';
    if (cp != null) {
      final partnerId = cp.userA == account.userId ? cp.userB : cp.userA;
      partnerName =
          cpPartnerProfile?['display_name']?.toString().trim().isNotEmpty == true
              ? cpPartnerProfile!['display_name'].toString()
              : partnerId;
      partnerAvatar = _provider(
        cpPartnerProfile?['avatar_data_url']?.toString(),
      );
      final days = DateTime.now()
              .difference(
                DateTime(
                  cp.startedAt.year,
                  cp.startedAt.month,
                  cp.startedAt.day,
                ),
              )
              .inDays +
          1;
      subtitle = 'Lv.' +
          cp.level.toString() +
          ' • ' +
          cp.intimacy.toString() +
          ' intimacy • ' +
          (days < 1 ? 1 : days).toString() +
          ' days';
      levelText = 'CP Lv.' + cp.level.toString();
    }

    Widget avatar({
      required ImageProvider? image,
      required String name,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: FeaturePalette.cpSoft,
                width: 1.6,
              ),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFF301126),
              backgroundImage: image,
              child: image == null
                  ? Text(
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: FeaturePalette.cpSoft,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 76,
            child: Text(
              name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RoyalPalette.cream,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }

    return RoyalPanel(
      key: const Key('profile-cp-card'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CpScreen(state: widget.state),
        ),
      ),
      accentColor: FeaturePalette.cp,
      child: Row(
        children: [
          avatar(image: myAvatar, name: account.displayName),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: FeaturePalette.cp,
                  size: 28,
                ),
                Text(
                  'CP',
                  style: TextStyle(
                    color: FeaturePalette.cpSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          avatar(image: partnerAvatar, name: partnerName),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  levelText,
                  style: const TextStyle(
                    color: FeaturePalette.cpSoft,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoyalPalette.muted,
                    fontSize: 10,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'All my CP  ›',
                  style: TextStyle(
                    color: FeaturePalette.cp,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutMe({
    required Map<String, dynamic>? guardianRow,
    required String accountName,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _buildCpProfileCard(),
          const SizedBox(height: 10),
          RoyalPanel(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GuardianScreen(state: widget.state),
              ),
            ),
            accentColor: RoyalPalette.deepGold,
            child: Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: RoyalPalette.gold,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Guardian',
                        style: TextStyle(
                          color: RoyalPalette.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        guardianRow == null
                            ? 'You do not have a Guardian yet'
                            : guardianRow['display_name']?.toString() ??
                                'Guardian',
                        style: const TextStyle(
                          color: RoyalPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: RoyalPalette.gold,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (media.values.any((value) => (value ?? '').isNotEmpty))
            RoyalPanel(
              accentColor: RoyalPalette.deepGold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Photos of life',
                    style: TextStyle(
                      color: RoyalPalette.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 7,
                    crossAxisSpacing: 7,
                    children: [
                      for (final key in const [
                        'life_1',
                        'life_2',
                        'life_3',
                        'travel',
                      ])
                        if (_provider(media[key]) != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image(
                              image: _provider(media[key])!,
                              fit: BoxFit.cover,
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrends() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('profile-add-trend'),
              onPressed: posting ? null : _addTrend,
              icon: const Icon(Icons.add_rounded),
              label: Text(posting ? 'Posting…' : 'Post a Trend'),
            ),
          ),
          const SizedBox(height: 9),
          if (trends.isEmpty)
            const RoyalPanel(
              child: Text(
                'No Trends yet.',
                style: TextStyle(color: RoyalPalette.muted),
              ),
            )
          else
            for (final trend in trends)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RoyalPanel(
                  accentColor: RoyalPalette.deepGold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trend['text']?.toString() ?? '',
                        style: const TextStyle(
                          color: RoyalPalette.cream,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _dateText(trend['created_at']),
                        style: const TextStyle(
                          color: RoyalPalette.muted,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ProfileIdentityTag extends StatelessWidget {
  const _ProfileIdentityTag({required this.tag});

  final Map<String, dynamic> tag;

  Color _hex(String? raw, Color fallback) {
    final value = (raw ?? '').replaceFirst('#', '');
    if (value.length != 6) return fallback;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? fallback : Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    final kind = tag['kind']?.toString() ?? 'custom';
    final designation = (tag['designation']?.toString().trim().isNotEmpty ?? false)
        ? tag['designation']!.toString().trim()
        : (tag['name']?.toString() ?? 'Tag');
    if (kind == 'v_official') {
      final background = _hex(
        tag['background_color']?.toString(),
        const Color(0xFF69C9FF),
      );
      return Container(
        key: const Key('profile-v-official-tag'),
        padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
        decoration: BoxDecoration(
          color: const Color(0xFF12100C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: RoyalPalette.deepGold.withValues(alpha: .72),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: background,
                border: Border.all(
                  color: RoyalPalette.gold,
                  width: 2.4,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55F6C84F),
                    blurRadius: 9,
                  ),
                ],
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFD6DAE1),
                    Color(0xFF8D939E),
                    Color(0xFFF7F8FA),
                  ],
                ).createShader(bounds),
                child: const Text(
                  'V',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              designation,
              style: const TextStyle(
                color: RoyalPalette.gold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    final automatic = tag['kind']?.toString() == 'auto_role';
    final color = _hex(
      tag['color']?.toString(),
      automatic ? RoyalPalette.gold : RoyalPalette.cream,
    );
    return Container(
      key: Key('profile-identity-tag-' + designation.toLowerCase()),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF14120E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .78)),
      ),
      child: Text(
        designation,
        style: TextStyle(
          color: automatic ? RoyalPalette.gold : color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? RoyalPalette.gold : RoyalPalette.muted,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 3,
              width: selected ? 34 : 0,
              decoration: BoxDecoration(
                color: RoyalPalette.gold,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
