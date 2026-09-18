import 'dart:math' as math;
import 'package:flutter/material.dart';

// Pre-rendered four-pose artwork with layered runtime motion, not a mesh renderer.
enum VipQuality { low, standard, ultra }

class VipThemeV08 {
  const VipThemeV08(this.level, this.name, this.animal, this.accent, this.secondary, this.motif);
  final int level;
  final String name, animal, motif;
  final Color accent, secondary;
  String get id => level.toString().padLeft(2, '0');
  String get sprite => 'assets/vip/vip$id.webp';
  String get background => 'assets/vip/bg$id.webp';
  bool get fullscreen => level >= 6;
  bool get rider => level >= 9;
  Duration get duration => Duration(milliseconds: 2200 + level * 350);
  double get frameWidth => 1.2 + level * .3;
  static VipThemeV08 of(int level) => vipThemesV08[(level.clamp(1, 11) - 1)];
}

const vipThemesV08 = <VipThemeV08>[
  VipThemeV08(1, 'Simple Glow', 'White Fawn', Color(0xFFDADACF), Color(0xFF676D60), 'antler'),
  VipThemeV08(2, 'Shining Edge', 'Royal Fox', Color(0xFFCE7B3E), Color(0xFF632818), 'fox'),
  VipThemeV08(3, 'Elegant Motion', 'Black Panther', Color(0xFF555555), Color(0xFF111111), 'claw'),
  VipThemeV08(4, 'Royal Light', 'White Tiger', Color(0xFFEAE3EF), Color(0xFF78587C), 'stripe'),
  VipThemeV08(5, 'Elite Crown', 'Golden Lion', Color(0xFFEBC36A), Color(0xFF8D581A), 'mane'),
  VipThemeV08(6, 'Diamond Prestige', 'Giant Wolf', Color(0xFFE4E5E5), Color(0xFF6C7478), 'fang'),
  VipThemeV08(7, 'Legendary Flame', 'Armored Lion', Color(0xFFE45729), Color(0xFF741E19), 'flame'),
  VipThemeV08(8, 'Thunder King', 'Thunder Wolf', Color(0xFFE9D6A5), Color(0xFF656364), 'thunder'),
  VipThemeV08(9, 'Black Eagle Rider', 'Black Eagle + Rider', Color(0xFFC7A664), Color(0xFF181818), 'wing'),
  VipThemeV08(10, 'Phoenix Emperor', 'Phoenix + Rider', Color(0xFFFFAE36), Color(0xFFAD2424), 'phoenix'),
  VipThemeV08(11, 'Celestial Dragon Supreme', 'Celestial Dragon + Rider', Color(0xFFEBD07B), Color(0xFF78429E), 'dragon'),
];

class VipAssignmentV08 {
  const VipAssignmentV08({required this.level, this.expiry});
  final int level;
  final DateTime? expiry;
  bool activeAt(DateTime now) => level >= 1 && level <= 11 && (expiry == null || now.isBefore(expiry!));
  Map<String, Object?> toJson() {
    final theme = VipThemeV08.of(level);
    return {'vipLevel': level, 'themeName': theme.name, 'entryId': 'vip${theme.id}_${theme.motif}',
      'frameId': 'frame_${theme.id}', 'badgeId': 'badge_${theme.id}',
      'nameEffectId': 'name_${theme.id}', 'micEffectId': 'mic_${theme.id}',
      'chatBubbleId': 'chat_${theme.id}', 'expiry': expiry?.toUtc().toIso8601String()};
  }
}

class VipSpriteV08 extends StatelessWidget {
  const VipSpriteV08({super.key, required this.level, this.frame = 0, this.quality = VipQuality.standard});
  final int level, frame;
  final VipQuality quality;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final side = math.min(box.maxWidth, box.maxHeight);
    final index = frame % 4;
    return Center(child: SizedBox(width: side, height: side, child: ClipRect(
      child: OverflowBox(maxWidth: side * 2, maxHeight: side * 2,
        alignment: Alignment(index.isEven ? -1 : 1, index < 2 ? -1 : 1),
        child: Image.asset(VipThemeV08.of(level).sprite, width: side * 2, height: side * 2,
          fit: BoxFit.fill, gaplessPlayback: true,
          cacheWidth: quality == VipQuality.low ? 640 : quality == VipQuality.ultra ? 1280 : 960,
          filterQuality: FilterQuality.medium),
      ),
    )));
  });
}

