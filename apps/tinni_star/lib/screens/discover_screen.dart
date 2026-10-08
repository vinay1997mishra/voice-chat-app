import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../ui/room_dp.dart';
import '../ui/royal_theme.dart';
import 'chat_user_profile_screen.dart';
import 'room_screen.dart';

enum _DiscoverMode { all, recent, favorites }

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final search = TextEditingController();
  List<RoomSummary>? results;
  Map<String, dynamic>? userResult;
  bool searching = false;
  String? searchError;
  int _searchGeneration = 0;
  _DiscoverMode mode = _DiscoverMode.all;

  @override
  void initState() {
    super.initState();
    widget.state.pageEntries.addListener(_onPageEntered);
    widget.state.realtimeChanges.addListener(_onLiveChanged);
    _refresh();
  }
  void _onPageEntered() { if (widget.state.pageEntries.value == 1) _refresh(); }
  void _onLiveChanged() {
    if (!mounted) return;
    final value = search.text.trim();
    if (value.isEmpty || results == null) return;
    setState(() => results = widget.state.discovery.search(value));
  }

  @override
  void dispose() {
    widget.state.pageEntries.removeListener(_onPageEntered);
    widget.state.realtimeChanges.removeListener(_onLiveChanged);
    search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      await widget.state.discovery.syncRooms(account.authToken);
      if (!mounted) return;
      final value = search.text.trim();
      if (value.isNotEmpty) {
        await _runSearch(value);
      } else {
        setState(() {});
      }
    } catch (_) {
      // Keep the last loaded room list until the next manual refresh/re-entry.
    }
  }

  Future<void> _runSearch(String rawQuery) async {
    final value = rawQuery.trim();
    final generation = ++_searchGeneration;
    if (value.isEmpty) {
      if (!mounted) return;
      setState(() {
        results = null;
        userResult = null;
        searching = false;
        searchError = null;
      });
      return;
    }

    final account = widget.state.auth.current;
    final localRooms = widget.state.discovery.search(value);
    if (mounted) {
      setState(() {
        results = localRooms;
        userResult = null;
        searching = account != null;
        searchError = null;
      });
    }
    if (account == null) return;

    try {
      final responses = await Future.wait<dynamic>([
        widget.state.discovery.searchRoomRemote(
          authToken: account.authToken,
          query: value,
        ),
        widget.state.backend.searchUserById(account.authToken, value),
      ]);
      if (!mounted || generation != _searchGeneration) return;

      final byId = <String, RoomSummary>{
        for (final room in widget.state.discovery.search(value)) room.id: room,
      };
      final remoteRoom = responses[0];
      if (remoteRoom is RoomSummary) {
        byId[remoteRoom.id] = remoteRoom;
      }
      final rawUser = responses[1];
      setState(() {
        results = byId.values.toList(growable: false);
        userResult = rawUser is Map
            ? Map<String, dynamic>.from(rawUser)
            : null;
        searching = false;
        searchError = null;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        searching = false;
        searchError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _openUser() {
    final user = userResult;
    if (user == null) return;
    final userId = user['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatUserProfileScreen(
          state: widget.state,
          userId: userId,
          displayName: user['display_name']?.toString() ?? userId,
          avatarDataUrl: user['avatar_data_url']?.toString(),
        ),
      ),
    );
  }

  List<RoomSummary> _roomsForMode() {
    final discovery = widget.state.discovery;
    switch (mode) {
      case _DiscoverMode.all:
        return discovery.recommend();
      case _DiscoverMode.recent:
        final byId = <String, RoomSummary>{for (final room in discovery.rooms) room.id: room};
        return discovery.recentRoomIds.map((id) => byId[id]).whereType<RoomSummary>().toList();
      case _DiscoverMode.favorites:
        return discovery.rooms.where((room) => discovery.favorites.contains(room.id)).toList();
    }
  }

  void _openRoom(RoomSummary room) {
    widget.state.discovery.visit(room.id);
    setState(() {});
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomScreen(state: widget.state, room: room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = results ?? _roomsForMode();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Discover',
          style: TextStyle(
            color: FeaturePalette.discover,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
        children: [
          TextField(
            key: const Key('discover-search-field'),
            controller: search,
            decoration: InputDecoration(
              hintText: 'Search user ID, room ID or room name',
              prefixIcon: const ShiningIcon(
                icon: Icons.search_rounded,
                color: FeaturePalette.discover,
                size: 18,
                boxSize: 34,
                glow: 0.28,
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  search.clear();
                  _searchGeneration += 1;
                  setState(() {
                    results = null;
                    userResult = null;
                    searching = false;
                    searchError = null;
                  });
                },
                icon: const Icon(Icons.clear_rounded),
              ),
            ),
            onSubmitted: _runSearch,
            textInputAction: TextInputAction.search,
          ),
          if (searching) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (searchError != null) ...[
            const SizedBox(height: 8),
            Text(
              searchError!,
              key: const Key('discover-search-error'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          if (userResult != null) ...[
            const SizedBox(height: 10),
            RoyalPanel(
              key: const Key('discover-user-result'),
              padding: const EdgeInsets.all(10),
              accentColor: FeaturePalette.discover,
              onTap: _openUser,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    child: Icon(Icons.person_rounded),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userResult!['display_name']?.toString() ??
                              userResult!['user_id']?.toString() ??
                              'User',
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'ID ' + (userResult!['user_id']?.toString() ?? ''),
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
                    color: FeaturePalette.discover,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SegmentedButton<_DiscoverMode>(
            segments: const [
              ButtonSegment(value: _DiscoverMode.all, icon: Icon(Icons.public_rounded), label: Text('All')),
              ButtonSegment(value: _DiscoverMode.recent, icon: Icon(Icons.history_rounded), label: Text('Recent')),
              ButtonSegment(value: _DiscoverMode.favorites, icon: Icon(Icons.star_rounded), label: Text('Favorites')),
            ],
            selected: {mode},
            onSelectionChanged: (selection) {
              search.clear();
              _searchGeneration += 1;
              setState(() {
                results = null;
                userResult = null;
                searching = false;
                searchError = null;
                mode = selection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            results == null ? 'Royal Rooms' : 'Rooms',
            style: const TextStyle(
              color: FeaturePalette.discover,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (rooms.isEmpty &&
              (results == null || (userResult == null && !searching)))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 42),
              child: Column(
                children: [
                  const ShiningIcon(
                    icon: Icons.travel_explore_rounded,
                    size: 34,
                    boxSize: 58,
                    color: FeaturePalette.discover,
                    glow: 0.42,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    results == null
                        ? 'No rooms in this list yet.'
                        : 'No matching user or room found.',
                    key: const Key('discover-search-empty'),
                  ),
                ],
              ),
            ),
          ...rooms.map(
            (room) {
              final favorite = widget.state.discovery.favorites.contains(room.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: RoyalPanel(
                  padding: const EdgeInsets.all(10),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF17140F),
                      RoyalPalette.panel,
                      Color(0xFF080808),
                    ],
                  ),
                  accentColor: RoyalPalette.deepGold,
                  onTap: () => _openRoom(room),
                  child: Row(
                    children: [
                      RoomDp(
                        room: room,
                        size: 62,
                        radius: 14,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(room.title, style: const TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w900)),
                            Text(
                              room.partyMode + ' • ' + room.seatCount.toString() + ' seats',
                              style: const TextStyle(color: RoyalPalette.muted, fontSize: 11),
                            ),
                            Text(
                              room.country + ' • ID ' + room.displayId + ' • ' + room.online.toString() + ' online',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          widget.state.discovery.toggleFavorite(room.id);
                          setState(() {});
                        },
                        icon: Icon(
                          favorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: favorite
                              ? FeaturePalette.rank
                              : FeaturePalette.discover,
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
