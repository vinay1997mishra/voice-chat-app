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
import '../room/room_control_service.dart';

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
  final chat = TextEditingController();

  RoomController get controller => widget.state.roomSession.controller!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.roomSession.addListener(_refresh);
    final session = widget.state.roomSession;
    if (session.room?.id != widget.room.id || session.controller == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openRoom();
      });
    } else {
      session.resume();
    }
  }

  Future<void> _openRoom() async {
    await widget.state.roomSession.open(widget.room);
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
    widget.state.roomSession.removeListener(_refresh);
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
    await widget.state.roomSession.setMicFromController();
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
                widget.state.roomSession.refreshFunctionPack();
                Navigator.pop(context);
                _snack(result.message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_rounded),
              title: const Text('Toggle public / private'),
              subtitle: Text(
                widget.state.roomControls.settings.visibility.name,
              ),
              onTap: () {
                final current = widget.state.roomControls.settings;
                widget.state.roomControls.settings = current.copyWith(
                  visibility:
                      current.visibility == RoomVisibility.publicRoom
                          ? RoomVisibility.privateRoom
                          : RoomVisibility.publicRoom,
                );
                Navigator.pop(context);
                _snack('Room visibility updated.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.how_to_reg_rounded),
              title: const Text('Cycle join policy'),
              subtitle: Text(
                widget.state.roomControls.settings.joinPolicy.name,
              ),
              onTap: () {
                final current = widget.state.roomControls.settings;
                final values = JoinPolicy.values;
                final next = values[
                    (current.joinPolicy.index + 1) % values.length];
                widget.state.roomControls.settings =
                    current.copyWith(joinPolicy: next);
                Navigator.pop(context);
                _snack('Join policy: ' + next.name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_external_on_rounded),
              title: const Text('Toggle free/apply mic'),
              subtitle: Text(widget.state.roomControls.settings.micMode.name),
              onTap: () {
                final current = widget.state.roomControls.settings;
                final next = current.micMode == MicMode.apply
                    ? MicMode.free
                    : MicMode.apply;
                widget.state.roomControls.settings =
                    current.copyWith(micMode: next);
                Navigator.pop(context);
                _snack('Mic mode: ' + next.name);
              },
            ),
            SwitchListTile(
              title: const Text('Only managers can speak'),
              value:
                  widget.state.roomControls.settings.onlyManagersCanSpeak,
              onChanged: (value) {
                final current = widget.state.roomControls.settings;
                widget.state.roomControls.settings =
                    current.copyWith(onlyManagersCanSpeak: value);
                Navigator.pop(context);
                _snack('Speaking policy updated.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.topic_rounded),
              title: const Text('Set room topic/theme/BGM'),
              subtitle: Text(
                widget.state.roomControls.settings.topic.isEmpty
                    ? 'No topic'
                    : widget.state.roomControls.settings.topic,
              ),
              onTap: () {
                final current = widget.state.roomControls.settings;
                widget.state.roomControls.settings = current.copyWith(
                  topic: 'Tinni Star Official Topic',
                  backgroundId: 'tinni-purple-room',
                  bgmId: 'tinni-room-bgm',
                );
                Navigator.pop(context);
                _snack('Topic, room background and BGM state updated.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: const Text('Rollback Function Pack'),
              onTap: () {
                final result = widget.state.connector.rollback(
                  ownerApproved: true,
                );
                widget.state.roomSession.refreshFunctionPack();
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
    final session = widget.state.roomSession;
    final activeController = session.controller;
    if (activeController == null || session.room?.id != widget.room.id) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.room.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final config = activeController.config;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop || !session.hasRoom) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (session.hasRoom) session.minimize();
        });
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.title),
            Text(
              'ID ' +
                  widget.room.id +
                  (widget.state.roomSession.connected
                      ? ' • Connected'
                      : widget.state.roomSession.connectionError != null
                          ? ' • Permission needed'
                          : ' • Connecting'),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Minimize room',
            onPressed: () {
              widget.state.roomSession.minimize();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          IconButton(
            tooltip: 'Close room',
            onPressed: () async {
              await widget.state.roomSession.close();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close_rounded),
          ),
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
    ),
    );
  }
}
