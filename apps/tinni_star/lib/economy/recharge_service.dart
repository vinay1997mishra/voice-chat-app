import '../billing/billing_adapter.dart';
import 'economy.dart';

class RechargeService {
  RechargeService(this.wallet);

  final WalletService wallet;
  bool firstRechargeCompleted = false;
  final Set<String> processedPurchaseTokens = <String>{};

  bool applyVerifiedReceipt(
    BillingReceipt receipt,
    BillingProduct product,
  ) {
    if (!receipt.verified ||
        receipt.productId != product.id ||
        receipt.purchaseToken.isEmpty ||
        !processedPurchaseTokens.add(receipt.purchaseToken)) {
      return false;
    }

    wallet.creditCoins(product.coins, 'Recharge: ' + product.title);
    firstRechargeCompleted = true;
    return true;
  }
}
