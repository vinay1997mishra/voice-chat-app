import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../ui/lucky_gift_art.dart';
import '../economy/economy.dart';
import 'cinematic_lane.dart';
import 'lucky_gift_queue.dart';

String luckyCoins(int amount) => amount.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');

class LuckyGiftOverlay extends StatefulWidget {
  const LuckyGiftOverlay({super.key, required this.queue, this.lane,
    this.enabled = true, this.reserveCombo = false, this.onStarted});
  final LuckyGiftQueue queue;
  final CinematicLane? lane;
  final bool enabled;
  final bool reserveCombo;
  final void Function(LuckyGiftPresentation presentation)? onStarted;
  @override
  State<LuckyGiftOverlay> createState() => _LuckyGiftOverlayState();
}

class _LuckyGiftOverlayState extends State<LuckyGiftOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ticker;
  Timer? _wake;
  bool _foreground = true;
  final _started = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_changed);
    widget.queue.addListener(_changed);
    widget.lane?.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(covariant LuckyGiftOverlay old) {
    super.didUpdateWidget(old);
    if (old.queue != widget.queue) {
      old.queue.removeListener(_changed);
      widget.queue.addListener(_changed);
      _started.clear();
    }
    if (old.lane != widget.lane) {
      old.lane?.removeListener(_changed);
      widget.lane?.addListener(_changed);
    }
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _changed();
  }

  void _changed() {
    if (!mounted) return;
    _wake?.cancel();
    _wake = null;
    widget.queue.prune();
    if (!widget.enabled || !_foreground || widget.queue.pending.isEmpty) {
      _ticker.stop();
      if (mounted) setState(() {});
      return;
    }
    final next = widget.queue.pending.first;
    final until = next.startedAtMs - widget.queue.clock();
    if (until > 0) {
      _ticker.stop();
      _wake = Timer(Duration(milliseconds: until), _changed);
    } else {
      if (!_ticker.isAnimating) _ticker.repeat();
      if (_started.add(next.event.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.enabled && _foreground) widget.onStarted?.call(next);
        });
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _wake?.cancel();
    widget.queue.removeListener(_changed);
    widget.lane?.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_foreground || widget.queue.pending.isEmpty) {
      return const SizedBox.expand();
    }
    final presentation = widget.queue.pending.first;
    final frame = presentation.frameAt(widget.queue.clock());
    if (frame == null) return const SizedBox.expand();
    final event = presentation.event;
    final result = frame.result;
    final tier = luckyTierFor(result?.multiplier ?? 0);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final primaryBusy = widget.lane?.busy ?? false;
    final celebrate = event.bannersEnabled && result != null && result.multiplier >= 200;
    final ultra = celebrate && (tier == LuckyBubbleTier.ultra || event.ultraWin);
    final progress = reduced ? .48 : frame.progress;
    final palette = LuckyGiftArt.paletteFor(event.giftId);
    final winTitle = !event.bannersEnabled ? null : event.ultraWin ? 'ULTRA WIN' :
        event.bannerWin ? 'LUCKY JACKPOT' : event.highWin ? 'BIG WIN' : null;

    return IgnorePointer(
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        // The sender's interactive Combo occupies the right edge. Keep the
        // multiplier and win title in the remaining space on every phone size.
        final reserve = widget.reserveCombo && !primaryBusy ? 140.0 : 0.0;
        final bubbleWidth = math.max(80.0, width - reserve);
        final extent = math.min(
          bubbleWidth * (primaryBusy ? .30 : reserve > 0 ? .4 + tier.index * .1 : .91),
          <double>[78, 112, 152, 194, 238, 288, 350][tier.index]);
        final bubbleY = primaryBusy ? height * .24 : height * .34;
        final hudY = primaryBusy ? height * .72 : height * .49;
        return Stack(clipBehavior: Clip.hardEdge, children: [
          if (ultra && !primaryBusy && !reduced)
            Positioned.fill(
              key: const Key('lucky-fullscreen-celebration'),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: RadialGradient(colors: [
                  const Color(0xB33D185E), const Color(0xAA110B24),
                  const Color(0xAA000000),
                ])),
                child: CustomPaint(painter: _LuckyBurstPainter(
                  progress: progress, strength: 7, color: const Color(0xFFFFD866))),
              ),
            ),
          if (result != null)
            Positioned(
              left: (bubbleWidth - extent) / 2 + (reduced ? 0 : math.sin(progress * math.pi) * 9),
              top: bubbleY - extent / 2 - (reduced ? 0 : progress * (primaryBusy ? 28 : 86)),
              width: extent, height: extent,
              child: Opacity(
                opacity: reduced ? 1 : math.min(1, math.min(progress * 8 + .1, (1 - progress) * 6)).clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(
                  scale: reduced ? 1 : .70 + .30 * Curves.easeOutBack.transform(math.min(1.0, progress * 4)),
                  child: _LuckyBubble(
                    key: ValueKey('lucky-bubble-${event.id}-${result.multiplier}-${frame.elapsedMs - (frame.progress * result.durationMs).round()}'),
                    result: result, tier: tier, progress: progress,
                    palette: palette, animate: !reduced,
                    celebrate: celebrate && !primaryBusy,
                  ),
                ),
              ),
            ),
          if (winTitle != null && !primaryBusy)
            Positioned(left: 12, right: reserve + 12, top: height * .14,
              child: FittedBox(fit: BoxFit.scaleDown,
                child: Text(winTitle, key: const Key('lucky-big-win-banner'),
                  textAlign: TextAlign.center, style: TextStyle(
                    fontSize: ultra ? 30 : 24, fontWeight: FontWeight.w900,
                    color: const Color(0xFFFFE99B), letterSpacing: 2,
                    shadows: [Shadow(color: palette[0], blurRadius: 24)])))),
          Positioned(left: width * .04, right: width * .04, top: hudY,
            child: Semantics(
              label: '${event.senderName} sent ${event.giftName}, quantity ${event.quantity}, '
                  '${event.sentCoins} coins. Lucky return ${event.rebateCoins} coins to the sender.',
              child: Container(
                key: const Key('lucky-center-banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(colors: [
                    palette[1].withValues(alpha: .95), const Color(0xF5161230),
                    palette[0].withValues(alpha: .80),
                  ]),
                  border: Border.all(color: const Color(0xFFFFD977), width: 1.5),
                  boxShadow: [BoxShadow(color: palette[0].withValues(alpha: .40),
                    blurRadius: reduced ? 8 : 22, spreadRadius: 1)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    SizedBox(width: primaryBusy ? 44 : 58, height: primaryBusy ? 44 : 58,
                      child: presentation.gift.artworkAsset == null ?
                        LuckyGiftArt(giftId: event.giftId, size: 52) :
                        Image.asset(presentation.gift.artworkAsset!, fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => LuckyGiftArt(giftId: event.giftId, size: 52))),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(event.senderName.isEmpty ? 'ID ${event.senderId}' : event.senderName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFC9BDE8), fontSize: 10)),
                      Text(event.giftName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                      Text('Gift ×${event.quantity}', key: const Key('lucky-hud-quantity'),
                        style: const TextStyle(color: Color(0xFFFFE994), fontSize: 12, fontWeight: FontWeight.w800)),
                    ])),
                    const SizedBox(width: 6),
                    Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('TOTAL RETURN', style: TextStyle(color: Color(0xFFC9BDE8), fontSize: 9)),
                      FittedBox(fit: BoxFit.scaleDown, child: Text(luckyCoins(event.rebateCoins),
                        key: const Key('lucky-total-return'),
                        style: const TextStyle(color: Color(0xFFFFE989), fontSize: 19, fontWeight: FontWeight.w900))),
                    ])),
                  ]),
                  const SizedBox(height: 6),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(
                    'Sent: ${luckyCoins(event.sentCoins)}  →  Won: ${luckyCoins(frame.revealedCoins)}',
                    key: const Key('lucky-reward-coins'),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
                  if (!primaryBusy) ...[
                    const SizedBox(height: 4),
                    Text(event.rebateCoins == 0 ? '0× · No return this send' :
                        presentation.zeroCount > 0 ? '${presentation.zeroCount} units returned 0× · rewards go to sender' :
                        'Lucky rewards go to sender',
                      key: const Key('lucky-return-status'),
                      style: const TextStyle(color: Color(0xFFD9CDEC), fontSize: 10)),
                  ],
                ]),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _LuckyBubble extends StatelessWidget {
  const _LuckyBubble({super.key, required this.result, required this.tier,
    required this.progress, required this.palette, required this.animate, required this.celebrate});
  final LuckyBubbleResult result;
  final LuckyBubbleTier tier;
  final double progress;
  final List<Color> palette;
  final bool animate;
  final bool celebrate;
  @override
  Widget build(BuildContext context) {
    final won = result.multiplier > 0;
    final strength = won ? tier.index + 1 : 0;
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      if (animate && strength >= 3)
        Positioned.fill(child: CustomPaint(painter: _LuckyBurstPainter(
          progress: progress, strength: celebrate ? strength : 2,
          color: const Color(0xFFFFD977)))),
      Container(
        key: Key('lucky-tier-${tier.name}'),
        width: double.infinity, height: double.infinity,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: const Alignment(-.25, -.3), colors: [
            won ? const Color(0xFFFFF3C3) : const Color(0xFF667085),
            won ? palette[0] : const Color(0xFF343E56),
            won ? palette[1] : const Color(0xFF182239),
          ]),
          border: Border.all(color: won ? const Color(0xFFFFE39D) : const Color(0xFF8290AB),
            width: 1.5 + strength * .5),
          boxShadow: [BoxShadow(color: (won ? palette[0] : Colors.blueGrey).withValues(alpha: .65),
            blurRadius: 8.0 + strength * 5, spreadRadius: strength.toDouble())],
        ),
        child: Padding(padding: const EdgeInsets.all(10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text('×${result.multiplier}',
              key: const Key('lucky-active-multiplier'),
              style: TextStyle(color: Colors.white, fontSize: 23.0 + strength * 5,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Color(0xAA320C36), blurRadius: 9)]))),
            if (result.count > 1)
              FittedBox(child: Text('${luckyCoins(result.count)} results',
                key: const Key('lucky-bubble-result-count'),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ])),
      ),
      if (celebrate && tier.index >= LuckyBubbleTier.premium.index)
        Align(alignment: const Alignment(0, 1.1),
          child: FittedBox(child: Text('+${luckyCoins(result.coins)}',
            style: const TextStyle(color: Color(0xFFFFE684), fontSize: 18, fontWeight: FontWeight.w900)))),
    ]);
  }
}

