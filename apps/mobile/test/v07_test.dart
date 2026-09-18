import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/main_v07.dart';
import 'package:voice_chat_app/games_v07.dart';

void main() {
  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('playable games expose bot and local multiplayer modes', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: GameLauncherV07(game: 'Ludo'),
    ));
    expect(find.text('Solo vs Bot'), findsOneWidget);
    expect(find.text('Local Multiplayer'), findsOneWidget);
    expect(find.text('Online Multiplayer'), findsOneWidget);

    await tester.tap(find.text('Solo vs Bot'));
    await tester.pumpAndSettle();
    expect(find.text('Ludo'), findsWidgets);
    expect(find.byKey(const Key('ludo-roll-v07')), findsOneWidget);
    expect(find.byKey(const Key('ludo-board-v07')), findsOneWidget);
  });

  testWidgets('UNO exposes real action-card gameplay surface', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: UnoGameV07(mode: V07GameMode.soloBot)));
    expect(find.text('UNO'), findsWidgets);
    expect(find.byKey(const Key('uno-draw-v07')), findsOneWidget);
    expect(find.textContaining('Bot cards:'), findsOneWidget);
    expect(find.text('Your hand'), findsOneWidget);
  });

  testWidgets('game center exposes all seven local games', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: GamesCenterV07()));
    for (final name in ['Ludo','UNO','Carrom','Lucky Dice','Lucky Wheel','Rock Paper Scissors','Teen Patti']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('dice wheel rps and teen patti are interactive', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: LuckyDiceGameV07(mode: V07GameMode.soloBot)));
    expect(find.byKey(const Key('lucky-dice-roll-v07')), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: LuckyWheelGameV07(mode: V07GameMode.soloBot)));
    expect(find.byKey(const Key('lucky-wheel-spin-v07')), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: RpsGameV07(mode: V07GameMode.soloBot)));
    expect(find.text('Rock'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: TeenPattiGameV07(mode: V07GameMode.soloBot)));
    expect(find.byKey(const Key('teen-patti-deal-v07')), findsOneWidget);
  });

  testWidgets('final v0.7 includes shell wallet and room tools', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV07());

    expect(find.byKey(const Key('create-room-v06')), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('Coins'), findsOneWidget);
    expect(find.text('Diamond'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-v07-room')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v07-seat-grid')), findsOneWidget);
    await tester.tap(find.byKey(const Key('v07-seat-0')));
    await tester.pumpAndSettle();
    expect(find.text('Lock Seat'), findsOneWidget);
    expect(find.text('Mute Seat'), findsOneWidget);
    Navigator.of(tester.element(find.text('Lock Seat'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v07-tools-grid')), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('LP'), findsOneWidget);
    expect(find.text('Game'), findsOneWidget);
    expect(find.text('Room DP'), findsOneWidget);
    expect(find.text('Background'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Admins'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
  });

  testWidgets('gift goes to recipient ID and appears in inbox and wallet', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV07());

    await tester.tap(find.byKey(const Key('open-v07-room')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gift'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gift-recipient-v06')), findsOneWidget);
    expect(find.text('Owner • ID 10000000'), findsOneWidget);
    expect(find.text('Rose'), findsOneWidget);
    expect(find.text('Dragon'), findsOneWidget);
    expect(find.text('Galaxy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('gift-rose-v06')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Gift sent to ID 10000000'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Transaction History'), findsOneWidget);
    expect(find.text('Gift sent: Rose'), findsOneWidget);
    expect(find.text('Diamond → Coins'), findsOneWidget);
  });
  test('local economy tracks sent and received gifts safely', () {
    final economy = DemoEconomy();
    final recipient = economy.users[2];
    final beforeCoins = economy.coins;
    final beforeDiamonds = recipient.diamonds;

    expect(economy.sendGift(economy.gifts.first, recipient, 'ROOM1'), isTrue);
    expect(economy.coins, beforeCoins - economy.gifts.first.coins);
    expect(recipient.diamonds, beforeDiamonds + economy.gifts.first.coins);
    expect(economy.giftHistory.first.direction, 'Sent');
    expect(economy.giftHistory.first.toId, recipient.id);

    final myDiamonds = economy.diamonds;
    economy.simulateIncomingGift();
    expect(economy.diamonds, greaterThan(myDiamonds));
    expect(economy.giftHistory.first.direction, 'Received');
  });

  testWidgets('VIP 1-11, store, bag, level and settings open', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV07());

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('VIP').last);
    await tester.tap(find.text('VIP').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('VIP 1–11'), findsOneWidget);
    Navigator.of(tester.element(find.text('VIP 1–11'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Store').last);
    await tester.tap(find.text('Store').last);
    await tester.pumpAndSettle();
    expect(find.text('Gift Catalog'), findsOneWidget);
    Navigator.of(tester.element(find.text('Gift Catalog'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bag').last);
    await tester.tap(find.text('Bag').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Equipped:'), findsOneWidget);
    Navigator.of(tester.element(find.textContaining('Equipped:'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Level').last);
    await tester.tap(find.text('Level').last);
    await tester.pumpAndSettle();
    expect(find.text('User Level'), findsOneWidget);
    Navigator.of(tester.element(find.text('User Level'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Settings').last);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('3D Effects'), findsOneWidget);
    expect(find.text('Allow Private Messages'), findsOneWidget);
  });
  testWidgets('VIP11 3D card renders and benefit stack reaches 11', (tester) async {
    setPhoneViewport(tester);
    expect(vipPreviewBenefitsV07(11).length, 11);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Vip3DCardV07(level: 11),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('vip11-3d-v07')), findsOneWidget);
    expect(find.text('VIP 11'), findsOneWidget);
  });


}
