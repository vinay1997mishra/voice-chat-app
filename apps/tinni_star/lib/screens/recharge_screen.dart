import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../economy/economy.dart';
import '../ui/royal_theme.dart';
import 'messages_screen.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  bool loading = true;
  String? errorText;
  List<Map<String, dynamic>> providers = <Map<String, dynamic>>[];
  final Map<String, bool> _passwordConfigured = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final account = widget.state.auth.current;
      if (account != null) {
        final results = await Future.wait<dynamic>(<Future<dynamic>>[
          widget.state.backend.wallet(account.authToken),
          widget.state.backend.rechargeProviders(account.authToken),
        ]);
        widget.state.wallet.applyRemote(results[0]);
        providers = List<Map<String, dynamic>>.from(results[1]);

        final checks = <Future<void>>[];
        if (widget.state.wallet.coinSellerActive) {
          checks.add(
            widget.state.backend
                .roleWalletPasswordConfigured(
                  account.authToken,
                  walletType: 'coin_seller',
                )
                .then((value) => _passwordConfigured['coin_seller'] = value),
          );
        } else {
          _passwordConfigured.remove('coin_seller');
        }
        if (widget.state.wallet.merchantActive) {
          checks.add(
            widget.state.backend
                .roleWalletPasswordConfigured(
                  account.authToken,
                  walletType: 'merchant',
                )
                .then((value) => _passwordConfigured['merchant'] = value),
          );
        } else {
          _passwordConfigured.remove('merchant');
        }
        if (checks.isNotEmpty) await Future.wait<void>(checks);
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

  String _roleTitle(String walletType) =>
      walletType == 'merchant' ? 'Merchant' : 'Coin Seller';

  int _providerCoins(Map<String, dynamic> provider) {
    final value = provider['balance_coins'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCoins(int value) {
    final text = value.toString();
    return text.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  String _providerUsdText(Map<String, dynamic> provider) {
    final value = provider['usd_cents'];
    final cents = value is int
        ? value
        : value is num
            ? value.toInt()
            : int.tryParse(value?.toString() ?? '') ?? 0;
    return '\
  ImageProvider? _avatarProvider(dynamic value) {
    final source = value?.toString().trim() ?? '';
    if (source.startsWith('data:image/')) {
      try {
        return MemoryImage(base64Decode(source.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return NetworkImage(source);
    }
    return null;
  }

  Future<bool> _setInitialRolePassword(String walletType) async {
    final account = widget.state.auth.current;
    if (account == null) return false;
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? dialogError;
    bool saving = false;
    var saved = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Set ${_roleTitle(walletType)} transfer password'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'First time setup. This password will be required whenever coins are sent to a user wallet.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Create password',
                    helperText: '6 to 64 characters',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final password = passwordController.text;
                      if (password.length < 6 || password.length > 64) {
                        setDialogState(
                          () => dialogError =
                              'Password must be 6 to 64 characters.',
                        );
                        return;
                      }
                      if (password != confirmController.text) {
                        setDialogState(
                          () => dialogError =
                              'Password and confirm password do not match.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await widget.state.backend.setupRoleWalletPassword(
                          account.authToken,
                          walletType: walletType,
                          password: password,
                        );
                        saved = true;
                        _passwordConfigured[walletType] = true;
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          saving = false;
                          dialogError = error
                              .toString()
                              .replaceFirst('Bad state: ', '');
                        });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save password'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    confirmController.dispose();
    if (saved && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet transfer password created.')),
      );
    }
    return saved;
  }

  Future<void> _resetRolePassword(String walletType) async {
    final account = widget.state.auth.current;
    if (account == null) return;

    Map<String, dynamic> started;
    try {
      started = await widget.state.backend.startRoleWalletPasswordReset(
        account.authToken,
        walletType: walletType,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
      return;
    }

    if (!mounted) return;
    final requestId = started['request_id']?.toString() ?? '';
    final email = started['email']?.toString() ?? '';
    if (requestId.isEmpty) return;

    final otpController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? dialogError;
    bool saving = false;
    var completed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reset ${_roleTitle(walletType)} password'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    email.isEmpty
                        ? 'Enter the OTP sent to your account email.'
                        : 'OTP sent to $email',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: '6-digit email OTP',
                    ),
                  ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      helperText: '6 to 64 characters',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      dialogError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final otp = otpController.text.trim();
                      final password = passwordController.text;
                      if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                        setDialogState(
                          () => dialogError = 'Enter the 6-digit OTP.',
                        );
                        return;
                      }
                      if (password.length < 6 || password.length > 64) {
                        setDialogState(
                          () => dialogError =
                              'Password must be 6 to 64 characters.',
                        );
                        return;
                      }
                      if (password != confirmController.text) {
                        setDialogState(
                          () => dialogError =
                              'Password and confirm password do not match.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await widget.state.backend
                            .verifyRoleWalletPasswordReset(
                          account.authToken,
                          walletType: walletType,
                          requestId: requestId,
                          otp: otp,
                        );
                        await widget.state.backend
                            .completeRoleWalletPasswordReset(
                          account.authToken,
                          walletType: walletType,
                          requestId: requestId,
                          newPassword: password,
                        );
                        completed = true;
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          saving = false;
                          dialogError = error
                              .toString()
                              .replaceFirst('Bad state: ', '');
                        });
                      }
                    },
              child: Text(saving ? 'Resetting…' : 'Reset password'),
            ),
          ],
        ),
      ),
    );

    otpController.dispose();
    passwordController.dispose();
    confirmController.dispose();

    if (completed && mounted) {
      _passwordConfigured[walletType] = true;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet transfer password reset.')),
      );
    }
  }

  Future<void> _transferFromRoleWallet(String walletType) async {
    final account = widget.state.auth.current;
    if (account == null) return;

    if (_passwordConfigured[walletType] != true) {
      await _setInitialRolePassword(walletType);
      return;
    }

    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    final passwordController = TextEditingController();
    String? dialogError;
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${_roleTitle(walletType)} Coin Transfer'),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      recipientController.text = account.userId;
                    },
                    icon: const Icon(Icons.person_rounded),
                    label: const Text('My Normal Wallet'),
                  ),
                ),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Coin amount',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Wallet password',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: sending
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                            _resetRolePassword(walletType);
                          },
                    child: const Text('Reset password'),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  sending ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      final recipient = recipientController.text.trim();
                      final amount =
                          int.tryParse(amountController.text.trim()) ?? 0;
                      final password = passwordController.text;
                      if (recipient.isEmpty ||
                          amount <= 0 ||
                          password.isEmpty) {
                        setDialogState(
                          () => dialogError =
                              'Enter User ID, coin amount and password.',
                        );
                        return;
                      }
                      setDialogState(() {
                        sending = true;
                        dialogError = null;
                      });
                      try {
                        await widget.state.backend.transferCoins(
                          account.authToken,
                          recipientUserId: recipient,
                          amountCoins: amount,
                          walletType: walletType,
                          password: password,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Transferred $amount coins to ID $recipient',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          sending = false;
                          dialogError = error
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
    passwordController.dispose();
  }

  Future<void> _messageProvider(Map<String, dynamic> provider) async {
    final userId = provider['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MessagesScreen(
          state: widget.state,
          targetUserId: userId,
          targetName: provider['display_name']?.toString() ?? userId,
          targetAvatarDataUrl: provider['avatar_data_url']?.toString(),
        ),
      ),
    );
  }

  Widget _buildProviders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GoldSectionTitle('Recharge from Coin Seller / Merchant'),
        const SizedBox(height: 8),
        if (providers.isEmpty)
          const RoyalPanel(
            child: Text(
              'No Coin Seller or Merchant with at least \$5 balance is available right now.',
              style: TextStyle(color: RoyalPalette.muted),
            ),
          )
        else
          for (final provider in providers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RoyalPanel(
                gradient: FeaturePalette.glow(FeaturePalette.wallet),
                accentColor: FeaturePalette.wallet,
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage:
                                _avatarProvider(provider['avatar_data_url']),
                            child:
                                _avatarProvider(provider['avatar_data_url']) ==
                                        null
                                    ? const Icon(Icons.storefront_rounded)
                                    : null,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider['display_name']?.toString() ??
                                      provider['user_id']?.toString() ??
                                      'Seller',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${provider['wallet_type'] == 'merchant' ? 'Merchant' : 'Coin Seller'} • ID ${provider['user_id'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: RoyalPalette.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    SizedBox(
                      width: 92,
                      child: FilledButton.icon(
                        onPressed: () => _messageProvider(provider),
                        icon: const Icon(
                          Icons.chat_bubble_rounded,
                          size: 15,
                        ),
                        label: const Text(
                          'Message',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 9,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    SizedBox(
                      width: 88,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCoins(_providerCoins(provider)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: FeaturePalette.wallet,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _providerUsdText(provider),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: RoyalPalette.cream,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _roleWalletCard({
    required String walletType,
    required int balance,
    required bool frozen,
  }) {
    final configured = _passwordConfigured[walletType] == true;
    return RoyalPanel(
      gradient: FeaturePalette.glow(FeaturePalette.wallet),
      accentColor: FeaturePalette.wallet,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ShiningIcon(
              icon: walletType == 'merchant'
                  ? Icons.account_balance_rounded
                  : Icons.storefront_rounded,
              color: FeaturePalette.wallet,
              size: 22,
              boxSize: 42,
              glow: 0.34,
            ),
            title: Text('${_roleTitle(walletType)} Wallet'),
            subtitle: Text(
              frozen ? 'Security frozen' : 'Balance: $balance',
            ),
            trailing: FilledButton(
              onPressed: frozen
                  ? null
                  : () => _transferFromRoleWallet(walletType),
              child: Text(configured ? 'Transfer' : 'Set Password'),
            ),
          ),
          if (configured && !frozen)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _resetRolePassword(walletType),
                child: const Text('Reset transfer password'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noCoins = widget.state.wallet.coins <= 0;
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                            'Coins ${widget.state.wallet.coins}\nDiamonds ${widget.state.wallet.diamonds}',
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
                  if (noCoins) ...[
                    const SizedBox(height: 10),
                    RoyalPanel(
                      gradient: FeaturePalette.glow(FeaturePalette.safety),
                      accentColor: FeaturePalette.safety,
                      child: const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: FeaturePalette.safety,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your coins are finished. Recharge from an active Coin Seller or Merchant below.',
                              style: TextStyle(
                                color: RoyalPalette.cream,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildProviders(),
                  ],
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
                    _roleWalletCard(
                      walletType: 'coin_seller',
                      balance: widget.state.wallet.coinSellerBalance,
                      frozen: widget.state.wallet.coinSellerFrozen,
                    ),
                  ],
                  if (widget.state.wallet.merchantActive) ...[
                    const SizedBox(height: 10),
                    _roleWalletCard(
                      walletType: 'merchant',
                      balance: widget.state.wallet.merchantBalance,
                      frozen: widget.state.wallet.merchantFrozen,
                    ),
                  ],
                  if (!noCoins) ...[
                    const SizedBox(height: 14),
                    _buildProviders(),
                  ],
                  const SizedBox(height: 14),
                  const GoldSectionTitle('Wallet activity'),
                  const SizedBox(height: 8),
                  if (widget.state.wallet.history.isEmpty)
                    const RoyalPanel(
                      child: Text(
                        'No wallet activity yet.',
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
                              '${entry.amount > 0 ? '+' : ''}${entry.amount}',
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
            ),
    );
  }
}
 + (cents / 100).toStringAsFixed(2);
  }

  ImageProvider? _avatarProvider(dynamic value) {
    final source = value?.toString().trim() ?? '';
    if (source.startsWith('data:image/')) {
      try {
        return MemoryImage(base64Decode(source.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return NetworkImage(source);
    }
    return null;
  }

  Future<bool> _setInitialRolePassword(String walletType) async {
    final account = widget.state.auth.current;
    if (account == null) return false;
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? dialogError;
    bool saving = false;
    var saved = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Set ${_roleTitle(walletType)} transfer password'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'First time setup. This password will be required whenever coins are sent to a user wallet.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Create password',
                    helperText: '6 to 64 characters',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final password = passwordController.text;
                      if (password.length < 6 || password.length > 64) {
                        setDialogState(
                          () => dialogError =
                              'Password must be 6 to 64 characters.',
                        );
                        return;
                      }
                      if (password != confirmController.text) {
                        setDialogState(
                          () => dialogError =
                              'Password and confirm password do not match.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await widget.state.backend.setupRoleWalletPassword(
                          account.authToken,
                          walletType: walletType,
                          password: password,
                        );
                        saved = true;
                        _passwordConfigured[walletType] = true;
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          saving = false;
                          dialogError = error
                              .toString()
                              .replaceFirst('Bad state: ', '');
                        });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save password'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    confirmController.dispose();
    if (saved && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet transfer password created.')),
      );
    }
    return saved;
  }

  Future<void> _resetRolePassword(String walletType) async {
    final account = widget.state.auth.current;
    if (account == null) return;

    Map<String, dynamic> started;
    try {
      started = await widget.state.backend.startRoleWalletPasswordReset(
        account.authToken,
        walletType: walletType,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
      return;
    }

    if (!mounted) return;
    final requestId = started['request_id']?.toString() ?? '';
    final email = started['email']?.toString() ?? '';
    if (requestId.isEmpty) return;

    final otpController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? dialogError;
    bool saving = false;
    var completed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reset ${_roleTitle(walletType)} password'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    email.isEmpty
                        ? 'Enter the OTP sent to your account email.'
                        : 'OTP sent to $email',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: '6-digit email OTP',
                    ),
                  ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      helperText: '6 to 64 characters',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      dialogError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final otp = otpController.text.trim();
                      final password = passwordController.text;
                      if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                        setDialogState(
                          () => dialogError = 'Enter the 6-digit OTP.',
                        );
                        return;
                      }
                      if (password.length < 6 || password.length > 64) {
                        setDialogState(
                          () => dialogError =
                              'Password must be 6 to 64 characters.',
                        );
                        return;
                      }
                      if (password != confirmController.text) {
                        setDialogState(
                          () => dialogError =
                              'Password and confirm password do not match.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await widget.state.backend
                            .verifyRoleWalletPasswordReset(
                          account.authToken,
                          walletType: walletType,
                          requestId: requestId,
                          otp: otp,
                        );
                        await widget.state.backend
                            .completeRoleWalletPasswordReset(
                          account.authToken,
                          walletType: walletType,
                          requestId: requestId,
                          newPassword: password,
                        );
                        completed = true;
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          saving = false;
                          dialogError = error
                              .toString()
                              .replaceFirst('Bad state: ', '');
                        });
                      }
                    },
              child: Text(saving ? 'Resetting…' : 'Reset password'),
            ),
          ],
        ),
      ),
    );

    otpController.dispose();
    passwordController.dispose();
    confirmController.dispose();

    if (completed && mounted) {
      _passwordConfigured[walletType] = true;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet transfer password reset.')),
      );
    }
  }

  Future<void> _transferFromRoleWallet(String walletType) async {
    final account = widget.state.auth.current;
    if (account == null) return;

    if (_passwordConfigured[walletType] != true) {
      await _setInitialRolePassword(walletType);
      return;
    }

    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    final passwordController = TextEditingController();
    String? dialogError;
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${_roleTitle(walletType)} Coin Transfer'),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      recipientController.text = account.userId;
                    },
                    icon: const Icon(Icons.person_rounded),
                    label: const Text('My Normal Wallet'),
                  ),
                ),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Coin amount',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Wallet password',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: sending
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                            _resetRolePassword(walletType);
                          },
                    child: const Text('Reset password'),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  sending ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      final recipient = recipientController.text.trim();
                      final amount =
                          int.tryParse(amountController.text.trim()) ?? 0;
                      final password = passwordController.text;
                      if (recipient.isEmpty ||
                          amount <= 0 ||
                          password.isEmpty) {
                        setDialogState(
                          () => dialogError =
                              'Enter User ID, coin amount and password.',
                        );
                        return;
                      }
                      setDialogState(() {
                        sending = true;
                        dialogError = null;
                      });
                      try {
                        await widget.state.backend.transferCoins(
                          account.authToken,
                          recipientUserId: recipient,
                          amountCoins: amount,
                          walletType: walletType,
                          password: password,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Transferred $amount coins to ID $recipient',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          sending = false;
                          dialogError = error
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
    passwordController.dispose();
  }

  Future<void> _messageProvider(Map<String, dynamic> provider) async {
    final userId = provider['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MessagesScreen(
          state: widget.state,
          targetUserId: userId,
          targetName: provider['display_name']?.toString() ?? userId,
          targetAvatarDataUrl: provider['avatar_data_url']?.toString(),
        ),
      ),
    );
  }

  Widget _buildProviders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GoldSectionTitle('Recharge from Coin Seller / Merchant'),
        const SizedBox(height: 8),
        if (providers.isEmpty)
          const RoyalPanel(
            child: Text(
              'No active Coin Seller or Merchant is available right now.',
              style: TextStyle(color: RoyalPalette.muted),
            ),
          )
        else
          for (final provider in providers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RoyalPanel(
                gradient: FeaturePalette.glow(FeaturePalette.wallet),
                accentColor: FeaturePalette.wallet,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage:
                        _avatarProvider(provider['avatar_data_url']),
                    child: _avatarProvider(provider['avatar_data_url']) == null
                        ? const Icon(Icons.storefront_rounded)
                        : null,
                  ),
                  title: Text(
                    provider['display_name']?.toString() ??
                        provider['user_id']?.toString() ??
                        'Seller',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${provider['wallet_type'] == 'merchant' ? 'Merchant' : 'Coin Seller'} • ID ${provider['user_id'] ?? ''}',
                  ),
                  trailing: FilledButton.icon(
                    onPressed: () => _messageProvider(provider),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 17),
                    label: const Text('Message'),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _roleWalletCard({
    required String walletType,
    required int balance,
    required bool frozen,
  }) {
    final configured = _passwordConfigured[walletType] == true;
    return RoyalPanel(
      gradient: FeaturePalette.glow(FeaturePalette.wallet),
      accentColor: FeaturePalette.wallet,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ShiningIcon(
              icon: walletType == 'merchant'
                  ? Icons.account_balance_rounded
                  : Icons.storefront_rounded,
              color: FeaturePalette.wallet,
              size: 22,
              boxSize: 42,
              glow: 0.34,
            ),
            title: Text('${_roleTitle(walletType)} Wallet'),
            subtitle: Text(
              frozen ? 'Security frozen' : 'Balance: $balance',
            ),
            trailing: FilledButton(
              onPressed: frozen
                  ? null
                  : () => _transferFromRoleWallet(walletType),
              child: Text(configured ? 'Transfer' : 'Set Password'),
            ),
          ),
          if (configured && !frozen)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _resetRolePassword(walletType),
                child: const Text('Reset transfer password'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noCoins = widget.state.wallet.coins <= 0;
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
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
                            'Coins ${widget.state.wallet.coins}\nDiamonds ${widget.state.wallet.diamonds}',
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
                  if (noCoins) ...[
                    const SizedBox(height: 10),
                    RoyalPanel(
                      gradient: FeaturePalette.glow(FeaturePalette.safety),
                      accentColor: FeaturePalette.safety,
                      child: const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: FeaturePalette.safety,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your coins are finished. Recharge from an active Coin Seller or Merchant below.',
                              style: TextStyle(
                                color: RoyalPalette.cream,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildProviders(),
                  ],
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
                    _roleWalletCard(
                      walletType: 'coin_seller',
                      balance: widget.state.wallet.coinSellerBalance,
                      frozen: widget.state.wallet.coinSellerFrozen,
                    ),
                  ],
                  if (widget.state.wallet.merchantActive) ...[
                    const SizedBox(height: 10),
                    _roleWalletCard(
                      walletType: 'merchant',
                      balance: widget.state.wallet.merchantBalance,
                      frozen: widget.state.wallet.merchantFrozen,
                    ),
                  ],
                  if (!noCoins) ...[
                    const SizedBox(height: 14),
                    _buildProviders(),
                  ],
                  const SizedBox(height: 14),
                  const GoldSectionTitle('Wallet activity'),
                  const SizedBox(height: 8),
                  if (widget.state.wallet.history.isEmpty)
                    const RoyalPanel(
                      child: Text(
                        'No wallet activity yet.',
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
                              '${entry.amount > 0 ? '+' : ''}${entry.amount}',
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
            ),
    );
  }
}
