import 'effect_queue.dart';

abstract interface class EffectPlayerAdapter {
  String get format;
  Future<void> preload(String asset);
  Future<void> play(String asset);
  Future<void> stop();
}

class LocalEffectPlayer implements EffectPlayerAdapter {
  LocalEffectPlayer(this.format);

  @override
  final String format;

  final Set<String> preloaded = <String>{};
  String? playing;

  @override
  Future<void> preload(String asset) async {
    preloaded.add(asset);
  }

  @override
  Future<void> play(String asset) async {
    preloaded.add(asset);
    playing = asset;
  }

  @override
  Future<void> stop() async {
    playing = null;
  }
}

class EffectRouter {
  EffectRouter({
    EffectPlayerAdapter? svga,
    EffectPlayerAdapter? pag,
    EffectPlayerAdapter? mp4,
    EffectPlayerAdapter? gif,
  })  : svga = svga ?? LocalEffectPlayer('svga'),
        pag = pag ?? LocalEffectPlayer('pag'),
        mp4 = mp4 ?? LocalEffectPlayer('mp4'),
        gif = gif ?? LocalEffectPlayer('gif');

  final EffectPlayerAdapter svga;
  final EffectPlayerAdapter pag;
  final EffectPlayerAdapter mp4;
  final EffectPlayerAdapter gif;

  EffectPlayerAdapter playerFor(String asset) {
    final lower = asset.toLowerCase();
    if (lower.contains('pag') || lower.endsWith('.pag')) return pag;
    if (lower.contains('mp4') || lower.endsWith('.mp4')) return mp4;
    if (lower.contains('gif') || lower.endsWith('.gif')) return gif;
    return svga;
  }

  Future<void> play(EffectRequest request) async {
    final player = playerFor(request.asset);
    await player.preload(request.asset);
    await player.play(request.asset);
  }
}
