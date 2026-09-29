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


  Future<void> _transferFromRoleWallet(String walletType) async {
    final account = widget.state.auth.current;
    if (account == null) return;

    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    String? errorText;
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            walletType == 'merchant'
                ? 'Merchant Coin Transfer'
                : 'Coin Seller Transfer',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: recipientController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Receiver User ID',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    recipientController.text = account.userId;
                  },
                  icon: const Icon(Icons.person_rounded),
                  label: const Text('My Normal Wallet'),
                ),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Coin amount',
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      final recipient = recipientController.text.trim();
                      final amount =
                          int.tryParse(amountController.text.trim()) ?? 0;
                      if (recipient.isEmpty || amount <= 0) {
                        setDialogState(
                          () => errorText =
                              'Enter a valid User ID and coin amount.',
                        );
                        return;
                      }
                      setDialogState(() {
                        sending = true;
                        errorText = null;
                      });
                      try {
                        await widget.state.backend.transferCoins(
                          account.authToken,
                          recipientUserId: recipient,
                          amountCoins: amount,
                          walletType: walletType,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Transferred ' +
                                  amount.toString() +
                                  ' coins to ID ' +
                                  recipient,
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          sending = false;
                          errorText = error
                              .toString()
                              .replaceFirst('Bad state: ', '');
                        });
                      }
                    },
              child: Text(sending ? 'Sending…' : 'Transfer'),
            ),
          ],
        ),
      ),
    );

    recipientController.dispose();
    amountController.dispose();
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
                if (widget.state.wallet.securityFrozen) ...[
                  const SizedBox(height: 10),
                  RoyalPanel(
                    gradient: FeaturePalette.glow(FeaturePalette.safety),
                    accentColor: FeaturePalette.safety,
                    child: const Text(
                      'Wallet security frozen. Unexpected coin credit was detected. Usable coin balance is hidden and only the Platform Owner can remove this freeze.',
                      style: TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                if (widget.state.wallet.coinSellerActive) ...[
                  const SizedBox(height: 10),
                  RoyalPanel(
                    gradient: FeaturePalette.glow(FeaturePalette.wallet),
                    accentColor: FeaturePalette.wallet,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const ShiningIcon(
                        icon: Icons.storefront_rounded,
                        color: FeaturePalette.wallet,
                        size: 22,
                        boxSize: 42,
                        glow: 0.34,
                      ),
                      title: const Text('Coin Seller Wallet'),
                      subtitle: Text(
                        widget.state.wallet.coinSellerFrozen
                            ? 'Security frozen'
                            : 'Balance: ' +
                                widget.state.wallet.coinSellerBalance.toString(),
                      ),
                      trailing: FilledButton(
                        onPressed: widget.state.wallet.coinSellerFrozen
                            ? null
                            : () => _transferFromRoleWallet('coin_seller'),
                        child: const Text('Transfer'),
                      ),
                    ),
                  ),
                ],
                if (widget.state.wallet.merchantActive) ...[
                  const SizedBox(height: 10),
                  RoyalPanel(
                    gradient: FeaturePalette.glow(FeaturePalette.wallet),
                    accentColor: FeaturePalette.wallet,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const ShiningIcon(
                        icon: Icons.account_balance_rounded,
                        color: FeaturePalette.wallet,
                        size: 22,
                        boxSize: 42,
                        glow: 0.34,
                      ),
                      title: const Text('Merchant Wallet'),
                      subtitle: Text(
                        widget.state.wallet.merchantFrozen
                            ? 'Security frozen'
                            : 'Balance: ' +
                                widget.state.wallet.merchantBalance.toString(),
                      ),
                      trailing: FilledButton(
                        onPressed: widget.state.wallet.merchantFrozen
                            ? null
                            : () => _transferFromRoleWallet('merchant'),
                        child: const Text('Transfer'),
                      ),
                    ),
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
