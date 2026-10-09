/// Background reads are deliberately sparse; explicit user actions bypass this.
abstract final class RequestBudget {
  static const homeRefresh = Duration(minutes: 2);
  static const ribbonFallback = Duration(minutes: 1);
  static const List<int> _socketFallbackSeconds = <int>[3, 5, 10, 20, 30];

  static Duration reconnectDelay(int failures) {
    final index = failures.clamp(0, _socketFallbackSeconds.length - 1).toInt();
    return Duration(seconds: _socketFallbackSeconds[index]);
  }

  static Duration presenceFallback({
    required bool seated,
    required int failures,
  }) => reconnectDelay(failures);
}
