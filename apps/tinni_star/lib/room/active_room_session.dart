import 'dart:async';

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
    return roomController.micState == MicState.live &&
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
    if (sameRoom && _activeAuthToken != null && _activeUserId != null) {
      minimized = false;
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

    // Start server-authoritative room presence first. _startPresence keeps its
    // own reconnect fallback, so a temporary network error does not destroy
    // the authenticated room session.
    await _startPresence();
    await _applyForcedSeatChange();
    await _enforceModerationMute();

    final granted = await permissions.requestVoiceRoomPermissions();
    if (!granted) {
      connecting = false;
      connected = false;
      connectionError =
          'Microphone permission is required for voice. Room controls remain active.';
      notifyListeners();
      return;
    }

    try {
      await foregroundService.start();
      await realtime.enterRoom(
        nextRoom.id,
        userId,
        authToken: authToken,
      );
      connected = true;
      connectionError = null;
    } catch (error) {
      // Voice must never tear down the room backend session. Keep presence,
      // auth and all non-voice room functions alive when LiveKit is missing,
      // unavailable or reconnecting.
      connected = false;
      connectionError = 'Voice unavailable: ' + error.toString();
      try {
        await realtime.exitRoom();
      } catch (_) {}
      try {
        await foregroundService.stop();
      } catch (_) {}
    } finally {
      connecting = false;
    }

    notifyListeners();
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
    if (roomController == null || !connected) return;
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
  }

  Future<void> setSelfMute(bool muted) async {
    final roomController = controller;
    if (roomController == null || roomController.mySeat == null) {
      throw StateError('You must be on a seat to use self mute.');
    }
    roomController.setSelfMuted(muted);
    if (connected) {
      await realtime.setMic(
        !muted && !presence.selfMicMuted && roomController.micState == MicState.live,
      );
    }
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
    await presence.sendChatMessage(text);
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
    await onRoomClosed?.call();
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
    await realtime.exitRoom();
    await foregroundService.stop();
    notifyListeners();
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
      _syncLiveState(force: true);
      await _applyForcedSeatChange();
      await _enforceModerationMute();
    } catch (_) {
      // Keep the room open; presence will retry on the next heartbeat.
    }

    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      // Healthy rooms stay entirely on the hibernating WebSocket. HTTP is
      // emergency fallback only while realtime is disconnected. The long
      // fallback interval stays well inside the server grace window while
      // avoiding request storms when a carrier/OEM temporarily blocks WS.
      if (presence.liveConnected) return;
      final currentRoomId = room?.id;
      final currentAuthToken = _activeAuthToken;
      if (currentRoomId == null || currentAuthToken == null) return;
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
        if (!_roomSoundEnabled) {
          await realtime.setRemoteAudioEnabled(false);
        }
      } catch (error) {
        final message = error.toString().toLowerCase();
        if (message.contains('kicked from this room')) {
          await close();
        }
      }
    });
  }

  Future<void> _applyForcedSeatChange() async {
    if (!presence.selfSeatForced) return;
    final roomController = controller;
    if (roomController == null) return;

    final previousSeat = roomController.mySeat;
    final forcedSeat = presence.selfForcedSeatIndex;
    roomController.forceMySeat(forcedSeat);
    presence.selfSeatForced = false;
    presence.selfForcedSeatIndex = null;

    if (previousSeat != null && forcedSeat == null) {
      _moderationForcedMicOff = false;
      await onSeatForcedDown?.call();
    }

    if (connected) {
      await realtime.setMic(false);
    }
  }

  Future<void> _enforceModerationMute() async {
    final roomController = controller;
    if (roomController == null || !connected) return;

    if (presence.selfMicMuted) {
      if (roomController.micState == MicState.live &&
          !roomController.selfMuted) {
        _moderationForcedMicOff = true;
      }
      roomController.forceMicMuted();
      if (realtime.rtc.publishingMic) {
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
    await realtime.setMic(roomController.micState == MicState.live);
  }

    Future<void> _stopPresence({
    required bool sendLeave,
    String? roomId,
    String? authToken,
  }) async {
    _presenceTimer?.cancel();
    _presenceTimer = null;
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
    final roomController = controller;
    roomController?.setInviteMode(presence.micMode != 'free');
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
      unawaited(_applyForcedSeatChange());
    } else {
      _reconcileMySeatFromPresence();
    }
    unawaited(_enforceModerationMute());
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
            'entered the room',
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
        'entered the room',
      );
    }
  }

  void _syncRoomChatMessages() {
    final roomController = controller;
    final event = presence.latestChatEvent;
    if (roomController == null || event == null) return;
    if (!_seenRoomChatEventIds.add(event.id)) return;
    roomController.addRoomMessage(
      event.displayName,
      event.text,
    );
  }

  void _syncLuckyNumberMessages() {
    final roomController = controller;
    if (roomController == null) return;
    for (final event in presence.luckyNumberEvents) {
      if (!_seenLuckyNumberEventIds.add(event.id)) continue;
      roomController.addRoomMessage(
        event.displayName,
        '🎲 Lucky Number: ${event.number}',
      );
    }
  }

  void _onRoomChanged() {
    _syncLiveState();
    notifyListeners();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    unawaited(presence.disconnectLive());
    presence.removeListener(_onPresenceChanged);
    controller?.removeListener(_onRoomChanged);
    controller?.dispose();
    super.dispose();
  }
}