class VipBadgeV08 extends StatelessWidget {
  const VipBadgeV08({super.key, required this.level});
  final int level;
  @override
  Widget build(BuildContext context) {
    final t = VipThemeV08.of(level);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(level > 8 ? 4 : 10),
        gradient: LinearGradient(colors: [t.secondary, const Color(0xFF080808)]),
        border: Border.all(color: t.accent)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 18, height: 18, child: CustomPaint(painter: _VipFramePainter(t, 0, badge: true))),
        const SizedBox(width: 3), Text('VIP $level', style: TextStyle(color: level == 3 ? Colors.white70 : t.accent,
          fontSize: 10, fontWeight: FontWeight.w900)),
      ]));
  }
}

class VipNameV08 extends StatelessWidget {
  const VipNameV08({super.key, required this.level, required this.name});
  final int level;
  final String name;
  @override
  Widget build(BuildContext context) {
    final t = VipThemeV08.of(level);
    return Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(fontWeight: FontWeight.w900, color: level == 3 ? Colors.white70 : t.accent,
        shadows: level == 3 ? null : [Shadow(color: t.secondary, blurRadius: 4 + level.toDouble())]));
  }
}

class VipFrameV08 extends StatelessWidget {
  const VipFrameV08({super.key, required this.level, required this.child, this.size = 70, this.micActive = false});
  final int level;
  final Widget child;
  final double size;
  final bool micActive;
  @override
  Widget build(BuildContext context) {
    final t = VipThemeV08.of(level);
    return SizedBox(width: size, height: size, child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: micActive ? 1 : .5), duration: const Duration(milliseconds: 900),
      builder: (_, value, inner) => CustomPaint(painter: _VipFramePainter(t, value),
        child: Padding(padding: EdgeInsets.all(size * (.12 + level * .002)), child: ClipOval(child: inner))),
      child: child));
  }
}

class _VipFramePainter extends CustomPainter {
  _VipFramePainter(this.t, this.progress, {this.badge = false});
  final VipThemeV08 t;
  final double progress;
  final bool badge;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide * .37;
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = badge ? 1.5 : t.frameWidth;
    line.shader = SweepGradient(colors: [t.secondary, t.accent, t.secondary, t.accent, t.secondary],
      transform: GradientRotation(progress * .5)).createShader(Offset.zero & size);
    canvas.drawCircle(c, r, line);
    if (t.level >= 4) canvas.drawCircle(c, r * 1.12, line..strokeWidth = 1);
    final count = 4 + t.level * 2;
    final fill = Paint()..shader = LinearGradient(colors: [t.secondary, t.accent, t.secondary]).createShader(Offset.zero & size);
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count;
      canvas.save(); canvas.translate(c.dx, c.dy); canvas.rotate(a);
      final path = Path()..moveTo(-r * .11, -r);
      switch (t.motif) {
        case 'antler':
          path..lineTo(0, -r * 1.12)..lineTo(r * .07, -r); break;
        case 'fox':
          path..quadraticBezierTo(-r * .18, -r * 1.3, r * .1, -r * 1.12)..lineTo(r * .13, -r); break;
        case 'claw':
          path..lineTo(r * .09, -r * 1.23)..lineTo(r * .02, -r); break;
        case 'stripe':
          path..lineTo(r * .2, -r * 1.15)..lineTo(r * .06, -r); break;
        case 'mane':
          path..quadraticBezierTo(-r * .15, -r * 1.35, r * .06, -r * 1.25)..lineTo(r * .15, -r); break;
        case 'fang':
          path..lineTo(0, -r * 1.36)..lineTo(r * .12, -r); break;
        case 'flame':
        case 'phoenix':
          path..cubicTo(-r * .3, -r * 1.18, r * .18, -r * 1.27, 0, -r * 1.4)
            ..quadraticBezierTo(r * .3, -r * 1.18, r * .11, -r); break;
        case 'thunder':
          path..lineTo(-r * .1, -r * 1.15)..lineTo(r * .06, -r * 1.14)
            ..lineTo(0, -r * 1.4)..lineTo(r * .22, -r * 1.13)..lineTo(r * .05, -r * 1.12); break;
        case 'wing':
          path..quadraticBezierTo(-r * .2, -r * 1.22, r * .1, -r * 1.36)
            ..quadraticBezierTo(r * .22, -r * 1.12, r * .12, -r); break;
        case 'dragon':
          path..lineTo(-r * .2, -r * 1.35)..lineTo(r * .03, -r * 1.23)
            ..lineTo(r * .15, -r * 1.43)..lineTo(r * .13, -r); break;
      }
      path.close(); canvas.drawPath(path, fill); canvas.restore();
    }
    if (t.level == 5 || t.level >= 9) {
      final crown = Path()..moveTo(c.dx-r*.32,c.dy-r*1.08)..lineTo(c.dx-r*.36,c.dy-r*1.4)
        ..lineTo(c.dx-r*.13,c.dy-r*1.23)..lineTo(c.dx,c.dy-r*1.5)
        ..lineTo(c.dx+r*.13,c.dy-r*1.23)..lineTo(c.dx+r*.36,c.dy-r*1.4)
        ..lineTo(c.dx+r*.32,c.dy-r*1.08)..close();
      canvas.drawPath(crown, fill);
    }
  }
  @override
  bool shouldRepaint(covariant _VipFramePainter old) => old.t != t || old.progress != progress;
}

