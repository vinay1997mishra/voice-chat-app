enum MicState { offSeat, muted, live, banned }

class RoomSeat {
  const RoomSeat({
    required this.index,
    this.userName,
    this.locked = false,
    this.roomMuted = false,
  });

  final int index;
  final String? userName;
  final bool locked;
  final bool roomMuted;

  bool get occupied => userName != null;

  RoomSeat copyWith({
    String? userName,
    bool clearUser = false,
    bool? locked,
    bool? roomMuted,
  }) {
    return RoomSeat(
      index: index,
      userName: clearUser ? null : (userName ?? this.userName),
      locked: locked ?? this.locked,
      roomMuted: roomMuted ?? this.roomMuted,
    );
  }
}

class RoomMessage {
  const RoomMessage(this.author, this.text);
  final String author;
  final String text;
}
