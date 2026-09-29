import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

import '../app/tinni_state.dart';
import '../calls/call_service.dart';
import '../infra/livekit_rtc.dart';
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

  Future<void> _startCall(SocialUser friend, {CallMedia media = CallMedia.voice}) async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final call = await widget.state.calls.startRemote(
        authToken: account.authToken,
        receiverId: friend.id,
        media: media,
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
                        IconButton(
                          key: Key('video-call-friend-' + friend.id),
                          tooltip: 'Video call',
                          onPressed: () => _startCall(friend, media: CallMedia.video),
                          icon: const ShiningIcon(
                            icon: Icons.videocam_rounded,
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
  static const MethodChannel _privacyChannel = MethodChannel('tinni.star/privacy');
  bool connecting = true;
  bool muted = false;
  bool ending = false;
  bool micPublished = false;
  bool cameraPublished = false;
  String? errorText;
  Map<String, dynamic>? privacyIncident;
  String? seenPrivacyIncidentId;
  late CallState remoteState;
  Timer? statusTimer;
  Timer? watermarkTimer;
  int watermarkStep = 0;
  EventsListener<RoomEvent>? rtcEvents;
  VideoTrack? remoteVideoTrack;
  VideoTrack? localVideoTrack;

  @override
  void initState() {
    super.initState();
    remoteState = widget.call.state;
    if (widget.call.media == CallMedia.video) {
      _privacyChannel.setMethodCallHandler(_handlePrivacyNativeEvent);
      _privacyChannel.invokeMethod<void>('setSecureScreen', <String, Object?>{'enabled': true});
    }
    _connect();
    if (widget.call.media == CallMedia.video) {
      watermarkTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) setState(() => watermarkStep = (watermarkStep + 1) % 6);
      });
    }
    statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollStatus(),
    );
  }

  Future<dynamic> _handlePrivacyNativeEvent(MethodCall call) async {
    if (call.method != 'captureAttempt' || widget.call.media != CallMedia.video) return;
    final account = widget.state.auth.current;
    if (account == null) return;
    final args = call.arguments is Map ? Map<String, dynamic>.from(call.arguments as Map) : <String, dynamic>{};
    final action = args['action']?.toString() ?? 'screenshot';
    try {
      await widget.state.calls.reportPrivacyIncident(
        authToken: account.authToken,
        callId: widget.call.id,
        action: action,
      );
      final rtc = widget.state.realtime.rtc;
      if (rtc is LiveKitRtcAdapter && cameraPublished) {
        await rtc.setCameraPublished(false);
        cameraPublished = false;
      }
    } catch (_) {}
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
        if (widget.call.media == CallMedia.video) {
          final rtc = widget.state.realtime.rtc;
          if (rtc is LiveKitRtcAdapter) {
            await rtc.setCameraPublished(true);
            cameraPublished = true;
            _bindVideoTracks(rtc);
          }
        }
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

  void _bindVideoTracks(LiveKitRtcAdapter rtc) {
    final room = rtc.room;
    if (room == null) return;
    rtcEvents?.dispose();
    rtcEvents = room.createListener()
      ..on<TrackSubscribedEvent>((_) => _refreshVideoTracks(rtc))
      ..on<TrackUnsubscribedEvent>((_) => _refreshVideoTracks(rtc))
      ..on<TrackPublishedEvent>((_) => _refreshVideoTracks(rtc))
      ..on<TrackUnpublishedEvent>((_) => _refreshVideoTracks(rtc))
      ..on<ParticipantDisconnectedEvent>((_) => _refreshVideoTracks(rtc));
    _refreshVideoTracks(rtc);
  }

  void _refreshVideoTracks(LiveKitRtcAdapter rtc) {
    final room = rtc.room;
    if (room == null || !mounted) return;
    VideoTrack? remote;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track is VideoTrack && !publication.muted) { remote = track; break; }
      }
      if (remote != null) break;
    }
    VideoTrack? local;
    final lp = room.localParticipant;
    if (lp != null) {
      for (final publication in lp.videoTrackPublications) {
        final track = publication.track;
        if (track is VideoTrack && !publication.muted) { local = track; break; }
      }
    }
    setState(() { remoteVideoTrack = remote; localVideoTrack = local; });
  }

  Future<void> _pollStatus() async {
    if (ending) return;
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final statusResult = await widget.state.calls.statusRemote(
        authToken: account.authToken,
        callId: widget.call.id,
      );
      final status = statusResult.call;
      final incident = statusResult.privacyIncident;
      if (!mounted) return;

      if (status.media == CallMedia.voice && cameraPublished) {
        final rtc = widget.state.realtime.rtc;
        if (rtc is LiveKitRtcAdapter) await rtc.setCameraPublished(false);
        cameraPublished = false;
      }
      if (incident != null) {
        final incidentId = incident['id']?.toString();
        final actorId = incident['actor_user_id']?.toString();
        if (incidentId != null && incidentId != seenPrivacyIncidentId && actorId != account.userId) {
          seenPrivacyIncidentId = incidentId;
          setState(() => privacyIncident = incident);
        }
      }

      if (status.state == CallState.connected && !micPublished) {
        await widget.state.realtime.setMic(true);
        micPublished = true;
        muted = false;
        if (widget.call.media == CallMedia.video && status.media == CallMedia.video && !cameraPublished) {
          final rtc = widget.state.realtime.rtc;
          if (rtc is LiveKitRtcAdapter) {
            await rtc.setCameraPublished(true);
            cameraPublished = true;
          }
        }
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
    watermarkTimer?.cancel();
    rtcEvents?.dispose();
    if (widget.call.media == CallMedia.video) {
      _privacyChannel.setMethodCallHandler(null);
      _privacyChannel.invokeMethod<void>('setSecureScreen', <String, Object?>{'enabled': false});
    }
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
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.call.media == CallMedia.video && privacyIncident == null)
              Positioned.fill(
                child: remoteVideoTrack != null
                    ? VideoTrackRenderer(remoteVideoTrack!)
                    : Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: Text(
                          connecting ? 'Connecting video…' : 'Waiting for peer video…',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
            if (widget.call.media == CallMedia.video && localVideoTrack != null && privacyIncident == null)
              Positioned(
                right: 16,
                top: 18,
                width: 112,
                height: 158,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: VideoTrackRenderer(localVideoTrack!),
                ),
              ),
            Center(
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
                              : widget.call.media == CallMedia.video
                                  ? 'Video call connected'
                                  : 'Voice call connected'),
                  style: TextStyle(
                    color: errorText == null
                        ? RoyalPalette.muted
                        : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.state.auth.current?.userId == widget.call.callerId)
                  Text(
                    'Cost ' +
                        widget.call.costCoinsPerMinute.toString() +
                        ' coins/min',
                    style: const TextStyle(
                      color: FeaturePalette.wallet,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else if (widget.call.receiverDiamondsPerMinute > 0)
                  Text(
                    'You receive ' +
                        widget.call.receiverDiamondsPerMinute.toString() +
                        ' diamonds/min',
                    style: const TextStyle(
                      color: FeaturePalette.gift,
                      fontWeight: FontWeight.w800,
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
            if (privacyIncident != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.82),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 72),
                        const SizedBox(height: 16),
                        const Text('PRIVACY ALERT', style: TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 14),
                        Text(
                          (privacyIncident!['actor_name']?.toString() ?? 'User') +
                              ' (ID ' + (privacyIncident!['actor_user_id']?.toString() ?? '') + ')',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          privacyIncident!['action']?.toString() == 'screen_recording'
                              ? 'Screen recording attempt detected'
                              : 'Screenshot attempt detected',
                          style: const TextStyle(color: Colors.white, fontSize: 17),
                        ),
                        const SizedBox(height: 10),
                        const Text('Video disabled by system • Call is now audio only', textAlign: TextAlign.center, style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.call.media == CallMedia.video)
              _VideoPrivacyWatermark(
                userId: widget.state.auth.current?.userId ?? '',
                callId: widget.call.id,
                step: watermarkStep,
              ),
          ],
        ),
      ),
    );
  }
}


class _VideoPrivacyWatermark extends StatelessWidget {
  const _VideoPrivacyWatermark({
    required this.userId,
    required this.callId,
    required this.step,
  });

  final String userId;
  final String callId;
  final int step;

  @override
  Widget build(BuildContext context) {
    final positions = <Alignment>[
      const Alignment(-0.78, -0.72),
      const Alignment(0.72, -0.48),
      const Alignment(-0.62, 0.02),
      const Alignment(0.62, 0.34),
      const Alignment(-0.70, 0.72),
      const Alignment(0.68, 0.78),
    ];
    final safeUser = userId.isEmpty ? 'private' : userId;
    final shortCall = callId.length <= 8 ? callId : callId.substring(callId.length - 8);
    final stamp = 'TINNI STAR • ID ' + safeUser + ' • ' + shortCall;
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: positions[step % positions.length],
            child: Transform.rotate(
              angle: -0.22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                ),
                child: Text(
                  stamp,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Transform.rotate(
              angle: -0.42,
              child: Text(
                'TINNI STAR • ' + safeUser,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.10),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