class VipChatV08 extends StatelessWidget {
  const VipChatV08({super.key, required this.level, required this.message});
  final int level;
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = VipThemeV08.of(level);
    return Container(margin: const EdgeInsets.only(top: 5), padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: t.secondary.withOpacity(.3), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withOpacity(.65))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [VipBadgeV08(level: level),
        const SizedBox(height: 4), Text(message)]));
  }
}

class VipEntryV08 extends StatefulWidget {
  const VipEntryV08({super.key, required this.level, required this.onComplete,
    this.name = 'Mr. WronG', this.quality = VipQuality.standard, this.caption, this.forceFullscreen});
  final int level;
  final String name;
  final String? caption;
  final bool? forceFullscreen;
  final VipQuality quality;
  final VoidCallback onComplete;
  @override
  State<VipEntryV08> createState() => _VipEntryV08State();
}

class _VipEntryV08State extends State<VipEntryV08> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool ready = false, done = false, started = false;
  void finish() { if (!done) { done = true; widget.onComplete(); } }
  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: VipThemeV08.of(widget.level).duration)
      ..addStatusListener((status) { if (status == AnimationStatus.completed) finish(); });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      // Start immediately; image loading stays inside Flutter's shared image cache.
      // Avoid creating unbounded image caches or starting a second entry on rebuild.
      ready = true;
      controller.forward();
    }
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final t = VipThemeV08.of(widget.level);
    final full = widget.forceFullscreen ?? t.fullscreen;
    final reduced = MediaQuery.of(context).disableAnimations;
    final quality = reduced ? VipQuality.low : widget.quality;
    return Align(alignment: Alignment.bottomCenter, child: FractionallySizedBox(
      key: Key('vip-entry-area-${widget.level}'), heightFactor: full ? 1 : .5, widthFactor: 1,
      child: ClipRect(child: Material(color: Colors.black, child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final p = controller.value;
          final entry = Curves.easeOutCubic.transform((p / .34).clamp(0.0, 1.0));
          final exit = ((p - .87) / .13).clamp(0.0, 1.0);
          final opacity = math.min((p / .08).clamp(0.0, 1.0), 1-exit);
          final frame = quality == VipQuality.low ? 0 : ((p * t.duration.inMilliseconds / 230).floor() % 4);
          final shake = quality == VipQuality.ultra && p > .3 && p < .4
              ? math.sin(p * 220) * (widget.level / 6) : 0.0;
          return Opacity(opacity: opacity, child: LayoutBuilder(builder: (context, box) {
            final spriteSide = math.min(box.maxWidth * (.65 + widget.level * .028), box.maxHeight * .72);
            final move = reduced ? 0.0 : (1-entry) * box.maxWidth * (widget.level == 3 ? .25 : .75);
            return Stack(fit: StackFit.expand, children: [
              Transform.scale(scale: reduced ? 1 : 1.08 + p * .10,
                child: Transform.translate(offset: Offset(reduced ? 0 : math.sin(p*math.pi)*(-8-widget.level), 0),
                  child: Image.asset(t.background, fit: BoxFit.cover,
                    cacheWidth: quality == VipQuality.low ? 480 : 960))),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xAA000000), Color(0x30000000), Color(0xDD000000)], stops: [0,.48,1]))),
              if (quality != VipQuality.low) RepaintBoundary(child: CustomPaint(
                painter: _EntryAtmosphere(t, p, quality))),
              Align(alignment: const Alignment(0, -.05), child: Transform.translate(
                offset: Offset(move + shake, reduced ? 0 : -math.sin(entry*math.pi)*18 + exit*30),
                child: Transform(alignment: Alignment.center, transform: Matrix4.identity()
                  ..setEntry(3,2,.001)..rotateY(reduced ? 0 : (1-entry)*-.26)
                  ..scale(reduced ? 1 : .62 + entry*.38),
                  child: SizedBox(width: spriteSide, height: spriteSide,
                    child: VipSpriteV08(level: widget.level, frame: frame, quality: quality))))),
              Positioned(left: 16, top: 12, child: VipBadgeV08(level: widget.level)),
              Positioned(right: 4, top: 0, child: IconButton(key: const Key('close-vip-entry'),
                tooltip: 'Skip entry', onPressed: finish, icon: const Icon(Icons.close, color: Colors.white))),
              Positioned(left: 16, right: 16, bottom: 14, child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(t.animal.toUpperCase(), textAlign: TextAlign.center,
                  style: TextStyle(color: widget.level == 3 ? Colors.white70 : t.accent,
                    fontSize: full ? 22 : 17, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 6),
                Text(widget.caption ?? 'VIP ${widget.level} ${widget.name} entered the room',
                  key: const Key('vip-join-announcement'), textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6), LinearProgressIndicator(value: p, minHeight: 2,
                  color: t.accent, backgroundColor: Colors.white12),
              ])),
            ]);
          }));
        },
      ))),
    ));
  }
}

