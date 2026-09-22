import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/billing/billing_adapter.dart';
import 'package:tinni_star/custom_gift/custom_gift_validation.dart';
import 'package:tinni_star/economy/economy.dart';
import 'package:tinni_star/economy/entitlement_service.dart';
import 'package:tinni_star/economy/recharge_service.dart';
import 'package:tinni_star/effects/effect_players.dart';
import 'package:tinni_star/effects/effect_queue.dart';

void main() {
  test('unverified billing receipt cannot credit wallet', () {
    final wallet = WalletService(coins: 0);
    final recharge = RechargeService(wallet);
    const product = BillingProduct(
      id: 'coins',
      title: 'Coins',
      coins: 50000,
    );
    const receipt = BillingReceipt(
      productId: 'coins',
      purchaseToken: 'demo',
      verified: false,
    );
    expect(recharge.applyVerifiedReceipt(receipt, product), false);
    expect(wallet.coins, 0);
  });

  test('renewable entitlement expires, renews and equips', () {
    final service = EntitlementService();
    final now = DateTime(2026, 9, 22);
    service.grant(
      Entitlement(
        id: 'vehicle-1',
        type: EntitlementType.vehicle,
        expiresAt: now.add(const Duration(days: 1)),
      ),
    );
    expect(service.equip('vehicle-1', now), true);
    expect(service.renew('vehicle-1', const Duration(days: 30), now), true);
  });

  test('custom gift validator checks video policy', () {
    const validator = CustomGiftValidator();
    const metadata = CustomGiftAssetMetadata(
      assetType: 'video',
      bytes: 1024,
      width: 1080,
      height: 1920,
      durationSeconds: 10,
      hasOriginalSound: true,
    );
    expect(validator.validate(metadata).valid, true);
  });

  test('effect router sends MP4 effect to MP4 player', () async {
    final router = EffectRouter();
    const request = EffectRequest(
      id: '1',
      kind: EffectKind.gift,
      asset: 'gift.mp4',
      priority: 50,
    );
    await router.play(request);
    expect((router.mp4 as LocalEffectPlayer).playing, 'gift.mp4');
  });
}
