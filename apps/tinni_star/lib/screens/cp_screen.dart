import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../relationship/cp_service.dart';
import '../ui/royal_theme.dart';
import 'cp_disconnect_screen.dart';

class CpScreen extends StatefulWidget {
  const CpScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<CpScreen> createState() => _CpScreenState();
}

class _CpScreenState extends State<CpScreen> {
  bool loadingFriends = false;

  @override
  void initState() {
    super.initState();
    _syncFriends();
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
    try {
      widget.state.cp.request(from: account.userId, to: friendId);
      setState(() {});
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  void _respond(bool accept) {
    widget.state.cp.respond(accept: accept);
    setState(() {});
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
    widget.state.cp.addMemory(value);
    setState(() {});
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
        onRefresh: _syncFriends,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            if (cp != null) ...[
              RoyalPanel(
                gradient: FeaturePalette.glow(FeaturePalette.cp),
                accentColor: FeaturePalette.cp,
                child: Column(
                  children: [
                    const ShiningIcon(
                      icon: Icons.favorite_rounded,
                      color: FeaturePalette.cp,
                      size: 36,
                      boxSize: 64,
                      glow: 0.44,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CP Level ' + cp.level.toString(),
                      style: const TextStyle(
                        color: RoyalPalette.cream,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Intimacy ' + cp.intimacy.toString(),
                      style: const TextStyle(color: RoyalPalette.muted),
                    ),
                    Text(
                      'Partner ID ' +
                          (cp.userA == account?.userId ? cp.userB : cp.userA),
                      style: const TextStyle(color: RoyalPalette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.state.cp.addIntimacy(100);
                        setState(() {});
                      },
                      icon: const Icon(Icons.favorite_border_rounded),
                      label: const Text('+100 Intimacy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addMemory,
                      icon: const Icon(Icons.photo_album_rounded),
                      label: const Text('Memory'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CpDisconnectScreen(state: widget.state),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.heart_broken_rounded),
                label: const Text('CP Disconnect'),
              ),
              const SizedBox(height: 16),
              const GoldSectionTitle('Memories'),
              const SizedBox(height: 8),
              if (widget.state.cp.memories.isEmpty)
                const Text(
                  'No memories yet.',
                  style: TextStyle(color: RoyalPalette.muted),
                )
              else
                for (final memory in widget.state.cp.memories)
                  ListTile(
                    leading: const Icon(
                      Icons.favorite_rounded,
                      color: FeaturePalette.cp,
                    ),
                    title: Text(memory),
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
                            child: const Text('Request'),
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
