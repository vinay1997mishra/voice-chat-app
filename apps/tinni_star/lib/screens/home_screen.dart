import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../infra/app_backend_service.dart';
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

Color _homeFeatureColor(String title) {
  final value = title.toLowerCase();
  if (value.contains('cp') || value.contains('heart')) {
    return FeaturePalette.cp;
  }
  if (value.contains('vip') || value.contains('noble')) {
    return FeaturePalette.vip;
  }
  if (value.contains('gift')) return FeaturePalette.gift;
  if (value.contains('family')) return FeaturePalette.family;
  if (value.contains('game')) return FeaturePalette.games;
  if (value.contains('music') || value.contains('ktv')) {
    return FeaturePalette.music;
  }
  if (value.contains('wallet') || value.contains('recharge')) {
    return FeaturePalette.wallet;
  }
  if (value.contains('rank') || value.contains('royal')) {
    return FeaturePalette.rank;
  }
  if (value.contains('event') || value.contains('party')) {
    return FeaturePalette.fruitParty;
  }
  return FeaturePalette.social;
}


String _compactNumber(int value) {
  if (value >= 1000000000) {
    return (value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1) + 'B';
  }
  if (value >= 1000000) {
    return (value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1) + 'M';
  }
  if (value >= 1000) {
    return (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1) + 'K';
  }
  return value.toString();
}

