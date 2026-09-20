import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const VoiceChatV03App());

class VoiceChatV03App extends StatelessWidget {
  const VoiceChatV03App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Chat v0.3',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF8A5CFF),
        scaffoldBackgroundColor: const Color(0xFF0E0F15),
      ),
      home: const V03LoginPage(),
    );
  }
}

class V03LoginPage extends StatelessWidget {
  const V03LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA46BFF), Color(0xFF4B32D9)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, size: 48),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Voice Chat v0.3',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'GitHub-only interactive demo with 30-seat rooms, gifts, VIP1–VIP11, Lucky Bag and Dice Rush.',
                style: TextStyle(height: 1.45, color: Colors.white70),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('continue-v03'),
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const V03Shell()),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Continue in Demo Mode'),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Demo balances only. No real money, cloud login or live voice is used.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class V03Shell extends StatefulWidget {
  const V03Shell({super.key});

  @override
  State<V03Shell> createState() => _V03ShellState();
}

class _V03ShellState extends State<V03Shell> {
  int _index = 0;
  int _coins = 2500000;
  int _diamonds = 1200;
  final List<WalletEntry> _transactions = [
    const WalletEntry('v0.3 demo balance', 2500000, true),
    const WalletEntry('Demo diamonds', 1200, false),
  ];

  bool _spendCoins(int amount, String label) {
    if (amount <= 0 || _coins < amount) return false;
    setState(() {
      _coins -= amount;
      _transactions.insert(0, WalletEntry(label, -amount, true));
    });
    return true;
  }

  void _creditCoins(int amount, String label) {
    if (amount <= 0) return;
    setState(() {
      _coins += amount;
      _transactions.insert(0, WalletEntry(label, amount, true));
    });
  }

  void _openRoom() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V03RoomPage(coins: _coins, spendCoins: _spendCoins),
      ),
    );
  }

  void _openVip() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VipCenterPage()));
  }

  void _openLuckyBag() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LuckyBagPage(
          coins: _coins,
          spendCoins: _spendCoins,
          creditCoins: _creditCoins,
        ),
      ),
    );
  }

  void _openGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiceRushPage(
          coins: _coins,
          spendCoins: _spendCoins,
          creditCoins: _creditCoins,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      V03HomePage(
        coins: _coins,
        diamonds: _diamonds,
        onOpenRoom: _openRoom,
        onOpenVip: _openVip,
        onOpenLuckyBag: _openLuckyBag,
        onOpenGame: _openGame,
      ),
      WalletPage(
        coins: _coins,
        diamonds: _diamonds,
        transactions: _transactions,
      ),
      const MePage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}

class V03HomePage extends StatelessWidget {
  const V03HomePage({
    super.key,
    required this.coins,
    required this.diamonds,
    required this.onOpenRoom,
    required this.onOpenVip,
    required this.onOpenLuckyBag,
    required this.onOpenGame,
  });

  final int coins;
  final int diamonds;
  final VoidCallback onOpenRoom;
  final VoidCallback onOpenVip;
  final VoidCallback onOpenLuckyBag;
  final VoidCallback onOpenGame;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Rooms'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(child: Text('V')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _BalanceCard(
                  icon: Icons.monetization_on_rounded,
                  label: 'Coins',
                  value: '$coins',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceCard(
                  icon: Icons.diamond_rounded,
                  label: 'Diamonds',
                  value: '$diamonds',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FeatureButton(
                key: const Key('open-vip'),
                icon: Icons.workspace_premium_rounded,
                label: 'VIP Center',
                onTap: onOpenVip,
              ),
              _FeatureButton(
                key: const Key('open-lucky-bag'),
                icon: Icons.redeem_rounded,
                label: 'Lucky Bag',
                onTap: onOpenLuckyBag,
              ),
              _FeatureButton(
                key: const Key('open-game'),
                icon: Icons.casino_rounded,
                label: 'Game Center',
                onTap: onOpenGame,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Featured Room',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: const Key('open-v03-room'),
            borderRadius: BorderRadius.circular(24),
            onTap: onOpenRoom,
            child: Ink(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF57338F), Color(0xFF18152B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          child: Icon(Icons.music_note_rounded),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Night Vibes',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text('Room ID 10000000 • Hindi / English'),
                            ],
                          ),
                        ),
                        Chip(label: Text('v0.3')),
                      ],
                    ),
                    const Spacer(),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Tag('30 seats'),
                        _Tag('Invite Mode'),
                        _Tag('Gift combos'),
                        _Tag('Owner/Admin tools'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Tap to enter the upgraded local room demo.'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _InfoTile(
            icon: Icons.cloud_off_rounded,
            title: 'GitHub-only v0.3',
            subtitle:
                'Realtime voice and multi-phone sync will be connected later.',
          ),
        ],
      ),
    );
  }
}

