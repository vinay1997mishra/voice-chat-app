import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/discovery/discovery_service.dart';
import 'package:tinni_star/identity/owner_tag.dart';
import 'package:tinni_star/room/room_presence_service.dart';

import 'test_account.dart';

void main() {
  testWidgets('authenticated real user opens real room and renders seat grid',
      (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    final account = attachTestAccount(state);
    final now = DateTime.now();
    state.roomPresence.members.add(
      RoomPresenceMember(
        userId: '92000002',
        displayName: 'Tagged Friend',
        joinedAt: now,
        lastSeen: now,
        ownerTags: const <OwnerTag>[
          OwnerTag(name: 'Official Host', colorHex: '#FF4081'),
        ],
        ownerMedals: const <OwnerTag>[
          OwnerTag(name: 'Verified', colorHex: '#4FC3F7'),
        ],
      ),
    );
    state.discovery.rooms.add(
      RoomSummary(
        id: account.userId,
        title: 'My Real Room',
        country: account.countryCode,
        countryName: account.countryName,
        flagEmoji: account.flagEmoji,
        online: 1,
        seatCount: 12,
        createdAt: DateTime.now(),
        ownerId: account.userId,
        ownerName: account.displayName,
        ownerFlagEmoji: account.flagEmoji,
      ),
    );

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('My Real Room'), findsWidgets);

    final roomCard = find.byKey(Key('room-card-' + account.userId));
    await tester.ensureVisible(roomCard);
    await tester.pumpAndSettle();
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);
    expect(find.byKey(const Key('room-rank-hall-button')), findsOneWidget);
    expect(
      find.byKey(const Key('room-game-floating-button')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('live-owner-tag-92000002-Official Host')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('live-owner-medal-92000002-Verified')),
      findsNothing,
    );

    state.roomSession.controller!.addRoomMessage(
      'Tagged Friend',
      'Hello from tagged user',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('room-comment-tag-92000002-Official Host'),
      ),
      findsOneWidget,
    );

    final taggedDp =
        find.byKey(const Key('room-live-user-dp-92000002'));
    expect(taggedDp, findsOneWidget);
    await tester.ensureVisible(taggedDp);
    await tester.tap(taggedDp);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('room-user-profile-card-92000002')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('room-owner-tag-92000002-Official Host')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('room-owner-medal-92000002-Verified')),
      findsNothing,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room-power-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minimize'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mini-room-bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-room-bar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);
  });

  testWidgets(
      'room tool tiles open the function panel matching their labels',
      (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    final account = attachTestAccount(state);
    state.discovery.rooms.add(
      RoomSummary(
        id: account.userId,
        title: 'My Real Room',
        country: account.countryCode,
        countryName: account.countryName,
        flagEmoji: account.flagEmoji,
        online: 1,
        seatCount: 12,
        createdAt: DateTime.now(),
        ownerId: account.userId,
        ownerName: account.displayName,
        ownerFlagEmoji: account.flagEmoji,
      ),
    );

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    final roomCard = find.byKey(Key('room-card-' + account.userId));
    await tester.ensureVisible(roomCard);
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    Future<void> expectToolOpens(String toolKey, Key panelKey) async {
      await tester.tap(find.byKey(const Key('room-tools-grid-button')));
      await tester.pumpAndSettle();
      final tool = find.byKey(Key(toolKey));
      await tester.ensureVisible(tool);
      await tester.tap(tool);
      await tester.pumpAndSettle();
      expect(find.byKey(panelKey), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('room-share-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-tools-grid-button')));
    await tester.pumpAndSettle();
    expect(find.text('Seat Controls'), findsNothing);
    expect(find.byKey(const Key('room-tool-room-type')), findsOneWidget);
    expect(find.byKey(const Key('room-tool-cover')), findsNothing);
    expect(find.byKey(const Key('room-tool-room-theme')), findsNothing);
    expect(find.byKey(const Key('room-tool-music')), findsOneWidget);
    expect(find.byKey(const Key('room-tool-blacklist')), findsNothing);
    expect(find.byKey(const Key('room-tool-seat-requests')), findsNothing);
    expect(find.byKey(const Key('room-tool-effects')), findsOneWidget);
    expect(find.byKey(const Key('room-tool-feedback')), findsNothing);
    expect(find.byKey(const Key('room-tool-gift')), findsNothing);
    expect(find.byKey(const Key('room-tool-moderation')), findsNothing);
    expect(find.byKey(const Key('room-tool-friends-mode')), findsNothing);
    expect(find.byKey(const Key('room-tool-event-mode')), findsNothing);
    expect(find.byKey(const Key('room-tool-launch-event')), findsNothing);
    expect(find.byKey(const Key('room-tool-stop-event')), findsNothing);
    expect(find.byKey(const Key('room-tool-lock')), findsNothing);
    expect(find.byKey(const Key('room-tool-settings')), findsNothing);
    expect(find.byKey(const Key('room-tool-game')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final removableSong = state.ktv.addLocalSong(
      fileName: 'Wrong Song.mp3',
      sourcePath: '/phone/Music/Wrong Song.mp3',
    );

    await tester.tap(find.byKey(const Key('room-tools-grid-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-tool-music')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-music-panel')), findsOneWidget);
    expect(find.byKey(const Key('room-add-music-button')), findsOneWidget);
    expect(find.text('Add Music'), findsOneWidget);
    expect(find.byKey(const Key('room-music-count')), findsOneWidget);
    expect(
      find.byKey(Key('remove-music-' + removableSong.id)),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await expectToolOpens(
      'room-tool-room-type',
      const Key('room-type-panel'),
    );
    await expectToolOpens(
      'room-tool-lucky-bag',
      const Key('room-lucky-bag-panel'),
    );
    await expectToolOpens(
      'room-tool-effects',
      const Key('room-effects-panel'),
    );

    await tester.tap(find.byKey(const Key('room-tools-grid-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-tool-room-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setting'));
    await tester.pumpAndSettle();
    final lockSetting =
        find.byKey(const Key('room-type-setting-lock'));
    await tester.ensureVisible(lockSetting);
    expect(lockSetting, findsOneWidget);
    expect(find.text('Exactly 5 digits'), findsNothing);
    expect(find.textContaining('Create room password'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room-tools-grid-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room-tool-effects')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('effect-master-effects')), findsOneWidget);
    expect(find.byKey(const Key('effect-master-notices')), findsOneWidget);
    expect(find.byKey(const Key('effect-gift-effects')), findsOneWidget);
    expect(find.byKey(const Key('effect-lucky-gift')), findsOneWidget);
    expect(find.byKey(const Key('effect-gift-sound')), findsOneWidget);

    final originalGiftEffects = state.roomControls.giftEffectsEnabled;
    await tester.tap(find.byKey(const Key('effect-gift-effects')));
    await tester.pumpAndSettle();
    expect(
      state.roomControls.giftEffectsEnabled,
      isNot(originalGiftEffects),
    );

    final effectsList = find.byType(ListView).last;
    await tester.drag(effectsList, const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('effect-gift-fly-in')), findsOneWidget);
    expect(find.byKey(const Key('effect-car-effects')), findsOneWidget);
    expect(find.byKey(const Key('effect-gift-bubble')), findsOneWidget);
    expect(
      find.byKey(const Key('effect-rocket-draw-notice')),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });


  testWidgets(
      'reference room seats game rocket and room info surfaces',
      (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    final account = attachTestAccount(state);
    state.discovery.rooms.add(
      RoomSummary(
        id: account.userId,
        title: 'Reference Room',
        country: account.countryCode,
        countryName: account.countryName,
        flagEmoji: account.flagEmoji,
        online: 1,
        seatCount: 15,
        createdAt: DateTime.now(),
        ownerId: account.userId,
        ownerName: account.displayName,
        ownerAvatarDataUrl: account.avatarDataUrl,
        ownerFlagEmoji: account.flagEmoji,
        announcement: 'Welcome notice',
      ),
    );

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    final roomCard = find.byKey(Key('room-card-' + account.userId));
    await tester.ensureVisible(roomCard);
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('seat-heart-0')), findsOneWidget);
    expect(
      find.byKey(const Key('reference-room-title-pill')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reference-room-rank-pill')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('room-online-members-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('room-game-floating-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('room-rocket-floating-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('room-gift-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-gift-panel')), findsOneWidget);
    expect(find.byKey(const Key('gift-category-normal')), findsOneWidget);
    expect(find.byKey(const Key('gift-category-lucky')), findsOneWidget);
    expect(find.byKey(const Key('gift-category-cp')), findsOneWidget);
    expect(find.byKey(const Key('gift-category-country')), findsOneWidget);
    expect(find.byKey(const Key('gift-category-luxury')), findsOneWidget);
    expect(find.text('Popular'), findsNothing);
    expect(find.text('Backpack'), findsNothing);
    expect(find.byKey(const Key('room-gift-wallet-coins')), findsOneWidget);

    await tester.tap(find.byKey(const Key('gift-category-lucky')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('lucky-gift-quantity-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('lucky-quantity-plus')), findsOneWidget);
    expect(find.byKey(const Key('lucky-quantity-presets')), findsOneWidget);
    await tester.tap(find.byKey(const Key('lucky-quantity-presets')));
    await tester.pumpAndSettle();
    for (final quantity in const <int>[
      9,
      21,
      51,
      99,
      199,
      599,
      899,
      2999,
      7999,
    ]) {
      expect(find.text('×' + quantity.toString()), findsOneWidget);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room-rank-hall-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('reference-room-rank-panel')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('room-rank-tab-day')), findsOneWidget);
    expect(find.byKey(const Key('room-rank-tab-week')), findsOneWidget);
    expect(find.byKey(const Key('room-rank-tab-month')), findsOneWidget);
    expect(
      find.byKey(const Key('room-rank-self-row')),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    state.roomSession.controller!.managerTakeSeat(1);
    state.roomSession.controller!.setSelfMuted(true);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('seat-muted-indicator-1')),
      findsOneWidget,
    );
    state.roomSession.controller!.setSelfMuted(false);
    state.roomSession.controller!.leaveSeat();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seat-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('reference-seat-control-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('seat-control-lock')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('seat-control-mute')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('seat-control-take')),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('room-game-floating-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('room-game-center-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('room-game-center-profile-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('game-center-fruit-jackpot')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('game-center-fruit-party')),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('room-rocket-floating-button')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-rocket-panel')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room-title-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('reference-room-info-sheet')),
      findsOneWidget,
    );
    expect(find.text('Welcome notice'), findsOneWidget);
    expect(
      find.byKey(const Key('reference-room-members-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reference-room-setup-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('reference-room-members-row')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('reference-room-members-panel')),
      findsOneWidget,
    );
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room-title-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('reference-room-setup-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Room Setup'), findsOneWidget);
    expect(
      find.byKey(const Key('reference-room-name-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reference-room-notice-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reference-room-block-list')),
      findsOneWidget,
    );
    expect(find.text('Room Lock'), findsNothing);
    expect(find.text('Public'), findsNothing);
    expect(find.text('Private'), findsNothing);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('reference-room-setup-save')),
      findsOneWidget,
    );
  });


  testWidgets('room settings live only inside Room Type Setting', (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    final account = attachTestAccount(state);
    state.discovery.rooms.add(
      RoomSummary(
        id: account.userId,
        title: 'Settings Room',
        country: account.countryCode,
        countryName: account.countryName,
        flagEmoji: account.flagEmoji,
        online: 1,
        seatCount: 15,
        createdAt: DateTime.now(),
        ownerId: account.userId,
        ownerName: account.displayName,
      ),
    );

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();
    final roomCard = find.byKey(Key('room-card-' + account.userId));
    await tester.ensureVisible(roomCard);
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room-tools-grid-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-tool-settings')), findsNothing);

    await tester.tap(find.byKey(const Key('room-tool-room-type')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-type-panel')), findsOneWidget);
    expect(find.text('Cover'), findsOneWidget);

    await tester.tap(find.text('Setting'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('room-type-setting-seats')),
      findsOneWidget,
    );
    expect(find.text('Free mic'), findsOneWidget);
    expect(find.text('Only managers can speak'), findsOneWidget);

    await tester.tap(find.text('Cover'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-type-cover')), findsOneWidget);
    expect(find.byKey(const Key('room-type-cover-open')), findsOneWidget);

    await tester.tap(find.byKey(const Key('room-type-cover-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-cover-theme-page')), findsOneWidget);
  });

}
