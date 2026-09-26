import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../ui/royal_theme.dart';
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
  _DiscoverMode mode = _DiscoverMode.all;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
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
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            controller: search,
            decoration: InputDecoration(
              hintText: 'Search room ID or name',
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
                  setState(() => results = null);
                },
                icon: const Icon(Icons.clear_rounded),
              ),
            ),
            onSubmitted: (value) => setState(() => results = widget.state.discovery.search(value)),
          ),
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
              setState(() {
                results = null;
                mode = selection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Royal Rooms',
            style: TextStyle(
              color: FeaturePalette.discover,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (rooms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Column(
                children: [
                  ShiningIcon(
                    icon: Icons.travel_explore_rounded,
                    size: 34,
                    boxSize: 58,
                    color: FeaturePalette.discover,
                    glow: 0.42,
                  ),
                  SizedBox(height: 10),
                  Text('No rooms in this list yet.'),
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
                  gradient: FeaturePalette.glow(FeaturePalette.discover),
                  accentColor: FeaturePalette.discover,
                  onTap: () => _openRoom(room),
                  child: Row(
                    children: [
                      const ShiningIcon(
                        icon: Icons.graphic_eq_rounded,
                        color: FeaturePalette.discover,
                        size: 28,
                        boxSize: 56,
                        glow: 0.40,
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
                              room.country + ' • ID ' + room.id + ' • ' + room.online.toString() + ' online',
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
    );
  }
}
