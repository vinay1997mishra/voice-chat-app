import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/core/connector_security.dart';
import 'package:tinni_star/core/function_pack.dart';

void main() {
  test('pairing HMAC verifier signs and validates a Function Pack', () {
    final verifier = PairingHmacSignatureVerifier('pair-secret');
    const unsigned = FunctionPack(
      id: 'room-core',
      version: 2,
      minSchema: 1,
      maxSchema: 1,
      summary: 'signed test',
      signature: '',
      config: TinniFunctionConfig(
        seatCount: 20,
        gamesEnabled: true,
      ),
    );

    final signed = verifier.sign(unsigned);
    expect(signed.signature, isNotEmpty);
    expect(verifier.verify(signed), true);
    expect(
      verifier.verify(
        signed.withSignature(signed.signature + '0'),
      ),
      false,
    );
  });

  test('pairing token has high-entropy URL-safe shape', () {
    final one = generatePairingToken();
    final two = generatePairingToken();
    expect(one, isNot(equals(two)));
    expect(one.length, greaterThanOrEqualTo(40));
    expect(one.contains('='), false);
  });
}
