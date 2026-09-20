import 'anamika_repair_page.dart';
import 'package:flutter/material.dart';

void main() => runApp(const VoiceChatApp());

class VoiceChatApp extends StatelessWidget {
  const VoiceChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Chat v0.2',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF8A5CFF),
        scaffoldBackgroundColor: const Color(0xFF0F1016),
      ),
      home: const DemoLoginPage(),
    );
  }
}

class DemoLoginPage extends StatelessWidget {
  const DemoLoginPage({super.key});

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
                      colors: [Color(0xFFA56FFF), Color(0xFF5A36E8)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, size: 48),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Voice Chat v0.2',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'GitHub-only interactive demo with 30 seats, Invite Mode, seat requests and Owner/Admin controls.',
                style: TextStyle(height: 1.45, color: Colors.white70),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('continue-demo'),
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DemoShell()),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Continue in Demo Mode'),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'No real money, cloud account or live microphone is used in this build.',
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

class DemoShell extends StatefulWidget {
  const DemoShell({super.key});

  @override
  State<DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<DemoShell> {
  int _index = 0;
  int _coins = 10000;
  final int _diamonds = 1200;
  final List<WalletEntry> _transactions = [
    const WalletEntry('Welcome bonus', 10000, true),
    const WalletEntry('Demo diamonds', 1200, false),
  ];

  bool _sendGift(int cost, String giftName) {
    if (_coins < cost) return false;
    setState(() {
      _coins -= cost;
      _transactions.insert(0, WalletEntry('Sent $giftName gift', -cost, true));
    });
    return true;
  }

  void _openRoom() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DemoRoomPage(startingCoins: _coins, onSendGift: _sendGift),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onOpenRoom: _openRoom, coins: _coins, diamonds: _diamonds),
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

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenRoom,
    required this.coins,
    required this.diamonds,
  });

  final VoidCallback onOpenRoom;
  final int coins;
  final int diamonds;

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
          const SizedBox(height: 24),
          const Text(
            'Featured',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: const Key('open-night-vibes'),
            borderRadius: BorderRadius.circular(24),
            onTap: onOpenRoom,
            child: Ink(
              height: 206,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF50318A), Color(0xFF17152A)],
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
                          radius: 24,
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
                        Chip(label: Text('v0.2')),
                      ],
                    ),
                    const Spacer(),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Tag('30 seats'),
                        _Tag('Invite Mode'),
                        _Tag('Owner/Admin tools'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Tap to enter the upgraded local demo room.'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _InfoTile(
            icon: Icons.cloud_off_rounded,
            title: 'GitHub-only build',
            subtitle:
                'Realtime voice and multi-phone sync will be connected later.',
          ),
        ],
      ),
    );
  }
}

class DemoRoomPage extends StatefulWidget {
  const DemoRoomPage({
    super.key,
    required this.startingCoins,
    required this.onSendGift,
  });

  final int startingCoins;
  final bool Function(int cost, String giftName) onSendGift;

  @override
  State<DemoRoomPage> createState() => _DemoRoomPageState();
}

class _DemoRoomPageState extends State<DemoRoomPage> {
  late int _coins;
  bool _inviteMode = true;
  bool _micMuted = true;
  int? _mySeat;
  int? _selectedSeat;
  final Set<int> _lockedSeats = {8, 14, 24};
  final List<SeatRequest> _requests = [
    const SeatRequest('Zara', 7, 5),
    const SeatRequest('Rahul', 0, 11),
  ];
  final List<String?> _seats = List<String?>.filled(30, null);
  final TextEditingController _chatController = TextEditingController();
  final List<RoomMessage> _messages = [
    const RoomMessage('Owner', 'Welcome to Night Vibes 👋'),
    const RoomMessage('Admin • VIP6', 'Invite Mode is ON.'),
  ];

