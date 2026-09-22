enum DisconnectState { none, requested, accepted, refused, timedOut }

enum HeartbeatState { idle, selecting, matched, failed }

class CpFeatureService {
  DisconnectState disconnectState = DisconnectState.none;
  HeartbeatState heartbeatState = HeartbeatState.idle;
  String? disconnectRequester;
  String? heartbeatChoice;

  void requestDisconnect(String userId) {
    disconnectRequester = userId;
    disconnectState = DisconnectState.requested;
  }

  void respondDisconnect({required bool accept}) {
    if (disconnectState != DisconnectState.requested) return;
    disconnectState =
        accept ? DisconnectState.accepted : DisconnectState.refused;
  }

  void timeoutDisconnect() {
    if (disconnectState == DisconnectState.requested) {
      disconnectState = DisconnectState.timedOut;
    }
  }

  void startHeartbeat() {
    heartbeatState = HeartbeatState.selecting;
    heartbeatChoice = null;
  }

  void chooseHeartbeat(String value) {
    if (heartbeatState != HeartbeatState.selecting) return;
    heartbeatChoice = value;
  }

  void resolveHeartbeat({required bool matched}) {
    if (heartbeatState != HeartbeatState.selecting) return;
    heartbeatState =
        matched ? HeartbeatState.matched : HeartbeatState.failed;
  }

  void closeHeartbeat() {
    heartbeatState = HeartbeatState.idle;
    heartbeatChoice = null;
  }
}
