import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../core/connector_security.dart';
import '../core/function_pack.dart';
import '../discovery/discovery_service.dart';
import '../economy/economy.dart';
import '../effects/effect_queue.dart';
import '../room/room_control_service.dart';
import '../room/room_controller.dart';
import '../room/room_models.dart';
import '../ui/royal_theme.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.state, required this.room});
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) session.resume();
      });
    }
  }

  Future<void> _openRoom() async => widget.state.roomSession.open(widget.room);

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
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 360,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text('Gift', style: TextStyle(color: RoyalPalette.gold, fontSize: 20, fontWeight: FontWeight.w900)),
                    Spacer(),
                    Text('Normal   Popular   Luxury', style: TextStyle(color: RoyalPalette.muted, fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: GiftService.catalog.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.82,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemBuilder: (_, index) {
                    final gift = GiftService.catalog[index];
                    return RoyalPanel(
                      padding: const EdgeInsets.all(8),
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
                        widget.state.activities.addGiftScore('10000000', tx.totalCost);
                        widget.state.identity.gainVipExperience(tx.totalCost ~/ 10);
                        _snack(gift.name + ' sent.');
                        setState(() {});
                      },
                      child: Column(
                        children: [
                          const Expanded(
                            child: Icon(Icons.card_giftcard_rounded, color: RoyalPalette.gold, size: 38),
                          ),
                          Text(gift.name, style: const TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w800)),
                          Text('🪙 ' + gift.price.toString(), style: const TextStyle(color: RoyalPalette.gold, fontSize: 10)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOwnerTools() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            const ListTile(
              title: Text('Owner / Admin Controls', style: TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900)),
            ),
            ListTile(
              leading: const Icon(Icons.extension_rounded, color: RoyalPalette.gold),
              title: const Text('Apply room-core Function Pack v1'),
              subtitle: const Text('18 seats + free-seat + KTV + Games'),
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
                final result = widget.state.connector.installValidatedPack(pack, ownerApproved: true);
                widget.state.roomSession.refreshFunctionPack();
                Navigator.pop(context);
                _snack(result.message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_rounded, color: RoyalPalette.gold),
              title: const Text('Toggle public / private'),
              subtitle: Text(widget.state.roomControls.settings.visibility.name),
              onTap: () {
                final current = widget.state.roomControls.settings;
                widget.state.roomControls.settings = current.copyWith(
                  visibility: current.visibility == RoomVisibility.publicRoom
                      ? RoomVisibility.privateRoom
                      : RoomVisibility.publicRoom,
                );
                Navigator.pop(context);
                _snack('Room visibility updated.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_external_on_rounded, color: RoyalPalette.gold),
              title: const Text('Toggle free/apply mic'),
              subtitle: Text(widget.state.roomControls.settings.micMode.name),
              onTap: () {
                final current = widget.state.roomControls.settings;
                final next = current.micMode == MicMode.apply ? MicMode.free : MicMode.apply;
                widget.state.roomControls.settings = current.copyWith(micMode: next);
                Navigator.pop(context);
                _snack('Mic mode: ' + next.name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.undo_rounded, color: RoyalPalette.gold),
              title: const Text('Rollback Function Pack'),
              onTap: () {
                final result = widget.state.connector.rollback(ownerApproved: true);
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
    final tools = [
      ('Sound', Icons.volume_up_rounded),
      ('Room mode', Icons.meeting_room_rounded),
      ('Launch event', Icons.celebration_rounded),
      ('Block effects', Icons.hide_image_rounded),
      ('Hide notice', Icons.visibility_off_rounded),
      ('Room theme', Icons.checkroom_rounded),
      ('Seat', Icons.event_seat_rounded),
      ('Lucky number', Icons.confirmation_number_rounded),
      ('Group PK', Icons.sports_mma_rounded),
      ('Room open', Icons.lock_open_rounded),
      ('Public Screen', Icons.tv_rounded),
      ('Setting', Icons.settings_rounded),
      ('Report', Icons.report_rounded),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: tools.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (_, index) {
              final tool = tools[index];
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _snack(tool.$1 + ' selected.');
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: RoyalPalette.panel2,
                      child: Icon(tool.$2, color: RoyalPalette.gold),
                    ),
                    const SizedBox(height: 5),
                    Text(tool.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9)),
                  ],
                ),
              );
            },
          ),
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
        body: const Center(child: CircularProgressIndicator(color: RoyalPalette.gold)),
      );
    }

    final config = activeController.config;
    final columns = controller.seats.length <= 10 ? 5 : 4;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop || !session.hasRoom) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (session.hasRoom) session.minimize();
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF03070B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF03070B),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.room.title, style: const TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w900)),
              Text(
                'ID ' + widget.room.id + ' • ' + widget.room.partyMode + (session.connected ? ' • Connected' : ' • Connecting'),
                style: const TextStyle(fontSize: 10, color: RoyalPalette.muted),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Minimize room',
              onPressed: () {
                session.minimize();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: RoyalPalette.gold),
            ),
            IconButton(
              tooltip: 'Close room',
              onPressed: () async {
                await session.close();
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              icon: const Icon(Icons.close_rounded, color: RoyalPalette.gold),
            ),
            IconButton(
              onPressed: _showOwnerTools,
              icon: const Icon(Icons.admin_panel_settings_rounded, color: RoyalPalette.gold),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(10, 2, 10, 7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [Color(0xFF4A2B05), Color(0xFF120C04)]),
                border: Border.all(color: RoyalPalette.deepGold),
              ),
              child: const Row(
                children: [
                  Icon(Icons.campaign_rounded, color: RoyalPalette.gold, size: 18),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Official room • Welcome to Tinni Star Royal Party',
                      style: TextStyle(color: RoyalPalette.cream, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('×250', style: TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Chip(label: Text(config.inviteMode ? 'Apply Mic' : 'Free Mic')),
                  const SizedBox(width: 6),
                  Chip(label: Text(controller.seats.length.toString() + ' seats')),
                  const Spacer(),
                  Text(
                    '🪙 ' + widget.state.wallet.coins.toString(),
                    style: const TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: GridView.builder(
                key: const Key('tinni-seat-grid'),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                itemCount: controller.seats.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 0.82,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                ),
                itemBuilder: (context, index) {
                  final seat = controller.seats[index];
                  final occupied = seat.userName != null;
                  return GestureDetector(
                    onTap: () {
                      final text = controller.requestOrJoinSeat(index);
                      if (config.inviteMode && controller.mySeat == null) {
                        controller.ownerApproveMySeat(index);
                      }
                      _snack(text);
                    },
                    onLongPress: () => controller.toggleSeatLock(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF10161C),
                            border: Border.all(
                              color: occupied ? RoyalPalette.gold : RoyalPalette.deepGold,
                              width: occupied ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: RoyalPalette.gold.withValues(alpha: occupied ? 0.28 : 0.08),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Center(
                            child: seat.locked
                                ? const Icon(Icons.lock_rounded, color: RoyalPalette.gold)
                                : occupied
                                    ? Text(
                                        seat.userName!.characters.first,
                                        style: const TextStyle(
                                          color: RoyalPalette.gold,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                        ),
                                      )
                                    : const Icon(Icons.star_rounded, color: RoyalPalette.deepGold, size: 22),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          occupied ? seat.userName! : 'Mic ' + (index + 1).toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: occupied ? RoyalPalette.cream : RoyalPalette.muted,
                            fontSize: 10,
                            fontWeight: occupied ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: RoyalPalette.panel.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: RoyalPalette.bronze),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: RoyalPalette.gold, size: 17),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.state.roomControls.settings.topic.isEmpty
                          ? 'Ask your followers to support the room.'
                          : widget.state.roomControls.settings.topic,
                      style: const TextStyle(color: RoyalPalette.muted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 4),
                itemCount: controller.messages.length,
                itemBuilder: (_, index) {
                  final message = controller.messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: message.author + ': ',
                            style: const TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: message.text, style: const TextStyle(color: RoyalPalette.cream)),
                        ],
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF05080B),
                  border: Border(top: BorderSide(color: RoyalPalette.bronze)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _showRoomTools,
                      icon: const Icon(Icons.more_horiz_rounded, color: RoyalPalette.gold),
                    ),
                    Expanded(
                      child: TextField(
                        controller: chat,
                        decoration: const InputDecoration(hintText: 'Chat', isDense: true),
                        onSubmitted: (_) {
                          controller.sendMessage(chat.text);
                          chat.clear();
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: controller.mySeat == null ? null : _toggleMic,
                      icon: Icon(
                        controller.micState == MicState.live ? Icons.mic_rounded : Icons.mic_off_rounded,
                        color: controller.mySeat == null ? RoyalPalette.muted : RoyalPalette.gold,
                      ),
                    ),
                    IconButton(
                      onPressed: config.giftsEnabled ? _showGiftSheet : null,
                      icon: const Icon(Icons.card_giftcard_rounded, color: RoyalPalette.gold),
                    ),
                    IconButton(
                      onPressed: () {
                        if (controller.mySeat == null) {
                          _snack('Tap any mic seat to join.');
                        } else {
                          controller.leaveSeat();
                        }
                      },
                      icon: const Icon(Icons.event_seat_rounded, color: RoyalPalette.gold),
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
