import 'anamika_repair_page.dart';
import 'package:flutter/material.dart';

void main() => runApp(const VoiceChatV05());

class VoiceChatV05 extends StatelessWidget {
  const VoiceChatV05({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Chat v0.5',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF120417),
        colorSchemeSeed: const Color(0xFF9B4DFF),
      ),
      home: const MainShellV05(),
    );
  }
}

class MainShellV05 extends StatefulWidget {
  const MainShellV05({super.key});
  @override
  State<MainShellV05> createState() => _MainShellV05State();
}

class _MainShellV05State extends State<MainShellV05> {
  int index = 0;
  final List<RoomCardData> rooms = [
    const RoomCardData('India Official Room', '1524843', '🇮🇳', 'IO'),
    const RoomCardData('Night Party', '10000000', '🌙', 'NP'),
    const RoomCardData('Music Club', '10000001', '🎵', 'MC'),
    const RoomCardData('Friends Hub', '10000002', '💜', 'FH'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeV05(
        rooms: rooms,
        onCreateRoom: _openCreateRoom,
        onOpenRoom: (room) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoyalRoomV05(room: room)),
        ),
      ),
      const BasicPage(title: 'Discover', icon: Icons.explore_rounded),
      const BasicPage(title: 'Message', icon: Icons.forum_rounded),
      const ProfileV05(),
    ];
    return Scaffold(
      floatingActionButton: anamikaOwnerTools
          ? FloatingActionButton(
              tooltip: 'Anamika Code Doctor',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AnamikaRepairPage(),
                ),
              ),
              child: const Icon(Icons.build_circle_outlined),
            )
          : null,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_rounded),
            label: 'Message',
          ),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }

  Future<void> _openCreateRoom() async {
    final result = await showModalBottomSheet<RoomCardData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CreateRoomSheet(),
    );
    if (result != null) setState(() => rooms.insert(0, result));
  }
}

class HomeV05 extends StatelessWidget {
  const HomeV05({
    super.key,
    required this.rooms,
    required this.onCreateRoom,
    required this.onOpenRoom,
  });
  final List<RoomCardData> rooms;
  final VoidCallback onCreateRoom;
  final ValueChanged<RoomCardData> onOpenRoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4B147A), Color(0xFF240630), Color(0xFF100313)],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                const Text(
                  'Mine',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 24),
                const Text(
                  'Popular',
                  style: TextStyle(fontSize: 23, color: Colors.white60),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onCreateRoom,
                  icon: const Icon(Icons.add_circle_rounded, size: 30),
                  tooltip: 'Create Room',
                ),
                const Icon(Icons.search_rounded, size: 30),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('create-room'),
              onPressed: onCreateRoom,
              icon: const Icon(Icons.add_home_rounded),
              label: const Text('Create Room'),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rooms.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .93,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) {
                final room = rooms[i];
                return GestureDetector(
                  key: i == 0 ? const Key('open-room') : null,
                  onTap: () => onOpenRoom(room),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7A2AA2), Color(0xFF271036)],
                      ),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            room.dp,
                            style: const TextStyle(fontSize: 56),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${room.flag} ID ${room.id}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key});
  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final name = TextEditingController(text: 'My Voice Room');
  int seats = 10;
  bool inviteMode = true;
  String dp = '👑';

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create Room',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Center(
            child: InkWell(
              key: const Key('room-dp-picker'),
              onTap: () => setState(
                () => dp = dp == '👑'
                    ? '🎧'
                    : dp == '🎧'
                    ? '🌙'
                    : '👑',
              ),
              borderRadius: BorderRadius.circular(50),
              child: CircleAvatar(
                radius: 42,
                child: Text(dp, style: const TextStyle(fontSize: 34)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('Tap Room DP to change')),
          const SizedBox(height: 14),
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Room name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: seats,
            decoration: const InputDecoration(
              labelText: 'Seat count',
              border: OutlineInputBorder(),
            ),
            items: const [10, 15, 20, 25, 30]
                .map((v) => DropdownMenuItem(value: v, child: Text('$v seats')))
                .toList(),
            onChanged: (v) => setState(() => seats = v ?? 10),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invite Mode'),
            value: inviteMode,
            onChanged: (v) => setState(() => inviteMode = v),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              RoomCardData(
                name.text.trim().isEmpty ? 'My Voice Room' : name.text.trim(),
                '10000009',
                '🇮🇳',
                dp,
              ),
            ),
            child: const Text('Create Room'),
          ),
        ],
      ),
    );
  }
}

class RoyalRoomV05 extends StatefulWidget {
  const RoyalRoomV05({super.key, required this.room});
  final RoomCardData room;
  @override
  State<RoyalRoomV05> createState() => _RoyalRoomV05State();
}

class _RoyalRoomV05State extends State<RoyalRoomV05> {
  final List<String?> seats = List<String?>.filled(30, null);
  final Set<int> locked = {7, 8, 11};
  final Set<int> muted = {2};
  int? mySeat;

