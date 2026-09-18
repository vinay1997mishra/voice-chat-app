import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const VoiceChatV06());

class VoiceChatV06 extends StatelessWidget {
  const VoiceChatV06({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Chat v0.6',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF8E35FF),
        scaffoldBackgroundColor: const Color(0xFF120316),
      ),
      home: const MainShellV06(),
    );
  }
}

class MainShellV06 extends StatefulWidget {
  const MainShellV06({super.key});
  @override
  State<MainShellV06> createState() => _MainShellV06State();
}

class _MainShellV06State extends State<MainShellV06> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const V06Home(),
      const BasicPageV06(
        title: 'Discover',
        icon: Icons.explore_rounded,
        subtitle: 'Popular rooms, categories and Game Center discovery.',
      ),
      const BasicPageV06(
        title: 'Message',
        icon: Icons.forum_rounded,
        subtitle: 'Room chat and private-message demo hub.',
      ),
      const ProfileV06(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_rounded), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.forum_rounded), label: 'Message'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}

class V06Home extends StatefulWidget {
  const V06Home({super.key});
  @override
  State<V06Home> createState() => _V06HomeState();
}

class _V06HomeState extends State<V06Home> {
  final rooms = <RoomData>[
    RoomData('India Official Room', '1524843', '👑', false, seatCount: 30, category: 'Official', inviteMode: true),
    RoomData('Night Party', '10000000', '🌙', true, seatCount: 15, category: 'Music', inviteMode: false, pin: '123456'),
  ];

  Future<void> _createRoom() async {
    final room = await showModalBottomSheet<RoomData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CreateRoomV06(),
    );
    if (room != null) setState(() => rooms.insert(0, room));
  }

  Future<void> _openRoom(RoomData room) async {
    if (room.locked) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Room Password'),
          content: TextField(
            key: const Key('join-room-pin-v06'),
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '6-digit PIN',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim() == room.pin) {
                  Navigator.pop(dialogContext, true);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Wrong room PIN')),
                  );
                }
              },
              child: const Text('Enter'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (ok != true || !mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomV06(room: room)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A1477), Color(0xFF21052C), Color(0xFF0F0213)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(children: [
                const Text('Mine', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Popular',
                    style: TextStyle(fontSize: 20, color: Colors.white60),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: const Key('create-room-v06'),
                  onPressed: _createRoom,
                  icon: const Icon(Icons.add_circle_rounded, size: 30),
                ),
              ]),
              const SizedBox(height: 18),
              for (final room in rooms)
                Card(
                  child: ListTile(
                    key: room.id == '1524843' ? const Key('open-v06-room') : null,
                    leading: room.dpPath == null ? CircleAvatar(child: Text(room.dp)) : CircleAvatar(backgroundImage: FileImage(File(room.dpPath!))),
                    title: Text(room.name),
                    subtitle: Text('${room.category} • ${room.seatCount} seats • ID ${room.id}${room.locked ? ' • Locked' : ''}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openRoom(room),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateRoomV06 extends StatefulWidget {
  const CreateRoomV06({super.key});
  @override
  State<CreateRoomV06> createState() => _CreateRoomV06State();
}

class _CreateRoomV06State extends State<CreateRoomV06> {
  final name = TextEditingController(text: 'My Voice Room');
  final pin = TextEditingController();
  int seats = 15;
  bool invite = true;
  bool locked = false;
  String dp = '🎧';
  String? dpPath;
  final picker = ImagePicker();
  String category = 'Friends';

  @override
  void dispose() {
    name.dispose();
    pin.dispose();
    super.dispose();
  }

  Future<void> _chooseDp() async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_rounded),
              title: const Text('Emoji DP'),
              onTap: () {
                setState(() {
                  dpPath = null;
                  dp = dp == '🎧' ? '👑' : dp == '👑' ? '🌙' : '🎧';
                });
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file != null && mounted) setState(() => dpPath = file.path);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Create Room v0.6', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Center(
          child: InkWell(
            key: const Key('room-dp-v06'),
            onTap: _chooseDp,
            child: dpPath == null
                ? CircleAvatar(radius: 42, child: Text(dp, style: const TextStyle(fontSize: 36)))
                : CircleAvatar(radius: 42, backgroundImage: FileImage(File(dpPath!))),
          ),
        ),
        const Center(child: Text('Tap DP • Gallery / Camera / Emoji')),
        const SizedBox(height: 14),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Room name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: category,
          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
          items: const ['Friends', 'Music', 'Game', 'Official'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => category = v ?? 'Friends'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: seats,
          decoration: const InputDecoration(labelText: 'Seats', border: OutlineInputBorder()),
          items: const [10, 15, 20, 25, 30].map((e) => DropdownMenuItem(value: e, child: Text('$e seats'))).toList(),
          onChanged: (v) => setState(() => seats = v ?? 15),
        ),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Invite Mode'), value: invite, onChanged: (v) => setState(() => invite = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Password Lock'), value: locked, onChanged: (v) => setState(() => locked = v)),
        if (locked) TextField(controller: pin, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit room PIN', border: OutlineInputBorder())),
        FilledButton(
          key: const Key('create-room-submit-v06'),
          onPressed: () {
            final cleanPin = pin.text.trim();
            if (locked && !RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password must be exactly 6 digits')),
              );
              return;
            }
            Navigator.pop(
              context,
              RoomData(
                name.text.trim().isEmpty ? 'My Voice Room' : name.text.trim(),
                '10000010',
                dp,
                locked,
                seatCount: seats,
                category: category,
                inviteMode: invite,
                pin: locked ? cleanPin : '',
                dpPath: dpPath,
              ),
            );
          },
          child: const Text('Create Room'),
        ),
      ]),
    );
  }
}

