import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import 'room_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final TinniState state;

  @override
  Widget build(BuildContext context) {
    final rooms = state.discovery.recommend(country: 'IN');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tinni Star ✨'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('🪙 ' + state.wallet.coins.toString()),
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
          ...rooms.map((room) => _RoomCard(state: state, room: room)),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.state, required this.room});

  final TinniState state;
  final RoomSummary room;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.graphic_eq_rounded)),
        title: Text(room.title),
        subtitle: Text(
          'ID ' + room.id + ' • ' + room.online.toString() + ' online',
        ),
        trailing: room.activity
            ? const Chip(label: Text('Activity'))
            : const Icon(Icons.chevron_right_rounded),
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