class _EntryAtmosphere extends CustomPainter {
  _EntryAtmosphere(this.t, this.p, this.quality);
  final VipThemeV08 t;
  final double p;
  final VipQuality quality;
  @override
  void paint(Canvas canvas, Size s) {
    final count = (quality == VipQuality.ultra ? 22 : 10) + t.level * 2;
    final paint = Paint();
    // Panther is deliberately monochrome: only eyes in the artwork shine.
    for(var i=0;i<count;i++) {
      final depth = .25+(i%5)*.15;
      final x = ((i*.618 + p*(.1+depth*.16))%1)*s.width;
      final y = ((i*.371 + (t.level==6 ? p : -p)*(.3+depth*.4))%1)*s.height;
      paint.color = (t.level==3 ? Colors.black : i.isEven ? t.accent : t.secondary).withOpacity(.12+depth*.35);
      if(t.level==2 || t.level==9) {
        canvas.save(); canvas.translate(x,y); canvas.rotate(p*4+i.toDouble());
        canvas.drawOval(Rect.fromCenter(center: Offset.zero,width: 3+depth*4,height: 8+depth*8),paint); canvas.restore();
      } else if(t.level==6 || t.level==11) {
        final crystal=Path()..moveTo(x,y-5*depth)..lineTo(x+3*depth,y)..lineTo(x,y+5*depth)..lineTo(x-3*depth,y)..close();
        canvas.drawPath(crystal,paint);
      } else { canvas.drawCircle(Offset(x,y),1+depth*2,paint); }
    }
    if(t.level==8 && p>.2 && p<.26) {
      final bolt=Path()..moveTo(s.width*.8,0)..lineTo(s.width*.66,s.height*.2)
        ..lineTo(s.width*.74,s.height*.18)..lineTo(s.width*.55,s.height*.5);
      canvas.drawPath(bolt,Paint()..color=t.accent.withOpacity(.7)..style=PaintingStyle.stroke..strokeWidth=2);
    }
    // Layered rolling fog, not a global colour glow.
    final mist=Paint()..shader=RadialGradient(colors:[Colors.grey.withOpacity(t.level==3?.045:.09),Colors.transparent])
      .createShader(Rect.fromLTWH(-s.width*.2,s.height*.6,s.width*1.5,s.height*.4));
    canvas.drawOval(Rect.fromLTWH(-s.width*.2+p*15,s.height*.64,s.width*1.5,s.height*.38),mist);
  }
  @override
  bool shouldRepaint(covariant _EntryAtmosphere old) => old.p!=p || old.t!=t || old.quality!=quality;
}

class VipPreviewV08 extends StatefulWidget {
  const VipPreviewV08({super.key, required this.level, this.quality = VipQuality.standard});
  final int level;
  final VipQuality quality;
  @override
  State<VipPreviewV08> createState()=>_VipPreviewV08State();
}
class _VipPreviewV08State extends State<VipPreviewV08> {
  bool playing=true; int replay=0;
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor: const Color(0xFF160F18),
    body: Stack(children:[SafeArea(child: Column(children:[
      Row(children:[BackButton(onPressed:()=>Navigator.pop(context)),const Text('VIP Entry Preview')]),
      const Spacer(),VipFrameV08(level:widget.level,size:100,child:const ColoredBox(color:Color(0xFF222222),child:Icon(Icons.person,size:45))),
      const SizedBox(height:18),VipNameV08(level:widget.level,name:VipThemeV08.of(widget.level).name),
      const SizedBox(height:18),FilledButton.icon(onPressed:()=>setState(() { playing=true; replay++; }),
        icon:const Icon(Icons.replay),label:const Text('Replay entry')),const Spacer(),
    ])), if(playing) Positioned.fill(child:VipEntryV08(key:ValueKey(replay),level:widget.level,quality:widget.quality,
      onComplete:(){if(mounted)setState(()=>playing=false);})),]));
}
