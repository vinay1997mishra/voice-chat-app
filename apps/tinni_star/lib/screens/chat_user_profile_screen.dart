import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';
import '../ui/stable_image_provider.dart';

class ChatUserProfileScreen extends StatefulWidget {
  const ChatUserProfileScreen({
    super.key, required this.state, required this.userId,
    required this.displayName, this.avatarDataUrl,
  });
  final TinniState state;
  final String userId;
  final String displayName;
  final String? avatarDataUrl;

  @override
  State<ChatUserProfileScreen> createState() => _ChatUserProfileScreenState();
}

class _ChatUserProfileScreenState extends State<ChatUserProfileScreen> {
  Map<String, dynamic>? _loaded;
  Map<String, dynamic> get _profile =>
      widget.state.social.liveProfiles[widget.userId] ?? _loaded ?? {
        'user_id': widget.userId, 'display_name': widget.displayName,
        'avatar_data_url': widget.avatarDataUrl,
      };

  @override
  void initState() {
    super.initState();
    widget.state.social.messageEvents.addListener(_changed);
    widget.state.social.retainProfile(widget.userId);
    _load();
  }

  void _changed() { if (mounted) setState(() {}); }

  Future<void> _load({bool force = false}) async {
    if (!force && widget.state.social.liveProfiles.containsKey(widget.userId)) return;
    final token = widget.state.auth.current?.authToken;
    if (token == null || widget.userId == 'tinni-official') return;
    try {
      final user = await widget.state.backend.searchUserById(token, widget.userId);
      if (mounted && user != null) setState(() => _loaded = user);
    } catch (_) { /* The chat's known profile stays visible offline. */ }
  }

  @override
  void dispose() {
    widget.state.social.messageEvents.removeListener(_changed);
    widget.state.social.releaseProfile(widget.userId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = profile['display_name']?.toString() ?? widget.displayName;
    final avatar = stableImageProvider(profile['avatar_data_url']?.toString());
    final country = [profile['flag_emoji'], profile['country_name'] ?? profile['country_code']]
        .where((value) => value != null && value.toString().isNotEmpty).join(' ');
    return Scaffold(
      key: Key('chat-user-profile-${widget.userId}'),
      appBar: AppBar(title: Text(name)),
      body: RefreshIndicator(onRefresh: () => _load(force: true), child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: CircleAvatar(radius: 54, backgroundImage: avatar,
            child: avatar == null ? const Icon(Icons.person_rounded, size: 54) : null)),
          const SizedBox(height: 16),
          Text(name, textAlign: TextAlign.center,
            style: const TextStyle(color: RoyalPalette.cream, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('ID ${widget.userId}', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (country.isNotEmpty) ListTile(title: const Text('Country'), subtitle: Text(country)),
          if (profile['age'] != null) ListTile(title: const Text('Age'), subtitle: Text('${profile['age']}')),
          if (profile['gender'] != null) ListTile(title: const Text('Gender'), subtitle: Text('${profile['gender']}')),
          if ((profile['signature']?.toString() ?? '').isNotEmpty)
            ListTile(title: const Text('Signature'), subtitle: Text(profile['signature'].toString())),
        ],
      )),
    );
  }
}