class V03RoomPage extends StatefulWidget {
  const V03RoomPage({super.key, required this.coins, required this.spendCoins});

  final int coins;
  final bool Function(int amount, String label) spendCoins;

  @override
  State<V03RoomPage> createState() => _V03RoomPageState();
}

class _V03RoomPageState extends State<V03RoomPage> {
  late int _coins;
  bool _inviteMode = true;
  bool _micMuted = true;
  int? _mySeat;
  final Set<int> _lockedSeats = {8, 14, 24};
  final List<String?> _seats = List<String?>.filled(30, null);
  final List<SeatRequest> _requests = [
    const SeatRequest('Zara', 7, 5),
    const SeatRequest('Rahul', 0, 11),
  ];
  final List<RoomMessage> _messages = [
    const RoomMessage('Owner', 'Welcome to Night Vibes 👋'),
    const RoomMessage('Admin • VIP6', 'Invite Mode is ON.'),
  ];
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _coins = widget.coins;
    _seats[0] = 'Owner';
    _seats[1] = 'Admin';
    _seats[3] = 'Aisha';
    _seats[6] = 'Sam';
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int _firstOpenSeat() {
    for (var i = 0; i < _seats.length; i++) {
      if (_seats[i] == null && !_lockedSeats.contains(i)) return i;
    }
    return -1;
  }

  void _tapSeat(int index) {
    if (_lockedSeats.contains(index)) {
      _snack('Seat ${index + 1} is locked.');
      return;
    }
    if (_seats[index] != null) {
      _snack('${_seats[index]} is already on seat ${index + 1}.');
      return;
    }
    if (_mySeat != null) {
      _snack('Leave your current seat first.');
      return;
    }
    if (_inviteMode) {
      if (_requests.any((request) => request.name == 'You')) {
        _snack('You already have an active request.');
        return;
      }
      setState(() => _requests.add(SeatRequest('You', 0, index)));
      _snack('Seat ${index + 1} request sent.');
    } else {
      setState(() {
        _seats[index] = 'You';
        _mySeat = index;
      });
    }
  }

  void _toggleLock(int index) {
    if (_seats[index] != null) {
      _snack('Occupied seat cannot be locked in this demo.');
      return;
    }
    setState(() {
      if (_lockedSeats.contains(index)) {
        _lockedSeats.remove(index);
      } else {
        _lockedSeats.add(index);
      }
    });
  }

  void _acceptRequest(SeatRequest request) {
    var target = request.preferredSeat;
    if (target < 0 ||
        target >= _seats.length ||
        _seats[target] != null ||
        _lockedSeats.contains(target)) {
      target = _firstOpenSeat();
    }
    if (target < 0) {
      _snack('No unlocked seat is available.');
      return;
    }
    setState(() {
      _requests.remove(request);
      _seats[target] = request.name;
      if (request.name == 'You') _mySeat = target;
      _messages.add(
        RoomMessage('System', '${request.name} joined seat ${target + 1}.'),
      );
    });
  }

