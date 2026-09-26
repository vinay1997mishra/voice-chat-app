import 'dart:async';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../calls/call_service.dart';
import '../social/social.dart';
import '../ui/royal_theme.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? incomingTimer;
  bool loading = true;
  bool checkingIncoming = false;
  String? errorText;
  CallSession? incoming;

  @override
  void initState() {
    super.initState();
    _load();
    incomingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkIncoming(),
    );
  }

  @override
  void dispose() {
    incomingTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      await widget.state.social.syncFriends(account.authToken);
      await _checkIncoming();
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = error.toString().replaceFirst('Bad state: ', '');
      });
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
      if (mounted) setState(() => incoming = call);
    } catch (_) {
      // Do not interrupt the friend list for a temporary polling failure.
    } finally {
      checkingIncoming = false;
    }
  }

  Future<void> _startCall(SocialUser friend) async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final call = await widget.state.calls.startRemote(
        authToken: account.authToken,
        receiverId: friend.id,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(
            state: widget.state,
            call: call,
            peerName: friend.name,
          ),
        ),
      );
      await _checkIncoming();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _answer(bool accept) async {
    final account = widget.state.auth.current;
    final call = incoming;
    if (account == null || call == null) return;
    try {
      final result = await widget.state.calls.respondRemote(
        authToken: account.authToken,
        callId: call.id,
        accept: accept,
      );
      if (!mounted) return;
      if (!accept) {
        setState(() => incoming = null);
        return;
      }
      setState(() => incoming = null);
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

  @override
  Widget build(BuildContext context) {
    final friends = widget.state.social.friendProfiles;
    return Scaffold(
      key: const Key('call-screen'),
      appBar: AppBar(
        title: const Text(
          'Calls',
          style: TextStyle(
            color: FeaturePalette.social,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            if (incoming != null) ...[
              RoyalPanel(
                key: const Key('incoming-call-card'),
                gradient: FeaturePalette.glow(FeaturePalette.social),
                accentColor: FeaturePalette.social,
                child: Column(
                  children: [
                    const ShiningIcon(
                      icon: Icons.call_received_rounded,
                      color: FeaturePalette.social,
                      size: 28,
                      boxSize: 54,
                      glow: 0.40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (incoming!.callerName ?? incoming!.callerId) +
                          ' is calling',
                      style: const TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _answer(false),
                            icon: const Icon(Icons.call_end_rounded),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _answer(true),
                            icon: const Icon(Icons.call_rounded),
                            label: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            const GoldSectionTitle('Friends'),
            const SizedBox(height: 8),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (errorText != null)
              RoyalPanel(
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              )
            else if (friends.isEmpty)
              const RoyalPanel(
                child: Text(
                  'No mutual friends available. Only friends can be called.',
                  style: TextStyle(color: RoyalPalette.muted),
                ),
              )
            else
              for (final friend in friends)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RoyalPanel(
                    gradient: FeaturePalette.glow(FeaturePalette.social),
                    accentColor: FeaturePalette.social,
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
                        IconButton(
                          key: Key('call-friend-' + friend.id),
                          tooltip: 'Voice call',
                          onPressed: () => _startCall(friend),
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
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({
    super.key,
    required this.state,
    required this.call,
    required this.peerName,
  });

  final TinniState state;
  final CallSession call;
  final String peerName;

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  bool connecting = true;
  bool muted = false;
  bool ending = false;
  bool micPublished = false;
  String? errorText;
  late CallState remoteState;
  Timer? statusTimer;

  @override
  void initState() {
    super.initState();
    remoteState = widget.call.state;
    _connect();
    statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollStatus(),
    );
  }

  Future<void> _connect() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      if (widget.state.roomSession.hasRoom) {
        await widget.state.roomSession.close();
      }
      await widget.state.realtime.enterRoom(
        widget.call.roomId,
        account.userId,
        authToken: account.authToken,
      );
      if (remoteState == CallState.connected) {
        await widget.state.realtime.setMic(true);
        micPublished = true;
      } else {
        await widget.state.realtime.setMic(false);
        micPublished = false;
      }
      if (!mounted) return;
      setState(() {
        connecting = false;
        muted = false;
        errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        connecting = false;
        errorText = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _pollStatus() async {
    if (ending) return;
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final status = await widget.state.calls.statusRemote(
        authToken: account.authToken,
        callId: widget.call.id,
      );
      if (!mounted) return;

      if (status.state == CallState.connected && !micPublished) {
        await widget.state.realtime.setMic(true);
        micPublished = true;
        muted = false;
      }

      if (status.state == CallState.rejected ||
          status.state == CallState.ended) {
        statusTimer?.cancel();
        await widget.state.realtime.exitRoom();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status.state == CallState.rejected
                  ? 'Call rejected.'
                  : 'Call ended.',
            ),
          ),
        );
        Navigator.pop(context);
        return;
      }

      setState(() => remoteState = status.state);
    } catch (_) {
      // Keep the call UI alive through short status polling failures.
    }
  }

  Future<void> _toggleMute() async {
    try {
      await widget.state.realtime.setMic(muted);
      if (mounted) setState(() => muted = !muted);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _end() async {
    if (ending) return;
    final account = widget.state.auth.current;
    if (account == null) return;
    setState(() => ending = true);
    try {
      await widget.state.calls.endRemote(
        authToken: account.authToken,
        callId: widget.call.id,
      );
    } catch (_) {
      // Local RTC cleanup must still happen if the signaling request fails.
    }
    await widget.state.realtime.exitRoom();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    statusTimer?.cancel();
    if (!ending) {
      widget.state.realtime.exitRoom();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const Key('active-call-screen'),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Tinni Star Call'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ShiningIcon(
                  icon: Icons.person_rounded,
                  color: FeaturePalette.social,
                  size: 54,
                  boxSize: 92,
                  glow: 0.46,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.peerName,
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorText ??
                      (connecting
                          ? 'Connecting…'
                          : remoteState == CallState.ringing
                              ? 'Calling…'
                              : 'Voice call connected'),
                  style: TextStyle(
                    color: errorText == null
                        ? RoyalPalette.muted
                        : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: connecting ||
                              errorText != null ||
                              remoteState != CallState.connected
                          ? null
                          : _toggleMute,
                      icon: Icon(
                        muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      ),
                    ),
                    const SizedBox(width: 28),
                    IconButton.filled(
                      key: const Key('end-call-button'),
                      onPressed: _end,
                      icon: const Icon(Icons.call_end_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
