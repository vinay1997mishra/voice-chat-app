import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/auth/auth_service.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/infra/app_backend_service.dart';
import 'package:tinni_star/screens/ludo_screen.dart';
import 'package:tinni_star/games/game_live_connection.dart';

class _Live extends GameLiveConnection {
  _Live(void Function(Map<String, dynamic>) onState, void Function() onStatus) : super(
    apiBase: Uri.parse('http://unused.test'), path: '/ludo/live',
    onState: onState, onStatus: onStatus,
  );
  bool active = false;
  int disconnects = 0;
  @override bool get connected => active;
  @override Future<void> connect(String token) async { active = true; }
  @override void disconnect() { active = false; disconnects++; }
  void push(Map<String, dynamic> data) => onState(data);
}

class _Backend extends AppBackendService {
  int rolls=0,moves=0,leaves=0,reads=0;
  _Live? live;
  int? lastToken;
  Completer<Map<String,dynamic>>? pendingRoll;
  Map<String,dynamic> state={
    'ok':true,'version':1,'player_color':'red','current_player':'red','rolled':null,
    'status':'RED turn.','winner':null,
    'tokens':{for(final c in ['red','green','yellow','blue']) c:[-1,-1,-1,-1]},
    'players':[
      for(final entry in [('red','Alice'),('green','Bob'),('yellow','Cora'),('blue','Dev')])
        {'user_id':entry.$1,'color':entry.$1,'display_name':entry.$2},
    ],
  };
  @override Future<Map<String,dynamic>> ludoState(String token,{required String roomId}) async { reads++; return state; }
  @override Future<Map<String,dynamic>> ludoRoll(String token,{required String roomId}) {
    rolls++;return pendingRoll!.future;
  }
  @override Future<Map<String,dynamic>> ludoMove(String token,{required String roomId,required int tokenIndex}) async {
    moves++;lastToken=tokenIndex;
    state={...state,'version':3,'current_player':'green','rolled':null,'status':'GREEN turn.',
      'tokens':{...state['tokens'] as Map,'red':[0,-1,-1,-1]}};
    return state;
  }
  @override Future<Map<String,dynamic>> ludoLeave(String token,{required String roomId}) async {leaves++;return {'ok':true};}
}
TinniState _state(_Backend backend) {
  final state=TinniState(backendService:backend,roomPresenceFallbackTimerEnabled:false,
    runtime:FunctionPackRuntime(signatureVerifier:const DevelopmentSignatureVerifier()));
  state.auth.setAuthenticatedAccount(TinniAccount.fromServer(
    {'user_id':'red','display_name':'Alice'},token:'test-token'));
  return state;
}
Widget _view(TinniState state,double height)=>RepaintBoundary(
  key:const Key('ludo-preview'),child:MaterialApp(home:Scaffold(body:Align(
    alignment:Alignment.bottomCenter,child:SizedBox(height:height,
      child:LudoScreen(state:state,roomId:'real-room',
        liveConnectionFactory: (onState, onStatus) {
          final live = _Live(onState, onStatus);
          (state.backend as _Backend).live = live;
          return live;
        }))))));

void main() {
  testWidgets('Ludo stays live without idle HTTP reads and closes its socket on exit', (tester) async {
    final backend = _Backend();
    final gameState = _state(backend);
    await tester.pumpWidget(_view(gameState, 446));
    await tester.pump();
    expect(backend.reads, 1);
    await tester.pump(const Duration(minutes: 2));
    expect(backend.reads, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(backend.live!.disconnects, 1);
    gameState.social.dispose();
  });

  for(final size in [const Size(360,640),const Size(412,892),const Size(640,360)]) {
    testWidgets('Ludo four real names and coloured seats fit bottom half '+size.toString(),(tester) async {
      tester.view.physicalSize=size;tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final backend=_Backend(),state=_state(backend);
      await tester.pumpWidget(_view(state,size.height/2));await tester.pump();
      for(final color in ['red','green','yellow','blue']) {
        expect(find.byKey(Key('ludo-player-'+color)),findsOneWidget);
        expect(find.byKey(Key('ludo-name-'+color)),findsOneWidget);
        expect(find.byKey(Key('ludo-mic-'+color)),findsOneWidget);
      }
      expect(find.byType(CircleAvatar),findsNWidgets(4));
      if(size.height>400) {
        final red=tester.getTopLeft(find.byKey(const Key('ludo-player-red')));
        final green=tester.getTopLeft(find.byKey(const Key('ludo-player-green')));
        final blue=tester.getTopLeft(find.byKey(const Key('ludo-player-blue')));
        final yellow=tester.getTopLeft(find.byKey(const Key('ludo-player-yellow')));
        expect(red.dx,lessThan(green.dx));expect(blue.dx,lessThan(yellow.dx));
        expect(red.dy,lessThan(blue.dy));
      }
      expect(tester.takeException(),isNull);
      if(size==const Size(360,640)) {
        await tester.runAsync(() async {
          final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('ludo-preview')));
          final image=await boundary.toImage(pixelRatio:2);
          final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
          await Directory('build/game_previews').create(recursive:true);
          await File('build/game_previews/ludo-bottom-half.png').writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());await tester.pump();
      expect(backend.leaves,1);
    });
  }
  testWidgets('single pending dice action, token move and realtime opponent turn update',(tester) async {
    final backend=_Backend(),state=_state(backend);
    await tester.pumpWidget(_view(state,446));await tester.pump();
    backend.pendingRoll=Completer();
    await tester.tap(find.byKey(const Key('ludo-roll-dice')));await tester.pump();
    await tester.tap(find.byKey(const Key('ludo-roll-dice')));expect(backend.rolls,1);
    backend.state={...backend.state,'version':2,'rolled':6};
    backend.pendingRoll!.complete(backend.state);await tester.pump();
    await tester.tap(find.byKey(const Key('ludo-token-red-0')));await tester.pump();
    expect(backend.moves,1);
    expect(tester.widget<FilledButton>(find.byKey(const Key('ludo-roll-dice'))).onPressed,isNull);
    backend.state={...backend.state,'version':4,'current_player':'red','status':'RED turn.'};
    backend.live!.push(backend.state);
    await tester.pump(const Duration(seconds:2));await tester.pump();
    expect(backend.reads, 1);
    expect(tester.widget<FilledButton>(find.byKey(const Key('ludo-roll-dice'))).onPressed,isNotNull);
    await tester.pumpWidget(const SizedBox());await tester.pump();
  });
  testWidgets('stacked tokens remain selectable through numbered move buttons',(tester) async{
    final backend=_Backend();
    backend.state={...backend.state,'rolled':6,
      'tokens':{...backend.state['tokens'] as Map,'red':[0,0,0,0]}};
    final state=_state(backend);
    await tester.pumpWidget(_view(state,446));await tester.pump();
    for(var index=0;index<4;index++) {
      expect(find.byKey(Key('ludo-move-token-'+index.toString())),findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('ludo-move-token-2')));await tester.pump();
    expect(backend.lastToken,2);expect(backend.moves,1);
    await tester.pumpWidget(const SizedBox());await tester.pump();
  });

}
