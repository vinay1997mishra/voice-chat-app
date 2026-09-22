import 'package:flutter_test/flutter_test.dart';

import '../lib/app/tinni_state.dart';
import '../lib/community/family_service.dart';
import '../lib/core/function_pack.dart';
import '../lib/economy/economy.dart';
import '../lib/games/game_service.dart';
import '../lib/infra/realtime.dart';

void main() {
  TinniState makeState() => TinniState(
        runtime: FunctionPackRuntime(
          signatureVerifier: const DevelopmentSignatureVerifier(),
        ),
      );

  test('gift spends wallet and records transaction', () {
    final state = makeState();
    final before = state.wallet.coins;
    final tx = state.gifts.send(
      gift: GiftService.catalog.first,
      quantity: 2,
      maxCombo: 100,
      senderId: '10000000',
      receiverIds: const ['20000000'],
    );
    expect(tx, isNotNull);
    expect(state.wallet.coins, before - 200);
    expect(state.gifts.sent.length, 1);
  });

  test('family hierarchy supports deputy and assistant', () {
    final state = makeState();
    state.family.create(
      familyName: 'Tinni Family',
      familyTag: 'TS',
      head: const FamilyMember(
        userId: '1',
        name: 'Owner',
        role: FamilyRole.head,
      ),
    );
    state.family.join(
      const FamilyMember(
        userId: '2',
        name: 'Member',
        role: FamilyRole.member,
      ),
    );
    state.family.appoint('2', FamilyRole.assistant);
    expect(state.family.members.last.role, FamilyRole.assistant);
  });

  test('realtime coordinator joins IM and RTC and publishes mic', () async {
    final rtc = LocalRtcAdapter();
    final im = LocalImAdapter();
    final realtime = RealtimeCoordinator(rtc: rtc, im: im);
    await realtime.enterRoom('room-1', 'user-1');
    expect(rtc.state, RtcConnectionState.joined);
    expect(im.joinedRooms, contains('room-1'));
    await realtime.setMic(true);
    expect(rtc.publishingMic, true);
    expect(im.sentEvents.last['type'], 'mic_state');
  });

  test('game lifecycle settles a round', () {
    final state = makeState();
    state.games.start(GameType.blackjack, const ['1', '2']);
    final settled = state.games.finish();
    expect(settled.state, 'settled');
    expect(state.games.active, isNull);
  });

  test('store inventory rejects duplicate purchase', () {
    final state = makeState();
    const item = StoreItem(
      id: 'car-1',
      name: 'Star Car',
      price: 500,
      type: 'vehicle',
    );
    expect(state.inventory.purchase(item), true);
    expect(state.inventory.purchase(item), false);
  });
}
