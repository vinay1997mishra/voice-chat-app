import 'dart:async';
import '../infra/request_budget.dart';

import 'package:flutter/foundation.dart';

import '../background/room_foreground_service.dart';
import '../background/room_permission_bridge.dart';
import '../core/function_pack.dart';
import '../discovery/discovery_service.dart';
import '../infra/realtime.dart';
import 'room_controller.dart';
import 'room_models.dart';
import 'room_presence_service.dart';

class ActiveRoomSession extends ChangeNotifier {
  ActiveRoomSession({
    required this.runtime,
    required this.realtime,
    required this.foregroundService,
    required this.permissions,
    required this.presence,
    this.enablePresenceFallbackTimer = true,
    this.nowProvider = DateTime.now,
    this.familyTagProvider,
    this.hostTagProvider,
    this.agencyNameProvider,
    this.equippedFrameIdProvider,
    this.equippedEntryIdProvider,
    this.equippedProfileCardIdProvider,
    this.onRoomClosed,
    this.onSeatForcedDown,
  });

  final FunctionPackRuntime runtime;
  final RealtimeCoordinator realtime;
  final RoomForegroundServiceBridge foregroundService;
  final RoomPermissionBridge permissions;
  final RoomPresenceService presence;
  final bool enablePresenceFallbackTimer;
  final DateTime Function() nowProvider;
  final String? Function()? familyTagProvider;
  final String? Function()? hostTagProvider;
  final String? Function()? agencyNameProvider;
  final String? Function()? equippedFrameIdProvider;
  final String? Function()? equippedEntryIdProvider;
  final String? Function()? equippedProfileCardIdProvider;
  final Future<void> Function()? onRoomClosed;
  final Future<void> Function()? onSeatForcedDown;

  RoomSummary? room;
  RoomController? controller;
  bool minimized = false;
  bool connecting = false;
  bool connected = false;
  String? connectionError;

  Timer? _presenceTimer;
  Timer? _voiceTimer;
  Timer? _fallbackStateTimer;
  bool _voicePermissionGranted = false;
  bool _voiceAttemptRunning = false;
  bool _micActionRunning = false;
  int _voiceEpoch = 0;
  int _voiceRetrySeconds = 2;
  DateTime? _nextVoiceAttempt;
  Timer? _presenceRecoveryTimer;
  bool _presenceRecoveryRunning = false;
  bool _fallbackRefreshRunning = false;
  DateTime? _nextFallbackPoll;
  int _fallbackFailures = 0;
  int _presenceRecoveryDelaySeconds = 2;
  String? _activeAuthToken;
  String? _activeUserId;
  bool _liveSyncInitialized = false;
  int? _lastSyncedSeatIndex;
  bool? _lastSyncedMicEnabled;
  bool _roomSoundEnabled = true;
  bool _moderationForcedMicOff = false;
  final Set<String> _seenLuckyNumberEventIds = <String>{};
  final Set<String> _seenRoomChatEventIds = <String>{};
  final Set<String> _seenRoomJoinKeys = <String>{};
  bool _roomJoinSnapshotInitialized = false;
  bool _disposed = false;

  List<RoomPresenceMember> get liveMembers =>
      List<RoomPresenceMember>.unmodifiable(presence.members);

  ValueListenable<Map<String, double>> get speakingLevelsListenable =>
      realtime.rtc.speakingLevelsListenable;

  Future<Map<String, dynamic>> sendGift({
    required String roomId,
    required String authToken,
    required String giftId,
    required String giftName,
    required int quantity,
    required int unitPrice,
    required List<String> receiverIds,
    String? luckySessionId,
  }) => presence.sendGift(
        roomId: roomId,
        authToken: authToken,
        giftId: giftId,
        giftName: giftName,
        quantity: quantity,
        unitPrice: unitPrice,
        receiverIds: receiverIds,
        luckySessionId: luckySessionId,
      );

  Future<Map<String, dynamic>> luckyGiftState({
    required String authToken,
  }) => presence.luckyGiftState(authToken: authToken);

  Future<List<Map<String, dynamic>>> roomGiftFeed({
    required String roomId,
    required String authToken,
  }) => presence.roomGiftFeed(
        roomId: roomId,
        authToken: authToken,
      );

