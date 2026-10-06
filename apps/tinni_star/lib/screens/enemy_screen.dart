import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../economy/enemy_gift_catalog.dart';
import '../infra/app_backend_service.dart';
import '../ui/royal_theme.dart';
import 'gifts_screen.dart';

class EnemyScreen extends StatefulWidget {
  const EnemyScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<EnemyScreen> createState() => _EnemyScreenState();
}

class _EnemyScreenState extends State<EnemyScreen> {
  RemoteEnemy? enemy;
  Map<String, dynamic>? partnerProfile;
  bool loading = true;
  bool loadingFriends = false;
  bool busy = false;

  static const red = Color(0xFFFF202D);
  static const black = Color(0xFF05070B);

  @override
  void initState() {
    super.initState();
    _syncEnemy();
    if (widget.state.social.friendProfiles.isEmpty) {
      _syncFriends();
    }
  }

  ImageProvider? _avatar(String? value) {
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

  Future<void> _syncEnemy() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final remote = await widget.state.backend.enemyState(account.authToken);
      Map<String, dynamic>? partner;
      if (remote != null && remote.state == 'accepted') {
        final partnerId =
            remote.userA == account.userId ? remote.userB : remote.userA;
        try {
          partner = await widget.state.backend.searchUserById(
            account.authToken,
            partnerId,
          );
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        enemy = remote;
        partnerProfile = partner;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _syncFriends() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    if (mounted) setState(() => loadingFriends = true);
    try {
      await widget.state.social.syncFriends(account.authToken);
    } catch (_) {}
    if (mounted) setState(() => loadingFriends = false);
  }

  Future<void> _requestEnemy(String userId) async {
    final account = widget.state.auth.current;
    if (account == null || busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF10080A),
        title: const Text('Enemy Challenge'),
        content: const Text(
          'Send an Enemy challenge? Once accepted, only Enemy gifts sent between this pair will raise the Enemy level.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Challenge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      enemy = await widget.state.backend.enemyRequest(
        account.authToken,
        userId,
      );
      partnerProfile = null;
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.state.backend.userSafeError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _respond(bool accept) async {
    final account = widget.state.auth.current;
    if (account == null || busy) return;
    setState(() => busy = true);
    try {
      enemy = await widget.state.backend.enemyRespond(
        account.authToken,
        accept,
      );
      await _syncEnemy();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.state.backend.userSafeError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _disconnect() async {
    final account = widget.state.auth.current;
    if (account == null || busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF10080A),
        title: const Text('Remove Enemy'),
        content: const Text(
          'Remove this Enemy relation? The current rivalry level will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.state.backend.enemyDisconnect(account.authToken);
      if (!mounted) return;
      setState(() {
        enemy = null;
        partnerProfile = null;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.state.backend.userSafeError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _avatarCard({
    required ImageProvider? image,
    required String name,
    required String userId,
    bool add = false,
  }) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: red, width: 2.4),
            boxShadow: const [
              BoxShadow(color: Color(0xAAFF1024), blurRadius: 20),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: const Color(0xFF16171C),
            backgroundImage: image,
            child: image == null
                ? Icon(
                    add ? Icons.add_rounded : Icons.person_rounded,
                    color: red,
                    size: add ? 38 : 32,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          width: 105,
          child: Text(
            add ? 'Add Enemy' : name,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        if (!add)
          Text(
            'ID ' + userId,
            style: const TextStyle(
              color: Color(0xFF9A8285),
              fontSize: 9.5,
            ),
          ),
      ],
    );
  }

  Widget _enemyCore() {
    return SizedBox(
      width: 106,
      height: 106,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: .78,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF09090C),
                border: Border.all(color: red, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xCCFF1327),
                    blurRadius: 28,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
          const Icon(
            Icons.dangerous_rounded,
            color: red,
            size: 62,
            shadows: [
              Shadow(color: Color(0xFFFF0018), blurRadius: 20),
            ],
          ),
          const Positioned(
            top: 4,
            child: Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFD8D9DE),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accepted(RemoteEnemy relation) {
    final account = widget.state.auth.current!;
    final partnerId =
        relation.userA == account.userId ? relation.userB : relation.userA;
    final partnerName =
        partnerProfile?['display_name']?.toString() ?? partnerId;
    final partnerAvatar = _avatar(
      partnerProfile?['avatar_data_url']?.toString(),
    );
    final next = relation.nextLevelThreshold;
    final progress = next == null || next <= 0
        ? 1.0
        : (relation.rivalry / next).clamp(0.0, 1.0).toDouble();

    return Column(
      children: [
        Container(
          key: const Key('enemy-hero'),
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: red, width: 1.5),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF260508),
                Color(0xFF08090D),
                Color(0xFF170407),
              ],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x66FF1024), blurRadius: 28),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'ENEMY ZONE',
                style: TextStyle(
                  color: red,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                  shadows: [
                    Shadow(color: Color(0xFFFF1327), blurRadius: 14),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _avatarCard(
                      image: _avatar(account.avatarDataUrl),
                      name: account.displayName,
                      userId: account.userId,
                    ),
                  ),
                  _enemyCore(),
                  Expanded(
                    child: _avatarCard(
                      image: partnerAvatar,
                      name: partnerName,
                      userId: partnerId,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Enemy Lv.${relation.level}',
                    style: const TextStyle(
                      color: red,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${relation.rivalry} rivalry',
                    style: const TextStyle(
                      color: Color(0xFFBCA4A7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  backgroundColor: const Color(0xFF25070A),
                  valueColor: const AlwaysStoppedAnimation<Color>(red),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                next == null
                    ? 'Top configured Enemy level reached'
                    : '${(next - relation.rivalry).clamp(0, next)} rivalry to next level',
                style: const TextStyle(
                  color: Color(0xFF8E777A),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RoyalPanel(
          accentColor: red,
          gradient: const LinearGradient(
            colors: [Color(0xFF1C0609), Color(0xFF090A0E)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enemy Gifts',
                style: TextStyle(
                  color: red,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Only Enemy-category gifts exchanged with your connected Enemy raise the Enemy level.',
                style: TextStyle(
                  color: Color(0xFF9E898C),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final gift in EnemyGiftCatalog.gifts.take(4))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          children: [
                            Text(
                              gift.emoji,
                              style: const TextStyle(fontSize: 25),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              gift.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('enemy-open-gifts'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GiftsScreen(
                        state: widget.state,
                        initialCategory: "Enemy's",
                      ),
                    ),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: red),
                  icon: const Icon(Icons.card_giftcard_rounded),
                  label: const Text("Open Enemy's Gifts"),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('enemy-remove'),
            onPressed: busy ? null : _disconnect,
            style: OutlinedButton.styleFrom(
              foregroundColor: red,
              side: const BorderSide(color: red),
            ),
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Remove Enemy'),
          ),
        ),
      ],
    );
  }

  Widget _pending(RemoteEnemy relation) {
    final account = widget.state.auth.current!;
    final incoming = relation.requestedBy != account.userId;
    final otherId =
        relation.userA == account.userId ? relation.userB : relation.userA;
    return RoyalPanel(
      key: const Key('enemy-pending'),
      accentColor: red,
      gradient: const LinearGradient(
        colors: [Color(0xFF260508), Color(0xFF090A0E)],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: red,
            size: 52,
            shadows: [Shadow(color: red, blurRadius: 15)],
          ),
          const SizedBox(height: 10),
          Text(
            incoming ? 'Enemy challenge received' : 'Enemy challenge sent',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'User ID ' + otherId,
            style: const TextStyle(color: Color(0xFF9F898C)),
          ),
          if (incoming) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _respond(false),
                    child: const Text('Refuse'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => _respond(true),
                    style: FilledButton.styleFrom(backgroundColor: red),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty() {
    final account = widget.state.auth.current!;
    final friends = widget.state.social.friendProfiles;
    return Column(
      children: [
        Container(
          key: const Key('enemy-empty-hero'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: red),
            gradient: const LinearGradient(
              colors: [Color(0xFF220508), black, Color(0xFF140306)],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _avatarCard(
                  image: _avatar(account.avatarDataUrl),
                  name: account.displayName,
                  userId: account.userId,
                ),
              ),
              _enemyCore(),
              const Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Color(0xFF15161C),
                      child: Icon(Icons.add_rounded, color: red, size: 40),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Add Enemy',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Choose a friend to challenge',
            style: TextStyle(
              color: red,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (loadingFriends)
          const Center(child: CircularProgressIndicator())
        else if (friends.isEmpty)
          const RoyalPanel(
            child: Text(
              'No mutual friends available yet.',
              style: TextStyle(color: RoyalPalette.muted),
            ),
          )
        else
          for (final friend in friends)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RoyalPanel(
                accentColor: red,
                gradient: const LinearGradient(
                  colors: [Color(0xFF190609), Color(0xFF090A0E)],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF1A1B20),
                      child: Text(
                        friend.name.isEmpty
                            ? '?'
                            : friend.name.characters.first.toUpperCase(),
                        style: const TextStyle(color: red),
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
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'ID ' + friend.id,
                            style: const TextStyle(
                              color: Color(0xFF8F7B7E),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: busy ? null : () => _requestEnemy(friend.id),
                      style: FilledButton.styleFrom(backgroundColor: red),
                      child: const Text('Challenge'),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.state.auth.current;
    if (account == null) {
      return const Scaffold(body: Center(child: Text('Login required')));
    }

    return Scaffold(
      key: const Key('enemy-screen'),
      backgroundColor: black,
      appBar: AppBar(
        backgroundColor: black,
        title: const Text(
          'Enemy',
          style: TextStyle(
            color: red,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _syncEnemy();
          await _syncFriends();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (enemy?.state == 'accepted')
              _accepted(enemy!)
            else if (enemy?.state == 'pending')
              _pending(enemy!)
            else
              _empty(),
          ],
        ),
      ),
    );
  }
}
