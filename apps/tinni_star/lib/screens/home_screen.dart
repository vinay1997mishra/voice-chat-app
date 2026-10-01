import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../infra/app_backend_service.dart';
import '../core/seat_policy.dart';
import '../ui/room_dp.dart';
import '../ui/royal_party_artwork.dart';
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
    await widget.state.refreshAuthenticatedAccount();
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
    await widget.state.refreshAuthenticatedAccount(force: true);
    final account = widget.state.auth.current;
    if (account == null) return;

    try {
      await widget.state.discovery.syncRooms(account.authToken);
    } catch (_) {
      // The backend still prevents a second owner room if this refresh fails.
    }

    final existing = widget.state.discovery.ownedRooms(account.userId);
    if (existing.isNotEmpty) {
      await openRoom(existing.first);
      return;
    }

    if (!mounted) return;
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

  Future<void> openRoom(RoomSummary room) async {
    final previousUserId = widget.state.auth.current?.userId;
    final idChanged =
        await widget.state.refreshAuthenticatedAccount(force: true);
    final account = widget.state.auth.current;
    var targetRoom = room;

    if (account != null && idChanged) {
      try {
        await widget.state.discovery.syncRooms(account.authToken);
        final migratedOwnedRooms =
            widget.state.discovery.ownedRooms(account.userId);
        if (previousUserId != null &&
            room.ownerId == previousUserId &&
            migratedOwnedRooms.isNotEmpty) {
          targetRoom = migratedOwnedRooms.first;
        } else {
          final refreshed = widget.state.discovery.rooms
              .where((item) => item.id == room.id)
              .toList();
          if (refreshed.isNotEmpty) targetRoom = refreshed.first;
        }
      } catch (_) {
        // Continue with the last room snapshot; server-side ownership remains authoritative.
      }
    }

    if (!mounted) return;
    widget.state.discovery.visit(targetRoom.id);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(state: widget.state, room: targetRoom),
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
                title: 'ROYAL PARTY',
                subtitle: 'Live rooms, rankings and royal rewards',
                icon: Icons.workspace_premium_rounded,
                onTap: () => openRankings(initialTab: 0),
              ),
              _PartyPromoCard(
                title: 'WEEKLY STAR',
                subtitle: 'Weekly rankings and royal rewards',
                icon: Icons.emoji_events_rounded,
                onTap: () => openRankings(initialTab: 1),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 3; i++) ...[
              Expanded(
                child: i < topRooms.length
                    ? _TopRoomCard(
                        room: topRooms[i],
                        rank: i + 1,
                        onTap: () => openRoom(topRooms[i]),
                      )
                    : const SizedBox.shrink(),
              ),
              if (i != 2) const SizedBox(width: 8),
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
        padding: EdgeInsets.zero,
        accentColor: RoyalPalette.deepGold,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              Positioned.fill(
                child: RoyalPartyBackdrop(
                  accent: color,
                  intensity: title == 'ROYAL PARTY' ? 1 : .72,
                ),
              ),
              const Positioned.fill(
                child: RoyalPanelOrnament(color: RoyalPalette.gold),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            RoyalPalette.gold.withValues(alpha: .24),
                            RoyalPalette.nearBlack,
                          ],
                        ),
                        border: Border.all(
                          color: RoyalPalette.gold.withValues(alpha: .65),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: RoyalPalette.gold.withValues(alpha: .12),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: RoyalPalette.gold,
                        size: 34,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RoyalPalette.cream,
                              fontWeight: FontWeight.w900,
                              fontSize: 21,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RoyalPalette.muted,
                              height: 1.2,
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: RoyalPalette.gold.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: RoyalPalette.gold.withValues(alpha: .28),
                                  ),
                                ),
                                child: const Text(
                                  'VIP • LIVE',
                                  style: TextStyle(
                                    color: RoyalPalette.gold,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .6,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: RoyalPalette.gold,
                                size: 20,
                              ),
                            ],
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
                          boxShadow: selectedIndex == i
                              ? [
                                  BoxShadow(
                                    color: RoyalPalette.gold
                                        .withValues(alpha: 0.28),
                                    blurRadius: 9,
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
      padding: EdgeInsets.zero,
      onTap: onTap,
      gradient: FeaturePalette.glow(color),
      accentColor: RoyalPalette.deepGold,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Positioned.fill(
              child: RoyalPanelOrnament(
                color: color.withValues(alpha: .85),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: RoyalPalette.cream,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.35,
                    ),
                  ),
                  const SizedBox(height: 9),
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
                      glow: .18,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    rankAvatarGroups.isEmpty
                        ? 'Royal ranking'
                        : 'TOP 1  •  TOP 2  •  TOP 3',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: rankAvatarGroups.isEmpty
                          ? RoyalPalette.muted
                          : RoyalPalette.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 8.2,
                      letterSpacing: .25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

    Widget avatar(int index) {
      return CircleAvatar(
        backgroundColor: RoyalPalette.nearBlack,
        backgroundImage: valid.isEmpty ? null : valid[index],
        child: valid.isEmpty
            ? Icon(
                rank == 1
                    ? Icons.workspace_premium_rounded
                    : Icons.person_rounded,
                size: 15,
                color: accent,
              )
            : null,
      );
    }

    final body = valid.length <= 1
        ? avatar(0)
        : Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: const Alignment(-.48, 0),
                child: FractionallySizedBox(
                  widthFactor: .72,
                  heightFactor: .72,
                  child: ClipOval(child: avatar(0)),
                ),
              ),
              Align(
                alignment: const Alignment(.48, 0),
                child: FractionallySizedBox(
                  widthFactor: .72,
                  heightFactor: .72,
                  child: ClipOval(child: avatar(1)),
                ),
              ),
            ],
          );

    return RoyalRankHalo(
      rank: rank,
      size: 52,
      child: body,
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
    final metal = rank == 1
        ? RoyalPalette.gold
        : rank == 2
            ? const Color(0xFFBEC4CB)
            : const Color(0xFFA56C43);
    return RoyalPanel(
      key: Key('room-card-' + room.id),
      padding: const EdgeInsets.fromLTRB(6, 9, 6, 7),
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          metal.withValues(alpha: .10),
          RoyalPalette.panel,
          RoyalPalette.black,
        ],
      ),
      accentColor: metal,
      child: Column(
        children: [
          RoyalRankFrame(
            rank: rank,
            height: 112,
            child: Center(
              child: RoomDp(
                room: room,
                size: 96,
                radius: 13,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            room.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            (room.country == 'IN' ? '🇮🇳 ' : '🌐 ') +
                room.online.toString() +
                '  •  EXP ' +
                _compactNumber(room.roomExperience),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: RoyalPalette.muted,
              fontSize: 8.8,
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF18140E),
            RoyalPalette.panel,
            Color(0xFF0B0B0B),
          ],
        ),
        accentColor: RoyalPalette.deepGold,
        child: Row(
          children: [
            RoomDp(
              room: room,
              size: 74,
              radius: 13,
              fit: BoxFit.contain,
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
                        'ID ' + room.displayId,
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

enum _RoomPhotoCropMode {
  full,
  center,
  top,
  bottom,
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
  _RoomPhotoCropMode photoCropMode = _RoomPhotoCropMode.full;

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
    if (!mounted) return;

    final mode = await _chooseRoomPhotoCrop(bytes);
    if (mode == null || !mounted) return;

    final squareBytes = await _renderSquareRoomPhoto(bytes, mode);
    if (!mounted) return;
    if (squareBytes.length > 320000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room photo is still too large after cropping.'),
        ),
      );
      return;
    }
    setState(() {
      photoCropMode = mode;
      photoDataUrl = 'data:image/png;base64,${base64Encode(squareBytes)}';
    });
  }

  String _cropModeLabel(_RoomPhotoCropMode mode) => switch (mode) {
        _RoomPhotoCropMode.full => 'Full photo',
        _RoomPhotoCropMode.center => 'Center crop',
        _RoomPhotoCropMode.top => 'Top crop',
        _RoomPhotoCropMode.bottom => 'Bottom crop',
      };

  Alignment _cropPreviewAlignment(_RoomPhotoCropMode mode) => switch (mode) {
        _RoomPhotoCropMode.top => Alignment.topCenter,
        _RoomPhotoCropMode.bottom => Alignment.bottomCenter,
        _ => Alignment.center,
      };

  Future<_RoomPhotoCropMode?> _chooseRoomPhotoCrop(Uint8List bytes) {
    return showModalBottomSheet<_RoomPhotoCropMode>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Room DP crop',
                style: TextStyle(
                  color: RoyalPalette.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose exactly how the square room DP should look.',
                style: TextStyle(
                  color: RoyalPalette.muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.14,
                children: [
                  for (final mode in _RoomPhotoCropMode.values)
                    InkWell(
                      key: Key('room-photo-crop-' + mode.name),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(sheetContext, mode),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: RoyalPalette.panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: RoyalPalette.deepGold.withValues(alpha: .72),
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  color: RoyalPalette.black,
                                  width: double.infinity,
                                  child: Image.memory(
                                    bytes,
                                    fit: mode == _RoomPhotoCropMode.full
                                        ? BoxFit.contain
                                        : BoxFit.cover,
                                    alignment: _cropPreviewAlignment(mode),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _cropModeLabel(mode),
                              style: const TextStyle(
                                color: RoyalPalette.cream,
                                fontSize: 10,
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
      ),
    );
  }

  Future<Uint8List> _renderSquareRoomPhoto(
    Uint8List bytes,
    _RoomPhotoCropMode mode,
  ) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    const outputSize = 256;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(RoyalPalette.black, BlendMode.src);

    final width = image.width.toDouble();
    final height = image.height.toDouble();
    final src = mode == _RoomPhotoCropMode.full
        ? Rect.fromLTWH(0, 0, width, height)
        : _squareSourceRect(width, height, mode);

    Rect dst;
    if (mode == _RoomPhotoCropMode.full) {
      final scale = math.min(outputSize / width, outputSize / height);
      final drawWidth = width * scale;
      final drawHeight = height * scale;
      dst = Rect.fromLTWH(
        (outputSize - drawWidth) / 2,
        (outputSize - drawHeight) / 2,
        drawWidth,
        drawHeight,
      );
    } else {
      dst = Rect.fromLTWH(
        0,
        0,
        outputSize.toDouble(),
        outputSize.toDouble(),
      );
    }

    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
    final output = await recorder.endRecording().toImage(
          outputSize,
          outputSize,
        );
    final data = await output.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    output.dispose();
    codec.dispose();
    if (data == null) throw StateError('Unable to crop room photo');
    return data.buffer.asUint8List();
  }

  Rect _squareSourceRect(
    double width,
    double height,
    _RoomPhotoCropMode mode,
  ) {
    final side = math.min(width, height);
    final left = (width - side) / 2;
    final top = switch (mode) {
      _RoomPhotoCropMode.top => 0.0,
      _RoomPhotoCropMode.bottom => height - side,
      _ => (height - side) / 2,
    };
    return Rect.fromLTWH(left, top, side, side);
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
                    if (photoDataUrl == null)
                      const ShiningIcon(
                        icon: Icons.add_a_photo_rounded,
                        color: FeaturePalette.moments,
                        size: 34,
                        boxSize: 76,
                        glow: 0.24,
                      )
                    else
                      Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: RoyalPalette.black,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: RoyalPalette.gold,
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            base64Decode(photoDataUrl!.split(',').last),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    const SizedBox(height: 7),
                    Text(
                      photoDataUrl == null
                          ? 'Add room photo'
                          : 'Room DP • ' + _cropModeLabel(photoCropMode),
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
