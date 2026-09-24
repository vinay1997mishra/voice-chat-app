import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/auth/auth_service.dart';

TinniAccount attachTestAccount(
  TinniState state, {
  String userId = '91000001',
  String name = 'Real User',
  String countryCode = 'IN',
  String countryName = 'India',
  String flagEmoji = '🇮🇳',
}) {
  final account = TinniAccount(
    userId: userId,
    email: 'user$userId@example.com',
    displayName: name,
    age: 25,
    signature: 'Test profile',
    countryCode: countryCode,
    countryName: countryName,
    flagEmoji: flagEmoji,
    gender: 'male',
    providers: const <LoginProvider>{LoginProvider.google},
    authToken: 'test-session-token-$userId',
  );
  state.auth.setAuthenticatedAccount(account);
  state.profile.loadFromAccount(account);
  return account;
}
