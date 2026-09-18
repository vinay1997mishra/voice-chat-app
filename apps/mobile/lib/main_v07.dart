import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'games_v07.dart';

void main() => runApp(const VoiceChatV07());


class DemoUser {
  DemoUser(this.name, this.id, {this.diamonds = 0, this.avatar = '👤'});
  final String name;
  final String id;
  int diamonds;
  final String avatar;
}

class DemoGift {
  const DemoGift(this.name, this.emoji, this.coins);
  final String name;
  final String emoji;
  final int coins;
}

class DemoLedgerEntry {
  DemoLedgerEntry(this.title, this.detail, this.amount);
  final String title;
  final String detail;
  final int amount;
}

class DemoInboxItem {
  DemoInboxItem(
    this.title,
    this.subtitle,
    this.icon, {
    this.unread = true,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  bool unread;
}

class DemoGiftHistory {
  DemoGiftHistory({
    required this.gift,
    required this.fromName,
    required this.fromId,
    required this.toName,
    required this.toId,
    required this.coins,
    required this.diamonds,
    required this.direction,
  });

  final String gift;
  final String fromName;
  final String fromId;
  final String toName;
  final String toId;
  final int coins;
  final int diamonds;
  final String direction;
}

class DemoEconomy extends ChangeNotifier {
  int coins = 10000000;
  int diamonds = 25000;
  int wealthXp = 1800;
  int activeVip = 3;
  String equippedFrame = 'Purple Glow';
  bool threeDEffects = true;
  bool messageNotifications = true;
  bool giftAnimations = true;
  bool allowPrivateMessages = true;
  final following = <String>{};

  final users = <DemoUser>[
    DemoUser('Owner', '10000000', diamonds: 5000, avatar: '👑'),
    DemoUser('Admin', '10000001', diamonds: 2400, avatar: '🛡️'),
    DemoUser('Aisha', '10000011', diamonds: 1800, avatar: '🌸'),
    DemoUser('Sam', '10000012', diamonds: 900, avatar: '🎧'),
  ];

  final gifts = const <DemoGift>[
    DemoGift('Rose', '🌹', 100),
    DemoGift('Heart', '💜', 500),
    DemoGift('Crown', '👑', 1000),
    DemoGift('Sports Car', '🏎️', 10000),
    DemoGift('Yacht', '🛥️', 100000),
    DemoGift('Dragon', '🐉', 1000000),
    DemoGift('Galaxy', '🌌', 5000000),
  ];

  final ledger = <DemoLedgerEntry>[
    DemoLedgerEntry('Opening balance', 'Demo wallet', 10000000),
  ];

  final inbox = <DemoInboxItem>[
    DemoInboxItem(
      'Welcome',
      'v0.7 final local demo wallet and inbox are ready.',
      Icons.celebration_rounded,
    ),
    DemoInboxItem(
      'Owner',
      'Welcome to India Official Room 👋',
      Icons.forum_rounded,
    ),
  ];

  final giftHistory = <DemoGiftHistory>[];

  final conversations = <String, List<String>>{
    '10000000': ['Owner: Welcome to India Official Room 👋'],
    '10000001': ['Admin: Room rules are active.'],
    '10000011': ['Aisha: Hi 👋'],
    '10000012': ['Sam: Music room tonight?'],
  };

  final unreadMessages = <String, int>{
    '10000000': 1,
    '10000011': 1,
  };

  final ownedItems = <String>[
    'Purple Glow',
    'Silver Ring',
    'Royal Mic Badge',
  ];

  DemoUser byName(String name) {
    return users.firstWhere(
      (user) => user.name == name,
      orElse: () => users.first,
    );
  }

  DemoUser byId(String id) {
    return users.firstWhere(
      (user) => user.id == id,
      orElse: () => users.first,
    );
  }

  List<String> conversationFor(String userId) {
    return conversations.putIfAbsent(userId, () => <String>[]);
  }

  void markConversationRead(String userId) {
    unreadMessages[userId] = 0;
    notifyListeners();
  }

  void sendDirectMessage(DemoUser user, String message) {
    final clean = message.trim();
    if (clean.isEmpty) return;
    conversationFor(user.id).add('You: ' + clean);
    inbox.insert(
      0,
      DemoInboxItem(
        user.name,
        'You: ' + clean,
        Icons.forum_rounded,
        unread: false,
      ),
    );
    notifyListeners();
  }

  void followUser(DemoUser user) {
    following.add(user.id);
    addInbox(
      'Following ' + user.name,
      'ID ' + user.id + ' added to local follow list.',
      Icons.person_add_alt_1_rounded,
    );
  }

  void equipFrame(String frame) {
    if (!ownedItems.contains(frame)) ownedItems.add(frame);
    equippedFrame = frame;
    notifyListeners();
  }

  void setVipPreview(int level) {
    activeVip = level.clamp(1, 11);
    notifyListeners();
  }

  void simulateIncomingGift() {
    const incoming = DemoGift('Crown', '👑', 1000);
    diamonds += incoming.coins;
    giftHistory.insert(
      0,
      DemoGiftHistory(
        gift: incoming.emoji + ' ' + incoming.name,
        fromName: 'Aisha',
        fromId: '10000011',
        toName: 'You',
        toId: '10000050',
        coins: incoming.coins,
        diamonds: incoming.coins,
        direction: 'Received',
      ),
    );
    ledger.insert(
      0,
      DemoLedgerEntry(
        'Gift received: Crown',
        'From Aisha • ID 10000011',
        incoming.coins,
      ),
    );
    inbox.insert(
      0,
      DemoInboxItem(
        'Gift received from ID 10000011',
        '👑 Crown • +1,000 Diamond',
        Icons.redeem_rounded,
      ),
    );
    notifyListeners();
  }

  bool sendGift(DemoGift gift, DemoUser recipient, String roomId) {
    if (coins < gift.coins) return false;
    coins -= gift.coins;
    recipient.diamonds += gift.coins;
    final owner = users.first;
    final ownerShare = gift.coins ~/ 10;
    owner.diamonds += ownerShare;
    wealthXp += gift.coins ~/ 100;

    giftHistory.insert(
      0,
      DemoGiftHistory(
        gift: gift.emoji + ' ' + gift.name,
        fromName: 'You',
        fromId: '10000050',
        toName: recipient.name,
        toId: recipient.id,
        coins: gift.coins,
        diamonds: gift.coins,
        direction: 'Sent',
      ),
    );

    ledger.insert(
      0,
      DemoLedgerEntry(
        'Gift sent: ${gift.name}',
        'To ${recipient.name} • ID ${recipient.id} • Room $roomId • Owner share $ownerShare Diamond',
        -gift.coins,
      ),
    );
    inbox.insert(
      0,
      DemoInboxItem(
        'Gift sent to ID ${recipient.id}',
        '${gift.emoji} ${gift.name} • ${gift.coins} Coins • recipient +${gift.coins} Diamond',
        Icons.card_giftcard_rounded,
      ),
    );
    notifyListeners();
    return true;
  }

  bool convertDiamonds(int amount) {
    if (amount <= 0 || amount > diamonds) return false;
    diamonds -= amount;
    final converted = amount ~/ 2;
    coins += converted;
    ledger.insert(
      0,
      DemoLedgerEntry(
        'Diamond converted',
        '$amount Diamond → $converted Coins',
        converted,
      ),
    );
    inbox.insert(
      0,
      DemoInboxItem(
        'Wallet conversion',
        '$amount Diamond converted to $converted Coins',
        Icons.swap_horiz_rounded,
      ),
    );
    notifyListeners();
    return true;
  }

  void addInbox(String title, String subtitle, IconData icon) {
    inbox.insert(0, DemoInboxItem(title, subtitle, icon));
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }
}

final demoEconomy = DemoEconomy();

String demoNumber(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}${buffer.toString()}';
}

class VoiceChatV07 extends StatelessWidget {
  const VoiceChatV07({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Chat v0.7',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF8E35FF),
        scaffoldBackgroundColor: const Color(0xFF120316),
      ),
      home: const MainShellV07(),
    );
  }
}

