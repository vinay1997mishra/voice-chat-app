import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'games_v08.dart';
import 'gift_catalog_v08.dart';
import 'gift_effects_v08.dart';
import 'dynamic_gifts_v08.dart';
import 'dynamic_gift_manager_v08.dart';
import 'app_owner_controls_v08.dart';

void main() => runApp(const VoiceChatV08());


class DemoUser {
  DemoUser(this.name, this.id, {this.diamonds = 0, this.avatar = '👤'});
  final String name;
  String id;
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
  String currentUserId = '10000050';
  int coins = 100000000;
  int diamonds = 25000;
  int wealthXp = 1800;
  int activeVip = 3;
  String equippedFrame = 'Purple Glow';
  bool threeDEffects = true;
  bool messageNotifications = true;
  bool giftAnimations = true;
  bool allowPrivateMessages = true;
  final following = <String>{};
  final Map<String, String> userIdAliases = <String, String>{};

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
    DemoLedgerEntry('Opening balance', 'Demo wallet', 100000000),
  ];

  final inbox = <DemoInboxItem>[
    DemoInboxItem(
      'Welcome',
      'v0.8 gift local demo wallet and inbox are ready.',
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
    final resolved = resolveUserId(id);
    return users.firstWhere(
      (user) => user.id == resolved,
      orElse: () => users.first,
    );
  }

  String resolveUserId(String id) {
    var resolved = id.trim();
    final seen = <String>{};
    while (userIdAliases.containsKey(resolved) && seen.add(resolved)) {
      resolved = userIdAliases[resolved]!;
    }
    return resolved;
  }

  DemoUser? findUserByAnyId(String id) {
    final resolved = resolveUserId(id);
    for (final user in users) {
      if (user.id == resolved) return user;
    }
    return null;
  }

  bool matchesCurrentUserId(String id) =>
      resolveUserId(id) == currentUserId;

  bool isHistoricalUserId(String id) =>
      userIdAliases.containsKey(id.trim());

  bool isValidUserId(String value) =>
      RegExp(r'^\d{5,12}$').hasMatch(value.trim());

  bool isUserIdAvailable(String value, {String? exceptId}) {
    final clean = value.trim();
    if (!isValidUserId(clean)) return false;
    if (userIdAliases.containsKey(clean) && clean != exceptId) return false;
    if (currentUserId == clean && exceptId != currentUserId) return false;
    return !users.any((user) => user.id == clean && user.id != exceptId);
  }

  void _rememberUserIdAlias(String oldId, String newId) {
    for (final key in userIdAliases.keys.toList()) {
      if (userIdAliases[key] == oldId) userIdAliases[key] = newId;
    }
    userIdAliases[oldId] = newId;
  }

  bool changeUserId(DemoUser user, String newId) {
    final clean = newId.trim();
    final oldId = user.id;
    if (clean == oldId) return true;
    if (!isUserIdAvailable(clean, exceptId: oldId)) return false;

    _rememberUserIdAlias(oldId, clean);
    user.id = clean;
    _migrateUserIdReferences(oldId, clean);
    _syncOwnedRoomIds(oldId, clean);
    notifyListeners();
    appOwnerControlsV08.refresh();
    return true;
  }

  bool changeCurrentUserId(String newId) {
    final clean = newId.trim();
    final oldId = currentUserId;
    if (clean == oldId) return true;
    if (!isUserIdAvailable(clean, exceptId: oldId)) return false;

    _rememberUserIdAlias(oldId, clean);
    currentUserId = clean;
    _migrateUserIdReferences(oldId, clean);
    _syncOwnedRoomIds(oldId, clean);
    notifyListeners();
    appOwnerControlsV08.refresh();
    return true;
  }

  void _syncOwnedRoomIds(String oldId, String newId) {
    for (final room in roomRegistryV08) {
      if (room.ownerUserId == oldId) {
        room
          ..ownerUserId = newId
          ..id = newId;
      }
    }
  }

  RoomData? findOwnedRoomByAnyUserId(String id) {
    final resolved = resolveUserId(id);
    for (final room in roomRegistryV08) {
      if (room.ownerUserId == resolved || room.id == resolved) return room;
    }
    return null;
  }

  String? matchedAliasFor(String searchedId) {
    final clean = searchedId.trim();
    if (!userIdAliases.containsKey(clean)) return null;
    return clean;
  }

  void _migrateUserIdReferences(String oldId, String newId) {
    final conversation = conversations.remove(oldId);
    if (conversation != null) conversations[newId] = conversation;

    final unread = unreadMessages.remove(oldId);
    if (unread != null) unreadMessages[newId] = unread;

    if (following.remove(oldId)) following.add(newId);

    if (appOwnerControlsV08.globalAdminIds.remove(oldId)) {
      appOwnerControlsV08.globalAdminIds.add(newId);
    }
    if (appOwnerControlsV08.bannedUserIds.remove(oldId)) {
      appOwnerControlsV08.bannedUserIds.add(newId);
    }
    final vip = appOwnerControlsV08.userVipLevels.remove(oldId);
    if (vip != null) appOwnerControlsV08.userVipLevels[newId] = vip;
    appOwnerControlsV08.auditLog.insert(
      0,
      'User ID changed: ' + oldId + ' → ' + newId +
          ' • owned Room ID synced automatically',
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
    if (clean.isEmpty || !appOwnerControlsV08.privateMessagesEnabled) return;
    conversationFor(user.id).add('You: ' + clean);
    if (messageNotifications) inbox.insert(
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
        toId: currentUserId,
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
    if (messageNotifications) inbox.insert(
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
    if (!appOwnerControlsV08.giftsEnabled || coins < gift.coins) return false;
    coins -= gift.coins;
    recipient.diamonds += gift.coins;
    final owner = users.first;
    final ownerShare =
        gift.coins * appOwnerControlsV08.ownerGiftSharePercent ~/ 100;
    owner.diamonds += ownerShare;
    wealthXp += gift.coins ~/ 100;

    giftHistory.insert(
      0,
      DemoGiftHistory(
        gift: gift.emoji + ' ' + gift.name,
        fromName: 'You',
        fromId: currentUserId,
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
    if (messageNotifications) inbox.insert(
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

  bool sendDynamicGiftV08(
    DynamicGiftV08 gift,
    DemoUser recipient,
    String roomId,
  ) {
    if (!appOwnerControlsV08.giftsEnabled ||
        !appOwnerControlsV08.videoGiftsEnabled ||
        coins < gift.coins) {
      return false;
    }
    coins -= gift.coins;
    recipient.diamonds += gift.coins;
    final owner = users.first;
    final ownerShare =
        gift.coins * appOwnerControlsV08.ownerGiftSharePercent ~/ 100;
    owner.diamonds += ownerShare;
    wealthXp += gift.coins ~/ 100;

    giftHistory.insert(
      0,
      DemoGiftHistory(
        gift: '🎬 ' + gift.name,
        fromName: 'You',
        fromId: currentUserId,
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
        'Video gift sent: ' + gift.name,
        'To ' +
            recipient.name +
            ' • ID ' +
            recipient.id +
            ' • Room ' +
            roomId +
            ' • Owner share ' +
            ownerShare.toString() +
            ' Diamond',
        -gift.coins,
      ),
    );
    if (messageNotifications) inbox.insert(
      0,
      DemoInboxItem(
        'Video gift sent to ID ' + recipient.id,
        gift.name +
            ' • ' +
            gift.coins.toString() +
            ' Coins • recipient +' +
            gift.coins.toString() +
            ' Diamond',
        Icons.ondemand_video_rounded,
      ),
    );
    notifyListeners();
    return true;
  }

  bool sendGiftV08(GiftV08 gift, DemoUser recipient, String roomId) {
    if (!appOwnerControlsV08.giftsEnabled || coins < gift.coins) return false;
    coins -= gift.coins;
    recipient.diamonds += gift.coins;
    final owner = users.first;
    final ownerShare =
        gift.coins * appOwnerControlsV08.ownerGiftSharePercent ~/ 100;
    owner.diamonds += ownerShare;
    wealthXp += gift.coins ~/ 100;

    giftHistory.insert(
      0,
      DemoGiftHistory(
        gift: gift.emoji + ' ' + gift.name,
        fromName: 'You',
        fromId: currentUserId,
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
        'Gift sent: ' + gift.name,
        'To ' + recipient.name + ' • ID ' + recipient.id + ' • Room ' + roomId + ' • Owner share ' + ownerShare.toString() + ' Diamond',
        -gift.coins,
      ),
    );
    if (messageNotifications) inbox.insert(
      0,
      DemoInboxItem(
        'Gift sent to ID ' + recipient.id,
        gift.emoji + ' ' + gift.name + ' • ' + gift.coins.toString() + ' Coins • recipient +' + gift.coins.toString() + ' Diamond',
        Icons.card_giftcard_rounded,
      ),
    );
    notifyListeners();
    return true;
  }
  bool convertDiamonds(int amount) {
    if (amount <= 0 || amount > diamonds) return false;
    final converted = amount ~/ appOwnerControlsV08.diamondsPerCoin;
    if (converted <= 0) return false;
    diamonds -= amount;
    coins += converted;
    ledger.insert(
      0,
      DemoLedgerEntry(
        'Diamond converted',
        '$amount Diamond → $converted Coins',
        converted,
      ),
    );
    if (messageNotifications) inbox.insert(
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
    if (messageNotifications) inbox.insert(0, DemoInboxItem(title, subtitle, icon));
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

class VoiceChatV08 extends StatelessWidget {
  const VoiceChatV08({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Chat v0.8',
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
                            builder: (_) => const GamesCenterV08(),
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
                                    : 'This section is active in the v0.8 local demo.',
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
    RoomData(
      'India Official Room',
      '10000000',
      '👑',
      false,
      seatCount: 30,
      category: 'Official',
      inviteMode: true,
      ownerUserId: '10000000',
    ),
    RoomData(
      'Night Party',
      '10000012',
      '🌙',
      true,
      seatCount: 15,
      category: 'Music',
      inviteMode: false,
      pin: '123456',
      ownerUserId: '10000012',
    ),
  ];
  bool _showPopular = false;

  RoomData? get _myRoom {
    for (final room in rooms) {
      if (room.ownedByMe && !room.closed) return room;
    }
    return null;
  }

  Future<void> _createRoom() async {
    if (!appOwnerControlsV08.roomCreationEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room creation is disabled by App Owner')),
      );
      return;
    }
    final existingIndex = rooms.indexWhere((room) => room.ownedByMe);
    if (existingIndex >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already created "${rooms[existingIndex].name}". One user can create only one room.',
          ),
        ),
      );
      return;
    }

    final room = await showModalBottomSheet<RoomData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CreateRoomV07(),
    );
    if (room != null) setState(() => rooms.insert(0, room));
  }

  Future<void> _openRoom(RoomData room) async {
    if (room.locked && !room.ownedByMe) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _RouteTextEditorV08(
          builder: (dialogContext, controller) => AlertDialog(
          title: const Text('Room Password'),
          content: TextField(
            key: const Key('join-room-pin-v06'),
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Room PIN (4–6 digits)',
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
        ),
      );
      if (ok != true || !mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomV07(room: room)),
    );
    if (!mounted) return;
    setState(() {
      if (room.closed && room.ownedByMe) rooms.remove(room);
    });
  }

  Future<void> _searchUserId() async {
    final searchedId = await showDialog<String>(
      context: context,
      builder: (_) => _RouteTextEditorV08(
        builder: (dialogContext, controller) => AlertDialog(
          title: const Text('Search User ID'),
          content: TextField(
            key: const Key('popular-user-id-search-input-v08'),
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 12,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'User ID',
              hintText: 'Enter old or current ID',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('popular-user-id-search-submit-v08'),
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Search'),
            ),
          ],
        ),
      ),
    );

    if (searchedId == null || !mounted) return;
    final resolvedId = demoEconomy.resolveUserId(searchedId);
    final user = demoEconomy.findUserByAnyId(searchedId);
    final isCurrentUser = demoEconomy.matchesCurrentUserId(searchedId);
    final room = demoEconomy.findOwnedRoomByAnyUserId(searchedId);

    if (user == null && !isCurrentUser && room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No user or room found for ID ' + searchedId)),
      );
      return;
    }

    final displayUser = user ??
        DemoUser(
          'You',
          demoEconomy.currentUserId,
          diamonds: demoEconomy.diamonds,
          avatar: '😎',
        );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          key: const Key('popular-id-search-results-v08'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            const Text(
              'Search Result',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              searchedId == resolvedId
                  ? 'ID ' + resolvedId
                  : 'Old ID ' + searchedId + ' → Current ID ' + resolvedId,
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('popular-search-room-result-v08'),
              enabled: room != null,
              leading: const CircleAvatar(
                child: Icon(Icons.meeting_room_rounded),
              ),
              title: const Text('Room'),
              subtitle: Text(
                room == null
                    ? 'This user has no room'
                    : room.name + ' • Room ID ' + room.id,
              ),
              trailing: room == null
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              onTap: room == null
                  ? null
                  : () {
                      Navigator.pop(sheetContext);
                      _openRoom(room);
                    },
            ),
            ListTile(
              key: const Key('popular-search-user-result-v08'),
              leading: CircleAvatar(child: Text(displayUser.avatar)),
              title: const Text('User'),
              subtitle: Text(
                displayUser.name + ' • ID ' + displayUser.id,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserIdLookupV08(
                      user: displayUser,
                      searchedId: searchedId,
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

  @override
  Widget build(BuildContext context) {
    final myRoom = _myRoom;
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
              Row(
                children: [
                  InkWell(
                    key: const Key('home-mine-tab-v08'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _showPopular = false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 8,
                      ),
                      child: Text(
                        'Mine',
                        style: TextStyle(
                          fontSize: _showPopular ? 20 : 28,
                          fontWeight:
                              _showPopular ? FontWeight.w500 : FontWeight.w900,
                          color: _showPopular ? Colors.white60 : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: InkWell(
                      key: const Key('home-popular-tab-v08'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _showPopular = true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 8,
                        ),
                        child: Text(
                          'Popular',
                          style: TextStyle(
                            fontSize: _showPopular ? 28 : 20,
                            fontWeight:
                                _showPopular ? FontWeight.w900 : FontWeight.w500,
                            color: _showPopular ? Colors.white : Colors.white60,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key(
                      _showPopular
                          ? 'popular-user-search-v08'
                          : myRoom == null
                              ? 'create-room-v06'
                              : 'my-room-home-v08',
                    ),
                    tooltip: _showPopular
                        ? 'Search User ID'
                        : myRoom == null
                            ? 'Create Room'
                            : 'Enter My Room',
                    onPressed: _showPopular
                        ? _searchUserId
                        : myRoom == null
                            ? _createRoom
                            : () => _openRoom(myRoom),
                    icon: Icon(
                      _showPopular
                          ? Icons.manage_search_rounded
                          : myRoom == null
                              ? Icons.add_circle_rounded
                              : Icons.home_rounded,
                      size: 30,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: appOwnerControlsV08,
                builder: (context, _) => Card(
                  key: const Key('global-announcement-v08'),
                  child: ListTile(
                    leading: const Icon(Icons.campaign_rounded),
                    title: const Text('Announcement'),
                    subtitle: Text(appOwnerControlsV08.announcement),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_showPopular) ...[
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.search_rounded),
                    title: Text('Search by User ID'),
                    subtitle: Text(
                      'Old ID and current ID both work. Use the search icon above.',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Popular Rooms',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
              ],
              for (final room in rooms)
                Card(
                  child: ListTile(
                    key: room.name == 'India Official Room'
                        ? const Key('open-v07-room')
                        : null,
                    leading: room.dpPath == null
                        ? CircleAvatar(child: Text(room.dp))
                        : CircleAvatar(
                            backgroundImage: FileImage(File(room.dpPath!)),
                          ),
                    title: Text(room.name),
                    subtitle: Text(
                      room.category +
                          ' • ' +
                          room.seatCount.toString() +
                          ' seats • ID ' +
                          room.id +
                          (room.locked ? ' • Locked' : '') +
                          (room.ownedByMe ? ' • My Room' : ''),
                    ),
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

class UserIdLookupV08 extends StatelessWidget {
  const UserIdLookupV08({
    super.key,
    required this.user,
    required this.searchedId,
  });

  final DemoUser user;
  final String searchedId;

  @override
  Widget build(BuildContext context) {
    final currentId = demoEconomy.resolveUserId(searchedId);
    final usedOldId = searchedId != currentId;
    return Scaffold(
      appBar: AppBar(title: const Text('User ID')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              child: Text(user.avatar, style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            key: const Key('searched-user-id-card-v08'),
            child: ListTile(
              leading: const Icon(Icons.badge_rounded),
              title: const Text('User ID'),
              subtitle: Text(
                usedOldId
                    ? 'Current ID ' + currentId + ' • searched with old ID ' + searchedId
                    : currentId,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DemoUserProfileV07(user: user),
                ),
              ),
            ),
          ),
          if (usedOldId)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Old ID remains searchable and always opens the current user.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
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
        const Text('Create Room v0.8', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
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
        if (locked)
          TextField(
            key: const Key('create-room-pin-v08'),
            controller: pin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Room PIN (4–6 digits)',
              border: OutlineInputBorder(),
            ),
          ),
        FilledButton(
          key: const Key('create-room-submit-v06'),
          onPressed: () {
            final cleanPin = pin.text.trim();
            if (locked && !RegExp(r'^\d{4,6}$').hasMatch(cleanPin)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Room PIN must be 4 to 6 digits')),
              );
              return;
            }
            Navigator.pop(
              context,
              RoomData(
                name.text.trim().isEmpty ? 'My Voice Room' : name.text.trim(),
                demoEconomy.currentUserId,
                dp,
                locked,
                seatCount: seats,
                category: category,
                inviteMode: invite,
                pin: locked ? cleanPin : '',
                dpPath: dpPath,
                ownedByMe: true,
                ownerUserId: demoEconomy.currentUserId,
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
  final pendingSeatRequests = <int, String>{};
  late final Set<String> audienceMembers;
  final admins = <String>{'Admin'};
  final blocked = <String>{};
  final List<String> chat = ['System: Welcome to the room', 'Aisha: Hello everyone 👋'];
  late bool inviteMode;
  String notice = 'Welcome! Be respectful and enjoy the room.';
  int? mySeat;
  bool micOn = false;
  int backgroundIndex = 0;
  int _lpRemaining = 0;
  bool _lpClaimed = false;
  final picker = ImagePicker();
  final TextEditingController _roomMessageController = TextEditingController();
  final ScrollController _roomScrollController = ScrollController();
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
    audienceMembers = widget.room.audienceMembers;
    lockedSeats.addAll(widget.room.savedLockedSeats);
    pendingSeatRequests.addAll(widget.room.pendingSeatRequests);
    if (seats.isNotEmpty) {
      seats[0] = 'Owner';
      if (widget.room.ownedByMe) mySeat = 0;
    }
    if (seats.length > 1 &&
        !lockedSeats.contains(1) &&
        !audienceMembers.contains('Admin') &&
        !pendingSeatRequests.containsValue('Admin')) {
      seats[1] = 'Admin';
    }
    if (seats.length > 2 &&
        !lockedSeats.contains(2) &&
        !audienceMembers.contains('Aisha') &&
        !pendingSeatRequests.containsValue('Aisha')) {
      seats[2] = 'Aisha';
      mutedSeats.add(2);
    }
    if (seats.length > 6 &&
        !lockedSeats.contains(6) &&
        !audienceMembers.contains('Sam') &&
        !pendingSeatRequests.containsValue('Sam')) {
      seats[6] = 'Sam';
    }
    for (final i in [8, 14, 24]) {
      if (i < seats.length) {
        lockedSeats.add(i);
        widget.room.savedLockedSeats.add(i);
      }
    }
  }

  @override
  void dispose() {
    _roomMessageController.dispose();
    _roomScrollController.dispose();
    super.dispose();
  }

  bool get _canModerateSeatRequests =>
      widget.room.ownedByMe ||
      widget.room.currentUserIsAdmin ||
      admins.contains('You');

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
                  Text(
                    '${widget.room.category} • ID ${widget.room.id} • ${inviteMode ? 'Invite Mode' : 'Open Seats'}${widget.room.locked ? ' • 🔒 Locked' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ])),
                IconButton(key: const Key('v07-four-box'), onPressed: _openTools, icon: const Icon(Icons.grid_view_rounded)),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Align(alignment: Alignment.centerLeft, child: Text('📢 $notice', maxLines: 1, overflow: TextOverflow.ellipsis))),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                controller: _roomScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                if (_lpRemaining > 0)
                  Card(
                    key: const Key('active-lp-v08'),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.card_giftcard_rounded),
                      ),
                      title: Text('Lucky Bag • $_lpRemaining LP remaining'),
                      subtitle: Text(
                        _lpClaimed
                            ? 'You already claimed this Lucky Bag.'
                            : 'Lucky Bag is live in this room. Tap Claim to open it.',
                      ),
                      trailing: FilledButton(
                        key: const Key('claim-lp-v08'),
                        onPressed: _lpClaimed ? null : _claimLuckyBag,
                        child: const Text('Claim'),
                      ),
                    ),
                  ),
                GridView.builder(
                  key: const Key('v07-seat-grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: seats.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: .82,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemBuilder: (_, i) => GestureDetector(
                    key: i == 0
                        ? const Key('v07-seat-0')
                        : Key('room-seat-$i-v08'),
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
                      Text(
                        seats[i] ??
                            (_canModerateSeatRequests &&
                                    pendingSeatRequests[i] != null
                                ? 'Request: ${pendingSeatRequests[i]}'
                                : 'Seat ${i + 1}'),
                        key: Key('seat-label-$i-v08'),
                        style: const TextStyle(fontSize: 8),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                ),
                if (audienceMembers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    key: const Key('audience-strip-v08'),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Audience',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 62,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final name in audienceMembers)
                                  Builder(
                                    builder: (_) {
                                      final user = name == 'You'
                                          ? null
                                          : demoEconomy.byName(name);
                                      final id = name == 'You'
                                          ? demoEconomy.currentUserId
                                          : user!.id;
                                      final avatar = name == 'You'
                                          ? '🙂'
                                          : user!.avatar;
                                      return Container(
                                        key: Key('audience-id-' + id + '-v08'),
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 17,
                                              child: Text(avatar),
                                            ),
                                            const SizedBox(width: 7),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                Text(
                                                  'ID ' + id,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Room Chat', style: TextStyle(fontWeight: FontWeight.w800)),
                      for (final m in chat.length > 10 ? chat.sublist(chat.length - 10) : chat)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(m),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              color: const Color(0xCC17051F),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('room-message-input-v08'),
                          controller: _roomMessageController,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(
                            hintText: 'Type a room message...',
                            border: OutlineInputBorder(),
                            isDense: false,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const Key('room-message-send-v08'),
                        tooltip: 'Send message',
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
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
                              inviteMode
                                  ? 'Invite request created'
                                  : 'Room link ready to share',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _seatOptions(int i) {
    final isLocked = lockedSeats.contains(i);
    final isMuted = mutedSeats.contains(i);
    final pendingRequester = pendingSeatRequests[i];
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
          if (widget.room.ownedByMe && seats[i] != 'Owner')
            ListTile(
              key: const Key('seat-lock-action-v08'),
              title: Text(isLocked ? 'Unlock Seat' : 'Lock Seat'),
              leading: Icon(isLocked ? Icons.lock_open : Icons.lock),
              onTap: () {
                setState(() {
                  if (isLocked) {
                    lockedSeats.remove(i);
                    widget.room.savedLockedSeats.remove(i);
                  } else {
                    final pending = pendingSeatRequests.remove(i);
                    widget.room.pendingSeatRequests.remove(i);
                    if (pending != null) {
                      audienceMembers.add(pending);
                      chat.add(
                        'System: ' +
                            pending +
                            ' seat request was cancelled because Seat ' +
                            (i + 1).toString() +
                            ' was locked.',
                      );
                    }
                    final occupant = seats[i];
                    if (occupant != null) {
                      audienceMembers.add(occupant);
                      if (occupant == 'You') mySeat = null;
                      seats[i] = null;
                      mutedSeats.remove(i);
                      chat.add(
                        'System: ' +
                            occupant +
                            ' moved to Audience because Seat ' +
                            (i + 1).toString() +
                            ' was locked.',
                      );
                    }
                    lockedSeats.add(i);
                    widget.room.savedLockedSeats.add(i);
                  }
                });
                Navigator.pop(sheetContext);
              },
            ),
          if (_canModerateSeatRequests &&
              !isLocked &&
              seats[i] == null &&
              pendingRequester != null) ...[
            ListTile(
              key: const Key('seat-approve-request-v08'),
              title: Text('Approve ' + pendingRequester),
              subtitle: Text('Allow ' + pendingRequester + ' to join this seat'),
              leading: const Icon(Icons.check_circle_rounded),
              onTap: () {
                _approveSeatRequest(i, pendingRequester);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              key: const Key('seat-reject-request-v08'),
              title: Text('Reject ' + pendingRequester),
              leading: const Icon(Icons.cancel_rounded),
              onTap: () {
                _rejectSeatRequest(i, pendingRequester);
                Navigator.pop(sheetContext);
              },
            ),
          ],
          if (widget.room.ownedByMe)
            ListTile(
              title: Text(isMuted ? 'Unmute Seat' : 'Mute Seat'),
              leading: Icon(isMuted ? Icons.mic : Icons.mic_off),
              onTap: () {
                setState(() => isMuted ? mutedSeats.remove(i) : mutedSeats.add(i));
                Navigator.pop(sheetContext);
              },
            ),
          if (!isLocked && (seats[i] == null || seats[i] == 'You'))
            ListTile(
              key: const Key('seat-join-action-v08'),
              title: Text(
                inviteMode && !_canModerateSeatRequests
                    ? 'Request Seat'
                    : 'Go to Seat',
              ),
              subtitle: inviteMode && !_canModerateSeatRequests
                  ? const Text('Owner or Admin approval required')
                  : null,
              leading: Icon(
                inviteMode && !_canModerateSeatRequests
                    ? Icons.how_to_reg_rounded
                    : Icons.event_seat_rounded,
              ),
              onTap: () {
                if (inviteMode && !_canModerateSeatRequests) {
                  setState(() {
                    pendingSeatRequests.removeWhere(
                      (seat, user) => user == 'You',
                    );
                    widget.room.pendingSeatRequests.removeWhere(
                      (seat, user) => user == 'You',
                    );
                    pendingSeatRequests[i] = 'You';
                    widget.room.pendingSeatRequests[i] = 'You';
                    if (mySeat == null) {
                      audienceMembers.add('You');
                    }
                    chat.add(
                      'System: You requested Seat ' +
                          (i + 1).toString() +
                          '. Waiting for Owner/Admin approval.',
                    );
                  });
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Seat ' +
                            (i + 1).toString() +
                            ' request sent. Waiting for Owner/Admin approval.',
                      ),
                    ),
                  );
                  return;
                }
                setState(() {
                  if (mySeat != null && mySeat != i) {
                    seats[mySeat!] = null;
                    mutedSeats.remove(mySeat!);
                  }
                  seats[i] = 'You';
                  mySeat = i;
                  audienceMembers.remove('You');
                  pendingSeatRequests.removeWhere(
                    (seat, user) => user == 'You',
                  );
                  widget.room.pendingSeatRequests.removeWhere(
                    (seat, user) => user == 'You',
                  );
                });
                Navigator.pop(sheetContext);
              },
            ),
          if (seats[i] == 'You' || (widget.room.ownedByMe && seats[i] != null && seats[i] != 'Owner'))
            ListTile(
              title: const Text('Move to Audience'),
              leading: const Icon(Icons.keyboard_arrow_down_rounded),
              onTap: () {
                setState(() {
                  final occupant = seats[i];
                  if (occupant == 'You') mySeat = null;
                  if (occupant != null) audienceMembers.add(occupant);
                  seats[i] = null;
                });
                Navigator.pop(sheetContext);
              },
            ),
          if (widget.room.ownedByMe && seats[i] != null && seats[i] != 'Owner' && seats[i] != 'You')
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
          if (widget.room.ownedByMe && seats[i] != null && seats[i] != 'Owner' && seats[i] != 'You')
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
          if (widget.room.ownedByMe && seats[i] != null && seats[i] != 'Owner' && seats[i] != 'You')
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
            if (widget.room.ownedByMe)
              _QuickTool(Icons.workspace_premium_rounded, 'Owner', () {
                Navigator.pop(sheetContext);
                _ownerPanel();
              }),
            if (widget.room.ownedByMe)
              _QuickTool(Icons.settings_rounded, 'Settings', () { Navigator.pop(sheetContext); _settings(); }),
            if (widget.room.ownedByMe)
              _QuickTool(Icons.card_giftcard_rounded, 'LP', () { Navigator.pop(sheetContext); _luckyBag(); }),
            _QuickTool(Icons.sports_esports_rounded, 'Game', () { Navigator.pop(sheetContext); _gameCenter(); }),
            if (widget.room.ownedByMe)
              _QuickTool(Icons.wallpaper_rounded, 'Room DP', () { Navigator.pop(sheetContext); _changeRoomDp(); }),
            if (widget.room.ownedByMe)
              _QuickTool(Icons.image_rounded, 'Background', () { Navigator.pop(sheetContext); _backgrounds(); }),
            _QuickTool(Icons.music_note_rounded, 'Music', () { Navigator.pop(sheetContext); _music(); }),
            _QuickTool(Icons.people_alt_rounded, 'Members', () { Navigator.pop(sheetContext); _members(); }),
            if (widget.room.ownedByMe)
              _QuickTool(Icons.admin_panel_settings_rounded, 'Admins', () { Navigator.pop(sheetContext); _admins(); }),
            if (widget.room.ownedByMe)
              _QuickTool(Icons.block_rounded, 'Block', () { Navigator.pop(sheetContext); _blockList(); }),
            _QuickTool(Icons.more_horiz_rounded, 'More', () { Navigator.pop(sheetContext); _more(); }),
          ],
        ),
      ),
    );
  }


  void _approveSeatRequest(int i, String requester) {
    setState(() {
      if (lockedSeats.contains(i) ||
          seats[i] != null ||
          pendingSeatRequests[i] != requester) {
        return;
      }
      final previousSeat = seats.indexOf(requester);
      if (previousSeat >= 0 && previousSeat != i) {
        seats[previousSeat] = null;
        mutedSeats.remove(previousSeat);
      }
      seats[i] = requester;
      if (requester == 'You') {
        mySeat = i;
      }
      audienceMembers.remove(requester);
      pendingSeatRequests.remove(i);
      widget.room.pendingSeatRequests.remove(i);
      chat.add(
        'System: ' +
            requester +
            ' was approved for Seat ' +
            (i + 1).toString() +
            '.',
      );
    });
  }

  void _rejectSeatRequest(int i, String requester) {
    setState(() {
      if (pendingSeatRequests[i] != requester) return;
      pendingSeatRequests.remove(i);
      widget.room.pendingSeatRequests.remove(i);
      audienceMembers.add(requester);
      chat.add(
        'System: ' +
            requester +
            ' seat request for Seat ' +
            (i + 1).toString() +
            ' was rejected.',
      );
    });
  }

  void _ownerPanel() {
    if (!widget.room.ownedByMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the room owner can open Owner Panel')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .88,
            child: ListView(
              key: const Key('owner-panel-v08'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                const Text(
                  'Room Owner Panel',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(widget.room.name + ' • ID ' + widget.room.id),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(
                        widget.room.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 18,
                      ),
                      label: Text(widget.room.locked ? 'Locked' : 'Open'),
                    ),
                    Chip(label: Text(widget.room.category)),
                    Chip(label: Text(widget.room.seatCount.toString() + ' seats')),
                    Chip(label: Text(inviteMode ? 'Invite Mode' : 'Open Seats')),
                  ],
                ),
                const Divider(height: 28),
                const Text(
                  'Room Controls',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                ListTile(
                  key: const Key('owner-edit-name-v08'),
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Room Name'),
                  subtitle: Text(widget.room.name),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editRoomName();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Invite Mode'),
                  subtitle: const Text('Control whether seats need an invite'),
                  value: inviteMode,
                  onChanged: (value) {
                    setState(() {
                      inviteMode = value;
                      widget.room.inviteMode = value;
                    });
                    setLocal(() {});
                  },
                ),
                ListTile(
                  key: const Key('owner-room-lock-v08'),
                  leading: Icon(widget.room.locked ? Icons.lock_reset_rounded : Icons.lock_rounded),
                  title: Text(widget.room.locked ? 'Change Room PIN' : 'Lock Room'),
                  subtitle: Text(
                    widget.room.locked
                        ? 'Owner never needs the PIN to enter or unlock'
                        : 'Set any 4–6 digit numeric PIN',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editPassword(forceEnable: true);
                  },
                ),
                if (widget.room.locked)
                  ListTile(
                    key: const Key('owner-remove-lock-v08'),
                    leading: const Icon(Icons.lock_open_rounded),
                    title: const Text('Remove Room Lock'),
                    subtitle: const Text('No PIN required for the owner'),
                    onTap: () {
                      setState(() {
                        widget.room.locked = false;
                        widget.room.pin = '';
                      });
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Room lock removed')),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.campaign_rounded),
                  title: const Text('Edit Room Notice'),
                  subtitle: Text(notice),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editNotice();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.category_rounded),
                  title: const Text('Room Category'),
                  subtitle: Text(widget.room.category),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editRoomCategory();
                  },
                ),
                const Divider(height: 28),
                const Text(
                  'People & Moderation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                ListTile(
                  leading: const Icon(Icons.people_alt_rounded),
                  title: const Text('Members'),
                  subtitle: Text(seats.whereType<String>().length.toString() + ' user(s) on seats'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _members();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_rounded),
                  title: const Text('Admins'),
                  subtitle: Text(admins.length.toString() + ' admin(s)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _admins();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_rounded),
                  title: const Text('Block List'),
                  subtitle: Text(blocked.length.toString() + ' blocked user(s)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _blockList();
                  },
                ),
                ListTile(
                  key: const Key('owner-unlock-seats-v08'),
                  leading: const Icon(Icons.event_seat_rounded),
                  title: const Text('Unlock All Seats'),
                  subtitle: Text(lockedSeats.length.toString() + ' seat(s) locked'),
                  onTap: () {
                    setState(() => lockedSeats.clear());
                    setLocal(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.mic_off_rounded),
                  title: const Text('Mute All Guests'),
                  subtitle: const Text('Owner/Admin seats stay unchanged'),
                  onTap: () {
                    setState(() {
                      for (var i = 0; i < seats.length; i++) {
                        final name = seats[i];
                        if (name != null &&
                            name != 'Owner' &&
                            name != 'Admin' &&
                            i != mySeat) {
                          mutedSeats.add(i);
                        }
                      }
                    });
                    setLocal(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded),
                  title: const Text('Clear Room Chat'),
                  onTap: () {
                    setState(() {
                      chat
                        ..clear()
                        ..add('System: Room chat was cleared by the owner');
                    });
                    setLocal(() {});
                  },
                ),
                const Divider(height: 28),
                const Text(
                  'Room Experience',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                ListTile(
                  leading: const Icon(Icons.card_giftcard_rounded),
                  title: const Text('Lucky Bag (LP)'),
                  subtitle: Text(
                    _lpRemaining > 0
                        ? _lpRemaining.toString() + ' LP active'
                        : 'Create a Lucky Bag',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _luckyBag();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wallpaper_rounded),
                  title: const Text('Room DP'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _changeRoomDp();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_rounded),
                  title: const Text('Background'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _backgrounds();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.music_note_rounded),
                  title: const Text('Music'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _music();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sports_esports_rounded),
                  title: const Text('Game Center'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _gameCenter();
                  },
                ),
                ListTile(
                  key: const Key('owner-video-gifts-v08'),
                  leading: const Icon(Icons.video_collection_rounded),
                  title: const Text('Video Gifts'),
                  subtitle: Text(
                    demoEconomy.activeVip >= 8
                        ? 'Add/manage 8-sec room gift videos'
                        : 'VIP8+ required to add room gift videos',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openRoomVideoGiftManager();
                  },
                ),
                const Divider(height: 28),
                const Text(
                  'AI Assistant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                ListTile(
                  key: const Key('ai-gift-assistant-v08'),
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: const Text('AI Gift Assistant'),
                  subtitle: const Text(
                    'Suggest a recipient + gift. Sending always asks for confirmation.',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _aiGiftAssistant();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRoomVideoGiftManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DynamicGiftManagerV08(
          title: 'Room Video Gifts',
          vipLevel: demoEconomy.activeVip,
          isAppOwner: false,
          roomId: widget.room.id,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _editRoomName() {
    showDialog<void>(
      context: context,
      builder: (_) => _RouteTextEditorV08(
        initialText: widget.room.name,
        builder: (dialogContext, controller) => AlertDialog(
          title: const Text('Edit Room Name'),
          content: TextField(
            key: const Key('owner-room-name-input-v08'),
            controller: controller,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Room name',
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
                final value = controller.text.trim();
                if (value.isEmpty) return;
                setState(() => widget.room.name = value);
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _editRoomCategory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Room Category',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            for (final category in const ['Friends', 'Music', 'Game', 'Official'])
              RadioListTile<String>(
                value: category,
                groupValue: widget.room.category,
                title: Text(category),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => widget.room.category = value);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _settings() {
    if (!widget.room.ownedByMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the room owner can change room settings')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
          const Text('Room Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          SwitchListTile(
            title: const Text('Invite Mode'),
            value: inviteMode,
            onChanged: (v) {
              setState(() {
                inviteMode = v;
                widget.room.inviteMode = v;
              });
              setLocal(() {});
            },
          ),
          SwitchListTile(
            key: const Key('room-lock-switch-v08'),
            title: const Text('Room Lock'),
            subtitle: Text(
              widget.room.locked
                  ? 'Locked • Owner entry does not need PIN'
                  : 'Set any 4–6 digit PIN',
            ),
            value: widget.room.locked,
            onChanged: (value) async {
              if (!value) {
                setState(() {
                  widget.room.locked = false;
                  widget.room.pin = '';
                });
                setLocal(() {});
                return;
              }
              await _editPassword(forceEnable: true);
              if (mounted) setLocal(() {});
            },
          ),
          ListTile(
            title: const Text('Edit Room Notice'),
            subtitle: Text(notice),
            trailing: const Icon(Icons.edit_rounded),
            onTap: _editNotice,
          ),
          if (widget.room.locked)
            ListTile(
              title: const Text('Change Room PIN'),
              subtitle: const Text('Update the 4–6 digit room PIN'),
              trailing: const Icon(Icons.password_rounded),
              onTap: _editPassword,
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editNotice() {
    showDialog<void>(context: context, builder: (_) => _RouteTextEditorV08(
      initialText: notice,
      builder: (dialogContext, c) => AlertDialog(
      title: const Text('Edit Room Notice'),
      content: TextField(controller: c),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { setState(() => notice = c.text.trim().isEmpty ? notice : c.text.trim()); Navigator.pop(dialogContext); }, child: const Text('Save'))],
    )));
  }

  void _luckyBag() {
    if (!widget.room.ownedByMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the room owner can create Lucky Bags')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => _RouteTextEditorV08(
        initialText: '6000',
        builder: (dialogContext, amount) => AlertDialog(
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
              setState(() {
                _lpRemaining = value;
                _lpClaimed = false;
                chat.add('System: Lucky Bag $value LP created');
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Create LP'),
          ),
        ],
      ),
      ),
    );
  }

  void _claimLuckyBag() {
    if (_lpRemaining <= 0 || _lpClaimed) return;
    var reward = _lpRemaining ~/ 10;
    if (reward < 100) reward = 100;
    if (reward > 1000) reward = 1000;
    if (reward > _lpRemaining) reward = _lpRemaining;
    setState(() {
      _lpRemaining -= reward;
      _lpClaimed = true;
      chat.add('You claimed $reward LP from Lucky Bag 🎁');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You claimed $reward LP')),
    );
  }

  List<GameVoicePlayerV08> _gameVoicePlayers() {
    final result = <GameVoicePlayerV08>[];
    for (var i = 0; i < seats.length && result.length < 4; i++) {
      final name = seats[i];
      if (name == null) continue;
      if (name == 'You') {
        result.add(
          GameVoicePlayerV08(
            name: 'You',
            avatar: '🙂',
            userId: demoEconomy.currentUserId,
            micOn: !mutedSeats.contains(i),
          ),
        );
        continue;
      }
      final user = demoEconomy.byName(name);
      result.add(
        GameVoicePlayerV08(
          name: name,
          avatar: user.avatar,
          userId: user.id,
          micOn: !mutedSeats.contains(i),
        ),
      );
    }
    return result;
  }

  void _gameCenter() {
    if (!appOwnerControlsV08.gamesEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game Center is disabled by App Owner')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamesCenterV08(players: _gameVoicePlayers()),
      ),
    );
  }

  Future<void> _changeRoomDp() async {
    if (!widget.room.ownedByMe) return;
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
    if (!widget.room.ownedByMe) return;
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
    if (!widget.room.ownedByMe) return;
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
    if (!widget.room.ownedByMe) return;
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
    if (!appOwnerControlsV08.giftsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gift sending is disabled by App Owner')),
      );
      return;
    }
    final activeNames = <String>{
      ...seats.whereType<String>(),
      ...audienceMembers,
    }
        .where((name) => name != 'You' && !blocked.contains(name))
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
        builder: (context, setLocal) {
          Widget giftGrid(List<GiftV08> gifts) {
            return GridView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 14),
              itemCount: gifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: .66,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, index) {
                final gift = gifts[index];
                final displayEmoji = gift.countryCode == null
                    ? gift.emoji
                    : flagEmojiV08(gift.countryCode!);
                return InkWell(
                  key: gift.name == 'Tiny Rose'
                      ? const Key('gift-tiny-rose-v08')
                      : gift.name == 'Eagles King'
                          ? const Key('gift-eagles-king-v08')
                          : null,
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final ok = demoEconomy.sendGiftV08(
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
                        'You sent ' + displayEmoji + ' ' + gift.name +
                            ' to ' + recipient.name + ' • ID ' + recipient.id,
                      );
                    });
                    Navigator.pop(sheetContext);
                    if (!mounted) return;

                    if (demoEconomy.giftAnimations && demoEconomy.threeDEffects) {
                      await GiftEffectV08.show(
                        this.context,
                        gift,
                        sender: 'You',
                        receiver: recipient.name + ' • ID ' + recipient.id,
                      );
                    } else {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            gift.name + ' sent to ID ' + recipient.id +
                                '. +' + demoNumber(gift.coins) +
                                ' Diamond credited.',
                          ),
                        ),
                      );
                    }
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(displayEmoji, style: const TextStyle(fontSize: 33)),
                          const SizedBox(height: 5),
                          Text(
                            gift.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatGiftCoinsV08(gift.coins) + ' Coins',
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(height: 3),
                          Icon(
                            iconForGiftTierV08(gift.animationTier),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }

          Widget dynamicGiftList() {
            if (!appOwnerControlsV08.videoGiftsEnabled) {
              return const Center(
                child: Text('Room video gifts are disabled by App Owner'),
              );
            }
            final gifts = dynamicGiftStoreV08.activeForRoom(
              widget.room.id,
              DateTime.now(),
            );
            if (gifts.isEmpty) {
              return const Center(
                child: Text('No active room video gifts'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 14),
              itemCount: gifts.length,
              itemBuilder: (_, index) {
                final gift = gifts[index];
                return Card(
                  child: ListTile(
                    key: ValueKey('send-dynamic-gift-' + gift.id),
                    leading: const CircleAvatar(
                      child: Icon(Icons.ondemand_video_rounded),
                    ),
                    title: Text(gift.name),
                    subtitle: Text(
                      formatGiftCoinsV08(gift.coins) +
                          ' Coins • ' +
                          gift.lease.label +
                          ' • ' +
                          gift.durationLabel,
                    ),
                    trailing: const Icon(Icons.send_rounded),
                    onTap: gift.localFileExists
                        ? () async {
                            final ok = demoEconomy.sendDynamicGiftV08(
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
                                'You sent video gift ' +
                                    gift.name +
                                    ' to ' +
                                    recipient.name +
                                    ' • ID ' +
                                    recipient.id,
                              );
                            });
                            Navigator.pop(sheetContext);
                            if (!mounted) return;
                            await DynamicGiftVideoEffectV08.show(
                              this.context,
                              gift,
                            );
                          }
                        : null,
                  ),
                );
              },
            );
          }

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .84,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      const Text(
                        'v0.8 Gift Center',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select receiver • swipe for more',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          key: const Key('gift-recipient-v08'),
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          itemCount: activeNames.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, index) {
                            final user = demoEconomy.byName(activeNames[index]);
                            final selected = recipient.id == user.id;
                            return GestureDetector(
                              key: ValueKey('gift-recipient-' + user.id + '-v08'),
                              onTap: () {
                                setLocal(() => recipient = user);
                              },
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: selected ? 1 : .38,
                                child: SizedBox(
                                  width: 68,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: selected
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFFD54F),
                                                    Color(0xFFFF5EC4),
                                                    Color(0xFF7B61FF),
                                                  ],
                                                )
                                              : null,
                                          border: selected
                                              ? null
                                              : Border.all(
                                                  color: Colors.white24,
                                                  width: 1,
                                                ),
                                          boxShadow: selected
                                              ? const [
                                                  BoxShadow(
                                                    color: Color(0x887B61FF),
                                                    blurRadius: 12,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: CircleAvatar(
                                          radius: selected ? 26 : 24,
                                          backgroundColor: const Color(0xFF2C1640),
                                          child: Text(
                                            user.avatar,
                                            style: TextStyle(
                                              fontSize: selected ? 28 : 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: selected
                                              ? FontWeight.w900
                                              : FontWeight.w600,
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'To: ' + recipient.name + ' • ID ' + recipient.id,
                          key: const Key('gift-selected-recipient-v08'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Your Coins: ' + demoNumber(demoEconomy.coins),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const TabBar(
                        isScrollable: true,
                        tabs: [
                          Tab(text: 'Normal'),
                          Tab(text: 'CP Couple'),
                          Tab(text: 'Flags'),
                          Tab(text: 'Room Videos'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            giftGrid(normalGiftsV08),
                            giftGrid(coupleGiftsV08),
                            giftGrid(flagGiftsV08),
                            dynamicGiftList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  GiftV08? _recommendedGiftV08() {
    final affordable = normalGiftsV08
        .where((gift) => gift.coins <= demoEconomy.coins)
        .toList()
      ..sort((a, b) => a.coins.compareTo(b.coins));
    if (affordable.isEmpty) return null;

    final softBudget = demoEconomy.coins ~/ 100;
    GiftV08 pick = affordable.first;
    for (final gift in affordable) {
      if (gift.coins <= softBudget) pick = gift;
    }
    return pick;
  }

  void _aiGiftAssistant() {
    final names = seats
        .whereType<String>()
        .where((name) => name != 'You' && name != 'Owner')
        .toSet()
        .toList();
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Gift Assistant needs another user in the room')),
      );
      return;
    }

    DemoUser recipient = demoEconomy.byName(names.first);
    GiftV08? recommendation = _recommendedGiftV08();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'AI Gift Assistant',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'v0.8 uses local smart recommendations. A real AI model can replace this later through the backend.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: const Key('ai-gift-recipient-v08'),
                  value: recipient.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Recipient',
                    border: OutlineInputBorder(),
                  ),
                  items: names.map((name) {
                    final user = demoEconomy.byName(name);
                    return DropdownMenuItem(
                      value: user.id,
                      child: Text(user.name + ' • ID ' + user.id),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setLocal(() {
                      recipient = demoEconomy.users.firstWhere((user) => user.id == id);
                      recommendation = _recommendedGiftV08();
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (recommendation == null)
                  const ListTile(
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('No affordable gift available'),
                  )
                else
                  Card(
                    child: ListTile(
                      leading: Text(
                        recommendation!.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                      title: Text('Suggested: ' + recommendation!.name),
                      subtitle: Text(
                        formatGiftCoinsV08(recommendation!.coins) +
                            ' Coins • for ' +
                            recipient.name,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('ai-gift-send-v08'),
                  onPressed: recommendation == null
                      ? null
                      : () async {
                          final gift = recommendation!;
                          final confirmed = await showDialog<bool>(
                            context: sheetContext,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Confirm AI Gift'),
                              content: Text(
                                'Send ' +
                                    gift.name +
                                    ' to ' +
                                    recipient.name +
                                    ' for ' +
                                    formatGiftCoinsV08(gift.coins) +
                                    ' Coins?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  key: const Key('confirm-ai-gift-v08'),
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('Send Gift'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !mounted) return;

                          final ok = demoEconomy.sendGiftV08(
                            gift,
                            recipient,
                            widget.room.id,
                          );
                          if (!ok) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Not enough Coins')),
                            );
                            return;
                          }

                          setState(() {
                            chat.add(
                              'AI Gift Assistant: You sent ' +
                                  gift.emoji +
                                  ' ' +
                                  gift.name +
                                  ' to ' +
                                  recipient.name,
                            );
                          });
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text(gift.name + ' sent to ' + recipient.name)),
                          );
                        },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Send Suggested Gift'),
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

  Future<void> _editPassword({bool forceEnable = false}) async {
    if (!widget.room.ownedByMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the room owner can change the PIN')),
      );
      return;
    }

    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RouteTextEditorV08(
        initialText: widget.room.pin,
        builder: (dialogContext, controller) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: Text(widget.room.locked ? 'Change Room PIN' : 'Set Room Lock'),
            content: TextField(
              key: const Key('room-pin-input-v08'),
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Room PIN',
                helperText: 'Enter any 4 to 6 digits',
                errorText: errorText,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('set-room-lock-v08'),
                onPressed: () {
                  final value = controller.text.trim();
                  if (!RegExp(r'^\d{4,6}$').hasMatch(value)) {
                    setLocal(() => errorText = 'PIN must be 4 to 6 digits');
                    return;
                  }
                  Navigator.pop(dialogContext, value);
                },
                child: Text(widget.room.locked ? 'Save PIN' : 'Set Lock'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      widget.room.locked = true;
      widget.room.pin = result;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room lock enabled')),
    );
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
                ListTile(
                  leading: const CircleAvatar(child: Text('😎')),
                  title: const Text('You'),
                  subtitle: Text('ID ' + demoEconomy.currentUserId),
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
    final value = _roomMessageController.text.trim();
    if (value.isEmpty) return;

    setState(() => chat.add('You: $value'));
    _roomMessageController.clear();
    demoEconomy.addInbox(
      'Room message',
      '${widget.room.name}: $value',
      Icons.chat_bubble_rounded,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_roomScrollController.hasClients) return;
      _roomScrollController.animateTo(
        _roomScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
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


final Set<RoomData> roomRegistryV08 = <RoomData>{};

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
    this.ownedByMe = false,
    this.currentUserIsAdmin = false,
    this.closed = false,
    String? ownerUserId,
  }) : ownerUserId = ownerUserId ?? id {
    roomRegistryV08.add(this);
  }

  String name;
  String id;
  String ownerUserId;
  String dp;
  bool locked;
  int seatCount;
  String category;
  bool inviteMode;
  String pin;
  String? dpPath;
  bool ownedByMe;
  final bool currentUserIsAdmin;
  bool closed;
  final Set<int> savedLockedSeats = <int>{};
  final Set<String> audienceMembers = <String>{};
  final Map<int, String> pendingSeatRequests = <int, String>{};
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
                        Text('ID ' + demoEconomy.currentUserId),
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
                icon: Icons.admin_panel_settings_rounded,
                title: 'Main Owner Panel',
                subtitle: 'Global gift videos and app-owner controls',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MainOwnerPanelV08(),
                  ),
                ),
              ),
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

class MainOwnerPanelV08 extends StatelessWidget {
  const MainOwnerPanelV08({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appOwnerControlsV08,
        builder: (context, _) {
          final activeVideoGifts = dynamicGiftStoreV08.gifts
              .where((gift) => gift.activeAt(DateTime.now()))
              .length;
          return Scaffold(
            appBar: AppBar(title: const Text('Main Owner / Admin Panel')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  key: const Key('main-owner-dashboard-v08'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(child: Icon(Icons.shield_rounded)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'App Owner Control Center',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: Icon(
                                appOwnerControlsV08.maintenanceMode
                                    ? Icons.build_circle_rounded
                                    : Icons.check_circle_rounded,
                                size: 17,
                              ),
                              label: Text(
                                appOwnerControlsV08.maintenanceMode
                                    ? 'Maintenance'
                                    : 'App Live',
                              ),
                            ),
                            Chip(
                              label: Text(
                                appOwnerControlsV08.globalAdminIds.length
                                        .toString() +
                                    ' Admin',
                              ),
                            ),
                            Chip(
                              label: Text(
                                appOwnerControlsV08.bannedUserIds.length
                                        .toString() +
                                    ' Banned',
                              ),
                            ),
                            Chip(
                              label: Text(
                                activeVideoGifts.toString() + ' Video Gifts',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const _OwnerSectionTitleV08('Communication & People'),
                _OwnerPanelTileV08(
                  key: const Key('owner-global-announcement-v08'),
                  icon: Icons.campaign_rounded,
                  title: 'Global Announcement',
                  subtitle: appOwnerControlsV08.announcement,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OwnerAnnouncementV08(),
                    ),
                  ),
                ),
                _OwnerPanelTileV08(
                  key: const Key('owner-users-roles-v08'),
                  icon: Icons.manage_accounts_rounded,
                  title: 'Users, Admins & VIP',
                  subtitle:
                      'Admin role, VIP 0–11, global ban/unban and user status',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OwnerUsersRolesV08(),
                    ),
                  ),
                ),
                _OwnerPanelTileV08(
                  key: const Key('owner-moderation-v08'),
                  icon: Icons.gavel_rounded,
                  title: 'Moderation & Reports',
                  subtitle: appOwnerControlsV08.openReports.length.toString() +
                      ' open report(s) • global ban controls',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OwnerModerationV08(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const _OwnerSectionTitleV08('App Controls'),
                _OwnerPanelTileV08(
                  key: const Key('owner-feature-controls-v08'),
                  icon: Icons.tune_rounded,
                  title: 'Feature Controls',
                  subtitle:
                      'Maintenance, rooms, gifts, video gifts, 3D, animations and DMs',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OwnerFeatureControlsV08(),
                    ),
                  ),
                ),
                _OwnerPanelTileV08(
                  key: const Key('owner-game-controls-v08'),
                  icon: Icons.sports_esports_rounded,
                  title: 'Game Controls',
                  subtitle:
                      'Master switch + Ludo, UNO, Carrom, Dice and Wheel',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OwnerGameControlsV08(),
                    ),
                  ),
                ),
                _OwnerPanelTileV08(
                  key: const Key('owner-economy-controls-v08'),
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Economy Controls',
                  subtitle: 'Gift owner share ' +
                      appOwnerControlsV08.ownerGiftSharePercent.toString() +
                      '% • ' +
                      appOwnerControlsV08.diamondsPerCoin.toString() +
                      ':1 Diamond conversion',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OwnerEconomyControlsV08(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const _OwnerSectionTitleV08('Gifts & Content'),
                _OwnerPanelTileV08(
                  key: const Key('main-owner-video-gifts-v08'),
                  icon: Icons.video_collection_rounded,
                  title: 'Global Video Gifts',
                  subtitle: activeVideoGifts.toString() +
                      ' active • add / disable / preview / remove videos',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DynamicGiftManagerV08(
                        title: 'Main Owner • Video Gifts',
                        vipLevel: 11,
                        isAppOwner: true,
                      ),
                    ),
                  ),
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.rule_rounded),
                    title: Text('Video Gift Limits'),
                    subtitle: Text(
                      'Maximum 8 seconds and 12 MB. App Owner can set 15d, 1m, 3m, 6m or Lifetime.',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const _OwnerSectionTitleV08('Security & Logs'),
                _OwnerPanelTileV08(
                  key: const Key('owner-audit-log-v08'),
                  icon: Icons.history_rounded,
                  title: 'Owner Activity Log',
                  subtitle: appOwnerControlsV08.auditLog.length.toString() +
                      ' recorded owner action(s)',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OwnerAuditLogV08(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _OwnerSectionTitleV08 extends StatelessWidget {
  const _OwnerSectionTitleV08(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      );
}

class _OwnerPanelTileV08 extends StatelessWidget {
  const _OwnerPanelTileV08({
    super.key,
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

class OwnerFeatureControlsV08 extends StatelessWidget {
  const OwnerFeatureControlsV08({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appOwnerControlsV08,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Feature Controls')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                key: const Key('owner-maintenance-toggle-v08'),
                title: const Text('Maintenance Mode'),
                subtitle: const Text('Global maintenance state for normal users'),
                value: appOwnerControlsV08.maintenanceMode,
                onChanged: appOwnerControlsV08.setMaintenance,
              ),
              SwitchListTile(
                key: const Key('owner-room-create-toggle-v08'),
                title: const Text('Allow Room Creation'),
                value: appOwnerControlsV08.roomCreationEnabled,
                onChanged: appOwnerControlsV08.setRoomCreation,
              ),
              SwitchListTile(
                key: const Key('owner-gifts-toggle-v08'),
                title: const Text('Gift Sending'),
                value: appOwnerControlsV08.giftsEnabled,
                onChanged: appOwnerControlsV08.setGifts,
              ),
              SwitchListTile(
                key: const Key('owner-video-gifts-toggle-v08'),
                title: const Text('Room Video Gifts'),
                value: appOwnerControlsV08.videoGiftsEnabled,
                onChanged: appOwnerControlsV08.setVideoGifts,
              ),
              SwitchListTile(
                key: const Key('owner-3d-toggle-v08'),
                title: const Text('3D Gift Effects'),
                value: appOwnerControlsV08.threeDEffectsEnabled,
                onChanged: (value) {
                  appOwnerControlsV08.setThreeDEffects(value);
                  demoEconomy.threeDEffects = value;
                  demoEconomy.refresh();
                },
              ),
              SwitchListTile(
                key: const Key('owner-gift-animation-toggle-v08'),
                title: const Text('Gift Animations'),
                value: appOwnerControlsV08.giftAnimationsEnabled,
                onChanged: (value) {
                  appOwnerControlsV08.setGiftAnimations(value);
                  demoEconomy.giftAnimations = value;
                  demoEconomy.refresh();
                },
              ),
              SwitchListTile(
                key: const Key('owner-private-message-toggle-v08'),
                title: const Text('Private Messages'),
                value: appOwnerControlsV08.privateMessagesEnabled,
                onChanged: (value) {
                  appOwnerControlsV08.setPrivateMessages(value);
                  demoEconomy.allowPrivateMessages = value;
                  demoEconomy.refresh();
                },
              ),
            ],
          ),
        ),
      );
}

class OwnerGameControlsV08 extends StatelessWidget {
  const OwnerGameControlsV08({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appOwnerControlsV08,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Game Controls')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                key: const Key('owner-games-master-toggle-v08'),
                title: const Text('Game Center'),
                subtitle: const Text('Master switch for all games'),
                value: appOwnerControlsV08.gamesEnabled,
                onChanged: appOwnerControlsV08.setGames,
              ),
              const Divider(),
              _OwnerGameSwitchV08(
                game: 'Ludo',
                value: appOwnerControlsV08.ludoEnabled,
              ),
              _OwnerGameSwitchV08(
                game: 'UNO',
                value: appOwnerControlsV08.unoEnabled,
              ),
              _OwnerGameSwitchV08(
                game: 'Carrom',
                value: appOwnerControlsV08.carromEnabled,
              ),
              _OwnerGameSwitchV08(
                game: 'Lucky Dice',
                value: appOwnerControlsV08.luckyDiceEnabled,
              ),
              _OwnerGameSwitchV08(
                game: 'Lucky Wheel',
                value: appOwnerControlsV08.luckyWheelEnabled,
              ),
            ],
          ),
        ),
      );
}

class _OwnerGameSwitchV08 extends StatelessWidget {
  const _OwnerGameSwitchV08({required this.game, required this.value});
  final String game;
  final bool value;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        key: Key(
          'owner-game-' + game.toLowerCase().replaceAll(' ', '-') + '-v08',
        ),
        title: Text(game),
        value: value,
        onChanged: appOwnerControlsV08.gamesEnabled
            ? (enabled) => appOwnerControlsV08.setGame(game, enabled)
            : null,
      );
}

class OwnerUsersRolesV08 extends StatelessWidget {
  const OwnerUsersRolesV08({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([appOwnerControlsV08, demoEconomy]),
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Users, Admins & VIP')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded),
                  title: const Text('Main App Owner'),
                  subtitle: Text(
                    'ID ' +
                        demoEconomy.currentUserId +
                        ' • fixed owner role • Room ID stays synced',
                  ),
                  trailing: TextButton(
                    key: const Key('owner-edit-current-user-id-v08'),
                    onPressed: () => _editCurrentUserId(context),
                    child: const Text('Edit ID'),
                  ),
                ),
              ),
              for (final user in demoEconomy.users)
                Card(
                  key: Key('owner-user-' + user.id + '-v08'),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(child: Text(user.avatar)),
                        title: Text(user.name),
                        subtitle: Text(
                          'ID ' +
                              user.id +
                              ' • ' +
                              demoNumber(user.diamonds) +
                              ' Diamond',
                        ),
                        trailing: TextButton(
                          key: Key('owner-edit-user-id-' + user.id + '-v08'),
                          onPressed: () => _editUserId(context, user),
                          child: const Text('Edit ID'),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Global Admin'),
                        value:
                            appOwnerControlsV08.globalAdminIds.contains(user.id),
                        onChanged:
                            appOwnerControlsV08.bannedUserIds.contains(user.id)
                                ? null
                                : (value) =>
                                    appOwnerControlsV08.setAdmin(user.id, value),
                      ),
                      SwitchListTile(
                        title: const Text('Global Ban'),
                        value:
                            appOwnerControlsV08.bannedUserIds.contains(user.id),
                        onChanged: (value) =>
                            appOwnerControlsV08.setBanned(user.id, value),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'VIP Level',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            DropdownButton<int>(
                              key: Key('owner-vip-' + user.id + '-v08'),
                              value:
                                  appOwnerControlsV08.userVipLevels[user.id] ?? 0,
                              items: List.generate(
                                12,
                                (level) => DropdownMenuItem(
                                  value: level,
                                  child: Text('VIP ' + level.toString()),
                                ),
                              ),
                              onChanged: (value) {
                                if (value != null) {
                                  appOwnerControlsV08.setVip(user.id, value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  Future<void> _editCurrentUserId(BuildContext context) async {
    final currentId = demoEconomy.currentUserId;
    final newId = await _requestId(
      context,
      title: 'Change Main Owner User ID',
      currentId: currentId,
    );
    if (newId == null || !context.mounted) return;
    final ok = demoEconomy.changeCurrentUserId(newId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'User ID and owned Room ID changed to ' + newId
              : 'ID must be unique and contain 5–12 digits',
        ),
      ),
    );
  }

  Future<void> _editUserId(BuildContext context, DemoUser user) async {
    final currentId = user.id;
    final newId = await _requestId(
      context,
      title: 'Change ' + user.name + ' User ID',
      currentId: currentId,
    );
    if (newId == null || !context.mounted) return;
    final ok = demoEconomy.changeUserId(user, newId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? user.name +
                  ' User ID changed to ' +
                  newId +
                  '. Owned Room ID synced automatically.'
              : 'ID must be unique and contain 5–12 digits',
        ),
      ),
    );
  }

  Future<String?> _requestId(
    BuildContext context, {
    required String title,
    required String currentId,
  }) {
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (_) => _RouteTextEditorV08(
        initialText: currentId,
        builder: (dialogContext, controller) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: Text(title),
            content: TextField(
              key: const Key('owner-user-id-input-v08'),
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: 'New User ID',
                helperText: '5–12 digits • must be unique',
                errorText: errorText,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('owner-save-user-id-v08'),
                onPressed: () {
                  final value = controller.text.trim();
                  if (!demoEconomy.isValidUserId(value) ||
                      !demoEconomy.isUserIdAvailable(
                        value,
                        exceptId: currentId,
                      )) {
                    setLocal(
                      () => errorText =
                          'Use a unique numeric ID with 5–12 digits',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, value);
                },
                child: const Text('Save ID'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OwnerModerationV08 extends StatelessWidget {
  const OwnerModerationV08({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appOwnerControlsV08,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Moderation & Reports')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Open Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (appOwnerControlsV08.openReports.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.check_circle_rounded),
                    title: Text('No open reports'),
                  ),
                ),
              for (final report
                  in List<String>.from(appOwnerControlsV08.openReports))
                Card(
                  child: ListTile(
                    title: Text(report),
                    trailing: TextButton(
                      onPressed: () =>
                          appOwnerControlsV08.resolveReport(report),
                      child: const Text('Resolve'),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const Text(
                'Global Bans',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (appOwnerControlsV08.bannedUserIds.isEmpty)
                const Card(
                  child: ListTile(title: Text('No globally banned users')),
                ),
              for (final userId in appOwnerControlsV08.bannedUserIds)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.block_rounded),
                    title: Text('ID ' + userId),
                    trailing: TextButton(
                      onPressed: () =>
                          appOwnerControlsV08.setBanned(userId, false),
                      child: const Text('Unban'),
                    ),
                  ),
                ),
              if (appOwnerControlsV08.bannedUserIds.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: appOwnerControlsV08.clearBans,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Clear All Bans'),
                ),
            ],
          ),
        ),
      );
}

class OwnerEconomyControlsV08 extends StatelessWidget {
  const OwnerEconomyControlsV08({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appOwnerControlsV08,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Economy Controls')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room Owner Gift Share: ' +
                            appOwnerControlsV08.ownerGiftSharePercent.toString() +
                            '%',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Slider(
                        key: const Key('owner-gift-share-slider-v08'),
                        min: 0,
                        max: 30,
                        divisions: 30,
                        value: appOwnerControlsV08.ownerGiftSharePercent
                            .toDouble(),
                        label:
                            appOwnerControlsV08.ownerGiftSharePercent.toString() +
                                '%',
                        onChanged: (value) => appOwnerControlsV08
                            .setOwnerGiftSharePercent(value.round()),
                      ),
                      const Text(
                        'Applied to local v0.8 gift settlement calculation.',
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Diamond → Coin Conversion'),
                  subtitle: Text(
                    appOwnerControlsV08.diamondsPerCoin.toString() +
                        ' Diamond = 1 Coin',
                  ),
                  trailing: DropdownButton<int>(
                    key: const Key('owner-diamond-rate-v08'),
                    value: appOwnerControlsV08.diamondsPerCoin,
                    items: const [1, 2, 5, 10]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.toString() + ':1'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        appOwnerControlsV08.setDiamondsPerCoin(value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class OwnerAnnouncementV08 extends StatefulWidget {
  const OwnerAnnouncementV08({super.key});

  @override
  State<OwnerAnnouncementV08> createState() => _OwnerAnnouncementV08State();
}

class _OwnerAnnouncementV08State extends State<OwnerAnnouncementV08> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: appOwnerControlsV08.announcement);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Global Announcement')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('owner-announcement-input-v08'),
              controller: controller,
              minLines: 3,
              maxLines: 6,
              maxLength: 180,
              decoration: const InputDecoration(
                labelText: 'Announcement',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('owner-announcement-save-v08'),
              onPressed: () {
                appOwnerControlsV08.setAnnouncement(controller.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Global announcement updated')),
                );
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Publish Announcement'),
            ),
          ],
        ),
      );
}

class OwnerAuditLogV08 extends StatelessWidget {
  const OwnerAuditLogV08({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appOwnerControlsV08,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Owner Activity Log')),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appOwnerControlsV08.auditLog.length,
            itemBuilder: (_, index) => Card(
              child: ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(appOwnerControlsV08.auditLog[index]),
              ),
            ),
          ),
        ),
      );
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
                  applicationName: 'Voice Chat v0.8',
                  applicationVersion: '0.8.0',
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

  
// The editor owns its controller for the entire route lifetime, including the
// reverse animation. A Navigator pop future completes before route disposal.
class _RouteTextEditorV08 extends StatefulWidget {
  const _RouteTextEditorV08({this.initialText = '', required this.builder});
  final String initialText;
  final Widget Function(BuildContext, TextEditingController) builder;

  @override
  State<_RouteTextEditorV08> createState() => _RouteTextEditorV08State();
}

class _RouteTextEditorV08State extends State<_RouteTextEditorV08> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, controller);
}
