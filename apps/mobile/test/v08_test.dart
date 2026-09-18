import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/main_v08.dart';
import 'package:voice_chat_app/gift_catalog_v08.dart';

void main() {
  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('v0.8 room gift center exposes normal couple and flag tabs',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());

    await tester.tap(find.byKey(const Key('open-v07-room')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gift'));
    await tester.pumpAndSettle();

    expect(find.text('v0.8 Gift Center'), findsOneWidget);
    expect(find.byKey(const Key('gift-recipient-v08')), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('CP Couple'), findsOneWidget);
    expect(find.text('Flags'), findsOneWidget);
    expect(find.text('Tiny Rose'), findsOneWidget);

    await tester.tap(find.text('CP Couple'));
    await tester.pumpAndSettle();
    expect(find.text('First Love'), findsOneWidget);

    await tester.tap(find.text('Flags'));
    await tester.pumpAndSettle();
    expect(find.text('AF Flag'), findsOneWidget);
  });


  testWidgets('room message closes with focused editor and can reopen',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());
    await tester.tap(find.byKey(const Key('open-v07-room')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'message $i');
      await tester.tap(find.text('Send'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('You: message $i'), findsOneWidget);
    }
    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'discard this');
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('You: discard this'), findsNothing);
  });

  testWidgets('locked room handles wrong PIN cancel and correct PIN',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());
    await tester.tap(find.text('Night Party'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-room-pin-v06')), '000000');
    await tester.tap(find.text('Enter'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong room PIN'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Night Party'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-room-pin-v06')), '123456');
    await tester.tap(find.text('Enter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(RoomV07), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('room password saves validates cancels and disables safely',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData('Test room', '123', '🎧', false);
    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));
    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Room Password'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(room.locked, isFalse);
    await tester.enterText(find.byType(TextField), '654321');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(room.locked, isTrue);
    expect(room.pin, '654321');
    await tester.tap(find.text('Room Password'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '111111');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(room.pin, '654321');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Room Password'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(room.locked, isFalse);
    expect(room.pin, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('v0.8 economy sends catalog gift to recipient and records history', () {
    final economy = DemoEconomy();
    final recipient = economy.users[2];
    final gift = normalGiftsV08.firstWhere((g) => g.name == 'Eagles King');
    final beforeCoins = economy.coins;
    final beforeDiamonds = recipient.diamonds;

    expect(economy.sendGiftV08(gift, recipient, 'ROOM-V08'), isTrue);
    expect(economy.coins, beforeCoins - gift.coins);
    expect(recipient.diamonds, beforeDiamonds + gift.coins);
    expect(economy.giftHistory.first.gift, contains('Eagles King'));
    expect(economy.giftHistory.first.toId, recipient.id);
    expect(gift.animationTier, GiftAnimationTierV08.ultraRide3d);
    expect(gift.isHumanRide, isTrue);
  });

  test('country flags use 21K and render regional flag emoji', () {
    expect(flagGiftsV08.every((gift) => gift.coins == 21000), isTrue);
    expect(flagEmojiV08('IN'), '🇮🇳');
    expect(flagEmojiV08('US'), '🇺🇸');
  });
}
