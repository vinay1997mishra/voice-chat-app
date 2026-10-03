import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';

int _walletInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> _walletRows(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

String _walletNumber(int value) {
  final text = value.toString();
  return text.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => (match[1] ?? '') + ',',
  );
}

String _walletUsd(int cents) => '\$' + (cents / 100).toStringAsFixed(2);

String _walletDateTime(int milliseconds) {
  if (milliseconds <= 0) return '—';
  final value = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

class CoinsHistoryScreen extends StatefulWidget {
  const CoinsHistoryScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<CoinsHistoryScreen> createState() => _CoinsHistoryScreenState();
}

class _CoinsHistoryScreenState extends State<CoinsHistoryScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final value = await widget.state.backend.coinsHistory(account.authToken);
      if (!mounted) return;
      setState(() {
        data = value;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gifts = _walletRows(data['gifts']);
    return Scaffold(
      appBar: AppBar(title: const Text('Coins History')),
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
                          icon: Icons.monetization_on_rounded,
                          color: FeaturePalette.wallet,
                          size: 24,
                          boxSize: 48,
                          glow: .3,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Coins',
                                style: TextStyle(color: RoyalPalette.muted),
                              ),
                              Text(
                                _walletNumber(_walletInt(data['current_coins'])),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: RoyalPalette.cream,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => SellerReceivedCoinsScreen(
                                  state: widget.state,
                                ),
                              ),
                            );
                          },
                          child: const Text('Seller Received'),
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 16),
                  const GoldSectionTitle('Gift Sent'),
                  const SizedBox(height: 8),
                  if (gifts.isEmpty)
                    const RoyalPanel(
                      child: Text(
                        'No gift history.',
                        style: TextStyle(color: RoyalPalette.muted),
                      ),
                    )
                  else
                    for (final row in gifts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RoyalPanel(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.card_giftcard_rounded,
                              color: FeaturePalette.gift,
                            ),
                            title: Text(
                              row['gift_name']?.toString() ?? 'Gift',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              '${row['receiver_name'] ?? row['receiver_user_id']} • '
                              'ID ${row['receiver_user_id'] ?? ''}\n'
                              '${_walletDateTime(_walletInt(row['created_at']))}',
                            ),
                            trailing: Text(
                              '-${_walletNumber(_walletInt(row['coins']))}',
                              style: const TextStyle(
                                color: FeaturePalette.wallet,
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

class SellerReceivedCoinsScreen extends StatefulWidget {
  const SellerReceivedCoinsScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<SellerReceivedCoinsScreen> createState() =>
      _SellerReceivedCoinsScreenState();
}

class _SellerReceivedCoinsScreenState extends State<SellerReceivedCoinsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final data = await widget.state.backend.coinsHistory(account.authToken);
      if (!mounted) return;
      setState(() {
        rows = _walletRows(data['seller_received']);
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coins Received')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                children: [
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  if (rows.isEmpty)
                    const RoyalPanel(
                      child: Text(
                        'No seller transfers.',
                        style: TextStyle(color: RoyalPalette.muted),
                      ),
                    )
                  else
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RoyalPanel(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              row['seller_name']?.toString() ??
                                  row['seller_user_id']?.toString() ??
                                  'Coin Seller',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              'ID ${row['seller_user_id'] ?? ''} • '
                              '${row['wallet_type'] == 'merchant' ? 'Merchant' : 'Coin Seller'}\n'
                              '${_walletDateTime(_walletInt(row['created_at']))}',
                            ),
                            trailing: Text(
                              '+${_walletNumber(_walletInt(row['coins']))}',
                              style: const TextStyle(
                                color: FeaturePalette.wallet,
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

class DiamondsWalletScreen extends StatefulWidget {
  const DiamondsWalletScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<DiamondsWalletScreen> createState() => _DiamondsWalletScreenState();
}

class _DiamondsWalletScreenState extends State<DiamondsWalletScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final value =
          await widget.state.backend.diamondsHistory(account.authToken);
      final wallet = await widget.state.backend.wallet(account.authToken);
      widget.state.wallet.applyRemote(wallet);
      if (!mounted) return;
      setState(() {
        data = value;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  Future<void> _convert() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    final controller = TextEditingController();
    String? dialogError;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Convert Diamonds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Available ${_walletNumber(_walletInt(data['current_diamonds']))}',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(labelText: 'Diamond amount'),
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
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final amount = int.tryParse(controller.text.trim()) ?? 0;
                      if (amount <= 0) {
                        setDialogState(
                          () => dialogError = 'Enter diamond amount.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await widget.state.backend.convertDiamonds(
                          account.authToken,
                          diamonds: amount,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _load();
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          saving = false;
                          dialogError = widget.state.backend.userSafeError(e);
                        });
                      }
                    },
              child: Text(saving ? 'Converting…' : 'Convert'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversions = _walletRows(data['conversions']);
    return Scaffold(
      appBar: AppBar(title: const Text('Diamonds')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                children: [
                  RoyalPanel(
                    gradient: FeaturePalette.glow(FeaturePalette.gift),
                    accentColor: FeaturePalette.gift,
                    child: Row(
                      children: [
                        const ShiningIcon(
                          icon: Icons.diamond_rounded,
                          color: FeaturePalette.gift,
                          size: 24,
                          boxSize: 48,
                          glow: .3,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Diamonds',
                                style: TextStyle(color: RoyalPalette.muted),
                              ),
                              Text(
                                _walletNumber(
                                  _walletInt(data['current_diamonds']),
                                ),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: _walletInt(data['current_diamonds']) > 0
                              ? _convert
                              : null,
                          child: const Text('Convert'),
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 16),
                  const GoldSectionTitle('Conversion History'),
                  const SizedBox(height: 8),
                  if (conversions.isEmpty)
                    const RoyalPanel(
                      child: Text(
                        'No conversions.',
                        style: TextStyle(color: RoyalPalette.muted),
                      ),
                    )
                  else
                    for (final row in conversions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RoyalPanel(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${_walletNumber(_walletInt(row['diamonds']))} Diamonds',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              _walletDateTime(_walletInt(row['created_at'])),
                            ),
                            trailing: Text(
                              '+${_walletNumber(_walletInt(row['coins']))} Coins',
                              style: const TextStyle(
                                color: FeaturePalette.wallet,
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

class RoleWalletDetailScreen extends StatefulWidget {
  const RoleWalletDetailScreen({
    super.key,
    required this.state,
    required this.walletType,
  });

  final TinniState state;
  final String walletType;

  @override
  State<RoleWalletDetailScreen> createState() => _RoleWalletDetailScreenState();
}

class _RoleWalletDetailScreenState extends State<RoleWalletDetailScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = const <String, dynamic>{};

  String get title =>
      widget.walletType == 'merchant' ? 'Merchant Wallet' : 'Coin Seller Wallet';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final value = await widget.state.backend.roleWalletDetail(
        account.authToken,
        walletType: widget.walletType,
      );
      if (!mounted) return;
      setState(() {
        data = value;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  Future<void> _transferDollars() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    final amountController = TextEditingController();
    final recipientController = TextEditingController();
    final passwordController = TextEditingController();
    String destination =
        widget.walletType == 'coin_seller' ? 'merchant' : 'company';
    String? dialogError;
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Dollar Transfer'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.walletType == 'coin_seller')
                    DropdownButtonFormField<String>(
                      initialValue: destination,
                      decoration: const InputDecoration(labelText: 'Destination'),
                      items: const [
                        DropdownMenuItem(
                          value: 'merchant',
                          child: Text('Merchant'),
                        ),
                        DropdownMenuItem(
                          value: 'company',
                          child: Text('Company'),
                        ),
                      ],
                      onChanged: sending
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() => destination = value);
                            },
                    )
                  else
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Destination'),
                      trailing: Text('Company'),
                    ),
                  if (destination == 'merchant') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: recipientController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration:
                          const InputDecoration(labelText: 'Merchant User ID'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          'USD amount (minimum ${_walletUsd(_walletInt(data['minimum_transfer_usd_cents']))})',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    keyboardType: widget.walletType == 'coin_seller'
                        ? TextInputType.number
                        : TextInputType.text,
                    inputFormatters: widget.walletType == 'coin_seller'
                        ? <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ]
                        : null,
                    maxLength: widget.walletType == 'coin_seller' ? 4 : null,
                    decoration: InputDecoration(
                      labelText: widget.walletType == 'coin_seller'
                          ? '4-digit PIN'
                          : 'Wallet password',
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
              onPressed:
                  sending ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      final amount =
                          double.tryParse(amountController.text.trim()) ?? 0;
                      final cents = (amount * 100).round();
                      final minimum =
                          _walletInt(data['minimum_transfer_usd_cents']);
                      final recipient = recipientController.text.trim();
                      if (cents < minimum) {
                        setDialogState(
                          () => dialogError =
                              'Minimum ${_walletUsd(minimum)}.',
                        );
                        return;
                      }
                      if (destination == 'merchant' && recipient.isEmpty) {
                        setDialogState(
                          () => dialogError = 'Enter Merchant ID.',
                        );
                        return;
                      }
                      final password = passwordController.text;
                      if (widget.walletType == 'coin_seller' &&
                          !RegExp(r'^\d{4}$').hasMatch(password)) {
                        setDialogState(
                          () => dialogError = 'Enter 4-digit PIN.',
                        );
                        return;
                      }
                      if (widget.walletType == 'merchant' &&
                          (password.length < 6 || password.length > 64)) {
                        setDialogState(
                          () => dialogError = 'Enter wallet password.',
                        );
                        return;
                      }
                      setDialogState(() {
                        sending = true;
                        dialogError = null;
                      });
                      try {
                        final requestId =
                            '${account.userId}-${widget.walletType}-'
                            '${DateTime.now().microsecondsSinceEpoch}';
                        await widget.state.backend.transferRoleDollars(
                          account.authToken,
                          walletType: widget.walletType,
                          destinationType: destination,
                          recipientUserId:
                              destination == 'merchant' ? recipient : null,
                          usdCents: cents,
                          password: password,
                          requestId: requestId,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _load();
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          sending = false;
                          dialogError = widget.state.backend.userSafeError(e);
                        });
                      }
                    },
              child: Text(sending ? 'Sending…' : 'Confirm'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    recipientController.dispose();
    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _walletRows(data['transactions']);
    final companyRows = transactions
        .where((row) =>
            row['kind'] == 'company_credit' ||
            row['kind'] == 'owner_debit' ||
            row['kind'] == 'dollars_to_company')
        .toList(growable: false);
    final sentRows = transactions
        .where((row) =>
            row['kind'] == 'coins_sent' ||
            row['kind'] == 'dollars_to_merchant')
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RoyalPanel(
                          gradient: FeaturePalette.glow(FeaturePalette.wallet),
                          accentColor: FeaturePalette.wallet,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Coins',
                                style: TextStyle(color: RoyalPalette.muted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _walletInt(data['balance_coins']) == 0
                                    ? '00'
                                    : _walletNumber(
                                        _walletInt(data['balance_coins']),
                                      ),
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ReceivedDollarsScreen(
                                  state: widget.state,
                                  walletType: widget.walletType,
                                ),
                              ),
                            );
                          },
                          child: RoyalPanel(
                            gradient:
                                FeaturePalette.glow(FeaturePalette.family),
                            accentColor: FeaturePalette.family,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Dollars',
                                  style: TextStyle(color: RoyalPalette.muted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _walletUsd(
                                    _walletInt(data['total_usd_cents']),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'View Received',
                                  style: TextStyle(
                                    color: RoyalPalette.gold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: data['security_frozen'] == true
                          ? null
                          : _transferDollars,
                      icon: const Icon(Icons.attach_money_rounded),
                      label: Text(
                        'Dollar Transfer • Min '
                        '${_walletUsd(_walletInt(data['minimum_transfer_usd_cents']))}',
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 16),
                  const GoldSectionTitle('Company Credit / Transfer'),
                  const SizedBox(height: 8),
                  _RoleTransactionList(rows: companyRows),
                  const SizedBox(height: 16),
                  const GoldSectionTitle('Transactions Sent'),
                  const SizedBox(height: 8),
                  _RoleTransactionList(rows: sentRows),
                ],
              ),
            ),
    );
  }
}

class ReceivedDollarsScreen extends StatefulWidget {
  const ReceivedDollarsScreen({
    super.key,
    required this.state,
    required this.walletType,
  });

  final TinniState state;
  final String walletType;

  @override
  State<ReceivedDollarsScreen> createState() => _ReceivedDollarsScreenState();
}

class _ReceivedDollarsScreenState extends State<ReceivedDollarsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final value = await widget.state.backend.roleWalletDetail(
        account.authToken,
        walletType: widget.walletType,
      );
      if (!mounted) return;
      setState(() {
        data = value;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _walletRows(data['received_dollars']);
    return Scaffold(
      appBar: AppBar(title: const Text('Received Dollars')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                children: [
                  RoyalPanel(
                    gradient: FeaturePalette.glow(FeaturePalette.family),
                    accentColor: FeaturePalette.family,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Dollars Received',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          _walletUsd(
                            _walletInt(data['received_dollars_total_cents']),
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    const RoyalPanel(
                      child: Text(
                        'No dollars received.',
                        style: TextStyle(color: RoyalPalette.muted),
                      ),
                    )
                  else
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RoyalPanel(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  '${row['sender_name'] ?? row['sender_user_id']}\n'
                                  'ID ${row['sender_user_id'] ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  _walletDateTime(
                                    _walletInt(row['created_at']),
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: RoyalPalette.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _walletUsd(_walletInt(row['usd_cents'])),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: RoyalPalette.gold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class _RoleTransactionList extends StatelessWidget {
  const _RoleTransactionList({required this.rows});
  final List<Map<String, dynamic>> rows;

  String _label(Map<String, dynamic> row) {
    switch (row['kind']?.toString()) {
      case 'company_credit':
        return 'Company Credit';
      case 'owner_debit':
        return 'Owner Debit';
      case 'coins_sent':
        return 'Coins Sent';
      case 'dollars_to_company':
        return 'Dollars to Company';
      case 'dollars_to_merchant':
        return 'Dollars to Merchant';
      case 'settlement_received':
        return 'Settlement Received';
      case 'dollars_received':
        return 'Dollars Received';
      default:
        return row['note']?.toString() ?? 'Transaction';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const RoyalPanel(
        child: Text(
          'No transactions.',
          style: TextStyle(color: RoyalPalette.muted),
        ),
      );
    }
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RoyalPanel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _label(row),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  [
                    if ((row['counterparty_name']?.toString() ?? '').isNotEmpty)
                      row['counterparty_name'].toString(),
                    if ((row['counterparty_user_id']?.toString() ?? '').isNotEmpty)
                      'ID ${row['counterparty_user_id']}',
                    _walletDateTime(_walletInt(row['created_at'])),
                  ].join(' • '),
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_walletInt(row['coins_delta']) != 0)
                      Text(
                        '${_walletInt(row['coins_delta']) > 0 ? '+' : ''}'
                        '${_walletNumber(_walletInt(row['coins_delta']))}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    if (_walletInt(row['usd_cents']) != 0)
                      Text(
                        _walletUsd(_walletInt(row['usd_cents']).abs()),
                        style: const TextStyle(
                          color: RoyalPalette.gold,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
