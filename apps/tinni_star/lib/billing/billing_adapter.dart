class BillingProduct {
  const BillingProduct({
    required this.id,
    required this.title,
    required this.coins,
  });

  final String id;
  final String title;
  final int coins;
}

class BillingReceipt {
  const BillingReceipt({
    required this.productId,
    required this.purchaseToken,
    required this.verified,
  });

  final String productId;
  final String purchaseToken;
  final bool verified;
}

abstract interface class BillingAdapter {
  Future<List<BillingProduct>> products();
  Future<BillingReceipt> purchase(String productId);
}

class LocalBillingAdapter implements BillingAdapter {
  static const _products = [
    BillingProduct(id: 'coins_small', title: '50K Coins', coins: 50000),
    BillingProduct(id: 'coins_large', title: '500K Coins', coins: 500000),
  ];

  @override
  Future<List<BillingProduct>> products() async => _products;

  @override
  Future<BillingReceipt> purchase(String productId) async {
    if (!_products.any((product) => product.id == productId)) {
      throw StateError('Unknown product');
    }
    return BillingReceipt(
      productId: productId,
      purchaseToken: 'LOCAL_DEMO_RECEIPT',
      verified: false,
    );
  }
}
