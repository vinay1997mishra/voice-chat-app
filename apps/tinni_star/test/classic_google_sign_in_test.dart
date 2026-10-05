import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/auth/classic_google_sign_in.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const auth = ClassicGoogleSignIn();
  tearDown(() => messenger.setMockMethodCallHandler(ClassicGoogleSignIn.channel, null));

  test('alternate picker requests the configured Web client and returns a verifiable ID token', () async {
    messenger.setMockMethodCallHandler(ClassicGoogleSignIn.channel, (call) async {
      expect(call.method, 'authenticate');
      expect((call.arguments as Map)['server_client_id'], 'web-client');
      return {'id_token':'signed-google-token','email':'user@example.test','display_name':'User'};
    });
    final account = await auth.authenticate(serverClientId:'web-client');
    expect(account.idToken,'signed-google-token');
    expect(account.email,'user@example.test');
    expect(account.displayName,'User');
  });

  test('cancelled picker stays cancelled and never fabricates a login', () async {
    var requests = 0;
    messenger.setMockMethodCallHandler(ClassicGoogleSignIn.channel, (call) async {
      requests++;
      throw PlatformException(code:'google_canceled',message:'Google login cancelled.');
    });
    await expectLater(auth.authenticate(serverClientId:'web-client'),
      throwsA(isA<PlatformException>().having((error)=>error.code,'code','google_canceled')));
    expect(requests,1);
  });

  test('missing token and missing config cannot become authenticated accounts', () async {
    var requests = 0;
    messenger.setMockMethodCallHandler(ClassicGoogleSignIn.channel, (call) async {
      requests++;
      return {'email':'user@example.test'};
    });
    await expectLater(auth.authenticate(serverClientId:''),throwsStateError);
    expect(requests,0);
    await expectLater(auth.authenticate(serverClientId:'web-client'),throwsStateError);
    expect(requests,1);
  });
}