class MainShellV07 extends StatefulWidget {
  const MainShellV07({super.key});
  @override
  State<MainShellV07> createState() => _MainShellV07State();
}

class _MainShellV07State extends State<MainShellV07> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const V07Home(),
      const DiscoverV06(),
      const MessageHubV07(),
      const ProfileV07(),
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

class DiscoverV06 extends StatelessWidget {
  const DiscoverV06({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('Voice Rooms', Icons.graphic_eq_rounded),
      ('Game Center', Icons.sports_esports_rounded),
      ('Music', Icons.music_note_rounded),
      ('VIP', Icons.workspace_premium_rounded),
      ('Events', Icons.celebration_rounded),
      ('Official', Icons.verified_rounded),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF35105D), Color(0xFF120316)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Discover',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.35,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                for (final item in items)
                  InkWell(
                    onTap: () {
                      if (item.$1 == 'Game Center') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GameLauncherV07(game: 'Ludo'),
                          ),
                        );
                        return;
                      }
                      showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item.$2, size: 46),
                              const SizedBox(height: 10),
                              Text(
                                item.$1,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.$1 == 'Game Center'
                                    ? 'Dice, Lucky Wheel and room games are active local demos.'
                                    : 'This section is active in the v0.7 local demo.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Card(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.$2, size: 38),
                          const SizedBox(height: 8),
                          Text(
                            item.$1,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MessageHubV07 extends StatelessWidget {
  const MessageHubV07({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: demoEconomy,
      builder: (context, _) => DefaultTabController(
        length: 3,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF35105D), Color(0xFF120316)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Chats'),
                    Tab(text: 'Inbox'),
                    Tab(text: 'Gifts'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final user in demoEconomy.users)
                            Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(user.avatar),
                                ),
                                title: Text(user.name),
                                subtitle: Text(
                                  'ID ' +
                                      user.id +
                                      ' • ' +
                                      (demoEconomy.conversationFor(user.id).isEmpty
                                          ? 'No messages yet'
                                          : demoEconomy.conversationFor(user.id).last),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing:
                                    (demoEconomy.unreadMessages[user.id] ?? 0) > 0
                                        ? Badge(
                                            label: Text(
                                              (demoEconomy.unreadMessages[user.id] ?? 0)
                                                  .toString(),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                onTap: () {
                                  demoEconomy.markConversationRead(user.id);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DemoChatV07(user: user),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final item in demoEconomy.inbox)
                            Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(item.icon),
                                ),
                                title: Text(item.title),
                                subtitle: Text(
                                  item.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: item.unread
                                    ? const Badge(label: Text('NEW'))
                                    : null,
                                onTap: () {
                                  item.unread = false;
                                  demoEconomy.refresh();
                                  showModalBottomSheet<void>(
                                    context: context,
                                    showDragHandle: true,
                                    builder: (_) => SafeArea(
                                      child: Padding(
                                        padding: const EdgeInsets.all(18),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(item.icon, size: 42),
                                            const SizedBox(height: 10),
                                            Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              item.subtitle,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      GiftHistoryV07(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GiftHistoryV07 extends StatelessWidget {
  const GiftHistoryV07({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gift History',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: demoEconomy.simulateIncomingGift,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Demo Receive'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (demoEconomy.giftHistory.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No gifts yet'),
                subtitle: Text('Send a gift in a room or use Demo Receive.'),
              ),
            ),
          for (final item in demoEconomy.giftHistory)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    item.direction == 'Sent'
                        ? Icons.north_east_rounded
                        : Icons.south_west_rounded,
                  ),
                ),
                title: Text(item.direction + ' • ' + item.gift),
                subtitle: Text(
                  'From ' +
                      item.fromName +
                      ' (' +
                      item.fromId +
                      ') → ' +
                      item.toName +
                      ' (' +
                      item.toId +
                      ')',
                ),
                trailing: Text(
                  demoNumber(item.coins) + '\nCoins',
                  textAlign: TextAlign.end,
                ),
              ),
            ),
        ],
      );
}

class DemoChatV07 extends StatefulWidget {
  const DemoChatV07({super.key, required this.user});
  final DemoUser user;

  @override
  State<DemoChatV07> createState() => _DemoChatV07State();
}

class _DemoChatV07State extends State<DemoChatV07> {
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    demoEconomy.markConversationRead(widget.user.id);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _send() {
    if (!demoEconomy.allowPrivateMessages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private messages are disabled in Settings')),
      );
      return;
    }
    final value = controller.text.trim();
    if (value.isEmpty) return;
    demoEconomy.sendDirectMessage(widget.user, value);
    controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: demoEconomy,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DemoUserProfileV07(user: widget.user),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(child: Text(widget.user.avatar)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.name),
                    Text(
                      'ID ' + widget.user.id,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  for (final message
                      in demoEconomy.conversationFor(widget.user.id))
                    Align(
                      alignment: message.startsWith('You:')
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(message),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Type message...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded),
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

class V07Home extends StatefulWidget {
  const V07Home({super.key});
  @override
  State<V07Home> createState() => _V07HomeState();
}

class _V07HomeState extends State<V07Home> {
  final rooms = <RoomData>[
    RoomData('India Official Room', '1524843', '👑', false, seatCount: 30, category: 'Official', inviteMode: true),
    RoomData('Night Party', '10000000', '🌙', true, seatCount: 15, category: 'Music', inviteMode: false, pin: '123456'),
  ];

  Future<void> _createRoom() async {
    final room = await showModalBottomSheet<RoomData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CreateRoomV07(),
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
      MaterialPageRoute(builder: (_) => RoomV07(room: room)),
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
                    key: room.id == '1524843' ? const Key('open-v07-room') : null,
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

class CreateRoomV07 extends StatefulWidget {
  const CreateRoomV07({super.key});
  @override
  State<CreateRoomV07> createState() => _CreateRoomV07State();
}

class _CreateRoomV07State extends State<CreateRoomV07> {
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
        const Text('Create Room v0.7', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
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

class RoomV07 extends StatefulWidget {
  const RoomV07({super.key, required this.room});
  final RoomData room;
  @override
  State<RoomV07> createState() => _RoomV07State();
}

class _RoomV07State extends State<RoomV07> {
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
                IconButton(key: const Key('v07-four-box'), onPressed: _openTools, icon: const Icon(Icons.grid_view_rounded)),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Align(alignment: Alignment.centerLeft, child: Text('📢 $notice', maxLines: 1, overflow: TextOverflow.ellipsis))),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: [
                GridView.builder(
                  key: const Key('v07-seat-grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: seats.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, childAspectRatio: .72, crossAxisSpacing: 6, mainAxisSpacing: 6),
                  itemBuilder: (_, i) => GestureDetector(
                    key: i == 0 ? const Key('v07-seat-0') : null,
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
          if (seats[i] != null && seats[i] != 'You')
            Builder(
              builder: (_) {
                final user = demoEconomy.byName(seats[i]!);
                return ListTile(
                  leading: CircleAvatar(child: Text(user.avatar)),
                  title: Text(user.name),
                  subtitle: Text(
                    'ID ${user.id} • ${demoNumber(user.diamonds)} Diamond',
                  ),
                  onTap: () => _openUserProfile(user),
                );
              },
            ),
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
          key: const Key('v07-tools-grid'),
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
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.05,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _GameCard('Dice', Icons.casino_rounded, () => _playGame('Dice')),
            _GameCard('Lucky Wheel', Icons.motion_photos_on_rounded, () => _playGame('Lucky Wheel')),
            _GameCard('Ludo', Icons.grid_view_rounded, () => _openPlayableGame('Ludo')),
            _GameCard('UNO', Icons.style_rounded, () => _openPlayableGame('UNO')),
            _GameCard('Carrom', Icons.sports_esports_rounded, () => _openPlayableGame('Carrom')),
          ],
        ),
      ]),
    )));
  }

  void _openPlayableGame(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameLauncherV07(game: name)),
    );
  }

  void _playGame(String name) {
    final random = Random();
    String result;
    switch (name) {
      case 'Dice':
        result = '${random.nextInt(6) + 1}';
        break;
      case 'Lucky Wheel':
        result = ['10x', '2x', 'Try Again', '5x'][random.nextInt(4)];
        break;
      case 'Ludo':
        result = [
          'Red moved 6',
          'Blue captured a token',
          'Green reached Home',
          'Yellow got another turn',
        ][random.nextInt(4)];
        break;
      case 'UNO':
        result = [
          'Red +2',
          'Skip turn',
          'Wild color changed',
          'UNO! 1 card left',
        ][random.nextInt(4)];
        break;
      case 'Carrom':
        result = [
          'White pocketed',
          'Black pocketed',
          'Queen covered',
          'Foul - turn lost',
        ][random.nextInt(4)];
        break;
      default:
        result = 'Demo result';
    }
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

  Future<void> _gift() async {
    final activeNames = seats
        .whereType<String>()
        .where((name) => name != 'You')
        .toSet()
        .toList();
    if (activeNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recipient is on a seat')),
      );
      return;
    }

    DemoUser recipient = demoEconomy.byName(activeNames.first);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Send Gift',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const Key('gift-recipient-v06'),
                  isExpanded: true,
                  value: recipient.id,
                  decoration: const InputDecoration(
                    labelText: 'Send to user ID',
                    border: OutlineInputBorder(),
                  ),
                  items: activeNames.map((name) {
                    final user = demoEconomy.byName(name);
                    return DropdownMenuItem(
                      value: user.id,
                      child: Text('${user.name} • ID ${user.id}'),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setLocal(() {
                      recipient = demoEconomy.users.firstWhere(
                        (user) => user.id == id,
                      );
                    });
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Your Coins: ${demoNumber(demoEconomy.coins)}'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 410,
                  child: GridView.builder(
                    itemCount: demoEconomy.gifts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: .64,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (_, i) {
                      final gift = demoEconomy.gifts[i];
                      final big = gift.coins >= 100000;
                      return InkWell(
                        key: gift.name == 'Rose'
                            ? const Key('gift-rose-v06')
                            : null,
                        onTap: () async {
                          final ok = demoEconomy.sendGift(
                            gift,
                            recipient,
                            widget.room.id,
                          );
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Not enough Coins')),
                            );
                            return;
                          }
                          setState(() {
                            chat.add(
                              'You sent ${gift.emoji} ${gift.name} to '
                              '${recipient.name} • ID ${recipient.id}',
                            );
                          });
                          Navigator.pop(sheetContext);
                          if (!mounted) return;

                          if (big &&
                              demoEconomy.giftAnimations &&
                              demoEconomy.threeDEffects) {
                            await showDialog<void>(
                              context: this.context,
                              barrierDismissible: false,
                              builder: (dialogContext) => BigGift3DV07(
                                gift: gift,
                                recipient: recipient,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${gift.name} sent to ID ${recipient.id}. '
                                  '+${demoNumber(gift.coins)} Diamond credited.',
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  gift.emoji,
                                  style: TextStyle(fontSize: big ? 36 : 30),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  gift.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  demoNumber(gift.coins),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                if (big)
                                  const Text(
                                    'BIG',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
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
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Members',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            for (final name in members)
              if (name == 'You')
                const ListTile(
                  leading: CircleAvatar(child: Text('😎')),
                  title: Text('You'),
                  subtitle: Text('ID 10000050'),
                )
              else
                Builder(
                  builder: (_) {
                    final user = demoEconomy.byName(name);
                    return ListTile(
                      leading: CircleAvatar(child: Text(user.avatar)),
                      title: Text(user.name),
                      subtitle: Text(
                        'ID ${user.id} • ${demoNumber(user.diamonds)} Diamond',
                      ),
                      trailing: name == 'Owner'
                          ? const Text('Owner')
                          : admins.contains(name)
                              ? const Text('Admin')
                              : null,
                      onTap: () => _openUserProfile(user),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }

  void _openUserProfile(DemoUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DemoUserProfileV07(user: user),
      ),
    );
  }

  void _sendMessage() {
    final c = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          14,
          14,
          MediaQuery.of(sheetContext).viewInsets.bottom + 14,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: c,
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final value = c.text.trim();
                if (value.isNotEmpty) {
                  setState(
                    () => chat.add(
                      'VIP ' +
                          demoEconomy.activeVip.toString() +
                          ' You: ' +
                          value,
                    ),
                  );
                  demoEconomy.addInbox(
                    'Room message',
                    '${widget.room.name}: $value',
                    Icons.chat_bubble_rounded,
                  );
                }
                Navigator.pop(sheetContext);
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    ).whenComplete(c.dispose);
  }
}

class DemoUserProfileV07 extends StatelessWidget {
  const DemoUserProfileV07({super.key, required this.user});
  final DemoUser user;

  Future<void> _gift(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 520,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    CircleAvatar(child: Text(user.avatar)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Gift to ' + user.name + ' • ID ' + user.id,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: demoEconomy.gifts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: .70,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (_, i) {
                    final gift = demoEconomy.gifts[i];
                    return InkWell(
                      onTap: () async {
                        final ok = demoEconomy.sendGift(
                          gift,
                          user,
                          'PROFILE',
                        );
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not enough Coins')),
                          );
                          return;
                        }
                        Navigator.pop(sheetContext);
                        if (gift.coins >= 100000 &&
                            demoEconomy.giftAnimations &&
                            demoEconomy.threeDEffects) {
                          await showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => BigGift3DV07(
                              gift: gift,
                              recipient: user,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                gift.name +
                                    ' sent to ID ' +
                                    user.id +
                                    ' • ' +
                                    demoNumber(gift.coins) +
                                    ' Coins',
                              ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(gift.emoji, style: const TextStyle(fontSize: 34)),
                              const SizedBox(height: 6),
                              Text(
                                gift.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                demoNumber(gift.coins) + ' Coins',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: demoEconomy,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('User Profile')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  child: Text(user.avatar, style: const TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Center(child: Text('ID ' + user.id)),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.diamond_rounded),
                  title: const Text('Diamond'),
                  trailing: Text(demoNumber(user.diamonds)),
                ),
              ),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.workspace_premium_rounded),
                  title: Text('VIP'),
                  trailing: Text('VIP 3'),
                ),
              ),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.bar_chart_rounded),
                  title: Text('Level'),
                  trailing: Text('Lv. 18'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DemoChatV07(user: user),
                        ),
                      ),
                      icon: const Icon(Icons.forum_rounded),
                      label: const Text('Message'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _gift(context),
                      icon: const Icon(Icons.card_giftcard_rounded),
                      label: const Text('Gift'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  demoEconomy.followUser(user);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Following ' + user.name)),
                  );
                },
                icon: Icon(
                  demoEconomy.following.contains(user.id)
                      ? Icons.check_circle_rounded
                      : Icons.person_add_alt_1_rounded,
                ),
                label: Text(
                  demoEconomy.following.contains(user.id)
                      ? 'Following'
                      : 'Follow',
                ),
              ),
            ],
          ),
        ),
      );
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

class BigGift3DV07 extends StatefulWidget {
  const BigGift3DV07({
    super.key,
    required this.gift,
    required this.recipient,
  });

  final DemoGift gift;
  final DemoUser recipient;

  @override
  State<BigGift3DV07> createState() => _BigGift3DV07State();
}

class _BigGift3DV07State extends State<BigGift3DV07>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final turn = (controller.value - .5) * .20;
            final lift = 1 + (controller.value * .05);
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..rotateY(turn)
              ..rotateX(-turn * .35)
              ..scale(lift);
            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: child,
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6F2BFF),
                  Color(0xFF271044),
                  Color(0xFF100416),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFD56A),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 30,
                  spreadRadius: 4,
                  color: Color(0x668E35FF),
                ),
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: 1,
                  color: Color(0x66FFD56A),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '✨ 3D BIG GIFT ✨',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 150,
                      height: 150,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0x88FFD56A),
                              Color(0x338E35FF),
                              Color(0x00100316),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      widget.gift.emoji,
                      style: const TextStyle(fontSize: 92),
                    ),
                  ],
                ),
                Text(
                  widget.gift.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(demoNumber(widget.gift.coins) + ' Coins'),
                const SizedBox(height: 8),
                Text(
                  'To ' + widget.recipient.name + ' • ID ' + widget.recipient.id,
                  textAlign: TextAlign.center,
                ),
                Text(
                  '+' + demoNumber(widget.gift.coins) + ' Diamond credited',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Awesome'),
                ),
              ],
            ),
          ),
        ),
      );
}

