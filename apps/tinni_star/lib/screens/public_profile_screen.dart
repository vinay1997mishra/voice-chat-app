import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/tinni_state.dart';
import '../infra/app_backend_service.dart';
import '../ui/royal_theme.dart';
import 'cp_screen.dart';
import 'enemy_screen.dart';
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
  List<Map<String, dynamic>> identityTags = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> trends = const <Map<String, dynamic>>[];
  Map<String, dynamic>? cpPartnerProfile;
  RemoteEnemy? enemyRelation;
  Map<String, dynamic>? enemyPartnerProfile;
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
      _safeProfileLoad(
        widget.state.backend.userTagsAndMedals(
          account.authToken,
          account.userId,
        ),
      ),
      _safeProfileLoad(widget.state.backend.profileTrends(account.authToken)),
      _safeProfileLoad(widget.state.backend.cpState(account.authToken)),
      _safeProfileLoad(widget.state.backend.enemyState(account.authToken)),
    ]);

    if (!mounted) return;

    final mediaResult = results[0];
    final statsResult = results[1];
    final tagResult = results[2];
    final trendsResult = results[3];
    final cpResult = results[4];
    final enemyResult = results[5] is RemoteEnemy
        ? results[5] as RemoteEnemy
        : null;

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

    Map<String, dynamic>? resolvedEnemyPartner;
    if (enemyResult != null && enemyResult.state == 'accepted') {
      final enemyId = enemyResult.userA == account.userId
          ? enemyResult.userB
          : enemyResult.userA;
      final enemyPartnerResult = await _safeProfileLoad(
        widget.state.backend.searchUserById(
          account.authToken,
          enemyId,
        ),
      );
      if (enemyPartnerResult is Map) {
        resolvedEnemyPartner =
            Map<String, dynamic>.from(enemyPartnerResult);
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
      enemyRelation = enemyResult;
      enemyPartnerProfile = resolvedEnemyPartner;
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
              _buildAboutMe()
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

  Widget _relationAvatar({
    required ImageProvider? image,
    required String fallback,
    required Color accent,
    required double size,
    bool add = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF151827),
        border: Border.all(color: accent, width: 2.6),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .55),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CircleAvatar(
              backgroundColor: const Color(0xFF171827),
              backgroundImage: image,
              child: image == null && !add
                  ? Text(
                      fallback.isEmpty ? '?' : fallback.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: size * .30,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : image == null
                      ? Icon(
                          Icons.person_rounded,
                          color: Colors.white.withValues(alpha: .30),
                          size: size * .42,
                        )
                      : null,
            ),
          ),
          if (add)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * .34,
                height: size * .34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF17131D),
                  border: Border.all(color: accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: .45),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: accent,
                  size: size * .23,
                ),
              ),
            ),
          Positioned(
            top: -14,
            left: size * .28,
            child: Icon(
              Icons.workspace_premium_rounded,
              color: accent,
              size: size * .32,
              shadows: [
                Shadow(color: accent.withValues(alpha: .75), blurRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowingCpHeart(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: size * .82,
            color: const Color(0xFFFF2D87),
            shadows: const [
              Shadow(color: Color(0xFFFF4FA0), blurRadius: 22),
              Shadow(color: Color(0xAAFF9ACC), blurRadius: 38),
            ],
          ),
          Icon(
            Icons.favorite_rounded,
            size: size * .55,
            color: const Color(0xFFFF79B6),
          ),
          Positioned(
            top: size * .15,
            right: size * .17,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: size * .17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _murderEnemyEmblem(double size) {
    const red = Color(0xFFFF202D);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Transform.rotate(
            angle: .78,
            child: Container(
              width: size * .68,
              height: size * .68,
              decoration: BoxDecoration(
                color: const Color(0xFF09080C),
                border: Border.all(color: red, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0xCCFF1428), blurRadius: 28, spreadRadius: 4),
                ],
              ),
            ),
          ),
          for (final angle in <double>[0, .78, 1.57, 2.35])
            Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.topCenter,
                child: Icon(
                  Icons.change_history_rounded,
                  color: const Color(0xFFDFE1E8),
                  size: size * .30,
                  shadows: const [
                    Shadow(color: Color(0xFFFF101F), blurRadius: 12),
                  ],
                ),
              ),
            ),
          const Icon(
            Icons.dangerous_rounded,
            color: red,
            size: 58,
            shadows: [
              Shadow(color: Color(0xFFFF001A), blurRadius: 20),
            ],
          ),
          Positioned(
            bottom: size * .04,
            child: Container(
              width: size * .72,
              height: 3,
              decoration: BoxDecoration(
                color: red,
                boxShadow: const [
                  BoxShadow(color: red, blurRadius: 12, spreadRadius: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCpProfileCard() {
    final account = widget.state.auth.current;
    final cp = widget.state.cp.relationship;
    if (account == null) return const SizedBox.shrink();

    final myAvatar = _provider(account.avatarDataUrl);
    ImageProvider? partnerAvatar;
    if (cp != null) {
      partnerAvatar = _provider(
        cpPartnerProfile?['avatar_data_url']?.toString(),
      );
    }

    return InkWell(
      key: const Key('profile-cp-card'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CpScreen(state: widget.state),
        ),
      ),
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 184,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFFF4FA0), width: 1.8),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF24132D),
              Color(0xFF12192D),
              Color(0xFF231126),
            ],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x55FF2D87), blurRadius: 22, spreadRadius: 1),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: const _RelationWavePainter(
                  primary: Color(0xFFFF2D87),
                  secondary: Color(0xFFFF8FC3),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: _relationAvatar(
                      image: myAvatar,
                      fallback: account.displayName,
                      accent: const Color(0xFFFF8FC3),
                      size: 92,
                    ),
                  ),
                ),
                _glowingCpHeart(104),
                Expanded(
                  child: Center(
                    child: _relationAvatar(
                      image: partnerAvatar,
                      fallback: '',
                      accent: const Color(0xFFFF8FC3),
                      size: 92,
                      add: cp == null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEnemyPanel() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnemyScreen(state: widget.state),
      ),
    );
    if (!mounted) return;
    setState(() => loading = true);
    await _load();
  }

  Widget _buildEnemyProfileCard() {
    final account = widget.state.auth.current;
    if (account == null) return const SizedBox.shrink();
    final activeEnemy =
        enemyRelation != null && enemyRelation!.state == 'accepted';
    final enemyAvatar = activeEnemy
        ? _provider(enemyPartnerProfile?['avatar_data_url']?.toString())
        : null;
    final enemyName = activeEnemy
        ? (enemyPartnerProfile?['display_name']?.toString() ?? '')
        : '';
    const red = Color(0xFFFF202D);
    return InkWell(
      key: const Key('profile-enemy-card'),
      onTap: _openEnemyPanel,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 184,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: red, width: 1.9),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1B0609),
              Color(0xFF07080D),
              Color(0xFF23070A),
            ],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66FF1226), blurRadius: 24, spreadRadius: 1),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: const _RelationWavePainter(
                  primary: Color(0xFFFF1428),
                  secondary: Color(0xFF5C0008),
                  hostile: true,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: _relationAvatar(
                      image: _provider(account.avatarDataUrl),
                      fallback: account.displayName,
                      accent: red,
                      size: 92,
                    ),
                  ),
                ),
                _murderEnemyEmblem(106),
                Expanded(
                  child: Center(
                    child: _relationAvatar(
                      image: enemyAvatar,
                      fallback: enemyName,
                      accent: red,
                      size: 92,
                      add: !activeEnemy,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutMe() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _buildCpProfileCard(),
          const SizedBox(height: 12),
          _buildEnemyProfileCard(),
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


class _RelationWavePainter extends CustomPainter {
  const _RelationWavePainter({
    required this.primary,
    required this.secondary,
    this.hostile = false,
  });

  final Color primary;
  final Color secondary;
  final bool hostile;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hostile ? 2.4 : 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..color = primary.withValues(alpha: .72);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = secondary.withValues(alpha: .85);

    for (var i = 0; i < 3; i++) {
      final y = size.height * (.40 + i * .10);
      final p = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * .22,
          y + (hostile ? -24 : 22) * (i.isEven ? 1 : -1),
          size.width * .38,
          y + (hostile ? 22 : -18) * (i.isEven ? 1 : -1),
          size.width * .50,
          y,
        )
        ..cubicTo(
          size.width * .64,
          y + (hostile ? -20 : 18) * (i.isEven ? 1 : -1),
          size.width * .80,
          y + (hostile ? 24 : -22) * (i.isEven ? 1 : -1),
          size.width,
          y,
        );
      canvas.drawPath(p, glow);
      canvas.drawPath(p, line);
    }

    final dot = Paint()..color = primary.withValues(alpha: .75);
    for (var i = 0; i < 16; i++) {
      final x = size.width * ((i * 37) % 100) / 100;
      final y = size.height * (.18 + ((i * 23) % 64) / 100);
      canvas.drawCircle(Offset(x, y), hostile ? 1.7 : 2.1, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RelationWavePainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.hostile != hostile;
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
