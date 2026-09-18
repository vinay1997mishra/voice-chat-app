import 'dart:math';
import 'package:flutter/material.dart';

class GamesCenterV07 extends StatelessWidget {
  const GamesCenterV07({super.key});
  @override Widget build(BuildContext context) {
    const games = [('UNO','🃏'),('Ludo','🎲'),('Lucky Dice','🎯'),('Lucky Wheel','🎡'),('Rock Paper Scissors','✊'),('Teen Patti','♠️')];
    return Scaffold(appBar: AppBar(title: const Text('Game Center')),body: GridView.builder(
      padding: const EdgeInsets.all(14),itemCount: games.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:1.05,crossAxisSpacing:10,mainAxisSpacing:10),
      itemBuilder:(context,i)=>Card(child:InkWell(key:Key('game-v07-'+i.toString()),borderRadius:BorderRadius.circular(12),
        onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>LocalGameV07(kind:i))),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Text(games[i].$2,style:const TextStyle(fontSize:44)),const SizedBox(height:8),
          Text(games[i].$1,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
          const SizedBox(height:5),const Text('Local demo',style:TextStyle(fontSize:12)),
        ]))),
    ));
  }
}

class LocalGameV07 extends StatefulWidget {
  const LocalGameV07({super.key,required this.kind});
  final int kind;
  @override State<LocalGameV07> createState()=>_LocalGameV07State();
}
class _LocalGameV07State extends State<LocalGameV07> {
  final rng=Random();
  int dice=1,wheel=0,rpsYou=0,rpsBot=0,ludoPos=0,teenScore=0,unoYou=7,unoBot=7;
  String result='Tap Play to start';
  static const wheelItems=['10 Coins','25 Coins','Try Again','50 Coins','100 Coins','Bonus'];
  static const rps=['✊','✋','✌️'];
  static const suits=['♠️','♥️','♦️','♣️'];
  String get title=>['UNO','Ludo','Lucky Dice','Lucky Wheel','Rock Paper Scissors','Teen Patti'][widget.kind];
  void play(){setState((){
    switch(widget.kind){
      case 0:
        if(unoYou>0) unoYou--; if(unoBot>0 && rng.nextBool()) unoBot--;
        result=unoYou==0?'You won UNO!':unoBot==0?'Bot won UNO':'Card played • your hand: '+unoYou.toString(); break;
      case 1:
        dice=rng.nextInt(6)+1;ludoPos=min(30,ludoPos+dice);result=ludoPos>=30?'Home! You completed the local Ludo track.':'Rolled '+dice.toString()+' • position '+ludoPos.toString()+'/30';break;
      case 2:dice=rng.nextInt(6)+1;result='You rolled '+dice.toString();break;
      case 3:wheel=rng.nextInt(wheelItems.length);result='Wheel: '+wheelItems[wheel];break;
      case 4:
        rpsYou=rng.nextInt(3);rpsBot=rng.nextInt(3);final d=(rpsYou-rpsBot+3)%3;result=d==0?'Draw':d==1?'You win!':'Bot wins';break;
      case 5:
        final cards=List.generate(3,(_)=>rng.nextInt(13)+2);teenScore=cards.reduce((a,b)=>a+b);
        result='Hand: '+List.generate(3,(i)=>suits[rng.nextInt(4)]+' '+cards[i].toString()).join('  ')+' • score '+teenScore.toString();break;
    }
  });}
  Widget board(){switch(widget.kind){
    case 0:return Column(children:[const Text('🟥  🟨  🟩  🟦',style:TextStyle(fontSize:38)),Text('Your cards: '+unoYou.toString()+'   •   Bot: '+unoBot.toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const Text('Simplified local turn demo; no online opponents yet.',textAlign:TextAlign.center)]);
    case 1:return Column(children:[Text('🎲 '+dice.toString(),style:const TextStyle(fontSize:52)),LinearProgressIndicator(value:ludoPos/30),const SizedBox(height:8),Text('Token position '+ludoPos.toString()+' / 30')]);
    case 2:return Text('🎲 '+dice.toString(),style:const TextStyle(fontSize:82));
    case 3:return Column(children:[const Text('🎡',style:TextStyle(fontSize:82)),Text(wheelItems[wheel],style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900))]);
    case 4:return Text(rps[rpsYou]+'  VS  '+rps[rpsBot],style:const TextStyle(fontSize:54));
    default:return const Column(children:[Text('♠️  ♥️  ♦️',style:TextStyle(fontSize:50)),Text('Teen Patti practice table',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),Text('No cash, withdrawal, betting, or real-money rewards.',textAlign:TextAlign.center)]);
  }}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(title)),body:SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
    Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[board(),const SizedBox(height:24),Text(result,key:const Key('game-result-v07'),textAlign:TextAlign.center,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:18),FilledButton.icon(key:const Key('game-play-v07'),onPressed:play,icon:const Icon(Icons.play_arrow_rounded),label:Text(widget.kind==0?'Play Card':'Play'))]))),
    const SizedBox(height:12),const Text('v0.7 local game demo • results stay on this device/session.',textAlign:TextAlign.center),
  ])));
}