List<String> vipPreviewBenefitsV07(int level) {
  final benefits = <String>[
    'VIP profile badge',
    'VIP profile frame preview',
    'VIP chat badge preview',
    'VIP room badge preview',
    'VIP room-entry effect preview',
    'Enhanced profile highlight',
    'Animated profile frame preview',
    'Premium gift-effect preview',
    'Premium 3D aura preview',
    'Elite room-entry preview',
    'Royal VIP11 3D aura and frame preview',
  ];
  return benefits.take(level.clamp(1, benefits.length)).toList();
}

class VipCenterV07 extends StatelessWidget {
  const VipCenterV07({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('VIP Center')),
        body: ListView(
          key: const Key('vip-center-list-v07'),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'VIP 1–11',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Active local VIP: VIP ' + demoEconomy.activeVip.toString(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Local 3D preview. Exact VIP prices/benefit rules will use your final VIP table, not guessed values.',
            ),
            const SizedBox(height: 16),
            for (var level = 1; level <= 11; level++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Vip3DCardV07(level: level),
              ),
          ],
        ),
      );
}

class Vip3DCardV07 extends StatefulWidget {
  const Vip3DCardV07({super.key, required this.level});
  final int level;

  @override
  State<Vip3DCardV07> createState() => _Vip3DCardV07State();
}

