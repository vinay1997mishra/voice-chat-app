import 'package:flutter_test/flutter_test.dart';
import '../lib/core/function_pack.dart';

void main() {
  test('owner approval is mandatory', () {
    final runtime = FunctionPackRuntime(
      signatureVerifier: const DevelopmentSignatureVerifier(),
    );
    const pack = FunctionPack(
      id: 'room-core',
      version: 1,
      minSchema: 1,
      maxSchema: 1,
      summary: 'test',
      signature: 'TINNI_DEV_SIGNED',
      config: TinniFunctionConfig(seatCount: 18),
    );

    final result = runtime.apply(pack, ownerApproved: false);
    expect(result.status, PackApplyStatus.rejected);
    expect(runtime.config.seatCount, 12);
  });

  test('valid signed pack applies and rollback restores previous config', () {
    final runtime = FunctionPackRuntime(
      signatureVerifier: const DevelopmentSignatureVerifier(),
    );
    const pack = FunctionPack(
      id: 'room-core',
      version: 1,
      minSchema: 1,
      maxSchema: 1,
      summary: 'test',
      signature: 'TINNI_DEV_SIGNED',
      config: TinniFunctionConfig(seatCount: 18, inviteMode: false),
    );

    expect(
      runtime.apply(pack, ownerApproved: true).status,
      PackApplyStatus.applied,
    );
    expect(runtime.config.seatCount, 18);
    expect(runtime.config.inviteMode, false);

    expect(
      runtime.rollback(ownerApproved: true).status,
      PackApplyStatus.rolledBack,
    );
    expect(runtime.config.seatCount, 12);
    expect(runtime.config.inviteMode, true);
  });

  test('invalid signature is rejected', () {
    final runtime = FunctionPackRuntime(
      signatureVerifier: const DevelopmentSignatureVerifier(),
    );
    const pack = FunctionPack(
      id: 'room-core',
      version: 1,
      minSchema: 1,
      maxSchema: 1,
      summary: 'test',
      signature: 'wrong',
      config: TinniFunctionConfig(),
    );

    expect(
      runtime.apply(pack, ownerApproved: true).status,
      PackApplyStatus.rejected,
    );
  });
}
