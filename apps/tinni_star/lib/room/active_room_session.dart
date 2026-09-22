import 'package:flutter/foundation.dart';

import '../background/room_foreground_service.dart';
import '../background/room_permission_bridge.dart';
import '../core/function_pack.dart';
import '../discovery/discovery_service.dart';
import '../infra/realtime.dart';
import 'room_controller.dart';
import 'room_models.dart';

class ActiveRoomSession extends ChangeNotifier {
  ActiveRoomSession({
    required this.runtime,
    required this.realtime,
    required this.foregroundService,
    required this.permissions,
  });

  final FunctionPackRuntime runtime;
  final RealtimeCoordinator realtime;
  final RoomForegroundServiceBridge foregroundService;
  final RoomPermissionBridge permissions;

  RoomSummary? room;
  RoomController? controller;
  bool minimized = false;
  bool connecting = false;
  bool connected = false;
  String? connectionError;

  bool get hasRoom => room != null && controller != null;

  Future<void> open(RoomSummary nextRoom) async {
    if (room?.id == nextRoom.id && controller != null) {
      minimized = false;
      notifyListeners();
      return;
    }

    if (hasRoom) {
      await close();
    }

    room = nextRoom;
    controller = RoomController(runtime: runtime)..addListener(_onRoomChanged);
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
      await realtime.enterRoom(nextRoom.id, '10000000');
      connected = true;
      connecting = false;
      connectionError = null;
    } catch (error) {
      connecting = false;
      connected = false;
      connectionError = error.toString();
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
    final oldController = controller;
    controller = null;
    room = null;
    minimized = false;
    connecting = false;
    connected = false;
    connectionError = null;

    oldController?.removeListener(_onRoomChanged);
    oldController?.dispose();

    await realtime.exitRoom();
    await foregroundService.stop();
    notifyListeners();
  }

  void _onRoomChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    controller?.removeListener(_onRoomChanged);
    controller?.dispose();
    super.dispose();
  }
}