class RoomV06 extends StatefulWidget {
  const RoomV06({super.key, required this.room});
  final RoomData room;
  @override
  State<RoomV06> createState() => _RoomV06State();
}

class _RoomV06State extends State<RoomV06> {
  late List<String?> seats;
  final lockedSeats = <int>{};
  final mutedSeats = <int>{};
  final admins = <String>{'Admin'};
  final blocked = <String>{};
  final List<String> chat = ['System: Welcome to the room', 'Aisha: Hello everyone 👋'];
  late bool inviteMode;
  String notice = 'Welcome! Be respectful and enjoy the room.';
  int? mySeat;
  bool micOn = false;
  int backgroundIndex = 0;
  final picker = ImagePicker();
  static const roomBackgrounds = <List<Color>>[
    [Color(0xFF5B2387), Color(0xFF2D0B48), Color(0xFF100216)],
    [Color(0xFF0E4C92), Color(0xFF12305F), Color(0xFF07111F)],
    [Color(0xFF6B2F2F), Color(0xFF3D1717), Color(0xFF160707)],
    [Color(0xFF12664F), Color(0xFF0C3A2F), Color(0xFF041813)],
  ];

  @override
  void initState() {
    super.initState();
    inviteMode = widget.room.inviteMode;
    seats = List<String?>.filled(widget.room.seatCount, null);
    if (seats.isNotEmpty) seats[0] = 'Owner';
    if (seats.length > 1) seats[1] = 'Admin';
    if (seats.length > 2) {
      seats[2] = 'Aisha';
      mutedSeats.add(2);
    }
    if (seats.length > 6) seats[6] = 'Sam';
    for (final i in [8, 14, 24]) {
      if (i < seats.length) lockedSeats.add(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: roomBackgrounds[backgroundIndex], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                widget.room.dpPath == null ? CircleAvatar(child: Text(widget.room.dp)) : CircleAvatar(backgroundImage: FileImage(File(widget.room.dpPath!))),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.room.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('${widget.room.category} • ID ${widget.room.id} • ${inviteMode ? 'Invite Mode' : 'Open Seats'}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ])),
                IconButton(key: const Key('v06-four-box'), onPressed: _openTools, icon: const Icon(Icons.grid_view_rounded)),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Align(alignment: Alignment.centerLeft, child: Text('📢 $notice', maxLines: 1, overflow: TextOverflow.ellipsis))),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: [
                GridView.builder(
                  key: const Key('v06-seat-grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: seats.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, childAspectRatio: .72, crossAxisSpacing: 6, mainAxisSpacing: 6),
                  itemBuilder: (_, i) => GestureDetector(
                    key: i == 0 ? const Key('v06-seat-0') : null,
                    onTap: () => _seatOptions(i),
                    child: Column(children: [
                      Expanded(child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: seats[i] != null ? const LinearGradient(colors: [Color(0xFFFFC04B), Color(0xFF8E35FF)]) : const LinearGradient(colors: [Color(0xFF39244C), Color(0xFF1A1123)]),
                          border: Border.all(color: const Color(0xFFFFCC67)),
                        ),
                        child: Center(child: lockedSeats.contains(i) ? const Icon(Icons.lock_rounded) : mutedSeats.contains(i) ? const Icon(Icons.mic_off_rounded) : seats[i] != null ? Text(seats[i]!.substring(0, 1)) : const Icon(Icons.add_rounded)),
                      )),
                      const SizedBox(height: 2),
                      Text(seats[i] ?? 'Seat ${i + 1}', style: const TextStyle(fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Room Chat', style: TextStyle(fontWeight: FontWeight.w800)),
                      for (final m in chat) Padding(padding: const EdgeInsets.only(top: 4), child: Text(m)),
                    ]),
                  ),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: const Color(0xCC17051F),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _BottomTool(Icons.chat_bubble_outline_rounded, 'Message', _sendMessage),
                _BottomTool(
                  micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  micOn ? 'Mic On' : 'Mic Off',
                  () => setState(() => micOn = !micOn),
                ),
                _BottomTool(Icons.card_giftcard_rounded, 'Gift', _gift),
                _BottomTool(
                  Icons.person_add_alt_1_rounded,
                  'Invite',
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        inviteMode ? 'Invite request created' : 'Room link ready to share',
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _seatOptions(int i) {
    final isLocked = lockedSeats.contains(i);
    final isMuted = mutedSeats.contains(i);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(14, 0, 14, 18), children: [
          Text('Seat ${i + 1} options', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ListTile(title: Text(isLocked ? 'Unlock Seat' : 'Lock Seat'), leading: Icon(isLocked ? Icons.lock_open : Icons.lock), onTap: () { setState(() => isLocked ? lockedSeats.remove(i) : lockedSeats.add(i)); Navigator.pop(sheetContext); }),
          ListTile(title: Text(isMuted ? 'Unmute Seat' : 'Mute Seat'), leading: Icon(isMuted ? Icons.mic : Icons.mic_off), onTap: () { setState(() => isMuted ? mutedSeats.remove(i) : mutedSeats.add(i)); Navigator.pop(sheetContext); }),
          if (!isLocked) ListTile(title: const Text('Go to Seat'), leading: const Icon(Icons.event_seat_rounded), onTap: () { setState(() { if (mySeat != null) seats[mySeat!] = null; seats[i] = 'You'; mySeat = i; }); Navigator.pop(sheetContext); }),
          if (seats[i] != null && seats[i] != 'Owner') ListTile(title: const Text('Move to Audience'), leading: const Icon(Icons.keyboard_arrow_down_rounded), onTap: () { setState(() => seats[i] = null); Navigator.pop(sheetContext); }),
          if (seats[i] != null && seats[i] != 'Owner' && seats[i] != 'You')
            ListTile(
              title: Text(admins.contains(seats[i]) ? 'Remove Admin' : 'Make Admin'),
              leading: const Icon(Icons.admin_panel_settings_rounded),
              onTap: () {
                final user = seats[i]!;
                setState(() {
                  if (!admins.remove(user)) admins.add(user);
                });
                Navigator.pop(sheetContext);
              },
            ),
          if (seats[i] != null && seats[i] != 'Owner' && seats[i] != 'You')
            ListTile(
              title: const Text('Block User'),
              leading: const Icon(Icons.block_rounded),
              onTap: () {
                final user = seats[i]!;
                setState(() {
                  blocked.add(user);
                  seats[i] = null;
                });
                Navigator.pop(sheetContext);
              },
            ),
          if (seats[i] != null && seats[i] != 'Owner' && seats[i] != 'You')
            ListTile(
              title: const Text('Kick 24h'),
              leading: const Icon(Icons.person_off_rounded),
              onTap: () {
                setState(() => seats[i] = null);
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User kicked for 24h in local demo')),
                );
              },
            ),
        ]),
      ),
    );
  }

  void _openTools() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: GridView.count(
          key: const Key('v06-tools-grid'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          crossAxisCount: 4,
          children: [
            _QuickTool(Icons.settings_rounded, 'Settings', () { Navigator.pop(sheetContext); _settings(); }),
            _QuickTool(Icons.card_giftcard_rounded, 'LP', () { Navigator.pop(sheetContext); _luckyBag(); }),
            _QuickTool(Icons.sports_esports_rounded, 'Game', () { Navigator.pop(sheetContext); _gameCenter(); }),
            _QuickTool(Icons.wallpaper_rounded, 'Room DP', () { Navigator.pop(sheetContext); _changeRoomDp(); }),
            _QuickTool(Icons.image_rounded, 'Background', () { Navigator.pop(sheetContext); _backgrounds(); }),
            _QuickTool(Icons.music_note_rounded, 'Music', () { Navigator.pop(sheetContext); _music(); }),
            _QuickTool(Icons.people_alt_rounded, 'Members', () { Navigator.pop(sheetContext); _members(); }),
            _QuickTool(Icons.admin_panel_settings_rounded, 'Admins', () { Navigator.pop(sheetContext); _admins(); }),
            _QuickTool(Icons.block_rounded, 'Block', () { Navigator.pop(sheetContext); _blockList(); }),
            _QuickTool(Icons.more_horiz_rounded, 'More', () { Navigator.pop(sheetContext); _more(); }),
          ],
        ),
      ),
    );
  }

  void _settings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(builder: (context, setLocal) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Room Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          SwitchListTile(title: const Text('Invite Mode'), value: inviteMode, onChanged: (v) { setState(() { inviteMode = v; widget.room.inviteMode = v; }); setLocal(() {}); }),
          ListTile(title: const Text('Edit Room Notice'), subtitle: Text(notice), trailing: const Icon(Icons.edit_rounded), onTap: _editNotice),
          ListTile(title: const Text('Room Password'), subtitle: Text(widget.room.locked ? 'Enabled' : 'Disabled'), trailing: const Icon(Icons.password_rounded), onTap: _editPassword),
        ]),
      ))),
    );
  }

  void _editNotice() {
    final c = TextEditingController(text: notice);
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Edit Room Notice'),
      content: TextField(controller: c),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { setState(() => notice = c.text.trim().isEmpty ? notice : c.text.trim()); Navigator.pop(dialogContext); }, child: const Text('Save'))],
    ));
  }

  void _luckyBag() {
    final amount = TextEditingController(text: '6000');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lucky Bag (LP)'),
        content: TextField(
          key: const Key('lp-amount-v06'),
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'LP amount (min 6,000)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(amount.text.trim()) ?? 0;
              if (value < 6000) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lucky Bag minimum is 6,000 LP')),
                );
                return;
              }
              setState(() => chat.add('System: Lucky Bag $value LP created'));
              Navigator.pop(dialogContext);
            },
            child: const Text('Create LP'),
          ),
        ],
      ),
    ).whenComplete(amount.dispose);
  }

  void _gameCenter() {
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Game Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _GameCard('Dice', Icons.casino_rounded, () => _playGame('Dice'))),
          const SizedBox(width: 10),
          Expanded(child: _GameCard('Lucky Wheel', Icons.motion_photos_on_rounded, () => _playGame('Lucky Wheel'))),
        ]),
      ]),
    )));
  }

  void _playGame(String name) {
    final random = Random();
    final result = name == 'Dice'
        ? '${random.nextInt(6) + 1}'
        : ['10x', '2x', 'Try Again', '5x'][random.nextInt(4)];
    setState(() => chat.add('Game: $name result → $result'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name result: $result')),
    );
  }

  Future<void> _changeRoomDp() async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_rounded),
              title: const Text('Cycle Emoji DP'),
              onTap: () {
                setState(() {
                  widget.room.dpPath = null;
                  widget.room.dp = widget.room.dp == '🎧'
                      ? '👑'
                      : widget.room.dp == '👑'
                          ? '🌙'
                          : '🎧';
                });
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file != null && mounted) {
      setState(() => widget.room.dpPath = file.path);
    }
  }

  void _backgrounds() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          itemCount: roomBackgrounds.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (_, i) => InkWell(
            onTap: () {
              setState(() => backgroundIndex = i);
              Navigator.pop(sheetContext);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: roomBackgrounds[i]),
                border: Border.all(color: Colors.white70),
              ),
              child: Center(child: Text('Background ${i + 1}')),
            ),
          ),
        ),
      ),
    );
  }

  void _admins() {
    final users = seats.whereType<String>().where((m) => m != 'Owner' && m != 'You').toList();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Admin Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              for (final user in users)
                SwitchListTile(
                  title: Text(user),
                  value: admins.contains(user),
                  onChanged: (value) {
                    setState(() {
                      if (value) { admins.add(user); } else { admins.remove(user); }
                    });
                    setLocal(() {});
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _blockList() {
    final users = seats.whereType<String>().where((m) => m != 'Owner' && m != 'You').toList();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Block List', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              if (blocked.isEmpty) const ListTile(title: Text('No blocked users')),
              for (final user in blocked.toList())
                ListTile(
                  title: Text(user),
                  trailing: TextButton(
                    onPressed: () { setState(() => blocked.remove(user)); setLocal(() {}); },
                    child: const Text('Unblock'),
                  ),
                ),
              const Divider(),
              for (final user in users.where((m) => !blocked.contains(m)))
                ListTile(
                  title: Text(user),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        blocked.add(user);
                        final i = seats.indexOf(user);
                        if (i >= 0) seats[i] = null;
                      });
                      setLocal(() {});
                    },
                    child: const Text('Block'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _gift() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Send Gift', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            for (final gift in const ['Rose 🌹', 'Crown 👑', 'Rocket 🚀'])
              ListTile(
                title: Text(gift),
                onTap: () {
                  setState(() => chat.add('You sent $gift'));
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _music() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Music', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            for (final track in const ['Chill Room', 'Party Beat', 'Lo-fi Night'])
              ListTile(
                leading: const Icon(Icons.music_note_rounded),
                title: Text(track),
                trailing: const Icon(Icons.play_arrow_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$track selected in local demo')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _more() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('More Room Tools', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 12),
              Text('Share Room • Report • Room Info • Local demo controls'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editPassword() async {
    final controller = TextEditingController(text: widget.room.pin);
    bool enabled = widget.room.locked;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Room Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable password'),
                value: enabled,
                onChanged: (value) => setLocal(() => enabled = value),
              ),
              if (enabled)
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: '6-digit PIN', border: OutlineInputBorder()),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (enabled && !RegExp(r'^\d{6}$').hasMatch(value)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN must be exactly 6 digits')),
                  );
                  return;
                }
                setState(() {
                  widget.room.locked = enabled;
                  widget.room.pin = enabled ? value : '';
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  void _members() {
    final members = seats.whereType<String>().toList();
    showModalBottomSheet<void>(context: context, builder: (_) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
      const Text('Members', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      for (final m in members) ListTile(leading: CircleAvatar(child: Text(m.substring(0, 1))), title: Text(m)),
    ])));
  }

  void _sendMessage() {
    final c = TextEditingController();
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(14, 14, 14, MediaQuery.of(sheetContext).viewInsets.bottom + 14),
      child: Row(children: [
        Expanded(child: TextField(controller: c, decoration: const InputDecoration(hintText: 'Message...', border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        FilledButton(onPressed: () { if (c.text.trim().isNotEmpty) setState(() => chat.add('You: ${c.text.trim()}')); Navigator.pop(sheetContext); }, child: const Text('Send')),
      ]),
    ));
  }
}

class RoomData {
  RoomData(
    this.name,
    this.id,
    this.dp,
    this.locked, {
    this.seatCount = 30,
    this.category = 'Friends',
    this.inviteMode = true,
    this.pin = '',
    this.dpPath,
  });

  String name;
  final String id;
  String dp;
  bool locked;
  int seatCount;
  String category;
  bool inviteMode;
  String pin;
  String? dpPath;
}

class _BottomTool extends StatelessWidget {
  const _BottomTool(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 11))])));
}

class _QuickTool extends StatelessWidget {
  const _QuickTool(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(child: Icon(icon)), const SizedBox(height: 6), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))]));
}

