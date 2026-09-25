import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../moderation/user_safety_menu.dart';
import '../ui/royal_theme.dart';

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
  String? errorText;

  String get _myUserId => widget.state.auth.current?.userId ?? '10000000';
  String get _targetUserId => widget.targetUserId ?? 'tinni-official';
  String get _targetName => widget.targetName ?? 'Tinni Official';
  bool get _isOfficial => _targetUserId == 'tinni-official';

  @override
  void initState() {
    super.initState();
    _load();
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
      await widget.state.social.syncBlocked(account.authToken);
      await widget.state.social.loadConversation(
        authToken: account.authToken,
        myUserId: _myUserId,
        peerUserId: _targetUserId,
      );
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (sending) return;
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

  @override
  Widget build(BuildContext context) {
    final messages = widget.state.social.directMessages.where((message) {
      return (message.from == _myUserId && message.to == _targetUserId) ||
          (message.from == _targetUserId && message.to == _myUserId);
    }).toList();

    ImageProvider? avatar;
    final rawAvatar = widget.targetAvatarDataUrl;
    if (rawAvatar != null && rawAvatar.startsWith('data:image/')) {
      try {
        avatar = MemoryImage(base64Decode(rawAvatar.split(',').last));
      } catch (_) {
        avatar = null;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Message',
          style: TextStyle(
            color: RoyalPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RoyalPanel(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: RoyalPalette.deepGold,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? (_isOfficial
                            ? const Icon(
                                Icons.verified_rounded,
                                color: Colors.black,
                              )
                            : Text(
                                _targetName.isEmpty
                                    ? '?'
                                    : _targetName.characters.first.toUpperCase(),
                                style: const TextStyle(color: Colors.black),
                              ))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _targetName,
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          _isOfficial
                              ? 'Verified official account'
                              : 'ID $_targetUserId',
                          style: const TextStyle(
                            color: RoyalPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.circle, color: Colors.green, size: 10),
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
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (_, index) {
                        final message = messages[index];
                        final mine = message.from == _myUserId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: RoyalPalette.panel2,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: RoyalPalette.deepGold),
                            ),
                            child: Text(message.text),
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
              decoration: const BoxDecoration(
                color: RoyalPalette.nearBlack,
                border: Border(top: BorderSide(color: RoyalPalette.deepGold)),
              ),
              child: _isOfficial
                  ? const Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: RoyalPalette.gold,
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
                            controller: controller,
                            onSubmitted: (_) {
                              send();
                            },
                            decoration: InputDecoration(
                              hintText: 'Message $_targetName…',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: sending
                              ? null
                              : () {
                                  send();
                                },
                          icon: sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: RoyalPalette.gold,
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
