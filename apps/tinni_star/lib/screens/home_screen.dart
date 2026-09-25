import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../core/seat_policy.dart';
import '../ui/royal_theme.dart';
import 'cp_ranking_screen.dart';
import 'discover_screen.dart';
import 'feature_center_screen.dart';
import 'family_ranking_screen.dart';
import 'gifts_screen.dart';
import 'ranking_screen.dart';
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
  Timer? _roomSyncTimer;
  int _page = 1;
  bool popular = true;
  String countryFilter = '';
  String countryFilterLabel = '';

  @override
  void initState() {
    super.initState();
    final account = widget.state.auth.current;
    countryFilter = account?.countryCode ?? '';
    countryFilterLabel = account == null
        ? 'Select country'
        : account.flagEmoji + ' ' + account.countryName;
    _syncRooms();
    _roomSyncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _syncRooms(),
    );
  }

  Future<void> _syncRooms() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      await widget.state.discovery.syncRooms(account.authToken);
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the last real server snapshot while reconnecting.
    }
  }

  @override
  void dispose() {
    _roomSyncTimer?.cancel();
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
    final account = widget.state.auth.current;
    if (account == null) return;

    final existing = widget.state.discovery.ownedRooms(account.userId);
    if (existing.isNotEmpty) {
      openRoom(existing.first);
      return;
    }

    final result = await showModalBottomSheet<_CreateRoomResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (_) => const _CreateRoomSheet(),
    );
    if (!mounted || result == null) return;

    try {
      final room = await widget.state.discovery.createRoomRemote(
        authToken: account.authToken,
        title: result.title,
        seatCount: result.seatCount,
        partyMode: result.partyMode,
        photoDataUrl: result.photoDataUrl,
      );
      widget.state.discovery.visit(room.id);

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomScreen(state: widget.state, room: room),
        ),
      );

      await _syncRooms();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
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

  Future<void> openRankings({int initialTab = 1}) async {
    final room = await Navigator.push<RoomSummary>(
      context,
      MaterialPageRoute(
        builder: (_) => RankingScreen(
          state: widget.state,
          initialTab: initialTab,
        ),
      ),
    );
    if (!mounted || room == null) return;
    openRoom(room);
  }

  void openCpRanking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CpRankingScreen(state: widget.state),
      ),
    );
  }

  void openFamilyRanking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyRankingScreen(state: widget.state),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _InteractiveTopTabs(
                    labels: _tabs,
                    selectedIndex: _page,
                    onSelected: _goToPage,
                  ),
                ),
                IconButton(
                  key: const Key('home-ranking-button'),
                  tooltip: 'Rankings',
                  onPressed: () => openRankings(initialTab: 1),
                  icon: const Icon(
                    Icons.leaderboard_rounded,
                    color: RoyalPalette.gold,
                  ),
                ),
                IconButton(
                  key: const Key('home-search-button'),
                  tooltip: 'Search',
                  onPressed: openSearch,
                  icon: const Icon(
                    Icons.search_rounded,
                    color: RoyalPalette.gold,
                  ),
                ),
              ],
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
      ),
    );
  }

  Widget _buildMinePage() {
    final currentUserId = widget.state.auth.current?.userId ?? '';
    final owned = widget.state.discovery.ownedRooms(currentUserId);
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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        SizedBox(
          key: const Key('party-promo-carousel'),
          height: 156,
          child: PageView(
            children: [
              _PartyPromoCard(
                title: 'WEEKLY STAR',
                subtitle: 'Weekly rankings and royal rewards',
                icon: Icons.workspace_premium_rounded,
                onTap: () => openRankings(initialTab: 1),
              ),
              _PartyPromoCard(
                title: 'ROYAL PARTY',
                subtitle: 'Live rooms, rankings and party events',
                icon: Icons.mic_external_on_rounded,
                onTap: () => openRankings(initialTab: 0),
              ),
              _PartyPromoCard(
                title: 'THE GREAT NAVIGATOR',
                subtitle: 'Featured seasonal event',
                icon: Icons.explore_rounded,
                onTap: openFeatureCenter,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                key: const Key('party-room-rank-button'),
                title: 'Room',
                icon: Icons.mic_external_on_rounded,
                onTap: () => openRankings(initialTab: 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FeatureCard(
                key: const Key('party-cp-button'),
                title: 'CP Ranking',
                icon: Icons.favorite_rounded,
                onTap: openCpRanking,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FeatureCard(
                key: const Key('party-family-button'),
                title: 'Family',
                icon: Icons.groups_rounded,
                onTap: openFamilyRanking,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
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

  void _pickCountryRoomFilter() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      useSafeArea: true,
      onSelect: (country) {
        setState(() {
          countryFilter = country.countryCode;
          countryFilterLabel = country.flagEmoji + ' ' + country.name;
        });
      },
    );
  }

  Widget _buildCountryPage() {
    final rooms = countryFilter.isEmpty
        ? widget.state.discovery.recommend()
        : widget.state.discovery.recommend(country: countryFilter);

    return ListView(
      key: const Key('home-country-page'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
      children: [
        const GoldSectionTitle('Country Rooms'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('all-country-room-filter'),
                onPressed: _pickCountryRoomFilter,
                icon: const Icon(Icons.public_rounded),
                label: Text(countryFilterLabel),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'All countries',
              onPressed: () {
                setState(() {
                  countryFilter = '';
                  countryFilterLabel = '🌍 All countries';
                });
              },
              icon: const Icon(
                Icons.language_rounded,
                color: RoyalPalette.gold,
              ),
            ),
          ],
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
                    'No real rooms for this country yet.',
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
  }}

class _RoomArtwork extends StatelessWidget {
  const _RoomArtwork({
    required this.room,
    required this.width,
    required this.height,
    this.icon,
    this.fallback,
  });

  final RoomSummary room;
  final double width;
  final double height;
  final IconData? icon;
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    final path = room.photoPath;
    final remotePhoto = room.photoDataUrl;
    final hasRemotePhoto =
        remotePhoto != null && remotePhoto.startsWith('data:image/');
    final hasLocalPhoto =
        path != null && path.isNotEmpty && File(path).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: RoyalPalette.gold),
          gradient: const LinearGradient(
            colors: [Color(0xFF382608), Color(0xFF090704)],
          ),
        ),
        child: hasRemotePhoto
            ? SizedBox.expand(
                child: Image.memory(
                  base64Decode(remotePhoto.split(',').last),
                  fit: BoxFit.cover,
                ),
              )
            : hasLocalPhoto
                ? SizedBox.expand(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                    ),
                  )
                : fallback != null
                ? Text(
                    fallback!,
                    style: const TextStyle(
                      color: RoyalPalette.gold,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : Icon(
                    icon ?? Icons.graphic_eq_rounded,
                    color: RoyalPalette.gold,
                    size: 34,
                  ),
      ),
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
          _RoomArtwork(
            room: room,
            width: 88,
            height: 88,
            fallback: room.title.characters.first.toUpperCase(),
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
                Text(
                  '👤 ' +
                      (room.ownerFlagEmoji ?? '') +
                      ((room.ownerFlagEmoji ?? '').isEmpty ? '' : ' ') +
                      (room.ownerName ?? room.ownerId ?? ''),
                  style: const TextStyle(
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
            child: _RoomArtwork(
              room: room,
              width: double.infinity,
              height: double.infinity,
              icon: Icons.graphic_eq_rounded,
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

class _PartyPromoCard extends StatelessWidget {
  const _PartyPromoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: RoyalPanel(
        onTap: onTap,
        radius: 22,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF090603),
            Color(0xFF6A3900),
            Color(0xFF120A03),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 37,
              backgroundColor: RoyalPalette.deepGold,
              child: Icon(
                icon,
                color: Colors.black,
                size: 38,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    style: const TextStyle(
                      color: RoyalPalette.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: RoyalPalette.cream,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Swipe for more',
                    style: TextStyle(
                      color: RoyalPalette.muted,
                      fontSize: 10,
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
            _RoomArtwork(
              room: room,
              width: 74,
              height: 74,
              icon: Icons.graphic_eq_rounded,
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
    required this.seatCount,
    required this.partyMode,
    this.photoDataUrl,
  });

  final String title;
  final int seatCount;
  final String partyMode;
  final String? photoDataUrl;
}

class _CreateRoomSheet extends StatefulWidget {
  const _CreateRoomSheet();

  @override
  State<_CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<_CreateRoomSheet> {
  final TextEditingController titleController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  int seatCount = 12;
  String partyMode = 'Friends-making Party';
  String? photoDataUrl;

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
        seatCount: seatCount,
        partyMode: partyMode,
        photoDataUrl: photoDataUrl,
      ),
    );
  }

  Future<void> _chooseRoomPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              key: const Key('create-room-photo-gallery'),
              leading: const Icon(Icons.photo_library_rounded, color: RoyalPalette.gold),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              key: const Key('create-room-photo-camera'),
              leading: const Icon(Icons.photo_camera_rounded, color: RoyalPalette.gold),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 65,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 320000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a smaller room photo.')),
      );
      return;
    }
    setState(() {
      photoDataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
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
            Center(
              child: InkWell(
                key: const Key('create-room-photo-button'),
                onTap: _chooseRoomPhoto,
                borderRadius: BorderRadius.circular(48),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: RoyalPalette.panel2,
                      child: Icon(
                        photoDataUrl == null
                            ? Icons.add_a_photo_rounded
                            : Icons.check_circle_rounded,
                        color: RoyalPalette.gold,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      photoDataUrl == null ? 'Add room photo' : 'Room photo selected',
                      style: const TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Tap to choose Gallery or Camera',
                      style: TextStyle(color: RoyalPalette.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