class _GameCard extends StatelessWidget {
  const _GameCard(this.label, this.icon, this.onPlay);
  final String label;
  final IconData icon;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              FilledButton(onPressed: onPlay, child: const Text('Play')),
            ],
          ),
        ),
      );
}

class ProfileV06 extends StatelessWidget {
  const ProfileV06({super.key});

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
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Row(
                children: [
                  CircleAvatar(radius: 34, child: Icon(Icons.person_rounded, size: 34)),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      Text('ID 10000000'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _WalletCard(title: 'Coins', value: '1,000,000', icon: Icons.monetization_on_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _WalletCard(title: 'Diamond', value: '25,000', icon: Icons.diamond_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              const ListTile(leading: Icon(Icons.workspace_premium_rounded), title: Text('VIP'), subtitle: Text('VIP levels 1–11 demo')),
              const ListTile(leading: Icon(Icons.shopping_bag_rounded), title: Text('Bag / Store')),
              const ListTile(leading: Icon(Icons.bar_chart_rounded), title: Text('Level')),
              const ListTile(leading: Icon(Icons.settings_rounded), title: Text('Settings')),
            ],
          ),
        ),
      );
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(value),
            ],
          ),
        ),
      );
}

class BasicPageV06 extends StatelessWidget {
  const BasicPageV06({
    super.key,
    required this.title,
    required this.icon,
    required this.subtitle,
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
                Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
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
