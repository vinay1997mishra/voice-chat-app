import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../core/seat_policy.dart';
import '../ui/royal_theme.dart';
import 'discover_screen.dart';
import 'feature_center_screen.dart';
import 'games_screen.dart';
import 'gifts_screen.dart';
import 'room_screen.dart';
import 'vip_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _tabs = ['Mine', 'Party', 'Events', 'Country'];

  final PageController _pageController = PageController(initialPage: 1);
  int _page = 1;
  bool popular = true;
  String countryFilter = 'IN';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int index) async {
    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> createRoom() async {
    final result = await showModalBottomSheet<_CreateRoomResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (_) => const _CreateRoomSheet(),
    );
    if (!mounted || result == null) return;

    final room = widget.state.discovery.createRoom(
      title: result.title,
      country: result.country,
      seatCount: result.seatCount,
      partyMode: result.partyMode,
    );
    widget.state.discovery.visit(room.id);

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomScreen(state: widget.state, room: room),
      ),
    );

    if (mounted) setState(() {});
  }

  void openRoom(RoomSummary room) {
    widget.state.discovery.visit(room.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(state: widget.state, room: room),
      ),
    );
  }

  void openVip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VipScreen(state: widget.state)),
    );
  }

  void openGames() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GamesScreen(state: widget.state)),
    );
  }

  void openGifts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GiftsScreen(state: widget.state)),
    );
  }

  void openFeatureCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeatureCenterScreen(state: widget.state),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiscoverScreen(state: widget.state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tinni Star ✨',
          style: TextStyle(
            color: RoyalPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('home-vip-button'),
            tooltip: 'VIP',
            onPressed: openVip,
            icon: const Icon(Icons.workspace_premium_rounded),
          ),
          IconButton(
            key: const Key('home-create-room-button'),
            tooltip: 'Create room',
            onPressed: createRoom,
            icon: const Icon(Icons.add_home_rounded),
          ),
          IconButton(
            key: const Key('home-search-button'),
            tooltip: 'Search',
            onPressed: openSearch,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _InteractiveTopTabs(
            labels: _tabs,
            selectedIndex: _page,
            onSelected: _goToPage,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: PageView(
              key: const Key('home-top-page-view'),
              controller: _pageController,
              onPageChanged: (index) => setState(() => _page = index),
              children: [
                _buildMinePage(),
                _buildPartyPage(),
                _buildEventsPage(),
                _buildCountryPage(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _page == 1
          ? FloatingActionButton.extended(
              key: const Key('home-room-fab'),
              onPressed: createRoom,
              backgroundColor: RoyalPalette.gold,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Room',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : null,
    );
  }

  Widget _buildMinePage() {
    final owned = widget.state.discovery.ownedRooms('10000000');
    final myRoom = owned.isEmpty ? null : owned.first;

    final byId = <String, RoomSummary>{
      for (final room in widget.state.discovery.rooms) room.id: room,
    };
    final recent = widget.state.discovery.recentRoomIds
        .map((id) => byId[id])
        .whereType<RoomSummary>()
        .take(4)
        .toList();
    final followings = widget.state.discovery.followedRooms();

    return ListView(
      key: const Key('home-mine-page'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        const GoldSectionTitle('My room'),
        const SizedBox(height: 10),
        if (myRoom == null)
          RoyalPanel(
            key: const Key('mine-create-my-room'),
            onTap: createRoom,
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: RoyalPalette.deepGold,
                  child: Icon(
                    Icons.add_home_rounded,
                    color: Colors.black,
                    size: 30,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create my room',
                        style: TextStyle(
                          color: RoyalPalette.cream,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Your own room will appear here.',
                        style: TextStyle(
                          color: RoyalPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: RoyalPalette.gold,
                ),
              ],
            ),
          )
        else
          _MineRoomCard(
            key: const Key('mine-my-room-card'),
            room: myRoom,
            onTap: () => openRoom(myRoom),
          ),
        const SizedBox(height: 20),
        GoldSectionTitle(
          'Recents',
          trailing: recent.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear recents',
                  onPressed: () {
                    widget.state.discovery.clearRecent();
                    setState(() {});
                  },
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    color: RoyalPalette.gold,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          RoyalPanel(
            onTap: () => _goToPage(1),
            child: const Row(
              children: [
                Icon(Icons.history_rounded, color: RoyalPalette.gold),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No recent rooms yet. Tap to open Party.',
                    style: TextStyle(color: RoyalPalette.cream),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: RoyalPalette.gold,
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final room = recent[index];
                return SizedBox(
                  width: 150,
                  child: _RecentRoomTile(
                    room: room,
                    onTap: () => openRoom(room),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 20),
        const GoldSectionTitle('My followings'),
        const SizedBox(height: 10),
        if (followings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 62,
                  color: RoyalPalette.bronze,
                ),
                SizedBox(height: 12),
                Text(
                  'No following rooms yet',
                  style: TextStyle(
                    color: RoyalPalette.muted,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          )
        else
          ...followings.map(
            (room) => _RoomListCard(
              state: widget.state,
              room: room,
              onTap: () => openRoom(room),
              onFavoriteChanged: () => setState(() {}),
            ),
          ),
      ],
    );
  }

  Widget _buildPartyPage() {
    final ordered = popular
        ? widget.state.discovery.recommend()
        : widget.state.discovery.newRooms();
    final topRooms = ordered.take(3).toList();
    final listRooms = ordered.skip(3).toList();

    return ListView(
      key: const Key('home-party-page'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
      children: [
        RoyalPanel(
          key: const Key('weekly-cp-banner'),
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          onTap: openFeatureCenter,
          gradient: const LinearGradient(
            colors: [Color(0xFF0A0804), Color(0xFF4A2B05), Color(0xFF0A0804)],
          ),
          child: const Row(
            children: [
              Expanded(
                child: Icon(
                  Icons.favorite_rounded,
                  color: RoyalPalette.gold,
                  size: 54,
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Text(
                      'WEEKLY',
                      style: TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                      'CP',
                      style: TextStyle(
                        color: RoyalPalette.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 43,
                      ),
                    ),
                    Text(
                      'Royal Couple Ranking',
                      style: TextStyle(color: RoyalPalette.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Icon(
                  Icons.favorite_rounded,
                  color: RoyalPalette.gold,
                  size: 54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                key: const Key('party-game-button'),
                title: 'Game',
                icon: Icons.casino_rounded,
                onTap: openGames,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FeatureCard(
                key: const Key('party-cp-button'),
                title: 'CP Ranking',
                icon: Icons.favorite_rounded,
                onTap: openFeatureCenter,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FeatureCard(
                key: const Key('party-family-button'),
                title: 'Family',
                icon: Icons.groups_rounded,
                onTap: openFeatureCenter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GoldSectionTitle(
          'Recommended',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChoiceChip(
                key: const Key('party-popular-chip'),
                label: const Text('🔥 Popular'),
                selected: popular,
                onSelected: (_) => setState(() => popular = true),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                key: const Key('party-new-chip'),
                label: const Text('New'),
                selected: !popular,
                onSelected: (_) => setState(() => popular = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < topRooms.length; i++) ...[
              Expanded(
                child: _TopRoomCard(
                  room: topRooms[i],
                  rank: i + 1,
                  onTap: () => openRoom(topRooms[i]),
                ),
              ),
              if (i != topRooms.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ...listRooms.map(
          (room) => _RoomListCard(
            state: widget.state,
            room: room,
            onTap: () => openRoom(room),
            onFavoriteChanged: () => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildEventsPage() {
    final events = [
      (
        'Weekly CP',
        'Couple ranking, intimacy and heartbeat activities',
        Icons.favorite_rounded,
        openFeatureCenter,
      ),
      (
        'Royal Game Night',
        'Lucky 777, Blackjack, Gift Draw and Guessing',
        Icons.casino_rounded,
        openGames,
      ),
      (
        'Gift Festival',
        'Popular, luxury, CP and backpack gift collections',
        Icons.card_giftcard_rounded,
        openGifts,
      ),
      (
        'VIP Celebration',
        'VIP privileges, entry status and royal rewards',
        Icons.workspace_premium_rounded,
        openVip,
      ),
      (
        'Family Party',
        'Family sign-in, contribution and group activities',
        Icons.groups_rounded,
        openFeatureCenter,
      ),
    ];

    return ListView(
      key: const Key('home-events-page'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
      children: [
        RoyalPanel(
          gradient: const LinearGradient(
            colors: [Color(0xFF401E00), Color(0xFF0B0804)],
          ),
          child: const Row(
            children: [
              Icon(
                Icons.celebration_rounded,
                color: RoyalPalette.gold,
                size: 48,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Royal Events',
                      style: TextStyle(
                        color: RoyalPalette.gold,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Swipe left or right to change the main section.',
                      style: TextStyle(color: RoyalPalette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...events.asMap().entries.map(
          (entry) {
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RoyalPanel(
                key: Key('event-card-' + entry.key.toString()),
                onTap: item.$4,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: RoyalPalette.deepGold,
                      child: Icon(item.$3, color: Colors.black),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(
                              color: RoyalPalette.cream,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            item.$2,
                            style: const TextStyle(
                              color: RoyalPalette.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: RoyalPalette.gold,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCountryPage() {
    final countries = const [
      ('IN', '🇮🇳 India'),
      ('US', '🇺🇸 United States'),
      ('VN', '🇻🇳 Vietnam'),
      ('SG', '🇸🇬 Singapore'),
    ];
    final rooms = widget.state.discovery.recommend(country: countryFilter);

    return ListView(
      key: const Key('home-country-page'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
      children: [
        const GoldSectionTitle('Country Rooms'),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: countries.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final country = countries[index];
              return ChoiceChip(
                key: Key('country-' + country.$1),
                label: Text(country.$2),
                selected: countryFilter == country.$1,
                onSelected: (_) {
                  setState(() => countryFilter = country.$1);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          RoyalPanel(
            onTap: openSearch,
            child: const Row(
              children: [
                Icon(Icons.public_off_rounded, color: RoyalPalette.gold),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No rooms for this country yet. Tap to search all rooms.',
                  ),
                ),
              ],
            ),
          )
        else
          ...rooms.map(
            (room) => _RoomListCard(
              state: widget.state,
              room: room,
              onTap: () => openRoom(room),
              onFavoriteChanged: () => setState(() {}),
            ),
          ),
      ],
    );
  }
}

class _MineRoomCard extends StatelessWidget {
  const _MineRoomCard({
    super.key,
    required this.room,
    required this.onTap,
  });

  final RoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF4A3308), Color(0xFF0B0905)],
              ),
              border: Border.all(color: RoyalPalette.gold),
            ),
            child: Text(
              room.title.characters.first.toUpperCase(),
              style: const TextStyle(
                color: RoyalPalette.gold,
                fontSize: 44,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '👤 Tinni User',
                  style: TextStyle(
                    color: RoyalPalette.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '🎙 ' + room.online.toString(),
                style: const TextStyle(
                  color: RoyalPalette.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 28),
              const Icon(
                Icons.chevron_right_rounded,
                color: RoyalPalette.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentRoomTile extends StatelessWidget {
  const _RecentRoomTile({
    required this.room,
    required this.onTap,
  });

  final RoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF382608), Color(0xFF090704)],
                ),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                color: RoyalPalette.gold,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            room.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveTopTabs extends StatelessWidget {
  const _InteractiveTopTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RoyalPalette.black,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                key: Key('top-tab-' + i.toString()),
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: selectedIndex == i
                              ? RoyalPalette.gold
                              : RoyalPalette.muted,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w900
                              : FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 4,
                        width: selectedIndex == i ? 28 : 0,
                        decoration: BoxDecoration(
                          color: RoyalPalette.gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: RoyalPalette.gold, size: 31),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      onTap: onTap,
      gradient: const LinearGradient(
        colors: [Color(0xFF251B08), Color(0xFF0B0905)],
      ),
      child: Column(
        children: [
          Icon(icon, color: RoyalPalette.gold, size: 32),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRoomCard extends StatelessWidget {
  const _TopRoomCard({
    required this.room,
    required this.rank,
    required this.onTap,
  });

  final RoomSummary room;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      key: Key('room-card-' + room.id),
      padding: const EdgeInsets.all(6),
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                height: 106,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: rank == 1
                        ? const [Color(0xFF614000), Color(0xFF130D03)]
                        : const [Color(0xFF292017), Color(0xFF080706)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    rank == 1
                        ? Icons.emoji_events_rounded
                        : Icons.groups_rounded,
                    size: 50,
                    color: RoyalPalette.gold,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -7),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: RoyalPalette.gold,
                  child: Text(
                    rank.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            room.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          Text(
            (room.country == 'IN' ? '🇮🇳  ' : '🌐  ') +
                room.online.toString(),
            style: const TextStyle(
              color: RoyalPalette.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomListCard extends StatelessWidget {
  const _RoomListCard({
    required this.state,
    required this.room,
    required this.onTap,
    required this.onFavoriteChanged,
  });

  final TinniState state;
  final RoomSummary room;
  final VoidCallback onTap;
  final VoidCallback onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    final favorite = state.discovery.favorites.contains(room.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: RoyalPanel(
        padding: const EdgeInsets.all(9),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: RoyalPalette.gold),
                gradient: const LinearGradient(
                  colors: [Color(0xFF31210A), Color(0xFF0A0805)],
                ),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: RoyalPalette.gold,
                size: 34,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RoyalPalette.cream,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    room.partyMode +
                        ' • ' +
                        room.seatCount.toString() +
                        ' seats',
                    style: const TextStyle(
                      color: RoyalPalette.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: RoyalPalette.gold,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'ID ' + room.id,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: () {
                    state.discovery.toggleFavorite(room.id);
                    onFavoriteChanged();
                  },
                  icon: Icon(
                    favorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: RoyalPalette.gold,
                  ),
                ),
                Text(
                  room.online.toString(),
                  style: const TextStyle(
                    color: RoyalPalette.muted,
                    fontSize: 10,
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

class _CreateRoomResult {
  const _CreateRoomResult({
    required this.title,
    required this.country,
    required this.seatCount,
    required this.partyMode,
  });

  final String title;
  final String country;
  final int seatCount;
  final String partyMode;
}

class _CreateRoomSheet extends StatefulWidget {
  const _CreateRoomSheet();

  @override
  State<_CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<_CreateRoomSheet> {
  final TextEditingController titleController = TextEditingController();
  String country = 'IN';
  int seatCount = 12;
  String partyMode = 'Friends-making Party';

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  void submit() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room name is required.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _CreateRoomResult(
        title: title,
        country: country,
        seatCount: seatCount,
        partyMode: partyMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    const seatOptions = supportedSeatCounts;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create room',
              style: TextStyle(
                color: RoyalPalette.gold,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Choose party mode',
              style: TextStyle(
                color: RoyalPalette.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final mode in [
                  'Friends-making Party',
                  'Event hosting mode',
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          mode == 'Friends-making Party'
                              ? 'Friends Party'
                              : 'Event Mode',
                        ),
                        selected: partyMode == mode,
                        onSelected: (_) {
                          setState(() => partyMode = mode);
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('create-room-name'),
              controller: titleController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: const InputDecoration(labelText: 'Room name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('create-room-country'),
              initialValue: country,
              decoration: const InputDecoration(labelText: 'Country'),
              items: const [
                DropdownMenuItem(value: 'IN', child: Text('🇮🇳 India')),
                DropdownMenuItem(
                  value: 'US',
                  child: Text('🇺🇸 United States'),
                ),
                DropdownMenuItem(value: 'VN', child: Text('🇻🇳 Vietnam')),
                DropdownMenuItem(value: 'SG', child: Text('🇸🇬 Singapore')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => country = value);
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Number of mics',
              style: TextStyle(
                color: RoyalPalette.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final count in seatOptions)
                  ChoiceChip(
                    label: Text(count.toString()),
                    selected: seatCount == count,
                    onSelected: (_) => setState(() => seatCount = count),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('create-room-submit'),
                onPressed: submit,
                icon: const Icon(Icons.add_home_rounded),
                label: const Text('Determine & Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
