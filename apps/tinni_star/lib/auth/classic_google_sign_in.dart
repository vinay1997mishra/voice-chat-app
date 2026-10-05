import 'package:flutter/services.dart';

class ClassicGoogleAccount {
  const ClassicGoogleAccount({required this.idToken, required this.email, this.displayName = ''});
  final String idToken;
  final String email;
  final String displayName;
}

/// A user-selected alternative to Credential Manager on Android. The returned
/// Google ID token goes through the same server verification as the main picker.
class ClassicGoogleSignIn {
  const ClassicGoogleSignIn();
  static const channel = MethodChannel('tinni.star/google_sign_in');

  Future<ClassicGoogleAccount> authenticate({required String serverClientId}) async {
    if (serverClientId.trim().isEmpty) {
      throw StateError('Google login setup is unavailable.');
    }
    final result = await channel.invokeMapMethod<String, dynamic>('authenticate',
      <String, dynamic>{'server_client_id': serverClientId.trim()});
    final token = result?['id_token']?.toString().trim() ?? '';
    final email = result?['email']?.toString() ?? '';
    if (token.isEmpty || email.isEmpty) {
      throw StateError('Google did not return a valid account. Please try again.');
    }
    return ClassicGoogleAccount(idToken: token, email: email,
      displayName: result?['display_name']?.toString() ?? '');
  }
}