  void _leaveSeat() {
    if (_mySeat == null) return;
    setState(() {
      _seats[_mySeat!] = null;
      _mySeat = null;
      _micMuted = true;
    });
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(RoomMessage('You', text));
      _chatController.clear();
    });
  }

  void _openOwnerTools() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void refresh(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Owner / Admin Controls',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Invite Mode'),
                      subtitle: const Text(
                        'Normal users request a seat when ON.',
                      ),
                      value: _inviteMode,
                      onChanged: (value) => refresh(() => _inviteMode = value),
                    ),
                    const Divider(),
                    Text(
                      'Seat requests (${_requests.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (_requests.isEmpty)
                      const Text(
                        'No pending requests.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ..._requests.map(
                      (request) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              request.vip > 0
                                  ? 'V${request.vip}'
                                  : request.name.substring(0, 1),
                            ),
                          ),
                          title: Text(request.name),
                          subtitle: Text(
                            'Preferred seat ${request.preferredSeat + 1}${request.vip > 0 ? ' • VIP${request.vip}' : ''}',
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    refresh(() => _requests.remove(request)),
                                icon: const Icon(Icons.close_rounded),
                              ),
                              IconButton(
                                onPressed: () {
                                  _acceptRequest(request);
                                  setSheetState(() {});
                                },
                                icon: const Icon(Icons.check_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _messages
                            ..clear()
                            ..add(
                              const RoomMessage(
                                'System',
                                'Chat cleared by Owner/Admin.',
                              ),
                            );
                        });
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.delete_sweep_rounded),
                      label: const Text('Clear room chat'),
                    ),
                    if (_mySeat != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          _leaveSeat();
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.keyboard_return_rounded),
                        label: const Text('Move You to audience'),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Long-press any empty seat to lock/unlock it.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openGiftSheet() {
    const gifts = [
      GiftOption('🌹', 'Rose', 100),
      GiftOption('💎', 'Crystal', 500),
      GiftOption('👑', 'Crown', 1000),
    ];
    const combos = [1, 7, 21, 51, 99, 599, 999];
    var selectedCombo = 1;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Send gift to seated Owner',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: combos
                          .map(
                            (combo) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text('×$combo'),
                                selected: selectedCombo == combo,
                                onSelected: (_) =>
                                    setSheetState(() => selectedCombo = combo),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...gifts.map(
                    (gift) => Card(
                      child: ListTile(
                        leading: Text(
                          gift.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: Text(gift.name),
                        subtitle: Text('${gift.cost} Coins each'),
                        trailing: FilledButton(
                          onPressed: () {
                            final total = gift.cost * selectedCombo;
                            final sent = widget.spendCoins(
                              total,
                              'Sent ${gift.name} ×$selectedCombo gift',
                            );
                            if (!sent) {
                              Navigator.pop(sheetContext);
                              _snack('Not enough demo Coins.');
                              return;
                            }
                            setState(() {
                              _coins -= total;
                              _messages.add(
                                RoomMessage(
                                  'System',
                                  'You sent ${gift.name} ×$selectedCombo to Owner 🎁',
                                ),
                              );
                            });
                            Navigator.pop(sheetContext);
                            _snack('$total demo Coins deducted.');
                          },
                          child: const Text('Send'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Night Vibes', style: TextStyle(fontSize: 17)),
            Text('Room ID 10000000 • 30 seats', style: TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          Center(child: Text('🪙 $_coins')),
          IconButton(
            key: const Key('owner-tools-v03'),
            onPressed: _openOwnerTools,
            icon: const Icon(Icons.admin_panel_settings_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.shield_rounded),
                    ),
                    title: const Text('Owner • VIP11'),
                    subtitle: Text(
                      _inviteMode ? 'Invite Mode ON' : 'Invite Mode OFF',
                    ),
                    trailing: Chip(
                      label: Text(_inviteMode ? 'Invite ON' : 'Direct Seat'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  key: const Key('seat-grid-v03'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 30,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final occupant = _seats[index];
                    final locked = _lockedSeats.contains(index);
                    final isMine = occupant == 'You';
                    return GestureDetector(
                      onTap: () => _tapSeat(index),
                      onLongPress: () => _toggleLock(index),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isMine
                                    ? const Color(0xFF6D48D8)
                                    : locked
                                    ? const Color(0xFF353640)
                                    : const Color(0xFF252631),
                                border: Border.all(
                                  color: isMine
                                      ? Colors.white70
                                      : Colors.white12,
                                ),
                              ),
                              child: Icon(
                                locked
                                    ? Icons.lock_rounded
                                    : occupant == null
                                    ? Icons.add_rounded
                                    : Icons.person_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            occupant ?? 'Seat ${index + 1}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _mySeat == null
                            ? null
                            : () => setState(() => _micMuted = !_micMuted),
                        icon: Icon(
                          _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        ),
                        label: Text(_micMuted ? 'Mic Off' : 'Mic On'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _openGiftSheet,
                        icon: const Icon(Icons.card_giftcard_rounded),
                        label: const Text('Gift'),
                      ),
                    ),
                  ],
                ),
                if (_mySeat != null)
                  TextButton.icon(
                    onPressed: _leaveSeat,
                    icon: const Icon(Icons.keyboard_return_rounded),
                    label: const Text('Leave seat / Audience'),
                  ),
                const Divider(height: 28),
                const Text(
                  'Room Chat',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._messages.map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${message.sender}: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: message.text),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      decoration: const InputDecoration(
                        hintText: 'Message room…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded),
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

class VipCenterPage extends StatelessWidget {
  const VipCenterPage({super.key});

  static const vehicles = [
    'Wolf Rider',
    'Shadow Bike',
    'Royal Panther',
    'Storm Horse',
    'Sky Tiger',
    'Crystal Lion',
    'Thunder Griffin',
    'Celestial Beast',
    'Eagle',
    'Phoenix',
    'Dragon',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VIP Center')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 11,
        itemBuilder: (context, index) {
          final tier = index + 1;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('$tier')),
              title: Text('VIP$tier • ${vehicles[index]}'),
              subtitle: Text(
                tier >= 9
                    ? 'Unique 3D+ entry concept, profile frame, mic skin, badge and room effects.'
                    : 'Progressive frame, badge, mic skin, vehicle and entry cosmetics.',
              ),
              trailing: tier == 3
                  ? const Chip(label: Text('Demo Active'))
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class LuckyBagPage extends StatefulWidget {
  const LuckyBagPage({
    super.key,
    required this.coins,
    required this.spendCoins,
    required this.creditCoins,
  });

  final int coins;
  final bool Function(int amount, String label) spendCoins;
  final void Function(int amount, String label) creditCoins;

  @override
  State<LuckyBagPage> createState() => _LuckyBagPageState();
}

class _LuckyBagPageState extends State<LuckyBagPage> {
  late int _coins;
  LuckyBagDemo? _bag;
  bool _claimed = false;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _coins = widget.coins;
  }

  int _capacityFor(int amount) {
    if (amount == 100000) return 10;
    if (amount == 500000) return 40;
    if (amount == 1000000) return 100;
    return 300;
  }

  void _createBag(int amount) {
    final ok = widget.spendCoins(amount, 'Created Lucky Bag $amount');
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not enough demo Coins.')));
      return;
    }
    setState(() {
      _coins -= amount;
      _claimed = false;
      _bag = LuckyBagDemo(amount, _capacityFor(amount));
    });
  }

  void _claim() {
    final bag = _bag;
    if (bag == null || _claimed) return;
    final maxReward = max(6000, bag.amount ~/ 3);
    final reward = 6000 + _random.nextInt(maxReward - 6000 + 1);
    widget.creditCoins(reward, 'Claimed Lucky Bag reward');
    setState(() {
      _coins += reward;
      _claimed = true;
      _bag = bag.copyWith(claimed: 1);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('You claimed $reward demo Coins.')));
  }

  @override
  Widget build(BuildContext context) {
    const amounts = [100000, 500000, 1000000, 2000000];
    return Scaffold(
      appBar: AppBar(title: const Text('Lucky Bag (LP)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BalanceCard(
            icon: Icons.monetization_on_rounded,
            label: 'Demo Coins',
            value: '$_coins',
          ),
          const SizedBox(height: 16),
          const Text(
            'Create LP',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Demo rules: one claim per bag, minimum simulated claim 6,000 Coins. No room-owner 10% applies to LP.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ...amounts.map(
            (amount) => Card(
              child: ListTile(
                leading: const Icon(Icons.redeem_rounded),
                title: Text('$amount Coins'),
                subtitle: Text('Up to ${_capacityFor(amount)} claimants'),
                trailing: FilledButton(
                  onPressed: () => _createBag(amount),
                  child: const Text('Create'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_bag != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Active LP • ${_bag!.amount} Coins',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${_bag!.claimed}/${_bag!.capacity} claimed'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _claimed ? null : _claim,
                      icon: const Icon(Icons.touch_app_rounded),
                      label: Text(
                        _claimed ? 'Already Claimed' : 'Claim Demo LP',
                      ),
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

class DiceRushPage extends StatefulWidget {
  const DiceRushPage({
    super.key,
    required this.coins,
    required this.spendCoins,
    required this.creditCoins,
  });

  final int coins;
  final bool Function(int amount, String label) spendCoins;
  final void Function(int amount, String label) creditCoins;

  @override
  State<DiceRushPage> createState() => _DiceRushPageState();
}

class _DiceRushPageState extends State<DiceRushPage> {
  late int _coins;
  int _bet = 500;
  bool _pickHigh = true;
  int? _lastRoll;
  String _result = 'Pick High (4–6) or Low (1–3), then roll.';
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _coins = widget.coins;
  }

  void _play() {
    final ok = widget.spendCoins(_bet, 'Dice Rush bet');
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not enough demo Coins.')));
      return;
    }
    final roll = _random.nextInt(6) + 1;
    final won = _pickHigh ? roll >= 4 : roll <= 3;
    var payout = 0;
    if (won) {
      payout = _bet * 2;
      widget.creditCoins(payout, 'Dice Rush win');
    }
    setState(() {
      _coins -= _bet;
      if (won) _coins += payout;
      _lastRoll = roll;
      _result = won ? 'You won! Payout $payout Coins.' : 'You lost this round.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Center • Dice Rush')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BalanceCard(
            icon: Icons.monetization_on_rounded,
            label: 'Demo Coins',
            value: '$_coins',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('🎲', style: TextStyle(fontSize: 72)),
                  Text(
                    _lastRoll == null ? '—' : 'Rolled $_lastRoll',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_result, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Low 1–3')),
              ButtonSegment(value: true, label: Text('High 4–6')),
            ],
            selected: {_pickHigh},
            onSelectionChanged: (value) =>
                setState(() => _pickHigh = value.first),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _bet,
            decoration: const InputDecoration(labelText: 'Bet amount'),
            items: const [100, 500, 1000]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('$value Coins'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _bet = value);
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('play-dice-rush'),
            onPressed: _play,
            icon: const Icon(Icons.casino_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Roll Dice'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Local demo only. Production games will use server-authoritative outcomes and automatic refunds on failed rounds.',
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class WalletPage extends StatelessWidget {
  const WalletPage({
    super.key,
    required this.coins,
    required this.diamonds,
    required this.transactions,
  });

  final int coins;
  final int diamonds;
  final List<WalletEntry> transactions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _BalanceCard(
                  icon: Icons.monetization_on_rounded,
                  label: 'Coins',
                  value: '$coins',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceCard(
                  icon: Icons.diamond_rounded,
                  label: 'Diamonds',
                  value: '$diamonds',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Demo transactions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...transactions.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry.isCoin
                    ? Icons.monetization_on_rounded
                    : Icons.diamond_rounded,
              ),
              title: Text(entry.label),
              trailing: Text(
                '${entry.amount > 0 ? '+' : ''}${entry.amount}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    child: Text('V', style: TextStyle(fontSize: 24)),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vinay Demo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text('ID 10000001 • 🇮🇳 • VIP3'),
                        SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            Chip(label: Text('VIP3')),
                            Chip(label: Text('Demo User')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 14),
          _InfoTile(
            icon: Icons.storefront_rounded,
            title: 'Store & Bag',
            subtitle: 'Catalog and owned cosmetics preview.',
          ),
          _InfoTile(
            icon: Icons.workspace_premium_rounded,
            title: 'VIP / Medal / Relationship',
            subtitle: 'Profile shortcuts are prepared for later expansion.',
          ),
          _InfoTile(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle:
                'Language, security and account controls will be connected later.',
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  const _FeatureButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x243FFFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class WalletEntry {
  const WalletEntry(this.label, this.amount, this.isCoin);
  final String label;
  final int amount;
  final bool isCoin;
}

class RoomMessage {
  const RoomMessage(this.sender, this.text);
  final String sender;
  final String text;
}

class SeatRequest {
  const SeatRequest(this.name, this.vip, this.preferredSeat);
  final String name;
  final int vip;
  final int preferredSeat;
}

class GiftOption {
  const GiftOption(this.emoji, this.name, this.cost);
  final String emoji;
  final String name;
  final int cost;
}

class LuckyBagDemo {
  const LuckyBagDemo(this.amount, this.capacity, {this.claimed = 0});
  final int amount;
  final int capacity;
  final int claimed;

  LuckyBagDemo copyWith({int? claimed}) {
    return LuckyBagDemo(amount, capacity, claimed: claimed ?? this.claimed);
  }
}
