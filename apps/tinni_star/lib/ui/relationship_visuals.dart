import 'dart:math' as math;
import 'package:flutter/material.dart';

bool relationshipMilestone(int before, int after) =>
    after > before && (before < 2 || after ~/ 5 > before ~/ 5);

class RelationshipBadge extends StatelessWidget {
  const RelationshipBadge({super.key,required this.level,this.rivalry=false});
  final int level;
  final bool rivalry;
  @override
  Widget build(BuildContext context) {
    final color = rivalry ? const Color(0xFFFF3549) : const Color(0xFFFFB0CF);
    return Container(
      padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:rivalry
          ? const [Color(0xFF33233F),Color(0xFF08090D)]
          : const [Color(0xFF82234D),Color(0xFF42122E)]),
        borderRadius:BorderRadius.circular(18),
        border:Border.all(color:level>=5 ? const Color(0xFFFFD485) : color,width:level>=5?2:1),
        boxShadow:[BoxShadow(color:color.withValues(alpha:level >= 5 ? .5 : .25),blurRadius:8+math.min(level,15).toDouble())],
      ),
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        Icon(rivalry ? (level>=5?Icons.bolt_rounded:Icons.flash_on_rounded)
          : (level>=5?Icons.auto_awesome_rounded:Icons.favorite_rounded),size:16,color:color),
        const SizedBox(width:5),Text('${rivalry?"VS":"CP"} Lv.$level',
          style:TextStyle(color:color,fontWeight:FontWeight.w900)),
      ]),
    );
  }
}

class RelationshipHero extends StatefulWidget {
  const RelationshipHero({super.key,required this.level,required this.progress,
    required this.startedAt,required this.nameA,required this.nameB,
    required this.idA,required this.idB,this.imageA,this.imageB,
    this.nextThreshold,this.previousThreshold=0,this.rivalry=false});
  final int level,progress,previousThreshold;
  final int? nextThreshold;
  final DateTime startedAt;
  final String nameA,nameB,idA,idB;
  final ImageProvider? imageA,imageB;
  final bool rivalry;
  @override
  State<RelationshipHero> createState()=>_RelationshipHeroState();
}

