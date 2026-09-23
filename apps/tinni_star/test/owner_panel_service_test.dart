import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/owner/owner_panel_service.dart';

void main() {
  test('owner treasury mints and sends coins with audit logs', () {
    final owner = OwnerPanelService();

    owner.addTreasuryCoins(1000000);
    expect(owner.treasuryCoins, 1000000);

    final sent = owner.debitTreasury(
      amount: 250000,
      receiverId: '20000001',
      walletType: 'coin_seller',
    );

    expect(sent, isTrue);
    expect(owner.treasuryCoins, 750000);
    expect(owner.audit.length, 2);
    expect(owner.audit.first.action, 'treasury_send');
  });

  test('owner can change policies and create VIP/custom panels', () {
    final owner = OwnerPanelService();

    owner.setPolicy('agency_commission_percent', 25);
    expect(owner.policyValues['agency_commission_percent'], 25);

    owner.addVip(name: 'VIP 12', priceCoins: 12000000);
    expect(owner.vips.last.name, 'VIP 12');

    owner.addCustomPanel(name: 'Finance');
    expect(owner.customPanels.single.name, 'Finance');

    final panel = owner.customPanels.single;
    owner.setPanelPermission(panel, 'manage_coin_seller', true);
    expect(panel.permissions, contains('manage_coin_seller'));
  });

  test('only platform owner id passes owner gate', () {
    final owner = OwnerPanelService();

    expect(owner.isOwner(OwnerPanelService.ownerUserId), isTrue);
    expect(owner.isOwner('99999999'), isFalse);
  });
}
