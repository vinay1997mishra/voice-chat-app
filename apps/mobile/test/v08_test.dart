import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/main_v08.dart';
import 'package:voice_chat_app/gift_catalog_v08.dart';
import 'package:voice_chat_app/dynamic_gifts_v08.dart';
import 'package:voice_chat_app/dynamic_gift_manager_v08.dart';
import 'package:voice_chat_app/app_owner_controls_v08.dart';
import 'package:voice_chat_app/games_v08.dart';

void main() {
  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openOfficialRoom(WidgetTester tester) async {
    final popularTab = find.byKey(const Key('home-popular-tab-v08'));
    if (popularTab.evaluate().isNotEmpty) {
      await tester.tap(popularTab);
      await tester.pumpAndSettle();
    }
    final roomFinder = find.byKey(const Key('open-v07-room'));
    final homeList = find.byType(ListView).first;
    for (var attempt = 0; attempt < 5 && roomFinder.evaluate().isEmpty; attempt++) {
      await tester.drag(homeList, const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    expect(roomFinder, findsOneWidget);
    await tester.tap(roomFinder);
    await tester.pumpAndSettle();
  }

  setUp(() {
    roomRegistryV08.clear();
    demoEconomy.userIdAliases.clear();
    demoEconomy.currentUserId = '10000050';
    demoEconomy.byName('Owner').id = '10000000';
    demoEconomy.byName('Admin').id = '10000001';
    demoEconomy.byName('Aisha').id = '10000011';
    demoEconomy.byName('Sam').id = '10000012';
    appOwnerControlsV08.maintenanceMode = false;
    appOwnerControlsV08.roomCreationEnabled = true;
    appOwnerControlsV08.giftsEnabled = true;
    appOwnerControlsV08.videoGiftsEnabled = true;
    appOwnerControlsV08.threeDEffectsEnabled = true;
    appOwnerControlsV08.giftAnimationsEnabled = true;
    appOwnerControlsV08.gamesEnabled = true;
    appOwnerControlsV08.ludoEnabled = true;
    appOwnerControlsV08.unoEnabled = true;
    appOwnerControlsV08.carromEnabled = true;
    appOwnerControlsV08.luckyDiceEnabled = true;
    appOwnerControlsV08.luckyWheelEnabled = true;
    appOwnerControlsV08.privateMessagesEnabled = true;
    appOwnerControlsV08.ownerGiftSharePercent = 10;
    appOwnerControlsV08.diamondsPerCoin = 2;
    appOwnerControlsV08.announcement = 'Welcome to Voice Chat v0.8';
    appOwnerControlsV08.bannedUserIds.clear();
    appOwnerControlsV08.globalAdminIds
      ..clear()
      ..add('10000001');
    appOwnerControlsV08.openReports
      ..clear()
      ..addAll(<String>[
        'Aisha • Spam report',
        'Sam • Abusive-language report',
      ]);
    demoEconomy.threeDEffects = true;
    demoEconomy.giftAnimations = true;
    demoEconomy.allowPrivateMessages = true;
    appOwnerControlsV08.refresh();
  });

  testWidgets('v0.8 room gift center exposes normal couple and flag tabs',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());

    await openOfficialRoom(tester);

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

    final flagsTab = find.text('Flags');
    await tester.ensureVisible(flagsTab);
    await tester.pumpAndSettle();
    await tester.tap(flagsTab);
    await tester.pumpAndSettle();
    expect(find.text('AF Flag'), findsOneWidget);
  });


  testWidgets('gift receiver avatars swipe horizontally and selection updates',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());
    await openOfficialRoom(tester);
    await tester.tap(find.text('Gift'));
    await tester.pumpAndSettle();

    final stripFinder = find.byKey(const Key('gift-recipient-v08'));
    expect(stripFinder, findsOneWidget);
    final strip = tester.widget<ListView>(stripFinder);
    expect(strip.scrollDirection, Axis.horizontal);

    expect(find.byKey(const Key('gift-recipient-10000000-v08')), findsOneWidget);
    expect(find.byKey(const Key('gift-recipient-10000011-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('gift-recipient-10000011-v08')));
    await tester.pumpAndSettle();

    final selectedRecipient = tester.widget<Text>(
      find.byKey(const Key('gift-selected-recipient-v08')),
    );
    expect(selectedRecipient.data, contains('Aisha'));
    expect(selectedRecipient.data, contains('ID 10000011'));
  });


  testWidgets('room has a persistent composer and sends visible messages',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());
    await openOfficialRoom(tester);

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

  testWidgets('owner moves seats without duplication and is excluded from mute-all',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData(
      'Owner seat room',
      'OWN-SEAT',
      '👑',
      false,
      ownedByMe: true,
    );
    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));

    expect(find.text('Owner'), findsOneWidget);
    await tester.tap(find.byKey(const Key('room-seat-3-v08')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to Seat'));
    await tester.pumpAndSettle();

    expect(find.text('Owner'), findsNothing);
    expect(find.text('You'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('room-seat-3-v08')),
        matching: find.byIcon(Icons.mic_off_rounded),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    final ownerTool = find.descendant(
      of: find.byKey(const Key('v07-tools-grid')),
      matching: find.text('Owner'),
    );
    await tester.tap(ownerTool);
    await tester.pumpAndSettle();

    final muteAll = find.text('Mute All Guests');
    await tester.scrollUntilVisible(
      muteAll,
      350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(muteAll);
    await tester.pumpAndSettle();

    Navigator.of(tester.element(muteAll)).pop();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('room-seat-3-v08')),
        matching: find.byIcon(Icons.mic_off_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets('owner Lucky Bag becomes visible and can be claimed',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData(
      'Owner room',
      'LP-1',
      '🎧',
      false,
      ownedByMe: true,
    );
    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));

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
    await tester.tap(find.byKey(const Key('home-popular-tab-v08')));
    await tester.pumpAndSettle();
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

  testWidgets('owner enters own locked room without PIN prompt', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());

    await tester.tap(find.byKey(const Key('create-room-v06')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Password Lock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('create-room-pin-v08')), '4321');
    final createSubmit = find.byKey(const Key('create-room-submit-v06'));
    await tester.ensureVisible(createSubmit);
    await tester.pumpAndSettle();
    await tester.tap(createSubmit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mine-my-room-card-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mine-my-room-card-v08')));
    await tester.pumpAndSettle();

    expect(find.byType(RoomV07), findsOneWidget);
    expect(find.byKey(const Key('join-room-pin-v06')), findsNothing);
  });

  testWidgets('non-owner cannot see owner management controls', (tester) async {
    setPhoneViewport(tester);
    final room = RoomData('Guest room', '999', '🎧', true, pin: '4321');
    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();

    final tools = find.byKey(const Key('v07-tools-grid'));
    expect(
      find.descendant(of: tools, matching: find.text('Owner')),
      findsNothing,
    );
    expect(
      find.descendant(of: tools, matching: find.text('Settings')),
      findsNothing,
    );
    expect(
      find.descendant(of: tools, matching: find.text('LP')),
      findsNothing,
    );
    expect(
      find.descendant(of: tools, matching: find.text('Admins')),
      findsNothing,
    );
    expect(
      find.descendant(of: tools, matching: find.text('Block')),
      findsNothing,
    );
  });

  testWidgets('owner panel exposes management and AI gift assistant',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData(
      'Owner panel room',
      'OWN-1',
      '👑',
      false,
      ownedByMe: true,
    );
    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    final ownerTool = find.descendant(
      of: find.byKey(const Key('v07-tools-grid')),
      matching: find.text('Owner'),
    );
    expect(ownerTool, findsOneWidget);
    await tester.tap(ownerTool);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owner-panel-v08')), findsOneWidget);
    expect(find.text('Room Owner Panel'), findsOneWidget);
    expect(find.text('Room Controls'), findsOneWidget);

    final aiTile = find.byKey(const Key('ai-gift-assistant-v08'));
    await tester.scrollUntilVisible(
      aiTile,
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(aiTile);
    await tester.pumpAndSettle();
    await tester.tap(aiTile);
    await tester.pumpAndSettle();

    expect(find.text('AI Gift Assistant'), findsWidgets);
    expect(find.byKey(const Key('ai-gift-send-v08')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-gift-send-v08')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm AI Gift'), findsOneWidget);
    expect(find.byKey(const Key('confirm-ai-gift-v08')), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('room lock sets a 4-6 digit PIN and disables cleanly',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData('Test room', '123', '🎧', false, ownedByMe: true);
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
    final createSubmit = find.byKey(const Key('create-room-submit-v06'));
    await tester.ensureVisible(createSubmit);
    await tester.pumpAndSettle();
    await tester.tap(createSubmit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mine-my-room-card-v08')), findsOneWidget);
    expect(find.byKey(const Key('create-room-v06')), findsNothing);
    expect(find.byKey(const Key('my-room-home-v08')), findsOneWidget);
    expect(find.byType(CreateRoomV07), findsNothing);

    await tester.tap(find.byKey(const Key('home-popular-tab-v08')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('popular-user-search-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-mine-tab-v08')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-room-v06')), findsNothing);
    expect(find.byKey(const Key('my-room-home-v08')), findsOneWidget);
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

  test('diamond conversion never burns balance for zero coin output', () {
    final economy = DemoEconomy();
    final beforeDiamonds = economy.diamonds;
    final beforeCoins = economy.coins;

    expect(economy.convertDiamonds(1), isFalse);
    expect(economy.diamonds, beforeDiamonds);
    expect(economy.coins, beforeCoins);
  });

  test('message notifications toggle suppresses demo inbox notifications', () {
    final economy = DemoEconomy();
    final user = economy.users[2];
    final beforeInbox = economy.inbox.length;

    economy.messageNotifications = false;
    economy.sendDirectMessage(user, 'hello without notification');

    expect(economy.conversationFor(user.id).last, 'You: hello without notification');
    expect(economy.inbox.length, beforeInbox);
  });

  test('dynamic video gift limits and VIP duration rules are fixed', () {
    expect(dynamicGiftMaxVideoBytesV08, 12 * 1024 * 1024);
    expect(dynamicGiftMaxVideoDurationV08, const Duration(seconds: 8));

    expect(roomGiftLeasesForVipV08(7), isEmpty);
    expect(
      roomGiftLeasesForVipV08(8),
      const [GiftLeaseV08.days15],
    );
    expect(
      roomGiftLeasesForVipV08(9),
      const [GiftLeaseV08.days15, GiftLeaseV08.month1],
    );
    expect(
      roomGiftLeasesForVipV08(10),
      const [
        GiftLeaseV08.days15,
        GiftLeaseV08.month1,
        GiftLeaseV08.months3,
      ],
    );
    expect(
      roomGiftLeasesForVipV08(11),
      const [
        GiftLeaseV08.days15,
        GiftLeaseV08.month1,
        GiftLeaseV08.months3,
        GiftLeaseV08.months6,
        GiftLeaseV08.lifetime,
      ],
    );
  });

  test('dynamic gift expiry hides expired gifts but lifetime stays active', () {
    final now = DateTime(2026, 9, 19);
    final store = DynamicGiftStoreV08();
    store.add(
      DynamicGiftV08(
        id: 'expired',
        name: 'Old Gift',
        coins: 100,
        videoPath: '/tmp/old.mp4',
        videoBytes: 1024,
        videoDuration: const Duration(seconds: 8),
        lease: GiftLeaseV08.days15,
        createdAt: now.subtract(const Duration(days: 16)),
        createdBy: 'Room Owner',
        roomId: 'R1',
      ),
    );
    store.add(
      DynamicGiftV08(
        id: 'life',
        name: 'Lifetime Gift',
        coins: 200,
        videoPath: '/tmp/life.mp4',
        videoBytes: 1024,
        videoDuration: const Duration(seconds: 8),
        lease: GiftLeaseV08.lifetime,
        createdAt: now.subtract(const Duration(days: 500)),
        createdBy: 'App Owner',
      ),
    );

    final active = store.activeForRoom('R1', now);
    expect(active.map((gift) => gift.id), contains('life'));
    expect(active.map((gift) => gift.id), isNot(contains('expired')));
  });

  testWidgets('VIP8 room owner can open video gift uploader while VIP7 is locked',
      (tester) async {
    setPhoneViewport(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: DynamicGiftManagerV08(
          title: 'Room Video Gifts',
          vipLevel: 7,
          isAppOwner: false,
          roomId: 'R1',
        ),
      ),
    );
    expect(find.text('VIP8+ required'), findsOneWidget);
    expect(find.byKey(const Key('add-video-gift-v08')), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: DynamicGiftManagerV08(
          title: 'Room Video Gifts',
          vipLevel: 8,
          isAppOwner: false,
          roomId: 'R1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-video-gift-v08')), findsOneWidget);
    expect(find.textContaining('Video maximum 8 seconds'), findsOneWidget);
    expect(find.textContaining('File maximum 12 MB'), findsOneWidget);
  });

  test('country flags use 21K and render regional flag emoji', () {
    expect(flagGiftsV08.every((gift) => gift.coins == 21000), isTrue);
    expect(flagEmojiV08('IN'), '🇮🇳');
    expect(flagEmojiV08('US'), '🇺🇸');
  });
  testWidgets('locking occupied seat moves user to audience and keeps them there on reopen',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData(
      'Seat lock room',
      'LOCK-SEAT-1',
      '🎧',
      false,
      ownedByMe: true,
    );

    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));
    expect(find.text('Aisha'), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-seat-2-v08')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seat-lock-action-v08')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audience-strip-v08')), findsOneWidget);
    expect(find.byKey(const Key('audience-id-10000011-v08')), findsOneWidget);
    expect(room.savedLockedSeats, contains(2));
    expect(room.audienceMembers, contains('Aisha'));
    expect(
      find.descendant(
        of: find.byKey(const Key('room-seat-2-v08')),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audience-id-10000011-v08')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('room-seat-2-v08')),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('seat-label-2-v08'))).data,
      'Seat 3',
    );

    await tester.tap(find.byKey(const Key('room-seat-2-v08')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seat-lock-action-v08')));
    await tester.pumpAndSettle();

    expect(room.savedLockedSeats, isNot(contains(2)));
    expect(room.audienceMembers, contains('Aisha'));
    expect(
      tester.widget<Text>(find.byKey(const Key('seat-label-2-v08'))).data,
      'Seat 3',
    );
    expect(find.byKey(const Key('audience-id-10000011-v08')), findsOneWidget);
  });

  testWidgets('invite mode keeps guest in audience until owner or admin approves',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData(
      'Invite room',
      'INVITE-1',
      '🎧',
      false,
      inviteMode: true,
    );

    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));
    await tester.tap(find.byKey(const Key('room-seat-3-v08')));
    await tester.pumpAndSettle();

    expect(find.text('Request Seat'), findsOneWidget);
    expect(find.text('Owner or Admin approval required'), findsOneWidget);
    await tester.tap(find.byKey(const Key('seat-join-action-v08')));
    await tester.pumpAndSettle();

    expect(room.pendingSeatRequests[3], 'You');
    expect(room.audienceMembers, contains('You'));
    expect(
      tester.widget<Text>(find.byKey(const Key('seat-label-3-v08'))).data,
      'Seat 4',
    );
    expect(find.textContaining('Waiting for Owner/Admin approval'), findsWidgets);
  });

  testWidgets('room owner can approve a pending invite-mode seat request',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData(
      'Owner approval room',
      'INVITE-OWNER',
      '👑',
      false,
      inviteMode: true,
      ownedByMe: true,
    );
    room.audienceMembers.add('Aisha');
    room.pendingSeatRequests[3] = 'Aisha';

    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));
    await tester.tap(find.byKey(const Key('room-seat-3-v08')));
    await tester.pumpAndSettle();

    expect(find.text('Approve Aisha'), findsOneWidget);
    await tester.tap(find.byKey(const Key('seat-approve-request-v08')));
    await tester.pumpAndSettle();

    expect(room.pendingSeatRequests.containsKey(3), isFalse);
    expect(room.audienceMembers, isNot(contains('Aisha')));
    expect(
      tester.widget<Text>(find.byKey(const Key('seat-label-3-v08'))).data,
      'Aisha',
    );
  });

  testWidgets('room admin can approve a pending invite-mode seat request',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData(
      'Admin approval room',
      'INVITE-ADMIN',
      '🛡️',
      false,
      inviteMode: true,
      currentUserIsAdmin: true,
    );
    room.audienceMembers.add('Aisha');
    room.pendingSeatRequests[3] = 'Aisha';

    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));
    await tester.tap(find.byKey(const Key('room-seat-3-v08')));
    await tester.pumpAndSettle();

    expect(find.text('Approve Aisha'), findsOneWidget);
    await tester.tap(find.byKey(const Key('seat-approve-request-v08')));
    await tester.pumpAndSettle();

    expect(room.pendingSeatRequests.containsKey(3), isFalse);
    expect(room.audienceMembers, isNot(contains('Aisha')));
    expect(
      tester.widget<Text>(find.byKey(const Key('seat-label-3-v08'))).data,
      'Aisha',
    );
  });



  testWidgets('main owner panel exposes functional control sections',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(home: MainOwnerPanelV08()),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    for (final keyName in const [
      'main-owner-dashboard-v08',
      'owner-global-announcement-v08',
      'owner-users-roles-v08',
      'owner-moderation-v08',
      'owner-feature-controls-v08',
      'owner-game-controls-v08',
      'owner-economy-controls-v08',
      'main-owner-video-gifts-v08',
    ]) {
      final finder = find.byKey(Key(keyName));
      await tester.scrollUntilVisible(
        finder,
        260,
        scrollable: scrollable,
      );
      expect(finder, findsOneWidget);
    }
  });

  testWidgets('owner can disable gifts and room creation',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(home: OwnerFeatureControlsV08()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('owner-gifts-toggle-v08')));
    await tester.pumpAndSettle();
    expect(appOwnerControlsV08.giftsEnabled, isFalse);

    final economy = DemoEconomy();
    final recipient = economy.users[2];
    final gift = normalGiftsV08.first;
    expect(economy.sendGiftV08(gift, recipient, 'OWNER-TEST'), isFalse);

    await tester.tap(find.byKey(const Key('owner-room-create-toggle-v08')));
    await tester.pumpAndSettle();
    expect(appOwnerControlsV08.roomCreationEnabled, isFalse);
  });

  testWidgets('owner game switches disable individual games',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(home: OwnerGameControlsV08()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('owner-game-ludo-v08')));
    await tester.pumpAndSettle();
    expect(appOwnerControlsV08.ludoEnabled, isFalse);

    await tester.pumpWidget(
      const MaterialApp(home: GamesCenterV08()),
    );
    await tester.pumpAndSettle();

    final ludo = tester.widget<InkWell>(
      find.byKey(const Key('game-ludo-v08')),
    );
    expect(ludo.onTap, isNull);
    expect(find.text('Disabled by Owner'), findsOneWidget);
  });

  testWidgets('owner announcement is published to home',
      (tester) async {
    setPhoneViewport(tester);
    appOwnerControlsV08.setAnnouncement('Server event tonight at 9 PM');
    await tester.pumpWidget(
      const MaterialApp(home: V07Home()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('global-announcement-v08')), findsOneWidget);
    expect(find.text('Server event tonight at 9 PM'), findsOneWidget);
  });

  test('owner economy share changes gift settlement', () {
    appOwnerControlsV08.setOwnerGiftSharePercent(20);
    final economy = DemoEconomy();
    final recipient = economy.users[2];
    final owner = economy.users.first;
    final before = owner.diamonds;
    final gift = normalGiftsV08.firstWhere((item) => item.coins >= 1000);

    expect(economy.sendGiftV08(gift, recipient, 'ECON-OWNER'), isTrue);
    expect(owner.diamonds - before, gift.coins * 20 ~/ 100);
  });


  test('changing a user ID automatically changes owned Room ID', () {
    final user = demoEconomy.byName('Aisha');
    final oldId = user.id;
    final room = RoomData(
      'Aisha Room',
      oldId,
      '🌸',
      false,
      ownerUserId: oldId,
    );
    appOwnerControlsV08.globalAdminIds.add(oldId);
    appOwnerControlsV08.userVipLevels[oldId] = 7;

    expect(demoEconomy.changeUserId(user, '20000011'), isTrue);
    expect(user.id, '20000011');
    expect(room.id, '20000011');
    expect(room.ownerUserId, '20000011');
    expect(appOwnerControlsV08.globalAdminIds, contains('20000011'));
    expect(appOwnerControlsV08.globalAdminIds, isNot(contains(oldId)));
    expect(appOwnerControlsV08.userVipLevels['20000011'], 7);
  });

  test('changing main owner ID automatically changes owned Room ID', () {
    final oldId = demoEconomy.currentUserId;
    final room = RoomData(
      'My Synced Room',
      oldId,
      '👑',
      false,
      ownedByMe: true,
      ownerUserId: oldId,
    );

    expect(demoEconomy.changeCurrentUserId('20000050'), isTrue);
    expect(demoEconomy.currentUserId, '20000050');
    expect(room.id, '20000050');
    expect(room.ownerUserId, '20000050');
  });

  test('duplicate and non-numeric user IDs are rejected', () {
    final aisha = demoEconomy.byName('Aisha');
    final admin = demoEconomy.byName('Admin');

    expect(demoEconomy.changeUserId(aisha, admin.id), isFalse);
    expect(demoEconomy.changeUserId(aisha, 'ABC12345'), isFalse);
    expect(aisha.id, '10000011');
  });


  test('old and new user IDs both resolve to the same user and room', () {
    final user = demoEconomy.byName('Aisha');
    final oldId = user.id;
    final room = RoomData(
      'Aisha Search Room',
      oldId,
      '🌸',
      false,
      ownerUserId: oldId,
    );

    expect(demoEconomy.changeUserId(user, '20000011'), isTrue);
    expect(demoEconomy.findUserByAnyId(oldId), same(user));
    expect(demoEconomy.findUserByAnyId('20000011'), same(user));
    expect(demoEconomy.resolveUserId(oldId), '20000011');
    expect(demoEconomy.findOwnedRoomByAnyUserId(oldId), same(room));
    expect(demoEconomy.findOwnedRoomByAnyUserId('20000011'), same(room));
    expect(room.id, '20000011');
    expect(demoEconomy.isHistoricalUserId(oldId), isTrue);
    expect(demoEconomy.isUserIdAvailable(oldId), isFalse);
  });

  testWidgets('Popular tab opens and ID search exposes Room and User results',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: V07Home()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-popular-tab-v08')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('popular-user-search-v08')), findsOneWidget);
    expect(find.text('Popular Rooms'), findsOneWidget);

    await tester.tap(find.byKey(const Key('popular-user-search-v08')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('popular-user-id-search-input-v08')),
      '10000000',
    );
    await tester.tap(
      find.byKey(const Key('popular-user-id-search-submit-v08')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('popular-id-search-results-v08')), findsOneWidget);
    expect(find.byKey(const Key('popular-search-room-result-v08')), findsOneWidget);
    expect(find.byKey(const Key('popular-search-user-result-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('popular-search-user-result-v08')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('searched-user-id-card-v08')), findsOneWidget);
    await tester.tap(find.byKey(const Key('searched-user-id-card-v08')));
    await tester.pumpAndSettle();
    expect(find.text('User Profile'), findsOneWidget);
  });

  testWidgets('Popular search accepts an old ID after user ID is changed',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: V07Home()));
    await tester.pumpAndSettle();

    final owner = demoEconomy.byName('Owner');
    expect(demoEconomy.changeUserId(owner, '20000000'), isTrue);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-popular-tab-v08')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popular-user-search-v08')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('popular-user-id-search-input-v08')),
      '10000000',
    );
    await tester.tap(
      find.byKey(const Key('popular-user-id-search-submit-v08')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Old ID 10000000'), findsOneWidget);
    expect(find.textContaining('Current ID 20000000'), findsOneWidget);
    expect(find.textContaining('Room ID 20000000'), findsOneWidget);
    expect(find.textContaining('Owner • ID 20000000'), findsOneWidget);
  });


  testWidgets('Mine replaces create icon with home shortcut after room creation',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: V07Home()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-room-v06')), findsOneWidget);
    expect(find.byKey(const Key('my-room-home-v08')), findsNothing);

    await tester.tap(find.byKey(const Key('create-room-v06')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-room-submit-v06')), findsOneWidget);

    final createSubmit = find.byKey(const Key('create-room-submit-v06'));
    await tester.ensureVisible(createSubmit);
    await tester.pumpAndSettle();
    await tester.tap(createSubmit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-room-v06')), findsNothing);
    expect(find.byKey(const Key('my-room-home-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('my-room-home-v08')));
    await tester.pumpAndSettle();

    expect(find.byType(RoomV07), findsOneWidget);
    expect(find.text('My Voice Room'), findsWidgets);
  });


  testWidgets('room owner cannot permanently close or delete room',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData(
      'Permanent Room',
      demoEconomy.currentUserId,
      '👑',
      false,
      ownedByMe: true,
      ownerUserId: demoEconomy.currentUserId,
    );

    await tester.pumpWidget(
      MaterialApp(home: RoomV07(room: room)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    final ownerTool = find.descendant(
      of: find.byKey(const Key('v07-tools-grid')),
      matching: find.text('Owner'),
    );
    expect(ownerTool, findsOneWidget);
    await tester.tap(ownerTool);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owner-panel-v08')), findsOneWidget);
    expect(find.text('Close My Room'), findsNothing);
    expect(find.text('Delete Room'), findsNothing);
    expect(find.byKey(const Key('confirm-close-room-v08')), findsNothing);
    expect(room.closed, isFalse);
  });

  testWidgets('leaving owned room keeps Mine home shortcut',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: V07Home()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-room-v06')));
    await tester.pumpAndSettle();
    final createSubmit = find.byKey(const Key('create-room-submit-v06'));
    await tester.ensureVisible(createSubmit);
    await tester.pumpAndSettle();
    await tester.tap(createSubmit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-room-home-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('my-room-home-v08')));
    await tester.pumpAndSettle();
    expect(find.byType(RoomV07), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-room-home-v08')), findsOneWidget);
    expect(find.byKey(const Key('create-room-v06')), findsNothing);
  });


  testWidgets('Mine shows permanent own room above Recent and Followed sections',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: V07Home()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mine-create-room-card-v08')), findsOneWidget);
    expect(find.byKey(const Key('mine-recent-rooms-tab-v08')), findsOneWidget);
    expect(find.byKey(const Key('mine-followed-rooms-tab-v08')), findsOneWidget);
    expect(find.byKey(const Key('mine-recent-empty-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mine-create-room-card-v08')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('room-dp-gallery-v08')), findsNothing);
    expect(find.byKey(const Key('room-dp-camera-v08')), findsNothing);
    expect(find.byKey(const Key('create-room-name-v08')), findsOneWidget);
    expect(find.byKey(const Key('create-room-description-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-dp-v06')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('room-dp-source-sheet-v08')), findsOneWidget);
    expect(find.byKey(const Key('room-dp-gallery-v08')), findsOneWidget);
    expect(find.byKey(const Key('room-dp-camera-v08')), findsOneWidget);
    expect(find.byKey(const Key('room-dp-emoji-v08')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('create-room-name-v08')),
      'My Permanent Room',
    );
    await tester.enterText(
      find.byKey(const Key('create-room-description-v08')),
      'Music, friends and daily voice chat',
    );
    final createSubmit = find.byKey(const Key('create-room-submit-v06'));
    await tester.ensureVisible(createSubmit);
    await tester.pumpAndSettle();
    await tester.tap(createSubmit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mine-create-room-card-v08')), findsNothing);
    expect(find.byKey(const Key('mine-my-room-card-v08')), findsOneWidget);
    expect(find.text('My Permanent Room'), findsOneWidget);
    expect(
      find.textContaining('Music, friends and daily voice chat'),
      findsOneWidget,
    );
  });

  testWidgets('visited rooms enter Recent only while room has online users',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: V07Home()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-popular-tab-v08')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-v07-room')));
    await tester.pumpAndSettle();

    expect(find.byType(RoomV07), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-mine-tab-v08')));
    await tester.pumpAndSettle();

    expect(find.text('India Official Room'), findsOneWidget);
    expect(find.byKey(const Key('mine-recent-empty-v08')), findsNothing);
    expect(find.textContaining('Recent Rooms (1)'), findsOneWidget);

    final officialRoom = roomRegistryV08.firstWhere(
      (room) => room.name == 'India Official Room',
    );
    officialRoom.onlineUsers = 0;
    await tester.pumpAndSettle();

    expect(find.text('India Official Room'), findsNothing);
    expect(find.byKey(const Key('mine-recent-empty-v08')), findsOneWidget);
    expect(find.textContaining('Recent Rooms (0)'), findsOneWidget);

    officialRoom.onlineUsers = 2;
    await tester.pumpAndSettle();

    expect(find.text('India Official Room'), findsOneWidget);
    expect(find.textContaining('Recent Rooms (1)'), findsOneWidget);
  });

  testWidgets('Followed Rooms shows only followed rooms with online users',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: V07Home()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-popular-tab-v08')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('follow-room-10000000-v08')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-mine-tab-v08')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mine-followed-rooms-tab-v08')));
    await tester.pumpAndSettle();

    expect(find.text('India Official Room'), findsOneWidget);
    expect(find.byKey(const Key('mine-followed-empty-v08')), findsNothing);
    expect(find.textContaining('Followed (1)'), findsOneWidget);

    final officialRoom = roomRegistryV08.firstWhere(
      (room) => room.name == 'India Official Room',
    );
    officialRoom.onlineUsers = 0;
    await tester.pumpAndSettle();

    expect(find.text('India Official Room'), findsNothing);
    expect(find.byKey(const Key('mine-followed-empty-v08')), findsOneWidget);
    expect(find.textContaining('Followed (0)'), findsOneWidget);

    officialRoom.onlineUsers = 4;
    await tester.pumpAndSettle();

    expect(find.text('India Official Room'), findsOneWidget);
    expect(find.textContaining('Followed (1)'), findsOneWidget);
  });

  test('room description is stored on room creation model', () {
    final room = RoomData(
      'Description Room',
      '55555123',
      '🎧',
      false,
      description: 'A persistent room description',
    );
    expect(room.description, 'A persistent room description');
  });


  test('RoomData online state reflects whether any user is present', () {
    final room = RoomData(
      'Online State Room',
      '77777123',
      '🎧',
      false,
      onlineUsers: 0,
    );
    expect(room.isOnline, isFalse);

    room.onlineUsers = 1;
    expect(room.isOnline, isTrue);
  });


  testWidgets('no user profile exposes the app owner admin panel',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileV07())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Main Owner Panel'), findsNothing);
    expect(find.byIcon(Icons.admin_panel_settings_rounded), findsNothing);
    expect(find.byType(MainOwnerPanelV08), findsNothing);

    appOwnerControlsV08.globalAdminIds.add(demoEconomy.currentUserId);
    appOwnerControlsV08.refresh();
    await tester.pumpAndSettle();

    expect(find.text('Main Owner Panel'), findsNothing);
    expect(find.byType(MainOwnerPanelV08), findsNothing);
  });


  testWidgets('Discover cards all navigate to active destinations',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DiscoverV06())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('discover-voice-rooms-v08')));
    await tester.pumpAndSettle();
    expect(find.byType(V07Home), findsOneWidget);
    expect(find.text('Popular Rooms'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('discover-game-center-v08')));
    await tester.pumpAndSettle();
    expect(find.byType(GamesCenterV08), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('discover-music-v08')));
    await tester.pumpAndSettle();
    expect(find.byType(MusicCenterV08), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('discover-vip-v08')));
    await tester.pumpAndSettle();
    expect(find.byType(VipCenterV07), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('discover-events-v08')));
    await tester.pumpAndSettle();
    expect(find.byType(EventsCenterV08), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('discover-official-v08')));
    await tester.pumpAndSettle();
    expect(find.byType(V07Home), findsOneWidget);
    expect(find.text('Official Rooms'), findsOneWidget);
  });

  testWidgets('Music and Events controls are interactive',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: MusicCenterV08()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('music-track-0-v08')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('music-selected-track-v08')), findsOneWidget);
    expect(find.text('Chill Room'), findsWidgets);

    await tester.tap(find.byKey(const Key('music-stop-v08')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('music-selected-track-v08')), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: EventsCenterV08()));
    await tester.pumpAndSettle();
    final join = find.byKey(const Key('event-join-0-v08'));
    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(find.text('Leave'), findsOneWidget);
    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(find.text('Join'), findsWidgets);
  });

  testWidgets('Room Invite More Report Info and Music tools all respond',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData(
      'Interaction Room',
      '88888001',
      '🎧',
      false,
      onlineUsers: 2,
      description: 'Interaction smoke test room',
    );
    await tester.pumpWidget(MaterialApp(home: RoomV07(room: room)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    expect(find.text('Room Invite'), findsOneWidget);
    expect(find.byKey(const Key('room-invite-details-v08')), findsOneWidget);
    final copyInvite = tester.widget<FilledButton>(
      find.byKey(const Key('copy-room-invite-v08')),
    );
    expect(copyInvite.onPressed, isNotNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    final musicTool = find.descendant(
      of: find.byKey(const Key('v07-tools-grid')),
      matching: find.text('Music'),
    );
    await tester.tap(musicTool);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-music-sheet-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-music-chill-room-v08')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-selected-music-v08')), findsOneWidget);
    expect(find.textContaining('Chill Room'), findsWidgets);

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    final moreTool = find.descendant(
      of: find.byKey(const Key('v07-tools-grid')),
      matching: find.text('More'),
    );
    await tester.tap(moreTool);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-more-tools-v08')), findsOneWidget);
    expect(find.byKey(const Key('room-share-v08')), findsOneWidget);
    expect(find.byKey(const Key('room-report-v08')), findsOneWidget);
    expect(find.byKey(const Key('room-info-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-info-v08')));
    await tester.pumpAndSettle();
    expect(find.text('Room Info'), findsOneWidget);
    expect(find.textContaining('88888001'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('v07-tools-grid')),
        matching: find.text('More'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-report-v08')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('report-room-input-v08')),
      'Test report reason',
    );
    await tester.tap(find.byKey(const Key('report-room-submit-v08')));
    await tester.pumpAndSettle();
    expect(find.text('Room report submitted'), findsOneWidget);
  });

  testWidgets('primary visible material buttons are enabled in app shell',
      (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV08());
    await tester.pumpAndSettle();

    for (final element in find.byType(IconButton).evaluate()) {
      final button = element.widget as IconButton;
      expect(button.onPressed, isNotNull);
    }
    for (final element in find.byWidgetPredicate(
      (widget) => widget is ButtonStyleButton,
    ).evaluate()) {
      final button = element.widget as ButtonStyleButton;
      expect(button.onPressed, isNotNull);
    }
  });


  testWidgets('Kick 24h persists across room reopen',
      (tester) async {
    setPhoneViewport(tester);
    final room = RoomData(
      'Kick Test Room',
      demoEconomy.currentUserId,
      '👑',
      false,
      ownedByMe: true,
      ownerUserId: demoEconomy.currentUserId,
      seatCount: 10,
    );

    await tester.pumpWidget(
      MaterialApp(home: RoomV07(key: UniqueKey(), room: room)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room-seat-2-v08')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('seat-kick-24h-v08')), findsOneWidget);

    await tester.tap(find.byKey(const Key('seat-kick-24h-v08')));
    await tester.pumpAndSettle();

    expect(room.kickedUntil.containsKey('Aisha'), isTrue);
    expect(
      room.kickedUntil['Aisha']!.isAfter(DateTime.now()),
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(home: RoomV07(key: UniqueKey(), room: room)),
    );
    await tester.pumpAndSettle();

    final seatLabel = tester.widget<Text>(
      find.byKey(const Key('seat-label-2-v08')),
    );
    expect(seatLabel.data, isNot('Aisha'));
  });

}
