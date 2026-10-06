import 'dart:async';

import 'package:flutter/foundation.dart';

/// One foreground movie at a time, in the order effects first request it.
class CinematicLane extends ChangeNotifier {
  Object? _owner;
  final _waiting = <Object>[];
  bool _disposed = false;
  bool _notificationPending = false;

  bool get busy => _owner != null;

  bool acquire(Object owner) {
    if (_disposed) return false;
    if (identical(_owner, owner)) return true;
    if (!_waiting.contains(owner)) _waiting.add(owner);
    if (_owner != null || !identical(_waiting.first, owner)) return false;
    _waiting.removeAt(0);
    _owner = owner;
    return true;
  }

  void release(Object owner) {
    if (_disposed || !identical(_owner, owner)) return;
    _owner = null;
    _notifyLater();
  }

  void _notifyLater() {
    if (_disposed || _notificationPending) return;
    _notificationPending = true;
    scheduleMicrotask(() {
      _notificationPending = false;
      if (!_disposed) notifyListeners();
    });
  }

  void cancel(Object owner) {
    if (_disposed) return;
    _waiting.remove(owner);
    release(owner);
    if (_owner == null) _notifyLater();
  }

  @override
  void dispose() {
    _disposed = true;
    _owner = null;
    _waiting.clear();
    super.dispose();
  }
}