  bool get hasRoom => room != null && controller != null;
  bool get moderationMicMuted => presence.selfMicMuted;
  bool get moderationChatBanned => presence.selfChatBanned;
  RoomSeatInvite? get pendingSeatInvite => presence.pendingSeatInvite;
  RoomGiftVisualEvent? get latestGiftVisualEvent =>
      presence.latestGiftVisualEvent;
  List<RoomSeatRequest> get seatRequests =>
      List<RoomSeatRequest>.unmodifiable(presence.seatRequests);

  String? get _familyTag => familyTagProvider?.call();
  String? get _hostTag => hostTagProvider?.call();
  String? get _agencyName => agencyNameProvider?.call();
  String? get _equippedFrameId => equippedFrameIdProvider?.call();
  String? get _equippedEntryId => equippedEntryIdProvider?.call();
  String? get _equippedProfileCardId => equippedProfileCardIdProvider?.call();

  bool get _micEnabledForPresence {
    final roomController = controller;
    final seatIndex = roomController?.mySeat;
    if (roomController == null || seatIndex == null) return false;
    final seatMuted = seatIndex >= 0 &&
        seatIndex < roomController.seats.length &&
        roomController.seats[seatIndex].roomMuted;
    return connected && realtime.rtc.state == RtcConnectionState.joined && realtime.rtc.publishingMic &&
        roomController.micState == MicState.live &&
        !roomController.selfMuted &&
        !presence.selfMicMuted &&
        !seatMuted;
  }

  Future<void> open(
    RoomSummary nextRoom, {
    required String userId,
    required String authToken,
  }) async {
    final sameRoom = room?.id == nextRoom.id && controller != null;

    // A previous voice/permission failure must never leave a dead RoomScreen
    // that only resumes a controller with no authenticated backend session.
    if (sameRoom && _activeAuthToken == authToken && _activeUserId == userId) {
      minimized = false;
      if (!connected) await retryVoice();
      notifyListeners();
      return;
    }

    if (hasRoom) {
      await close();
    }

    room = nextRoom;
    _roomSoundEnabled = true;
    _moderationForcedMicOff = false;
    _seenLuckyNumberEventIds.clear();
    _seenRoomChatEventIds.clear();
    _seenRoomJoinKeys.clear();
    _roomJoinSnapshotInitialized = false;
    controller = RoomController(
      runtime: runtime,
      seatCountOverride: nextRoom.seatCount,
    )..addListener(_onRoomChanged);
    minimized = false;
    connecting = true;
    connected = false;
    connectionError = null;

    // Room controls/presence are authenticated independently from microphone
    // permission and LiveKit. Keep these credentials active even if voice is
    // unavailable so seats, chat, gifts and moderation continue to work.
    _activeAuthToken = authToken;
    _activeUserId = userId;
    notifyListeners();

    // Presence and voice use separate transports and recover independently.
    final presenceStart = _startPresence();
    _startRecoveryMonitors();
    await retryVoice();
    await presenceStart;
  }

  Future<void> retryVoice({bool requestPermission = true}) async {
    if (_disposed || _voiceAttemptRunning) return;
    final roomId = room?.id;
    final userId = _activeUserId;
    final token = _activeAuthToken;
    if (roomId == null || userId == null || token == null) return;
    final epoch = ++_voiceEpoch;
    _voiceAttemptRunning = true;
    connecting = true;
    notifyListeners();
    try {
      _voicePermissionGranted = requestPermission
          ? await permissions.requestVoiceRoomPermissions()
          : await permissions.hasVoiceRoomPermissions();
      if (epoch != _voiceEpoch || room?.id != roomId) return;
      if (!_voicePermissionGranted) {
        connected = false;
        connectionError = 'Allow microphone access to use voice.';
        return;
      }
      // Notification/Bluetooth refusal and foreground-service errors must not
      // prevent ordinary foreground microphone audio.
      try { await foregroundService.start(); } catch (_) {}
      await realtime.enterRoom(roomId, userId, authToken: token);
      if (epoch != _voiceEpoch || room?.id != roomId) {
        await realtime.exitRoom();
        return;
      }
      connected = true;
      connectionError = null;
      _voiceRetrySeconds = 2;
      _nextVoiceAttempt = null;
      await realtime.setRemoteAudioEnabled(_roomSoundEnabled);
      await setMicFromController();
    } catch (error) {
      if (epoch != _voiceEpoch) return;
      connected = realtime.rtc.state == RtcConnectionState.joined;
      connectionError = (connected ? 'Microphone update failed: ' : 'Voice connection failed: ') +
          error.toString().replaceFirst('Bad state: ', '');
      _nextVoiceAttempt = nowProvider().add(Duration(seconds: _voiceRetrySeconds));
      _voiceRetrySeconds = (_voiceRetrySeconds * 2).clamp(2, 120).toInt();
    } finally {
      _voiceAttemptRunning = false;
      if (epoch == _voiceEpoch) {
        connecting = false;
        notifyListeners();
      }
    }
  }

