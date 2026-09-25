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
  });

  final FunctionPackRuntime runtime;
  final RealtimeCoordinator realtime;
  final RoomForegroundServiceBridge foregroundService;
  final RoomPermissionBridge permissions;
  final RoomPresenceService presence;
  final String? Function()? familyTagProvider;
  final String? Function()? hostTagProvider;
  final String? Function()? agencyNameProvider;

  RoomSummary? room;
  RoomController? controller;
  bool minimized = false;
  bool connecting = false;
  bool connected = false;
  String? connectionError;

  Timer? _presenceTimer;
  String? _activeAuthToken;

  List<RoomPresenceMember> get liveMembers =>
      List<RoomPresenceMember>.unmodifiable(presence.members);

  bool get hasRoom => room != null && controller != null;
  bool get moderationMicMuted => presence.selfMicMuted;
  RoomSeatInvite? get pendingSeatInvite => presence.pendingSeatInvite;

  String? get _familyTag => familyTagProvider?.call();
  String? get _hostTag => hostTagProvider?.call();
  String? get _agencyName => agencyNameProvider?.call();

  Future<void> open(
    RoomSummary nextRoom, {
    required String userId,
    required String authToken,
  }) async {
    if (room?.id == nextRoom.id && controller != null) {
      minimized = false;
      notifyListeners();
      return;
    }

    if (hasRoom) {
      await close();
    }

    room = nextRoom;
    controller = RoomController(
      runtime: runtime,
      seatCountOverride: nextRoom.seatCount,
    )..addListener(_onRoomChanged);
    minimized = false;
    connecting = true;
    connected = false;
    connectionError = null;
    notifyListeners();

    try {
      final granted = await permissions.requestVoiceRoomPermissions();
      if (!granted) {
        connectionError = 'Microphone permission is required.';
        connecting = false;
        notifyListeners();
        return;
      }

      await foregroundService.start();
      await realtime.enterRoom(
        nextRoom.id,
        userId,
        authToken: authToken,
      );
      _activeAuthToken = authToken;
      await _startPresence();
      connected = true;
      connecting = false;
      connectionError = null;
    } catch (error) {
      connecting = false;
      connected = false;
      connectionError = error.toString();
      await _stopPresence(sendLeave: true);
      await foregroundService.stop();
    }
    notifyListeners();
  }

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

  Future<void> setMicFromController() async {
    final roomController = controller;
    if (roomController == null || !connected) return;
    if (presence.selfMicMuted && roomController.micState == MicState.live) {
      roomController.forceMicMuted();
    }
    await realtime.setMic(
      !presence.selfMicMuted && roomController.micState == MicState.live,
    );
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
    final oldRoomId = room?.id;
    final oldAuthToken = _activeAuthToken;
    final oldController = controller;
    controller = null;
    room = null;
    minimized = false;
    connecting = false;
    connected = false;
    connectionError = null;

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
        familyTag: _familyTag,
        hostTag: _hostTag,
        agencyName: _agencyName,
      );
      await _applyForcedSeatChange();
      await _enforceModerationMute();
    } catch (_) {
      // Keep the room open; presence will retry on the next heartbeat.
    }

    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final currentRoomId = room?.id;
      final currentAuthToken = _activeAuthToken;
      if (currentRoomId == null || currentAuthToken == null) {
        return;
      }
      try {
        await presence.heartbeat(
          roomId: currentRoomId,
          authToken: currentAuthToken,
          seatIndex: controller?.mySeat,
          familyTag: _familyTag,
          hostTag: _hostTag,
          agencyName: _agencyName,
        );
        await _applyForcedSeatChange();
        await _enforceModerationMute();
      } catch (error) {
        final message = error.toString().toLowerCase();
        if (message.contains('kicked from this room')) {
          await close();
          return;
        }
        // A later heartbeat/refresh will reconnect automatically.
      }
    });
  }

  Future<void> _applyForcedSeatChange() async {
    if (!presence.selfSeatForced) return;
    final roomController = controller;
    if (roomController == null) return;

    roomController.forceMySeat(presence.selfForcedSeatIndex);
    presence.selfSeatForced = false;
    presence.selfForcedSeatIndex = null;

    if (connected) {
      await realtime.setMic(false);
    }
  }

    Future<void> _enforceModerationMute() async {
    final roomController = controller;
    if (roomController == null || !connected) return;
    if (!presence.selfMicMuted) return;

    roomController.forceMicMuted();
    if (realtime.rtc.publishingMic) {
      await realtime.setMic(false);
    }
  }

    Future<void> _stopPresence({
    required bool sendLeave,
    String? roomId,
    String? authToken,
  }) async {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    presence.removeListener(_onPresenceChanged);

    if (sendLeave && roomId != null && authToken != null) {
      try {
        await presence.leave(roomId: roomId, authToken: authToken);
      } catch (_) {
        // Server TTL removes stale members if a graceful leave fails.
      }
    }

    _activeAuthToken = null;
  }

  void _onPresenceChanged() {
    controller?.setInviteMode(presence.micMode != 'free');
    notifyListeners();
  }

  void _onRoomChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    presence.removeListener(_onPresenceChanged);
    controller?.removeListener(_onRoomChanged);
    controller?.dispose();
    super.dispose();
  }
}
