import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The ten server-backed gift milestones, expressed as incremental targets.
const rocketStageTargets = <int>[
  8000000,15000000,30000000,50000000,90000000,
  150000000,200000000,250000000,350000000,500000000,
];
int completedRocketStages(int total) {
  var completed=0;
  for(final target in rocketStageTargets) {
    if(total<target) break;
    total-=target;completed++;
  }
  return completed;
}

class RocketModel extends StatelessWidget {
  const RocketModel({super.key,required this.level,this.size=100,this.thrust=0});
  final int level;
  final double size,thrust;
  @override Widget build(BuildContext context)=>Semantics(
    label:'Rocket level $level of 10',
    child:CustomPaint(size:Size(size,size*1.55),
      painter:RocketModelPainter(level:level,thrust:thrust)),
  );
}

class RocketModelPainter extends CustomPainter {
  const RocketModelPainter({required this.level,this.thrust=0});
  final int level;
  final double thrust;
  @override void paint(Canvas canvas,Size size) {
    final w=size.width,h=size.height;
    final tier=level.clamp(1,10);
    final accent=Color.lerp(const Color(0xFF62DFFF),const Color(0xFFFFD479),(tier-1)/9)!;
    canvas.save();canvas.scale(w/100,h/155);
    void metal(Rect r,{double radius=4}) {
      canvas.drawRRect(RRect.fromRectAndRadius(r,Radius.circular(radius)),
        Paint()..shader=const LinearGradient(colors:[
          Color(0xFF28354A),Color(0xFFEDF6FF),Color(0xFF768AA6),Color(0xFF142033),
        ],stops:[0,.35,.62,1]).createShader(r));
      canvas.drawRRect(RRect.fromRectAndRadius(r,Radius.circular(radius)),
        Paint()..style=PaintingStyle.stroke..strokeWidth=.8..color=accent);
    }
    void engine(double x,double y,double width) {
      metal(Rect.fromLTWH(x-width/2,y,width,8),radius:2);
      if(thrust<=0) return;
      final flame=Path()..moveTo(x-width/2,y+7)..quadraticBezierTo(x-width,y+20,x,y+22+26*thrust)
        ..quadraticBezierTo(x+width,y+20,x+width/2,y+7)..close();
      canvas.drawPath(flame,Paint()..shader=LinearGradient(
        begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[Colors.white,accent,const Color(0xFFFFA02F),const Color(0x00FF4920)],
      ).createShader(Rect.fromLTWH(x-width,y,2*width,55)));
    }
    // Every new tier adds distinct hardware to the preceding design.
    if(tier>=3) {
      for(final x in [25.0,75.0]) {
        metal(Rect.fromLTWH(x-7,49,14,61));
        final nose=Path()..moveTo(x-7,50)..quadraticBezierTo(x-5,35,x,28)..quadraticBezierTo(x+5,35,x+7,50)..close();
        canvas.drawPath(nose,Paint()..color=accent);
        engine(x,107,12);
      }
    }
    if(tier>=7) {
      for(final x in [10.0,90.0]) {
        metal(Rect.fromLTWH(x-5,63,10,48));
        engine(x,109,9);
      }
    }
    metal(const Rect.fromLTWH(36,31,28,77),radius:10);
    final nose=Path()..moveTo(36,40)..quadraticBezierTo(36,22,50,5)..quadraticBezierTo(64,22,64,40)..close();
    canvas.drawPath(nose,Paint()..shader=LinearGradient(colors:[
      const Color(0xFF17283E),accent,const Color(0xFF40546F),
    ]).createShader(const Rect.fromLTWH(36,5,28,35)));
    canvas.drawCircle(const Offset(50,48),6,Paint()..color=const Color(0xFF092840));
    canvas.drawCircle(const Offset(49,46),3,Paint()..color=accent);
    if(tier>=2) {
      final fins=Path()..moveTo(36,80)..lineTo(20,111)..lineTo(37,103)
        ..moveTo(64,80)..lineTo(80,111)..lineTo(63,103);
      canvas.drawPath(fins,Paint()..color=accent);
    }
    if(tier>=4) for(final y in [66.0,92.0]) {
      canvas.drawRect(Rect.fromLTWH(35,y,30,3),Paint()..color=accent);
    }
    if(tier>=5) {
      metal(const Rect.fromLTWH(40,58,20,9),radius:2);
    }
    if(tier>=6) {
      for(final x in [40.0,60.0]) {
        canvas.drawLine(Offset(x,70),Offset(x,90),Paint()..color=accent..strokeWidth=2);
      }
    }
    if(tier>=8) {
      for(final x in [18.0,69.0]) {
        metal(Rect.fromLTWH(x,54,13,8),radius:1);
      }
    }
    if(tier>=9) {
      for(final y in [73.0,83.0,98.0]) {
        canvas.drawCircle(Offset(39,y),1.5,Paint()..color=accent);
        canvas.drawCircle(Offset(61,y),1.5,Paint()..color=accent);
      }
    }
    if(tier>=10) {
      canvas.drawLine(const Offset(50,5),const Offset(50,0),Paint()..color=accent..strokeWidth=2);
      metal(const Rect.fromLTWH(43,99,14,8),radius:1);
    }
    final label=TextPainter(text:TextSpan(text:'$tier',style:const TextStyle(
      fontSize:12,color:Color(0xFF091525),fontWeight:FontWeight.w900)),textDirection:TextDirection.ltr)..layout();
    label.paint(canvas,Offset(50-label.width/2,76));
    engine(50,106,22);
    canvas.restore();
  }
  @override bool shouldRepaint(RocketModelPainter old)=>old.level!=level||old.thrust!=thrust;
}