  void _startRecoveryMonitors() {
    if (!enablePresenceFallbackTimer) return;
    _voiceTimer?.cancel();
    _fallbackStateTimer?.cancel();
    _voiceTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_disposed || room == null || connecting) return;
      final voiceState = realtime.rtc.state;
      if (voiceState == RtcConnectionState.joined) {
        if (!connected) {
          connected = true;
          connectionError = null;
          try {
            await realtime.setRemoteAudioEnabled(_roomSoundEnabled);
            await setMicFromController();
          } catch (error) { connectionError = error.toString(); }
          notifyListeners();
        }
        return;
      }
      if (connected) {
        connected = false;
        connectionError = 'Voice connection lost. Retrying…';
        _syncLiveState(force: true);
        notifyListeners();
      }
      if (voiceState == RtcConnectionState.reconnecting ||
          !_voicePermissionGranted ||
          (_nextVoiceAttempt?.isAfter(nowProvider()) ?? false)) { return; }
      await retryVoice(requestPermission: false);
    });
    _fallbackStateTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_disposed || presence.liveConnected || _presenceRecoveryRunning || _fallbackRefreshRunning) return;
      final roomId = room?.id;
      final token = _activeAuthToken;
      if (roomId == null || token == null ||
          (_nextFallbackPoll?.isAfter(nowProvider()) ?? false)) { return; }
      _fallbackRefreshRunning = true;
      try {
        await presence.refresh(roomId: roomId, authToken: token);
        _fallbackFailures = presence.lastError == null ? 0 : _fallbackFailures + 1;
      } catch (_) {
        _fallbackFailures++;
      } finally {
        _nextFallbackPoll = nowProvider().add(RequestBudget.presenceFallback(
          seated: controller?.mySeat != null, failures: _fallbackFailures));
        _fallbackRefreshRunning = false;
      }
    });
  }

  Future<void> syncCurrentPresence() async {
    final roomId = room?.id;
    final token = _activeAuthToken;
    if (roomId == null || token == null) return;
    if (presence.liveConnected) {
      _syncLiveState(force: true);
      return;
    }
    await presence.heartbeat(
      roomId: roomId, authToken: token, seatIndex: controller?.mySeat,
      micEnabled: _micEnabledForPresence, familyTag: _familyTag,
      hostTag: _hostTag, agencyName: _agencyName,
      equippedFrameId: _equippedFrameId, equippedEntryId: _equippedEntryId,
      equippedProfileCardId: _equippedProfileCardId,
    );
  }

  Future<void> toggleMyMic() async {
    if (_micActionRunning) return;
    final current = controller;
    if (current?.mySeat == null) throw StateError('Join a seat before using the microphone.');
    final seat = current!.seats[current.mySeat!];
    if (presence.selfMicMuted || seat.roomMuted) {
      throw StateError('The room owner/admin has muted this seat.');
    }
    _micActionRunning = true;
    try {
      if (!connected && current.micState != MicState.live) {
        await retryVoice();
        if (!connected) throw StateError(connectionError ?? 'Voice is unavailable.');
      }
      current.toggleMic();
      await setMicFromController();
    } catch (_) {
      current.forceMicMuted();
      if (realtime.rtc.publishingMic) {
        try { await realtime.setMic(false); } catch (_) {}
      }
      rethrow;
    } finally { _micActionRunning = false; }
  }

  Future<void> leaveMySeat() async {
    final current = controller;
    if (current == null || current.mySeat == null) return;
    // Commit the leave before changing the local seat, including HTTP-only rooms.
    final roomId = room?.id;
    final token = _activeAuthToken;
    if (roomId == null || token == null) throw StateError('Room session is not active.');
    if (realtime.rtc.publishingMic && connected) await realtime.setMic(false);
    await presence.leaveSeat(roomId: roomId, authToken: token);
    current.leaveSeat();
    _syncLiveState(force: true);
  }

  bool get backendSessionActive =>
      room != null &&
      controller != null &&
      _activeAuthToken != null &&
      _activeUserId != null;

  void minimize() {
    if (!hasRoom) return;
    minimized = true;
    notifyListeners();
  }

  void resume() {
    if (!hasRoom) return;
    minimized = false;
    notifyListeners();
  }

  Future<RoomLuckyNumberEvent> drawLuckyNumber() async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    final event = await presence.drawLuckyNumber(
      roomId: roomId,
      authToken: authToken,
    );
    _syncLuckyNumberMessages();
    return event;
  }

  Future<void> setRoomSoundEnabled(bool enabled) async {
    _roomSoundEnabled = enabled;
    if (connected) {
      await realtime.setRemoteAudioEnabled(enabled);
    }
    notifyListeners();
  }

  Future<void> setMicFromController() async {
    final roomController = controller;
    if (roomController == null) return;
    if (!connected) {
      if (roomController.micState == MicState.live) {
        throw StateError(connectionError ?? 'Voice is reconnecting. Please retry.');
      }
      await syncCurrentPresence();
      return;
    }
    final mySeat = roomController.mySeat;
    final seatMuted = mySeat != null &&
        mySeat >= 0 &&
        mySeat < roomController.seats.length &&
        roomController.seats[mySeat].roomMuted;
    if ((presence.selfMicMuted || seatMuted) &&
        roomController.micState == MicState.live) {
      roomController.forceMicMuted();
    }
    await realtime.setMic(
      !presence.selfMicMuted &&
          !seatMuted &&
          !roomController.selfMuted &&
          roomController.micState == MicState.live,
    );
    // Permission/seat moderation can change while LiveKit creates a track.
    // Recheck after publishing so a late track cannot bypass a new mute.
    final latestSeat = roomController.mySeat;
    final allowedNow = identical(controller, roomController) &&
        latestSeat != null && !presence.selfMicMuted &&
        !roomController.seats[latestSeat].roomMuted && !roomController.selfMuted &&
        roomController.micState == MicState.live;
    if (!allowedNow && realtime.rtc.publishingMic) await realtime.setMic(false);
    await syncCurrentPresence();
  }

  Future<void> setSelfMute(bool muted) async {
    final roomController = controller;
    if (roomController == null || roomController.mySeat == null) {
      throw StateError('You must be on a seat to use self mute.');
    }
    if (!muted && !connected) {
      await retryVoice();
      if (!connected) throw StateError(connectionError ?? 'Voice is unavailable.');
    }
    roomController.setSelfMuted(muted);
    await setMicFromController();
  }

  Future<void> kickUser(
    String targetUserId, {
    Duration? duration,
  }) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.kick(
      roomId: roomId,
      authToken: authToken,
      targetUserId: targetUserId,
      duration: duration,
    );
  }

  Future<void> setRoomAdmin(
    String targetUserId, {
    required bool enabled,
  }) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.setAdmin(
      roomId: roomId,
      authToken: authToken,
      targetUserId: targetUserId,
      enabled: enabled,
    );
  }

  Future<void> setRoomChatBan(
    String targetUserId, {
    required bool banned,
  }) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.setChatBan(
      roomId: roomId,
      authToken: authToken,
      targetUserId: targetUserId,
      banned: banned,
    );
  }

  Future<void> setSeatLock(int seatIndex, bool locked) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.setSeatLock(
      roomId: roomId,
      authToken: authToken,
      seatIndex: seatIndex,
      locked: locked,
    );
  }

  Future<void> setSeatMute(int seatIndex, bool muted) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.setSeatMute(
      roomId: roomId,
      authToken: authToken,
      seatIndex: seatIndex,
      muted: muted,
    );
  }

  Future<void> takeMySeat(int seatIndex) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.takeSeat(
      roomId: roomId,
      authToken: authToken,
      seatIndex: seatIndex,
    );
    await _applyForcedSeatChange();
    _reconcileMySeatFromPresence();
    if (controller?.mySeat != seatIndex) {
      throw StateError('Seat join was not confirmed. Please try again.');
    }
    await _enforceModerationMute();
  }

  Future<void> setRoomMicMode(String micMode) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.setMicMode(
      roomId: roomId,
      authToken: authToken,
      micMode: micMode,
    );
    controller?.setInviteMode(presence.micMode != 'free');
  }

  Future<void> setRoomPublicScreen(bool enabled) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.setPublicScreenEnabled(
      roomId: roomId,
      authToken: authToken,
      enabled: enabled,
    );
  }

  Future<void> clearRoomComments() async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.clearComments(
      roomId: roomId,
      authToken: authToken,
    );
  }

  Future<void> sendRoomComment(String text) async {
    if (room == null || _activeAuthToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.sendChatMessage(text, roomId: room?.id, authToken: _activeAuthToken);
  }

    Future<void> requestMySeat(int seatIndex) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.requestSeat(
      roomId: roomId,
      authToken: authToken,
      seatIndex: seatIndex,
    );
  }

  Future<void> resolveSeatRequest(
    String targetUserId, {
    required bool approved,
  }) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.resolveSeatRequest(
      roomId: roomId,
      authToken: authToken,
      targetUserId: targetUserId,
      approved: approved,
    );
  }

    Future<void> inviteUserToSeat(
    String targetUserId, {
    required int seatIndex,
  }) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.inviteToSeat(
      roomId: roomId,
      authToken: authToken,
      targetUserId: targetUserId,
      seatIndex: seatIndex,
    );
  }

  Future<void> respondToSeatInvite(bool accepted) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.respondSeatInvite(
      roomId: roomId,
      authToken: authToken,
      accepted: accepted,
    );
    await _applyForcedSeatChange();
  }

  Future<void> moveUserToAudience(String targetUserId) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.removeFromSeat(
      roomId: roomId,
      authToken: authToken,
      targetUserId: targetUserId,
    );
  }

    Future<void> setMySeatEmote(String emote) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    final seatIndex = controller?.mySeat;
    if (roomId == null || authToken == null || seatIndex == null) {
      throw StateError('You must be on a seat to use emotes.');
    }

    // Push the current seat first so a just-seated user can use an emote
    // immediately instead of waiting for the next presence heartbeat.
    await presence.heartbeat(
      roomId: roomId,
      authToken: authToken,
      seatIndex: seatIndex,
      micEnabled: _micEnabledForPresence,
      familyTag: _familyTag,
      hostTag: _hostTag,
      agencyName: _agencyName,
      equippedFrameId: _equippedFrameId,
      equippedEntryId: _equippedEntryId,
      equippedProfileCardId: _equippedProfileCardId,
    );
    await presence.setEmote(
      roomId: roomId,
      authToken: authToken,
      seatIndex: seatIndex,
      emote: emote,
    );
  }

  Future<void> setUserSeatMute(
    String targetUserId, {
    required int seatIndex,
    required bool muted,
  }) async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) {
      throw StateError('Room session is not active.');
    }
    await presence.setMute(
      roomId: roomId,
      authToken: authToken,
      targetUserId: targetUserId,
      seatIndex: seatIndex,
      muted: muted,
    );
  }

  void refreshFunctionPack() {
    controller?.refreshFunctionPack();
    notifyListeners();
  }

  Future<void> close() async {
    try { await onRoomClosed?.call(); } catch (_) {}
    _voiceEpoch++;
    _voiceTimer?.cancel();
    _fallbackStateTimer?.cancel();
    final oldRoomId = room?.id;
    final oldAuthToken = _activeAuthToken;
    final oldController = controller;
    controller = null;
    room = null;
    minimized = false;
    connecting = false;
    connected = false;
    connectionError = null;
    _moderationForcedMicOff = false;
    _seenLuckyNumberEventIds.clear();
    _seenRoomChatEventIds.clear();
    _seenRoomJoinKeys.clear();
    _roomJoinSnapshotInitialized = false;

    oldController?.removeListener(_onRoomChanged);
    oldController?.dispose();

    await _stopPresence(
      sendLeave: oldRoomId != null && oldAuthToken != null,
      roomId: oldRoomId,
      authToken: oldAuthToken,
    );
    try { await realtime.exitRoom(); } catch (_) {}
    try { await foregroundService.stop(); } catch (_) {}
    notifyListeners();
  }

  void _cancelPresenceRecovery({bool resetBackoff = false}) {
    _presenceRecoveryTimer?.cancel();
    _presenceRecoveryTimer = null;
    if (resetBackoff) {
      _presenceRecoveryDelaySeconds = 2;
    }
  }

  void _schedulePresenceRecovery({bool immediate = false}) {
    if (_disposed ||
        !enablePresenceFallbackTimer ||
        _presenceRecoveryTimer != null ||
        _presenceRecoveryRunning ||
        room == null ||
        _activeAuthToken == null) {
      return;
    }

    final delaySeconds = immediate ? 0 : _presenceRecoveryDelaySeconds;
    if (!immediate) {
      _presenceRecoveryDelaySeconds =
          (_presenceRecoveryDelaySeconds * 2).clamp(2, 120).toInt();
    }

    _presenceRecoveryTimer = Timer(Duration(seconds: delaySeconds), () {
      _presenceRecoveryTimer = null;
      unawaited(_recoverPresence());
    });
  }

  Future<void> _recoverPresence() async {
    if (_disposed || _presenceRecoveryRunning) return;
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) return;

    _presenceRecoveryRunning = true;
    var retry = false;
    try {
      await presence.join(
        roomId: roomId,
        authToken: authToken,
        seatIndex: controller?.mySeat,
        micEnabled: _micEnabledForPresence,
        familyTag: _familyTag,
        hostTag: _hostTag,
        agencyName: _agencyName,
        equippedFrameId: _equippedFrameId,
        equippedEntryId: _equippedEntryId,
        equippedProfileCardId: _equippedProfileCardId,
      );
      await presence.connectLive(
        roomId: roomId,
        authToken: authToken,
      );
      if (!presence.connected) {
        throw StateError('Room presence reconnect pending');
      }
      _presenceRecoveryDelaySeconds = 2;
      _syncLiveState(force: true);
      await _applyForcedSeatChange();
      await _enforceModerationMute();
      if (!_roomSoundEnabled && connected) {
        await realtime.setRemoteAudioEnabled(false);
      }
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('kicked from this room')) {
        await close();
        return;
      }
      retry = true;
    } finally {
      _presenceRecoveryRunning = false;
      if (retry &&
          !_disposed &&
          room != null &&
          _activeAuthToken != null) {
        _schedulePresenceRecovery();
      }
    }
  }

  Future<void> _startPresence() async {
    final roomId = room?.id;
    final authToken = _activeAuthToken;
    if (roomId == null || authToken == null) return;

    presence.removeListener(_onPresenceChanged);
    presence.addListener(_onPresenceChanged);

    try {
      await presence.join(
        roomId: roomId,
        authToken: authToken,
        seatIndex: controller?.mySeat,
        micEnabled: _micEnabledForPresence,
        familyTag: _familyTag,
        hostTag: _hostTag,
        agencyName: _agencyName,
        equippedFrameId: _equippedFrameId,
        equippedEntryId: _equippedEntryId,
        equippedProfileCardId: _equippedProfileCardId,
      );
      await presence.connectLive(
        roomId: roomId,
        authToken: authToken,
      );
      _cancelPresenceRecovery(resetBackoff: true);
      _syncLiveState(force: true);
      await _applyForcedSeatChange();
      await _enforceModerationMute();
    } catch (_) {
      // Do not wait for the 60-second fallback heartbeat. Recover room
      // membership immediately with bounded exponential backoff while keeping
      // the RoomScreen, seat selection and local controls alive.
      _schedulePresenceRecovery(immediate: true);
    }

    _presenceTimer?.cancel();
    _presenceTimer = null;
    if (!enablePresenceFallbackTimer) return;
    _presenceTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      // Healthy rooms stay entirely on the hibernating WebSocket. HTTP is
      // emergency fallback only while realtime is disconnected. While a
      // carrier/OEM blocks WebSocket, refresh once a minute so the server's
      // 90-second online grace never drops a user who is still in the room.
      if (presence.liveConnected) return;
      final currentRoomId = room?.id;
      final currentAuthToken = _activeAuthToken;
      if (currentRoomId == null || currentAuthToken == null) return;

      if (!presence.connected) {
        _schedulePresenceRecovery(immediate: true);
        return;
      }

      try {
        await presence.heartbeat(
          roomId: currentRoomId,
          authToken: currentAuthToken,
          seatIndex: controller?.mySeat,
          micEnabled: _micEnabledForPresence,
          familyTag: _familyTag,
          hostTag: _hostTag,
          agencyName: _agencyName,
          equippedFrameId: _equippedFrameId,
          equippedEntryId: _equippedEntryId,
          equippedProfileCardId: _equippedProfileCardId,
        );
        await presence.connectLive(
          roomId: currentRoomId,
          authToken: currentAuthToken,
        );
        _syncLiveState(force: true);
        await _applyForcedSeatChange();
        await _enforceModerationMute();
        if (!_roomSoundEnabled && connected) {
          await realtime.setRemoteAudioEnabled(false);
        }
      } catch (error) {
        final message = error.toString().toLowerCase();
        if (message.contains('kicked from this room')) {
          await close();
          return;
        }
        _schedulePresenceRecovery(immediate: true);
      }
    });
  }


  Future<void> _applyForcedSeatChange() async {
    if (!presence.selfSeatForced) return;
    final roomController = controller;
    if (roomController == null) return;

    final previousSeat = roomController.mySeat;
    final forcedSeat = presence.selfForcedSeatIndex;
    // Consume before controller notifications can send an acknowledgement.
    presence.selfSeatForced = false;
    presence.selfForcedSeatIndex = null;
    roomController.forceMySeat(forcedSeat);

    if (previousSeat != forcedSeat) {
      if (previousSeat != null && forcedSeat == null) {
        _moderationForcedMicOff = false;
        await onSeatForcedDown?.call();
      }
      if (connected && realtime.rtc.publishingMic) await realtime.setMic(false);
    }
    await syncCurrentPresence();
  }

  Future<void> _enforceModerationMute() async {
    final roomController = controller;
    if (roomController == null) return;
    final seat = roomController.mySeat;
    final seatMuted = seat != null && roomController.seats[seat].roomMuted;

    if (presence.selfMicMuted || seatMuted) {
      if (roomController.micState == MicState.live &&
          !roomController.selfMuted) {
        _moderationForcedMicOff = true;
      }
      roomController.forceMicMuted();
      if (connected && realtime.rtc.publishingMic) {
        await realtime.setMic(false);
      }
      return;
    }

    if (!_moderationForcedMicOff) return;
    _moderationForcedMicOff = false;

    if (roomController.mySeat == null || roomController.selfMuted) {
      return;
    }

    roomController.restoreMicAfterModeration();
    if (connected) await setMicFromController();
  }

    Future<void> _stopPresence({
    required bool sendLeave,
    String? roomId,
    String? authToken,
  }) async {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _cancelPresenceRecovery(resetBackoff: true);
    presence.removeListener(_onPresenceChanged);
    await presence.disconnectLive();

    if (sendLeave && roomId != null && authToken != null) {
      try {
        await presence.leave(roomId: roomId, authToken: authToken);
      } catch (_) {
        // Server TTL removes stale members if a graceful leave fails.
      }
    }

    _activeAuthToken = null;
    _activeUserId = null;
    _liveSyncInitialized = false;
    _lastSyncedSeatIndex = null;
    _lastSyncedMicEnabled = null;
  }

  void _onPresenceChanged() {
    if (presence.connected) {
      _cancelPresenceRecovery(resetBackoff: true);
    } else if (room != null && _activeAuthToken != null) {
      _schedulePresenceRecovery(immediate: true);
    }

    final roomController = controller;
    roomController?.setInviteMode(presence.micMode != 'free');
    final serverSeatCount = presence.seatCount;
    if (roomController != null &&
        serverSeatCount != null &&
        roomController.seats.length != serverSeatCount) {
      roomController.setSeatCount(serverSeatCount);
    }
    _syncRoomJoinMessages();
    _syncRoomChatMessages();
    _syncLuckyNumberMessages();
    if (roomController != null) {
      for (var index = 0; index < roomController.seats.length; index++) {
        roomController.setSeatLocked(
          index,
          presence.lockedSeats.contains(index),
        );
        roomController.setSeatRoomMuted(
          index,
          presence.mutedSeats.contains(index),
        );
      }
    }
    if (presence.selfSeatForced) {
      unawaited(_applyForcedSeatChange().catchError((Object error) {
        connectionError = error.toString();
      }));
    } else {
      _reconcileMySeatFromPresence();
    }
    unawaited(_enforceModerationMute().catchError((Object error) {
      connectionError = error.toString();
    }));
    notifyListeners();
  }

  void _reconcileMySeatFromPresence() {
    final userId = _activeUserId;
    final roomController = controller;
    if (userId == null || roomController == null) return;
    RoomPresenceMember? me;
    for (final member in presence.members) {
      if (member.userId == userId) {
        me = member;
        break;
      }
    }
    if (me == null || roomController.mySeat == me.seatIndex) return;
    roomController.forceMySeat(me.seatIndex);
    if (connected && realtime.rtc.publishingMic) {
      unawaited(realtime.setMic(false).catchError((Object _) {}));
    }
  }

  void _syncLiveState({bool force = false}) {
    if (!presence.liveConnected) return;
    final seatIndex = controller?.mySeat;
    final micEnabled = _micEnabledForPresence;
    if (!force &&
        _liveSyncInitialized &&
        _lastSyncedSeatIndex == seatIndex &&
        _lastSyncedMicEnabled == micEnabled) {
      return;
    }
    _liveSyncInitialized = true;
    _lastSyncedSeatIndex = seatIndex;
    _lastSyncedMicEnabled = micEnabled;
    presence.syncLiveState(
      seatIndex: seatIndex,
      micEnabled: micEnabled,
    );
  }

  void _syncRoomJoinMessages() {
    final roomController = controller;
    if (roomController == null) return;

    final members = presence.members;
    if (!_roomJoinSnapshotInitialized) {
      _roomJoinSnapshotInitialized = true;
      for (final member in members) {
        final key =
            member.userId + ':' + member.joinedAt.millisecondsSinceEpoch.toString();
        _seenRoomJoinKeys.add(key);
      }

      final currentUserId = _activeUserId;
      if (currentUserId != null) {
        for (final member in members) {
          if (member.userId != currentUserId) continue;
          roomController.addRoomMessage(
            member.displayName,
            'entered the room', userId: member.userId, avatarDataUrl: member.avatarDataUrl,
          );
          break;
        }
      }
      return;
    }

    for (final member in members) {
      final key =
          member.userId + ':' + member.joinedAt.millisecondsSinceEpoch.toString();
      if (!_seenRoomJoinKeys.add(key)) continue;
      roomController.addRoomMessage(
        member.displayName,
        'entered the room', userId: member.userId, avatarDataUrl: member.avatarDataUrl,
      );
    }
  }

  void _syncRoomChatMessages() {
    final current = controller;
    if (current == null) return;
    for (final event in <RoomChatEvent>[
      ...presence.chatEvents,
      if (presence.latestChatEvent != null) presence.latestChatEvent!,
    ]) {
      if (!_seenRoomChatEventIds.add(event.id)) continue;
      final member = presence.members.where((member) => member.userId == event.userId).firstOrNull;
      current.addRoomMessage(event.displayName, event.text,
        userId: event.userId, avatarDataUrl: member?.avatarDataUrl);
    }
  }

  void _syncLuckyNumberMessages() {
    final roomController = controller;
    if (roomController == null) return;
    for (final event in presence.luckyNumberEvents) {
      if (!_seenLuckyNumberEventIds.add(event.id)) continue;
      roomController.addRoomMessage(
        event.displayName,
        '🎲 Lucky Number: ${event.number}', userId: event.userId,
      );
    }
  }

  void _onRoomChanged() {
    _syncLiveState();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _voiceEpoch++;
    _voiceTimer?.cancel();
    _fallbackStateTimer?.cancel();
    _activeAuthToken = null;
    _activeUserId = null;
    _presenceTimer?.cancel();
    _presenceRecoveryTimer?.cancel();
    _presenceRecoveryTimer = null;
    unawaited(presence.disconnectLive());
    presence.removeListener(_onPresenceChanged);
    controller?.removeListener(_onRoomChanged);
    controller?.dispose();
    super.dispose();
  }
}