ImageProvider? _homeAvatarProvider(String? value) {
  final source = value?.trim() ?? '';
  if (source.isEmpty) return null;
  if (source.startsWith('data:image/')) {
    try {
      return MemoryImage(base64Decode(source.split(',').last));
    } catch (_) {
      return null;
    }
  }
  if (source.startsWith('https://') || source.startsWith('http://')) {
    return NetworkImage(source);
  }
  return null;
}

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
  Timer? _partyRankTimer;
  final List<Map<String, dynamic>> _cpTop = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _familyTop = <Map<String, dynamic>>[];
  int _page = 1;
  bool popular = true;
  String countryFilter = '';
  String countryFilterLabel = '';
  final List<RemoteNotification> _notifications = <RemoteNotification>[];
  bool _notificationsInitialized = false;
  bool _notificationVoice = true;
  bool _notificationVibration = true;
  bool _roomFloatingOnly = false;

  @override
  void initState() {
    super.initState();
    final account = widget.state.auth.current;
    countryFilter = account?.countryCode ?? '';
    countryFilterLabel = account == null
        ? 'Select country'
        : account.flagEmoji + ' ' + account.countryName;
    _syncRooms();
    _syncPartyRankPreviews();
    _syncNotifications();
    _roomSyncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        _syncRooms();
        _syncNotifications();
      },
    );
    _partyRankTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _syncPartyRankPreviews(),
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

  Future<void> _syncPartyRankPreviews() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final results = await Future.wait<dynamic>([
        widget.state.backend.cpRanking(account.authToken, limit: 3),
        widget.state.backend.familyList(account.authToken, limit: 3),
      ]);
      if (!mounted) return;
      setState(() {
        _cpTop
          ..clear()
          ..addAll(
            List<Map<String, dynamic>>.from(results[0] as List),
          );
        _familyTop
          ..clear()
          ..addAll(
            List<Map<String, dynamic>>.from(results[1] as List),
          );
      });
    } catch (_) {
      // Keep the last successful podium preview while reconnecting.
    }
  }

  Future<void> _syncNotifications() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final results = await Future.wait<dynamic>([
        widget.state.backend.notifications(account.authToken),
        widget.state.backend.accountPreferences(account.authToken),
      ]);
      final values = List<RemoteNotification>.from(results[0] as List);
      final preferences =
          Map<String, dynamic>.from(results[1] as Map);

      final previousIds = _notifications.map((item) => item.id).toSet();
      final newlyArrived = _notificationsInitialized
          ? values
              .where((item) => !item.read && !previousIds.contains(item.id))
              .toList(growable: false)
          : const <RemoteNotification>[];

      _notificationVoice = preferences['message_voice'] != false;
      _notificationVibration =
          preferences['message_vibration'] != false;
      _roomFloatingOnly = preferences['room_floating_only'] == true;

      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(values);
        _notificationsInitialized = true;
      });

      if (newlyArrived.isNotEmpty) {
        if (_notificationVoice) {
          await SystemSound.play(SystemSoundType.alert);
        }
        if (_notificationVibration) {
          await HapticFeedback.mediumImpact();
        }
        final canFloat =
            !_roomFloatingOnly || widget.state.roomSession.hasRoom;
        if (canFloat && mounted) {
          final notice = newlyArrived.first;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(notice.title + ': ' + notice.message),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: _showNotifications,
                ),
              ),
            );
        }
      }
    } catch (_) {
      // Keep the last notification snapshot while reconnecting.
    }
  }

  Future<void> _showNotifications() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    await _syncNotifications();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      color: RoyalPalette.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(color: RoyalPalette.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final notice = _notifications[index];
                          return RoyalPanel(
                            accentColor: notice.read
                                ? RoyalPalette.muted
                                : FeaturePalette.message,
                            onTap: () async {
                              if (!notice.read) {
                                await widget.state.backend.markNotificationRead(
                                  account.authToken,
                                  notice.id,
                                );
                                await _syncNotifications();
                              }
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ShiningIcon(
                                icon: notice.type.contains('call')
                                    ? Icons.call_rounded
                                    : notice.type.contains('message')
                                        ? Icons.message_rounded
                                        : notice.type.contains('coins') ||
                                                notice.type.contains('commission')
                                            ? Icons.account_balance_wallet_rounded
                                            : notice.type.contains('online')
                                                ? Icons.circle_notifications_rounded
                                                : Icons.notifications_rounded,
                                color: notice.read
                                    ? RoyalPalette.muted
                                    : FeaturePalette.message,
                                size: 20,
                                boxSize: 38,
                                glow: notice.read ? 0.12 : 0.32,
                              ),
                              title: Text(
                                notice.title,
                                style: const TextStyle(
                                  color: RoyalPalette.cream,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                notice.message,
                                style: const TextStyle(
                                  color: RoyalPalette.muted,
                                ),
                              ),
                              trailing: notice.read
                                  ? null
                                  : const Icon(
                                      Icons.circle,
                                      size: 9,
                                      color: FeaturePalette.message,
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
    await _syncNotifications();
  }

  @override
  void dispose() {
    _roomSyncTimer?.cancel();
    _partyRankTimer?.cancel();
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
      backgroundColor: RoyalPalette.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RoyalPalette.black,
              RoyalPalette.nearBlack,
              RoyalPalette.black,
            ],
          ),
        ),
        child: SafeArea(
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
                  icon: const ShiningIcon(
                    icon: Icons.leaderboard_rounded,
                    color: FeaturePalette.rank,
                    size: 20,
                    boxSize: 36,
                    glow: 0.34,
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      key: const Key('home-notifications-button'),
                      tooltip: 'Notifications',
                      onPressed: _showNotifications,
                      icon: const ShiningIcon(
                        icon: Icons.notifications_rounded,
                        color: FeaturePalette.message,
                        size: 20,
                        boxSize: 36,
                        glow: 0.34,
                      ),
                    ),
                    if (_notifications.where((item) => !item.read).isNotEmpty)
                      Positioned(
                        right: 3,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: FeaturePalette.safety,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _notifications
                                .where((item) => !item.read)
                                .length
                                .clamp(1, 99)
                                .toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  key: const Key('home-search-button'),
                  tooltip: 'Search',
                  onPressed: openSearch,
                  icon: const ShiningIcon(
                    icon: Icons.search_rounded,
                    color: FeaturePalette.discover,
                    size: 20,
                    boxSize: 36,
                    glow: 0.34,
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
            gradient: FeaturePalette.glow(FeaturePalette.family),
            accentColor: FeaturePalette.family,
            child: const Row(
              children: [
                ShiningIcon(
                  icon: Icons.add_home_rounded,
                  color: FeaturePalette.family,
                  size: 30,
                  boxSize: 58,
                  glow: 0.42,
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
                  color: FeaturePalette.family,
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
                  icon: const ShiningIcon(
                    icon: Icons.delete_sweep_rounded,
                    color: FeaturePalette.safety,
                    size: 18,
                    boxSize: 34,
                    glow: 0.28,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          RoyalPanel(
            onTap: () => _goToPage(1),
            gradient: FeaturePalette.glow(FeaturePalette.discover),
            accentColor: FeaturePalette.discover,
            child: const Row(
              children: [
                ShiningIcon(
                  icon: Icons.history_rounded,
                  color: FeaturePalette.discover,
                  size: 20,
                  boxSize: 38,
                  glow: 0.32,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No recent rooms yet. Tap to open Party.',
                    style: TextStyle(color: RoyalPalette.cream),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: FeaturePalette.discover,
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
                ShiningIcon(
                  icon: Icons.inventory_2_outlined,
                  size: 42,
                  boxSize: 68,
                  color: FeaturePalette.social,
                  glow: 0.34,
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
    final selectedCountry =
        countryFilter.trim().isEmpty ? null : countryFilter.trim();
    final ordered = popular
        ? widget.state.discovery.recommend(country: selectedCountry)
        : widget.state.discovery
            .newRooms()
            .where(
              (room) =>
                  selectedCountry == null || room.country == selectedCountry,
            )
            .toList();
    final topRooms = ordered.take(3).toList();
    final listRooms = ordered.skip(3).toList();
    final roomRankGroups = topRooms
        .map<List<String?>>((room) => <String?>[room.photoDataUrl])
        .toList(growable: false);
    final cpRankGroups = _cpTop
        .map<List<String?>>(
          (row) => <String?>[
            row['user_a_avatar']?.toString(),
            row['user_b_avatar']?.toString(),
          ],
        )
        .toList(growable: false);
    final familyRankGroups = _familyTop
        .map<List<String?>>(
          (row) => <String?>[row['leader_avatar_data_url']?.toString()],
        )
        .toList(growable: false);

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
                rankAvatarGroups: roomRankGroups,
                onTap: () => openRankings(initialTab: 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FeatureCard(
                key: const Key('party-cp-button'),
                title: 'CP Ranking',
                icon: Icons.favorite_rounded,
                rankAvatarGroups: cpRankGroups,
                onTap: openCpRanking,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FeatureCard(
                key: const Key('party-family-button'),
                title: 'Family',
                icon: Icons.groups_rounded,
                rankAvatarGroups: familyRankGroups,
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
          gradient: FeaturePalette.glow(FeaturePalette.fruitParty),
          accentColor: FeaturePalette.fruitParty,
          child: const Row(
            children: [
              ShiningIcon(
                icon: Icons.celebration_rounded,
                color: FeaturePalette.fruitParty,
                size: 38,
                boxSize: 64,
                glow: 0.46,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Royal Events',
                      style: TextStyle(
                        color: FeaturePalette.fruitParty,
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
              child: Builder(
                builder: (context) {
                  final color = _homeFeatureColor(item.$1);
                  return RoyalPanel(
                    key: Key('event-card-' + entry.key.toString()),
                    onTap: item.$4,
                    gradient: FeaturePalette.glow(color),
                    accentColor: color,
                    child: Row(
                      children: [
                        ShiningIcon(
                          icon: item.$3,
                          color: color,
                          size: 28,
                          boxSize: 54,
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
                        Icon(
                          Icons.chevron_right_rounded,
                          color: color,
                        ),
                      ],
                    ),
                  );
                },
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
              icon: const ShiningIcon(
                icon: Icons.language_rounded,
                color: FeaturePalette.discover,
                size: 20,
                boxSize: 36,
                glow: 0.34,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          RoyalPanel(
            onTap: openSearch,
            gradient: FeaturePalette.glow(FeaturePalette.discover),
            accentColor: FeaturePalette.discover,
            child: const Row(
              children: [
                ShiningIcon(
                  icon: Icons.public_off_rounded,
                  color: FeaturePalette.discover,
                  size: 20,
                  boxSize: 38,
                  glow: 0.32,
                ),
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
    final hasNetworkPhoto = remotePhoto != null &&
        (remotePhoto.startsWith('https://') || remotePhoto.startsWith('http://'));
    final hasLocalPhoto =
        path != null && path.isNotEmpty && File(path).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: FeaturePalette.discover.withValues(alpha: 0.72),
          ),
          gradient: FeaturePalette.glow(FeaturePalette.discover),
          boxShadow: [
            BoxShadow(
              color: FeaturePalette.discover.withValues(alpha: 0.24),
              blurRadius: 12,
            ),
          ],
        ),
        child: hasRemotePhoto
            ? SizedBox.expand(
                child: Image.memory(
                  base64Decode(remotePhoto.split(',').last),
                  fit: BoxFit.cover,
                ),
              )
            : hasNetworkPhoto
                ? SizedBox.expand(
                    child: Image.network(
                      remotePhoto,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          fallback ?? room.title.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: FeaturePalette.discover,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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
                      color: FeaturePalette.discover,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : Icon(
                    icon ?? Icons.graphic_eq_rounded,
                    color: FeaturePalette.discover,
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
      gradient: FeaturePalette.glow(FeaturePalette.family),
      accentColor: FeaturePalette.family,
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
                  color: FeaturePalette.family,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 28),
              const Icon(
                Icons.chevron_right_rounded,
                color: FeaturePalette.family,
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
    final color = _homeFeatureColor(title);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: RoyalPanel(
        onTap: onTap,
        radius: 22,
        gradient: FeaturePalette.glow(color),
        accentColor: color,
        child: Row(
          children: [
            ShiningIcon(
              icon: icon,
              color: color,
              size: 38,
              boxSize: 70,
              glow: 0.46,
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
                    style: TextStyle(
                      color: color,
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
            Icon(
              Icons.chevron_right_rounded,
              color: color,
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
                              ? <Color>[
                                  FeaturePalette.social,
                                  FeaturePalette.family,
                                  FeaturePalette.fruitParty,
                                  FeaturePalette.discover,
                                ][i]
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
                          color: <Color>[
                            FeaturePalette.social,
                            FeaturePalette.family,
                            FeaturePalette.fruitParty,
                            FeaturePalette.discover,
                          ][i],
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: selectedIndex == i
                              ? [
                                  BoxShadow(
                                    color: <Color>[
                                      FeaturePalette.social,
                                      FeaturePalette.family,
                                      FeaturePalette.fruitParty,
                                      FeaturePalette.discover,
                                    ][i].withValues(alpha: 0.55),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
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
    this.rankAvatarGroups = const <List<String?>>[],
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final List<List<String?>> rankAvatarGroups;

  @override
  Widget build(BuildContext context) {
    final color = _homeFeatureColor(title);
    return RoyalPanel(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      onTap: onTap,
      gradient: FeaturePalette.glow(color),
      accentColor: color,
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              shadows: [
                Shadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (rankAvatarGroups.isNotEmpty)
            _PartyRankAvatarRow(
              groups: rankAvatarGroups.take(3).toList(growable: false),
              accent: color,
            )
          else
            ShiningIcon(
              icon: icon,
              color: color,
              size: 28,
              boxSize: 50,
            ),
          const SizedBox(height: 7),
          Text(
            rankAvatarGroups.isEmpty ? 'Top ranking' : 'TOP 1  •  TOP 2  •  TOP 3',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w800,
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyRankAvatarRow extends StatelessWidget {
  const _PartyRankAvatarRow({
    required this.groups,
    required this.accent,
  });

  final List<List<String?>> groups;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < groups.length; i++)
          _PartyRankAvatarGroup(
            rank: i + 1,
            sources: groups[i],
            accent: i == 0
                ? FeaturePalette.rank
                : i == 1
                    ? const Color(0xFFC7D1DC)
                    : const Color(0xFFD78955),
          ),
      ],
    );
  }
}

class _PartyRankAvatarGroup extends StatelessWidget {
  const _PartyRankAvatarGroup({
    required this.rank,
    required this.sources,
    required this.accent,
  });

  final int rank;
  final List<String?> sources;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final valid = sources
        .map(_homeAvatarProvider)
        .whereType<ImageProvider>()
        .take(2)
        .toList(growable: false);
    return SizedBox(
      width: 52,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          for (var i = 0; i < (valid.isEmpty ? 1 : valid.length); i++)
            Positioned(
              left: valid.length > 1 ? 5.0 + i * 18 : 11,
              bottom: 1,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.55),
                      blurRadius: 9,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: RoyalPalette.nearBlack,
                  backgroundImage: valid.isEmpty ? null : valid[i],
                  child: valid.isEmpty
                      ? Icon(
                          rank == 1
                              ? Icons.workspace_premium_rounded
                              : Icons.person_rounded,
                          size: 15,
                          color: accent,
                        )
                      : null,
                ),
              ),
            ),
          Positioned(
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.55),
                    blurRadius: 7,
                  ),
                ],
              ),
              child: Text(
                rank.toString(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
    final accent = rank == 1
        ? FeaturePalette.rank
        : rank == 2
            ? const Color(0xFFC5D0DA)
            : FeaturePalette.family;
    return RoyalPanel(
      key: Key('room-card-' + room.id),
      padding: const EdgeInsets.all(6),
      onTap: onTap,
      gradient: FeaturePalette.glow(accent),
      accentColor: accent,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: accent, width: rank == 1 ? 3 : 2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: rank == 1 ? 0.62 : 0.42),
                      blurRadius: rank == 1 ? 18 : 12,
                      spreadRadius: rank == 1 ? 1 : 0,
                    ),
                  ],
                  gradient: LinearGradient(
                    colors: rank == 1
                        ? const [
                            Color(0xFFFFD85A),
                            Color(0xFF6E4300),
                            Color(0xFF171008),
                          ]
                        : rank == 2
                            ? const [
                                Color(0xFFE4EDF4),
                                Color(0xFF5D6875),
                                Color(0xFF111418),
                              ]
                            : const [
                                Color(0xFFFFB07A),
                                Color(0xFF7A3B1D),
                                Color(0xFF17100D),
                              ],
                  ),
                ),
                child: _RoomArtwork(
                  room: room,
                  width: double.infinity,
                  height: 100,
                  fallback: room.title.characters.first.toUpperCase(),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -9),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.65),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        rank == 1
                            ? Icons.workspace_premium_rounded
                            : Icons.emoji_events_rounded,
                        size: 12,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'TOP $rank',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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
                room.online.toString() +
                '  •  EXP ' +
                _compactNumber(room.roomExperience),
            style: const TextStyle(
              color: RoyalPalette.muted,
              fontSize: 9.5,
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
        gradient: FeaturePalette.glow(FeaturePalette.discover),
        accentColor: FeaturePalette.discover,
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
                      const ShiningIcon(
                        icon: Icons.workspace_premium_rounded,
                        color: FeaturePalette.vip,
                        size: 14,
                        boxSize: 26,
                        glow: 0.28,
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
                  icon: ShiningIcon(
                    icon: favorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: favorite
                        ? FeaturePalette.rank
                        : FeaturePalette.discover,
                    size: 17,
                    boxSize: 32,
                    glow: favorite ? 0.34 : 0.22,
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
              leading: const ShiningIcon(
                icon: Icons.photo_library_rounded,
                color: FeaturePalette.moments,
                size: 18,
                boxSize: 34,
                glow: 0.30,
              ),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              key: const Key('create-room-photo-camera'),
              leading: const ShiningIcon(
                icon: Icons.photo_camera_rounded,
                color: FeaturePalette.discover,
                size: 18,
                boxSize: 34,
                glow: 0.30,
              ),
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
                color: FeaturePalette.family,
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
                    ShiningIcon(
                      icon: photoDataUrl == null
                          ? Icons.add_a_photo_rounded
                          : Icons.check_circle_rounded,
                      color: photoDataUrl == null
                          ? FeaturePalette.moments
                          : FeaturePalette.family,
                      size: 34,
                      boxSize: 76,
                      glow: 0.44,
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
                    selectedColor:
                        FeaturePalette.family.withValues(alpha: 0.28),
                    side: BorderSide(
                      color: seatCount == count
                          ? FeaturePalette.family
                          : RoyalPalette.bronze,
                    ),
                    labelStyle: TextStyle(
                      color: seatCount == count
                          ? FeaturePalette.family
                          : RoyalPalette.cream,
                      fontWeight: FontWeight.w800,
                    ),
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
