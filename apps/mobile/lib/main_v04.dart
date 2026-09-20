import 'package:flutter/material.dart';

void main() => runApp(const VoiceChatV04());

class VoiceChatV04 extends StatelessWidget {
  const VoiceChatV04({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Chat v0.4',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF16051F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8E24FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  int coins = 2000000;
  int diamonds = 17125;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenRoom: () => _openRoom(context)),
      const DiscoverScreen(),
      const MessagesScreen(),
      MeScreen(coins: coins, diamonds: diamonds),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3C075E), Color(0xFF16051F)],
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_rounded),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_rounded),
              label: 'Message',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_rounded),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }

  void _openRoom(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoyalRoomScreen()),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenRoom});
  final VoidCallback onOpenRoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A1478), Color(0xFF250734), Color(0xFF110416)],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            const Row(
              children: [
                Text(
                  'Mine',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 24),
                Text(
                  'Popular',
                  style: TextStyle(fontSize: 24, color: Colors.white60),
                ),
                Spacer(),
                Icon(Icons.search_rounded, size: 30),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              key: const Key('official-room-card'),
              onTap: onOpenRoom,
              child: _glass(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _avatar('IO', 58, gold: true),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'India Official Room',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Room ID: 1524843',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Chip(label: Text('Mine')),
                        SizedBox(height: 4),
                        Text(
                          '▮▮▮ 99+',
                          style: TextStyle(color: Color(0xFFD14BFF)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _pill('New room', selected: true)),
                const SizedBox(width: 10),
                Expanded(child: _pill('Recently')),
                const SizedBox(width: 10),
                Expanded(child: _pill('Follow')),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .95,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) => GestureDetector(
                onTap: onOpenRoom,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: i.isEven
                          ? const [Color(0xFF7C2B9B), Color(0xFF271036)]
                          : const [Color(0xFF432968), Color(0xFF13233A)],
                    ),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          i.isEven
                              ? Icons.auto_awesome_rounded
                              : Icons.music_note_rounded,
                          size: 62,
                          color: Colors.white24,
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Row(
                          children: [
                            const Text('🇮🇳  '),
                            Expanded(
                              child: Text(
                                [
                                  'Love Lounge',
                                  'Night Party',
                                  'Music Club',
                                  'Friends Hub',
                                ][i % 4],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Text(
                              '999+',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});
  @override
  Widget build(BuildContext context) => _basicPage(
    'Discover',
    'Games, events, trending rooms and recommendations will live here.',
    Icons.explore_rounded,
  );
}

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF32104D), Color(0xFF120519)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Message',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            for (final item in const [
              ('Aisha', 'See you in the room 👋'),
              ('Rahul', 'Gift received, thanks!'),
              ('Host Team', 'Your application is being reviewed.'),
            ])
              Card(
                color: Colors.white.withValues(alpha: .06),
                child: ListTile(
                  leading: CircleAvatar(child: Text(item.$1.substring(0, 1))),
                  title: Text(item.$1),
                  subtitle: Text(item.$2),
                  trailing: const Text(
                    '21:06',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MeScreen extends StatelessWidget {
  const MeScreen({super.key, required this.coins, required this.diamonds});
  final int coins;
  final int diamonds;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('me-screen'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A1478), Color(0xFF20052C), Color(0xFF110416)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          children: [
            Row(
              children: [
                _avatar('MW', 54, gold: true),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mr.WronG 🌈',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '👑 1001   🇮🇳   ◈ 0   ✹ 0   🐼 0',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                _avatar('M', 48, gold: true),
              ],
            ),
            const SizedBox(height: 26),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat('14', 'Visitors'),
                _Stat('4', 'Following'),
                _Stat('7', 'Followers'),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6522A9),
                    Color(0xFFBA2DFF),
                    Color(0xFF6F22A8),
                  ],
                ),
                border: Border.all(color: const Color(0xFFFFC95A), width: 2),
              ),
              child: Row(
                children: [
                  const Text(
                    'VIP8',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD45A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIP',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFD45A),
                          ),
                        ),
                        Text('Unlock Premium Experience'),
                      ],
                    ),
                  ),
                  FilledButton(onPressed: () {}, child: const Text('Upgrade')),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _walletCard(
                    Icons.monetization_on_rounded,
                    'Coins',
                    _format(coins),
                    const [Color(0xFFFFD85A), Color(0xFFFFF0A6)],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _walletCard(
                    Icons.diamond_rounded,
                    'Diamond',
                    _format(diamonds),
                    const [Color(0xFFE2B5FF), Color(0xFFB367FF)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _glass(
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Shortcut(Icons.storefront_rounded, 'Store'),
                  _Shortcut(Icons.task_alt_rounded, 'Task'),
                  _Shortcut(Icons.military_tech_rounded, 'Medal'),
                  _Shortcut(Icons.backpack_rounded, 'Bag'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _glass(
              child: const Column(
                children: [
                  _Menu(Icons.auto_awesome_rounded, 'Level'),
                  _Menu(Icons.how_to_reg_rounded, 'Apply ToHost'),
                  _Menu(Icons.settings_rounded, 'Setting'),
                  _Menu(Icons.translate_rounded, 'Language'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoyalRoomScreen extends StatefulWidget {
  const RoyalRoomScreen({super.key});
  @override
  State<RoyalRoomScreen> createState() => _RoyalRoomScreenState();
}

class _RoyalRoomScreenState extends State<RoyalRoomScreen> {
  final List<String?> seats = List<String?>.filled(30, null);
  final Set<int> locked = {7, 8, 10, 11, 12, 13};
  int? mySeat;
  bool micMuted = true;
  final controller = TextEditingController();
  final List<String> messages = [
    'Sakura: Welcome everyone! 🎉',
    'Rohan: Great voice room! 🎤✨',
    'Angel: Nice to meet you all! 💖',
  ];

  @override
  void initState() {
    super.initState();
    seats[0] = 'Kitti';
    seats[1] = 'Alex';
    seats[2] = 'Sakura';
    seats[3] = 'Rohan';
    seats[5] = 'Angel';
    seats[6] = 'Dev';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF51217A), Color(0xFF2A0C45), Color(0xFF110317)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    _avatar('IO', 34, gold: true),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'India Official Room',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'ID: 1524843',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.share_rounded),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Chip(label: Text('👥 99+')),
                    SizedBox(width: 8),
                    Chip(label: Text('🎵 Music')),
                    SizedBox(width: 8),
                    Chip(label: Text('📶 68ms')),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '📢 Welcome to India Official Room! Be kind, respectful and enjoy.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    GridView.builder(
                      key: const Key('room-seat-grid'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 15,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            childAspectRatio: .78,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _seatTap(i),
                        onLongPress: () => _toggleLock(i),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: seats[i] != null
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFFFFB52E),
                                            Color(0xFF7A25FF),
                                          ],
                                        )
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFF3A244B),
                                            Color(0xFF1B1225),
                                          ],
                                        ),
                                  border: Border.all(
                                    color: const Color(0xFFFFC85A),
                                    width: 1.3,
                                  ),
                                ),
                                child: Center(
                                  child: locked.contains(i)
                                      ? const Icon(Icons.lock_rounded)
                                      : seats[i] == null
                                      ? const Icon(Icons.add_rounded, size: 30)
                                      : Text(
                                          seats[i]!.substring(0, 1),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              seats[i] ?? 'Take Seat',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    for (final m in messages)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: _glass(
                          padding: const EdgeInsets.all(10),
                          child: Text(m),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Say something nice...',
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => micMuted = !micMuted),
                      icon: Icon(
                        micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _requestSeat,
                      icon: const Icon(Icons.pan_tool_alt_rounded),
                      label: const Text('Request'),
                    ),
                  ],
                ),
              ),
              Container(
                key: const Key('room-bottom-tools'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF24102E),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _tool(Icons.chat_bubble_outline_rounded, 'Message', _send),
                    _tool(
                      Icons.lock_rounded,
                      'Seat Lock',
                      () => _toggleLock(7),
                    ),
                    _tool(Icons.event_seat_rounded, 'Go to Seat', _goToSeat),
                    _tool(
                      Icons.settings_rounded,
                      'Room Settings',
                      _roomSettings,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fab(Icons.sports_esports_rounded, 'Game'),
            _fab(Icons.card_giftcard_rounded, 'Gift'),
            _fab(Icons.campaign_rounded, 'Room'),
            _fab(Icons.group_add_rounded, 'Invite'),
          ],
        ),
      ),
    );
  }

  void _seatTap(int i) {
    if (locked.contains(i)) {
      _snack('Seat ${i + 1} locked hai.');
      return;
    }
    if (seats[i] != null) {
      _snack('${seats[i]} is seat ${i + 1} par hai.');
      return;
    }
    setState(() {
      if (mySeat != null) seats[mySeat!] = null;
      seats[i] = 'You';
      mySeat = i;
    });
  }

  void _toggleLock(int i) =>
      setState(() => locked.contains(i) ? locked.remove(i) : locked.add(i));
  void _goToSeat() => _seatTap(14);
  void _requestSeat() => _snack('Seat request Owner/Admin ko bhej di gayi.');
  void _roomSettings() => _snack('Room settings panel demo.');
  void _send() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add('You: $text');
      controller.clear();
    });
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Widget _fab(IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      children: [
        FloatingActionButton.small(
          heroTag: label,
          onPressed: () => _snack('$label opened'),
          child: Icon(icon),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );
}

Widget _tool(IconData icon, String label, VoidCallback onTap) => InkWell(
  onTap: onTap,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  ),
);

