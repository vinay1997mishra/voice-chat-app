import 'dart:math' as math;

/// Background reads are deliberately sparse; explicit user actions bypass this.
abstract final class RequestBudget {
  static const homeRefresh = Duration(minutes: 2);
  static const ribbonFallback = Duration(minutes: 1);
  static Duration reconnectDelay(int failures) =>
      Duration(seconds: math.min(120, 2 * (1 << math.min(failures, 6))));
  static Duration presenceFallback({required bool seated, required int failures}) =>
      Duration(seconds: math.min(120, (seated ? 5 : 30) * (1 << math.min(failures, 6))));
}
