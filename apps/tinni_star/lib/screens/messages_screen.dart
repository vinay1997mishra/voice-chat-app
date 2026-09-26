import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../calls/call_service.dart';
import '../moderation/user_safety_menu.dart';
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
  Timer? refreshTimer;
  bool loading = true;
  bool sending = false;
  bool checkingIncoming = false;
  String? errorText;
  CallSession? incomingCall;

  bool get _isInbox => widget.targetUserId == null;
  String get _myUserId => widget.state.auth.current?.userId ?? '10000000';
  String get _targetUserId => widget.targetUserId ?? '';
  String get _targetName => widget.targetName ?? _targetUserId;
  bool get _isOfficial => _targetUserId == 'tinni-official';
  bool get _isFriend => widget.state.social.friends.contains(_targetUserId);

  @override
  void initState() {
    super.initState();
    _load();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshSilently(),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    controller.dispose();
    super.dispose();
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
      } else {
        await widget.state.social.loadConversation(
          authToken: account.authToken,
          myUserId: _myUserId,
          peerUserId: _targetUserId,
        );
      }
      await _checkIncoming();
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the last loaded inbox/conversation while reconnecting.
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

  Widget _buildInbox() {
    final threads = widget.state.social.messageThreads;
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
            child: loading && threads.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: threads.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 180),
                              Center(
                                child: Text(
                                  'No friend messages yet.',
                                  style: TextStyle(color: RoyalPalette.muted),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            key: const Key('message-thread-list'),
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                            itemCount: threads.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final thread = threads[index];
                              final last = thread.lastMessage;
                              final mine = last?.from == _myUserId;
                              final avatar =
                                  _avatarProvider(thread.avatarDataUrl);
                              return RoyalPanel(
                                key: Key(
                                  'message-thread-' + thread.userId,
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MessagesScreen(
                                        state: widget.state,
                                        targetUserId: thread.userId,
                                        targetName: thread.displayName,
                                        targetAvatarDataUrl:
                                            thread.avatarDataUrl,
                                      ),
                                    ),
                                  );
                                  if (mounted) await _refreshSilently();
                                },
                                gradient: FeaturePalette.glow(
                                  FeaturePalette.message,
                                ),
                                accentColor: FeaturePalette.message,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: avatar,
                                      backgroundColor: RoyalPalette.panel,
                                      child: avatar == null
                                          ? (thread.userId ==
                                                  'tinni-official'
                                              ? const Icon(
                                                  Icons.verified_rounded,
                                                  color: FeaturePalette.rank,
                                                )
                                              : Text(
                                                  thread.displayName.isEmpty
                                                      ? '?'
                                                      : thread.displayName
                                                          .characters.first
                                                          .toUpperCase(),
                                                  style: const TextStyle(
                                                    color:
                                                        FeaturePalette.message,
                                                    fontWeight:
                                                        FontWeight.w900,
                                                  ),
                                                ))
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  thread.displayName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color:
                                                        RoyalPalette.cream,
                                                    fontWeight:
                                                        FontWeight.w900,
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
                                            last == null
                                                ? 'Start a conversation'
                                                : (mine ? 'You: ' : '') +
                                                    last.text,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: thread.unreadCount > 0
                                                  ? RoyalPalette.cream
                                                  : RoyalPalette.muted,
                                              fontWeight:
                                                  thread.unreadCount > 0
                                                      ? FontWeight.w800
                                                      : FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (mine && last != null)
                                            Text(
                                              last.seenAt != null
                                                  ? 'Seen'
                                                  : 'Sent',
                                              style: TextStyle(
                                                color: last.seenAt != null
                                                    ? FeaturePalette.social
                                                    : RoyalPalette.muted,
                                                fontSize: 10,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (thread.unreadCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: FeaturePalette.message,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          thread.unreadCount > 99
                                              ? '99+'
                                              : thread.unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
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
                    child: Text(
                      _isOfficial
                          ? 'Verified official account'
                          : 'ID ' + _targetUserId,
                      style: const TextStyle(
                        color: RoyalPalette.muted,
                        fontSize: 11,
                      ),
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
                        final displayText = verificationNotice
                            ? message.text
                                .replaceFirst('[CALL_VERIFY]', '')
                                .trim()
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
                                Text(displayText),
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