  @override
  void initState() {
    super.initState();
    _coins = widget.startingCoins;
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

  void _tapSeat(int index) {
    setState(() => _selectedSeat = index);
    if (_lockedSeats.contains(index)) {
      _snack('Seat ${index + 1} is locked by the Owner.');
      return;
    }
    if (_seats[index] != null) {
      _snack('${_seats[index]} is sitting on seat ${index + 1}.');
      return;
    }
    if (_mySeat != null) {
      _snack('Leave your current seat before choosing another one.');
      return;
    }
    if (_inviteMode) {
      if (_requests.any((request) => request.name == 'You')) {
        _snack('You already have an active seat request.');
        return;
      }
      setState(() => _requests.add(SeatRequest('You', 0, index)));
      _snack('Seat ${index + 1} request sent to Owner/Admin.');
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
    final preferred = request.preferredSeat;
    int target = preferred;
    if (target < 0 ||
        target >= _seats.length ||
        _seats[target] != null ||
        _lockedSeats.contains(target)) {
      target = _seats.indexWhere(
        (seat) => seat == null && !_lockedSeats.contains(_seats.indexOf(seat)),
      );
    }
    if (target < 0 || target >= _seats.length) {
      _snack('No available unlocked seat.');
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

  void _rejectRequest(SeatRequest request) {
    setState(() => _requests.remove(request));
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

  void _clearChat() {
    setState(() {
      _messages
        ..clear()
        ..add(const RoomMessage('System', 'Chat cleared by Owner/Admin.'));
    });
  }

  void _openOwnerTools() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void refresh(VoidCallback action) {
            setState(action);
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
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Invite Mode'),
                      subtitle: const Text(
                        'ON = normal users request a seat before sitting.',
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
                                  : request.name.characters.first,
                            ),
                          ),
                          title: Text(request.name),
                          subtitle: Text(
                            'Preferred seat ${request.preferredSeat + 1}${request.vip > 0 ? ' • VIP${request.vip}' : ''}',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Reject',
                                onPressed: () =>
                                    refresh(() => _rejectRequest(request)),
                                icon: const Icon(Icons.close_rounded),
                              ),
                              IconButton(
                                tooltip: 'Accept',
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
                        _clearChat();
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
                      'Tip: long-press any empty seat to lock/unlock it.',
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Send demo gift to Owner',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _GiftTile(
                icon: '🌹',
                name: 'Rose',
                cost: 100,
                onTap: () => _sendGift(sheetContext, 'Rose', 100),
              ),
              _GiftTile(
                icon: '💎',
                name: 'Crystal',
                cost: 500,
                onTap: () => _sendGift(sheetContext, 'Crystal', 500),
              ),
              _GiftTile(
                icon: '👑',
                name: 'Crown',
                cost: 1000,
                onTap: () => _sendGift(sheetContext, 'Crown', 1000),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendGift(BuildContext sheetContext, String name, int cost) {
    final sent = widget.onSendGift(cost, name);
    Navigator.pop(sheetContext);
    if (!sent) {
      _snack('Not enough demo Coins.');
      return;
    }
    setState(() {
      _coins -= cost;
      _messages.add(RoomMessage('System', 'You sent $name to Owner 🎁'));
    });
    _snack('$name sent. $cost demo Coins deducted.');
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
            key: const Key('owner-tools'),
            tooltip: 'Owner/Admin controls',
            onPressed: _openOwnerTools,
            icon: const Icon(Icons.admin_panel_settings_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.workspace_premium_rounded),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Owner • VIP11',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Admin: VIP6 • Room demo mode',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Chip(label: Text(_inviteMode ? 'Invite ON' : 'Invite OFF')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    '${_requests.length} requests',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const Spacer(),
                  Text(
                    _selectedSeat == null
                        ? 'Tap a seat'
                        : 'Selected seat ${_selectedSeat! + 1}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 5,
              child: GridView.builder(
                key: const Key('seat-grid'),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: 30,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                ),
                itemBuilder: (context, index) {
                  final occupant = _seats[index];
                  final locked = _lockedSeats.contains(index);
                  final mine = occupant == 'You';
                  return InkWell(
                    onTap: () => _tapSeat(index),
                    onLongPress: () => _toggleLock(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: mine
                            ? const Color(0xFF5536A9)
                            : const Color(0xFF191A22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedSeat == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white12,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: locked ? Colors.white10 : null,
                            child: locked
                                ? const Icon(Icons.lock_rounded, size: 18)
                                : occupant == null
                                ? const Icon(Icons.add_rounded, size: 18)
                                : Text(occupant.characters.first),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            occupant ??
                                (locked ? 'Locked' : 'Seat ${index + 1}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _mySeat == null ? null : _leaveSeat,
                      icon: const Icon(Icons.event_seat_outlined),
                      label: Text(_mySeat == null ? 'Audience' : 'Leave seat'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _mySeat == null
                        ? null
                        : () => setState(() => _micMuted = !_micMuted),
                    icon: Icon(
                      _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _openGiftSheet,
                    icon: const Icon(Icons.card_giftcard_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF15161D),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${message.author}: ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: message.text),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: const InputDecoration(
                                hintText: 'Message room…',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
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
          const SizedBox(height: 22),
          const Text(
            'Transactions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...transactions.map(
            (entry) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(entry.title),
                subtitle: Text(entry.isCoins ? 'Coins' : 'Diamonds'),
                trailing: Text(
                  '${entry.amount > 0 ? '+' : ''}${entry.amount}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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
    const shortcuts = [
      ('VIP', Icons.workspace_premium_rounded),
      ('Bag', Icons.backpack_rounded),
      ('Medal', Icons.military_tech_rounded),
      ('Agency', Icons.groups_rounded),
      ('Tasks', Icons.task_alt_rounded),
      ('Language', Icons.language_rounded),
      ('Settings', Icons.settings_rounded),
      ('My Room', Icons.meeting_room_rounded),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: [
          if (anamikaOwnerTools)
            IconButton(
              tooltip: 'Anamika Code Doctor',
              icon: const Icon(Icons.build_circle_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AnamikaRepairPage(),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF4D2D84), Color(0xFF1B1730)],
              ),
            ),
            child: const Row(
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
                        'Demo User',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('ID 10000000  🇮🇳'),
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          Chip(label: Text('VIP11')),
                          Chip(label: Text('Owner')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat('128', 'Following'),
              _Stat('2.4K', 'Followers'),
              _Stat('86', 'Friends'),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            childAspectRatio: 0.92,
            children: shortcuts
                .map((item) => _Shortcut(title: item.$1, icon: item.$2))
                .toList(),
          ),
          const SizedBox(height: 10),
          const _InfoTile(
            icon: Icons.verified_user_rounded,
            title: 'v0.2 profile preview',
            subtitle:
                'Profile editing, badges and entitlement data are local demo content for now.',
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
        padding: const EdgeInsets.all(15),
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
                      fontSize: 18,
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

class _GiftTile extends StatelessWidget {
  const _GiftTile({
    required this.icon,
    required this.name,
    required this.cost,
    required this.onTap,
  });
  final String icon;
  final String name;
  final int cost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Text(icon, style: const TextStyle(fontSize: 28)),
      title: Text(name),
      trailing: Text('🪙 $cost'),
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

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(label, style: const TextStyle(color: Colors.white60)),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(child: Icon(icon)),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class RoomMessage {
  const RoomMessage(this.author, this.text);
  final String author;
  final String text;
}

class SeatRequest {
  const SeatRequest(this.name, this.vip, this.preferredSeat);
  final String name;
  final int vip;
  final int preferredSeat;
}

class WalletEntry {
  const WalletEntry(this.title, this.amount, this.isCoins);
  final String title;
  final int amount;
  final bool isCoins;
}
