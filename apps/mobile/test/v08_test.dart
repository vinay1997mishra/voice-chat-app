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


  testWidgets('room has a persistent composer and sends visible messages',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());
    await tester.tap(find.byKey(const Key('open-v07-room')));
    await tester.pumpAndSettle();

    final input = find.byKey(const Key('room-message-input-v08'));
    final send = find.byKey(const Key('room-message-send-v08'));
    expect(input, findsOneWidget);
    expect(send, findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.enterText(input, 'message $i');
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('You: message $i'), findsOneWidget);
    }
  });

  testWidgets('Lucky Bag becomes visible in room and can be claimed',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());
    await tester.tap(find.byKey(const Key('open-v07-room')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LP'));
    await tester.pumpAndSettle();
    expect(find.text('Lucky Bag (LP)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('lp-amount-v06')), '6000');
    await tester.tap(find.text('Create LP'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('active-lp-v08')), findsOneWidget);
    expect(find.textContaining('6000 LP remaining'), findsOneWidget);
    await tester.tap(find.byKey(const Key('claim-lp-v08')));
    await tester.pumpAndSettle();
    expect(find.textContaining('You claimed'), findsWidgets);
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

  testWidgets('room lock sets a 4-6 digit PIN and disables cleanly',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData('Test room', '123', '🎧', false);
    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final lockSwitch = find.byKey(const Key('room-lock-switch-v08'));
    expect(lockSwitch, findsOneWidget);
    await tester.tap(lockSwitch);
    await tester.pumpAndSettle();

    final pinInput = find.byKey(const Key('room-pin-input-v08'));
    final setLock = find.byKey(const Key('set-room-lock-v08'));
    expect(pinInput, findsOneWidget);
    expect(setLock, findsOneWidget);

    await tester.enterText(pinInput, '123');
    await tester.tap(setLock);
    await tester.pumpAndSettle();
    expect(find.text('PIN must be 4 to 6 digits'), findsOneWidget);
    expect(room.locked, isFalse);

    await tester.enterText(pinInput, '4321');
    await tester.tap(setLock);
    await tester.pumpAndSettle();
    expect(room.locked, isTrue);
    expect(room.pin, '4321');
    expect(find.text('Change Room PIN'), findsOneWidget);
    expect(find.text('Room lock enabled'), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-lock-switch-v08')));
    await tester.pumpAndSettle();
    expect(room.locked, isFalse);
    expect(room.pin, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one user can create only one room', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());

    await tester.tap(find.byKey(const Key('create-room-v06')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-room-submit-v06')));
    await tester.pumpAndSettle();
    expect(find.textContaining('• My Room'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create-room-v06')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('One user can create only one room'),
      findsOneWidget,
    );
    expect(find.byType(CreateRoomV07), findsNothing);
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
