import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../calls/call_service.dart';
import '../infra/app_backend_service.dart';
import '../moderation/user_safety_menu.dart';
import '../social/social.dart';
import '../ui/royal_theme.dart';
import 'call_screen.dart';
import 'call_verification_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.state,
    this.targetUserId,
    this.targetName,
    this.targetAvatarDataUrl,
  });

  final TinniState state;
  final String? targetUserId;
  final String? targetName;
  final String? targetAvatarDataUrl;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final controller = TextEditingController();
  bool loading = true;
  bool sending = false;
  bool checkingIncoming = false;
  String? errorText;
  CallSession? incomingCall;
  List<Map<String, dynamic>> targetIdentityTags =
      const <Map<String, dynamic>>[];
  List<RemoteNotification> activityNotifications =
      const <RemoteNotification>[];
  Map<String, String> roleInviteStatuses = const <String, String>{};
  final Set<String> respondingRoleInvites = <String>{};

  bool get _isInbox => widget.targetUserId == null;
  String get _myUserId => widget.state.auth.current?.userId ?? '10000000';
  String get _targetUserId => widget.targetUserId ?? '';
  String get _targetName => widget.targetName ?? _targetUserId;
  bool get _isOfficial => _targetUserId == 'tinni-official';
  bool get _isFriend => widget.state.social.friends.contains(_targetUserId);

  @override
  void initState() {
    super.initState();
    widget.state.social.messageEvents.addListener(_handleMessageEvent);
    final account = widget.state.auth.current;
    if (account != null) {
      widget.state.social.connectMessageEvents(account.authToken);
    }
    _load();
  }

  @override
  void dispose() {
    widget.state.social.messageEvents.removeListener(_handleMessageEvent);
    controller.dispose();
    super.dispose();
  }

  void _handleMessageEvent() {
    final event = widget.state.social.messageEvents.value;
    if (event == null || event['type'] != 'message_received') return;
    _refreshForIncomingMessage(event);
  }

  Future<void> _refreshForIncomingMessage(
    Map<String, dynamic> event,
  ) async {
    final account = widget.state.auth.current;
    if (account == null) return;
    final rawMessage = event['message'];
    final message = rawMessage is Map
        ? rawMessage.map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : const <String, dynamic>{};
    final from = message['from']?.toString() ?? '';
    final to = message['to']?.toString() ?? '';

    try {
      if (_isInbox) {
        await widget.state.social.syncInbox(account.authToken);
        await _loadActivity();
      } else if (from == _targetUserId || to == _targetUserId) {
        await widget.state.social.loadConversation(
          authToken: account.authToken,
          myUserId: _myUserId,
          peerUserId: _targetUserId,
        );
        await _loadInviteStatuses();
        final tagData = await widget.state.backend.userTagsAndMedals(
          account.authToken,
          _targetUserId,
        );
        final rawIdentityTags = tagData['identity_tags'];
        targetIdentityTags = rawIdentityTags is List
            ? rawIdentityTags
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false)
            : const <Map<String, dynamic>>[];
      } else {
        return;
      }
      if (mounted) setState(() {});
    } catch (_) {
      // The next message event, manual pull-to-refresh, or re-entry retries.
    }
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) {
      if (mounted) {
        setState(() {
          loading = false;
          errorText = 'Login session is required.';
        });
      }
      return;
    }

    try {
      if (_isInbox) {
        await widget.state.social.syncInbox(account.authToken);
        await _loadActivity();
      } else {
        await widget.state.social.syncBlocked(account.authToken);
        if (!_isOfficial && !_isFriend) {
          await widget.state.social.syncFriends(account.authToken);
        }
        await widget.state.social.loadConversation(
          authToken: account.authToken,
          myUserId: _myUserId,
          peerUserId: _targetUserId,
        );
      }
      if (!_isInbox) await _loadInviteStatuses();
      await _checkIncoming();
      if (mounted) {
        setState(() {
          loading = false;
          errorText = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          loading = false;
          errorText = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  Future<void> _refreshSilently() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      if (_isInbox) {
        await widget.state.social.syncInbox(account.authToken);
        await _loadActivity();
      } else {
        await widget.state.social.loadConversation(
          authToken: account.authToken,
          myUserId: _myUserId,
          peerUserId: _targetUserId,
        );
      }
      if (!_isInbox) await _loadInviteStatuses();
      await _checkIncoming();
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the last loaded inbox/conversation while reconnecting.
    }
  }

  Future<void> _loadActivity() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    final notices = await widget.state.backend.notifications(account.authToken);
    activityNotifications = notices
        .where((notice) => notice.type != 'message')
        .toList(growable: false);
  }

  Future<void> _loadInviteStatuses() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    final invites =
        await widget.state.backend.hierarchyInvites(account.authToken);
    roleInviteStatuses = <String, String>{
      for (final invite in invites)
        if ((invite['id']?.toString() ?? '').isNotEmpty)
          invite['id'].toString():
              (invite['status']?.toString() ?? 'pending'),
    };
  }

  Future<void> _respondRoleInvite(String inviteId, bool accept) async {
    final account = widget.state.auth.current;
    if (account == null || respondingRoleInvites.contains(inviteId)) return;
    setState(() => respondingRoleInvites.add(inviteId));
    try {
      await widget.state.backend.respondHierarchyInvite(
        account.authToken,
        inviteId: inviteId,
        accept: accept,
      );
      final wallet = await widget.state.backend.wallet(account.authToken);
      widget.state.wallet.applyRemote(wallet);
      await _loadInviteStatuses();
      await widget.state.social.loadConversation(
        authToken: account.authToken,
        myUserId: _myUserId,
        peerUserId: _targetUserId,
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Role invitation accepted.'
                : 'Role invitation rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => respondingRoleInvites.remove(inviteId));
      }
    }
  }

  Future<void> _checkIncoming() async {
    if (checkingIncoming) return;
    final account = widget.state.auth.current;
    if (account == null) return;
    checkingIncoming = true;
    try {
      final call = await widget.state.calls.incomingRemote(
        authToken: account.authToken,
      );
      if (mounted) setState(() => incomingCall = call);
    } catch (_) {
      // Temporary call polling failures should not block messaging.
    } finally {
      checkingIncoming = false;
    }
  }

  Future<void> _answerIncoming(bool accept) async {
    final account = widget.state.auth.current;
    final call = incomingCall;
    if (account == null || call == null) return;
    try {
      final result = await widget.state.calls.respondRemote(
        authToken: account.authToken,
        callId: call.id,
        accept: accept,
      );
      if (!mounted) return;
      if (!accept) {
        setState(() => incomingCall = null);
        return;
      }
      setState(() => incomingCall = null);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(
            state: widget.state,
            call: result,
            peerName: result.callerName ?? result.callerId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _startCall({
    required String userId,
    required String displayName,
  }) async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final call = await widget.state.calls.startRemote(
        authToken: account.authToken,
        receiverId: userId,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(
            state: widget.state,
            call: call,
            peerName: displayName,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _startRandomCall() async {
    final account = widget.state.auth.current;
    if (account == null) return;

    final gender = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Random Call',
                style: TextStyle(
                  color: RoyalPalette.cream,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '500,000 coins per minute. Calls go only to available Verified IDs. Best ranked available IDs are tried first, with rotation for newly verified IDs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RoyalPalette.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('random-call-girls'),
                      onPressed: () => Navigator.pop(sheetContext, 'female'),
                      icon: const Icon(Icons.woman_rounded),
                      label: const Text('Girls'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('random-call-boys'),
                      onPressed: () => Navigator.pop(sheetContext, 'male'),
                      icon: const Icon(Icons.man_rounded),
                      label: const Text('Boys'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (gender == null || !mounted) return;
    try {
      final call = await widget.state.calls.startRandomRemote(
        authToken: account.authToken,
        gender: gender,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(
            state: widget.state,
            call: call,
            peerName: call.receiverName ?? 'Random Call',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _openCallVerification() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallVerificationScreen(state: widget.state),
      ),
    );
    if (mounted) await _refreshSilently();
  }

  Future<void> send() async {
    if (sending || _isInbox) return;
    final account = widget.state.auth.current;
    final value = controller.text.trim();
    if (account == null || value.isEmpty) return;

    setState(() => sending = true);
    try {
      await widget.state.social.sendDirectMessageRemote(
        authToken: account.authToken,
        from: _myUserId,
        to: _targetUserId,
        text: value,
      );
      controller.clear();
      if (mounted) {
        setState(() {
          errorText = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          errorText = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  ImageProvider? _avatarProvider(String? rawAvatar) {
    if (rawAvatar == null || !rawAvatar.startsWith('data:image/')) {
      return null;
    }
    try {
      return MemoryImage(base64Decode(rawAvatar.split(',').last));
    } catch (_) {
      return null;
    }
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    final local = value.toLocal();
    if (now.year == local.year &&
        now.month == local.month &&
        now.day == local.day) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return hour + ':' + minute;
    }
    return local.day.toString() + '/' + local.month.toString();
  }

  Widget _incomingCallCard() {
    final call = incomingCall;
    if (call == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: RoyalPanel(
        key: const Key('message-incoming-call'),
        gradient: FeaturePalette.glow(FeaturePalette.social),
        accentColor: FeaturePalette.social,
        child: Column(
          children: [
            Row(
              children: [
                const ShiningIcon(
                  icon: Icons.call_received_rounded,
                  color: FeaturePalette.social,
                  size: 22,
                  boxSize: 42,
                  glow: 0.38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (call.callerName ?? call.callerId) + ' is calling',
                    style: const TextStyle(
                      color: RoyalPalette.cream,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _answerIncoming(false),
                    icon: const Icon(Icons.call_end_rounded),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _answerIncoming(true),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageThreadTile(MessageThread thread) {
    final last = thread.lastMessage;
    final mine = last?.from == _myUserId;
    final avatar = _avatarProvider(thread.avatarDataUrl);
    final isOfficial = thread.userId == 'tinni-official';
    final isActivity = thread.userId == 'tinni-activity';
    final subtitle = last == null
        ? (isOfficial
            ? 'Official notices from Tinni Star'
            : isActivity
                ? 'Rewards, events and account activity'
                : 'Start a conversation')
        : (mine ? 'You: ' : '') +
            last.text.replaceFirst(
              RegExp(r'^\[ROLE_INVITE:[^\]]+\]\s*'),
              '',
            );

    return RoyalPanel(
      key: Key('message-thread-' + thread.userId),
      onTap: () async {
        if (isActivity) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ActivityInboxScreen(state: widget.state),
            ),
          );
          if (!mounted) return;
          await _loadActivity();
          setState(() {});
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessagesScreen(
              state: widget.state,
              targetUserId: thread.userId,
              targetName: thread.displayName,
              targetAvatarDataUrl: thread.avatarDataUrl,
            ),
          ),
        );
        if (!mounted) return;
        await _refreshSilently();
      },
      gradient: FeaturePalette.glow(
        isOfficial
            ? FeaturePalette.rank
            : isActivity
                ? FeaturePalette.social
                : FeaturePalette.message,
      ),
      accentColor: isOfficial
          ? FeaturePalette.rank
          : isActivity
              ? FeaturePalette.social
              : FeaturePalette.message,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: avatar,
            backgroundColor: RoyalPalette.panel,
            child: avatar == null
                ? Icon(
                    isOfficial
                        ? Icons.verified_rounded
                        : isActivity
                            ? Icons.notifications_active_rounded
                            : Icons.person_rounded,
                    color: isOfficial
                        ? FeaturePalette.rank
                        : isActivity
                            ? FeaturePalette.social
                            : FeaturePalette.message,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RoyalPalette.cream,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _timeLabel(last?.createdAt),
                      style: const TextStyle(
                        color: RoyalPalette.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: thread.unreadCount > 0
                        ? RoyalPalette.cream
                        : RoyalPalette.muted,
                    fontWeight: thread.unreadCount > 0
                        ? FontWeight.w800
                        : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (thread.unreadCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isOfficial
                    ? FeaturePalette.rank
                    : isActivity
                        ? FeaturePalette.social
                        : FeaturePalette.message,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                thread.unreadCount > 99 ? '99+' : thread.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInbox() {
    final threads = widget.state.social.messageThreads;
    MessageThread? official;
    final normal = <MessageThread>[];
    for (final thread in threads) {
      if (thread.userId == 'tinni-official') {
        official = thread;
      } else {
        normal.add(thread);
      }
    }
    official ??= const MessageThread(
      userId: 'tinni-official',
      displayName: 'Tinni Official',
      isFriend: false,
    );
    final latest =
        activityNotifications.isEmpty ? null : activityNotifications.first;
    final activity = MessageThread(
      userId: 'tinni-activity',
      displayName: 'Activity',
      isFriend: false,
      lastMessage: latest == null
          ? null
          : ChatMessage(
              from: 'tinni-activity',
              to: _myUserId,
              text: latest.title + ': ' + latest.message,
              createdAt: DateTime.fromMillisecondsSinceEpoch(latest.createdAt),
            ),
      unreadCount: activityNotifications.where((item) => !item.read).length,
    );
    final visible = <MessageThread>[official, activity, ...normal];

    return Scaffold(
      key: const Key('messages-inbox'),
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: FeaturePalette.message,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('messages-random-call-button'),
            tooltip: 'Random Call',
            onPressed: _startRandomCall,
            icon: const ShiningIcon(
              icon: Icons.call_rounded,
              color: FeaturePalette.social,
              size: 20,
              boxSize: 38,
              glow: 0.34,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _incomingCallCard(),
          if (errorText != null && threads.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                errorText!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Expanded(
            child: loading && threads.isEmpty && activityNotifications.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      key: const Key('message-thread-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, index) =>
                          _messageThreadTile(visible[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation() {
    final messages = widget.state.social.directMessages.where((message) {
      return (message.from == _myUserId && message.to == _targetUserId) ||
          (message.from == _targetUserId && message.to == _myUserId);
    }).toList();

    final avatar = _avatarProvider(widget.targetAvatarDataUrl);

    return Scaffold(
      key: const Key('message-conversation'),
      appBar: AppBar(
        title: Text(
          _targetName,
          style: const TextStyle(
            color: FeaturePalette.message,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (_isFriend)
            IconButton(
              key: const Key('message-conversation-call'),
              tooltip: 'Call',
              onPressed: () => _startCall(
                userId: _targetUserId,
                displayName: _targetName,
              ),
              icon: const ShiningIcon(
                icon: Icons.call_rounded,
                color: FeaturePalette.social,
                size: 20,
                boxSize: 38,
                glow: 0.34,
              ),
            ),
          if (!_isOfficial)
            UserSafetyMenuButton(
              state: widget.state,
              targetUserId: _targetUserId,
              targetDisplayName: _targetName,
            ),
        ],
      ),
      body: Column(
        children: [
          _incomingCallCard(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RoyalPanel(
              gradient: FeaturePalette.glow(FeaturePalette.message),
              accentColor: FeaturePalette.message,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: RoyalPalette.panel,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? (_isOfficial
                            ? const Icon(
                                Icons.verified_rounded,
                                color: FeaturePalette.rank,
                              )
                            : Text(
                                _targetName.isEmpty
                                    ? '?'
                                    : _targetName.characters.first
                                        .toUpperCase(),
                                style: const TextStyle(
                                  color: FeaturePalette.message,
                                  fontWeight: FontWeight.w900,
                                ),
                              ))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOfficial
                              ? 'Verified official account'
                              : 'ID ' + _targetUserId,
                          style: const TextStyle(
                            color: RoyalPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                        if (!_isOfficial && targetIdentityTags.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            key: const Key('message-identity-tags'),
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              for (final tag in targetIdentityTags.take(4))
                                _MessageIdentityTag(tag: tag),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_isFriend)
                    const Text(
                      'Friend',
                      style: TextStyle(
                        color: FeaturePalette.social,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                errorText!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ),
          Expanded(
            child: loading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (_, index) {
                        final message = messages[index];
                        final mine = message.from == _myUserId;
                        final verificationNotice = _isOfficial &&
                            !mine &&
                            message.text.startsWith('[CALL_VERIFY]');
                        final roleInviteMatch = !mine
                            ? RegExp(
                                r'^\[ROLE_INVITE:([^:\]]+):(host|agency)\]\s*(.*)$',
                              ).firstMatch(message.text)
                            : null;
                        final inviteId = roleInviteMatch?.group(1) ?? '';
                        final inviteRole = roleInviteMatch?.group(2) ?? '';
                        final inviteStatus =
                            roleInviteStatuses[inviteId] ?? 'pending';
                        final displayText = verificationNotice
                            ? message.text
                                .replaceFirst('[CALL_VERIFY]', '')
                                .trim()
                            : roleInviteMatch != null
                                ? (roleInviteMatch.group(3) ?? '').trim()
                                : message.text;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 300),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: FeaturePalette.glow(
                                mine
                                    ? FeaturePalette.social
                                    : FeaturePalette.message,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (mine
                                        ? FeaturePalette.social
                                        : FeaturePalette.message)
                                    .withValues(alpha: 0.70),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (mine
                                          ? FeaturePalette.social
                                          : FeaturePalette.message)
                                      .withValues(alpha: 0.18),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: mine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  displayText,
                                  key: Key(
                                    'message-selectable-' +
                                        (message.id ?? index.toString()),
                                  ),
                                ),
                                if (verificationNotice) ...[
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    key: Key(
                                      'official-call-verify-' +
                                          (message.id ?? index.toString()),
                                    ),
                                    onPressed: _openCallVerification,
                                    icon: const Icon(
                                      Icons.verified_user_rounded,
                                    ),
                                    label: const Text('Verify Call ID'),
                                  ),
                                ],
                                if (roleInviteMatch != null &&
                                    message.to == _myUserId) ...[
                                  const SizedBox(height: 8),
                                  if (inviteStatus == 'pending')
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        OutlinedButton(
                                          key: Key(
                                            'role-invite-reject-' + inviteId,
                                          ),
                                          onPressed: respondingRoleInvites
                                                  .contains(inviteId)
                                              ? null
                                              : () => _respondRoleInvite(
                                                    inviteId,
                                                    false,
                                                  ),
                                          child: const Text('Reject'),
                                        ),
                                        FilledButton(
                                          key: Key(
                                            'role-invite-accept-' + inviteId,
                                          ),
                                          onPressed: respondingRoleInvites
                                                  .contains(inviteId)
                                              ? null
                                              : () => _respondRoleInvite(
                                                    inviteId,
                                                    true,
                                                  ),
                                          child: Text(
                                            'Accept ' +
                                                (inviteRole == 'host'
                                                    ? 'Host'
                                                    : 'Agency'),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      inviteStatus == 'accepted'
                                          ? 'Accepted'
                                          : 'Rejected',
                                      style: TextStyle(
                                        color: inviteStatus == 'accepted'
                                            ? FeaturePalette.social
                                            : Colors.redAccent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                ],
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _timeLabel(message.createdAt),
                                      style: const TextStyle(
                                        color: RoyalPalette.muted,
                                        fontSize: 9,
                                      ),
                                    ),
                                    if (mine) ...[
                                      const SizedBox(width: 5),
                                      Text(
                                        message.seenAt != null
                                            ? 'Seen'
                                            : 'Sent',
                                        key: Key(
                                          'message-status-' +
                                              (message.id ??
                                                  index.toString()),
                                        ),
                                        style: TextStyle(
                                          color: message.seenAt != null
                                              ? FeaturePalette.social
                                              : RoyalPalette.muted,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RoyalPalette.nearBlack,
                border: Border(
                  top: BorderSide(
                    color: (_isOfficial
                            ? FeaturePalette.rank
                            : FeaturePalette.social)
                        .withValues(alpha: 0.72),
                  ),
                ),
              ),
              child: _isOfficial
                  ? const Row(
                      children: [
                        ShiningIcon(
                          icon: Icons.verified_rounded,
                          color: FeaturePalette.rank,
                          size: 18,
                          boxSize: 34,
                          glow: 0.34,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Messages from Tinni Official are official platform notices.',
                            style: TextStyle(
                              color: RoyalPalette.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('message-input'),
                            controller: controller,
                            onSubmitted: (_) => send(),
                            decoration: InputDecoration(
                              hintText: 'Message ' + _targetName + '…',
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('message-send-button'),
                          onPressed: sending ? null : send,
                          icon: sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const ShiningIcon(
                                  icon: Icons.send_rounded,
                                  color: FeaturePalette.message,
                                  size: 20,
                                  boxSize: 36,
                                  glow: 0.34,
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

  @override
  Widget build(BuildContext context) {
    return _isInbox ? _buildInbox() : _buildConversation();
  }
}



class _ActivityInboxScreen extends StatefulWidget {
  const _ActivityInboxScreen({required this.state});

  final TinniState state;

  @override
  State<_ActivityInboxScreen> createState() => _ActivityInboxScreenState();
}

class _ActivityInboxScreenState extends State<_ActivityInboxScreen> {
  bool loading = true;
  String? error;
  List<RemoteNotification> notices = const <RemoteNotification>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final values = await widget.state.backend.notifications(
        account.authToken,
      );
      if (!mounted) return;
      setState(() {
        notices = values
            .where((notice) => notice.type != 'message')
            .toList(growable: false);
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

  Future<void> _markRead(RemoteNotification notice) async {
    if (notice.read) return;
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      await widget.state.backend.markNotificationRead(
        account.authToken,
        notice.id,
      );
      await _load();
    } catch (_) {}
  }

  String _date(RemoteNotification notice) {
    if (notice.createdAt <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(
      notice.createdAt,
    ).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('activity-inbox'),
      appBar: AppBar(
        title: const Text(
          'Activity',
          style: TextStyle(
            color: FeaturePalette.social,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  if (notices.isEmpty)
                    const RoyalPanel(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No activity yet.',
                          style: TextStyle(color: RoyalPalette.muted),
                        ),
                      ),
                    ),
                  for (final notice in notices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RoyalPanel(
                        key: Key('activity-notice-' + notice.id),
                        onTap: () => _markRead(notice),
                        gradient: FeaturePalette.glow(
                          notice.read
                              ? RoyalPalette.muted
                              : FeaturePalette.social,
                        ),
                        accentColor: notice.read
                            ? RoyalPalette.muted
                            : FeaturePalette.social,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  notice.read
                                      ? Icons.notifications_none_rounded
                                      : Icons.notifications_active_rounded,
                                  color: FeaturePalette.social,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    notice.title,
                                    style: const TextStyle(
                                      color: RoyalPalette.cream,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (!notice.read)
                                  const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: FeaturePalette.social,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notice.message,
                              style: const TextStyle(
                                color: RoyalPalette.cream,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _date(notice),
                              style: const TextStyle(
                                color: RoyalPalette.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _MessageIdentityTag extends StatelessWidget {
  const _MessageIdentityTag({required this.tag});

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
    final label = (tag['designation']?.toString().trim().isNotEmpty ?? false)
        ? tag['designation']!.toString().trim()
        : (tag['name']?.toString() ?? 'Tag');
    if (kind == 'v_official') {
      final bg = _hex(tag['background_color']?.toString(), const Color(0xFF69C9FF));
      return Container(
        padding: const EdgeInsets.fromLTRB(3, 2, 7, 2),
        decoration: BoxDecoration(
          color: const Color(0xFF12100C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RoyalPalette.deepGold),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
                border: Border.all(color: RoyalPalette.gold, width: 1.5),
              ),
              child: const Text(
                'V',
                style: TextStyle(
                  color: Color(0xFFE4E7ED),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: RoyalPalette.gold,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }
    final color = _hex(tag['color']?.toString(), RoyalPalette.gold);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .75)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: kind == 'auto_role' ? RoyalPalette.gold : color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
