import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/auth/auth_service.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/economy/economy.dart';
import 'package:tinni_star/infra/app_backend_service.dart';

void main() {
  test('wallet ignores older snapshots within one account but accepts another account', () {
    final wallet = WalletService();
    wallet.applyRemote(const RemoteWallet(userId: 'alice', coins: 100, diamonds: 0, banned: false, updatedAt: 20));
    wallet.applyRemote(const RemoteWallet(userId: 'alice', coins: 999, diamonds: 0, banned: false, updatedAt: 10));
    expect(wallet.coins, 100);
    wallet.applyRemote(const RemoteWallet(userId: 'bob', coins: 3, diamonds: 0, banned: false, updatedAt: 1));
    expect(wallet.coins, 3);
  });
  test('private reconnect snapshot applies main coins and publishes the last bet result once', () {
    final state = TinniState(runtime: FunctionPackRuntime(signatureVerifier: const DevelopmentSignatureVerifier()),
      roomPresenceFallbackTimerEnabled: false);
    state.auth.setAuthenticatedAccount(TinniAccount.fromServer({'user_id': 'alice', 'display_name': 'Alice'}, token: 'test'));
    final event = <String, dynamic>{
      'user': {'user_id': 'alice', 'display_name': 'Alice'},
      'wallet': {'user_id': 'alice', 'coins': 25000, 'diamonds': 0, 'updated_at': 20},
      'game_results': [{'id': 'fruit_party:10:alice', 'user_id': 'alice', 'game_key': 'fruit_party',
        'round_id': 10, 'winning_coins': 25000, 'bet_coins': 5000, 'outcome': 'win', 'wallet_type': 'main'}],
    };
    var notices = 0;
    state.gameResults.addListener(() { notices++; });
    state.social.accountEvents.value = event;
    expect(state.wallet.coins, 25000);
    expect(state.gameResults.value.single['outcome'], 'win');
    state.social.accountEvents.value = {...event};
    expect(notices, 1);
    state.social.accountEvents.value = {
      ...event, 'user': {'user_id': 'bob'}, 'wallet': {'coins': 999999},
    };
    expect(state.wallet.coins, 25000);
    state.social.dispose();
  });
}
