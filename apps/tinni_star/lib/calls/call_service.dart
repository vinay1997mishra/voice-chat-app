enum CallState { idle, ringing, connected, ended, rejected }

enum CallMedia { voice, video }

class CallSession {
  const CallSession({
    required this.callerId,
    required this.receiverId,
    required this.media,
    required this.state,
  });

  final String callerId;
  final String receiverId;
  final CallMedia media;
  final CallState state;

  CallSession copyWith({CallState? state}) => CallSession(
        callerId: callerId,
        receiverId: receiverId,
        media: media,
        state: state ?? this.state,
      );
}

class CallService {
  bool friendsOnly = true;
  CallSession? active;

  CallSession initiate({
    required String callerId,
    required String receiverId,
    required CallMedia media,
    required bool isFriend,
  }) {
    if (friendsOnly && !isFriend) {
      throw StateError('Calls are limited to friends');
    }
    if (active != null && active!.state != CallState.ended) {
      throw StateError('Another call is active');
    }
    active = CallSession(
      callerId: callerId,
      receiverId: receiverId,
      media: media,
      state: CallState.ringing,
    );
    return active!;
  }

  void accept() {
    final call = active;
    if (call == null || call.state != CallState.ringing) return;
    active = call.copyWith(state: CallState.connected);
  }

  void reject() {
    final call = active;
    if (call == null) return;
    active = call.copyWith(state: CallState.rejected);
  }

  void end() {
    final call = active;
    if (call == null) return;
    active = call.copyWith(state: CallState.ended);
  }
}
