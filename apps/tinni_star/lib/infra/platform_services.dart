abstract interface class PushAdapter {
  Future<void> register(String userId);
  Future<void> unregister();
}

abstract interface class AnalyticsAdapter {
  void event(String name, Map<String, Object?> properties);
}

abstract interface class CrashReporter {
  void record(Object error, StackTrace? stackTrace);
}

abstract interface class RemoteConfigAdapter {
  Future<Map<String, Object?>> fetch();
}

class LocalPushAdapter implements PushAdapter {
  String? registeredUserId;

  @override
  Future<void> register(String userId) async {
    if (userId.isEmpty) throw StateError('userId is required');
    registeredUserId = userId;
  }

  @override
  Future<void> unregister() async {
    registeredUserId = null;
  }
}

class LocalAnalyticsAdapter implements AnalyticsAdapter {
  final List<Map<String, Object?>> events = <Map<String, Object?>>[];

  @override
  void event(String name, Map<String, Object?> properties) {
    events.add({
      'name': name,
      'properties': Map<String, Object?>.unmodifiable(properties),
    });
  }
}

class LocalCrashReporter implements CrashReporter {
  final List<String> errors = <String>[];

  @override
  void record(Object error, StackTrace? stackTrace) {
    errors.add(error.toString());
  }
}

class LocalRemoteConfigAdapter implements RemoteConfigAdapter {
  final Map<String, Object?> values = <String, Object?>{
    'room_recommendation_enabled': true,
    'gift_effects_enabled': true,
    'ktv_enabled': true,
    'games_enabled': true,
  };

  @override
  Future<Map<String, Object?>> fetch() async =>
      Map<String, Object?>.unmodifiable(values);
}
