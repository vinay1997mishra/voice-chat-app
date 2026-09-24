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
  });

  final FunctionPackRuntime runtime;
  final RealtimeCoordinator realtime;
  final RoomForegroundServiceBridge foregroundService;
  final RoomPermissionBridge permissions;
  final RoomPresenceService presence;

  RoomSummary? room;
  RoomController? controller;
  bool minimized = false;
  bool connecting = false;
  bool connected = false;
  String? connectionError;

  Timer? _presenceTimer;
  String? _activeUserId;
  String? _activeDisplayName;

  List<RoomPresenceMember> get liveMembers =>
      List<RoomPresenceMember>.unmodifiable(presence.members);

  bool get hasRoom => room != null && controller != null;

  Future<void> open(
    RoomSummary nextRoom, {
    required String userId,
    required String displayName,
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
      await realtime.enterRoom(nextRoom.id, userId);
      _activeUserId = userId;
      _activeDisplayName = displayName;
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
    await realtime.setMic(roomController.micState == MicState.live);
  }

  void refreshFunctionPack() {
    controller?.refreshFunctionPack();
    notifyListeners();
  }

  Future<void> close() async {
    final oldRoomId = room?.id;
    final oldUserId = _activeUserId;
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
      sendLeave: oldRoomId != null && oldUserId != null,
      roomId: oldRoomId,
      userId: oldUserId,
    );
    await realtime.exitRoom();
    await foregroundService.stop();
    notifyListeners();
  }

  Future<void> _startPresence() async {
    final roomId = room?.id;
    final userId = _activeUserId;
    final displayName = _activeDisplayName;
    if (roomId == null || userId == null || displayName == null) return;

    presence.removeListener(_onPresenceChanged);
    presence.addListener(_onPresenceChanged);

    try {
      await presence.join(
        roomId: roomId,
        userId: userId,
        displayName: displayName,
      );
    } catch (_) {
      // Keep the room open; presence will retry on the next heartbeat.
    }

    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final currentRoomId = room?.id;
      final currentUserId = _activeUserId;
      final currentDisplayName = _activeDisplayName;
      if (currentRoomId == null ||
          currentUserId == null ||
          currentDisplayName == null) {
        return;
      }
      try {
        await presence.heartbeat(
          roomId: currentRoomId,
          userId: currentUserId,
          displayName: currentDisplayName,
        );
      } catch (_) {
        // A later heartbeat/refresh will reconnect automatically.
      }
    });
  }

  Future<void> _stopPresence({
    required bool sendLeave,
    String? roomId,
    String? userId,
  }) async {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    presence.removeListener(_onPresenceChanged);

    if (sendLeave && roomId != null && userId != null) {
      try {
        await presence.leave(roomId: roomId, userId: userId);
      } catch (_) {
        // Server TTL removes stale members if a graceful leave fails.
      }
    }

    _activeUserId = null;
    _activeDisplayName = null;
  }

  void _onPresenceChanged() {
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
