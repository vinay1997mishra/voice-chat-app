import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../economy/economy.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final account = widget.state.auth.current;
      if (account != null) {
        final remoteWallet = await widget.state.backend.wallet(account.authToken);
        widget.state.wallet.applyRemote(remoteWallet);
      }
      if (!mounted) return;
      setState(() {
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('recharge-screen'),
      appBar: AppBar(
        title: const Text(
          'Wallet',
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
                          'Coins ' + widget.state.wallet.coins.toString() + '\nDiamonds ' + widget.state.wallet.diamonds.toString(),
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
                const GoldSectionTitle('Wallet activity'),
                const SizedBox(height: 8),
                if (widget.state.wallet.history.isEmpty)
                  const RoyalPanel(
                    child: Text(
                      'No wallet activity yet. Tinni Star uses coins and diamonds only; there are no real-money purchase packs.',
                      style: TextStyle(color: RoyalPalette.muted),
                    ),
                  )
                else
                  for (final entry in widget.state.wallet.history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RoyalPanel(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.label),
                          trailing: Text(
                            (entry.amount > 0 ? '+' : '') + entry.amount.toString(),
                            style: TextStyle(
                              color: entry.currency == CurrencyKind.coins
                                  ? FeaturePalette.wallet
                                  : FeaturePalette.gift,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
