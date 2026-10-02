import 'package:flutter/foundation.dart';

import '../core/function_pack.dart';
import '../core/seat_policy.dart';
import 'room_models.dart';

class RoomController extends ChangeNotifier {
  RoomController({required this.runtime, this.seatCountOverride}) {
    _rebuildSeats();
  }

  final FunctionPackRuntime runtime;
  int? seatCountOverride;

  final List<RoomMessage> messages = [
    const RoomMessage('System', 'Welcome to Tinni Star ✨'),
  ];

  late List<RoomSeat> seats;
  int? mySeat;
  MicState micState = MicState.offSeat;
  bool? inviteModeOverride;
  bool selfMuted = false;

  TinniFunctionConfig get config => runtime.config;
  bool get inviteMode => inviteModeOverride ?? config.inviteMode;

  void setSeatCount(int seatCount) {
    final oldSeats = seats;
    final oldMySeat = mySeat;
    seatCountOverride = normalizeSeatCount(seatCount);
    _rebuildSeats();
    final copyCount = oldSeats.length < seats.length ? oldSeats.length : seats.length;
    for (var index = 0; index < copyCount; index++) {
      seats[index] = oldSeats[index];
    }
    if (oldMySeat != null && oldMySeat < seats.length) {
      mySeat = oldMySeat;
    } else {
      mySeat = null;
      micState = MicState.offSeat;
      selfMuted = false;
    }
    notifyListeners();
  }

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
    selfMuted = false;
    notifyListeners();
  }

  void forceMySeat(int? index) {
    final oldSeat = mySeat;
    if (oldSeat != null && oldSeat >= 0 && oldSeat < seats.length) {
      seats[oldSeat] = seats[oldSeat].copyWith(clearUser: true);
    }

    if (index == null) {
      mySeat = null;
      micState = MicState.offSeat;
      notifyListeners();
      return;
    }

    if (index < 0 || index >= seats.length) return;
    seats[index] = seats[index].copyWith(userName: 'You');
    mySeat = index;
    micState = MicState.muted;
    notifyListeners();
  }

    bool managerRemoveUserFromSeat(int index) {
    if (index < 0 || index >= seats.length) return false;
    final seat = seats[index];
    if (!seat.occupied) return false;
    seats[index] = seat.copyWith(clearUser: true);
    if (mySeat == index) {
      mySeat = null;
      micState = MicState.offSeat;
    }
    messages.add(
      RoomMessage(
        'System',
        'Seat ' + (index + 1).toString() + ' user moved to audience.',
      ),
    );
    notifyListeners();
    return true;
  }

  void setInviteMode(bool enabled) {
    inviteModeOverride = enabled;
    notifyListeners();
  }

  void toggleMic() {
    if (mySeat == null || micState == MicState.banned || selfMuted) return;
    micState = micState == MicState.live ? MicState.muted : MicState.live;
    notifyListeners();
  }

  void setSelfMuted(bool muted) {
    selfMuted = muted;
    if (muted && micState == MicState.live) {
      micState = MicState.muted;
    }
    notifyListeners();
  }

  void toggleSelfMuted() => setSelfMuted(!selfMuted);

  void toggleSeatLock(int index) {
    if (!config.seatLockEnabled || index < 0 || index >= seats.length) return;
    final seat = seats[index];
    if (seat.occupied) return;
    seats[index] = seat.copyWith(locked: !seat.locked);
    notifyListeners();
  }

  void setSeatLocked(int index, bool locked) {
    if (index < 0 || index >= seats.length) return;
    final seat = seats[index];
    if (seat.occupied && locked) return;
    if (seat.locked == locked) return;
    seats[index] = seat.copyWith(locked: locked);
    notifyListeners();
  }

  void toggleSeatRoomMute(int index) {
    if (index < 0 || index >= seats.length) return;
    setSeatRoomMuted(index, !seats[index].roomMuted);
  }

  void setSeatRoomMuted(int index, bool muted) {
    if (index < 0 || index >= seats.length) return;
    final seat = seats[index];
    seats[index] = seat.copyWith(roomMuted: muted);
    if (mySeat == index && muted) {
      micState = MicState.muted;
    }
    notifyListeners();
  }

  void forceMicMuted() {
    if (mySeat == null ||
        micState == MicState.banned ||
        micState == MicState.muted) {
      return;
    }
    micState = MicState.muted;
    notifyListeners();
  }

  void restoreMicAfterModeration() {
    if (mySeat == null || micState == MicState.banned || selfMuted) {
      return;
    }
    if (micState == MicState.live) return;
    micState = MicState.live;
    notifyListeners();
  }

  void sendMessage(String text) {
    final value = text.trim();
    if (!config.roomChatEnabled || value.isEmpty) return;
    messages.add(RoomMessage('You', value));
    notifyListeners();
  }

  void addRoomMessage(String author, String text) {
    final cleanAuthor = author.trim().isEmpty ? 'User' : author.trim();
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    messages.add(RoomMessage(cleanAuthor, cleanText));
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