Widget _walletCard(
  IconData icon,
  String label,
  String value,
  List<Color> colors,
) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: colors),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFFFFC85A), width: 2),
  ),
  child: Row(
    children: [
      Icon(icon, color: const Color(0xFF5A2700), size: 36),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF5A2700))),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF5A2700),
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    ],
  ),
);

Widget _glass({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(14),
}) => Container(
  padding: padding,
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: .07),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white12),
  ),
  child: child,
);

Widget _avatar(String text, double radius, {bool gold = false}) => Container(
  width: radius * 2,
  height: radius * 2,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: const LinearGradient(
      colors: [Color(0xFF22222A), Color(0xFF060607)],
    ),
    border: Border.all(
      color: gold ? const Color(0xFFFFC85A) : Colors.white24,
      width: gold ? 3 : 1,
    ),
  ),
  child: Center(
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
  ),
);

Widget _pill(String text, {bool selected = false}) => Container(
  alignment: Alignment.center,
  padding: const EdgeInsets.symmetric(vertical: 12),
  decoration: BoxDecoration(
    gradient: selected
        ? const LinearGradient(colors: [Color(0xFF8427D7), Color(0xFF51118B)])
        : null,
    color: selected ? null : Colors.white10,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(
      color: selected ? const Color(0xFFFFCE59) : Colors.white24,
    ),
  ),
  child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
);

Widget _basicPage(String title, String subtitle, IconData icon) => Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF3D0E5F), Color(0xFF14051A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  child: SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 70),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    ),
  ),
);

String _format(int n) =>
    n.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => ',');

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      Text(label, style: const TextStyle(color: Colors.white60)),
    ],
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      children: [
        CircleAvatar(radius: 26, child: Icon(icon)),
        const SizedBox(height: 8),
        Text(label),
      ],
    ),
  );
}

class _Menu extends StatelessWidget {
  const _Menu(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: const Color(0xFFC95BFF)),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}
