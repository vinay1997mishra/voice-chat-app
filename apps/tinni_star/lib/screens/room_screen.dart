import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../core/function_pack.dart';
import '../core/connector_security.dart';
import '../discovery/discovery_service.dart';
import '../economy/economy.dart';
import '../effects/effect_queue.dart';
import '../games/game_service.dart';
import '../room/room_controller.dart';
import '../room/room_models.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.state,
    required this.room,
  });

  final TinniState state;
  final RoomSummary room;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with WidgetsBindingObserver {
  late final RoomController controller;
  final chat = TextEditingController();
  bool realtimeJoined = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = RoomController(runtime: widget.state.runtime)
      ..addListener(_refresh);
    _joinRealtime();
  }

  Future<void> _joinRealtime() async {
    await widget.state.realtime.enterRoom(widget.room.id, '10000000');
    if (mounted) setState(() => realtimeJoined = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.state.lifecycle.onBackground(inVoiceRoom: true);
    }
    if (state == AppLifecycleState.resumed) {
      widget.state.lifecycle.onForeground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.state.realtime.exitRoom();
    controller.removeListener(_refresh);
    controller.dispose();
    chat.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleMic() async {
    controller.toggleMic();
    await widget.state.realtime.setMic(
      controller.micState == MicState.live,
    );
    setState(() {});
  }

  void _showGiftSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: GiftService.catalog
              .map(
                (gift) => ListTile(
                  leading: const Icon(Icons.card_giftcard_rounded),
                  title: Text(gift.name),
                  subtitle: Text(
                    gift.price.toString() + ' Coins • ' + gift.effectKind,
                  ),
                  onTap: () {
                    final tx = widget.state.gifts.send(
                      gift: gift,
                      quantity: 1,
                      maxCombo: controller.config.maxGiftCombo,
                      senderId: '10000000',
                      receiverIds: const ['room-owner'],
                    );
                    Navigator.pop(context);
                    if (tx == null) {
                      _snack('Gift failed or balance is insufficient.');
                      return;
                    }
                    widget.state.effects.enqueue(
                      EffectRequest(
                        id: 'gift-' + widget.state.gifts.sent.length.toString(),
                        kind: EffectKind.gift,
                        asset: gift.effectKind + ':' + gift.id,
                        priority: 50,
                      ),
                    );
                    widget.state.activities.addGiftScore(
                      '10000000',
                      tx.totalCost,
                    );
                    widget.state.identity.gainVipExperience(tx.totalCost ~/ 10);
                    _snack(gift.name + ' sent.');
                    setState(() {});
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showOwnerTools() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            const ListTile(
              title: Text(
                'Owner / Admin Controls',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            SwitchListTile(
              title: const Text('Function Pack invite mode'),
              value: controller.config.inviteMode,
              onChanged: null,
              subtitle: const Text(
                'Managed by the active Function Pack.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.extension_rounded),
              title: const Text('Apply room-core Function Pack v1'),
              subtitle: const Text(
                '18 seats + free-seat + KTV + Games',
              ),
              onTap: () {
                var pack = const FunctionPack(
                  id: 'room-core',
                  version: 1,
                  minSchema: 1,
                  maxSchema: 1,
                  summary: 'Expanded room runtime',
                  signature: '',
                  config: TinniFunctionConfig(
                    seatCount: 18,
                    inviteMode: false,
                    seatLockEnabled: true,
                    roomChatEnabled: true,
                    giftsEnabled: true,
                    maxGiftCombo: 1000,
                    ktvEnabled: true,
                    gamesEnabled: true,
                    cpEnabled: true,
                    familyEnabled: true,
                  ),
                );
                final verifier = widget.state.runtime.signatureVerifier;
                if (verifier is PairingHmacSignatureVerifier) {
                  pack = verifier.sign(pack);
                } else {
                  pack = pack.withSignature('TINNI_DEV_SIGNED');
                }
                final result = widget.state.connector.installValidatedPack(
                  pack,
                  ownerApproved: true,
                );
                controller.refreshFunctionPack();
                Navigator.pop(context);
                _snack(result.message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: const Text('Rollback Function Pack'),
              onTap: () {
                final result = widget.state.connector.rollback(
                  ownerApproved: true,
                );
                controller.refreshFunctionPack();
                Navigator.pop(context);
                _snack(result.message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomTools() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.music_note_rounded),
              title: const Text('KTV'),
              enabled: controller.config.ktvEnabled,
              onTap: controller.config.ktvEnabled
                  ? () {
                      widget.state.ktv.addToQueue(
                        widget.state.ktv.library.first,
                        '10000000',
                      );
                      widget.state.ktv.startNext();
                      Navigator.pop(context);
                      _snack('KTV song started.');
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.casino_rounded),
              title: const Text('Lucky 777'),
              enabled: controller.config.gamesEnabled,
              onTap: controller.config.gamesEnabled
                  ? () {
                      if (widget.state.games.active == null) {
                        widget.state.games.start(
                          GameType.lucky777,
                          const ['10000000'],
                        );
                        final result = widget.state.games.finish();
                        widget.state.wallet.creditCoins(
                          result.rewardCoins,
                          'Lucky 777 reward',
                        );
                      }
                      Navigator.pop(context);
                      _snack('Lucky 777 settled.');
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.rocket_launch_rounded),
              title: const Text('Room Rocket'),
              onTap: () {
                widget.state.rewards.launchRocket(1000);
                widget.state.effects.enqueue(
                  EffectRequest(
                    id: 'rocket-' +
                        widget.state.rewards.rocket.progress.toString(),
                    kind: EffectKind.rocket,
                    asset: 'rocket-level-' +
                        widget.state.rewards.rocket.level.toString(),
                    priority: 90,
                  ),
                );
                Navigator.pop(context);
                _snack(
                  'Rocket level ' +
                      widget.state.rewards.rocket.level.toString(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.title),
            Text(
              'ID ' + widget.room.id + (realtimeJoined ? ' • Connected' : ''),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showOwnerTools,
            icon: const Icon(Icons.admin_panel_settings_rounded),
          ),
          IconButton(
            onPressed: _showRoomTools,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: Row(
              children: [
                Chip(
                  label: Text(
                    config.inviteMode ? 'Apply Mic' : 'Free Mic',
                  ),
                ),
                const SizedBox(width: 6),
                Chip(label: Text(config.seatCount.toString() + ' seats')),
                const Spacer(),
                Text('🪙 ' + widget.state.wallet.coins.toString()),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: GridView.builder(
              key: const Key('tinni-seat-grid'),
              padding: const EdgeInsets.all(10),
              itemCount: controller.seats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final seat = controller.seats[index];
                return GestureDetector(
                  onTap: () {
                    final text = controller.requestOrJoinSeat(index);
                    if (config.inviteMode && controller.mySeat == null) {
                      controller.ownerApproveMySeat(index);
                    }
                    _snack(text);
                  },
                  onLongPress: () => controller.toggleSeatLock(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF211027),
                      borderRadius: BorderRadius.circular(18),
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
                        const SizedBox(height: 5),
                        Text(
                          seat.userName ??
                              (seat.locked
                                  ? 'Locked'
                                  : 'Seat ' + (index + 1).toString()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        controller.mySeat == null ? null : controller.leaveSeat,
                    icon: const Icon(Icons.event_seat_outlined),
                    label: Text(
                      controller.mySeat == null ? 'Audience' : 'Leave Seat',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed: controller.mySeat == null ? null : _toggleMic,
                  icon: Icon(
                    controller.micState == MicState.live
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: config.giftsEnabled ? _showGiftSheet : null,
                  icon: const Icon(Icons.card_giftcard_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              itemCount: controller.messages.length,
              itemBuilder: (_, index) {
                final message = controller.messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(message.author + ': ' + message.text),
                );
              },
            ),
          ),
          if (config.roomChatEnabled)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                          controller.sendMessage(chat.text);
                          chat.clear();
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        controller.sendMessage(chat.text);
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
