import 'package:flutter/foundation.dart';

import '../core/function_pack.dart';
import '../core/seat_policy.dart';
import 'room_models.dart';

class RoomController extends ChangeNotifier {
  RoomController({required this.runtime, this.seatCountOverride}) {
    _rebuildSeats();
  }

  final FunctionPackRuntime runtime;
  final int? seatCountOverride;

  final List<RoomMessage> messages = [
    const RoomMessage('System', 'Welcome to Tinni Star ✨'),
  ];

  late List<RoomSeat> seats;
  int? mySeat;
  MicState micState = MicState.offSeat;
  bool? inviteModeOverride;

  TinniFunctionConfig get config => runtime.config;
  bool get inviteMode => inviteModeOverride ?? config.inviteMode;

  void refreshFunctionPack() {
    final oldSeat = mySeat;
    _rebuildSeats();
    if (oldSeat != null && oldSeat < seats.length) {
      seats[oldSeat] = seats[oldSeat].copyWith(userName: 'You');
      mySeat = oldSeat;
      micState = MicState.muted;
    } else {
      mySeat = null;
      micState = MicState.offSeat;
    }
    notifyListeners();
  }

  String requestOrJoinSeat(int index) {
    if (index < 0 || index >= seats.length) return 'Invalid seat.';
    final seat = seats[index];
    if (seat.locked) return 'Seat ' + (index + 1).toString() + ' is locked.';
    if (seat.occupied) return 'Seat ' + (index + 1).toString() + ' is occupied.';
    if (mySeat != null) return 'Leave your current seat first.';
    if (inviteMode) {
      messages.add(RoomMessage('System', 'Seat ' + (index + 1).toString() + ' request sent.'));
      notifyListeners();
      return 'Request sent to Owner/Admin.';
    }
    seats[index] = seat.copyWith(userName: 'You');
    mySeat = index;
    micState = MicState.muted;
    notifyListeners();
    return 'Joined seat ' + (index + 1).toString() + '.';
  }

  void ownerApproveMySeat(int index) {
    managerTakeSeat(index);
  }

  String managerTakeSeat(int index) {
    if (index < 0 || index >= seats.length) return 'Invalid seat.';
    final seat = seats[index];
    if (seat.occupied) {
      return 'Seat ' + (index + 1).toString() + ' is occupied.';
    }
    if (mySeat != null && mySeat != index) {
      return 'Leave your current seat first.';
    }
    seats[index] = seat.copyWith(userName: 'You');
    mySeat = index;
    micState = MicState.muted;
    messages.add(
      RoomMessage(
        'System',
        'You joined seat ' + (index + 1).toString() + ' directly.',
      ),
    );
    notifyListeners();
    return 'Joined seat ' + (index + 1).toString() + '.';
  }

  void leaveSeat() {
    final index = mySeat;
    if (index == null) return;
    seats[index] = seats[index].copyWith(clearUser: true);
    mySeat = null;
    micState = MicState.offSeat;
    notifyListeners();
  }

  void setInviteMode(bool enabled) {
    inviteModeOverride = enabled;
    notifyListeners();
  }

  void toggleMic() {
    if (mySeat == null || micState == MicState.banned) return;
    micState = micState == MicState.live ? MicState.muted : MicState.live;
    notifyListeners();
  }

  void toggleSeatLock(int index) {
    if (!config.seatLockEnabled || index < 0 || index >= seats.length) return;
    final seat = seats[index];
    if (seat.occupied) return;
    seats[index] = seat.copyWith(locked: !seat.locked);
    notifyListeners();
  }

  void toggleSeatRoomMute(int index) {
    if (index < 0 || index >= seats.length) return;
    final seat = seats[index];
    seats[index] = seat.copyWith(roomMuted: !seat.roomMuted);
    if (mySeat == index && seats[index].roomMuted) {
      micState = MicState.muted;
    }
    notifyListeners();
  }

  void sendMessage(String text) {
    final value = text.trim();
    if (!config.roomChatEnabled || value.isEmpty) return;
    messages.add(RoomMessage('You', value));
    notifyListeners();
  }

  void _rebuildSeats() {
    final requested = seatCountOverride ?? config.seatCount;
    final normalized = normalizeSeatCount(requested);
    seats = List.generate(
      normalized,
      (index) => RoomSeat(index: index),
    );
  }
}
