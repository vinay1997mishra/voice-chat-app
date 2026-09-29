import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:pag/pag.dart';
import 'package:video_player/video_player.dart';

import 'effect_queue.dart';

class EffectOverlay extends StatefulWidget {
  const EffectOverlay({
    super.key,
    required this.queue,
    required this.enabled,
  });

  final EffectQueue queue;
  final bool enabled;

  @override
  State<EffectOverlay> createState() => _EffectOverlayState();
}

class _EffectOverlayState extends State<EffectOverlay> {
  EffectRequest? current;

  @override
  void initState() {
    super.initState();
    _pump();
  }

  @override
  void didUpdateWidget(covariant EffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pump();
  }

  void _pump() {
    if (!widget.enabled || current != null) return;
    final next = widget.queue.takeNext();
    if (next == null) return;
    current = next;
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => current = null);
      _pump();
    });
  }

  @override
  Widget build(BuildContext context) {
    final effect = current;
    if (!widget.enabled || effect == null) return const SizedBox.shrink();
    final icon = switch (effect.kind) {
      EffectKind.gift => Icons.card_giftcard_rounded,
      EffectKind.entry => Icons.login_rounded,
      EffectKind.vip => Icons.workspace_premium_rounded,
      EffectKind.cp => Icons.favorite_rounded,
      EffectKind.rocket => Icons.rocket_launch_rounded,
      EffectKind.rank => Icons.emoji_events_rounded,
      EffectKind.banner => Icons.campaign_rounded,
    };
    final label = effect.asset.contains(':')
        ? effect.asset.split(':').last.replaceAll('_', ' ')
        : effect.asset;

    final lowerAsset = effect.asset.toLowerCase();
    final isRenderableAsset = lowerAsset.startsWith('https://') &&
        (lowerAsset.endsWith('.svga') || lowerAsset.endsWith('.pag') ||
         lowerAsset.endsWith('.mp4') || lowerAsset.endsWith('.gif'));
    if (isRenderableAsset) {
      return IgnorePointer(
        child: Center(
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * .92,
            height: MediaQuery.sizeOf(context).height * .52,
            child: _BinaryEffectView(key: ValueKey(effect.id), asset: effect.asset),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(effect.id),
          tween: Tween<double>(begin: .45, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.elasticOut,
          builder: (_, value, child) => Transform.scale(
            scale: value,
            child: Opacity(opacity: value.clamp(0, 1), child: child),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const RadialGradient(
                colors: <Color>[Color(0xEE5D3900), Color(0xDD080808)],
              ),
              border: Border.all(color: const Color(0xFFFFD45A), width: 2),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0xAAFFD45A), blurRadius: 30),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 72, color: const Color(0xFFFFD45A)),
                const SizedBox(height: 10),
                Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFE8A3),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _BinaryEffectView extends StatefulWidget {
  const _BinaryEffectView({super.key, required this.asset});
  final String asset;
  @override
  State<_BinaryEffectView> createState() => _BinaryEffectViewState();
}

class _BinaryEffectViewState extends State<_BinaryEffectView> {
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    if (widget.asset.toLowerCase().endsWith('.mp4')) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.asset),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _video = controller;
      controller.initialize().then((_) async {
        if (!mounted) return;
        await controller.setLooping(false);
        await controller.play();
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lower = widget.asset.toLowerCase();
    if (lower.endsWith('.gif')) {
      return Image.network(widget.asset, fit: BoxFit.contain, gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink());
    }
    if (lower.endsWith('.svga')) {
      return SVGAEasyPlayer(resUrl: widget.asset, fit: BoxFit.contain);
    }
    if (lower.endsWith('.pag')) {
      return PAGView.network(widget.asset, autoPlay: true, repeatCount: 1,
        defaultBuilder: (_) => const SizedBox.shrink());
    }
    final video = _video;
    if (video != null && video.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(width: video.value.size.width, height: video.value.size.height,
          child: VideoPlayer(video)),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