class _RelationshipHeroState extends State<RelationshipHero>
    with TickerProviderStateMixin,WidgetsBindingObserver {
  late final AnimationController _entrance;
  late final AnimationController _pulse;
  bool reduced=false;
  @override
  void initState() {
    super.initState();
    _entrance=AnimationController(vsync:this,duration:const Duration(milliseconds:1100));
    _pulse=AnimationController(vsync:this,duration:const Duration(seconds:5));
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced=MediaQuery.disableAnimationsOf(context);
    if(reduced) {_entrance.value=1;_pulse.stop();}
    else {_entrance.forward();if(!_pulse.isAnimating)_pulse.repeat();}
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed&&!reduced) _pulse.repeat();
    else _pulse.stop();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entrance.dispose();_pulse.dispose();super.dispose();
  }
  Widget person(String name,String id,ImageProvider? image,double offset) =>
    Transform.translate(offset:Offset(offset,0),child:Column(children:[
      Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(shape:BoxShape.circle,
        border:Border.all(color:widget.rivalry?const Color(0xFFDADBE6):const Color(0xFFFFD485),width:2),
        boxShadow:[BoxShadow(color:(widget.rivalry?Colors.red:Colors.pink).withValues(alpha:.4),blurRadius:12+widget.level.clamp(0,12).toDouble())]),
        child:CircleAvatar(radius:33,backgroundImage:image,
          onBackgroundImageError:image==null?null:(_,__) {},
          child:image==null?Text(name.isEmpty?'?':name.characters.first):null)),
      const SizedBox(height:9),Text(name,maxLines:1,overflow:TextOverflow.ellipsis,
        style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),
      Text('ID $id',style:const TextStyle(color:Color(0xFFD4B9CA),fontSize:10)),
    ]));
  @override
  Widget build(BuildContext context) {
    final color=widget.rivalry?const Color(0xFFFF3549):const Color(0xFFFFAFCC);
    final next=widget.nextThreshold;
    final ratio=next==null?1.0:((widget.progress-widget.previousThreshold)/
      math.max(1,next-widget.previousThreshold)).clamp(0.0,1.0).toDouble();
    final days=math.max(0,DateTime.now().difference(widget.startedAt).inDays);
    final date=widget.startedAt.toLocal().toIso8601String().split('T').first;
    return AnimatedBuilder(animation:Listenable.merge([_entrance,_pulse]),builder:(context,child) {
      final enter=Curves.easeOutCubic.transform(_entrance.value);
      return Container(
        padding:const EdgeInsets.all(18),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(26),border:Border.all(color:color),
          gradient:LinearGradient(colors:widget.rivalry
            ?const [Color(0xFF260811),Color(0xFF08090F),Color(0xFF251236)]
            :const [Color(0xFF681C41),Color(0xFF3B1033),Color(0xFF240D24)])),
        child:Stack(children:[
          Positioned.fill(child:IgnorePointer(child:CustomPaint(painter:_RelationshipPainter(
            rivalry:widget.rivalry,level:widget.level,t:reduced?0:_pulse.value)))),
          Opacity(opacity:enter,child:Column(children:[
            Text(widget.rivalry?'VS ARENA':'CP NEST',style:TextStyle(color:color,fontSize:21,fontWeight:FontWeight.w900,letterSpacing:2)),
            const SizedBox(height:20),
            Row(children:[
              Expanded(child:person(widget.nameA,widget.idA,widget.imageA,-60*(1-enter))),
              Transform.scale(scale:.7+.3*enter+(reduced?0:.04*math.sin(_pulse.value*math.pi*2)),
                child:Container(width:70,height:76,alignment:Alignment.center,
                  child:widget.rivalry?Text('VS',style:TextStyle(fontSize:35,color:color,fontWeight:FontWeight.w900,
                    shadows:[Shadow(color:color,blurRadius:15)]))
                    :Icon(Icons.favorite_rounded,size:58,color:color,shadows:[Shadow(color:color,blurRadius:18)]))),
              Expanded(child:person(widget.nameB,widget.idB,widget.imageB,60*(1-enter))),
            ]),
            const SizedBox(height:20),RelationshipBadge(level:widget.level,rivalry:widget.rivalry),
            const SizedBox(height:12),Text('${widget.progress} ${widget.rivalry?"VS progress":"CP progress"}',
              style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),
            const SizedBox(height:10),ClipRRect(borderRadius:BorderRadius.circular(12),
              child:LinearProgressIndicator(value:ratio,minHeight:9,backgroundColor:Colors.black38,color:color)),
            const SizedBox(height:8),Text(next==null?'Highest configured level reached':
              '${math.max(0,next-widget.progress)} progress to Lv.${widget.level+1}',
              style:TextStyle(color:color,fontSize:11)),
            const SizedBox(height:12),Text('${widget.rivalry?"Rivalry":"Together"} since $date · $days ${widget.rivalry?"active":"together"} days',
              textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFE3C5D4),fontSize:11)),
          ])),
        ]),
      );
    });
  }
}

class RelationshipLevelUpVisual extends StatelessWidget {
  const RelationshipLevelUpVisual({super.key,required this.level,required this.timeline,this.rivalry=false});
  final int level;
  final Animation<double> timeline;
  final bool rivalry;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation:timeline,builder:(context,child) {
    final reduced=MediaQuery.disableAnimationsOf(context);
    final t=reduced ? .5 : timeline.value;
    final color=rivalry?const Color(0xFFFF3549):const Color(0xFFFFC398);
    return ColoredBox(color:rivalry?const Color(0xF5080710):const Color(0xF52B0A20),
      child:Stack(fit:StackFit.expand,children:[
        CustomPaint(painter:_RelationshipPainter(rivalry:rivalry,level:level+5,t:t)),
        Center(child:Transform.translate(offset:Offset(rivalry&&!reduced?math.sin(t*100)*(1-t)*5:0,0),
          child:Transform.scale(scale:.7+.3*Curves.easeOutBack.transform(t.clamp(0,1)),child:Column(mainAxisSize:MainAxisSize.min,children:[
            Icon(rivalry?Icons.bolt_rounded:Icons.favorite_rounded,size:110,color:color),
            Text(rivalry?'VS LEVEL UP':'CP LEVEL UP',style:TextStyle(color:color,fontWeight:FontWeight.w900,fontSize:28)),
            const SizedBox(height:18),RelationshipBadge(level:level,rivalry:rivalry),
          ])))),
      ]));
  });
}

