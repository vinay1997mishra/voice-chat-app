enum AppVisibility { foreground, background }

class SessionLifecycle {
  AppVisibility visibility = AppVisibility.foreground;
  bool foregroundServiceRequested = false;
  bool audioFocusHeld = false;
  bool reconnectNeeded = false;

  void onBackground({required bool inVoiceRoom}) {
    visibility = AppVisibility.background;
    foregroundServiceRequested = inVoiceRoom;
    audioFocusHeld = inVoiceRoom;
  }

  void onForeground() {
    visibility = AppVisibility.foreground;
    reconnectNeeded = false;
  }

  void onTransportLost() {
    reconnectNeeded = true;
  }

  void onTransportRestored() {
    reconnectNeeded = false;
  }
}
