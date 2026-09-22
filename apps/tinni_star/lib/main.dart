import 'package:flutter/material.dart';

import 'core/anamika_connector.dart';
import 'core/function_pack.dart';
import 'room/room_controller.dart';
import 'room/room_models.dart';

void main() {
  final runtime = FunctionPackRuntime(
    signatureVerifier: const DevelopmentSignatureVerifier(),
  );
  runApp(TinniStarApp(runtime: runtime));
}

class TinniStarApp extends StatelessWidget {
  const TinniStarApp({super.key, required this.runtime});

  final FunctionPackRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tinni Star',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFB95CFF),
        scaffoldBackgroundColor: const Color(0xFF100615),
      ),
      home: TinniHome(runtime: runtime),
    );
  }
}

class TinniHome extends StatelessWidget {
  const TinniHome({super.key, required this.runtime});

  final FunctionPackRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tinni Star ✨')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'India Official Room',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'New modular voice-room foundation with Function Pack support.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('open-room'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TinniRoomPage(runtime: runtime),
              ),
            ),
            icon: const Icon(Icons.graphic_eq_rounded),
            label: const Text('Enter Room'),
          ),
        ],
      ),
    );
  }
}

class TinniRoomPage extends StatefulWidget {
  const TinniRoomPage({super.key, required this.runtime});

  final FunctionPackRuntime runtime;

  @override
  State<TinniRoomPage> createState() => _TinniRoomPageState();
}

class _TinniRoomPageState extends State<TinniRoomPage> {
  late final RoomController room;
  late final AnamikaConnector connector;
  final chat = TextEditingController();

  @override
  void initState() {
    super.initState();
    room = RoomController(runtime: widget.runtime)..addListener(_refresh);
    connector = AnamikaConnector(runtime: widget.runtime);
  }

  @override
  void dispose() {
    room.removeListener(_refresh);
    room.dispose();
    chat.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _applyDemoFixPack() {
    final result = connector.installValidatedPack(
      const FunctionPack(
        id: 'room-core',
        version: 1,
        minSchema: 1,
        maxSchema: 1,
        summary: 'Enable 18 seats, free-seat mode and future feature flags.',
        signature: 'TINNI_DEV_SIGNED',
        config: TinniFunctionConfig(
          seatCount: 18,
          inviteMode: false,
          seatLockEnabled: true,
          roomChatEnabled: true,
          giftsEnabled: true,
          maxGiftCombo: 1000,
          ktvEnabled: true,
          gamesEnabled: true,
        ),
      ),
      ownerApproved: true,
    );
    room.refreshFunctionPack();
    _show(result.message);
  }

  @override
  Widget build(BuildContext context) {
    final config = room.config;
    return Scaffold(
      appBar: AppBar(
        title: const Text('India Official Room'),
        actions: [
          IconButton(
            tooltip: 'Apply demo Function Pack',
            onPressed: _applyDemoFixPack,
            icon: const Icon(Icons.extension_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Chip(label: Text(config.inviteMode ? 'Invite mode' : 'Free seat')),
                const SizedBox(width: 8),
                Chip(label: Text(config.seatCount.toString() + ' seats')),
                const Spacer(),
                Icon(room.micState == MicState.live ? Icons.mic : Icons.mic_off),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: GridView.builder(
              key: const Key('seat-grid'),
              padding: const EdgeInsets.all(10),
              itemCount: room.seats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final seat = room.seats[index];
                return InkWell(
                  onTap: () {
                    final message = room.requestOrJoinSeat(index);
                    _show(message);
                    if (room.config.inviteMode && room.mySeat == null) {
                      room.ownerApproveMySeat(index);
                    }
                  },
                  onLongPress: () => room.toggleSeatLock(index),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: const Color(0xFF211027),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          child: seat.locked
                              ? const Icon(Icons.lock_rounded)
                              : Text(
                                  seat.userName?.characters.first ??
                                      (index + 1).toString(),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          seat.userName ??
                              (seat.locked
                                  ? 'Locked'
                                  : 'Seat ' + (index + 1).toString()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: room.mySeat == null ? null : room.leaveSeat,
                    icon: const Icon(Icons.event_seat_outlined),
                    label: Text(room.mySeat == null ? 'Audience' : 'Leave Seat'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: room.mySeat == null ? null : room.toggleMic,
                  icon: Icon(
                    room.micState == MicState.live ? Icons.mic : Icons.mic_off,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: config.giftsEnabled
                      ? () => _show('Gift engine slot ready for server integration.')
                      : null,
                  icon: const Icon(Icons.card_giftcard_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: room.messages.length,
              itemBuilder: (_, index) {
                final message = room.messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(message.author + ': ' + message.text),
                );
              },
            ),
          ),
          if (config.roomChatEnabled)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: chat,
                        decoration: const InputDecoration(
                          hintText: 'Message room…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) {
                          room.sendMessage(chat.text);
                          chat.clear();
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        room.sendMessage(chat.text);
                        chat.clear();
                      },
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
