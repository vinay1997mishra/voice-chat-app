import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../ui/royal_theme.dart';
import 'games_screen.dart';
import 'room_screen.dart';
import 'vip_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool popular = true;

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

  @override
  Widget build(BuildContext context) {
    final rooms = widget.state.discovery.recommend();
    final topRooms = rooms.take(3).toList();
    final listRooms = rooms.skip(3).toList();

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
            tooltip: 'VIP',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VipScreen(state: widget.state),
              ),
            ),
            icon: const Icon(Icons.workspace_premium_rounded),
          ),
          IconButton(
            tooltip: 'Create room',
            onPressed: createRoom,
            icon: const Icon(Icons.add_home_rounded),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        children: [
          const _TopTabs(),
          const SizedBox(height: 12),
          RoyalPanel(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            gradient: const LinearGradient(
              colors: [Color(0xFF0A0804), Color(0xFF4A2B05), Color(0xFF0A0804)],
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Icon(Icons.favorite_rounded, color: RoyalPalette.gold, size: 54),
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
                      Text('Royal Couple Ranking', style: TextStyle(color: RoyalPalette.muted)),
                    ],
                  ),
                ),
                Expanded(
                  child: Icon(Icons.favorite_rounded, color: RoyalPalette.gold, size: 54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FeatureCard(
                  title: 'Game',
                  icon: Icons.casino_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GamesScreen(state: widget.state),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FeatureCard(
                  title: 'CP Ranking',
                  icon: Icons.favorite_rounded,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CP ranking opened.')),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FeatureCard(
                  title: 'Family',
                  icon: Icons.groups_rounded,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Family center opened.')),
                  ),
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
                  label: const Text('🔥 Popular'),
                  selected: popular,
                  onSelected: (_) => setState(() => popular = true),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
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
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createRoom,
        backgroundColor: RoyalPalette.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Room', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs();

  @override
  Widget build(BuildContext context) {
    final tabs = ['Mine', 'Party', 'Events', 'Country'];
    return Row(
      children: [
        for (final tab in tabs)
          Expanded(
            child: Column(
              children: [
                Text(
                  tab,
                  style: TextStyle(
                    color: tab == 'Party' ? RoyalPalette.gold : RoyalPalette.muted,
                    fontWeight: tab == 'Party' ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 4,
                  width: tab == 'Party' ? 27 : 0,
                  decoration: BoxDecoration(
                    color: RoyalPalette.gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.icon, required this.onTap});
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RoyalPanel(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      onTap: onTap,
      gradient: const LinearGradient(colors: [Color(0xFF251B08), Color(0xFF0B0905)]),
      child: Column(
        children: [
          Icon(icon, color: RoyalPalette.gold, size: 32),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TopRoomCard extends StatelessWidget {
  const _TopRoomCard({required this.room, required this.rank, required this.onTap});
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
                    rank == 1 ? Icons.emoji_events_rounded : Icons.groups_rounded,
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
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
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
            style: const TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w800, fontSize: 11),
          ),
          Text(
            (room.country == 'IN' ? '🇮🇳  ' : '🌐  ') + room.online.toString(),
            style: const TextStyle(color: RoyalPalette.muted, fontSize: 10),
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
                gradient: const LinearGradient(colors: [Color(0xFF31210A), Color(0xFF0A0805)]),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: RoyalPalette.gold, size: 34),
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
                    style: const TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    room.partyMode + ' • ' + room.seatCount.toString() + ' seats',
                    style: const TextStyle(color: RoyalPalette.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: RoyalPalette.gold, size: 16),
                      const SizedBox(width: 5),
                      Text('ID ' + room.id, style: const TextStyle(fontSize: 10)),
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
                    favorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: RoyalPalette.gold,
                  ),
                ),
                Text(room.online.toString(), style: const TextStyle(color: RoyalPalette.muted, fontSize: 10)),
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
    final seatOptions = [8, 10, 12, 15, 18, 20];
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
              style: TextStyle(color: RoyalPalette.gold, fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            const Text('Choose party mode', style: TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final mode in ['Friends-making Party', 'Event hosting mode'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(mode == 'Friends-making Party' ? 'Friends Party' : 'Event Mode'),
                        selected: partyMode == mode,
                        onSelected: (_) => setState(() => partyMode = mode),
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
                DropdownMenuItem(value: 'US', child: Text('🇺🇸 United States')),
                DropdownMenuItem(value: 'VN', child: Text('🇻🇳 Vietnam')),
                DropdownMenuItem(value: 'SG', child: Text('🇸🇬 Singapore')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => country = value);
              },
            ),
            const SizedBox(height: 14),
            const Text('Number of mics', style: TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w800)),
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
