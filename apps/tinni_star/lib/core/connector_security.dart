import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'function_pack.dart';

class PairingHmacSignatureVerifier implements FunctionPackSignatureVerifier {
  PairingHmacSignatureVerifier(this.secret);

  final String secret;

  String signatureFor(FunctionPack pack) {
    final canonical = jsonEncode({
      'id': pack.id,
      'version': pack.version,
      'minSchema': pack.minSchema,
      'maxSchema': pack.maxSchema,
      'summary': pack.summary,
      'config': {
        'seatCount': pack.config.seatCount,
        'inviteMode': pack.config.inviteMode,
        'seatLockEnabled': pack.config.seatLockEnabled,
        'roomChatEnabled': pack.config.roomChatEnabled,
        'giftsEnabled': pack.config.giftsEnabled,
        'maxGiftCombo': pack.config.maxGiftCombo,
        'ktvEnabled': pack.config.ktvEnabled,
        'gamesEnabled': pack.config.gamesEnabled,
        'cpEnabled': pack.config.cpEnabled,
        'familyEnabled': pack.config.familyEnabled,
      },
    });
    return Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(canonical))
        .toString();
  }

  FunctionPack sign(FunctionPack pack) => pack.withSignature(signatureFor(pack));

  @override
  bool verify(FunctionPack pack) {
    final expected = signatureFor(pack);
    return _constantTimeEquals(expected, pack.signature);
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return diff == 0;
  }
}

String generatePairingToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
