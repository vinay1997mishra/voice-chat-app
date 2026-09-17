import 'package:flutter/material.dart';

void main() {
  runApp(const VoiceChatApp());
}

class VoiceChatApp extends StatelessWidget {
  const VoiceChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8A5CFF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Chat Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF101014),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
        ),
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
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9B6CFF), Color(0xFF5F3DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.graphic_eq_rounded, size: 48),
              ),
              const SizedBox(height: 28),
              const Text(
                'Voice Chat',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Phase 1 local demo. Explore rooms, seats, chat, gifts and wallet flows without a cloud server.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('continue-demo'),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const DemoShell()),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Continue in Demo Mode'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Google Sign-In and real server login will be connected in a later phase.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
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
  int _diamonds = 1200;
  final List<WalletEntry> _transactions = [
    const WalletEntry('Welcome bonus', 10000, true),
    const WalletEntry('Demo diamonds', 1200, false),
  ];

  bool _sendGift(int cost, String giftName) {
    if (_coins < cost) {
      return false;
    }

    setState(() {
      _coins -= cost;
      _transactions.insert(
        0,
        WalletEntry('Sent $giftName gift', -cost, true),
      );
    });
    return true;
  }

  void _openRoom() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DemoRoomPage(
          startingCoins: _coins,
          onSendGift: _sendGift,
        ),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Text('V'),
            ),
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
            borderRadius: BorderRadius.circular(24),
            onTap: onOpenRoom,
            child: Ink(
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF452A77), Color(0xFF1C1635)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          child: Icon(Icons.music_note_rounded),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Night Vibes',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text('Room ID 10000000 • Hindi / English'),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.headphones_rounded, size: 16),
                              SizedBox(width: 4),
                              Text('18'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'Tap to enter the local demo room',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seat controls, chat and gifts are active in demo mode.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _InfoTile(
            icon: Icons.lock_outline_rounded,
            title: 'GitHub-only mode',
            subtitle: 'No real user data or money is used in this build.',
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
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
  bool _isSeated = false;
  bool _micMuted = true;
  int? _mySeat;
  final TextEditingController _chatController = TextEditingController();
  final List<RoomMessage> _messages = [
    const RoomMessage('Host', 'Welcome to Night Vibes 👋'),
    const RoomMessage('Aisha', 'Hello everyone!'),
  ];
  final List<String?> _seats = [
    'Host',
    'Aisha',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
  ];

  @override
  void initState() {
    super.initState();
    _coins = widget.startingCoins;
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _toggleSeat() {
    setState(() {
      if (_isSeated && _mySeat != null) {
        _seats[_mySeat!] = null;
        _isSeated = false;
        _mySeat = null;
        _micMuted = true;
        return;
      }

      final emptySeat = _seats.indexWhere((seat) => seat == null);
      if (emptySeat >= 0) {
        _seats[emptySeat] = 'You';
        _isSeated = true;
        _mySeat = emptySeat;
      }
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

  void _openGiftSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Send demo gift to Host',
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
        );
      },
    );
  }

  void _sendGift(BuildContext sheetContext, String name, int cost) {
    final sent = widget.onSendGift(cost, name);
    Navigator.of(sheetContext).pop();

    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough demo Coins.')),
      );
      return;
    }

    setState(() {
      _coins -= cost;
      _messages.add(RoomMessage('System', 'You sent $name to Host 🎁'));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name sent. $cost demo Coins deducted.')),
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
            Text('Room ID 10000000', style: TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('🪙 $_coins'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.shield_rounded)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Host • Owner', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('Voice is simulated in this GitHub-only build.'),
                    ],
                  ),
                ),
                Icon(_micMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _seats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.78,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final occupant = _seats[index];
                final isMine = occupant == 'You';
                return Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isMine
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: isMine ? 2.5 : 1,
                          ),
                          color: occupant == null
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : Theme.of(context).colorScheme.primaryContainer,
                        ),
                        alignment: Alignment.center,
                        child: occupant == null
                            ? const Icon(Icons.add_rounded)
                            : Text(
                                occupant.substring(0, 1),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
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
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: '${message.sender}: ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: message.text),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(
                            hintText: 'Message the room',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _toggleSeat,
                          icon: Icon(
                            _isSeated
                                ? Icons.airline_seat_recline_normal_rounded
                                : Icons.event_seat_rounded,
                          ),
                          label: Text(_isSeated ? 'Leave seat' : 'Take seat'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Microphone',
                        onPressed: _isSeated
                            ? () => setState(() => _micMuted = !_micMuted)
                            : null,
                        icon: Icon(
                          _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Gift',
                        onPressed: _openGiftSheet,
                        icon: const Icon(Icons.card_giftcard_rounded),
                      ),
                    ],
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
      leading: Text(icon, style: const TextStyle(fontSize: 30)),
      title: Text(name),
      trailing: Text('🪙 $cost'),
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
          const SizedBox(height: 18),
          const _InfoTile(
            icon: Icons.science_rounded,
            title: 'Demo wallet',
            subtitle: 'Balances are local test values and have no cash value.',
          ),
          const SizedBox(height: 22),
          const Text(
            'Transactions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...transactions.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(
                  entry.amount >= 0
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                ),
              ),
              title: Text(entry.label),
              subtitle: Text(entry.isCoin ? 'Coins' : 'Diamonds'),
              trailing: Text(
                '${entry.amount >= 0 ? '+' : ''}${entry.amount}',
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
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: const Text(
                      'V',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo User',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 3),
                        Text('ID: 10000001 • India 🇮🇳'),
                        SizedBox(height: 5),
                        Text('VIP: Not active • Level 1'),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _InfoTile(
            icon: Icons.storefront_rounded,
            title: 'Store',
            subtitle: 'Catalog placeholder for the next phase.',
          ),
          const _InfoTile(
            icon: Icons.workspace_premium_rounded,
            title: 'VIP',
            subtitle: 'VIP1–VIP11 system will be added incrementally.',
          ),
          const _InfoTile(
            icon: Icons.inventory_2_rounded,
            title: 'Bag',
            subtitle: 'Owned and equipped cosmetics will appear here.',
          ),
          const _InfoTile(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: 'English • Hindi and more later.',
          ),
          const _InfoTile(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'Privacy, security and account controls.',
          ),
        ],
      ),
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
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
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