class _Vip3DCardV07State extends State<Vip3DCardV07>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + widget.level * 70),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final strength = widget.level >= 9 ? .10 : .065;
          final angle = (controller.value - .5) * strength;
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle)
            ..rotateX(-angle * .45);
          if (!demoEconomy.threeDEffects) return child ?? const SizedBox();
          return Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: child,
          );
        },
        child: InkWell(
          key: widget.level == 11 ? const Key('vip11-3d-v07') : null,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VIP ' + widget.level.toString(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final benefit
                        in vipPreviewBenefitsV07(widget.level))
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.check_circle_outline_rounded,
                        ),
                        title: Text(benefit),
                      ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () {
                        demoEconomy.setVipPreview(widget.level);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'VIP ' +
                                  widget.level.toString() +
                                  ' activated locally',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('Activate Local VIP'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: widget.level >= 9
                    ? const [
                        Color(0xFFFFB84D),
                        Color(0xFF8E35FF),
                        Color(0xFF26113C),
                      ]
                    : const [
                        Color(0xFF5B2387),
                        Color(0xFF2D0B48),
                        Color(0xFF14051B),
                      ],
              ),
              border: Border.all(
                color: widget.level == 11
                    ? const Color(0xFFFFE18A)
                    : const Color(0xFF9A6CC2),
                width: widget.level == 11 ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: widget.level == 11 ? 24 : 10,
                  spreadRadius: widget.level == 11 ? 2 : 0,
                  color: widget.level == 11
                      ? const Color(0x66FFD56A)
                      : const Color(0x448E35FF),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFFFE9A6),
                        Color(0xFFFFB84D),
                        Color(0xFF6F2BFF),
                      ],
                    ),
                  ),
                  child: Text(
                    widget.level.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VIP ' + widget.level.toString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.level == 11
                            ? 'Elite 3D aura + frame preview'
                            : '3D badge + frame preview',
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.view_in_ar_rounded),
              ],
            ),
          ),
        ),
      );
}


