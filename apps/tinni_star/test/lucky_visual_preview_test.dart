import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/economy/economy.dart';
import 'package:tinni_star/effects/lucky_gift_queue.dart';
import 'package:tinni_star/effects/lucky_gift_overlay.dart';
import 'package:tinni_star/room/room_presence_service.dart';

void main() {
  testWidgets('export all Lucky effect tiers with the center HUD and right Combo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gift = GiftService.luckyCatalog.firstWhere((gift) => gift.id == 'lucky-neon-butterfly');
    for (final multiplier in [0, 10, 50, 100, 250, 500, 750, 1000]) {
      final now = 1 + 600 + (luckyBubbleDurationMs(multiplier) * .48).round();
      final queue = LuckyGiftQueue(clock: () => now)..add(RoomGiftVisualEvent(
        id: 'preview-$multiplier', senderId: 'preview-sender', senderName: 'Lucky Sender',
        giftId: gift.id, giftName: gift.name, receiverIds: const ['preview-receiver'],
        quantity: 1, lucky: true, multiplier: multiplier, rebateCoins: 500 * multiplier,
        sentCoins: 500, unitPrice: 500, createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        visualStartedAtMs: 1, highWin: multiplier >= 200, bannerWin: multiplier >= 500,
        ultraWin: multiplier >= 1000,
        multiplierCounts: [{'multiplier': multiplier, 'count': 1}],
      ), gift);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(home: RepaintBoundary(key: boundaryKey,
        child: Scaffold(
          backgroundColor: const Color(0xFF10162D),
          body: Stack(children: [
            const Positioned(left: 18, top: 30, child: Text('Tinni Star', style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
            Positioned.fill(child: LuckyGiftOverlay(queue: queue)),
            Positioned(right: 8, top: 70, child: LuckyComboPanel(
              gift: gift, quantity: 1, count: 1, wonCoins: 500 * multiplier,
              sentCoins: 500, highest: multiplier, secondsLeft: 9,
              loading: false, onSend: () {},
            )),
          ]),
        ),
      )));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.byKey(const Key('lucky-active-multiplier')), findsOneWidget);
      expect(find.byKey(const Key('lucky-center-banner')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/lucky_previews').createSync(recursive: true);
        File('build/lucky_previews/lucky-$multiplier.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox()); await tester.pump();
      queue.dispose();
    }
  });
}
