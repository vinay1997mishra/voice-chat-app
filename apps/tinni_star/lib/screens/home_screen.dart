import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> createRoom() async {
    final title = TextEditingController();
    String country = 'IN';
    final room = await showModalBottomSheet<RoomSummary>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Create room',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Room name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: country,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'IN', child: Text('🇮🇳 India')),
                  DropdownMenuItem(value: 'US', child: Text('🇺🇸 United States')),
                  DropdownMenuItem(value: 'VN', child: Text('🇻🇳 Vietnam')),
                  DropdownMenuItem(value: 'SG', child: Text('🇸🇬 Singapore')),
                ],
                onChanged: (value) {
                  if (value != null) updateSheet(() => country = value);
                },
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  final value = title.text.trim();
                  if (value.isEmpty) return;
                  Navigator.pop(
                    sheetContext,
                    widget.state.discovery.createRoom(
                      title: value,
                      country: country,
                    ),
                  );
                },
                icon: const Icon(Icons.add_home_rounded),
                label: const Text('Create room'),
              ),
            ],
          ),
        ),
      ),
    );
    title.dispose();

    if (room != null && mounted) {
      setState(() {});
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomScreen(state: widget.state, room: room),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.state.discovery.recommend(country: 'IN');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tinni Star ✨'),
        actions: [
          IconButton(
            tooltip: 'Create room',
            onPressed: createRoom,
            icon: const Icon(Icons.add_home_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('🪙 ' + widget.state.wallet.coins.toString()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF5E188A), Color(0xFF25102D)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'India Rooms',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 6),
                Text(
                  'Voice rooms, gifts, KTV, games, CP, family and activities.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Recommended',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...rooms.map(
            (room) => _RoomCard(
              state: widget.state,
              room: room,
              onFavoriteChanged: () => setState(() {}),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createRoom,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Room'),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.state,
    required this.room,
    required this.onFavoriteChanged,
  });

  final TinniState state;
  final RoomSummary room;
  final VoidCallback onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    final favorite = state.discovery.favorites.contains(room.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.graphic_eq_rounded)),
        title: Text(room.title),
        subtitle: Text(
          'ID ' + room.id + ' • ' + room.online.toString() + ' online',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (room.activity) const Chip(label: Text('Activity')),
            IconButton(
              tooltip: favorite ? 'Remove favorite' : 'Favorite room',
              onPressed: () {
                state.discovery.toggleFavorite(room.id);
                onFavoriteChanged();
              },
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_border_rounded,
              ),
            ),
          ],
        ),
        onTap: () {
          state.discovery.visit(room.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoomScreen(state: state, room: room),
            ),
          );
        },
      ),
    );
  }
}