class ProfileV07 extends StatelessWidget {
  const ProfileV07({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: demoEconomy,
      builder: (context, _) => Container(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFD56A),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 14,
                          color: Color(0x668E35FF),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 34,
                      child: Text('😎', style: TextStyle(fontSize: 30)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text('ID 10000050'),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Chip(
                              avatar: const Icon(
                                Icons.workspace_premium_rounded,
                                size: 16,
                              ),
                              label: Text(
                                'VIP ' + demoEconomy.activeVip.toString(),
                              ),
                            ),
                            Chip(
                              avatar: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                              ),
                              label: Text(demoEconomy.equippedFrame),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _WalletCard(
                      title: 'Coins',
                      value: demoNumber(demoEconomy.coins),
                      icon: Icons.monetization_on_rounded,
                      onTap: () => _openWallet(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WalletCard(
                      title: 'Diamond',
                      value: demoNumber(demoEconomy.diamonds),
                      icon: Icons.diamond_rounded,
                      onTap: () => _openWallet(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProfileTile(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Wallet',
                subtitle: 'Balances, conversion and transaction history',
                onTap: () => _openWallet(context),
              ),
              _ProfileTile(
                icon: Icons.workspace_premium_rounded,
                title: 'VIP',
                subtitle: 'VIP levels 1–11',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VipCenterV07()),
                ),
              ),
              _ProfileTile(
                icon: Icons.shopping_bag_rounded,
                title: 'Store',
                subtitle: 'Gifts, frames and room cosmetics',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StoreV07()),
                ),
              ),
              _ProfileTile(
                icon: Icons.inventory_2_rounded,
                title: 'Bag',
                subtitle: 'Owned items',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BagV07()),
                ),
              ),
              _ProfileTile(
                icon: Icons.bar_chart_rounded,
                title: 'Level',
                subtitle: 'User and wealth level',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LevelCenterV07()),
                ),
              ),
              _ProfileTile(
                icon: Icons.settings_rounded,
                title: 'Settings',
                subtitle: 'Account and app settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsV07()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWallet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletV06()),
    );
  }

}