class _RelationshipPainter extends CustomPainter {
  const _RelationshipPainter({required this.rivalry,required this.level,required this.t});
  final bool rivalry;
  final int level;
  final double t;
  @override
  void paint(Canvas canvas,Size size) {
    final color=rivalry?const Color(0xFFFF3549):const Color(0xFFFFB7D4);
    final paint=Paint()..color=color.withValues(alpha:.24)..strokeWidth=1.5..style=PaintingStyle.stroke;
    final count=8+level.clamp(0,16);
    for(var i=0;i<count;i++) {
      final phase=(i/count+t)%1;
      final x=size.width*((i*.618)%1),y=size.height*(1-phase);
      if(rivalry) {
        final path=Path()..moveTo(x,y)..lineTo(x+7,y+12)..lineTo(x-3,y+16)..lineTo(x+9,y+29);
        canvas.drawPath(path,paint);
        canvas.drawCircle(Offset(x,y),2,Paint()..color=color.withValues(alpha:.65));
      } else {
        final path=Path()..moveTo(x,y+7)..cubicTo(x-14,y-3,x-6,y-10,x,y-3)
          ..cubicTo(x+6,y-10,x+14,y-3,x,y+7);
        canvas.drawPath(path,paint);
      }
    }
    if(level>=5) {
      canvas.drawOval(Rect.fromLTWH(4,4,size.width-8,size.height-8),
        Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=(rivalry?const Color(0xFF8D68D8):const Color(0xFFFFD485)).withValues(alpha:.25+.15*math.sin(t*math.pi*2)));
    }
  }
  @override
  bool shouldRepaint(covariant _RelationshipPainter old)=>old.t!=t||old.level!=level||old.rivalry!=rivalry;
}

class RelationshipSeatAura extends StatefulWidget {
  const RelationshipSeatAura({super.key,required this.level,this.rivalry=false});
  final int level;
  final bool rivalry;
  @override
  State<RelationshipSeatAura> createState()=>_RelationshipSeatAuraState();
}
class _RelationshipSeatAuraState extends State<RelationshipSeatAura> with SingleTickerProviderStateMixin {
  late final AnimationController motion;
  @override
  void initState(){super.initState();motion=AnimationController(vsync:this,duration:const Duration(seconds:4));}
  @override
  void didChangeDependencies(){super.didChangeDependencies();
    if(widget.level>=5&&!MediaQuery.disableAnimationsOf(context))motion.repeat();else motion.stop();}
  @override
  void dispose(){motion.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>AnimatedBuilder(animation:motion,builder:(context,child)=>Stack(children:[
    if(widget.level>=5)Positioned.fill(child:CustomPaint(painter:_RelationshipPainter(rivalry:widget.rivalry,level:widget.level,t:motion.value))),
    Align(alignment:widget.rivalry?Alignment.topRight:Alignment.bottomLeft,child:Container(
      padding:const EdgeInsets.symmetric(horizontal:3,vertical:1),
      decoration:BoxDecoration(color:widget.rivalry?const Color(0xFF4B0713):const Color(0xFF741C44),borderRadius:BorderRadius.circular(6)),
      child:Text('${widget.rivalry?"VS":"CP"} ${widget.level}',style:const TextStyle(fontSize:8,color:Colors.white,fontWeight:FontWeight.w800)))),
  ]));
}