/// Each newly completed stage launches once; opening a room never replays history.
class RocketLaunchOverlay extends StatefulWidget {
  const RocketLaunchOverlay({super.key,required this.completed, this.enabled=true});
  final ValueNotifier<int?> completed;
  final bool enabled;
  @override State<RocketLaunchOverlay> createState()=>_RocketLaunchOverlayState();
}
class _RocketLaunchOverlayState extends State<RocketLaunchOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _flight;
  final _queue=<int>[];
  int? _seen;
  int? _level;
  @override void initState() {
    super.initState();
    _seen=widget.completed.value;
    _flight=AnimationController(vsync:this,duration:const Duration(seconds:9))
      ..addStatusListener((status){if(status==AnimationStatus.completed) _next();});
    widget.completed.addListener(_changed);
  }
  void _changed() {
    final next=widget.completed.value;
    if(next==null) return;
    final previous=_seen;
    _seen=next;
    if(previous==null||next<=previous||!widget.enabled) return;
    for(var level=previous+1;level<=next&&level<=10;level++) _queue.add(level);
    if(_level==null) _next();
  }
  void _next() {
    if(!mounted) return;
    setState(()=>_level=_queue.isEmpty?null:_queue.removeAt(0));
    if(_level!=null) _flight.forward(from:0);
  }
  @override void dispose() {
    widget.completed.removeListener(_changed);_flight.dispose();super.dispose();
  }
  @override Widget build(BuildContext context) {
    if(_level==null) return const SizedBox.shrink();
    return IgnorePointer(child:RepaintBoundary(child:AnimatedBuilder(
      animation:_flight,builder:(context,child)=>LayoutBuilder(builder:(context,c) {
        final t=_flight.value;
        // Ignition 0-1.8s, slow liftoff to 4.5s, accelerating vertical ascent to 9s.
        final ascent=((t-.20)/.80).clamp(0.0,1.0);
        final rise=ascent*ascent;
        final width=math.min(c.maxWidth*.30,140.0);
        final y=c.maxHeight*.60-rise*(c.maxHeight+width*2);
        final thrust=(t/.18).clamp(0.0,1.0)*(0.90+0.10*math.sin(t*180));
        return Stack(key:const Key('rocket-nine-second-launch'),children:[
          Positioned.fill(child:CustomPaint(painter:_LaunchAtmosphere(
            t:t,level:_level!,padY:c.maxHeight*.60+width*1.18))),
          Positioned(top:36,left:16,right:16,child:Opacity(
            opacity:(1-t).clamp(0.0,1.0),child:Column(children:[
              Text('ROCKET $_level / 10',style:const TextStyle(color:Color(0xFFFFD479),fontSize:25,fontWeight:FontWeight.w900,letterSpacing:3)),
              const Text('100% • LAUNCH',style:TextStyle(color:Colors.white,fontSize:13,letterSpacing:4)),
            ]))),
          Positioned(top:y,left:(c.maxWidth-width)/2,child:RocketModel(
            key:ValueKey('launch-rocket-$_level'),level:_level!,size:width,thrust:thrust)),
        ]);
      }),
    )));
  }
}
class _LaunchAtmosphere extends CustomPainter {
  const _LaunchAtmosphere({required this.t,required this.level,required this.padY});
  final double t,padY;
  final int level;
  @override void paint(Canvas canvas,Size size) {
    final intensity=(1-t).clamp(0.0,1.0);
    canvas.drawRect(Offset.zero&size,Paint()..color=Color.fromRGBO(3,9,20,.55*intensity));
    final cx=size.width/2;
    final plume=(t/.2).clamp(0.0,1.0);
    final smoke=Paint();
    for(var i=0;i<22+level*3;i++) {
      final angle=i*2.39996;
      final spread=(12+i*2.0)*(1+t*3);
      final x=cx+math.cos(angle)*spread;
      final y=padY+math.sin(angle)*spread*.25;
      final r=(9+(i%5)*3+level)*plume;
      smoke.shader=RadialGradient(colors:[
        Color.fromRGBO(223,233,246,.40*intensity),const Color(0x008899AA),
      ]).createShader(Rect.fromCircle(center:Offset(x,y),radius:r));
      canvas.drawCircle(Offset(x,y),r,smoke);
    }
    final glow=Rect.fromCenter(center:Offset(cx,padY),width:160+level*8,height:85);
    canvas.drawOval(glow,Paint()..shader=RadialGradient(colors:[
      Color.fromRGBO(255,159,42,.65*intensity*plume),const Color(0x00FF9922),
    ]).createShader(glow));
    for(var i=0;i<12+level*2;i++) {
      final x=cx+math.sin(i*7.1)*(20+t*size.width*.4);
      final y=padY-((t*240+i*23)%260);
      canvas.drawCircle(Offset(x,y),1.2,Paint()..color=Color.fromRGBO(255,210,125,intensity));
    }
  }
  @override bool shouldRepaint(_LaunchAtmosphere old)=>old.t!=t||old.level!=level;
}