  @override
  void initState() {
    super.initState();
    seats[0] = 'Owner';
    seats[1] = 'Admin';
    seats[2] = 'Sakura';
    seats[4] = 'Rohan';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF57217F), Color(0xFF2D0B48), Color(0xFF100216)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 10, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    CircleAvatar(child: Text(widget.room.dp)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.room.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'ID: ${widget.room.id}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('four-box-menu'),
                      onPressed: _openFourBoxMenu,
                      icon: const Icon(Icons.grid_view_rounded, size: 28),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  key: const Key('room-seat-grid'),
                  padding: const EdgeInsets.all(12),
                  itemCount: 30,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: .72,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 7,
                  ),
                  itemBuilder: (_, i) {
                    final occupied = seats[i] != null;
                    final isLocked = locked.contains(i);
                    final isMuted = muted.contains(i);
                    return GestureDetector(
                      key: i == 0 ? const Key('seat-0') : null,
                      onTap: () => _openSeatActions(i),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: occupied
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFFFC13A),
                                          Color(0xFF8B36FF),
                                        ],
                                      )
                                    : const LinearGradient(
                                        colors: [
                                          Color(0xFF3A244C),
                                          Color(0xFF1B1225),
                                        ],
                                      ),
                                border: Border.all(
                                  color: const Color(0xFFFFCB62),
                                ),
                              ),
                              child: Center(
                                child: isLocked
                                    ? const Icon(Icons.lock_rounded)
                                    : isMuted
                                    ? const Icon(Icons.mic_off_rounded)
                                    : occupied
                                    ? Text(
                                        seats[i]!.substring(0, 1),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      )
                                    : const Icon(Icons.add_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            seats[i] ?? 'Seat ${i + 1}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                key: const Key('room-bottom-tools'),
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                decoration: const BoxDecoration(color: Color(0xCC17051F)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Tool(Icons.chat_bubble_outline_rounded, 'Message'),
                    _Tool(Icons.mic_rounded, 'Mic'),
                    _Tool(Icons.card_giftcard_rounded, 'Gift'),
                    _Tool(Icons.person_add_alt_1_rounded, 'Invite'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSeatActions(int i) {
    final isLocked = locked.contains(i);
    final isMuted = muted.contains(i);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Seat ${i + 1} options',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                key: const Key('seat-lock-action'),
                leading: Icon(
                  isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                ),
                title: Text(isLocked ? 'Unlock Seat' : 'Lock Seat'),
                onTap: () {
                  setState(() {
                    if (isLocked) {
                      locked.remove(i);
                    } else {
                      locked.add(i);
                    }
                  });
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                key: const Key('seat-mute-action'),
                leading: Icon(
                  isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                ),
                title: Text(isMuted ? 'Unmute Seat' : 'Mute Seat'),
                onTap: () {
                  setState(() {
                    if (isMuted) {
                      muted.remove(i);
                    } else {
                      muted.add(i);
                    }
                  });
                  Navigator.pop(sheetContext);
                },
              ),
              if (!isLocked)
                ListTile(
                  leading: const Icon(Icons.event_seat_rounded),
                  title: const Text('Go to Seat'),
                  onTap: () {
                    setState(() {
                      if (mySeat != null) seats[mySeat!] = null;
                      seats[i] = 'You';
                      mySeat = i;
                    });
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFourBoxMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Room Tools',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                children: [
                  _QuickBox(
                    Icons.settings_rounded,
                    'Settings',
                    () => _showSimple('Room Settings'),
                  ),
                  _QuickBox(
                    Icons.card_giftcard_rounded,
                    'LP',
                    () => _showSimple('Lucky Bag (LP)'),
                  ),
                  _QuickBox(
                    Icons.sports_esports_rounded,
                    'Game',
                    () => _showSimple('Game Center'),
                  ),
                  _QuickBox(
                    Icons.wallpaper_rounded,
                    'Room DP',
                    _changeRoomDpInfo,
                  ),
                  _QuickBox(
                    Icons.music_note_rounded,
                    'Music',
                    () => _showSimple('Music'),
                  ),
                  _QuickBox(
                    Icons.people_alt_rounded,
                    'Members',
                    () => _showSimple('Members'),
                  ),
                  _QuickBox(
                    Icons.block_rounded,
                    'Block',
                    () => _showSimple('Block List'),
                  ),
                  _QuickBox(
                    Icons.more_horiz_rounded,
                    'More',
                    () => _showSimple('More Room Tools'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSimple(String title) {
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title opened in demo mode.')));
  }

  void _changeRoomDpInfo() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Room DP picker is available from Create/Edit Room in this demo.',
        ),
      ),
    );
  }
}

class ProfileV05 extends StatelessWidget {
  const ProfileV05({super.key});
  @override
  Widget build(BuildContext context) => const BasicPage(
    title: 'Me',
    icon: Icons.person_rounded,
    subtitle: 'Coins, Diamond, VIP, Store, Bag, Level and settings live here.',
  );
}

class BasicPage extends StatelessWidget {
  const BasicPage({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle = 'Coming in the next connected build.',
  });
  final String title;
  final IconData icon;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF43126C), Color(0xFF130419)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(subtitle, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Tool extends StatelessWidget {
  const _Tool(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class _QuickBox extends StatelessWidget {
  const _QuickBox(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class RoomCardData {
  const RoomCardData(this.name, this.id, this.flag, this.dp);
  final String name;
  final String id;
  final String flag;
  final String dp;
}
