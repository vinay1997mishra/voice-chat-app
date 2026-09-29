import 'package:flutter/material.dart';

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
