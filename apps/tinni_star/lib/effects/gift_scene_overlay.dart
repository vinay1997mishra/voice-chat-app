import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../economy/economy.dart';
import '../economy/premium_gift_catalog.dart';
import 'cinematic_video.dart';

class GiftSceneEvent {
  GiftSceneEvent({required this.gift, required List<String> recipients})
      : recipients = List.unmodifiable(recipients.toSet());
  final GiftDefinition gift;
  final List<String> recipients;
}

class GiftSceneQueue extends ChangeNotifier {
  final _pending = <GiftSceneEvent>[];
  void add(GiftSceneEvent event) {
    _pending.add(event);
    notifyListeners();
  }

  GiftSceneEvent? take() =>
      _pending.isEmpty ? null : _pending.removeAt(0);

  void clear() => _pending.clear();
}

class GiftSceneOverlay extends StatefulWidget {
  const GiftSceneOverlay({
    super.key,
    required this.queue,
    required this.onDelivered,
    this.enabled = true,
  });

  final GiftSceneQueue queue;
  final void Function(GiftSceneEvent) onDelivered;
  final bool enabled;

  @override
  State<GiftSceneOverlay> createState() => _GiftSceneOverlayState();
}

class _GiftSceneOverlayState extends State<GiftSceneOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  GiftSceneEvent? _event;
  Timer? _hold;
  int _generation = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.queue.addListener(_next);
    _next();
  }

  @override
  void didUpdateWidget(covariant GiftSceneOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queue != widget.queue) {
      oldWidget.queue.removeListener(_next);
      _cancel();
      widget.queue.addListener(_next);
    }
    if (!widget.enabled) {
      _cancel();
      widget.queue.clear();
    } else {
      _next();
    }
  }

  void _next() {
    if (!mounted || _event != null || !_foreground) return;
    if (!widget.enabled) {
      widget.queue.clear();
      return;
    }
    final event = widget.queue.take();
    if (event == null) return;
    setState(() => _event = event);
    _motion.duration =
        Duration(seconds: PremiumGiftCatalog.holdSeconds(event.gift.id));
    _motion.value = 0;
    _resume();
  }

  void _resume() {
    if (_event == null || !_foreground || !widget.enabled) return;
    _hold?.cancel();
    final token = ++_generation;
    final remaining = Duration(
      microseconds:
          (_motion.duration!.inMicroseconds * (1 - _motion.value)).round(),
    );
    _motion.forward();
    _hold = Timer(remaining, () {
      if (mounted && token == _generation) _finish();
    });
  }

  void _cancel() {
    _hold?.cancel();
    _hold = null;
    _generation++;
    _motion.stop();
    _event = null;
  }

  void _finish() {
    final event = _event;
    if (!mounted || event == null) return;
    _cancel();
    setState(() {});
    widget.onDelivered(event);
    if (mounted) _next();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _hold?.cancel();
      _generation++;
      _motion.stop();
    } else if (_event != null) {
      _resume();
    } else {
      _next();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    widget.queue.removeListener(_next);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    if (event == null || !widget.enabled) return const SizedBox.shrink();
    final fullScreen = PremiumGiftCatalog.isFullScreen(event.gift.id);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: RepaintBoundary(
        key: ValueKey('gift-scene-' + event.gift.id),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _motion,
              builder: (context, child) {
                final fallback = CustomPaint(
                  painter: _GiftScenePainter(
                    gift: event.gift,
                    t: reduced ? .6 : _motion.value,
                  ),
                  child: const SizedBox.expand(),
                );
                return Center(
                  child: FractionallySizedBox(
                    widthFactor: fullScreen ? 1 : .72,
                    heightFactor: fullScreen ? 1 : .62,
                    child: CinematicVideo(
                      key: ObjectKey(event),
                      sceneId: event.gift.id,
                      duration: _motion.duration!,
                      timeline: _motion,
                      fallback: fallback,
                    ),
                  ),
                );
              },
            ),
            Align(
              alignment: const Alignment(0, .65),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(event.gift.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(blurRadius: 8)],
                        )),
                    Text(
                      'To ' + event.recipients.map((id) => 'ID $id').join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFD479),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _GiftScenePainter extends CustomPainter {
  const _GiftScenePainter({required this.gift,required this.t});
  final GiftDefinition gift;
  final double t;
  @override void paint(Canvas canvas,Size size) {
    final scene=PremiumGiftCatalog.scene(gift.id);
    final tier=(gift.price/10000000).clamp(.02,1.0);
    final entrance=(t/.14).clamp(0.0,1.0);
    final fade=t>.94?((1-t)/.06).clamp(0.0,1.0):1.0;
    final center=Offset(size.width/2,size.height*.46);
    final fullScreen=PremiumGiftCatalog.isFullScreen(gift.id);
    final radius=math.min(size.width*(fullScreen ? .48 : .30),fullScreen?310.0:140.0);
    canvas.drawRect(Offset.zero&size,Paint()..color=Color.fromRGBO(2,8,20,.55*entrance*fade));
    final glow=Rect.fromCircle(center:center,radius:radius*1.5);
    canvas.drawOval(glow,Paint()..shader=RadialGradient(colors:[
      Color.fromRGBO(116,65,199,.5*entrance*fade),const Color(0x00040815),
    ]).createShader(glow));
    for(var i=0;i<18+(tier*80).round();i++) {
      final a=i*2.399+t*math.pi;
      final r=radius*(.45+(i%9)/8);
      canvas.drawCircle(center+Offset(math.cos(a)*r,math.sin(a)*r),
        1.3+(i%3),Paint()..color=Color.fromRGBO(255,204,128,fade*(.2+.5*math.sin(i+t*12).abs())));
    }
    canvas.save();
    canvas.translate(center.dx,center.dy);
    canvas.scale(entrance);
    if(scene=='food') { _food(canvas,radius,fade); }
    else if(scene=='rose') { _roses(canvas,radius,fade); }
    else if(scene=='dragon') { _dragon(canvas,radius,size,fade); }
    else if(scene=='couple'||scene=='wedding') { _couple(canvas,radius,scene=='wedding'); }
    else {
      _text(canvas,gift.emoji,Offset.zero,radius*.95);
      if(scene=='flag') {
        for(var i=0;i<8;i++) {
          final wave=math.sin(t*20+i)*6;
          canvas.drawLine(Offset(-radius+i*radius/4,-radius*.7+wave),
            Offset(-radius+i*radius/4,radius*.5+wave),
            Paint()..color=Colors.white.withValues(alpha:.08)..strokeWidth=3);
        }
      }
      if(scene=='love') { _text(canvas,'💍',Offset(math.sin(t*6)*radius*.5,radius*.35),radius*.45); }
    }
    canvas.restore();
  }
  void _text(Canvas c,String text,Offset point,double fontSize) {
    final p=TextPainter(text:TextSpan(text:text,style:TextStyle(fontSize:fontSize)),textDirection:TextDirection.ltr)..layout();
    p.paint(c,point-Offset(p.width/2,p.height/2));
  }
  void _food(Canvas c,double r,double fade) {
    final plate=Rect.fromCenter(center:Offset(0,r*.2),width:r*1.6,height:r*.65);
    c.drawOval(plate,Paint()..shader=const LinearGradient(colors:[
      Color(0xFFFFFFFF),Color(0xFF7B8CA1),Color(0xFFEEF6FF),
    ]).createShader(plate));
    final bowl=Rect.fromCenter(center:Offset.zero,width:r*1.25,height:r*.7);
    c.drawOval(bowl,Paint()..shader=const RadialGradient(colors:[
      Color(0xFFFFD382),Color(0xFFA65C21),Color(0xFF3B1808),
    ]).createShader(bowl));
    for(var i=0;i<80;i++) {
      final a=i*2.4,rr=math.sqrt(i/80)*r*.5;
      final pos=Offset(math.cos(a)*rr,math.sin(a)*rr*.45);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:pos,width:7,height:2),const Radius.circular(1)),
        Paint()..color=i%4==0?const Color(0xFF58A54B):const Color(0xFFFFE0A0));
    }
    for(var i=0;i<6;i++) {
      final path=Path();
      final x=(i-2.5)*r*.15;
      path.moveTo(x,-r*.1);
      path.cubicTo(x+r*.15*math.sin(t*20+i),-r*.4,x-r*.15,-r*.65,x+r*.08*math.sin(t*16),-r*.95);
      c.drawPath(path,Paint()..color=Colors.white.withValues(alpha:.26*fade)..style=PaintingStyle.stroke..strokeWidth=4..maskFilter=const MaskFilter.blur(BlurStyle.normal,3));
    }
  }
  void _roses(Canvas c,double r,double fade) {
    final wrap=Path()..moveTo(-r*.65,0)..lineTo(0,r*.8)..lineTo(r*.65,0)..close();
    c.drawPath(wrap,Paint()..shader=const LinearGradient(colors:[
      Color(0xFF44326C),Color(0xFFDFC184),Color(0xFF382248),
    ]).createShader(Rect.fromCircle(center:Offset.zero,radius:r)));
    for(var i=0;i<13;i++) {
      final a=i*2.4,rr=math.sqrt(i/13)*r*.5;
      final pos=Offset(math.cos(a)*rr,math.sin(a)*rr*.6-r*.15);
      for(var petal=0;petal<9;petal++) {
        final angle=petal*2.4;
        final p=pos+Offset(math.cos(angle),math.sin(angle))*(petal*1.4);
        c.drawOval(Rect.fromCenter(center:p,width:r*.24-petal,height:r*.20-petal),
          Paint()..shader=RadialGradient(colors:[
            Color.lerp(const Color(0xFFFFB8C9),const Color(0xFFFF174C),petal/9)!,
            const Color(0xFF7C0829),
          ]).createShader(Rect.fromCircle(center:p,radius:r*.14)));
      }
    }
    for(var i=0;i<7;i++) {
      final phase=(t*2+i/7)%1;
      final pos=Offset(math.sin(phase*7+i)*r*.7,-r*.25-phase*r);
      c.drawCircle(pos,r*.035,Paint()..color=const Color(0xFFFFC8E2).withValues(alpha:(1-phase)*.5*fade));
    }
  }
  void _dragon(Canvas c,double r,Size size,double fade) {
    c.save();c.translate(0,-size.height*.7*(1-(t/.28).clamp(0.0,1.0)));
    final flap=math.sin(t*40)*r*.2;
    for(final side in [-1.0,1.0]) {
      final wing=Path()..moveTo(0,-r*.1)..lineTo(side*r*.95,-r*.6+flap)
        ..lineTo(side*r*.80,r*.0)..lineTo(side*r*.4,-r*.1)..close();
      c.drawPath(wing,Paint()..shader=const LinearGradient(colors:[
        Color(0xFFFFCD62),Color(0xFFAB411D),Color(0xFF441013),
      ]).createShader(Rect.fromCircle(center:Offset.zero,radius:r)));
      c.drawPath(wing,Paint()..color=const Color(0xFFFFE4A0)..style=PaintingStyle.stroke..strokeWidth=2);
    }
    final body=Path()..moveTo(0,-r*.65)..cubicTo(r*.65,-r*.1,-r*.55,r*.45,0,r*.8);
    c.drawPath(body,Paint()..style=PaintingStyle.stroke..strokeWidth=r*.20..strokeCap=StrokeCap.round..shader=const LinearGradient(
      colors:[Color(0xFFFFE4A0),Color(0xFFDC7C20),Color(0xFF55281B)],
    ).createShader(Rect.fromCircle(center:Offset.zero,radius:r)));
    _text(c,'🐉',Offset(0,-r*.35),r*.65);
    c.restore();
  }
  void _couple(Canvas c,double r,bool wedding) {
    final meet=(t/.45).clamp(0.0,1.0);
    final kiss=((t-.6)/.25).clamp(0.0,1.0);
    final gap=r*(1-meet)*1.5+r*(.22-.10*kiss);
    if(wedding) {
      c.drawArc(Rect.fromCircle(center:Offset.zero,radius:r*.95),math.pi,math.pi,false,
        Paint()..style=PaintingStyle.stroke..strokeWidth=8..color=const Color(0xFFE7C78B));
      for(var i=0;i<12;i++) { _text(c,'🌹',Offset(math.cos(i/11*math.pi)*r*.95,-math.sin(i/11*math.pi)*r*.95),r*.15); }
    }
    void person(double x,bool girl) {
      c.drawCircle(Offset(x,-r*.36),r*.12,Paint()..color=const Color(0xFFE5AF8F));
      c.drawArc(Rect.fromCircle(center:Offset(x,-r*.38),radius:r*.14),math.pi,math.pi,false,
        Paint()..strokeWidth=girl?12:8..style=PaintingStyle.stroke..color=const Color(0xFF27141C));
      final torso=Path()..moveTo(x-r*.09,-r*.20)..lineTo(x-r*(girl ? .23 : .12),r*.35)..lineTo(x+r*(girl ? .23 : .12),r*.35)..lineTo(x+r*.09,-r*.20)..close();
      c.drawPath(torso,Paint()..color=girl?(wedding?const Color(0xFFFFF5E9):const Color(0xFFE666B4)):const Color(0xFF263B65));
      c.drawLine(Offset(x,-r*.10),Offset(x>0?0:r*.02,0),Paint()..color=const Color(0xFFE5AF8F)..strokeWidth=6..strokeCap=StrokeCap.round);
      for(final d in [-1.0,1.0]) { c.drawLine(Offset(x+d*r*.06,r*.3),Offset(x+d*r*.08,r*.65),Paint()..color=const Color(0xFF253348)..strokeWidth=7); }
    }
    person(-gap,false);person(gap,true);
    if(t>.6) {
      c.save();c.translate(0,-r*.38);c.scale(1+math.sin(t*25)*.1);
      _text(c,'💋',Offset.zero,r*.28);c.restore();
      for(var i=0;i<6;i++) { _text(c,'💗',Offset(math.sin(i*2+t*8)*r*.7,-r*.5-((t*2+i/6)%1)*r*.7),r*.16); }
    }
  }
  @override bool shouldRepaint(_GiftScenePainter old)=>old.t!=t||old.gift.id!=gift.id;
}
