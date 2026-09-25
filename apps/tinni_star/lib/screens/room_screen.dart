import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../economy/economy.dart';
import '../effects/effect_queue.dart';
import '../moderation/moderation_service.dart';
import '../room/room_control_service.dart';
import '../room/room_controller.dart';
import '../room/room_models.dart';
import '../room/room_presence_service.dart';
import '../room/seat_layout.dart';
import '../ui/royal_theme.dart';
import 'games_screen.dart';
import 'messages_screen.dart';

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
    final account = widget.state.auth.current;
    if (account == null) return;
    final ownerId = widget.room.ownerId ?? widget.room.id;
    widget.state.roomControls.configureForRoom(ownerId);
    widget.state.roomControls.roomMode =
        widget.room.partyMode == 'Event hosting mode' ? 'event' : 'friends';
    await widget.state.roomSession.open(
      widget.room,
      userId: account.userId,
      authToken: account.authToken,
    );
    widget.state.roomSession.controller?.setInviteMode(
      widget.state.roomControls.settings.micMode == MicMode.apply,
    );
  }

  Color get _roomBackgroundColor {
    switch (widget.state.roomControls.themeId) {
      case 'night-blue':
        return const Color(0xFF03101B);
      case 'rose-gold':
        return const Color(0xFF17090D);
      default:
        return const Color(0xFF03070B);
    }
  }

  RoomRole? get _currentRoomRole {
    final userId = widget.state.auth.current?.userId;
    if (userId == null) return null;
    return widget.state.roomControls.roles[userId];
  }

  bool get _isRoomOwner => _currentRoomRole == RoomRole.owner;

  bool get _canModerateSeats =>
      _currentRoomRole == RoomRole.owner ||
      _currentRoomRole == RoomRole.admin;

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

  Future<void> _leaveSeatAndMute() async {
    controller.leaveSeat();
    await widget.state.roomSession.setMicFromController();
    if (mounted) setState(() {});
  }

  void _insertChatEmoji(String emoji) {
    final selection = chat.selection;
    final text = chat.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final safeStart = start.clamp(0, text.length);
    final safeEnd = end.clamp(safeStart, text.length);
    final next = text.replaceRange(safeStart, safeEnd, emoji);
    chat.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: safeStart + emoji.length,
      ),
    );
  }

  void _showEmojiPicker() {
    const emojis = <String>[
      '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '🥰',
      '😎', '🤩', '🥳', '😇', '🙂', '🙃', '😉', '😋',
      '😜', '🤪', '🤗', '🤭', '🫣', '🤔', '🫡', '😴',
      '😭', '🥺', '😢', '😡', '🤬', '😱', '😳', '🫠',
      '❤️', '🩷', '💖', '💕', '💞', '💔', '🔥', '✨',
      '🎉', '🎊', '🎁', '👑', '🌹', '🌟', '💯', '⚡',
      '👍', '👎', '👏', '🙌', '🙏', '🤝', '💪', '✌️',
      '👌', '🤟', '🤘', '👋', '💋', '🫶', '💃', '🕺',
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Emoji & Emotes',
                    style: TextStyle(
                      color: RoyalPalette.gold,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                  itemCount: emojis.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemBuilder: (_, index) {
                    final emoji = emojis[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _insertChatEmoji(emoji),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 27),
                        ),
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

  Future<void> _openRoomThemeSelector() async {
    if (!_isRoomOwner) {
      _snack('Only the room owner can change room theme.');
      return;
    }

    final controls = widget.state.roomControls;
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (pageContext) {
          var pendingTheme = controls.themeId;
          return StatefulBuilder(
            builder: (pageContext, setPageState) {
              const themes = <(String, String, Color)>[
                ('royal-dark', 'Royal Dark', Color(0xFF03070B)),
                ('night-blue', 'Night Blue', Color(0xFF03101B)),
                ('rose-gold', 'Rose Gold', Color(0xFF17090D)),
              ];
              return Scaffold(
                backgroundColor: RoyalPalette.nearBlack,
                appBar: AppBar(
                  title: const Text(
                    'Room Theme',
                    style: TextStyle(
                      color: RoyalPalette.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                body: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: themes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final theme = themes[index];
                    final active = pendingTheme == theme.$1;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setPageState(() {
                          pendingTheme = theme.$1;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: active
                                ? RoyalPalette.gold
                                : RoyalPalette.bronze,
                            width: active ? 2 : 1,
                          ),
                          color: RoyalPalette.panel,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: theme.$3,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: RoyalPalette.deepGold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                theme.$2,
                                style: const TextStyle(
                                  color: RoyalPalette.cream,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Icon(
                              active
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: active
                                  ? RoyalPalette.gold
                                  : RoyalPalette.muted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                bottomNavigationBar: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(pageContext, pendingTheme);
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Theme'),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    if (!mounted || selected == null) return;
    controls.setTheme(selected);
    setState(() {});
    _snack('Room theme saved.');
  }

    Future<void> _showRoomPowerMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: ListTile(
                  leading: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: RoyalPalette.gold,
                  ),
                  title: const Text('Minimize'),
                  subtitle: const Text('Stay in the room and return to the app.'),
                  onTap: () => Navigator.pop(sheetContext, 'minimize'),
                ),
              ),
              Expanded(
                child: ListTile(
                  leading: const Icon(
                    Icons.exit_to_app_rounded,
                    color: RoyalPalette.gold,
                  ),
                  title: const Text('Exit'),
                  subtitle: const Text('Leave the room immediately.'),
                  onTap: () => Navigator.pop(sheetContext, 'exit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    final session = widget.state.roomSession;

    if (action == 'minimize') {
      session.minimize();
      if (mounted) Navigator.pop(context);
      return;
    }

    if (action == 'exit') {
      await session.close();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  String _familyTagFor(String userId) {
    if (widget.state.family.exists && widget.state.family.isMember(userId)) {
      return widget.state.family.tag ?? widget.state.family.name ?? 'Family';
    }
    return '—';
  }

  String _hostTagFor(String userId) {
    final role = widget.state.roomControls.roles[userId];
    if (role == RoomRole.host) return 'Host';
    if (role == RoomRole.owner) return 'Owner';
    if (role == RoomRole.admin) return 'Admin';
    return '—';
  }

  String _agencyNameFor(String userId) =>
      widget.state.roomControls.agencyNameFor(userId) ?? '—';

  Future<void> _openPrivateMessage(RoomPresenceMember member) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          state: widget.state,
          targetUserId: member.userId,
          targetName: member.displayName,
          targetAvatarDataUrl: member.avatarDataUrl,
        ),
      ),
    );
  }

  Future<void> _showSeatInvitePicker(RoomPresenceMember member) async {
    final available = <int>[
      for (var index = 0; index < controller.seats.length; index++)
        if (!controller.seats[index].occupied && !controller.seats[index].locked)
          index,
    ];
    if (available.isEmpty) {
      _snack('No empty seat is available.');
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite ' + member.displayName + ' to seat',
                style: const TextStyle(
                  color: RoyalPalette.gold,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final index in available)
                    ActionChip(
                      label: Text('Seat ' + (index + 1).toString()),
                      onPressed: () => Navigator.pop(context, index),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    widget.state.roomControls.applyForMic(member.userId, selected);
    final roomId = widget.state.roomSession.room?.id;
    if (roomId != null) {
      await widget.state.realtime.im.sendRoomEvent(roomId, {
        'type': 'seat_invite',
        'userId': member.userId,
        'seat': selected,
      });
    }
    _snack('Seat ' + (selected + 1).toString() + ' invite sent to ' + member.displayName + '.');
  }

  int? _seatIndexForMember(
    RoomPresenceMember member, {
    int? hint,
  }) {
    if (hint != null &&
        hint >= 0 &&
        hint < controller.seats.length &&
        controller.seats[hint].occupied) {
      return hint;
    }
    if (member.seatIndex != null &&
        member.seatIndex! >= 0 &&
        member.seatIndex! < controller.seats.length) {
      return member.seatIndex;
    }
    for (final entry in widget.state.roomControls.seatUsers.entries) {
      if (entry.value == member.userId) return entry.key;
    }
    final byName = controller.seats.indexWhere(
      (seat) => seat.userName == member.displayName,
    );
    return byName < 0 ? null : byName;
  }

  Future<void> _setUserSeatMute(
    RoomPresenceMember member,
    int seatIndex,
    bool muted,
  ) async {
    try {
      await widget.state.roomSession.setUserSeatMute(
        member.userId,
        seatIndex: seatIndex,
        muted: muted,
      );
      controller.setSeatRoomMuted(seatIndex, muted);
      _snack(
        muted
            ? member.displayName + ' muted on this seat.'
            : member.displayName + ' unmuted on this seat.',
      );
      if (mounted) setState(() {});
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

    Future<void> _moveUserToAudience(
    RoomPresenceMember member, {
    int? seatIndexHint,
  }) async {
    final seatIndex = _seatIndexForMember(member, hint: seatIndexHint);
    if (seatIndex == null) {
      _snack(member.displayName + ' is not on a seat.');
      return;
    }
    controller.managerRemoveUserFromSeat(seatIndex);
    widget.state.roomControls.kickFromMic(member.userId);
    final roomId = widget.state.roomSession.room?.id;
    if (roomId != null) {
      await widget.state.realtime.im.sendRoomEvent(roomId, {
        'type': 'seat_remove',
        'userId': member.userId,
        'seat': seatIndex,
      });
    }
    _snack(member.displayName + ' moved to audience.');
  }

  Future<void> _showKickPicker(RoomPresenceMember member) async {
    final duration = await showModalBottomSheet<Duration?>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(title: Text('Kick duration', style: TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900))),
            ListTile(title: const Text('2 hours'), onTap: () => Navigator.pop(context, const Duration(hours: 2))),
            ListTile(title: const Text('6 hours'), onTap: () => Navigator.pop(context, const Duration(hours: 6))),
            ListTile(title: const Text('24 hours'), onTap: () => Navigator.pop(context, const Duration(hours: 24))),
            ListTile(title: const Text('Permanent'), onTap: () => Navigator.pop(context, Duration.zero)),
          ],
        ),
      ),
    );
    if (!mounted || duration == null) return;
    final permanent = duration == Duration.zero;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm kick'),
        content: Text(
          permanent
              ? 'Permanently kick ' + member.displayName + ' from this room?'
              : 'Kick ' + member.displayName + ' for ' + duration.inHours.toString() + ' hours?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Agree')),
        ],
      ),
    );
    if (agreed != true) return;
    final effectiveDuration = permanent ? null : duration;
    widget.state.roomControls.kickFor(member.userId, effectiveDuration);
    try {
      await widget.state.roomSession.kickUser(member.userId, duration: effectiveDuration);
      _snack(permanent
          ? member.displayName + ' permanently kicked.'
          : member.displayName + ' kicked for ' + duration.inHours.toString() + ' hours.');
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _showUserProfile(
    RoomPresenceMember member, {
    int? seatIndexHint,
  }) {
    if (!_canModerateSeats) return;
    if (member.userId == widget.state.auth.current?.userId) return;
    ImageProvider? avatar;
    final avatarData = member.avatarDataUrl;
    if (avatarData != null && avatarData.startsWith('data:image/')) {
      try {
        avatar = MemoryImage(base64Decode(avatarData.split(',').last));
      } catch (_) {
        avatar = null;
      }
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          var currentMember = member;
          for (final item in widget.state.roomSession.liveMembers) {
            if (item.userId == member.userId) {
              currentMember = item;
              break;
            }
          }
          final followed =
              widget.state.social.following.contains(currentMember.userId);
          final seatIndex = _seatIndexForMember(
            currentMember,
            hint: seatIndexHint,
          );
          final seated = seatIndex != null;
          final micMuted = seated && currentMember.micMuted;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: RoyalPalette.panel2,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? Text(member.displayName.isEmpty ? '?' : member.displayName.characters.first.toUpperCase(),
                            style: const TextStyle(color: RoyalPalette.gold, fontSize: 28, fontWeight: FontWeight.w900))
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(currentMember.displayName, style: const TextStyle(color: RoyalPalette.cream, fontSize: 20, fontWeight: FontWeight.w900)),
                  Text('ID ' + currentMember.userId, style: const TextStyle(color: RoyalPalette.muted)),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      Chip(label: Text('Family ' + _familyTagFor(currentMember.userId))),
                      Chip(label: Text('Host ' + _hostTagFor(currentMember.userId))),
                      Chip(label: Text('Agency ' + _agencyNameFor(currentMember.userId))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 82,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _ProfileAction(
                          icon: followed ? Icons.person_remove_rounded : Icons.person_add_rounded,
                          label: followed ? 'Unfollow' : 'Follow',
                          onTap: () {
                            if (followed) { widget.state.social.unfollow(currentMember.userId); } else { widget.state.social.follow(currentMember.userId); }
                            setSheetState(() {});
                          },
                        ),
                        _ProfileAction(
                          icon: Icons.mail_rounded,
                          label: 'Message',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openPrivateMessage(currentMember);
                          },
                        ),
                        if (seated)
                          _ProfileAction(
                            icon: Icons.keyboard_arrow_down_rounded,
                            label: 'Down Seat',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _moveUserToAudience(
                                currentMember,
                                seatIndexHint: seatIndex,
                              );
                            },
                          )
                        else
                          _ProfileAction(
                            icon: Icons.event_seat_rounded,
                            label: 'Seat Invite',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _showSeatInvitePicker(currentMember);
                            },
                          ),
                        _ProfileAction(
                          icon: Icons.card_giftcard_rounded,
                          label: 'Gift',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            Future<void>.delayed(Duration.zero, () {
                              if (mounted) {
                                _showGiftSheet(
                                  preselectedUserId: currentMember.userId,
                                );
                              }
                            });
                          },
                        ),
                        if (seated)
                          _ProfileAction(
                            icon: micMuted
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                            label: micMuted ? 'Unmute' : 'Mute',
                            onTap: () async {
                              await _setUserSeatMute(
                                currentMember,
                                seatIndex,
                                !micMuted,
                              );
                              if (sheetContext.mounted) {
                                setSheetState(() {});
                              }
                            },
                          ),
                        _ProfileAction(
                          icon: Icons.logout_rounded,
                          label: 'Kick',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _showKickPicker(currentMember);
                          },
                        ),
                      ],
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

  void _showGiftSheet({String? preselectedUserId}) {
    final ownerId = widget.room.ownerId ?? widget.room.id;
    final senderId = widget.state.auth.current?.userId;
    if (senderId == null) return;
    if (preselectedUserId != null && preselectedUserId != senderId) {
      _selectedGiftRecipients
        ..clear()
        ..add(preselectedUserId);
    }

    final roomGifts = <GiftDefinition>[
      const GiftDefinition(
        id: 'gold-dragon',
        name: 'Golden Dragon',
        price: 5000,
        effectKind: 'mp4',
      ),
      const GiftDefinition(
        id: 'royal-crown',
        name: 'Royal Crown',
        price: 2500,
        effectKind: 'pag',
      ),
      const GiftDefinition(
        id: 'star-castle',
        name: 'Star Castle',
        price: 12000,
        effectKind: 'mp4',
      ),
      const GiftDefinition(
        id: 'heart-ring',
        name: 'Heart Ring',
        price: 1800,
        effectKind: 'svga',
      ),
      ...GiftService.catalog,
    ];

    List<(String, String)> recipients() {
      final values = <(String, String)>[];
      if (ownerId != senderId) {
        values.add((ownerId, 'Room Owner'));
      }
      for (var index = 0; index < controller.seats.length; index++) {
        final seat = controller.seats[index];
        final name = seat.userName;
        if (name == null) continue;
        final id = name == 'You' ? senderId : 'seat-${index + 1}';
        if (id == senderId) continue;
        if (values.any((item) => item.$1 == id)) continue;
        values.add((id, name));
      }
      for (final member in widget.state.roomSession.liveMembers) {
        if (member.userId == senderId) continue;
        if (values.any((item) => item.$1 == member.userId)) continue;
        values.add((member.userId, member.displayName));
      }
      _selectedGiftRecipients.removeWhere(
        (id) => !values.any((item) => item.$1 == id),
      );
      if (_selectedGiftRecipients.isEmpty && values.isNotEmpty) {
        _selectedGiftRecipients.add(values.first.$1);
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
                  if (roomRecipients.isEmpty)
                    const SizedBox(
                      key: Key('gift-recipient-strip'),
                      height: 88,
                      child: Center(
                        child: Text(
                          'No other user is available for gifting.',
                          style: TextStyle(color: RoyalPalette.muted),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      key: const Key('gift-recipient-strip'),
                      height: 88,
                      child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: roomRecipients.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
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
                      itemCount: roomGifts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.82,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemBuilder: (_, index) {
                        final gift = roomGifts[index];
                        return RoyalPanel(
                          padding: const EdgeInsets.all(8),
                          onTap: () {
                            if (_selectedGiftRecipients.isEmpty) {
                              _snack('Select at least one recipient.');
                              return;
                            }
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
                            if (widget.state.roomControls.effectsEnabled) {
                              widget.state.effects.enqueue(
                                EffectRequest(
                                  id:
                                      'gift-${widget.state.gifts.sent.length}',
                                  kind: EffectKind.gift,
                                  asset: '${gift.effectKind}:${gift.id}',
                                  priority: 50,
                                ),
                              );
                            }
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
        'Games',
        Icons.casino_rounded,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GamesScreen(state: widget.state),
            ),
          );
        },
      ),
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
          if (!_isRoomOwner) {
            _snack('Only the room owner can change room mode.');
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
          if (!_isRoomOwner) {
            _snack('Only the room owner can launch events.');
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
          _openRoomThemeSelector();
        },
      ),
      (
        'Seat Controls',
        Icons.event_seat_rounded,
        () {
          _snack(_canModerateSeats ? 'Tap an empty seat for seat controls.' : 'Tap a free seat to join or apply for mic.');
        },
      ),
      (
        controls.luckyNumberEnabled ? 'Lucky Number On' : 'Lucky Number',
        Icons.confirmation_number_rounded,
        () {
          if (!_isRoomOwner) {
            _snack('Only the room owner can set lucky number.');
            return;
          }
          _showLuckyNumberDialog();
        },
      ),
      (
        controls.groupPkEnabled ? 'Stop Group PK' : 'Group PK',
        Icons.sports_mma_rounded,
        () {
          if (!_isRoomOwner) {
            _snack('Only the room owner can control Group PK.');
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
          if (!_isRoomOwner) {
            _snack('Only the room owner can change visibility.');
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
          if (!_isRoomOwner) {
            _snack('Only the room owner can control public screen.');
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
    if (!_isRoomOwner) {
      _snack('Only the room owner can change room settings.');
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
                    controller.setInviteMode(!value);
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
    final result = await showDialog<int>(
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
              key: const Key('seat-control-lock'),
              leading: Icon(
                seat.locked ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: RoyalPalette.gold,
              ),
              title: Text(seat.locked ? 'Seat Unlock' : 'Seat Lock'),
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
            ListTile(
              key: const Key('seat-control-mute'),
              leading: Icon(
                seat.roomMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: RoyalPalette.gold,
              ),
              title: Text(
                seat.roomMuted ? 'Seat Unmute' : 'Seat Mute',
              ),
              onTap: () async {
                Navigator.pop(context);
                controller.toggleSeatRoomMute(index);
                if (controller.mySeat == index) {
                  await widget.state.roomSession.setMicFromController();
                }
                _snack(
                  seat.roomMuted
                      ? 'Seat ${index + 1} unmuted.'
                      : 'Seat ${index + 1} muted.',
                );
              },
            ),
            if (!seat.occupied && controller.mySeat == null)
              ListTile(
                key: const Key('seat-control-take'),
                leading: const Icon(
                  Icons.event_seat_rounded,
                  color: RoyalPalette.gold,
                ),
                title: const Text('Take Seat'),
                subtitle: const Text(
                  'Owner/Admin can take the seat without Apply Mic.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  final text = controller.managerTakeSeat(index);
                  _snack(text);
                },
              ),
            if (controller.mySeat == index)
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: RoyalPalette.gold,
                ),
                title: const Text('Leave this seat'),
                onTap: () async {
                  Navigator.pop(context);
                  await _leaveSeatAndMute();
                },
              ),
            if (controller.mySeat != null && controller.mySeat != index)
              ListTile(
                key: const Key('seat-control-leave-current'),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: RoyalPalette.gold,
                ),
                title: const Text('Leave current seat'),
                subtitle: Text(
                  'Leave seat ' + (controller.mySeat! + 1).toString() + ' and go to audience.',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _leaveSeatAndMute();
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
          if (_canModerateSeats && occupied) {
            RoomPresenceMember? member;
            final mappedUserId = widget.state.roomControls.seatUsers[index];
            for (final item in widget.state.roomSession.liveMembers) {
              final idMatch = mappedUserId != null && item.userId == mappedUserId;
              final nameMatch = item.displayName == seat.userName;
              if (idMatch || nameMatch) {
                member = item;
                break;
              }
            }
            if (member != null) {
              _showUserProfile(member, seatIndexHint: index);
              return;
            }
          }
          if (_canModerateSeats) {
            _showSeatControls(index);
            return;
          }
          final text = controller.requestOrJoinSeat(index);
          _snack(text);
        },
        onLongPress: () {
          if (_canModerateSeats) {
            _showSeatControls(index);
          } else {
            _snack('Only the room owner or room admin can control seats.');
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
              occupied
                  ? seat.userName!
                  : seat.roomMuted
                      ? 'Muted'
                      : 'Mic ' + (index + 1).toString(),
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
        backgroundColor: _roomBackgroundColor,
        appBar: AppBar(
          backgroundColor: _roomBackgroundColor,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.room.title, style: const TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w900)),
              Text(
                'ID ' +
                    widget.room.id +
                    ' • ' +
                    (widget.state.roomControls.roomMode == 'event'
                        ? 'Event hosting mode'
                        : 'Friends-making Party') +
                    (session.connected ? ' • Connected' : ' • Connecting'),
                style: const TextStyle(fontSize: 10, color: RoyalPalette.muted),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('room-power-button'),
              tooltip: 'Room options',
              onPressed: _showRoomPowerMenu,
              icon: const Icon(
                Icons.power_settings_new_rounded,
                color: RoyalPalette.gold,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (widget.state.roomControls.noticesVisible)
              Container(
                margin: const EdgeInsets.fromLTRB(10, 2, 10, 7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A2B05), Color(0xFF120C04)],
                  ),
                  border: Border.all(color: RoyalPalette.deepGold),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      color: RoyalPalette.gold,
                      size: 18,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Welcome to Tinni Star Royal Party',
                        style: TextStyle(
                          color: RoyalPalette.cream,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '×250',
                      style: TextStyle(
                        color: RoyalPalette.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      controller.inviteMode ? 'Apply Mic' : 'Free Mic',
                    ),
                  ),
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
              key: const Key('room-live-users'),
              height: 78,
              child: session.liveMembers.isEmpty
                  ? const Center(
                      child: Text(
                        'Waiting for users…',
                        style: TextStyle(
                          color: RoyalPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      scrollDirection: Axis.horizontal,
                      itemCount: session.liveMembers.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 9),
                      itemBuilder: (_, index) {
                        final member = session.liveMembers[index];
                        final isMe =
                            member.userId == widget.state.auth.current?.userId;
                        final initial = member.displayName.trim().isEmpty
                            ? '?'
                            : member.displayName.trim().characters.first;
                        ImageProvider? avatar;
                        final avatarData = member.avatarDataUrl;
                        if (avatarData != null &&
                            avatarData.startsWith('data:image/')) {
                          try {
                            avatar = MemoryImage(
                              base64Decode(avatarData.split(',').last),
                            );
                          } catch (_) {
                            avatar = null;
                          }
                        }
                        return Container(
                          width: 74,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: RoyalPalette.panel.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMe
                                  ? RoyalPalette.gold
                                  : RoyalPalette.bronze,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _canModerateSeats && !isMe
                                    ? () => _showUserProfile(member)
                                    : null,
                                child: CircleAvatar(
                                  radius: 17,
                                  backgroundColor: RoyalPalette.panel2,
                                  backgroundImage: avatar,
                                  child: avatar == null
                                      ? Text(
                                          initial.toUpperCase(),
                                          style: const TextStyle(
                                            color: RoyalPalette.gold,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                (member.flagEmoji.isEmpty
                                        ? ''
                                        : member.flagEmoji + ' ') +
                                    (isMe ? 'You' : member.displayName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: RoyalPalette.cream,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'ID ' + member.userId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: RoyalPalette.muted,
                                  fontSize: 7.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 4),
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
                padding: const EdgeInsets.fromLTRB(0, 6, 6, 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF05080B),
                  border: Border(top: BorderSide(color: RoyalPalette.bronze)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.28,
                      child: TextField(
                        controller: chat,
                        decoration: const InputDecoration(
                          hintText: 'Chat',
                          isDense: true,
                          contentPadding: EdgeInsets.fromLTRB(10, 10, 8, 10),
                        ),
                        onSubmitted: (_) {
                          controller.sendMessage(chat.text);
                          chat.clear();
                        },
                      ),
                    ),
                    IconButton(
                      key: const Key('room-emoji-button'),
                      tooltip: 'Emoji & Emotes',
                      iconSize: 28,
                      padding: const EdgeInsets.all(9),
                      constraints: const BoxConstraints(
                        minWidth: 46,
                        minHeight: 46,
                      ),
                      onPressed: _showEmojiPicker,
                      icon: const Icon(
                        Icons.emoji_emotions_rounded,
                        color: RoyalPalette.gold,
                      ),
                    ),
                    IconButton(
                      key: const Key('room-mic-button'),
                      iconSize: 28,
                      padding: const EdgeInsets.all(9),
                      constraints: const BoxConstraints(
                        minWidth: 46,
                        minHeight: 46,
                      ),
                      tooltip: widget.state.roomSession.moderationMicMuted
                          ? 'Muted by room owner/admin'
                          : 'Microphone',
                      onPressed: controller.mySeat == null ||
                              widget.state.roomSession.moderationMicMuted
                          ? null
                          : _toggleMic,
                      icon: Icon(
                        controller.micState == MicState.live
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        color: controller.mySeat == null ||
                                widget.state.roomSession.moderationMicMuted
                            ? RoyalPalette.muted
                            : RoyalPalette.gold,
                      ),
                    ),
                    IconButton(
                      key: const Key('room-gift-button'),
                      tooltip: 'Gifts',
                      iconSize: 31,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: config.giftsEnabled ? _showGiftSheet : null,
                      icon: const Icon(
                        Icons.card_giftcard_rounded,
                        color: RoyalPalette.gold,
                      ),
                    ),
                    IconButton(
                      key: const Key('room-tools-grid-button'),
                      tooltip: 'More',
                      iconSize: 28,
                      padding: const EdgeInsets.all(9),
                      constraints: const BoxConstraints(
                        minWidth: 46,
                        minHeight: 46,
                      ),
                      onPressed: _showRoomTools,
                      icon: const Icon(
                        Icons.grid_view_rounded,
                        color: RoyalPalette.gold,
                      ),
                    ),
                    if (controller.inviteMode)
                      IconButton(
                        key: const Key('room-seat-button'),
                        tooltip: 'Seat request',
                        iconSize: 28,
                        padding: const EdgeInsets.all(9),
                        constraints: const BoxConstraints(
                          minWidth: 46,
                          minHeight: 46,
                        ),
                        onPressed: () async {
                          if (controller.mySeat == null) {
                            _snack('Tap any mic seat to send a seat request.');
                          } else {
                            await _leaveSeatAndMute();
                          }
                        },
                        icon: const Icon(
                          Icons.event_seat_rounded,
                          color: RoyalPalette.gold,
                        ),
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

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: RoyalPalette.panel2,
                child: Icon(icon, color: RoyalPalette.gold, size: 20),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: RoyalPalette.cream, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
