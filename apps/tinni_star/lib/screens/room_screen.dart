import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../economy/economy.dart';
import '../effects/effect_queue.dart';
import '../moderation/moderation_service.dart';
import '../room/room_control_service.dart';
import '../room/room_controller.dart';
import '../room/room_models.dart';
import '../room/seat_layout.dart';
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
  final Set<String> _selectedGiftRecipients = <String>{};
  RoomController get controller => widget.state.roomSession.controller!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.roomSession.addListener(_refresh);
    _selectedGiftRecipients.add(widget.room.ownerId ?? widget.room.id);
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

  Future<void> _openRoom() async {
    final ownerId = widget.room.ownerId ?? widget.room.id;
    widget.state.roomControls.configureForRoom(ownerId);
    widget.state.roomControls.roomMode =
        widget.room.partyMode == 'Event hosting mode' ? 'event' : 'friends';
    await widget.state.roomSession.open(
      widget.room,
      userId: widget.state.auth.current?.userId ?? '10000000',
    );
  }

  bool get _canManageRoom {
    final userId = widget.state.auth.current?.userId ?? '10000000';
    final role = widget.state.roomControls.roles[userId];
    return role == RoomRole.owner || role == RoomRole.admin;
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
    final ownerId = widget.room.ownerId ?? widget.room.id;
    final senderId = widget.state.auth.current?.userId ?? '10000000';

    List<(String, String)> recipients() {
      final values = <(String, String)>[(ownerId, 'Room Owner')];
      for (var index = 0; index < controller.seats.length; index++) {
        final seat = controller.seats[index];
        final name = seat.userName;
        if (name == null) continue;
        final id = name == 'You' ? senderId : 'seat-${index + 1}';
        if (id == senderId) continue;
        values.add((id, name));
      }
      return values;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final roomRecipients = recipients();
          return SafeArea(
            child: SizedBox(
              height: 470,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Gift',
                          style: TextStyle(
                            color: RoyalPalette.gold,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Spacer(),
                        Text(
                          'Normal   Popular   Luxury',
                          style: TextStyle(
                            color: RoyalPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    key: const Key('gift-recipient-strip'),
                    height: 88,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: roomRecipients.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, index) {
                        final recipient = roomRecipients[index];
                        final selected =
                            _selectedGiftRecipients.contains(recipient.$1);
                        return InkWell(
                          key: Key('gift-recipient-${recipient.$1}'),
                          onTap: () {
                            setSheetState(() {
                              if (selected) {
                                if (_selectedGiftRecipients.length > 1) {
                                  _selectedGiftRecipients.remove(recipient.$1);
                                }
                              } else {
                                _selectedGiftRecipients.add(recipient.$1);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(32),
                          child: SizedBox(
                            width: 66,
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: RoyalPalette.panel2,
                                    border: Border.all(
                                      color: selected
                                          ? RoyalPalette.gold
                                          : RoyalPalette.bronze,
                                      width: selected ? 3 : 1.5,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: RoyalPalette.gold
                                                  .withValues(alpha: 0.28),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : const [],
                                  ),
                                  child: Icon(
                                    index == 0
                                        ? Icons.workspace_premium_rounded
                                        : Icons.person_rounded,
                                    color: RoyalPalette.gold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  recipient.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected
                                        ? RoyalPalette.cream
                                        : RoyalPalette.muted,
                                    fontSize: 9,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: GiftService.catalog.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                              senderId: senderId,
                              receiverIds:
                                  _selectedGiftRecipients.toList(growable: false),
                            );
                            if (tx == null) {
                              _snack(
                                'Gift failed, select a recipient or check balance.',
                              );
                              return;
                            }
                            Navigator.pop(context);
                            widget.state.effects.enqueue(
                              EffectRequest(
                                id:
                                    'gift-${widget.state.gifts.sent.length}',
                                kind: EffectKind.gift,
                                asset: '${gift.effectKind}:${gift.id}',
                                priority: 50,
                              ),
                            );
                            widget.state.activities
                                .addGiftScore(senderId, tx.totalCost);
                            widget.state.identity
                                .gainVipExperience(tx.totalCost ~/ 10);
                            _snack(
                              '${gift.name} sent to ${tx.receiverIds.length} user(s).',
                            );
                            setState(() {});
                          },
                          child: Column(
                            children: [
                              const Expanded(
                                child: Icon(
                                  Icons.card_giftcard_rounded,
                                  color: RoyalPalette.gold,
                                  size: 38,
                                ),
                              ),
                              Text(
                                gift.name,
                                style: const TextStyle(
                                  color: RoyalPalette.cream,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '🪙 ${gift.price}',
                                style: const TextStyle(
                                  color: RoyalPalette.gold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRoomTools() {
    final controls = widget.state.roomControls;
    final tools = <(String, IconData, VoidCallback)>[
      (
        controls.soundEnabled ? 'Sound On' : 'Sound Off',
        controls.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        () {
          final enabled = controls.toggleSound();
          _snack('Room sound ${enabled ? "enabled" : "muted"}.');
        },
      ),
      (
        controls.roomMode == 'friends' ? 'Friends Mode' : 'Event Mode',
        Icons.meeting_room_rounded,
        () {
          if (!_canManageRoom) {
            _snack('Only the room owner or room admin can change room mode.');
            return;
          }
          final mode = controls.toggleRoomMode();
          widget.state.discovery.editRoom(
            widget.room.id,
            partyMode: mode == 'event' ? 'Event hosting mode' : 'Friends-making Party',
          );
          _snack(mode == 'event' ? 'Event hosting mode enabled.' : 'Friends-making Party mode enabled.');
        },
      ),
      (
        controls.eventActive ? 'Stop Event' : 'Launch Event',
        Icons.celebration_rounded,
        () {
          if (!_canManageRoom) {
            _snack('Only the room owner or room admin can launch events.');
            return;
          }
          final active = controls.toggleEvent();
          _snack(active ? 'Room event launched.' : 'Room event stopped.');
        },
      ),
      (
        controls.effectsEnabled ? 'Block Effects' : 'Allow Effects',
        Icons.hide_image_rounded,
        () {
          final enabled = controls.toggleEffects();
          _snack(enabled ? 'Gift effects enabled.' : 'Gift effects blocked.');
        },
      ),
      (
        controls.noticesVisible ? 'Hide Notice' : 'Show Notice',
        Icons.visibility_off_rounded,
        () {
          final visible = controls.toggleNotices();
          _snack(visible ? 'Room notice visible.' : 'Room notice hidden.');
        },
      ),
      (
        'Room Theme',
        Icons.checkroom_rounded,
        () {
          if (!_canManageRoom) {
            _snack('Only the room owner or room admin can change room theme.');
            return;
          }
          final theme = controls.cycleTheme();
          _snack('Room theme changed to $theme.');
        },
      ),
      (
        'Seat Controls',
        Icons.event_seat_rounded,
        () {
          _snack(_canManageRoom ? 'Long-press a seat for manual lock/unlock controls.' : 'Tap a free seat to join or apply for mic.');
        },
      ),
      (
        controls.luckyNumberEnabled ? 'Lucky Number On' : 'Lucky Number',
        Icons.confirmation_number_rounded,
        () {
          if (!_canManageRoom) {
            _snack('Only the room owner or room admin can set lucky number.');
            return;
          }
          _showLuckyNumberDialog();
        },
      ),
      (
        controls.groupPkEnabled ? 'Stop Group PK' : 'Group PK',
        Icons.sports_mma_rounded,
        () {
          if (!_canManageRoom) {
            _snack('Only the room owner or room admin can control Group PK.');
            return;
          }
          final enabled = controls.toggleGroupPk();
          _snack(enabled ? 'Group PK enabled.' : 'Group PK disabled.');
        },
      ),
      (
        controls.settings.visibility == RoomVisibility.publicRoom ? 'Room Open' : 'Room Private',
        controls.settings.visibility == RoomVisibility.publicRoom ? Icons.lock_open_rounded : Icons.lock_rounded,
        () {
          if (!_canManageRoom) {
            _snack('Only the room owner or room admin can change visibility.');
            return;
          }
          final current = controls.settings;
          final next = current.visibility == RoomVisibility.publicRoom ? RoomVisibility.privateRoom : RoomVisibility.publicRoom;
          controls.settings = current.copyWith(visibility: next);
          _snack(next == RoomVisibility.publicRoom ? 'Room is public.' : 'Room is private.');
        },
      ),
      (
        controls.publicScreenEnabled ? 'Screen On' : 'Public Screen',
        Icons.tv_rounded,
        () {
          if (!_canManageRoom) {
            _snack('Only the room owner or room admin can control public screen.');
            return;
          }
          final enabled = controls.togglePublicScreen();
          _snack(enabled ? 'Public screen enabled.' : 'Public screen disabled.');
        },
      ),
      ('Settings', Icons.settings_rounded, _showRoomSettings),
      (
        'Report',
        Icons.report_rounded,
        () {
          final reporter = widget.state.auth.current?.userId ?? '10000000';
          final target = widget.room.ownerId ?? widget.room.id;
          widget.state.moderation.report(
            UserReport(
              reporterId: reporter,
              targetId: target,
              category: ReportCategory.other,
              details: 'Room report for ${widget.room.id}',
            ),
          );
          _snack('Room report submitted.');
        },
      ),
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
              childAspectRatio: 0.88,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (_, index) {
              final tool = tools[index];
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  tool.$3();
                  if (mounted) setState(() {});
                },
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: RoyalPalette.panel2,
                      child: Icon(tool.$2, color: RoyalPalette.gold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tool.$1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showRoomSettings() {
    final controls = widget.state.roomControls;
    if (!_canManageRoom) {
      _snack('Room settings are available only to the room owner or room admin.');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final settings = controls.settings;
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              children: [
                const ListTile(
                  title: Text(
                    'Room Settings',
                    style: TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Public room'),
                  subtitle: const Text('Turn off to make the room private.'),
                  value: settings.visibility == RoomVisibility.publicRoom,
                  onChanged: (value) {
                    controls.settings = settings.copyWith(
                      visibility: value ? RoomVisibility.publicRoom : RoomVisibility.privateRoom,
                    );
                    setSheetState(() {});
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Free mic'),
                  subtitle: const Text('When off, users send a mic request and wait for approval.'),
                  value: settings.micMode == MicMode.free,
                  onChanged: (value) {
                    controls.settings = settings.copyWith(
                      micMode: value ? MicMode.free : MicMode.apply,
                    );
                    setSheetState(() {});
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Only managers can speak'),
                  value: settings.onlyManagersCanSpeak,
                  onChanged: (value) {
                    controls.settings = settings.copyWith(onlyManagersCanSpeak: value);
                    setSheetState(() {});
                    setState(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showLuckyNumberDialog() async {
    final controls = widget.state.roomControls;
    final numberController = TextEditingController(
      text: controls.luckyNumber?.toString() ?? '',
    );
    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lucky Number'),
        content: TextField(
          controller: numberController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Enter lucky number', hintText: 'e.g. 777'),
        ),
        actions: [
          if (controls.luckyNumberEnabled)
            TextButton(
              onPressed: () => Navigator.pop(context, -1),
              child: const Text('Turn Off'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(numberController.text.trim());
              if (value == null || value < 0) return;
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    numberController.dispose();
    if (result == null) return;
    if (result == -1) {
      if (controls.luckyNumberEnabled) controls.toggleLuckyNumber();
      _snack('Lucky number disabled.');
    } else {
      controls.setLuckyNumber(result);
      _snack('Lucky number set to $result.');
    }
    if (mounted) setState(() {});
  }
  void _showSeatControls(int index) {
    if (index < 0 || index >= controller.seats.length) return;
    final seat = controller.seats[index];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                seat.locked ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: RoyalPalette.gold,
              ),
              title: Text(seat.locked ? 'Unlock seat' : 'Lock seat'),
              subtitle: const Text('Manual room control only'),
              onTap: () {
                Navigator.pop(context);
                controller.toggleSeatLock(index);
                _snack(
                  seat.locked
                      ? 'Seat ${index + 1} unlocked.'
                      : 'Seat ${index + 1} locked.',
                );
              },
            ),
            if (controller.mySeat == index)
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: RoyalPalette.gold),
                title: const Text('Leave this seat'),
                onTap: () {
                  Navigator.pop(context);
                  controller.leaveSeat();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatRow({
    required int row,
    required SeatLayoutSpec spec,
    required double seatDiameter,
  }) {
    final range = spec.rangeForRow(row);
    return Row(
      key: Key('seat-row-' + row.toString()),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = range.$1; index < range.$2; index++)
          _buildSeat(
            index: index,
            seatDiameter: seatDiameter,
          ),
      ],
    );
  }

  Widget _buildSeat({
    required int index,
    required double seatDiameter,
  }) {
    final seat = controller.seats[index];
    final occupied = seat.userName != null;
    final compact = seatDiameter < 44;
    final labelWidth = (seatDiameter + (compact ? 8 : 16))
        .clamp(38.0, 78.0)
        .toDouble();

    return SizedBox(
      key: Key('seat-' + index.toString()),
      width: labelWidth,
      child: GestureDetector(
        onTap: () {
          final text = controller.requestOrJoinSeat(index);
          _snack(text);
        },
        onLongPress: () {
          if (_canManageRoom) {
            _showSeatControls(index);
          } else {
            _snack('Only the room owner or room admin can lock/unlock seats.');
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: seatDiameter,
              height: seatDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10161C),
                border: Border.all(
                  color: occupied
                      ? RoyalPalette.gold
                      : RoyalPalette.deepGold,
                  width: occupied ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: RoyalPalette.gold.withValues(
                      alpha: occupied ? 0.28 : 0.08,
                    ),
                    blurRadius: compact ? 6 : 12,
                  ),
                ],
              ),
              child: Center(
                child: seat.locked
                    ? Icon(
                        Icons.lock_rounded,
                        color: RoyalPalette.gold,
                        size: seatDiameter * 0.42,
                      )
                    : occupied
                        ? Text(
                            seat.userName!.characters.first,
                            style: TextStyle(
                              color: RoyalPalette.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: seatDiameter * 0.34,
                            ),
                          )
                        : Icon(
                            Icons.star_rounded,
                            color: RoyalPalette.deepGold,
                            size: seatDiameter * 0.42,
                          ),
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              occupied ? seat.userName! : 'Mic ' + (index + 1).toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: occupied ? RoyalPalette.cream : RoyalPalette.muted,
                fontSize: compact ? 7.5 : 9.5,
                height: 1.0,
                fontWeight: occupied ? FontWeight.w800 : FontWeight.w500,
              ),
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
        body: const Center(child: CircularProgressIndicator(color: RoyalPalette.gold)),
      );
    }

    final config = activeController.config;
    final seatSpec = SeatLayoutSpec.forCount(controller.seats.length);
    final screenSize = MediaQuery.sizeOf(context);
    final widthSeatDiameter = seatSpec.seatDiameter(screenSize.width - 8);
    final maxSeatAreaHeight = screenSize.height * 0.38;
    final rowLabelSpace = widthSeatDiameter < 44 ? 16.0 : 22.0;
    final heightSeatDiameter =
        (maxSeatAreaHeight / seatSpec.rows) - rowLabelSpace;
    final seatDiameter = (widthSeatDiameter < heightSeatDiameter
            ? widthSeatDiameter
            : heightSeatDiameter)
        .clamp(28.0, 64.0)
        .toDouble();
    final seatAreaHeight = seatSpec
        .preferredHeight(seatDiameter)
        .clamp(120.0, maxSeatAreaHeight)
        .toDouble();

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
            SizedBox(
              key: const Key('tinni-seat-grid'),
              height: seatAreaHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  children: [
                    for (var row = 0; row < seatSpec.rows; row++)
                      Expanded(
                        child: _buildSeatRow(
                          row: row,
                          spec: seatSpec,
                          seatDiameter: seatDiameter,
                        ),
                      ),
                  ],
                ),
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
              child: ListView.builder(
                key: const Key('room-message-list'),
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
