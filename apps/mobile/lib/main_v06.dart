import 'package:flutter/material.dart';

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
      home: const V06Home(),
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
    const RoomData('India Official Room', '1524843', '👑', false),
    const RoomData('Night Party', '10000000', '🌙', true),
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
                const Text('Mine', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(width: 20),
                const Text('Popular', style: TextStyle(fontSize: 22, color: Colors.white60)),
                const Spacer(),
                IconButton(key: const Key('create-room-v06'), onPressed: _createRoom, icon: const Icon(Icons.add_circle_rounded, size: 30)),
              ]),
              const SizedBox(height: 18),
              for (final room in rooms)
                Card(
                  child: ListTile(
                    key: room.id == '1524843' ? const Key('open-v06-room') : null,
                    leading: CircleAvatar(child: Text(room.dp)),
                    title: Text(room.name),
                    subtitle: Text('ID ${room.id}${room.locked ? '  •  Locked' : ''}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoomV06(room: room))),
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
  String category = 'Friends';

  @override
  void dispose() {
    name.dispose();
    pin.dispose();
    super.dispose();
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
            onTap: () => setState(() => dp = dp == '🎧' ? '👑' : dp == '👑' ? '🌙' : '🎧'),
            child: CircleAvatar(radius: 42, child: Text(dp, style: const TextStyle(fontSize: 36))),
          ),
        ),
        const Center(child: Text('Room DP • gallery/camera hook ready for next integration')),
        const SizedBox(height: 14),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Room name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
          items: const ['Friends', 'Music', 'Game', 'Official'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => category = v ?? 'Friends'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: seats,
          decoration: const InputDecoration(labelText: 'Seats', border: OutlineInputBorder()),
          items: const [10, 15, 20, 25, 30].map((e) => DropdownMenuItem(value: e, child: Text('$e seats'))).toList(),
          onChanged: (v) => setState(() => seats = v ?? 15),
        ),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Invite Mode'), value: invite, onChanged: (v) => setState(() => invite = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Password Lock'), value: locked, onChanged: (v) => setState(() => locked = v)),
        if (locked) TextField(controller: pin, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit room PIN', border: OutlineInputBorder())),
        FilledButton(
          onPressed: () => Navigator.pop(context, RoomData(name.text.trim().isEmpty ? 'My Voice Room' : name.text.trim(), '10000010', dp, locked)),
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
  final seats = List<String?>.filled(30, null);
  final lockedSeats = <int>{8, 14, 24};
  final mutedSeats = <int>{2};
  final List<String> chat = ['System: Welcome to the room', 'Aisha: Hello everyone 👋'];
  bool inviteMode = true;
  String notice = 'Welcome! Be respectful and enjoy the room.';
  int? mySeat;

  @override
  void initState() {
    super.initState();
    seats[0] = 'Owner';
    seats[1] = 'Admin';
    seats[2] = 'Aisha';
    seats[6] = 'Sam';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF5B2387), Color(0xFF2D0B48), Color(0xFF100216)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                CircleAvatar(child: Text(widget.room.dp)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.room.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('ID ${widget.room.id} • ${inviteMode ? 'Invite Mode' : 'Open Seats'}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
                  itemCount: 30,
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
                _BottomTool(Icons.mic_rounded, 'Mic', () {}),
                _BottomTool(Icons.card_giftcard_rounded, 'Gift', () {}),
                _BottomTool(Icons.person_add_alt_1_rounded, 'Invite', () {}),
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
          if (seats[i] != null && seats[i] != 'Owner') ListTile(title: const Text('Kick 24h'), leading: const Icon(Icons.person_off_rounded), onTap: () { setState(() => seats[i] = null); Navigator.pop(sheetContext); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User kicked for 24h in local demo'))); }),
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
            _QuickTool(Icons.wallpaper_rounded, 'Room DP', () => Navigator.pop(sheetContext)),
            _QuickTool(Icons.image_rounded, 'Background', () => Navigator.pop(sheetContext)),
            _QuickTool(Icons.people_alt_rounded, 'Members', () { Navigator.pop(sheetContext); _members(); }),
            _QuickTool(Icons.admin_panel_settings_rounded, 'Admins', () => Navigator.pop(sheetContext)),
            _QuickTool(Icons.block_rounded, 'Block', () => Navigator.pop(sheetContext)),
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
          SwitchListTile(title: const Text('Invite Mode'), value: inviteMode, onChanged: (v) { setState(() => inviteMode = v); setLocal(() {}); }),
          ListTile(title: const Text('Edit Room Notice'), subtitle: Text(notice), trailing: const Icon(Icons.edit_rounded), onTap: _editNotice),
          ListTile(title: const Text('Room Password'), trailing: Text(widget.room.locked ? 'ON' : 'OFF')),
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
    showDialog<void>(context: context, builder: (_) => AlertDialog(
      title: const Text('Lucky Bag (LP)'),
      content: const Text('Local demo: create LP with Coins, set winners and timing. Server-authoritative payout comes later.'),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Create 6,000 LP'))],
    ));
  }

  void _gameCenter() {
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Game Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _GameCard('Dice', Icons.casino_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _GameCard('Lucky Wheel', Icons.motion_photos_on_rounded)),
        ]),
      ]),
    )));
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
  const RoomData(this.name, this.id, this.dp, this.locked);
  final String name;
  final String id;
  final String dp;
  final bool locked;
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
  const _GameCard(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [Icon(icon, size: 40), const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), FilledButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label local demo started'))), child: const Text('Play'))])));
}