class _LuckyBurstPainter extends CustomPainter {
  _LuckyBurstPainter({required this.progress, required this.strength, required this.color});
  final double progress;
  final int strength;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * (.14 + progress * .55);
    final alpha = math.sin(math.pi * progress).clamp(0.0, 1.0).toDouble();
    final paint = Paint()..color = color.withValues(alpha: alpha * .8);
    for (var i = 0; i < 8 + strength * 8; i++) {
      final angle = i * 2 * math.pi / (8 + strength * 8) + progress * .25;
      final distance = radius * (.7 + (i % 4) * .12);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final length = 2.5 + (i % 3) + strength * .7;
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + progress * 2);
      final path = Path()..moveTo(0, -length)..lineTo(length * .4, 0)
        ..lineTo(0, length)..lineTo(-length * .4, 0)..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
    if (strength >= 4) {
      paint..style = PaintingStyle.stroke..strokeWidth = 1.5;
      canvas.drawCircle(center, radius * .85, paint);
      canvas.drawCircle(center, radius * 1.05, paint..color = color.withValues(alpha: alpha * .4));
    }
  }
  @override
  bool shouldRepaint(covariant _LuckyBurstPainter old) =>
      old.progress != progress || old.strength != strength || old.color != color;
}

class LuckyComboPanel extends StatelessWidget {
  const LuckyComboPanel({super.key, required this.gift, required this.quantity,
    required this.count, required this.wonCoins, required this.sentCoins,
    required this.highest, required this.secondsLeft, required this.loading,
    required this.onSend, this.avatar, this.poolCoins = 0});
  final GiftDefinition gift;
  final int quantity, count, wonCoins, sentCoins, highest, secondsLeft;
  final bool loading;
  final VoidCallback onSend;
  final ImageProvider? avatar;
  final int poolCoins;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(width: 116, padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xF541174F), Color(0xF515102E)]),
        border: Border.all(color: const Color(0xFFFFD875), width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0x557C34A8), blurRadius: 14)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (avatar != null) ...[
            CircleAvatar(radius: 10, backgroundImage: avatar),
            const SizedBox(width: 4),
          ],
          SizedBox(width: 24, height: 24,
            child: gift.artworkAsset == null ? LuckyGiftArt(giftId: gift.id, size: 24) :
              Image.asset(gift.artworkAsset!, fit: BoxFit.contain,
                errorBuilder: (_, _, _) => LuckyGiftArt(giftId: gift.id, size: 24))),
          const SizedBox(width: 4),
          Text('×$quantity', style: const TextStyle(color: Color(0xFFFFDE8F),
            fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 4),
        Text(gift.name, textAlign: TextAlign.center, maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        FittedBox(child: Text('Gifts ×${luckyCoins(count)}', key: const Key('lucky-combo-gift-count'),
          style: const TextStyle(color: Color(0xFFD8C9ED), fontSize: 10))),
        FittedBox(child: Text('Won ${luckyCoins(wonCoins)}', key: const Key('lucky-combo-won'),
          style: const TextStyle(color: Color(0xFFFFDF85), fontSize: 12, fontWeight: FontWeight.w900))),
        FittedBox(child: Text('Sent ${luckyCoins(sentCoins)}',
          style: const TextStyle(color: Color(0xFFD8C9ED), fontSize: 9))),
        Text('Highest ×$highest', style: const TextStyle(color: Color(0xFFD8C9ED), fontSize: 9)),
        if (poolCoins > 0) FittedBox(child: Text('Pool ${luckyCoins(poolCoins)}',
          style: const TextStyle(color: Color(0xFFD8C9ED), fontSize: 9))),
        const SizedBox(height: 7),
        Semantics(button: true, label: 'Send ${gift.name} quantity $quantity again',
          child: InkResponse(key: const Key('lucky-combo-button'),
            onTap: loading ? null : onSend, radius: 30,
            child: Container(width: 54, height: 54, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: const RadialGradient(center: Alignment(-.25, -.3),
                  colors: [Color(0xFFFFF1A3), Color(0xFFFFB431), Color(0xFFD86035)]),
                border: Border.all(color: const Color(0xFFFFEBB0), width: 1.5),
                boxShadow: const [BoxShadow(color: Color(0x88FFA733), blurRadius: 12)]),
              child: loading ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) :
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('COMBO', style: TextStyle(color: Color(0xFF4B1C19),
                    fontSize: 10, fontWeight: FontWeight.w900)),
                  Text('${secondsLeft}s', key: const Key('lucky-combo-countdown'),
                    style: const TextStyle(color: Color(0xFF4B1C19), fontSize: 10, fontWeight: FontWeight.w900)),
                ]),
            ))),
      ]),
    ),
  );
}
