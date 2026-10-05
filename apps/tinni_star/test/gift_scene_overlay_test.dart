import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/effects/gift_scene_overlay.dart';
import 'package:tinni_star/economy/premium_gift_catalog.dart';
void main() {
  testWidgets('multi recipient gift holds once for five seconds before delivery',(tester) async {
    final queue=GiftSceneQueue();
    final delivered=<GiftSceneEvent>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:GiftSceneOverlay(queue:queue,onDelivered:delivered.add))));
    queue.add(GiftSceneEvent(gift:PremiumGiftCatalog.normal.first,recipients:['a','b','a']));
    await tester.pump();
    expect(find.byKey(const ValueKey('gift-scene-rose')),findsOneWidget);
    await tester.pump(const Duration(seconds:4));
    expect(delivered,isEmpty);
    await tester.pump(const Duration(seconds:1));await tester.pump();
    expect(delivered.length,1);
    expect(delivered.single.recipients,['a','b']);
    await tester.pumpWidget(const SizedBox());queue.dispose();
  });
  testWidgets('CP holds seven seconds and queued normal gift waits',(tester) async {
    final queue=GiftSceneQueue();
    final delivered=<GiftSceneEvent>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:GiftSceneOverlay(queue:queue,onDelivered:delivered.add))));
    queue.add(GiftSceneEvent(gift:PremiumGiftCatalog.cp[1],recipients:['a']));
    queue.add(GiftSceneEvent(gift:PremiumGiftCatalog.normal.first,recipients:['b']));
    await tester.pump();
    await tester.pump(const Duration(seconds:6));expect(delivered,isEmpty);
    await tester.pump(const Duration(seconds:1));await tester.pump();
    expect(delivered.single.gift.id,'cp-invite');
    expect(find.byKey(const ValueKey('gift-scene-rose')),findsOneWidget);
    await tester.pump(const Duration(seconds:5));await tester.pump();
    expect(delivered.length,2);
    await tester.pumpWidget(const SizedBox());queue.dispose();
  });
}