class StoreV07 extends StatelessWidget {
  const StoreV07({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: demoEconomy,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Store')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Gift Catalog',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: demoEconomy.gifts.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: .58,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (_, i) {
                  final gift = demoEconomy.gifts[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(gift.emoji, style: const TextStyle(fontSize: 34)),
                          const SizedBox(height: 4),
                          Text(
                            gift.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            demoNumber(gift.coins) + ' Coins',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Cosmetics',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (final frame in const [
                'Purple Glow',
                'Silver Ring',
                'Royal Mic Badge',
                'Golden Crown Frame',
                'Galaxy Aura',
              ])
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome_rounded),
                    title: Text(frame),
                    subtitle: Text(
                      demoEconomy.ownedItems.contains(frame)
                          ? 'Owned • tap to equip'
                          : 'Local demo item • claim free for testing',
                    ),
                    trailing: demoEconomy.equippedFrame == frame
                        ? const Icon(Icons.check_circle_rounded)
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      demoEconomy.equipFrame(frame);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(frame + ' equipped')),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
}

class BagV07 extends StatelessWidget {
  const BagV07({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: demoEconomy,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Bag')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Equipped: ' + demoEconomy.equippedFrame,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in demoEconomy.ownedItems)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_rounded),
                    title: Text(item),
                    trailing: demoEconomy.equippedFrame == item
                        ? const Text('Equipped')
                        : FilledButton(
                            onPressed: () => demoEconomy.equipFrame(item),
                            child: const Text('Equip'),
                          ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class LevelCenterV07 extends StatelessWidget {
  const LevelCenterV07({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: demoEconomy,
      builder: (context, _) {
        final level = 1 + (demoEconomy.wealthXp ~/ 1000);
        final cappedLevel = level > 99 ? 99 : level;
        final progress = (demoEconomy.wealthXp % 1000) / 1000;
        return Scaffold(
          appBar: AppBar(title: const Text('Level Center')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                'User Level',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        child: Text(
                          cappedLevel.toString(),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text(
                        (demoEconomy.wealthXp % 1000).toString() +
                            ' / 1000 XP to next level',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(Icons.graphic_eq_rounded),
                title: Text('Room activity'),
                subtitle: Text('Local level progress from room/gift activity.'),
              ),
              const ListTile(
                leading: Icon(Icons.card_giftcard_rounded),
                title: Text('Wealth XP'),
                subtitle: Text(
                  'Sending gifts increases local demo wealth XP.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SettingsV07 extends StatelessWidget {
  const SettingsV07({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: demoEconomy,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              SwitchListTile(
                title: const Text('3D Effects'),
                subtitle: const Text('VIP cards and premium gift effects'),
                value: demoEconomy.threeDEffects,
                onChanged: (value) {
                  demoEconomy.threeDEffects = value;
                  demoEconomy.refresh();
                },
              ),
              SwitchListTile(
                title: const Text('Gift Animations'),
                value: demoEconomy.giftAnimations,
                onChanged: (value) {
                  demoEconomy.giftAnimations = value;
                  demoEconomy.refresh();
                },
              ),
              SwitchListTile(
                title: const Text('Message Notifications'),
                value: demoEconomy.messageNotifications,
                onChanged: (value) {
                  demoEconomy.messageNotifications = value;
                  demoEconomy.refresh();
                },
              ),
              SwitchListTile(
                title: const Text('Allow Private Messages'),
                value: demoEconomy.allowPrivateMessages,
                onChanged: (value) {
                  demoEconomy.allowPrivateMessages = value;
                  demoEconomy.refresh();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Local Demo Mode'),
                subtitle: const Text(
                  'Backend/database connection will be added later.',
                ),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Voice Chat v0.7',
                  applicationVersion: '0.7.0',
                  children: const [
                    Text(
                      'Local-first build with gift, wallet, room, message, VIP and profile flows.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}


class WalletV06 extends StatefulWidget {
  const WalletV06({super.key});

  @override
  State<WalletV06> createState() => _WalletV06State();
}

class _WalletV06State extends State<WalletV06> {
  final conversion = TextEditingController(text: '1000');

  @override
  void dispose() {
    conversion.dispose();
    super.dispose();
  }

  void _showBalanceInfo(String type, int balance) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                type == 'Coins'
                    ? Icons.monetization_on_rounded
                    : Icons.diamond_rounded,
                size: 46,
              ),
              const SizedBox(height: 10),
              Text(
                type,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text('Current balance: ' + demoNumber(balance)),
              const SizedBox(height: 8),
              Text(
                type == 'Coins'
                    ? 'Coins are used for local gifts and game demos.'
                    : 'Diamond can be converted to Coins at the local 50% demo rate.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _convert() {
    final amount = int.tryParse(conversion.text.trim()) ?? 0;
    if (!demoEconomy.convertDiamonds(amount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Diamond amount')),
      );
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$amount Diamond converted to ${amount ~/ 2} Coins',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: demoEconomy,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Wallet')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _WalletCard(
                    title: 'Coins',
                    value: demoNumber(demoEconomy.coins),
                    icon: Icons.monetization_on_rounded,
                    onTap: () => _showBalanceInfo(
                      'Coins',
                      demoEconomy.coins,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WalletCard(
                    title: 'Diamond',
                    value: demoNumber(demoEconomy.diamonds),
                    icon: Icons.diamond_rounded,
                    onTap: () => _showBalanceInfo(
                      'Diamond',
                      demoEconomy.diamonds,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Diamond → Coins',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text('Conversion rate: 50%'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: conversion,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Diamond amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _convert,
                      child: const Text('Convert'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Gift History')),
                    body: const GiftHistoryV07(),
                  ),
                ),
              ),
              icon: const Icon(Icons.card_giftcard_rounded),
              label: const Text('Open Gift History'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Transaction History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final entry in demoEconomy.ledger)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      entry.amount >= 0
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                    ),
                  ),
                  title: Text(entry.title),
                  subtitle: Text(entry.detail),
                  trailing: Text(
                    '${entry.amount >= 0 ? '+' : ''}${demoNumber(entry.amount)}',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Icon(icon, size: 30),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

class BasicPageV07 extends StatelessWidget {
  const BasicPageV07({
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
