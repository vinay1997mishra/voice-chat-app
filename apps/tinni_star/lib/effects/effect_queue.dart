enum EffectKind { gift, entry, vip, cp, rocket, rank, banner }

class EffectRequest {
  const EffectRequest({
    required this.id,
    required this.kind,
    required this.asset,
    required this.priority,
  });

  final String id;
  final EffectKind kind;
  final String asset;
  final int priority;
}

class EffectQueue {
  final List<EffectRequest> _pending = <EffectRequest>[];

  List<EffectRequest> get pending => List<EffectRequest>.unmodifiable(_pending);

  void enqueue(EffectRequest request) {
    if (_pending.any((item) => item.id == request.id)) return;
    _pending.add(request);
    _pending.sort((a, b) => b.priority.compareTo(a.priority));
  }

  EffectRequest? takeNext() {
    if (_pending.isEmpty) return null;
    return _pending.removeAt(0);
  }

  void clearKind(EffectKind kind) {
    _pending.removeWhere((item) => item.kind == kind);
  }
}
