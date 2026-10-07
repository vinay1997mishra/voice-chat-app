import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/games/fruit_party_game.dart';
import 'package:tinni_star/games/fruit_party_remote.dart';
import 'package:tinni_star/screens/casino_fruit_panel.dart';
class _RealHttp extends HttpOverrides {}
void main() {
  test('Fruit Party server Lucky result retains all four payout fruits',()=>HttpOverrides.runWithHttpOverrides(() async {
    final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);
    final now=DateTime.now().millisecondsSinceEpoch;
    server.listen((request) async {
      request.response.headers.contentType=ContentType.json;
      request.response.write(jsonEncode({
        'ok':true,'server_time':now,'wallet_balance':12345,'today_winnings':15000,
        'round':{'round_id':2,'round_end':now+21000,'cycle_end':now+26000,
          'phase':'betting','round_duration_ms':21000},
        'my_bets':{},
        'history':[{'round_id':1,'fruit':{'key':'lemon'},'special_kind':'lucky11',
          'bonus_fruits':[{'key':'lemon'},{'key':'banana'},{'key':'watermelon'},{'key':'cherry'}],
          'total_bet':5000,'total_payout':300000,'active_players':1,'settled_at':now}],
      }));
      await request.response.close();
    });
    final remote=FruitPartyRemoteService(apiBase:Uri.parse('http://127.0.0.1:'+server.port.toString()));
    try {
      await remote.sync('test-token');
      expect(remote.connected,true);expect(remote.history.single.lucky11,true);
      expect(remote.history.single.bonusFruits,[FruitPartyKind.lemon,FruitPartyKind.banana,FruitPartyKind.watermelon,FruitPartyKind.cherry]);
      expect(remote.walletBalance,12345);
    } finally { remote.dispose();await server.close(force:true); }
  },_RealHttp()));
  testWidgets('Party Lucky is visible in the real casino panel',(tester) async {
    final source=ValueNotifier<int>(0);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:CasinoGameDock(
      child:CasinoFruitPanel(title:'Fruit Party',gameId:'party-lucky',party:true,
        source:source,refresh:()async{},bet:(_,_)async=>null,
        snapshot:()=>CasinoSnapshot(connected:true,loading:false,bettingOpen:true,spinning:false,
          remaining:const Duration(seconds:21),spinRemaining:Duration.zero,roundDuration:21000,
          round:2,balance:12345,mine:5000,winnings:300000,
          fruits:[for(final fruit in FruitPartyKind.values) CasinoFruit(
            key:fruit.name,label:fruit.label,multiplier:fruit.multiplier,bet:0)],
          history:[CasinoResult(round:1,fruit:'lemon',lucky:true,bonus:const ['lemon','banana','watermelon','cherry'],
            settledAt:DateTime.now().subtract(const Duration(seconds:1)))]),
      )))));
    await tester.pump();
    expect(find.text('LUCKY 11'),findsOneWidget);
    expect(find.text('4 HOT fruits'),findsOneWidget);
    expect(find.text('HOT'),findsWidgets);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());source.dispose();
  });
}
