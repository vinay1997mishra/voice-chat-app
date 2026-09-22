import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import 'room_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final search = TextEditingController();
  List<RoomSummary>? results;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = results ?? widget.state.discovery.recommend();
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
          const SizedBox(height: 14),
          ...rooms.map(
            (room) => Card(
              child: ListTile(
                title: Text(room.title),
                subtitle: Text(room.country + ' • ' + room.id),
                trailing: Text(room.online.toString()),
                onTap: () {
                  widget.state.discovery.visit(room.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomScreen(
                        state: widget.state,
                        room: room,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
