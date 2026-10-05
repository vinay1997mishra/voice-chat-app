
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../effects/rocket_launch.dart';

class RocketLaunchBanner extends StatefulWidget {
  const RocketLaunchBanner({super.key, required this.level, required this.roomName,
    required this.launchedAt, required this.onEnter, required this.onEnd});
  final int level;
  final String roomName;
  final int launchedAt;
  final VoidCallback onEnter, onEnd;
  @override
  State<RocketLaunchBanner> createState() => _RocketLaunchBannerState();
}

class _RocketLaunchBannerState extends State<RocketLaunchBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  bool _ended = false;
  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: const Duration(seconds: 9))
      ..addListener(() {
        if (!_ended && DateTime.now().millisecondsSinceEpoch >= widget.launchedAt + 9000) {
          _ended = true;
          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) widget.onEnd(); });
        }
      })..repeat();
  }
  @override
  void dispose() { _clock.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) {
      final level = widget.level.clamp(1, 10);
      final seconds = ((widget.launchedAt + 7000 - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 7);
      final accent = Color.lerp(const Color(0xFF65D9FF), const Color(0xFFFFD166), (level - 1) / 9)!;
      final glow = .35 + .25 * math.sin(_clock.value * math.pi * 8).abs();
      return GestureDetector(
        onTap: seconds > 0 ? widget.onEnter : null,
        child: Container(
          key: Key('rocket-launch-banner-level-$level'),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [const Color(0xFF080D18), Color.lerp(const Color(0xFF162C49), const Color(0xFF50300B), level / 10)!, const Color(0xFF080D18)]),
            border: Border.all(color: accent, width: 1 + level * .12),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: glow), blurRadius: 7 + level * 1.2)],
          ),
          child: Row(children: [
            RocketModel(level: level, size: 43, thrust: .8 + .2 * math.sin(_clock.value * 40).abs()),
            const SizedBox(width: 9),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ROCKET $level LAUNCH', maxLines: 1, style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: level >= 6 ? 1.2 : .5)),
              Text(widget.roomName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11)),
              Text(seconds > 0 ? 'Enter within ${seconds}s for audience rewards' : 'Audience entry closed',
                style: const TextStyle(color: Color(0xFFBDD0E5), fontSize: 10)),
            ])),
            if (level >= 4) Icon(Icons.auto_awesome, color: accent, size: 14 + level.toDouble()),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: accent),
          ]),
        ),
      );
    },
  );
}
