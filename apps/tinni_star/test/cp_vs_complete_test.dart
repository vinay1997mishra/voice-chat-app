import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/economy/economy.dart';
import 'package:tinni_star/effects/gift_scene_overlay.dart';
import 'package:tinni_star/infra/app_backend_service.dart';
import 'package:tinni_star/screens/relationship_ranking_screen.dart';
import 'package:tinni_star/ui/relationship_visuals.dart';
import 'test_account.dart';

class RelationshipBackend extends AppBackendService {
  @override
  Future<List<Map<String,dynamic>>> vsRanking(String token) async => [{
    'rank':1,'user_a':'91000001','user_b':'91000002',
    'user_a_name':'Rival One','user_b_name':'Rival Two','rivalry':3000000,'level':3,
  }];
}

void main(){
  testWidgets('VS hero shows authoritative next level, identities and date without romantic elements',(tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:RelationshipHero(
      rivalry:true,level:3,progress:4000000,previousThreshold:3000000,nextThreshold:6000000,
      startedAt:DateTime(2026,1,1),nameA:'A',nameB:'B',idA:'1',idB:'2',
    ))));
    await tester.pump(const Duration(milliseconds:1200));
    expect(find.text('2000000 progress to Lv.4'),findsOneWidget);
    expect(find.text('ID 1'),findsOneWidget);expect(find.text('ID 2'),findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded),findsNothing);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,closeTo(1/3,.001));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(),isNull);
  });

  testWidgets('VS ranking renders server pairs instead of placeholder scores',(tester)async{
    final state=TinniState(runtime:FunctionPackRuntime(signatureVerifier:const DevelopmentSignatureVerifier()),
      backendService:RelationshipBackend());
    attachTestAccount(state);
    await tester.pumpWidget(MaterialApp(home:RelationshipRankingScreen(state:state,rivalry:true)));
    await tester.pumpAndSettle();
    expect(find.text('Rival One'),findsOneWidget);
    expect(find.text('3000000 confirmed progress'),findsOneWidget);
    expect(find.text('Aarav'),findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('owner-created gifts need no predefined app ID and keep independent categories',(){
    final service=GiftService(WalletService());
    service.applyCatalog([
      {'id':'gift-owner-123','name':'CP Movie','data':{'category':'cp','coin_price':2000000,
        'animation_url':'https://example.test/movie.mp4','poster_url':'https://example.test/poster.png'}},
      {'id':'gift-owner-456','name':'VS Movie','data':{'category':'vs','coin_price':3000000}},
    ]);
    final cp=service.catalogFor('CP',const[]);
    final vs=service.catalogFor('VS',const[]);
    expect(cp.single.id,'gift-owner-123');expect(vs.single.id,'gift-owner-456');
    expect(cp.single.animationUrl,'https://example.test/movie.mp4');
    expect(service.catalogFor('Lucky',const[]),isEmpty);
    service.applyCatalog([]);
    expect(service.catalogFor('CP',const[]),isEmpty);
  });

  testWidgets('a confirmed VS gift falls back visually and delivers once after level up',(tester)async{
    final queue=GiftSceneQueue(), delivered=<GiftSceneEvent>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:GiftSceneOverlay(queue:queue,onDelivered:delivered.add))));
    queue.add(GiftSceneEvent(gift:const GiftDefinition(id:'vs-owner',name:'VS Movie',price:3000000,
      category:'vs',effectKind:'scene',animationUrl:'https://example.test/unavailable.mp4',
      animationDurationMs:1000,levelBefore:1,levelAfter:3),recipients:['2']));
    await tester.pump();
    await tester.pump(const Duration(seconds:1));await tester.pump();
    expect(find.text('VS LEVEL UP'),findsOneWidget);expect(delivered,isEmpty);
    await tester.pump(const Duration(seconds:3));await tester.pump();
    expect(delivered.length,1);
    await tester.pumpWidget(const SizedBox());queue.dispose();
    expect(tester.takeException(),isNull);
  });
}
