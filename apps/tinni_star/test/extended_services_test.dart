import 'package:flutter_test/flutter_test.dart';

import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/calls/call_service.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/rewards/reward_service.dart';
import 'package:tinni_star/sharing/share_service.dart';

import 'test_account.dart';

class _FakeNativeShare implements NativeShareAdapter {
  String? value;
  @override
  Future<void> share(String text) async => value = text;
}

void main() {
  TinniState makeState() => TinniState(
        runtime: FunctionPackRuntime(
          signatureVerifier: const DevelopmentSignatureVerifier(),
        ),
      );

  test('lucky bag can only be grabbed once by same user', () {
    final state = makeState();
    state.rewards.createLuckyBag(
      id: 'bag-1',
      senderId: '1',
      totalSlots: 2,
      reward: const LuckyBagReward(
        kind: LuckyBagRewardKind.coins,
        label: 'Lucky coins',
        amount: 100,
      ),
    );
    expect(state.rewards.grab('bag-1', '2'), isNotNull);
    expect(state.rewards.grab('bag-1', '2'), isNull);
  });

  test('rocket progresses through reward levels', () {
    final state = makeState();
    state.rewards.launchRocket(2200);
    expect(state.rewards.rocket.level, 2);
    expect(state.rewards.rocket.luckMultiplier, 3);
  });

  test('friend-only call rejects non friend', () {
    final state = makeState();
    expect(
      () => state.calls.initiate(
        callerId: '1',
        receiverId: '2',
        media: CallMedia.voice,
        isFriend: false,
      ),
      throwsStateError,
    );
  });

  test('sharing invokes native share adapter and keeps target history', () async {
    final native = _FakeNativeShare();
    final sharing = ShareService(native: native);
    const payload = SharePayload(title: 'Join Tinni Star', link: 'https://example.test/r/123');
    await sharing.share(ShareTarget.whatsapp, payload);
    expect(native.value, 'Join Tinni Star https://example.test/r/123');
    expect(sharing.history.single, startsWith('whatsapp:'));
  });

  test('system share opens native share instead of copying the link', () async {
    final native = _FakeNativeShare();
    final sharing = ShareService(native: native);
    const payload = SharePayload(
      title: 'Join Tinni Star',
      link: 'https://example.test/r/123',
    );

    await sharing.share(ShareTarget.system, payload);

    expect(native.value, payload.text);
    expect(sharing.history.single, startsWith('system:'));
  });

  test('profile mirrors the authenticated real account', () {
    final state = makeState();
    final account = attachTestAccount(state, name: 'Tinni Queen');
    expect(state.profile.current?.nick, 'Tinni Queen');
    expect(state.profile.current?.userId, account.userId);
    expect(state.profile.current?.flagEmoji, account.flagEmoji);
  });
}
