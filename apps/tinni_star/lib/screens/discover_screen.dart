import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
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
        final byId = <String, RoomSummary>{
          for (final room in discovery.rooms) room.id: room,
        };
        return discovery.recentRoomIds
            .map((id) => byId[id])
            .whereType<RoomSummary>()
            .toList();
      case _DiscoverMode.favorites:
        return discovery.rooms
            .where((room) => discovery.favorites.contains(room.id))
            .toList();
    }
  }

  void _openRoom(RoomSummary room) {
    widget.state.discovery.visit(room.id);
    setState(() {});
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(
          state: widget.state,
          room: room,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = results ?? _roomsForMode();
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: search,
            decoration: InputDecoration(
              hintText: 'Search room ID or name',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () {
                  search.clear();
                  setState(() => results = null);
                },
                icon: const Icon(Icons.clear_rounded),
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              setState(() => results = widget.state.discovery.search(value));
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<_DiscoverMode>(
            segments: const [
              ButtonSegment(
                value: _DiscoverMode.all,
                icon: Icon(Icons.public_rounded),
                label: Text('All'),
              ),
              ButtonSegment(
                value: _DiscoverMode.recent,
                icon: Icon(Icons.history_rounded),
                label: Text('Recent'),
              ),
              ButtonSegment(
                value: _DiscoverMode.favorites,
                icon: Icon(Icons.star_rounded),
                label: Text('Favorites'),
              ),
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
          const SizedBox(height: 14),
          if (rooms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Column(
                children: [
                  Icon(Icons.travel_explore_rounded, size: 42),
                  SizedBox(height: 10),
                  Text('No rooms in this list yet.'),
                ],
              ),
            ),
          ...rooms.map(
            (room) {
              final favorite =
                  widget.state.discovery.favorites.contains(room.id);
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.graphic_eq_rounded),
                  ),
                  title: Text(room.title),
                  subtitle: Text(room.country + ' • ' + room.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(room.online.toString()),
                      IconButton(
                        tooltip: favorite
                            ? 'Remove favorite'
                            : 'Favorite room',
                        onPressed: () {
                          widget.state.discovery.toggleFavorite(room.id);
                          setState(() {});
                        },
                        icon: Icon(
                          favorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _openRoom(room),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
