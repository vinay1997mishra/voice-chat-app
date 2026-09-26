import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../billing/billing_adapter.dart';
import '../ui/royal_theme.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  bool loading = true;
  String? errorText;
  List<BillingProduct> products = const <BillingProduct>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await widget.state.billing.products();
      if (!mounted) return;
      setState(() {
        products = values;
        loading = false;
        errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _buy(BillingProduct product) async {
    try {
      final receipt = await widget.state.billing.purchase(product.id);
      final applied =
          widget.state.recharge.applyVerifiedReceipt(receipt, product);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            applied
                ? product.title + ' added.'
                : 'Purchase needs verified billing before coins are credited.',
          ),
        ),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('recharge-screen'),
      appBar: AppBar(
        title: const Text(
          'Recharge',
          style: TextStyle(
            color: FeaturePalette.wallet,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                RoyalPanel(
                  gradient: FeaturePalette.glow(FeaturePalette.wallet),
                  accentColor: FeaturePalette.wallet,
                  child: Row(
                    children: [
                      const ShiningIcon(
                        icon: Icons.account_balance_wallet_rounded,
                        color: FeaturePalette.wallet,
                        size: 26,
                        boxSize: 52,
                        glow: 0.38,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Coins ' + widget.state.wallet.coins.toString(),
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 14),
                const GoldSectionTitle('Recharge packs'),
                const SizedBox(height: 8),
                for (final product in products)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RoyalPanel(
                      gradient: FeaturePalette.glow(FeaturePalette.wallet),
                      accentColor: FeaturePalette.wallet,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            color: FeaturePalette.wallet,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              product.title,
                              style: const TextStyle(
                                color: RoyalPalette.cream,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => _buy(product),
                            child: const Text('Top up'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
