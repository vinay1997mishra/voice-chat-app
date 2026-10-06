import 'dart:math' as math;
import 'dart:async';
import '../infra/request_budget.dart';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../ui/stable_image_provider.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../app/tinni_state.dart';
import '../discovery/discovery_service.dart';
import '../economy/economy.dart';
import '../economy/premium_gift_catalog.dart';
import '../effects/gift_scene_overlay.dart';
import '../effects/effect_overlay.dart';
import '../effects/rocket_launch.dart';
import '../effects/cinematic_lane.dart';
import '../effects/lucky_combo_timer.dart';
import '../effects/lucky_gift_queue.dart';
import '../effects/lucky_gift_overlay.dart';
import '../identity/owner_tag.dart';
import '../media/ktv_service.dart';
import '../moderation/user_safety_menu.dart';
import '../room/room_control_service.dart';
import '../room/room_controller.dart';
import '../room/room_models.dart';
import '../room/room_presence_service.dart';
import '../room/seat_layout.dart';
import '../ui/royal_theme.dart';
import '../ui/room_emotion_backdrop.dart';
import '../ui/animated_avatar_frame.dart';
import '../ui/rocket_rewards_panel.dart';
import '../ui/rocket_personal_reward.dart';
import '../ui/rocket_launch_banner.dart';
import '../ui/premium_effects.dart';
import 'fruit_jackpot_panel.dart';
import 'fruit_party_panel.dart';
import 'ludo_screen.dart';
import 'messages_screen.dart';
import 'recharge_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.state, required this.room});
  final TinniState state;
  final RoomSummary room;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with WidgetsBindingObserver {
  final chat = TextEditingController();
  final _giftScenes = GiftSceneQueue();
  final _cinematicLane = CinematicLane();
  final ScrollController _roomMessageScrollController = ScrollController();
  final ScrollController _rocketLevelScrollController = ScrollController();
  int _lastRoomMessageCount = 0;
  int? _lastCommentsClearVersion;
  String? _roomLockPassword;
  final Set<String> _selectedGiftRecipients = <String>{};
  GiftDefinition? _seatGiftEffect;
  final Set<String> _seatGiftEffectReceiverIds = <String>{};
  GiftDefinition? _luckySeatEffectGift;
  final _handledGiftVisualEventIds = <String>{};
  late final _luckyVisuals = LuckyGiftQueue(clock: () => widget.state.roomSession.presence.serverNowMs);
  final _luckyComboTimer = LuckyComboTimer();
  int _seatGiftEffectSequence = 0;
  Timer? _seatGiftEffectTimer;
  GiftDefinition? _luckyComboGift;
  List<String> _luckyComboRecipients = <String>[];
  int _luckyComboQuantity = 1;
  int _luckyComboCount = 0;
  int _luckyComboWon = 0;
  int _luckyComboSent = 0;
  int _luckyLastMultiplier = 0;
  int _luckyPoolBalance = 0;
  int _luckyAnimationSequence = 0;
  final Set<String> _luckyAnimationReceiverIds = <String>{};
  bool _luckyComboSending = false;
  String? _luckySessionId;
  int _luckySessionHighest = 0;
  Timer? _luckyBubbleTimer;
  int get _luckyComboSecondsLeft => _luckyComboTimer.secondsLeft;
  Timer? _emoteExpiryTimer;
  int? _handledSeatInviteCreatedAtMs;
  bool _seatInviteDialogOpen = false;
  bool _fruitJackpotOpen = false;
  bool _fruitPartyOpen = false;
  String? _roomTitleOverride;
  String? _roomPhotoOverride;
  String? _roomAnnouncementOverride;
  String? _cachedRoomPhotoSource;
  ImageProvider? _cachedRoomPhotoProvider;
  String? _cachedThemeSource;
  ImageProvider? _cachedThemeProvider;
  final Map<String, ImageProvider> _avatarProviderCache =
      <String, ImageProvider>{};
  Future<Map<String, dynamic>>? _roomSendingSummaryFuture;
  Map<String, dynamic> _lastRoomSendingSummary = <String, dynamic>{
    'lifetime_total': 0, 'ranking': const <Map<String, dynamic>>[],
  };
  bool _roomSendingRefreshRunning = false;
  final _rocketCompleted = ValueNotifier<int?>(null);
  int? _selectedRocketPreviewLevel;
  Timer? _rocketBannerPoll;
  bool _ribbonFetchRunning = false;
  Timer? _roomRecoveryTimer;
  bool _roomRecoveryRunning = false;
  int _roomRecoveryFailures = 0;
  static const List<int> _rocketStageTargets = <int>[
    8000000,
    15000000,
    30000000,
    50000000,
    90000000,
    150000000,
    200000000,
    250000000,
    350000000,
    500000000,
  ];
  final List<Map<String, dynamic>> _ribbonQueue = <Map<String, dynamic>>[];
  final Set<String> _seenRibbonIds = <String>{};
  final Set<String> _seenEntranceKeys = <String>{};
  final List<RoomPresenceMember> _entranceQueue = <RoomPresenceMember>[];
  RoomPresenceMember? _activeEntrance;
  final DateTime _screenOpenedAtUtc = DateTime.now().toUtc();
  RoomController get controller => widget.state.roomSession.controller!;

  RoomSummary get _roomSnapshot {
    for (final room in widget.state.discovery.rooms) {
      if (room.id == widget.room.id) return room;
    }
    return widget.room;
  }

  String get _roomTitle => _roomTitleOverride ?? _roomSnapshot.title;
  String? get _roomPhotoDataUrl =>
      _roomPhotoOverride ?? _roomSnapshot.photoDataUrl;
  String get _roomAnnouncement =>
      _roomAnnouncementOverride ?? _roomSnapshot.announcement;

  ImageProvider? get _roomPhotoProvider {
    final value = _roomPhotoDataUrl?.trim() ?? '';
    if (value.isEmpty) {
      _cachedRoomPhotoSource = null;
      _cachedRoomPhotoProvider = null;
      return null;
    }
    if (_cachedRoomPhotoSource == value) {
      return _cachedRoomPhotoProvider;
    }

    ImageProvider? provider;
    if (value.startsWith('data:image/')) {
      try {
        provider = stableImageProvider(value);
      } catch (_) {
        provider = null;
      }
    } else if (value.startsWith('https://') || value.startsWith('http://')) {
      provider = stableImageProvider(value);
    }

    _cachedRoomPhotoSource = value;
    _cachedRoomPhotoProvider = provider;
    return provider;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.roomSession.addListener(_refresh);
    _luckyComboTimer.addListener(_onLuckyComboTimer);
    widget.state.social.retainMessageEvents();
    widget.state.social.roomEvents.addListener(_onCountryRibbonEvent);
    _primeRoomSendingSummary();
    _rocketBannerPoll = Timer.periodic(RequestBudget.ribbonFallback, (_) {
      if (!widget.state.social.messageEventsConnected &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _refreshCountryRibbons();
      }
    });
    widget.state.social.unreadMessages.addListener(_refresh);
    final account = widget.state.auth.current;
    if (account != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.state.social.connectMessageEvents(account.authToken);
      });
    }
    _selectedGiftRecipients.add(widget.room.ownerId ?? widget.room.id);
    final session = widget.state.roomSession;
    if (session.room?.id != widget.room.id || !session.backendSessionActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openRoom();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) session.resume();
      });
    }
  }

  Future<Map<String, dynamic>> _loadRoomSendingSummary() async {
    final account = widget.state.auth.current;
    if (account == null) {
      return <String, dynamic>{
        'lifetime_total': 0,
        'ranking': const <Map<String, dynamic>>[],
      };
    }
    try {
      final summary = await widget.state.discovery.roomGiftRanking(
        authToken: account.authToken,
        roomId: widget.room.id,
        period: 'day',
      );
      if (mounted) {
        final completed = completedRocketStages((summary['lifetime_total'] as num? ?? 0).toInt());
        final previous = _rocketCompleted.value;
        if (previous == null || completed > previous) _rocketCompleted.value = completed;
      }
      if (_giftInt(summary['lifetime_total']) >=
          _giftInt(_lastRoomSendingSummary['lifetime_total'])) {
        _lastRoomSendingSummary = summary;
      }
      return _lastRoomSendingSummary;
    } catch (_) {
      // A failed read never clears a previously displayed rocket or ranking.
      return _lastRoomSendingSummary;
    }
  }

  Future<void> _refreshRocketRewardWallet() async {
    try {
      await widget.state.refreshAuthenticatedAccount(force: true);
    } catch (_) {
      // A display refresh never affects the already settled server reward.
    }
  }

  Future<RocketPersonalReward?> _loadPersonalRocketReward(int level) async {
    final account = widget.state.auth.current;
    if (account == null) return null;
    for (var attempt = 0; attempt < 3; attempt++) {
      final response = await widget.state.discovery.personalRocketReward(
        authToken: account.authToken, roomId: widget.room.id, level: level,
      );
      if (!mounted || widget.state.auth.current?.userId != account.userId) {
        return null;
      }
      final reward = RocketPersonalReward.fromResponse(
        response, viewerId: account.userId, level: level,
      );
      if (reward != null) {
        unawaited(_refreshRocketRewardWallet());
        return reward;
      }
      if (response['settled'] == true) return null;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  void _primeRoomSendingSummary() {
    _roomSendingSummaryFuture = _loadRoomSendingSummary();
  }

  bool _applyRoomSendingSummary(dynamic raw) {
    if (raw is! Map || !mounted) return false;
    final summary = Map<String, dynamic>.from(raw);
    if (summary['room_id']?.toString() != widget.room.id) return false;
    if (_giftInt(summary['lifetime_total']) <
        _giftInt(_lastRoomSendingSummary['lifetime_total'])) { return true; }
    _lastRoomSendingSummary = {..._lastRoomSendingSummary, ...summary};
    final completed = completedRocketStages(_giftInt(summary['lifetime_total']));
    if (_rocketCompleted.value == null || completed > _rocketCompleted.value!) {
      _rocketCompleted.value = completed;
    }
    setState(() {
      _roomSendingSummaryFuture = Future.value(_lastRoomSendingSummary);
    });
    return true;
  }

  void _refreshRoomSendingSummary() {
    if (!mounted || _roomSendingRefreshRunning) return;
    _roomSendingRefreshRunning = true;
    final next = _loadRoomSendingSummary().whenComplete(() {
      _roomSendingRefreshRunning = false;
    });
    setState(() => _roomSendingSummaryFuture = next);
  }

  Offset _giftFlightOriginOffset(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return Offset.zero;
    }
    final screen = MediaQuery.sizeOf(context);
    final screenCenterGlobal = Offset(screen.width / 2, screen.height / 2);
    final screenCenterLocal = renderObject.globalToLocal(screenCenterGlobal);
    return screenCenterLocal - renderObject.size.center(Offset.zero);
  }

  Map<String, num> _rocketProgressState(int totalValue) {
    var remaining = math.max(0, totalValue);
    var completed = 0;
    for (final target in _rocketStageTargets) {
      if (remaining < target) break;
      remaining -= target;
      completed++;
    }
    final allComplete = completed >= _rocketStageTargets.length;
    final currentIndex = allComplete
        ? _rocketStageTargets.length - 1
        : completed;
    final currentTarget = _rocketStageTargets[currentIndex];
    final currentProgress = allComplete ? currentTarget : remaining;
    return <String, num>{
      'completed': completed,
      'current_index': currentIndex,
      'current_target': currentTarget,
      'current_progress': currentProgress,
      'percent': allComplete
          ? 1.0
          : (currentProgress / currentTarget).clamp(0.0, 1.0),
    };
  }

  String _compactRoomSending(int value) {
    if (value >= 1000000000) {
      final n = value / 1000000000;
      return n.toStringAsFixed(value % 1000000000 == 0 ? 0 : 1) + 'B';
    }
    if (value >= 1000000) {
      final n = value / 1000000;
      return n.toStringAsFixed(value % 1000000 == 0 ? 0 : 1) + 'M';
    }
    if (value >= 100000) {
      final n = value / 100000;
      return n.toStringAsFixed(value % 100000 == 0 ? 0 : 1) + 'L';
    }
    if (value >= 1000) {
      final n = value / 1000;
      return n.toStringAsFixed(value % 1000 == 0 ? 0 : 1) + 'K';
    }
    return value.toString();
  }

  Future<void> _openRoom() async {
    await widget.state.refreshAuthenticatedAccount(force: true);
    final account = widget.state.auth.current;
    if (account == null) return;

    try {
      await widget.state.discovery.syncRooms(account.authToken);
    } catch (_) {
      // Keep room entry usable if directory refresh is temporarily unavailable.
    }

    final canonicalRoom = _roomSnapshot;
    final ownerId =
        canonicalRoom.ownerId ?? widget.room.ownerId ?? widget.room.id;
    widget.state.roomControls.setOwner(ownerId);

    if (_selectedGiftRecipients.length == 1) {
      _selectedGiftRecipients
        ..clear()
        ..add(ownerId);
    }

    if (canonicalRoom.locked && account.userId != ownerId) {
      final allowed = await _requestLockedRoomAccess(
        authToken: account.authToken,
      );
      if (!allowed) {
        if (mounted) Navigator.maybePop(context);
        return;
      }
    }

    try {
      await widget.state.social.syncFollowing(account.authToken);
      await widget.state.social.syncBlocked(account.authToken);
    } catch (_) {
      // Room entry should still work if social sync is temporarily unavailable.
    }

    widget.state.roomControls.configureForRoom(ownerId);
    widget.state.roomControls.settings =
        widget.state.roomControls.settings.copyWith(
      visibility: canonicalRoom.locked
          ? RoomVisibility.privateRoom
          : RoomVisibility.publicRoom,
    );
    widget.state.roomControls.roomMode =
        canonicalRoom.partyMode == 'Event hosting mode' ? 'event' : 'friends';
    if (RoomControlService.availableSeatThemes.contains(canonicalRoom.seatThemeId)) {
      widget.state.roomControls.setSeatTheme(canonicalRoom.seatThemeId);
    } else {
      widget.state.roomControls.setSeatTheme('royal-gold');
    }
    if (canonicalRoom.themeAsset == null || canonicalRoom.themeAsset!.isEmpty) {
      if (RoomControlService.availableThemes.contains(canonicalRoom.themeId)) {
        widget.state.roomControls.setTheme(canonicalRoom.themeId);
      } else {
        widget.state.roomControls.setTheme('royal-dark');
      }
    } else {
      widget.state.roomControls.setCustomTheme(
        canonicalRoom.themeId,
        canonicalRoom.themeAsset!,
      );
    }
    await widget.state.roomSession.open(
      canonicalRoom,
      userId: account.userId,
      authToken: account.authToken,
    );

    await _refreshOwnerRoomLockPassword();

    // The room-presence backend is authoritative for Free mic / Request mode.
    // Do not overwrite the freshly loaded server value with the local default
    // when the room is reopened. Keep the local room settings mirror in sync
    // with the server instead.
    final serverMicMode = widget.state.roomSession.presence.micMode;
    widget.state.roomControls.settings =
        widget.state.roomControls.settings.copyWith(
      micMode: serverMicMode == 'free' ? MicMode.free : MicMode.apply,
    );
  }

  Future<bool> _requestLockedRoomAccess({
    required String authToken,
  }) async {
    RoomAccessResult status;
    try {
      status = await widget.state.discovery.getRoomAccessStatus(
        authToken: authToken,
        roomId: widget.room.id,
      );
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
      return false;
    }

    if (status.allowed) return true;
    if (status.blocked) {
      _snack(
        status.error ??
            '5 wrong attempts used. Wait until the room is opened.',
      );
      return false;
    }

    var errorText = status.error;
    var attemptsRemaining = status.attemptsRemaining;

    while (mounted) {
      final password = await _promptRoomPassword(
        errorText: errorText,
        attemptsRemaining: attemptsRemaining,
      );
      if (password == null) return false;

      RoomAccessResult result;
      try {
        result = await widget.state.discovery.verifyRoomPassword(
          authToken: authToken,
          roomId: widget.room.id,
          password: password,
        );
      } catch (error) {
        _snack(error.toString().replaceFirst('Bad state: ', ''));
        return false;
      }

      if (result.allowed) return true;
      if (result.blocked) {
        _snack(
          result.error ??
              '5 wrong attempts used. Wait until the room is opened.',
        );
        return false;
      }

      errorText = result.error ?? 'Incorrect room password';
      attemptsRemaining = result.attemptsRemaining;
    }

    return false;
  }

  Future<String?> _promptRoomPassword({
    String? errorText,
    int? attemptsRemaining,
  }) async {
    var passwordValue = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Room Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the password to join this locked room.'),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              obscureText: true,
              maxLength: 5,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (value) => passwordValue = value,
              onSubmitted: (value) {
                if (RegExp(r'^\d{5}$').hasMatch(value)) {
                  Navigator.pop(dialogContext, value);
                }
              },
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'Exactly 5 digits',
                errorText: errorText,
              ),
            ),
            if (attemptsRemaining != null) ...[
              const SizedBox(height: 8),
              Text(
                'Attempts remaining: $attemptsRemaining',
                style: const TextStyle(
                  color: RoyalPalette.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (RegExp(r'^\d{5}$').hasMatch(passwordValue)) {
                Navigator.pop(dialogContext, passwordValue);
              }
            },
            child: const Text('Enter'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRoomLock() async {
    if (!_isRoomOwner) {
      _snack('Only the room owner can change room lock.');
      return;
    }

    final account = widget.state.auth.current;
    if (account == null) return;
    final controls = widget.state.roomControls;
    final currentlyLocked =
        controls.settings.visibility == RoomVisibility.privateRoom;

    try {
      await widget.state.discovery.setRoomLock(
        authToken: account.authToken,
        roomId: widget.room.id,
        locked: !currentlyLocked,
      );
      controls.settings = controls.settings.copyWith(
        visibility: currentlyLocked
            ? RoomVisibility.publicRoom
            : RoomVisibility.privateRoom,
      );
      final generated = currentlyLocked
          ? null
          : widget.state.discovery.lastGeneratedRoomPassword;
      if (mounted) {
        setState(() => _roomLockPassword = generated);
      }
      if (currentlyLocked) {
        _snack('Room unlocked. Owner password is not required.');
      } else {
        _snack(
          generated == null || generated.isEmpty
              ? 'Room locked.'
              : 'Room locked • Password ' + generated,
        );
      }
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _refreshOwnerRoomLockPassword() async {
    if (!_isRoomOwner) {
      if (mounted && _roomLockPassword != null) {
        setState(() => _roomLockPassword = null);
      }
      return;
    }
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final status = await widget.state.discovery.getRoomAccessStatus(
        authToken: account.authToken,
        roomId: widget.room.id,
      );
      if (!mounted) return;
      setState(() => _roomLockPassword = status.roomPassword);
    } catch (_) {
      // Lock controls remain usable even if the owner code refresh retries.
    }
  }

  void _scrollRoomCommentsToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_roomMessageScrollController.hasClients) return;
      final position = _roomMessageScrollController.position;
      _roomMessageScrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  RoomPresenceMember? _roomCommentMember(RoomMessage message) {
    final account = widget.state.auth.current;
    final currentUserId = account?.userId;
    for (final member in widget.state.roomSession.liveMembers) {
      if (message.author == 'You' && member.userId == currentUserId) {
        return member;
      }
      if (message.author != 'You' && member.displayName == message.author) {
        return member;
      }
    }
    return null;
  }

  String _roomCommentTagLabel(OwnerTag tag) {
    if (tag.kind == 'v_official' && tag.designation.trim().isNotEmpty) {
      return tag.designation.trim();
    }
    return tag.name.trim();
  }

  Widget _buildRoomComment(RoomMessage message) {
    final member = _roomCommentMember(message);
    final tags = member?.ownerTags ?? const <OwnerTag>[];
    final children = <InlineSpan>[];

    for (final tag in tags) {
      final label = _roomCommentTagLabel(tag);
      if (label.isEmpty) continue;
      final color = _ownerTagColor(tag.colorHex);
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            key: Key(
              'room-comment-tag-' +
                  (member?.userId ?? 'unknown') +
                  '-' +
                  label,
            ),
            margin: const EdgeInsets.only(right: 5),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 0.9),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                height: 1.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }

    children.add(
      TextSpan(
        text: message.author + ': ',
        style: const TextStyle(
          color: FeaturePalette.message,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
    children.add(
      TextSpan(
        text: message.text,
        style: const TextStyle(
          color: RoyalPalette.cream,
          fontSize: 12,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(
        TextSpan(children: children),
        style: const TextStyle(fontSize: 12, height: 1.25),
      ),
    );
  }

  Color get _seatThemeAccent {
    switch (widget.state.roomControls.seatThemeId) {
      case 'neon-blue':
        return const Color(0xFF44C8FF);
      case 'rose-glow':
        return const Color(0xFFFF4FA3);
      default:
        return RoyalPalette.gold;
    }
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
  ImageProvider? get _roomThemeImage {
    final source =
        widget.state.roomControls.customThemeAsset?.trim() ?? '';
    if (source.isEmpty) {
      _cachedThemeSource = null;
      _cachedThemeProvider = null;
      return null;
    }
    if (_cachedThemeSource == source) {
      return _cachedThemeProvider;
    }

    ImageProvider? provider;
    if (source.startsWith('data:image/')) {
      try {
        provider = stableImageProvider(source);
      } catch (_) {
        provider = null;
      }
    } else if (source.startsWith('https://') ||
        source.startsWith('http://')) {
      provider = stableImageProvider(source);
    }

    _cachedThemeSource = source;
    _cachedThemeProvider = provider;
    return provider;
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

  bool get _canTypeInRoom {
    final userId = widget.state.auth.current?.userId;
    if (userId == null) return false;
    if (widget.state.roomSession.presence.publicScreenEnabled) {
      return true;
    }
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
      unawaited(_refreshIdentityAndRoomOwnership(force: true));
    }
  }

  Future<void> _refreshIdentityAndRoomOwnership({
    bool force = false,
  }) async {
    final before = widget.state.auth.current;
    if (before == null) return;

    await widget.state.refreshAuthenticatedAccount(force: force);
    final account = widget.state.auth.current;
    if (account == null) return;

    try {
      await widget.state.discovery.syncRooms(account.authToken);
    } catch (_) {
      // Existing room session remains usable while directory sync retries later.
    }

    final ownerId =
        _roomSnapshot.ownerId ?? widget.room.ownerId ?? widget.room.id;
    widget.state.roomControls.setOwner(ownerId);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _rocketCompleted.dispose();
    _rocketLevelScrollController.dispose();
    _giftScenes.dispose();
    _cinematicLane.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.state.roomSession.removeListener(_refresh);
    _emoteExpiryTimer?.cancel();
    _seatGiftEffectTimer?.cancel();
    _luckyBubbleTimer?.cancel();
    _luckyComboTimer.removeListener(_onLuckyComboTimer);
    _luckyComboTimer.dispose();
    _luckyVisuals.dispose();
    _roomRecoveryTimer?.cancel();
    _rocketBannerPoll?.cancel();
    widget.state.social.unreadMessages.removeListener(_refresh);
    widget.state.social.roomEvents.removeListener(_onCountryRibbonEvent);
    unawaited(widget.state.social.releaseMessageEvents());
    chat.dispose();
    _roomMessageScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshCountryRibbons() async {
    if (_ribbonFetchRunning || !mounted) return;
    final account = widget.state.auth.current;
    if (account == null) return;
    _ribbonFetchRunning = true;
    try {
      final rows = await widget.state.discovery.countryRibbons(account.authToken);
      _acceptCountryRibbons(rows);
    } catch (_) {} finally {
      _ribbonFetchRunning = false;
    }
  }

  void _onCountryRibbonEvent() {
    if (!mounted) return;
    final event = widget.state.social.roomEvents.value;
    final rows = event?['ribbons'];
    if (rows is List) {
      _acceptCountryRibbons(rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)));
    } else if (event?['ribbon'] is Map) {
      _acceptCountryRibbons([Map<String, dynamic>.from(event!['ribbon'] as Map)]);
    }
  }

  void _acceptCountryRibbons(Iterable<Map<String, dynamic>> rows) {
    if (!mounted) return;
    var changed = false;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final expiry = (row['expires_at'] as num?)?.toInt() ?? 0;
      if (id.isEmpty || expiry <= now || !_seenRibbonIds.add(id)) continue;
      _ribbonQueue.add(row);
      changed = true;
    }
    // Bounded deduplication history: only live/recent ribbons need remembering.
    if (_seenRibbonIds.length > 256) {
      _seenRibbonIds.remove(_seenRibbonIds.first);
    }
    _ribbonQueue.sort((a, b) {
      final priority = ((b['priority'] as num?)?.toInt() ?? 0)
          .compareTo((a['priority'] as num?)?.toInt() ?? 0);
      if (priority != 0) return priority;
      return ((a['created_at'] as num?)?.toInt() ?? 0)
          .compareTo((b['created_at'] as num?)?.toInt() ?? 0);
    });
    if (changed) setState(() {});
  }

  void _finishRibbon(String id) {
    if (!mounted) return;
    setState(() => _ribbonQueue.removeWhere((row) => row['id']?.toString() == id));
  }

  Future<void> _enterRibbonRoom(Map<String, dynamic> ribbon) async {
    final roomId = ribbon['room_id']?.toString() ?? '';
    RoomSummary? target;
    for (final room in widget.state.discovery.rooms) {
      if (room.id == roomId) { target = room; break; }
    }
    if (target == null) {
      final account = widget.state.auth.current;
      if (account == null) return;
      try { await widget.state.discovery.syncRooms(account.authToken); } catch (_) {}
      if (!mounted) return;
      for (final room in widget.state.discovery.rooms) {
        if (room.id == roomId) { target = room; break; }
      }
    }
    if (target == null || target.id == widget.room.id) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => RoomScreen(state: widget.state, room: target!)),
    );
  }

  Widget _buildRibbonLane(Map<String, dynamic> ribbon, int lane) {
    final id = ribbon['id']?.toString() ?? '';
    final kind = ribbon['kind']?.toString() ?? '';
    if (kind == 'rocket_launch') {
      return Positioned(
        left: 10, right: 10, top: 6.0 + lane * 76.0, height: 72,
        child: RocketLaunchBanner(
          key: ValueKey<String>(id),
          level: (ribbon['amount'] as num? ?? 1).toInt(),
          roomName: ribbon['user_name']?.toString() ?? 'Room',
          launchedAt: (ribbon['created_at'] as num? ?? 0).toInt(),
          onEnter: () => _enterRibbonRoom(ribbon),
          onEnd: () => _finishRibbon(id),
        ),
      );
    }
    final isLp = kind == 'lp';
    final isLucky = kind == 'lucky_gift' || kind == 'lucky_gift_ultra';
    final isLuckyUltra = kind == 'lucky_gift_ultra';
    final name = ribbon['user_name']?.toString() ?? 'User';
    final amount = (ribbon['amount'] as num?)?.toInt() ?? 0;
    String amountText;
    if (amount >= 1000000) {
      amountText = (amount / 1000000)
              .toStringAsFixed(amount % 1000000 == 0 ? 0 : 1) +
          'M';
    } else {
      amountText = (amount / 100000)
              .toStringAsFixed(amount % 100000 == 0 ? 0 : 1) +
          'L';
    }
    final game =
        (ribbon['game_key']?.toString() ?? 'Game').replaceAll('_', ' ');
    final headline = isLp
        ? 'LUCKY POUCH'
        : isLuckyUltra
            ? 'LUCKY ULTRA'
            : isLucky
                ? 'LUCKY WIN'
                : 'BIG WIN';
    final message = isLp
        ? name + ' opened ' + amountText + ' LP'
        : name + ' WIN ' + amountText + ' • ' + game;

    return Positioned(
      left: 10,
      right: 10,
      top: 6.0 + lane * 52.0,
      height: 46,
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>(id),
        tween: Tween<double>(begin: 1.08, end: -1.08),
        duration: const Duration(seconds: 8),
        onEnd: () => _finishRibbon(id),
        builder: (context, value, child) => FractionalTranslation(
          translation: Offset(value, 0),
          child: child,
        ),
        child: GestureDetector(
          key: Key('country-ribbon-' + id),
          onTap: () => _enterRibbonRoom(ribbon),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLp
                    ? const <Color>[
                        Color(0xFF5D0711),
                        Color(0xFF9A151E),
                        Color(0xFF41040A),
                      ]
                    : isLuckyUltra
                        ? const <Color>[
                            Color(0xFF0B0710),
                            Color(0xFF6A3B00),
                            Color(0xFF2F164A),
                            Color(0xFF050505),
                          ]
                        : const <Color>[
                            Color(0xFF050505),
                            Color(0xFF17100A),
                            Color(0xFF050505),
                          ],
              ),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: const Color(0xFFFFD45A),
                width: 1.3,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x88FFD45A),
                  blurRadius: 11,
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1C0E22),
                    border: Border.all(
                      color: const Color(0xFFFFD45A),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isLp
                        ? Icons.shopping_bag_rounded
                        : isLucky
                            ? Icons.card_giftcard_rounded
                            : Icons.sports_esports_rounded,
                    color: isLuckyUltra
                        ? const Color(0xFFFFF2A8)
                        : const Color(0xFFFFD45A),
                    size: isLuckyUltra ? 22 : 20,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 82,
                  child: Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      color: Color(0xFFFFD45A),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFFFD45A),
                  size: 18,
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _refresh() {
    if (!mounted) return;

    final presence = widget.state.roomSession.presence;
    widget.state.roomControls.setPublicScreenEnabled(
      presence.publicScreenEnabled,
    );

    final currentUserId = widget.state.auth.current?.userId;
    final roomOwnerId =
        _roomSnapshot.ownerId ?? widget.room.ownerId ?? widget.room.id;
    final isOwnerForCommentClear =
        currentUserId != null && currentUserId == roomOwnerId;
    final clearVersion = isOwnerForCommentClear
        ? presence.ownerCommentsClearVersion
        : presence.commentsClearVersion;
    final previousClearVersion = _lastCommentsClearVersion;
    _lastCommentsClearVersion = clearVersion;
    if (previousClearVersion != null &&
        clearVersion > previousClearVersion) {
      widget.state.roomSession.controller?.clearRoomMessages();
    }

    final messageCount =
        widget.state.roomSession.controller?.messages.length ?? 0;
    final hasNewMessage = messageCount > _lastRoomMessageCount;
    _lastRoomMessageCount = messageCount;
    _scheduleEmoteExpiry();
    _syncMyAdminRole();
    _maybeShowSeatInvite();
    _syncEntranceQueue();
    _syncGiftVisualEvent();
    setState(() {});
    if (hasNewMessage) {
      _scrollRoomCommentsToNewest();
    }
  }

  GiftDefinition _giftDefinitionForVisualEvent(
    RoomGiftVisualEvent event,
  ) {
    for (final gift in <GiftDefinition>[
      ...PremiumGiftCatalog.normal,...PremiumGiftCatalog.cp,...PremiumGiftCatalog.countries,
      ...GiftService.catalog,
      ...GiftService.luckyCatalog,
    ]) {
      if (gift.id == event.giftId) return gift;
    }
    return GiftDefinition(
      id: event.giftId,
      name: event.giftName,
      price: 0,
      effectKind: event.lucky ? 'lucky' : 'svga',
      lucky: event.lucky,
    );
  }

  void _syncGiftVisualEvent() {
    final presence = widget.state.roomSession.presence;
    final latest = widget.state.roomSession.latestGiftVisualEvent;
    final events = <RoomGiftVisualEvent>[...presence.giftVisualEvents];
    if (latest != null) { events.add(latest); }
    for (final event in events) {
      if (!_handledGiftVisualEventIds.add(event.id)) continue;
      if (!_applyRoomSendingSummary(event.roomSummary)) { _refreshRoomSendingSummary(); }
      if (!event.lucky && event.createdAt.millisecondsSinceEpoch < presence.serverNowMs - 5000) continue;
      final gift = _giftDefinitionForVisualEvent(event);
      if (event.lucky) {
        _luckyVisuals.add(event, gift);
      } else if (event.senderId != widget.state.auth.current?.userId) {
        _triggerSeatGiftEffect(gift, event.receiverIds);
      }
    }
  }

  void _playLuckySeatVisual(LuckyGiftPresentation presentation) {
    if (!mounted || !widget.state.roomControls.effectsEnabled ||
        !widget.state.roomControls.luckyGiftEffectEnabled) return;
    final event = presentation.event;
    _luckyBubbleTimer?.cancel();
    setState(() {
      _luckySeatEffectGift = presentation.gift;
      _luckyLastMultiplier = event.multiplier;
      _luckyAnimationReceiverIds
        ..clear()
        ..addAll(event.receiverIds);
      _luckyAnimationSequence++;
    });
    _luckyBubbleTimer = Timer(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      setState(() {
        _luckyAnimationReceiverIds.clear();
        _luckyLastMultiplier = 0;
        _luckySeatEffectGift = null;
      });
    });
  }

  void _syncEntranceQueue() {
    final currentUserId = widget.state.auth.current?.userId;
    for (final member in widget.state.roomSession.liveMembers) {
      final entryId = member.equippedEntryId;
      if (entryId == null || entryId.isEmpty) continue;
      final key =
          member.userId + ':' + member.joinedAt.millisecondsSinceEpoch.toString();
      if (!_seenEntranceKeys.add(key)) continue;
      final isCurrentUser = member.userId == currentUserId;
      final isNewJoin = member.joinedAt.toUtc().isAfter(
            _screenOpenedAtUtc.subtract(const Duration(seconds: 4)),
          );
      if (isCurrentUser || isNewJoin) {
        _entranceQueue.add(member);
      }
    }
    if (_activeEntrance == null && _entranceQueue.isNotEmpty) {
      _activeEntrance = _entranceQueue.removeAt(0);
    }
  }

  void _finishPremiumEntrance() {
    if (!mounted) return;
    setState(() {
      _activeEntrance =
          _entranceQueue.isEmpty ? null : _entranceQueue.removeAt(0);
    });
  }

  void _syncMyAdminRole() {
    final account = widget.state.auth.current;
    if (account == null || account.userId == (widget.room.ownerId ?? widget.room.id)) {
      return;
    }

    RoomPresenceMember? me;
    for (final member in widget.state.roomSession.liveMembers) {
      if (member.userId == account.userId) {
        me = member;
        break;
      }
    }
    if (me == null) return;

    final current = widget.state.roomControls.roles[account.userId];
    if (me.isAdmin && current != RoomRole.admin) {
      widget.state.roomControls.setAdmin(account.userId, true);
    } else if (!me.isAdmin && current == RoomRole.admin) {
      widget.state.roomControls.setAdmin(account.userId, false);
    }
  }

  void _maybeShowSeatInvite() {
    final invite = widget.state.roomSession.pendingSeatInvite;
    if (invite == null) {
      _handledSeatInviteCreatedAtMs = null;
      return;
    }

    final inviteId = invite.createdAt.millisecondsSinceEpoch;
    if (_seatInviteDialogOpen ||
        _handledSeatInviteCreatedAtMs == inviteId) {
      return;
    }

    _handledSeatInviteCreatedAtMs = inviteId;
    _seatInviteDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _seatInviteDialogOpen = false;
        return;
      }

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Seat Invite'),
          content: Text(
            (invite.invitedBy ==
                    (_roomSnapshot.ownerId ??
                        widget.room.ownerId ??
                        widget.room.id)
                ? 'Owner'
                : 'Admin') +
                ' invites you to Seat No. ' +
                (invite.seatIndex + 1).toString() +
                '.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );

      try {
        await widget.state.roomSession.respondToSeatInvite(
          accepted == true,
        );
        if (accepted == true) {
          _snack(
            'Joined Seat ' + (invite.seatIndex + 1).toString() + '.',
          );
        }
      } catch (error) {
        _snack(error.toString().replaceFirst('Bad state: ', ''));
      } finally {
        _seatInviteDialogOpen = false;
      }
    });
  }

  void _scheduleEmoteExpiry() {
    _emoteExpiryTimer?.cancel();
    DateTime? nextExpiry;
    final now = DateTime.now();

    for (final member in widget.state.roomSession.liveMembers) {
      final expiry = member.seatEmoteUntil;
      if (member.seatEmote == null ||
          expiry == null ||
          !expiry.isAfter(now)) {
        continue;
      }
      if (nextExpiry == null || expiry.isBefore(nextExpiry)) {
        nextExpiry = expiry;
      }
    }

    if (nextExpiry == null) return;
    final delay = nextExpiry.difference(now);
    _emoteExpiryTimer = Timer(delay, () {
      if (!mounted) return;
      _scheduleEmoteExpiry();
      setState(() {});
    });
  }

  bool _isTransientRoomServerError(String text) {
    final lower = text.toLowerCase();
    return lower.contains('temporarily unavailable') ||
        lower.contains('invalid response') ||
        lower.contains('connection problem') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('timed out') ||
        lower.contains('connection closed');
  }

  void _scheduleRoomRecovery() {
    if (!mounted || _roomRecoveryRunning || _roomRecoveryTimer != null) {
      return;
    }
    _roomRecoveryTimer = Timer(const Duration(milliseconds: 350), () {
      _roomRecoveryTimer = null;
      unawaited(_recoverRoomConnection());
    });
  }

  Future<void> _recoverRoomConnection() async {
    if (!mounted || _roomRecoveryRunning) return;
    final account = widget.state.auth.current;
    if (account == null) return;

    _roomRecoveryRunning = true;
    try {
      final session = widget.state.roomSession;
      if (session.room?.id != widget.room.id || !session.backendSessionActive) {
        await _openRoom();
        return;
      }

      await session.presence.refresh(
        roomId: widget.room.id,
        authToken: account.authToken,
      );
      await session.presence.connectLive(
        roomId: widget.room.id,
        authToken: account.authToken,
      );
      if (!session.presence.connected) {
        throw StateError('Room presence reconnect pending');
      }
      session.resume();
      _roomRecoveryFailures = 0;
    } catch (_) {
      if (mounted && _roomRecoveryTimer == null) {
        _roomRecoveryTimer = Timer(RequestBudget.reconnectDelay(_roomRecoveryFailures++), () {
          _roomRecoveryTimer = null;
          _scheduleRoomRecovery();
        });
      }
    } finally {
      _roomRecoveryRunning = false;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    final clean = text.replaceFirst('Bad state: ', '').trim();
    if (_isTransientRoomServerError(clean)) {
      _scheduleRoomRecovery();
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(clean),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildRoomConnectionStatus() {
    final presence = widget.state.roomSession.presence;
    final session = widget.state.roomSession;
    final voiceProblem = !session.connected && !session.connecting && session.connectionError != null;
    final shouldShow = presence.hasConnectionProblem || voiceProblem;
    if (!shouldShow) return const SizedBox.shrink();

    final text = presence.hasConnectionProblem
        ? 'Connection problem • retrying…'
        : 'Voice unavailable • Tap to retry';

    return GestureDetector(
      onTap: () async {
        await widget.state.roomSession.retryVoice();
        _scheduleRoomRecovery();
      },
      child: Center(
        child: Container(
          key: const Key('room-connection-retrying'),
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xE621143A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFFD45A).withValues(alpha: 0.72),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sync_rounded,
                color: Color(0xFFFFD45A),
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMic() async {
    try {
      await widget.state.roomSession.toggleMyMic();
    } catch (error) { _snack(error.toString()); }
    if (mounted) setState(() {});
  }

  Future<void> _leaveSeatAndMute() async {
    final userId = widget.state.auth.current?.userId ?? '';
    await widget.state.ktv.stopForSeatDown(userId);
    try {
      await widget.state.roomSession.leaveMySeat();
    } catch (error) { _snack(error.toString()); }
    if (mounted) setState(() {});
  }

  Future<void> _showMySeatLeavePanel() async {
    if (controller.mySeat == null) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: RoyalPalette.nearBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: RoyalPalette.gold.withValues(alpha: 0.85),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            Navigator.pop(dialogContext);
            await _leaveSeatAndMute();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 34, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShiningIcon(
                  icon: Icons.keyboard_double_arrow_down_rounded,
                  color: FeaturePalette.safety,
                  size: 28,
                  boxSize: 44,
                  glow: 0.34,
                ),
                SizedBox(height: 10),
                Text(
                  'Leave Seat',
                  style: TextStyle(
                    color: RoyalPalette.cream,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                      color: FeaturePalette.games,
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
                      onTap: () async {
                        try {
                          await widget.state.roomSession.setMySeatEmote(emoji);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        } catch (error) {
                          _snack(
                            error.toString().replaceFirst('Bad state: ', ''),
                          );
                        }
                      },
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

  Future<RoomThemeRecord?> _createPaidRoomTheme({
    required int priceCoins,
    required int durationDays,
  }) async {
    final account = widget.state.auth.current;
    if (account == null) return null;

     final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1440,
      maxHeight: 1920,
    );
    if (image == null || !mounted) return null;

    final bytes = await image.readAsBytes();
    final mime = image.mimeType?.startsWith('image/') == true
        ? image.mimeType!
        : 'image/jpeg';
    final asset = 'data:' + mime + ';base64,' + base64Encode(bytes);
    if (asset.length > 2500000) {
      _snack('Theme image is too large. Choose a smaller image.');
      return null;
    }
    if (!mounted) return null;

    final nameController = TextEditingController();
    var policyConfirmed = false;
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final validName = nameController.text.trim().length >= 2;
          return AlertDialog(
            title: const Text('Add New Room Theme'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    priceCoins.toString() + ' coins • ' + durationDays.toString() + ' days',
                    style: const TextStyle(
                      color: FeaturePalette.wallet,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    maxLength: 60,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(labelText: 'Theme name'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: policyConfirmed,
                    onChanged: (value) {
                      setDialogState(() {
                        policyConfirmed = value == true;
                      });
                    },
                    title: const Text(
                      'I confirm this theme does not contain sexual or political content.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const Text(
                    'Themes that break this rule can be removed from the Owner Panel.',
                    style: TextStyle(color: RoyalPalette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: validName && policyConfirmed
                    ? () => Navigator.pop(dialogContext, nameController.text.trim())
                    : null,
                child: const Text('Add for 7 Days'),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    if (name == null || !mounted) return null;

    try {
      final theme = await widget.state.discovery.createRoomTheme(
        authToken: account.authToken,
        roomId: widget.room.id,
        name: name,
        asset: asset,
        policyConfirmed: true,
        durationDays: durationDays,
      );
      try {
        final remoteWallet = await widget.state.backend.wallet(account.authToken);
        widget.state.wallet.applyRemote(remoteWallet);
      } catch (_) {}
      if (mounted) {
        _snack('Theme added for ' + durationDays.toString() + ' days.');
      }
      return theme;
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
      return null;
    }
  }
  Future<void> _openRoomThemeSelector() async {
    if (!_isRoomOwner) {
      _snack('Only the room owner can change room theme.');
      return;
    }

    final account = widget.state.auth.current;
    if (account == null) return;
    final controls = widget.state.roomControls;
    var priceCoins = 10000000;
    var durationDays = 7;
    final remoteChoices = <_RoomThemeChoice>[];

    try {
      final catalog = await widget.state.discovery.fetchRoomThemes(
        authToken: account.authToken,
        roomId: widget.room.id,
      );
      priceCoins = catalog.userPriceCoins;
      durationDays = catalog.userDurationDays;
      for (final theme in catalog.themes) {
        remoteChoices.add(
          _RoomThemeChoice(
            id: theme.id,
            name: theme.name,
            asset: theme.asset,
            expiresAt: theme.expiresAt,
            panelFree: theme.isPanelTheme,
          ),
        );
      }
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
    if (!mounted) return;

    final builtIns = <_RoomThemeChoice>[
      const _RoomThemeChoice(
        id: 'royal-dark',
        name: 'Royal Dark',
        color: Color(0xFF03070B),
      ),
      const _RoomThemeChoice(
        id: 'night-blue',
        name: 'Night Blue',
        color: Color(0xFF03101B),
      ),
      const _RoomThemeChoice(
        id: 'rose-gold',
        name: 'Rose Gold',
        color: Color(0xFF17090D),
      ),
      const _RoomThemeChoice(
        id: 'mood-happy',
        name: 'Happy',
        color: Color(0xFF8F3448),
      ),
      const _RoomThemeChoice(
        id: 'mood-sad',
        name: 'Sad',
        color: Color(0xFF173E5D),
      ),
      const _RoomThemeChoice(
        id: 'mood-boring',
        name: 'Boring',
        color: Color(0xFF433154),
      ),
      const _RoomThemeChoice(
        id: 'mood-love',
        name: 'Love',
        color: Color(0xFF9A1838),
      ),
      const _RoomThemeChoice(
        id: 'mood-mountain-view',
        name: 'Mountain View',
        color: Color(0xFF536D82),
      ),
      const _RoomThemeChoice(
        id: 'mood-alone',
        name: 'Alone',
        color: Color(0xFF142A3D),
      ),
      const _RoomThemeChoice(
        id: 'mood-with-her',
        name: 'With Her',
        color: Color(0xFF8B462F),
      ),
      const _RoomThemeChoice(
        id: 'mood-with-him',
        name: 'With Him',
        color: Color(0xFF173B59),
      ),
      const _RoomThemeChoice(
        id: 'mood-love-scene',
        name: 'Love Scene',
        color: Color(0xFF3C1D58),
      ),
      const _RoomThemeChoice(
        id: 'mood-rainy-love',
        name: 'Rainy Love',
        color: Color(0xFF4A3536),
      ),
    ];

    var pending = builtIns.first;
    for (final item in <_RoomThemeChoice>[...builtIns, ...remoteChoices]) {
      if (item.id == controls.themeId) {
        pending = item;
        break;
      }
    }

    final selected = await Navigator.push<_RoomThemeChoice>(
      context,
      MaterialPageRoute(
        builder: (pageContext) => StatefulBuilder(
          builder: (pageContext, setPageState) {
            final themes = <_RoomThemeChoice>[...builtIns, ...remoteChoices];
            return Scaffold(
              key: const Key('room-cover-theme-page'),
              backgroundColor: RoyalPalette.nearBlack,
              appBar: AppBar(
                title: const Text(
                  'Room Cover / Theme',
                  style: TextStyle(
                    color: FeaturePalette.moments,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              body: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: themes.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final created = await _createPaidRoomTheme(
                          priceCoins: priceCoins,
                          durationDays: durationDays,
                        );
                        if (created == null || !pageContext.mounted) return;
                        final choice = _RoomThemeChoice(
                          id: created.id,
                          name: created.name,
                          asset: created.asset,
                          expiresAt: created.expiresAt,
                        );
                        setPageState(() {
                          remoteChoices.insert(0, choice);
                          pending = choice;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: FeaturePalette.glow(
                            FeaturePalette.moments,
                          ),
                          border: Border.all(color: FeaturePalette.moments),
                          boxShadow: [
                            BoxShadow(
                              color: FeaturePalette.moments
                                  .withValues(alpha: 0.24),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const ShiningIcon(
                              icon: Icons.add_rounded,
                              color: FeaturePalette.moments,
                              size: 30,
                              boxSize: 58,
                              glow: 0.42,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Add New',
                                    style: TextStyle(
                                      color: RoyalPalette.cream,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    priceCoins.toString() + ' coins • ' + durationDays.toString() + ' days',
                                    style: const TextStyle(
                                      color: FeaturePalette.wallet,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Text(
                                    'No sexual or political content.',
                                    style: TextStyle(
                                      color: RoyalPalette.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final theme = themes[index - 1];
                  final active = pending.id == theme.id;
                  ImageProvider? preview;
                  if (theme.asset?.startsWith('data:image/') == true) {
                    try {
                      preview = stableImageProvider(theme.asset!);
                    } catch (_) {
                      preview = null;
                    }
                  } else if (theme.asset?.startsWith('https://') == true) {
                    preview = NetworkImage(theme.asset!);
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setPageState(() {
                        pending = theme;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active
                              ? FeaturePalette.moments
                              : FeaturePalette.moments
                                  .withValues(alpha: 0.32),
                          width: active ? 2 : 1,
                        ),
                        color: RoyalPalette.panel,
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: FeaturePalette.moments
                                      .withValues(alpha: 0.24),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: theme.color ?? RoyalPalette.panel2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: FeaturePalette.moments
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isEmotionRoomTheme(theme.id)
                                ? RoomEmotionBackdrop(themeId: theme.id)
                                : preview == null
                                    ? null
                                    : Image(
                                        image: preview,
                                        fit: BoxFit.cover,
                                      ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  theme.name,
                                  style: const TextStyle(
                                    color: RoyalPalette.cream,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (theme.panelFree)
                                  const Text(
                                    'Added free from Owner Panel',
                                    style: TextStyle(
                                      color: FeaturePalette.moments,
                                      fontSize: 10,
                                    ),
                                  )
                                else if (theme.expiresAt != null)
                                  Text(
                                    'Valid until ' + theme.expiresAt!.day.toString() + '/' + theme.expiresAt!.month.toString() + '/' + theme.expiresAt!.year.toString(),
                                    style: const TextStyle(
                                      color: RoyalPalette.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            active
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: active
                                ? FeaturePalette.moments
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
                    onPressed: () => Navigator.pop(pageContext, pending),
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Theme'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (!mounted || selected == null) return;

    try {
      await widget.state.discovery.setRoomTheme(
        authToken: account.authToken,
        roomId: widget.room.id,
        themeId: selected.id,
        themeAsset: selected.asset,
      );
      if (selected.asset == null) {
        controls.setTheme(selected.id);
      } else {
        controls.setCustomTheme(selected.id, selected.asset!);
      }
      if (mounted) setState(() {});
      _snack('Room theme saved.');
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
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
                  leading: const ShiningIcon(
                    icon: Icons.keyboard_arrow_down_rounded,
                    color: FeaturePalette.social,
                    size: 18,
                    boxSize: 34,
                    glow: 0.30,
                  ),
                  title: const Text('Minimize'),
                  subtitle: const Text('Stay in the room and return to the app.'),
                  onTap: () => Navigator.pop(sheetContext, 'minimize'),
                ),
              ),
              Expanded(
                child: ListTile(
                  leading: const ShiningIcon(
                    icon: Icons.exit_to_app_rounded,
                    color: FeaturePalette.safety,
                    size: 18,
                    boxSize: 34,
                    glow: 0.30,
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
      await widget.state.ktv.stopRoomPlayback();
      await session.close();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  ImageProvider? _roomAvatarProvider(String? value) {
    final source = value?.trim() ?? '';
    if (source.isEmpty) return null;

    final cached = _avatarProviderCache[source];
    if (cached != null) return cached;

    ImageProvider? provider;
    if (source.startsWith('data:image/')) {
      try {
        provider = stableImageProvider(source);
      } catch (_) {
        provider = null;
      }
    } else if (source.startsWith('https://') ||
        source.startsWith('http://')) {
      provider = stableImageProvider(source);
    }

    if (provider != null) {
      if (_avatarProviderCache.length >= 128) {
        _avatarProviderCache.clear();
      }
      _avatarProviderCache[source] = provider;
    }
    return provider;
  }

  Color _ownerTagColor(String colorHex) {
    final value = int.tryParse(
      colorHex.replaceFirst('#', ''),
      radix: 16,
    );
    return Color(0xFF000000 | (value ?? 0xFFD54F));
  }

  int get _roomUnreadMessageCount =>
      widget.state.social.totalUnreadMessages;

  Future<void> _openRoomInbox() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesScreen(state: widget.state),
      ),
    );
  }

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

  Future<void> _showKickPicker(RoomPresenceMember member) async {
    final duration = await showModalBottomSheet<Duration?>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              leading: ShiningIcon(
                icon: Icons.person_remove_rounded,
                color: FeaturePalette.safety,
                size: 18,
                boxSize: 34,
                glow: 0.30,
              ),
              title: Text(
                'Kick duration',
                style: TextStyle(
                  color: FeaturePalette.safety,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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

  bool _adminCanControlSeatOccupant(RoomPresenceMember member) {
    if (_isRoomOwner) return true;
    final ownerId =
        _roomSnapshot.ownerId ?? widget.room.ownerId ?? widget.room.id;
    if (member.userId == ownerId) return false;
    if (member.isAdmin) return false;
    return _currentRoomRole == RoomRole.admin;
  }

  RoomPresenceMember? _memberOnSeat(int seatIndex) {
    for (final member in widget.state.roomSession.liveMembers) {
      if (member.seatIndex == seatIndex) return member;
    }
    final mappedUserId = widget.state.roomControls.seatUsers[seatIndex];
    if (mappedUserId != null) {
      for (final member in widget.state.roomSession.liveMembers) {
        if (member.userId == mappedUserId) return member;
      }
    }
    return null;
  }

  Future<void> _moveMemberSeatDown(RoomPresenceMember member) async {
    try {
      await widget.state.roomSession.moveUserToAudience(member.userId);
      _snack(member.displayName + ' moved to audience.');
      if (mounted) setState(() {});
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _setRoomAdminById({
    required String userId,
    required String displayName,
    required bool enabled,
  }) async {
    try {
      await widget.state.roomSession.setRoomAdmin(
        userId,
        enabled: enabled,
      );
      _snack(
        enabled
            ? displayName + ' is now a room admin.'
            : displayName + ' removed from room admin.',
      );
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
      rethrow;
    }
  }

  Future<void> _toggleRoomAdmin(
    RoomPresenceMember member,
    bool enabled,
  ) async {
    try {
      await widget.state.roomSession.setRoomAdmin(
        member.userId,
        enabled: enabled,
      );
      _snack(
        enabled
            ? member.displayName + ' is now a room admin.'
            : member.displayName + ' removed from room admin.',
      );
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _toggleRoomChatBan(
    RoomPresenceMember member,
    bool banned,
  ) async {
    try {
      await widget.state.roomSession.setRoomChatBan(
        member.userId,
        banned: banned,
      );
      _snack(
        banned
            ? member.displayName + ' chat banned in this room.'
            : member.displayName + ' chat unbanned.',
      );
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _openFullRoomProfile(RoomPresenceMember member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RoomMemberProfilePage(member: member),
      ),
    );
  }

  void _showUserProfile(
    RoomPresenceMember member, {
    int? seatIndexHint,
  }) {
    final selfUserId = widget.state.auth.current?.userId;
    final isSelf = member.userId == selfUserId;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
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
          final moderationMuted = currentMember.moderationMuted;
          final ownerId =
              _roomSnapshot.ownerId ?? widget.room.ownerId ?? widget.room.id;
          final targetIsOwner = currentMember.userId == ownerId;
          final canModerate = !isSelf &&
              _canModerateSeats &&
              !targetIsOwner &&
              (_isRoomOwner || !currentMember.isAdmin);
          final sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.44;

          ImageProvider? avatar;
          final avatarData = currentMember.avatarDataUrl;
          if (avatarData != null && avatarData.startsWith('data:image/')) {
            try {
              avatar = stableImageProvider(avatarData);
            } catch (_) {
              avatar = null;
            }
          }

          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              key: Key('room-user-profile-card-' + currentMember.userId),
              width: double.infinity,
              height: sheetHeight,
              decoration: const BoxDecoration(
                color: RoyalPalette.nearBlack,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                border: Border(
                  top: BorderSide(color: RoyalPalette.bronze),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    children: [
                      GestureDetector(
                        key: Key(
                          'room-profile-card-dp-' + currentMember.userId,
                        ),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Future<void>.delayed(Duration.zero, () {
                            if (mounted) {
                              _openFullRoomProfile(currentMember);
                            }
                          });
                        },
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: RoyalPalette.panel2,
                          backgroundImage: avatar,
                          child: avatar == null
                              ? Text(
                                  currentMember.displayName.isEmpty
                                      ? '?'
                                      : currentMember
                                          .displayName.characters.first
                                          .toUpperCase(),
                                  style: const TextStyle(
                                    color: FeaturePalette.social,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        currentMember.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RoyalPalette.cream,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'ID ' + currentMember.userId,
                        style: const TextStyle(
                          color: RoyalPalette.muted,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 67,
                        child: ListView(
                          key: Key(
                            'room-profile-card-actions-' +
                                currentMember.userId,
                          ),
                          scrollDirection: Axis.horizontal,
                          children: [
                            if (!isSelf)
                              _ProfileAction(
                                icon: followed
                                    ? Icons.person_remove_rounded
                                    : Icons.person_add_rounded,
                                label: followed ? 'Unfollow' : 'Follow',
                                onTap: () async {
                                  final account = widget.state.auth.current;
                                  if (account == null) return;
                                  try {
                                    await widget.state.social
                                        .setFollowingRemote(
                                      authToken: account.authToken,
                                      targetUserId: currentMember.userId,
                                      value: !followed,
                                    );
                                    if (sheetContext.mounted) {
                                      setSheetState(() {});
                                    }
                                  } catch (error) {
                                    _snack(
                                      error
                                          .toString()
                                          .replaceFirst('Bad state: ', ''),
                                    );
                                  }
                                },
                              ),
                            if (_isRoomOwner &&
                                !isSelf &&
                                !targetIsOwner)
                              _ProfileAction(
                                icon: currentMember.isAdmin
                                    ? Icons.remove_moderator_rounded
                                    : Icons.admin_panel_settings_rounded,
                                label: currentMember.isAdmin
                                    ? 'Remove Admin'
                                    : 'Set Admin',
                                onTap: () async {
                                  await _toggleRoomAdmin(
                                    currentMember,
                                    !currentMember.isAdmin,
                                  );
                                  if (sheetContext.mounted) {
                                    setSheetState(() {});
                                  }
                                },
                              ),
                            if (!isSelf)
                              _ProfileAction(
                                icon: Icons.card_giftcard_rounded,
                                label: 'Gifting',
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  Future<void>.delayed(Duration.zero, () {
                                    if (mounted) {
                                      _showGiftSheet(
                                        preselectedUserId:
                                            currentMember.userId,
                                      );
                                    }
                                  });
                                },
                              ),
                            if (!isSelf)
                              _ProfileAction(
                                icon: Icons.mail_rounded,
                                label: 'Message',
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _openPrivateMessage(currentMember);
                                },
                              ),
                            if (canModerate)
                              _ProfileAction(
                                icon: moderationMuted
                                    ? Icons.mic_rounded
                                    : Icons.mic_off_rounded,
                                label: moderationMuted ? 'Unmute' : 'Mute',
                                onTap: () async {
                                  if (seatIndex == null) {
                                    _snack(
                                      currentMember.displayName +
                                          ' is not on a seat.',
                                    );
                                    return;
                                  }
                                  await _setUserSeatMute(
                                    currentMember,
                                    seatIndex,
                                    !moderationMuted,
                                  );
                                  if (sheetContext.mounted) {
                                    setSheetState(() {});
                                  }
                                },
                              ),
                            if (canModerate && seatIndex != null)
                              _ProfileAction(
                                icon:
                                    Icons.airline_seat_recline_normal_rounded,
                                label: 'Seat down',
                                onTap: () async {
                                  Navigator.pop(sheetContext);
                                  await _moveMemberSeatDown(currentMember);
                                },
                              ),
                            if (canModerate)
                              _ProfileAction(
                                icon: currentMember.chatBanned
                                    ? Icons.chat_rounded
                                    : Icons.comments_disabled_rounded,
                                label: currentMember.chatBanned
                                    ? 'Chat Unban'
                                    : 'Chat Ban',
                                onTap: () async {
                                  await _toggleRoomChatBan(
                                    currentMember,
                                    !currentMember.chatBanned,
                                  );
                                  if (sheetContext.mounted) {
                                    setSheetState(() {});
                                  }
                                },
                              ),
                            if (canModerate)
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
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createRoomCustomGift() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Custom Gift',
      type: FileType.custom,
      allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'mp4'],
    );
    if (file == null || !mounted) return;
    final path = file.path;
    if (path == null || path.isEmpty) {
      _snack('This custom gift file could not be opened.');
      return;
    }

    final nameController = TextEditingController(
      text: file.name.contains('.')
          ? file.name.substring(0, file.name.lastIndexOf('.'))
          : file.name,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom Gift'),
        content: TextField(
          controller: nameController,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Gift name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = nameController.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.isEmpty) return;

    final lower = file.name.toLowerCase();
    final assetType = lower.endsWith('.mp4') ? 'video' : 'image';
    final id = 'custom-' + DateTime.now().microsecondsSinceEpoch.toString();
    widget.state.customGifts.create(
      id: id,
      name: name,
      assetType: assetType,
      assetPath: path,
    );
    widget.state.customGifts.submit(id);
    _snack(name + ' added to Custom Gifts and sent for review.');
  }

  int _giftInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _applyGiftServerWallet(Map<String, dynamic> response) {
    final raw = response['wallet'];
    if (raw is! Map) return;
    final wallet = raw.map((key, value) => MapEntry(key.toString(), value));
    widget.state.wallet.coins = _giftInt(wallet['coins']);
    widget.state.wallet.diamonds = _giftInt(wallet['diamonds']);
  }

  bool _sameLuckyRecipients(List<String> next) {
    final ids = next.toSet();
    return _luckyComboRecipients.toSet().length == ids.length &&
        ids.containsAll(_luckyComboRecipients);
  }

  void _clearLuckyComboFields() {
    _luckyComboGift = null;
    _luckyComboRecipients = <String>[];
    _luckyComboQuantity = 1;
    _luckyComboCount = 0;
    _luckyComboWon = 0;
    _luckyComboSent = 0;
    _luckyPoolBalance = 0;
    _luckySessionId = null;
    _luckySessionHighest = 0;
  }

  void _onLuckyComboTimer() {
    if (!mounted) return;
    setState(() {
      if (!_luckyComboTimer.active) _clearLuckyComboFields();
    });
  }

  void _resetLuckyComboState() {
    _clearLuckyComboFields();
    _luckyComboTimer.clear();
  }

  void _armLuckyComboExpiry() {
    final gift = _luckyComboGift;
    if (gift == null || _luckySessionId == null) return;
    _luckyComboTimer.success(
      gift: gift.id, receiverIds: _luckyComboRecipients,
      session: _luckySessionId!, sendQuantity: _luckyComboQuantity,
      totalCount: _luckyComboCount, totalWon: _luckyComboWon,
      totalSent: _luckyComboSent, highestMultiplier: _luckySessionHighest,
    );
  }

  void _triggerSeatGiftEffect(
    GiftDefinition gift,
    List<String> receiverIds,
  ) {
    if (widget.state.roomControls.effectsEnabled &&
        widget.state.roomControls.giftEffectsEnabled) {
      _giftScenes.add(GiftSceneEvent(gift:gift,recipients:receiverIds));
    }
  }

  void _deliverGiftScene(GiftSceneEvent event) {
    final gift=event.gift;
    final receiverIds=event.recipients;
    _seatGiftEffectTimer?.cancel();
    setState(() {
      _seatGiftEffect = gift;
      _seatGiftEffectReceiverIds
        ..clear()
        ..addAll(receiverIds);
      _seatGiftEffectSequence++;
    });
    _seatGiftEffectTimer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      setState(() {
        _seatGiftEffect = null;
        _seatGiftEffectReceiverIds.clear();
      });
    });
  }

  Widget _buildCountryAudienceLandings() {
    final gift = _seatGiftEffect;
    if (gift == null || !gift.id.startsWith('flag-') ||
        !widget.state.roomControls.effectsEnabled ||
        !widget.state.roomControls.giftEffectsEnabled) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final seated = <String>{...widget.state.roomControls.seatUsers.values};
    final members = widget.state.roomSession.liveMembers;
    for (final member in members) {
      if (member.seatIndex != null) seated.add(member.userId);
    }
    final account = widget.state.auth.current;
    if (controller.mySeat != null && account != null) seated.add(account.userId);
    final receivers = _seatGiftEffectReceiverIds.where((id) => !seated.contains(id)).toList();
    if (receivers.isEmpty) return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    return Positioned(
      left: 12, right: 12, bottom: 148, height: 86,
      child: IgnorePointer(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal, clipBehavior: Clip.none,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final receiverId in receivers)
            _buildCountryAudienceLanding(receiverId, gift, members, account?.userId,
              account?.avatarDataUrl),
        ]),
      )),
    );
  }

  Widget _buildCountryAudienceLanding(
    String receiverId, GiftDefinition gift, List<RoomPresenceMember> members,
    String? ownId, String? ownAvatar,
  ) {
    final member = members.where((row) => row.userId == receiverId).firstOrNull;
    final source = member?.avatarDataUrl ?? (receiverId == ownId ? ownAvatar : null);
    final avatar = _roomAvatarProvider(source);
    return SizedBox(
      key: Key('country-recipient-landing-$receiverId'),
      width: 90,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          key: Key('country-recipient-dp-$receiverId'), width: 44, height: 44,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF20304C),
              child: avatar == null ? const Icon(Icons.person, color: Colors.white)
                  : ClipOval(child: Image(image: avatar, fit: BoxFit.cover,
                      width: 44, height: 44,
                      errorBuilder: (_, _, _) => const Icon(Icons.person, color: Colors.white))),
            ),
            _buildSeatGiftImpactEffect(
              gift: gift, seatDiameter: 44, receiverId: receiverId,
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Text('ID $receiverId', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFFFD479), fontSize: 10,
            fontWeight: FontWeight.w800)),
      ]),
    );
  }

  String _newLuckySessionId(String userId) =>
      'lucky-' + userId + '-' + DateTime.now().microsecondsSinceEpoch.toString();

  ImageProvider? _luckyAvatarProvider(dynamic value) {
    final source = value?.toString().trim();
    if (source == null || source.isEmpty) return null;
    return _roomAvatarProvider(source);
  }

  Future<void> _openRechargeDirect() async {
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RechargeScreen(state: widget.state),
      ),
    );
  }

  Future<bool> _sendLuckyGift(
    GiftDefinition gift,
    List<String> receiverIds, {
    int quantity = 1,
  }) async {
    final account = widget.state.auth.current;
    if (account == null || receiverIds.isEmpty || _luckyComboSending) {
      return false;
    }

    final continuesSession = _luckyComboTimer.active && _luckyComboGift?.id == gift.id &&
        _sameLuckyRecipients(receiverIds) &&
        _luckySessionId != null;
    final sessionId =
        continuesSession ? _luckySessionId! : _newLuckySessionId(account.userId);

    // Only successful sends renew the nine-second Combo. In-flight and
    // failed requests leave the original deadline running.

    setState(() => _luckyComboSending = true);
    try {
      final response = await widget.state.roomSession.sendGift(
        roomId: widget.room.id,
        authToken: account.authToken,
        giftId: gift.id,
        giftName: gift.name,
        quantity: quantity,
        unitPrice: gift.price,
        receiverIds: receiverIds,
        luckySessionId: sessionId,
      );
      if (!mounted || widget.state.auth.current?.userId != account.userId) return false;
      _applyGiftServerWallet(response);
      if (!_applyRoomSendingSummary(response['room_summary'])) _refreshRoomSendingSummary();

      final rawLucky = response['lucky'];
      final lucky = rawLucky is Map
          ? rawLucky.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      final multiplier = _giftInt(lucky['multiplier']);
      final rebateCoins = _giftInt(lucky['rebate_coins']);
      final poolBalance = _giftInt(lucky['pool_balance']);
      final totalCost = _giftInt(response['total_cost']);
      final rawSession = lucky['session'];
      final session = rawSession is Map
          ? rawSession.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};

      _luckySessionId = sessionId;
      _luckyComboGift = gift;
      _luckyComboRecipients = List<String>.from(receiverIds);
      _luckyComboQuantity = quantity;

      final serverCount = _giftInt(session['send_count']);
      final serverWon = _giftInt(session['total_rebate_coins']);
      final serverHighest = _giftInt(session['highest_multiplier']);
      _luckyComboCount =
          serverCount > 0 ? serverCount : (continuesSession ? _luckyComboCount : 0) + quantity * receiverIds.length;
      _luckyComboWon = session.containsKey('total_rebate_coins')
          ? serverWon
          : (continuesSession ? _luckyComboWon + rebateCoins : rebateCoins);
      _luckyComboSent = session.containsKey('total_sent_coins')
          ? _giftInt(session['total_sent_coins'])
          : (continuesSession ? _luckyComboSent : 0) + totalCost;
      _luckySessionHighest = continuesSession
          ? math.max(_luckySessionHighest, math.max(serverHighest, multiplier))
          : math.max(serverHighest, multiplier);
      _luckyPoolBalance = poolBalance;
      final rawVisual = response['visual_event'];
      if (rawVisual is Map) {
        _luckyVisuals.add(RoomGiftVisualEvent.fromJson(
          Map<String, dynamic>.from(rawVisual)), gift);
      } else {
        final transactions = response['transactions'];
        final first = transactions is List && transactions.isNotEmpty && transactions.first is Map
            ? Map<String, dynamic>.from(transactions.first as Map) : <String, dynamic>{};
        final counts = lucky['multiplier_counts'];
        _luckyVisuals.add(RoomGiftVisualEvent(
          id: first['id']?.toString() ?? '$sessionId-${DateTime.now().microsecondsSinceEpoch}',
          senderId: account.userId, senderName: account.displayName,
          giftId: gift.id, giftName: gift.name, receiverIds: List.unmodifiable(receiverIds),
          quantity: quantity, lucky: true, multiplier: multiplier, rebateCoins: rebateCoins,
          sentCoins: totalCost, unitPrice: _giftInt(first['unit_price']),
          sessionId: sessionId, createdAt: DateTime.now(),
          multiplierCounts: counts is List ? counts.whereType<Map>().map((row) => <String, int>{
            'multiplier': _giftInt(row['multiplier']), 'count': _giftInt(row['count']),
          }).toList() : const [],
          highWin: lucky['high_win'] == true, bannerWin: lucky['banner_win'] == true,
          ultraWin: lucky['ultra_win'] == true, bannersEnabled: lucky['banners_enabled'] != false,
        ), gift);
      }
      _armLuckyComboExpiry();

      final tx = GiftTransaction(
        gift: gift,
        quantity: quantity,
        senderId: account.userId,
        receiverIds: List<String>.unmodifiable(receiverIds),
        totalCost: totalCost > 0
            ? totalCost
            : gift.price * quantity * receiverIds.length,
      );
      widget.state.gifts.sent.insert(0, tx);
      widget.state.activities.addGiftScore(
        account.userId,
        tx.totalCost ~/ 10,
      );
      widget.state.identity.gainVipExperience(tx.totalCost ~/ 10);

      if (lucky['banner_win'] == true && lucky['banners_enabled'] != false) {
        await _refreshCountryRibbons();
      }
      if (mounted) setState(() {});
      return true;
    } catch (error) {
      final message = error.toString().replaceFirst('Bad state: ', '');
      if (message.toLowerCase().contains('insufficient coins')) {
        await _openRechargeDirect();
      } else if (mounted) {
        _snack(message);
      }
      return false;
    } finally {
      if (mounted) setState(() => _luckyComboSending = false);
    }
  }

  Future<void> _repeatLuckyGift() async {
    final gift = _luckyComboGift;
    if (gift == null || _luckyComboRecipients.isEmpty) return;
    await _sendLuckyGift(
      gift,
      List<String>.from(_luckyComboRecipients),
      quantity: _luckyComboQuantity,
    );
  }

  Widget _luckyArtwork(
    GiftDefinition gift, {
    required double size,
    BoxFit fit = BoxFit.contain,
  }) {
    final asset = gift.artworkAsset;
    if (asset == null || asset.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            gift.emoji,
            style: TextStyle(fontSize: size * 0.62),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(
            gift.emoji,
            style: TextStyle(fontSize: size * 0.62),
          ),
        ),
      ),
    );
  }

  Widget _buildSeatGiftImpactEffect({
    required GiftDefinition gift,
    required double seatDiameter,
    String? receiverId,
  }) {
    final countryFlag = gift.id.startsWith('flag-');
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>('seat-gift-impact-$_seatGiftEffectSequence'),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1450),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final fade = value < 0.72
              ? 1.0
              : ((1 - value) / 0.28).clamp(0.0, 1.0).toDouble();
          final scale = countryFlag
              ? .7 + (1 - value) * (MediaQuery.sizeOf(context).width * .88 /
                  (seatDiameter * .76 * .62) - .7)
              : 0.38 + Curves.easeOutBack.transform(value) * 0.86;
          final rise = math.sin(math.pi * value) * seatDiameter * 0.42;
          final origin = _giftFlightOriginOffset(context);
          return Transform.translate(
            offset: Offset(
              origin.dx * (1 - value),
              origin.dy * (1 - value) - rise,
            ),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: fade,
                child: Container(
                  padding: countryFlag ? EdgeInsets.zero : EdgeInsets.all(math.max(1.0, seatDiameter * 0.035)),
                  decoration: countryFlag ? null : BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFD45A),
                      width: 1.2,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x99FFD45A),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: KeyedSubtree(
                    key: countryFlag && receiverId != null
                        ? Key('country-flag-flight-$receiverId') : null,
                    child: _luckyArtwork(gift, size: seatDiameter * 0.76),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLuckyImpactEffect({
    required GiftDefinition gift,
    required double seatDiameter,
  }) {
    final highWin = _luckyLastMultiplier >= 200;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>('lucky-impact-$_luckyAnimationSequence'),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1180),
        curve: Curves.easeOut,
        builder: (context, value, _) {
          if (value < 0.46) return const SizedBox.shrink();
          final phase = ((value - 0.46) / 0.54).clamp(0.0, 1.0).toDouble();
          final fade = (1 - phase).clamp(0.0, 1.0).toDouble();
          final burstRadius = seatDiameter * (0.45 + phase * 0.9);
          return SizedBox(
            width: seatDiameter * 2.6,
            height: seatDiameter * 2.6,
            child: Center(
              child: Opacity(
                opacity: fade,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: 0.55 + phase * 1.35,
                      child: Container(
                        width: seatDiameter * 0.95,
                        height: seatDiameter * 0.95,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: highWin
                                ? const <Color>[
                                    Color(0xFFFFF7B2),
                                    Color(0xCCFFAE36),
                                    Color(0x55FF4D18),
                                    Colors.transparent,
                                  ]
                                : const <Color>[
                                    Color(0xFFFFF4A8),
                                    Color(0xAAFF67D8),
                                    Color(0x553A7BFF),
                                    Colors.transparent,
                                  ],
                            stops: const <double>[0, 0.28, 0.62, 1],
                          ),
                          border: Border.all(
                            color: highWin
                                ? const Color(0xFFFFD45A)
                                : const Color(0xFFFFB7F2),
                            width: highWin ? 2.2 : 1.4,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: highWin
                                  ? const Color(0xAAFFB020)
                                  : const Color(0x887F55FF),
                              blurRadius: highWin ? 24 : 17,
                              spreadRadius: highWin ? 5 : 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (var index = 0; index < 10; index++)
                      Transform.translate(
                        offset: Offset(
                          math.cos(index * math.pi / 5) * burstRadius,
                          math.sin(index * math.pi / 5) * burstRadius,
                        ),
                        child: Transform.rotate(
                          angle: index * 0.45 + phase,
                          child: Icon(
                            index.isEven
                                ? Icons.auto_awesome
                                : Icons.star_rounded,
                            size: seatDiameter *
                                (highWin ? 0.28 : 0.22) *
                                (1 - phase * 0.35),
                            color: index % 3 == 0
                                ? const Color(0xFFFFD45A)
                                : index % 3 == 1
                                    ? const Color(0xFFFF70D8)
                                    : const Color(0xFF72D9FF),
                          ),
                        ),
                      ),
                    Transform.scale(
                      scale: 0.55 +
                          Curves.easeOutBack.transform(phase) *
                              (highWin ? 0.95 : 0.72),
                      child: _luckyArtwork(
                        gift,
                        size: seatDiameter * (highWin ? 1.12 : 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLuckyComboOverlay() {
    final gift = _luckyComboGift;
    if (gift == null) return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    return Positioned(
      key: const Key('lucky-combo-overlay'), right: 8, top: 20,
      child: LuckyComboPanel(
        gift: gift, quantity: _luckyComboQuantity, count: _luckyComboCount,
        wonCoins: _luckyComboWon, sentCoins: _luckyComboSent,
        highest: _luckySessionHighest, secondsLeft: _luckyComboSecondsLeft,
        loading: _luckyComboSending, poolCoins: _luckyPoolBalance, avatar: _luckyAvatarProvider(widget.state.auth.current?.avatarDataUrl),
        onSend: () => unawaited(_repeatLuckyGift()),
      ),
    );
  }

  Future<void> _showLuckyGiftDetails() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    Map<String, dynamic> data;
    try {
      data = await widget.state.roomSession.luckyGiftState(
        authToken: account.authToken,
      );
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
      return;
    }
    if (!mounted) return;

    List<Map<String, dynamic>> mapList(dynamic value) => value is List
        ? value
            .whereType<Map>()
            .map((row) => row.map(
                  (key, item) => MapEntry(key.toString(), item),
                ))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final ranking = mapList(data['ranking']);
    final sessions = mapList(data['recent_sessions']);
    final rawShares = data['visible_daily_rank_shares'];
    final shares = rawShares is List
        ? rawShares.map(_giftInt).toList(growable: false)
        : const <int>[50, 25, 15];
    final countdownEndsAt = _giftInt(data['countdown_ends_at']);
    final remainingMs = math.max(
      0,
      countdownEndsAt - DateTime.now().millisecondsSinceEpoch,
    );
    final remaining = Duration(milliseconds: remainingMs);
    final countdownText =
        remaining.inHours.toString().padLeft(2, '0') +
            ':' +
            (remaining.inMinutes % 60).toString().padLeft(2, '0') +
            ':' +
            (remaining.inSeconds % 60).toString().padLeft(2, '0');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171021),
        title: const Row(
          children: [
            Text('🎁', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lucky Gift',
                style: TextStyle(
                  color: Color(0xFFFFD45A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          height: math.min(
            MediaQuery.sizeOf(dialogContext).height * 0.68,
            570,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[
                        Color(0xFF4C175F),
                        Color(0xFF241035),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFD45A),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'REAL-TIME PRIZE POOL',
                        style: TextStyle(
                          color: Color(0xFFD7C7FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🪙 ${_giftInt(data['pool_balance'])}',
                        style: const TextStyle(
                          color: Color(0xFFFFD45A),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reset $countdownText • up to ${_giftInt(data['max_multiplier'])}×',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_giftInt(data['high_win_multiplier'])}×+ rare • ${_giftInt(data['banner_multiplier'])}×+ banner',
                        style: const TextStyle(
                          color: Color(0xFFFFEFA8),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Lucky Day Ranking',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (ranking.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No Lucky Gift ranking yet today.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  for (var index = 0;
                      index < math.min(10, ranking.length);
                      index++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFF2E2140),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Color(0xFFFFD45A),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      title: Text(
                        ranking[index]['display_name']?.toString() ??
                            ranking[index]['user_id']?.toString() ??
                            'User',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        'Sent ${_giftInt(ranking[index]['sent_count'])} • Highest ${_giftInt(ranking[index]['highest_multiplier'])}×',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                      trailing: Text(
                        '+${_giftInt(ranking[index]['rebate_coins'])}',
                        style: const TextStyle(
                          color: Color(0xFFFFD45A),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                const SizedBox(height: 4),
                Text(
                  'Top shares: ${shares.map((value) => value.toString() + '%').join(' • ')}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                  ),
                ),
                if (_giftInt(data['remaining_share_percent']) > 0)
                  Text(
                    'Remaining ${_giftInt(data['remaining_share_percent'])}% stays in the pool unless Owner Panel changes the shares.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 8,
                    ),
                  ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent Lucky Sessions',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      'No Lucky session yet.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  for (final session in sessions.take(8))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21162B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _giftInt(session['highest_multiplier']) >= 200
                              ? const Color(0xFFFFD45A)
                              : const Color(0x554E3A5C),
                        ),
                      ),
                      child: Text(
                        'Total won ${_giftInt(session['total_rebate_coins'])} by sending '
                        '${_giftInt(session['send_count'])}×${_giftInt(session['unit_price'])} coins'
                        ' — Highest ×${_giftInt(session['highest_multiplier'])}',
                        style: const TextStyle(
                          color: Color(0xFFEBDDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showGiftSheet({String? preselectedUserId}) {
    final senderId = widget.state.auth.current?.userId;
    if (senderId == null) return;
    if (preselectedUserId != null && preselectedUserId != senderId) {
      _selectedGiftRecipients
        ..clear()
        ..add(preselectedUserId);
    }

    var giftCategory = 'Normal';
    var luckyQuantity = 1;
    var giftSendInFlight = false;
    GiftDefinition? selectedGift;
    const giftCategories = <String>[
      'Normal',
      'Lucky',
      'CP',
      'Country',
      'Luxury',
    ];

    List<GiftDefinition> visibleGifts() {
      switch(giftCategory) {
        case 'Lucky': return GiftService.luckyCatalog;
        case 'CP': return PremiumGiftCatalog.cp;
        case 'Country': return PremiumGiftCatalog.countries;
        case 'Luxury': return PremiumGiftCatalog.normal.where((gift)=>gift.price>=1000000).toList();
        default: return PremiumGiftCatalog.normal;
      }
    }

    List<(String, String)> recipients() {
      final account = widget.state.auth.current;
      final values = <(String, String)>[];

      void addRecipient(String id, String name) {
        if (id.trim().isEmpty || values.any((item) => item.$1 == id)) return;
        values.add((id, name.trim().isEmpty ? id : name.trim()));
      }

      // Only real user IDs are allowed here. Never invent seat-N recipient IDs,
      // because the server cannot route diamonds/effects to a placeholder.
      for (var index = 0; index < controller.seats.length; index++) {
        for (final member in widget.state.roomSession.liveMembers) {
          if (member.seatIndex == index) {
            addRecipient(member.userId, member.displayName);
            break;
          }
        }
      }
      for (final member in widget.state.roomSession.liveMembers) {
        addRecipient(member.userId, member.displayName);
      }
      addRecipient(senderId, account?.displayName ?? 'You');

      _selectedGiftRecipients.removeWhere(
        (id) => !values.any((item) => item.$1 == id),
      );
      if (_selectedGiftRecipients.isEmpty && values.isNotEmpty) {
        _selectedGiftRecipients.add(values.first.$1);
      }
      return values;
    }

    Future<void> sendSelectedGift(
      BuildContext sheetContext,
      GiftDefinition gift,
    ) async {
      if (_selectedGiftRecipients.isEmpty) {
        _snack('Select at least one recipient.');
        return;
      }

      if (gift.lucky) {
        final selectedRecipients =
            _selectedGiftRecipients.toList(growable: false);
        // Close the gift sheet immediately on a valid Lucky send tap. The
        // network request continues on the room screen so the Combo control
        // becomes the visible continuation UI instead of leaving the panel
        // covering it while the server responds.
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        await _sendLuckyGift(
          gift,
          selectedRecipients,
          quantity: luckyQuantity,
        );
        return;
      }

      final selectedRecipients =
          _selectedGiftRecipients.toList(growable: false);
      Map<String, dynamic> response;
      try {
        response = await widget.state.roomSession.sendGift(
          roomId: widget.room.id,
          authToken: widget.state.auth.current!.authToken,
          giftId: gift.id,
          giftName: gift.name,
          quantity: 1,
          unitPrice: gift.price,
          receiverIds: selectedRecipients,
        );
        _applyGiftServerWallet(response);
        _refreshRoomSendingSummary();
        // Any non-Lucky send breaks the "same Lucky gift consecutively"
        // sequence, so an older Combo must not remain actionable.
        _resetLuckyComboState();
      } catch (error) {
        final message =
            error.toString().replaceFirst('Bad state: ', '');
        if (message.toLowerCase().contains('insufficient coins')) {
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          await _openRechargeDirect();
        } else {
          _snack(message);
        }
        return;
      }

      final serverTotal = _giftInt(response['total_cost']);
      final tx = GiftTransaction(
        gift: gift,
        quantity: 1,
        senderId: senderId,
        receiverIds: List<String>.unmodifiable(selectedRecipients),
        totalCost: serverTotal > 0
            ? serverTotal
            : gift.price * selectedRecipients.length,
      );
      widget.state.gifts.sent.insert(0, tx);
      // Sending any non-Lucky gift ends a previously armed Lucky Combo
      // immediately so a stale Combo tab never survives unrelated gifting.
      if (_luckyComboGift != null) {
        setState(_resetLuckyComboState);
      }
      _triggerSeatGiftEffect(gift, selectedRecipients);

      if (!sheetContext.mounted) return;
      Navigator.pop(sheetContext);
      widget.state.activities.addGiftScore(senderId, tx.totalCost);
      widget.state.identity.gainVipExperience(tx.totalCost ~/ 10);
      _snack(
        '${gift.name} sent to ${tx.receiverIds.length} user(s).',
      );
      if (mounted) setState(() {});
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final roomRecipients = recipients();
          final filteredGifts = visibleGifts();
          return SafeArea(
            key: const Key('room-gift-panel'),
            child: SizedBox(
              height: 470,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Gift',
                            style: TextStyle(
                              color: FeaturePalette.gift,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('room-custom-gift-create'),
                          tooltip: 'Create Custom Gift',
                          onPressed: () {
                            Navigator.pop(context);
                            unawaited(_createRoomCustomGift());
                          },
                          icon: const Icon(
                            Icons.add_photo_alternate_rounded,
                            color: FeaturePalette.gift,
                          ),
                        ),
                        if (giftCategory == 'Lucky')
                          IconButton(
                            key: const Key('lucky-gift-details-button'),
                            tooltip: 'Lucky Gift details',
                            onPressed: () {
                              Navigator.pop(context);
                              unawaited(_showLuckyGiftDetails());
                            },
                            icon: const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFFFC247),
                            ),
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: giftCategories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 7),
                      itemBuilder: (_, index) {
                        final value = giftCategories[index];
                        final color = value == 'Lucky'
                            ? const Color(0xFFFFC247)
                            : value == 'CP'
                                ? FeaturePalette.cp
                                : value == 'Country'
                                    ? FeaturePalette.family
                                    : value == 'Luxury'
                                        ? FeaturePalette.vip
                                        : FeaturePalette.social;
                        return ChoiceChip(
                          key: Key(
                            'gift-category-' + value.toLowerCase(),
                          ),
                          label: Text(value),
                          selected: giftCategory == value,
                          selectedColor: color.withValues(alpha: 0.28),
                          side: BorderSide(
                            color: giftCategory == value
                                ? color
                                : RoyalPalette.bronze,
                          ),
                          labelStyle: TextStyle(
                            color: giftCategory == value
                                ? color
                                : RoyalPalette.cream,
                            fontWeight: FontWeight.w800,
                          ),
                          onSelected: (_) {
                            setSheetState(() {
                              giftCategory = value;
                              selectedGift = null;
                              luckyQuantity = 1;
                            });
                          },
                        );
                      },
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
                              // Multi-select is intentional. The backend and
                              // animation routing receive exactly this real-ID
                              // set; no seat placeholder IDs are allowed.
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
                                          ? FeaturePalette.gift
                                          : FeaturePalette.social
                                              .withValues(alpha: 0.45),
                                      width: selected ? 3 : 1.5,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: FeaturePalette.gift
                                                  .withValues(alpha: 0.36),
                                              blurRadius: 12,
                                            ),
                                          ]
                                        : const [],
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipOval(
                                        child: ImageFiltered(
                                          key: Key(
                                            'gift-recipient-blur-${recipient.$1}',
                                          ),
                                          imageFilter: ui.ImageFilter.blur(
                                            sigmaX: selected ? 2.4 : 0,
                                            sigmaY: selected ? 2.4 : 0,
                                          ),
                                          child: Builder(
                                            builder: (_) {
                                              final account =
                                                  widget.state.auth.current;
                                              String? avatar;
                                              if (recipient.$1 == senderId) {
                                                avatar = account?.avatarDataUrl;
                                              } else {
                                                for (final member in widget
                                                    .state
                                                    .roomSession
                                                    .liveMembers) {
                                                  if (member.userId ==
                                                      recipient.$1) {
                                                    avatar =
                                                        member.avatarDataUrl;
                                                    break;
                                                  }
                                                }
                                              }
                                              final provider =
                                                  _roomAvatarProvider(avatar);
                                              if (provider != null) {
                                                return DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    image: DecorationImage(
                                                      image: provider,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return Icon(
                                                recipient.$1 == senderId
                                                    ? Icons
                                                        .account_circle_rounded
                                                    : Icons.person_rounded,
                                                color: FeaturePalette.social,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        DecoratedBox(
                                          key: Key(
                                            'gift-recipient-selected-${recipient.$1}',
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black
                                                .withValues(alpha: 0.20),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.check_rounded,
                                              color: Color(0xFFFFD45A),
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                    ],
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
                  if (giftCategory == 'Lucky')
                    Container(
                      key: const Key('lucky-gift-quantity-selector'),
                      height: 38,
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21162B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0x88FFD45A),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.repeat_rounded,
                            color: Color(0xFFFFD45A),
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Lucky quantity • independent result per unit',
                              style: TextStyle(
                                color: RoyalPalette.cream,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('lucky-quantity-minus'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            onPressed: luckyQuantity <= 1
                                ? null
                                : () => setSheetState(
                                      () => luckyQuantity--,
                                    ),
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                              size: 20,
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            child: Text(
                              luckyQuantity.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFD45A),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('lucky-quantity-plus'),
                            tooltip: 'Add one',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 30,
                            ),
                            onPressed: luckyQuantity >= 7999
                                ? null
                                : () => setSheetState(
                                      () => luckyQuantity++,
                                    ),
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 20,
                            ),
                          ),
                          PopupMenuButton<int>(
                            key: const Key('lucky-quantity-presets'),
                            tooltip: 'Choose Lucky quantity',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 30,
                            ),
                            color: const Color(0xFF24152F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Color(0x88FFD45A),
                              ),
                            ),
                            onSelected: (value) {
                              setSheetState(() => luckyQuantity = value);
                            },
                            itemBuilder: (context) => const <int>[
                              9,
                              21,
                              51,
                              99,
                              199,
                              599,
                              899,
                              2999,
                              7999,
                            ]
                                .map(
                                  (value) => PopupMenuItem<int>(
                                    value: value,
                                    height: 34,
                                    child: Text(
                                      '×$value',
                                      style: TextStyle(
                                        color: Color(0xFFFFD45A),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            child: const Icon(
                              Icons.arrow_drop_down_circle_outlined,
                              size: 19,
                              color: Color(0xFFFFD45A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredGifts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.82,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemBuilder: (_, index) {
                        final gift = filteredGifts[index];
                        return RoyalPanel(
                          padding: const EdgeInsets.all(8),
                          onTap: () {
                            setSheetState(() {
                              selectedGift = gift;
                            });
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: Center(
                                  child: gift.lucky
                                      ? Container(
                                          width: 54,
                                          height: 54,
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const RadialGradient(
                                              colors: <Color>[
                                                Color(0x66FFFFFF),
                                                Color(0x445C2A80),
                                                Colors.transparent,
                                              ],
                                            ),
                                            border: Border.all(
                                              color: const Color(0x88FFD45A),
                                              width: 1,
                                            ),
                                            boxShadow: const <BoxShadow>[
                                              BoxShadow(
                                                color: Color(0x66FFB84D),
                                                blurRadius: 9,
                                              ),
                                            ],
                                          ),
                                          child: _luckyArtwork(
                                            gift,
                                            size: 50,
                                          ),
                                        )
                                      : _luckyArtwork(gift,size:54),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (selectedGift?.id == gift.id) ...[
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 13,
                                      color: Color(0xFFFFD45A),
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Flexible(
                                    child: Text(
                                      gift.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selectedGift?.id == gift.id
                                            ? const Color(0xFFFFD45A)
                                            : RoyalPalette.cream,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${gift.price}',
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
                  Container(
                    key: const Key('room-gift-send-bar'),
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    decoration: const BoxDecoration(
                      color: RoyalPalette.nearBlack,
                      border: Border(
                        top: BorderSide(
                          color: Color(0x335C4A72),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.monetization_on_rounded,
                                    color: Color(0xFFFFD45A),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Total Coins  ' +
                                        widget.state.wallet.coins.toString(),
                                    key: const Key('room-gift-wallet-coins'),
                                    style: const TextStyle(
                                      color: Color(0xFFFFD45A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 118,
                          height: 42,
                          child: FilledButton.icon(
                            key: const Key('room-gift-send-button'),
                            onPressed: selectedGift == null ||
                                    _selectedGiftRecipients.isEmpty ||
                                    giftSendInFlight
                                ? null
                                : () {
                                    setSheetState(
                                      () => giftSendInFlight = true,
                                    );
                                    unawaited(
                                      sendSelectedGift(
                                        context,
                                        selectedGift!,
                                      ).whenComplete(() {
                                        if (context.mounted) {
                                          setSheetState(
                                            () => giftSendInFlight = false,
                                          );
                                        }
                                      }),
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFFFFC247),
                              foregroundColor:
                                  const Color(0xFF1A111F),
                              disabledBackgroundColor:
                                  const Color(0xFF3A3140),
                              disabledForegroundColor:
                                  RoyalPalette.muted,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(22),
                              ),
                            ),
                            icon: giftSendInFlight
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1A111F),
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              selectedGift?.lucky == true &&
                                      luckyQuantity > 1
                                  ? 'Send ×$luckyQuantity'
                                  : 'Send',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
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

  void _showRoomMusic() {
    final account = widget.state.auth.current;
    if (account == null) {
      _snack('Please sign in to use room music.');
      return;
    }
    unawaited(widget.state.ktv.loadLocalSongs());

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final songs = widget.state.ktv.library;
          final current = widget.state.ktv.current;
          final localSongCount = widget.state.ktv.localSongCount;
          final canAddLocalSong = widget.state.ktv.canAddLocalSong;
          final canPlayPrevious = widget.state.ktv.canPlayPrevious;
          final canPlayNext = widget.state.ktv.canPlayNext;
          final musicPlaying = widget.state.ktv.isPlaying;
          final onSeat = controller.mySeat != null;
          return SafeArea(
            key: const Key('room-music-panel'),
            child: SizedBox(
              height: 470,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Music',
                        style: TextStyle(
                          color: FeaturePalette.music,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: FeaturePalette.glow(FeaturePalette.music),
                      border: Border.all(
                        color: FeaturePalette.music.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      children: [
                        const ShiningIcon(
                          icon: Icons.graphic_eq_rounded,
                          color: FeaturePalette.music,
                          size: 22,
                          boxSize: 40,
                          glow: 0.34,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current == null
                                    ? 'Nothing playing'
                                    : current.song.title,
                                style: const TextStyle(
                                  color: RoyalPalette.cream,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                current == null
                                    ? 'Tap a song below to add and play it.'
                                    : current.song.singer +
                                        ' • Queue ' +
                                        widget.state.ktv.queue.length.toString(),
                                style: const TextStyle(
                                  color: RoyalPalette.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          key: const Key('room-music-previous-button'),
                          tooltip: 'Previous',
                          onPressed: onSeat && canPlayPrevious
                              ? () async {
                                  await widget.state.ktv.playPrevious();
                                  setSheetState(() {});
                                }
                              : null,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        IconButton(
                          key: const Key('room-music-play-pause-button'),
                          tooltip: musicPlaying ? 'Pause' : 'Play',
                          onPressed: onSeat && current != null
                              ? () async {
                                  await widget.state.ktv.togglePlayPause();
                                  setSheetState(() {});
                                }
                              : null,
                          icon: Icon(
                            musicPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 34,
                            color: FeaturePalette.music,
                          ),
                        ),
                        IconButton(
                          key: const Key('room-music-stop-button'),
                          tooltip: 'Stop',
                          onPressed: onSeat && current != null
                              ? () async {
                                  await widget.state.ktv.stopPlayback();
                                  setSheetState(() {});
                                }
                              : null,
                          icon: const Icon(Icons.stop_circle_rounded),
                        ),
                        IconButton(
                          key: const Key('room-music-next-button'),
                          tooltip: 'Next',
                          onPressed: onSeat && canPlayNext
                              ? () async {
                                  await widget.state.ktv.playNext();
                                  setSheetState(() {});
                                }
                              : null,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('room-add-music-button'),
                        onPressed: canAddLocalSong && onSeat
                            ? () async {
                          final file = await FilePicker.pickFile(
                            dialogTitle: 'Add Music',
                            type: FileType.audio,
                          );
                          if (file == null || !sheetContext.mounted) return;
                          final path = file.path;
                          if (path == null || path.isEmpty) {
                            _snack('This audio file could not be opened.');
                            return;
                          }
                          final song = await widget.state.ktv.importLocalSong(
                            fileName: file.name,
                            sourcePath: path,
                          );
                          widget.state.ktv.addToQueue(
                            song,
                            account.userId,
                          );
                          if (widget.state.ktv.current == null) {
                            widget.state.ktv.startNext();
                            await widget.state.ktv.playCurrent();
                          }
                          setSheetState(() {});
                          _snack(song.title + ' added from phone.');
                        }
                            : null,
                        icon: const Icon(Icons.library_music_rounded),
                        label: const Text('Add Music'),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        localSongCount.toString() +
                            '/' +
                            KtvService.maxLocalSongs.toString() +
                            ' songs added',
                        key: const Key('room-music-count'),
                        style: TextStyle(
                          color: canAddLocalSong
                              ? RoyalPalette.muted
                              : FeaturePalette.safety,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: songs.isEmpty
                        ? const Center(
                            child: Text(
                              'No music is available right now.',
                              style: TextStyle(color: RoyalPalette.muted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            itemCount: songs.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final song = songs[index];
                              return ListTile(
                                leading: const ShiningIcon(
                                  icon: Icons.music_note_rounded,
                                  color: FeaturePalette.music,
                                  size: 20,
                                  boxSize: 38,
                                  glow: 0.34,
                                ),
                                title: Text(song.title),
                                subtitle: Text(
                                  song.local
                                      ? 'From phone • ' + song.singer
                                      : song.singer,
                                ),
                                trailing: song.local
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.playlist_add_rounded,
                                          ),
                                          IconButton(
                                            key: Key(
                                              'remove-music-' + song.id,
                                            ),
                                            tooltip: 'Remove Music',
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: FeaturePalette.safety,
                                            ),
                                            onPressed: () async {
                                              final remove =
                                                  await showDialog<bool>(
                                                context: sheetContext,
                                                builder: (dialogContext) =>
                                                    AlertDialog(
                                                  title: const Text(
                                                    'Remove Music',
                                                  ),
                                                  content: Text(
                                                    'Remove "' +
                                                        song.title +
                                                        '" from the music list?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                        dialogContext,
                                                        false,
                                                      ),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                        dialogContext,
                                                        true,
                                                      ),
                                                      child: const Text(
                                                        'Remove',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (remove != true ||
                                                  !sheetContext.mounted) {
                                                return;
                                              }
                                              final removed = await widget.state.ktv
                                                  .removeLocalSongAndFile(song.id);
                                              if (removed) {
                                                setSheetState(() {});
                                                _snack(
                                                  song.title + ' removed.',
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      )
                                    : const Icon(
                                        Icons.playlist_add_rounded,
                                      ),
                                onTap: onSeat
                                    ? () async {
                                        widget.state.ktv
                                            .addToQueue(song, account.userId);
                                        if (widget.state.ktv.current == null) {
                                          widget.state.ktv.startNext();
                                          await widget.state.ktv.playCurrent();
                                        }
                                        setSheetState(() {});
                                      }
                                    : () {
                                        _snack(
                                          'Join a room seat before playing music.',
                                        );
                                      },
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

  void _showRoomLuckyBag() {
    final account = widget.state.auth.current;
    if (account == null) {
      _snack('Please sign in to use LP.');
      return;
    }
    var selectedUsers = 5;
    var selectedCoins = 100000;
    var refreshKey = 0;
    const allowed = <int, List<int>>{
      5: <int>[100000, 500000, 1000000, 2000000, 5000000, 8000000, 10000000],
      20: <int>[100000, 500000, 1000000, 2000000, 5000000, 8000000, 10000000],
      50: <int>[500000, 1000000, 2000000, 5000000, 8000000, 10000000],
      100: <int>[1000000, 2000000, 5000000, 8000000, 10000000],
      200: <int>[1000000, 2000000, 5000000, 8000000, 10000000],
      500: <int>[2000000, 5000000, 8000000, 10000000],
    };
    String coinLabel(int value) {
      if (value == 100000) return '1L';
      if (value == 500000) return '5L';
      return (value ~/ 1000000).toString() + 'M';
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final future = widget.state.discovery.luckyPouch(
            authToken: account.authToken,
            roomId: widget.room.id,
          );
          return SafeArea(
            key: const Key('room-lucky-bag-panel'),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.72,
              child: FutureBuilder<Map<String, dynamic>>(
                key: ValueKey<int>(refreshKey),
                future: future,
                builder: (context, snapshot) {
                  final pouch = snapshot.data?['pouch'];
                  final active = pouch is Map &&
                      (pouch['remaining_slots'] as num? ?? 0).toInt() > 0;
                  final claimed = active && pouch['claimed'] == true;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A050B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: RoyalPalette.gold, width: 1.4),
                              boxShadow: const [
                                BoxShadow(color: Color(0x557A0B16), blurRadius: 16),
                              ],
                            ),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              color: Color(0xFFD71932),
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'LP • Lucky Pouch',
                              style: TextStyle(
                                color: RoyalPalette.gold,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (active) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF350409),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RoyalPalette.gold),
                          ),
                          child: Text(
                            (pouch['remaining_slots']?.toString() ?? '0') +
                                ' users left • ' +
                                coinLabel((pouch['remaining_coins'] as num? ?? 0).toInt()) +
                                ' pool remaining',
                            style: const TextStyle(
                              color: RoyalPalette.cream,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          key: const Key('room-lp-open'),
                          onPressed: claimed
                              ? null
                              : () async {
                                  try {
                                    final result = await widget.state.discovery.claimLuckyPouch(
                                      authToken: account.authToken,
                                      roomId: widget.room.id,
                                    );
                                    if (result['ok'] == true) {
                                      _snack('LP received: ' +
                                          coinLabel((result['coins'] as num? ?? 0).toInt()));
                                    } else {
                                      _snack(result['message']?.toString() ?? 'Next Time');
                                    }
                                    setSheetState(() => refreshKey++);
                                  } catch (error) {
                                    _snack(error.toString().replaceFirst('Bad state: ', ''));
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF760A16),
                            foregroundColor: RoyalPalette.gold,
                          ),
                          icon: const Icon(Icons.touch_app_rounded),
                          label: Text(claimed ? 'Already Opened' : 'OPEN'),
                        ),
                        const Divider(height: 30),
                      ],
                      const Text(
                        '1. Select users',
                        style: TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: allowed.keys.map((count) => ChoiceChip(
                          label: Text(count.toString() + ' users'),
                          selected: selectedUsers == count,
                          onSelected: (_) => setSheetState(() {
                            selectedUsers = count;
                            selectedCoins = allowed[count]!.first;
                          }),
                        )).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '2. Select coins',
                        style: TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: allowed[selectedUsers]!.map((coins) => ChoiceChip(
                          label: Text(coinLabel(coins)),
                          selected: selectedCoins == coins,
                          onSelected: (_) => setSheetState(() => selectedCoins = coins),
                        )).toList(),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('room-lp-confirm'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF650812),
                          foregroundColor: RoyalPalette.gold,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () async {
                          try {
                            await widget.state.discovery.openLuckyPouch(
                              authToken: account.authToken,
                              roomId: widget.room.id,
                              users: selectedUsers,
                              coins: selectedCoins,
                            );
                            _snack('LP opened for ' +
                                selectedUsers.toString() +
                                ' users • ' +
                                coinLabel(selectedCoins));
                            setSheetState(() => refreshKey++);
                          } catch (error) {
                            _snack(error.toString().replaceFirst('Bad state: ', ''));
                          }
                        },
                        child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ignore: unused_element
  void _showRoomModerationCenter() {
    final currentUserId = widget.state.auth.current?.userId;
    final members = widget.state.roomSession.liveMembers
        .where((member) => member.userId != currentUserId)
        .toList(growable: false);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        key: const Key('room-moderation-panel'),
        child: SizedBox(
          height: 470,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Moderation',
                    style: TextStyle(
                      color: FeaturePalette.safety,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (!_canModerateSeats)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Moderation controls are available to the room owner and room admins.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: RoyalPalette.muted),
                      ),
                    ),
                  ),
                )
              else if (members.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No other users are in the room.',
                      style: TextStyle(color: RoyalPalette.muted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final member = members[index];
                      final seat = member.seatIndex;
                      return ListTile(
                        leading: const ShiningIcon(
                          icon: Icons.shield_rounded,
                          color: FeaturePalette.safety,
                          size: 20,
                          boxSize: 38,
                          glow: 0.34,
                        ),
                        title: Text(member.displayName),
                        subtitle: Text(
                          seat == null
                              ? 'Audience • Tap for moderation actions'
                              : 'Seat ' +
                                  (seat + 1).toString() +
                                  ' • Tap for moderation actions',
                        ),
                        trailing:
                            const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Future<void>.delayed(Duration.zero, () {
                            if (mounted) {
                              _showUserProfile(
                                member,
                                seatIndexHint: seat,
                              );
                            }
                          });
                        },
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

  Color _roomToolColor(String label) {
    final value = label.toLowerCase();
    if (value.contains('fruit jackpot')) return FeaturePalette.fruitJackpot;
    if (value.contains('fruit party')) return FeaturePalette.fruitParty;
    if (value.contains('game')) return FeaturePalette.games;
    if (value.contains('gift')) return FeaturePalette.gift;
    if (value.contains('music') || value.contains('sound')) {
      return FeaturePalette.music;
    }
    if (value.contains('lp') || value.contains('lucky bag')) {
      return const Color(0xFFD71932);
    }
    if (value.contains('rocket')) return FeaturePalette.rocket;
    if (value.contains('moderation')) return const Color(0xFFFF5A5F);
    if (value.contains('friend')) return const Color(0xFF42D392);
    if (value.contains('event')) return const Color(0xFFFF8A34);
    if (value.contains('effect')) return const Color(0xFFFF4FA3);
    if (value.contains('notice')) return const Color(0xFF44C8FF);
    if (value.contains('theme')) return const Color(0xFFB56CFF);
    if (value.contains('seat') || value.contains('request')) {
      return const Color(0xFF42D392);
    }
    if (value.contains('lucky')) return const Color(0xFFFFD45A);
    if (value.contains('pk')) return const Color(0xFFFF5A5F);
    if (value.contains('locked') || value.contains('report')) {
      return const Color(0xFFFF4B4B);
    }
    if (value.contains('open')) return const Color(0xFF42D392);
    if (value.contains('screen')) return const Color(0xFF44C8FF);
    if (value.contains('setting')) return const Color(0xFFFFD45A);
    return FeaturePalette.social;
  }

  Widget _roomActionLogo({
    required String label,
    required IconData icon,
    double size = 42,
  }) {
    return _PremiumRoomToolLogo(label: label, fallbackIcon: icon, size: size);
  }

  void _showGamePanel() {
    final account = widget.state.auth.current;
    if (account == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF241033),
      builder: (sheetContext) => SafeArea(
        key: const Key('room-game-center-panel'),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.58,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Game Center',
                    style: TextStyle(
                      color: RoyalPalette.cream,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  key: const Key('room-game-center-profile-card'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34233E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6E4B7D),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF151018),
                        backgroundImage: _roomPhotoProvider,
                        child: _roomPhotoProvider == null
                            ? Text(
                                _roomTitle.isEmpty
                                    ? '?'
                                    : _roomTitle.characters.first.toUpperCase(),
                                style: const TextStyle(
                                  color: RoyalPalette.cream,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _roomTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: RoyalPalette.cream,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: const LinearProgressIndicator(
                                value: 0.15,
                                minHeight: 6,
                                backgroundColor: Color(0xFF1A1320),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFB62E),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Room Lv.' +
                                  _roomSnapshot.roomLevel.toString() +
                                  ' • Play Tinni games',
                              style: const TextStyle(
                                color: RoyalPalette.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '🪙 ' + widget.state.wallet.coins.toString(),
                        style: const TextStyle(
                          color: Color(0xFFFFD45A),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'All Games',
                  style: TextStyle(
                    color: RoyalPalette.cream,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.82,
                    children: [
                      _ReferenceGameTile(
                        key: const Key('game-center-fruit-jackpot'),
                        label: 'Fruit Jackpot',
                        icon: Icons.casino_rounded,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          setState(() {
                            _fruitJackpotOpen = true;
                            _fruitPartyOpen = false;
                          });
                        },
                      ),
                      _ReferenceGameTile(
                        key: const Key('game-center-fruit-party'),
                        label: 'Fruit Party',
                        icon: Icons.local_activity_rounded,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          setState(() {
                            _fruitPartyOpen = true;
                            _fruitJackpotOpen = false;
                          });
                        },
                      ),
                      _ReferenceGameTile(
                        key: const Key('game-center-ludo'),
                        label: 'Ludo',
                        icon: Icons.grid_view_rounded,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          showModalBottomSheet<void>(
                            context: context, isScrollControlled: true,
                            useSafeArea: false,
                            constraints: BoxConstraints.tightFor(
                              height: MediaQuery.sizeOf(context).height * 0.50),
                            builder: (_) => LudoScreen(
                              state: widget.state, roomId: widget.room.id),
                          );
                        },
                      ),
                      const _ReferenceGameTile(
                        label: 'Coming Soon',
                        icon: Icons.lock_clock_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRocketPanel() {
    final rocketFuture = _loadRoomSendingSummary();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setRocketSheetState) => FractionallySizedBox(
        heightFactor: 0.76,
        child: Container(
          key: const Key('room-rocket-panel'),
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFF07143B),
                Color(0xFF0B2564),
                Color(0xFF08163F),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFC94A),
              width: 1.1,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x665D3BFF),
                blurRadius: 24,
              ),
            ],
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: rocketFuture,
            builder: (context, snapshot) {
              final total =
                  (snapshot.data?['lifetime_total'] as num? ?? 0).toInt();
              final rocket = _rocketProgressState(total);
              final completed = rocket['completed']!.toInt();
              final currentIndex = rocket['current_index']!.toInt();
              final currentTarget = rocket['current_target']!.toInt();
              final currentProgress = rocket['current_progress']!.toInt();
              final percent = rocket['percent']!.toDouble();
              final allComplete = completed >= _rocketStageTargets.length;

              final selectedLevel = _selectedRocketPreviewLevel ?? (allComplete ? 10 : currentIndex + 1);
              final levels = (snapshot.data?['rocket_levels'] as List? ?? const []).whereType<Map>().toList();
              final rewardData = levels.where((row) => row['level'] == selectedLevel).firstOrNull;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.help_outline_rounded,
                          color: RoyalPalette.cream,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rocket ' +
                              (allComplete ? 10 : currentIndex + 1).toString() +
                              '/10',
                          style: const TextStyle(
                            color: Color(0xFFFFD45A),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _compactRoomSending(total),
                          key: const Key('room-rocket-social-total'),
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          key: const Key('room-rocket-close'),
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: RoyalPalette.cream,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 86,
                          child: Scrollbar(
                            controller: _rocketLevelScrollController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              key: const Key('room-rocket-level-scroll'),
                              controller: _rocketLevelScrollController,
                              primary: false,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              itemCount: _rocketStageTargets.length,
                              itemBuilder: (context, index) {
                                final done = index < completed;
                                final current =
                                    !allComplete && index == currentIndex;
                                final target = _rocketStageTargets[index];
                                final color = done
                                    ? const Color(0xFFFFD45A)
                                    : current
                                        ? const Color(0xFF61D9FF)
                                        : const Color(0xFF56627E);
                                final level=index+1;
                                final previewSelected=
                                    _selectedRocketPreviewLevel==level;
                                return InkWell(
                                  key: Key(
                                    'room-rocket-stage-' + level.toString(),
                                  ),
                                  onTap: () {
                                    setRocketSheetState(() {
                                      _selectedRocketPreviewLevel=level;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 7),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: previewSelected
                                          ? const Color(0xFF173E8F)
                                          : current
                                              ? const Color(0xFF0D2D72)
                                              : const Color(0xFF071B4D),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: previewSelected
                                            ? const Color(0xFFFFFFFF)
                                            : color.withValues(alpha: 0.95),
                                        width: previewSelected
                                            ? 2
                                            : current
                                                ? 1.6
                                                : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          child: Text(
                                            level.toString(),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              RocketModel(
                                                level: level,
                                                size: 20,
                                              ),
                                              Text(
                                                _compactRoomSending(target),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: RoyalPalette.cream,
                                                  fontSize: 7.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
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
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Center(
                            child: RocketModel(
                              key: Key(
                                'room-rocket-large-preview-' +
                                    (_selectedRocketPreviewLevel ??
                                            (allComplete
                                                ? 10
                                                : currentIndex + 1))
                                        .toString(),
                              ),
                              level: _selectedRocketPreviewLevel ??
                                  (allComplete ? 10 : currentIndex + 1),
                              size: 112,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                  RocketRewardsPanel(level: selectedLevel, data: rewardData == null ? null : Map<String, dynamic>.from(rewardData)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        key: const Key('room-rocket-progress'),
                        value: percent,
                        minHeight: 12,
                        backgroundColor: const Color(0xFF241B2C),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFD45A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    allComplete
                        ? '10/10 rockets complete'
                        : _compactRoomSending(currentProgress) +
                            ' / ' +
                            _compactRoomSending(currentTarget) +
                            '  •  ' +
                            (percent * 100).floor().toString() +
                            '%',
                    key: const Key('room-rocket-progress-label'),
                    style: const TextStyle(
                      color: Color(0xFFFFD45A),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
                    child: Text(
                      'Lucky gifts add 10% to Rocket. All other gifts add 100%.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB9C8F3),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _shareRoom() async {
    final text = 'Join my Tinni Star room: ' +
        _roomTitle +
        '\nRoom ID: ' +
        widget.room.id;
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (error) {
      _snack('Unable to share room right now.');
    }
  }

  // ignore: unused_element
  Future<void> _changeRoomCover() async {
    if (!_isRoomOwner) {
      _snack('Only the room owner can change the room cover.');
      return;
    }
    final account = widget.state.auth.current;
    if (account == null) return;

    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 68,
      maxWidth: 900,
      maxHeight: 900,
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    final mime = image.mimeType?.startsWith('image/') == true
        ? image.mimeType!
        : 'image/jpeg';
    final dataUrl = 'data:' + mime + ';base64,' + base64Encode(bytes);
    if (dataUrl.length > 450000) {
      _snack('Room cover is too large. Choose a smaller image.');
      return;
    }

    try {
      final updated = await widget.state.discovery.updateRoomRemote(
        authToken: account.authToken,
        roomId: widget.room.id,
        photoDataUrl: dataUrl,
      );
      _roomPhotoOverride = updated.photoDataUrl;
      _snack('Room cover updated.');
      if (mounted) setState(() {});
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _showRoomBlacklist([BuildContext? hostContext]) {
    final controls = widget.state.roomControls;
    showModalBottomSheet<void>(
      context: hostContext ?? context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final ids = controls.roomBlacklist.toList()..sort();
          return SafeArea(
            key: const Key('room-blacklist-panel'),
            child: SizedBox(
              height: 420,
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.person_off_rounded),
                    title: Text(
                      'Blacklist',
                      style: TextStyle(
                        color: RoyalPalette.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(
                      'Users blocked from this room.',
                      style: TextStyle(color: RoyalPalette.muted),
                    ),
                  ),
                  Expanded(
                    child: ids.isEmpty
                        ? const Center(
                            child: Text(
                              'No blacklisted users.',
                              style: TextStyle(color: RoyalPalette.muted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                            itemCount: ids.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final userId = ids[index];
                              return ListTile(
                                title: Text('ID ' + userId),
                                trailing: _isRoomOwner
                                    ? TextButton(
                                        onPressed: () {
                                          controls.unblacklist(userId);
                                          setSheetState(() {});
                                          if (mounted) setState(() {});
                                        },
                                        child: const Text('Remove'),
                                      )
                                    : null,
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

  // ignore: unused_element
  void _showRoomFeedback() {
    final ownerId = widget.room.ownerId ?? widget.room.id;
    final isOwnRoom = ownerId == widget.state.auth.current?.userId;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        key: const Key('room-feedback-panel'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.feedback_rounded),
                title: Text(
                  'Feedback',
                  style: TextStyle(
                    color: RoyalPalette.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  'Report a problem with this room or its owner.',
                  style: TextStyle(color: RoyalPalette.muted),
                ),
              ),
              ListTile(
                enabled: !isOwnRoom,
                leading: const Icon(Icons.report_rounded),
                title: Text(isOwnRoom ? 'Your own room' : 'Report room'),
                subtitle: Text(
                  isOwnRoom
                      ? 'You cannot report your own room.'
                      : 'Open the room/user report flow.',
                ),
                onTap: isOwnRoom
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        showReportUserSheet(
                          context: context,
                          state: widget.state,
                          targetUserId: ownerId,
                          targetDisplayName: widget.room.title,
                          roomId: widget.room.id,
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomTypePanel() {
    final controls = widget.state.roomControls;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => DefaultTabController(
        length: 4,
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            key: const Key('room-type-panel'),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.66,
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.dashboard_customize_rounded),
                    title: Text(
                      'Room Type',
                      style: TextStyle(
                        color: RoyalPalette.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Mic Types'),
                      Tab(text: 'Cover'),
                      Tab(text: 'Mic Theme'),
                      Tab(text: 'Setting'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ListTile(
                              key: const Key('room-type-mic-types'),
                              leading: const Icon(Icons.event_seat_rounded),
                              title: const Text('Mic Types'),
                              subtitle: Text(
                                controller.seats.length.toString() +
                                    ' seats • Tinni 8–42 layout',
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _showSeatCountSelector();
                              },
                            ),
                          ],
                        ),
                        ListView(
                          key: const Key('room-type-cover'),
                          padding: const EdgeInsets.all(16),
                          children: [
                            ListTile(
                              key: const Key('room-type-cover-open'),
                              leading: const Icon(Icons.image_rounded),
                              title: const Text('Room Cover / Theme'),
                              subtitle: const Text(
                                'Change the room background or theme.',
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              enabled: _isRoomOwner,
                              onTap: !_isRoomOwner
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      Future<void>.delayed(
                                        const Duration(milliseconds: 220),
                                        () {
                                          if (mounted) {
                                            _openRoomThemeSelector();
                                          }
                                        },
                                      );
                                    },
                            ),
                          ],
                        ),
                        ListView(
                          key: const Key('room-type-mic-theme'),
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Mic Theme',
                              style: TextStyle(
                                color: RoyalPalette.cream,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final entry in const <(String, String)>[
                              ('royal-gold', 'Royal Gold'),
                              ('neon-blue', 'Neon Blue'),
                              ('rose-glow', 'Rose Glow'),
                            ])
                              ListTile(
                                key: Key('mic-theme-' + entry.$1),
                                leading: Icon(
                                  controls.seatThemeId == entry.$1
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: controls.seatThemeId == entry.$1
                                      ? _seatThemeAccent
                                      : RoyalPalette.muted,
                                ),
                                title: Text(entry.$2),
                                enabled: _isRoomOwner,
                                onTap: !_isRoomOwner
                                    ? null
                                    : () async {
                                        final account =
                                            widget.state.auth.current;
                                        if (account == null) return;
                                        try {
                                          final updated = await widget
                                              .state.discovery
                                              .updateRoomRemote(
                                            authToken: account.authToken,
                                            roomId: widget.room.id,
                                            seatThemeId: entry.$1,
                                          );
                                          controls.setSeatTheme(
                                            updated.seatThemeId,
                                          );
                                          setSheetState(() {});
                                          if (mounted) setState(() {});
                                        } catch (error) {
                                          _snack(
                                            error
                                                .toString()
                                                .replaceFirst(
                                                  'Bad state: ',
                                                  '',
                                                ),
                                          );
                                        }
                                      },
                              ),
                          ],
                        ),
                        ListView(
                          key: const Key('room-type-setting'),
                          padding: const EdgeInsets.all(12),
                          children: [
                            ListTile(
                              key: const Key('room-type-setting-seats'),
                              leading: const Icon(Icons.event_seat_rounded),
                              title: const Text('Room Seats'),
                              subtitle: Text(
                                controller.seats.length.toString() + ' seats',
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: _showSeatCountSelector,
                            ),
                            if (_isRoomOwner)
                              SwitchListTile(
                                key: const Key('room-type-setting-lock'),
                                secondary: Icon(
                                  controls.settings.visibility ==
                                          RoomVisibility.privateRoom
                                      ? Icons.lock_rounded
                                      : Icons.lock_open_rounded,
                                  color: RoyalPalette.gold,
                                ),
                                title: const Text('Room Lock'),
                                subtitle: Text(
                                  controls.settings.visibility ==
                                          RoomVisibility.privateRoom
                                      ? (_roomLockPassword == null ||
                                              _roomLockPassword!.isEmpty
                                          ? 'Locked • loading password…'
                                          : 'Locked • Password ' +
                                              _roomLockPassword!)
                                      : 'Public • tap to generate room password',
                                ),
                                value: controls.settings.visibility ==
                                    RoomVisibility.privateRoom,
                                onChanged: (_) async {
                                  await _toggleRoomLock();
                                  setSheetState(() {});
                                },
                              ),
                            SwitchListTile(
                              title: const Text('Free mic'),
                              subtitle: const Text(
                                'When off, users send a mic request.',
                              ),
                              value: controller.inviteMode == false,
                              onChanged: !_isRoomOwner
                                  ? null
                                  : (value) async {
                                      try {
                                        await widget.state.roomSession
                                            .setRoomMicMode(
                                          value ? 'free' : 'apply',
                                        );
                                        controls.settings =
                                            controls.settings.copyWith(
                                          micMode: value
                                              ? MicMode.free
                                              : MicMode.apply,
                                        );
                                        setSheetState(() {});
                                        if (mounted) setState(() {});
                                      } catch (error) {
                                        _snack(
                                          error
                                              .toString()
                                              .replaceFirst(
                                                'Bad state: ',
                                                '',
                                              ),
                                        );
                                      }
                                    },
                            ),
                            SwitchListTile(
                              title: const Text(
                                'Only managers can speak',
                              ),
                              value:
                                  controls.settings.onlyManagersCanSpeak,
                              onChanged: !_isRoomOwner
                                  ? null
                                  : (value) {
                                      controls.settings =
                                          controls.settings.copyWith(
                                        onlyManagersCanSpeak: value,
                                      );
                                      setSheetState(() {});
                                      if (mounted) setState(() {});
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRoomEffects() {
    final controls = widget.state.roomControls;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget effectSwitch({
            required Key key,
            required String title,
            required String subtitle,
            required IconData icon,
            required bool value,
            required bool Function() toggle,
          }) {
            return SwitchListTile(
              key: key,
              value: value,
              activeThumbColor: RoyalPalette.gold,
              secondary: ShiningIcon(
                icon: icon,
                color: const Color(0xFFFF4FA3),
                size: 20,
                boxSize: 38,
                glow: 0.34,
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: RoyalPalette.cream,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: const TextStyle(
                  color: RoyalPalette.muted,
                  fontSize: 11,
                ),
              ),
              onChanged: (_) {
                toggle();
                setSheetState(() {});
                if (mounted) setState(() {});
              },
            );
          }

          return SafeArea(
            key: const Key('room-effects-panel'),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.72,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        ShiningIcon(
                          icon: Icons.auto_awesome_rounded,
                          color: Color(0xFFFF4FA3),
                          size: 24,
                          boxSize: 44,
                          glow: 0.42,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Effects',
                            style: TextStyle(
                              color: RoyalPalette.gold,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choose exactly which room effects you want to see or hear.',
                        style: TextStyle(
                          color: RoyalPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
                      children: [
                        SwitchListTile(
                          key: const Key('effect-master-effects'),
                          title: const Text('All Visual Effects'),
                          subtitle: const Text(
                            'Master switch for room visual effects.',
                          ),
                          value: controls.effectsEnabled,
                          onChanged: (_) {
                            controls.toggleEffects();
                            setSheetState(() {});
                            if (mounted) setState(() {});
                          },
                        ),
                        SwitchListTile(
                          key: const Key('effect-master-notices'),
                          title: const Text('Room Notices'),
                          subtitle: const Text(
                            'Show or hide general room notices.',
                          ),
                          value: controls.noticesVisible,
                          onChanged: (_) {
                            controls.toggleNotices();
                            setSheetState(() {});
                            if (mounted) setState(() {});
                          },
                        ),
                        effectSwitch(
                          key: const Key('effect-gift-effects'),
                          title: 'Gift Effects',
                          subtitle: 'Gift animation and full-screen gift effects.',
                          icon: Icons.card_giftcard_rounded,
                          value: controls.giftEffectsEnabled,
                          toggle: controls.toggleGiftEffects,
                        ),
                        effectSwitch(
                          key: const Key('effect-lucky-gift'),
                          title: 'Lucky Gift Effect',
                          subtitle: 'Special Lucky Gift animation and celebration.',
                          icon: Icons.auto_awesome_rounded,
                          value: controls.luckyGiftEffectEnabled,
                          toggle: controls.toggleLuckyGiftEffect,
                        ),
                        effectSwitch(
                          key: const Key('effect-gift-sound'),
                          title: 'Gift Sound',
                          subtitle: 'Sound played with supported gift effects.',
                          icon: Icons.volume_up_rounded,
                          value: controls.giftSoundEnabled,
                          toggle: controls.toggleGiftSound,
                        ),
                        effectSwitch(
                          key: const Key('effect-gift-fly-in'),
                          title: 'Gift Fly-in',
                          subtitle: 'Gift entry/fly-in animation in the room.',
                          icon: Icons.flight_takeoff_rounded,
                          value: controls.giftFlyInEnabled,
                          toggle: controls.toggleGiftFlyIn,
                        ),
                        effectSwitch(
                          key: const Key('effect-car-effects'),
                          title: 'Car Effects',
                          subtitle: 'Vehicle/car room-entry animations.',
                          icon: Icons.directions_car_filled_rounded,
                          value: controls.carEffectsEnabled,
                          toggle: controls.toggleCarEffects,
                        ),
                        effectSwitch(
                          key: const Key('effect-gift-bubble'),
                          title: 'Gift Bubble',
                          subtitle: 'Gift bubble/pop-up notices in the room.',
                          icon: Icons.chat_bubble_rounded,
                          value: controls.giftBubbleEnabled,
                          toggle: controls.toggleGiftBubble,
                        ),
                        effectSwitch(
                          key: const Key('effect-rocket-draw-notice'),
                          title: 'Rocket Draw Notice',
                          subtitle: 'Rocket draw/result notices and rocket effects.',
                          icon: Icons.rocket_launch_rounded,
                          value: controls.rocketDrawNoticeEnabled,
                          toggle: controls.toggleRocketDrawNotice,
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

  Future<void> _showPublicScreenMenu() async {
    if (!_canModerateSeats) {
      _snack('Only the room owner or room admin can control Public Screen.');
      return;
    }

    final controls = widget.state.roomControls;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          children: [
            const ListTile(
              title: Text(
                'Public Screen',
                style: TextStyle(
                  color: FeaturePalette.message,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ListTile(
              key: const Key('public-screen-admin-owner-only'),
              leading: const Icon(Icons.admin_panel_settings_rounded),
              title: const Text('Only Admin/Owner can type'),
              trailing: !widget.state.roomSession.presence.publicScreenEnabled
                  ? const Icon(Icons.check_rounded, color: RoyalPalette.gold)
                  : null,
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await widget.state.roomSession.setRoomPublicScreen(false);
                  controls.setPublicScreenEnabled(false);
                  if (mounted) setState(() {});
                  _snack('Public Screen: only Admin/Owner can type.');
                } catch (error) {
                  _snack(
                    error.toString().replaceFirst('Bad state: ', ''),
                  );
                }
              },
            ),
            ListTile(
              key: const Key('public-screen-everyone'),
              leading: const Icon(Icons.forum_rounded),
              title: const Text('Everyone can type'),
              trailing: widget.state.roomSession.presence.publicScreenEnabled
                  ? const Icon(Icons.check_rounded, color: RoyalPalette.gold)
                  : null,
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await widget.state.roomSession.setRoomPublicScreen(true);
                  controls.setPublicScreenEnabled(true);
                  if (mounted) setState(() {});
                  _snack('Public Screen: everyone can type.');
                } catch (error) {
                  _snack(
                    error.toString().replaceFirst('Bad state: ', ''),
                  );
                }
              },
            ),
            if (_canModerateSeats)
              ListTile(
                key: const Key('public-screen-clear-comments'),
                leading: const Icon(Icons.cleaning_services_rounded),
                title: const Text('Clear comments area'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await widget.state.roomSession.clearRoomComments();
                    _snack('Comments area cleared.');
                  } catch (error) {
                    _snack(
                      error.toString().replaceFirst('Bad state: ', ''),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showRoomTools() {
    final controls = widget.state.roomControls;
    final tools = <(String, IconData, VoidCallback)>[
      (
        'Room Type',
        Icons.dashboard_customize_rounded,
        _showRoomTypePanel,
      ),
      (
        'Music',
        Icons.music_note_rounded,
        () {
          Future<void>.delayed(Duration.zero, () {
            if (mounted) _showRoomMusic();
          });
        },
      ),
      (
        'Effects',
        Icons.auto_awesome_rounded,
        () {
          Future<void>.delayed(Duration.zero, () {
            if (mounted) _showRoomEffects();
          });
        },
      ),
      (
        'Lucky Bag',
        Icons.shopping_bag_rounded,
        () {
          Future<void>.delayed(Duration.zero, () {
            if (mounted) _showRoomLuckyBag();
          });
        },
      ),
      (
        controls.soundEnabled ? 'Sound On' : 'Sound Off',
        controls.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        () {
          final enabled = controls.toggleSound();
          Future<void>.delayed(Duration.zero, () async {
            try {
              await widget.state.roomSession.setRoomSoundEnabled(enabled);
              await widget.state.ktv.setOutputMuted(!enabled);
              _snack('Room sound ${enabled ? "enabled" : "muted"}.');
            } catch (error) {
              controls.toggleSound();
              await widget.state.ktv.setOutputMuted(enabled);
              _snack(
                error.toString().replaceFirst('Bad state: ', ''),
              );
              if (mounted) setState(() {});
            }
          });
        },
      ),
      (
        'Lucky Number',
        Icons.confirmation_number_rounded,
        () {
          Future<void>.delayed(Duration.zero, () async {
            try {
              await widget.state.roomSession.drawLuckyNumber();
            } catch (error) {
              _snack(
                error.toString().replaceFirst('Bad state: ', ''),
              );
            }
          });
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
        'Public Screen',
        Icons.tv_rounded,
        () {
          Future<void>.delayed(Duration.zero, () {
            if (mounted) _showPublicScreenMenu();
          });
        },
      ),
      (
        'Report',
        Icons.report_rounded,
        () {
          final target = widget.room.ownerId ?? widget.room.id;
          if (target == widget.state.auth.current?.userId) {
            _snack('You cannot report your own ID.');
            return;
          }
          showReportUserSheet(
            context: context,
            state: widget.state,
            targetUserId: target,
            targetDisplayName: widget.room.title,
            roomId: widget.room.id,
          );
        },
      ),
    ];

    final visibleTools = tools.where((tool) {
      final label = tool.$1;
      if (!_canModerateSeats &&
          (label == 'Room Type' || label == 'Music')) {
        return false;
      }
      if (!_isRoomOwner &&
          (label == 'Lock' || label == 'Unlock')) {
        return false;
      }
      if (!_canModerateSeats && label == 'Public Screen') {
        return false;
      }
      return true;
    }).toList(growable: false);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: visibleTools.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.88,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (_, index) {
              final tool = visibleTools[index];
              return InkWell(
                key: Key(
                  'room-tool-' +
                      tool.$1.toLowerCase().replaceAll(' ', '-'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Future<void>.delayed(
                    const Duration(milliseconds: 220),
                    () {
                      if (!mounted) return;
                      tool.$3();
                      setState(() {});
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: tool.$1 == 'Lucky Bag'
                          ? const <Color>[Color(0xFF5B0710), Color(0xFF220204)]
                          : <Color>[
                              Color.lerp(
                                const Color(0xFF080808),
                                _roomToolColor(tool.$1),
                                0.13,
                              )!,
                              const Color(0xFF030303),
                            ],
                    ),
                    border: Border.all(
                      color: RoyalPalette.gold.withValues(alpha: 0.88),
                      width: 1.05,
                    ),
                    boxShadow: <BoxShadow>[
                      const BoxShadow(color: Color(0x55FFD45A), blurRadius: 10),
                      BoxShadow(
                        color: _roomToolColor(tool.$1).withValues(alpha: 0.14),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _roomActionLogo(
                        label: tool.$1,
                        icon: tool.$2,
                        size: 42,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tool.$1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: RoyalPalette.cream,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static const List<int> _validRoomSeatCounts = <int>[
    8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18,
    19, 20, 21, 22, 23, 24, 25, 26, 27, 28,
    29, 30, 31, 32, 33, 34, 35,
    36, 37, 38, 39, 40, 41, 42,
  ];

  Future<void> _showSeatCountSelector() async {
    if (!_canModerateSeats) {
      _snack('Only the room owner or room admin can change seat count.');
      return;
    }
    final account = widget.state.auth.current;
    if (account == null) return;
    final current = controller.seats.length;
    final options = _isRoomOwner
        ? _validRoomSeatCounts
        : _validRoomSeatCounts.where((count) => count > current).toList();
    if (options.isEmpty) {
      _snack('No higher seat count is available.');
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            ListTile(
              title: Text(
                _isRoomOwner ? 'Room Seats' : 'Increase Room Seats',
                style: const TextStyle(
                  color: FeaturePalette.discover,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                _isRoomOwner
                    ? 'Owner can increase or decrease seats.'
                    : 'Admin can only see seat counts higher than $current.',
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final count in options)
                  ChoiceChip(
                    label: Text(count.toString()),
                    selected: count == current,
                    onSelected: count == current
                        ? null
                        : (_) => Navigator.pop(sheetContext, count),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (selected == null || selected == current) return;
    try {
      final updated = await widget.state.discovery.setRoomSeatCount(
        authToken: account.authToken,
        roomId: widget.room.id,
        seatCount: selected,
      );
      controller.setSeatCount(updated.seatCount);
      if (mounted) setState(() {});
      _snack('Room seats changed to ' + updated.seatCount.toString() + '.');
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _showSendingRanking() {
    final account = widget.state.auth.current;
    if (account == null) return;
    var period = 'day';

    String periodLabel(String value) {
      switch (value) {
        case 'week':
          return 'Weekly';
        case 'month':
          return 'Monthly';
        default:
          return 'Daily';
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final currentUserId = account.userId;
          final currentName = account.displayName;
          ImageProvider? currentAvatar;
          final avatarData = account.avatarDataUrl;
          if (avatarData != null && avatarData.startsWith('data:image/')) {
            try {
              currentAvatar =
                  stableImageProvider(avatarData);
            } catch (_) {
              currentAvatar = null;
            }
          }

          return FractionallySizedBox(
            heightFactor: 0.58,
            alignment: Alignment.bottomCenter,
            child: Container(
              key: const Key('reference-room-rank-panel'),
              decoration: const BoxDecoration(
                color: Color(0xFF211034),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          for (final entry in const <(String, String)>[
                            ('day', 'Daily'),
                            ('week', 'Weekly'),
                            ('month', 'Monthly'),
                          ])
                            Expanded(
                              child: InkWell(
                                key: Key(
                                  'room-rank-tab-' + entry.$1,
                                ),
                                onTap: () => setSheetState(
                                  () => period = entry.$1,
                                ),
                                child: Center(
                                  child: Text(
                                    entry.$2,
                                    style: TextStyle(
                                      color: period == entry.$1
                                          ? Colors.white
                                          : const Color(0xFF8B789D),
                                      fontSize: 13,
                                      fontWeight: period == entry.$1
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(
                      height: 1,
                      color: Color(0x332F1D45),
                    ),
                    Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: widget.state.discovery.roomGiftRanking(
                          authToken: account.authToken,
                          roomId: widget.room.id,
                          period: period,
                        ),
                        builder: (context, snapshot) {
                          final raw = snapshot.data?['ranking'];
                          final rows = raw is List
                              ? raw.whereType<Map>().toList()
                              : const <Map>[];
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              rows.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF9A57FF),
                              ),
                            );
                          }
                          if (rows.isEmpty) {
                            return Center(
                              child: Text(
                                'No contributors yet',
                                key: const Key(
                                  'room-rank-empty',
                                ),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(14, 8, 14, 12),
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              final rank =
                                  (row['rank'] as num? ?? index + 1).toInt();
                              final name =
                                  row['name']?.toString() ?? 'User';
                              final userId =
                                  row['user_id']?.toString() ?? '';
                              final sending =
                                  (row['sending'] as num? ?? 0).toInt();
                              return Container(
                                key: Key(
                                  'room-rank-row-' +
                                      userId +
                                      '-' +
                                      rank.toString(),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 3,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      child: Text(
                                        rank.toString(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: rank <= 3
                                              ? const Color(0xFFFFD35C)
                                              : const Color(0xFF8E7A9D),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          const Color(0xFF120A1B),
                                      child: Text(
                                        name.isEmpty
                                            ? '?'
                                            : name.characters.first
                                                .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            'ID: ' + userId,
                                            style: const TextStyle(
                                              color: Color(0xFF8E7A9D),
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.monetization_on_rounded,
                                      size: 15,
                                      color: Color(0xFFFFC83D),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      sending.toString(),
                                      style: const TextStyle(
                                        color: Color(0xFFFFC83D),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Container(
                      key: const Key('room-rank-self-row'),
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFF190C28),
                        border: Border(
                          top: BorderSide(
                            color: Color(0x333D2852),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 24,
                            child: Text(
                              '99',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF8E7A9D),
                                fontSize: 9,
                              ),
                            ),
                          ),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF120A1B),
                            backgroundImage: currentAvatar,
                            child: currentAvatar == null
                                ? Text(
                                    currentName.isEmpty
                                        ? '?'
                                        : currentName.characters.first
                                            .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'ID: ' + currentUserId,
                                  style: const TextStyle(
                                    color: Color(0xFF8E7A9D),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            periodLabel(period),
                            style: const TextStyle(
                              color: Color(0xFF8E7A9D),
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.monetization_on_rounded,
                            size: 16,
                            color: Color(0xFFFFC83D),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            '0',
                            style: TextStyle(
                              color: Color(0xFFFFC83D),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRoomIdentityCard() {
    final account = widget.state.auth.current;
    if (account == null) return;
    final room = _roomSnapshot;
    final ownerId = room.ownerId ?? room.id;
    final ownerName = room.ownerName ??
        (ownerId == account.userId ? account.displayName : 'Room Owner');
    final ownerAvatarValue = room.ownerAvatarDataUrl ??
        (ownerId == account.userId ? account.avatarDataUrl : null);

    ImageProvider? ownerAvatar;
    if (ownerAvatarValue != null &&
        ownerAvatarValue.startsWith('data:image/')) {
      try {
        ownerAvatar = stableImageProvider(ownerAvatarValue);
      } catch (_) {
        ownerAvatar = null;
      }
    }

    final liveMembers = widget.state.roomSession.liveMembers;
    final memberCount = liveMembers.isEmpty ? 1 : liveMembers.length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: const Color(0xFF241033),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        key: const Key('reference-room-info-sheet'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 29,
                  backgroundColor: const Color(0xFF171019),
                  backgroundImage: _roomPhotoProvider,
                  child: _roomPhotoProvider == null
                      ? const Icon(
                          Icons.meeting_room_rounded,
                          color: RoyalPalette.gold,
                        )
                      : null,
                ),
                title: Text(
                  _roomTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '🏅 ' + _roomSnapshot.displayId,
                    style: const TextStyle(
                      color: Color(0xFFFFD45A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                trailing: _isRoomOwner
                    ? IconButton(
                        key: const Key('reference-room-setup-button'),
                        tooltip: 'Room Setup',
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Future<void>.delayed(
                            const Duration(milliseconds: 220),
                            () {
                              if (mounted) _showReferenceRoomSetup();
                            },
                          );
                        },
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: RoyalPalette.cream,
                          size: 30,
                        ),
                      )
                    : null,
              ),
              const Divider(color: Color(0x334C3759)),
              ListTile(
                key: const Key('reference-room-members-row'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Members:' + memberCount.toString(),
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: const Color(0xFF171019),
                      backgroundImage: ownerAvatar,
                      child: ownerAvatar == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: RoyalPalette.cream,
                              size: 17,
                            )
                          : null,
                    ),
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: RoyalPalette.cream,
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future<void>.delayed(
                    const Duration(milliseconds: 220),
                    () {
                      if (mounted) _showReferenceRoomMembers();
                    },
                  );
                },
              ),
              const Divider(color: Color(0x334C3759)),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Notice',
                  style: TextStyle(
                    color: RoyalPalette.cream.withValues(alpha: 0.94),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _roomAnnouncement.isEmpty
                      ? 'No notice'
                      : _roomAnnouncement,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoyalPalette.muted,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF171019),
                  backgroundImage: ownerAvatar,
                  child: ownerAvatar == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: RoyalPalette.cream,
                        )
                      : null,
                ),
                title: Text(
                  ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Text(
                      '🏅 ' + ownerId,
                      style: const TextStyle(
                        color: Color(0xFFFFD45A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const Key('reference-room-copy-owner-id'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: ownerId),
                        );
                        _snack('Copied successfully.');
                      },
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: RoyalPalette.muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      room.ownerFlagEmoji ?? account.flagEmoji,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReferenceRoomMembers() {
    final room = _roomSnapshot;
    final ownerId = room.ownerId ?? room.id;
    final searchController = TextEditingController();
    Map<String, dynamic>? searchedUser;
    var searchBusy = false;
    String? searchError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF241033),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final members = widget.state.roomSession.liveMembers;
            final admins = members
                .where(
                  (member) =>
                      member.userId == ownerId || member.isAdmin,
                )
                .toList(growable: false);
            final regularMembers = members
                .where(
                  (member) =>
                      member.userId != ownerId && !member.isAdmin,
                )
                .toList(growable: false);

            ImageProvider? avatarFor(String? data) {
              if (data == null || !data.startsWith('data:image/')) {
                return null;
              }
              try {
                return stableImageProvider(data);
              } catch (_) {
                return null;
              }
            }

            Future<void> searchById() async {
              final query = searchController.text.trim();
              if (query.isEmpty) {
                setSheetState(() {
                  searchedUser = null;
                  searchError = 'Enter a user ID.';
                });
                return;
              }
              if (!RegExp(
                r'^(?:\d{4,8}|[A-Za-z][A-Za-z0-9_]{2,19})$',
              ).hasMatch(query)) {
                setSheetState(() {
                  searchedUser = null;
                  searchError =
                      'Enter a valid number ID or Owner-approved Name ID.';
                });
                return;
              }
              final account = widget.state.auth.current;
              if (account == null) {
                return;
              }

              setSheetState(() {
                searchBusy = true;
                searchedUser = null;
                searchError = null;
              });
              try {
                final result = await widget.state.backend.searchUserById(
                  account.authToken,
                  query,
                );
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  searchedUser = result;
                  searchBusy = false;
                  searchError =
                      result == null ? 'User ID not found.' : null;
                });
              } catch (error) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  searchedUser = null;
                  searchBusy = false;
                  searchError =
                      error.toString().replaceFirst('Bad state: ', '');
                });
              }
            }

            Widget memberTile(
              RoomPresenceMember member, {
              required bool admin,
            }) {
              final avatar = avatarFor(member.avatarDataUrl);
              final isOwnerMember = member.userId == ownerId;
              Widget? trailing;

              if (isOwnerMember) {
                trailing = const Text(
                  'Owner',
                  style: TextStyle(
                    color: Color(0xFFFFD45A),
                    fontWeight: FontWeight.w800,
                  ),
                );
              } else if (admin) {
                trailing = _isRoomOwner
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Admin',
                            style: TextStyle(
                              color: Color(0xFFFFD45A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            key: Key(
                              'room-member-remove-admin-' + member.userId,
                            ),
                            onPressed: () async {
                              await _toggleRoomAdmin(member, false);
                              if (sheetContext.mounted) {
                                setSheetState(() {});
                              }
                            },
                            child: const Text('Remove'),
                          ),
                        ],
                      )
                    : const Text(
                        'Admin',
                        style: TextStyle(
                          color: Color(0xFFFFD45A),
                          fontWeight: FontWeight.w800,
                        ),
                      );
              } else if (_isRoomOwner) {
                trailing = TextButton(
                  key: Key('room-member-add-admin-' + member.userId),
                  onPressed: () async {
                    await _toggleRoomAdmin(member, true);
                    if (sheetContext.mounted) {
                      setSheetState(() {});
                    }
                  },
                  child: const Text('Add Admin'),
                );
              }

              return ListTile(
                key: Key(
                  'room-member-row-' +
                      (admin ? 'admin-' : 'member-') +
                      member.userId,
                ),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF171019),
                  backgroundImage: avatar,
                  child: avatar == null
                      ? Text(
                          member.displayName.isEmpty
                              ? '?'
                              : member.displayName.characters.first
                                  .toUpperCase(),
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  member.displayName,
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'ID ' + member.userId,
                  style: const TextStyle(color: RoyalPalette.muted),
                ),
                trailing: trailing,
              );
            }

            Widget ownerFallbackTile() {
              return ListTile(
                key: const Key('room-owner-admin-row'),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF171019),
                  backgroundImage: _roomPhotoProvider,
                  child: _roomPhotoProvider == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: RoyalPalette.cream,
                        )
                      : null,
                ),
                title: Text(
                  room.ownerName ?? 'Room Owner',
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'ID ' + ownerId,
                  style: const TextStyle(color: RoyalPalette.muted),
                ),
                trailing: const Text(
                  'Owner',
                  style: TextStyle(
                    color: Color(0xFFFFD45A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }

            Widget searchResultCard() {
              if (searchBusy) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (searchedUser == null) {
                return searchError == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                        child: Text(
                          searchError!,
                          style: const TextStyle(
                            color: Color(0xFFFF8A80),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
              }

              final user = searchedUser!;
              final userId = user['user_id']?.toString() ?? '';
              final rawName = user['display_name']?.toString().trim() ?? '';
              final displayName = rawName.isEmpty ? userId : rawName;
              final avatar = avatarFor(user['avatar_data_url']?.toString());
              final isOwnerResult = userId == ownerId;
              final isAdminResult = members.any(
                (member) => member.userId == userId && member.isAdmin,
              );

              return Container(
                key: const Key('room-admin-search-result'),
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2038),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFB52DFF)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF171019),
                    backgroundImage: avatar,
                    child: avatar == null
                        ? Text(
                            displayName.isEmpty
                                ? '?'
                                : displayName.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: RoyalPalette.cream,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    displayName,
                    style: const TextStyle(
                      color: RoyalPalette.cream,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    'ID ' + userId,
                    style: const TextStyle(color: RoyalPalette.muted),
                  ),
                  trailing: isOwnerResult
                      ? const Text(
                          'Owner',
                          style: TextStyle(
                            color: Color(0xFFFFD45A),
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : isAdminResult
                          ? const Text(
                              'Admin',
                              style: TextStyle(
                                color: Color(0xFFFFD45A),
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : FilledButton(
                              key: const Key('room-admin-search-add-button'),
                              onPressed: () async {
                                try {
                                  await _setRoomAdminById(
                                    userId: userId,
                                    displayName: displayName,
                                    enabled: true,
                                  );
                                  if (sheetContext.mounted) {
                                    setSheetState(() {
                                      searchError = null;
                                    });
                                  }
                                } catch (_) {}
                              },
                              child: const Text('Add Admin'),
                            ),
                ),
              );
            }

            final ownerIsLive =
                admins.any((member) => member.userId == ownerId);

            return SafeArea(
              key: const Key('reference-room-members-panel'),
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.54,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Room Members',
                      style: TextStyle(
                        color: RoyalPalette.cream,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const TabBar(
                      indicatorColor: Color(0xFFB52DFF),
                      labelColor: RoyalPalette.cream,
                      unselectedLabelColor: RoyalPalette.muted,
                      tabs: [
                        Tab(text: 'Administrator'),
                        Tab(text: 'Members'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ListView(
                            children: [
                              if (!ownerIsLive) ownerFallbackTile(),
                              for (final member in admins)
                                memberTile(member, admin: true),
                            ],
                          ),
                          Column(
                            children: [
                              if (_isRoomOwner) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 12, 12, 4),
                                  child: TextField(
                                    key: const Key('room-admin-id-search-field'),
                                    controller: searchController,
                                    keyboardType: TextInputType.text,
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[A-Za-z0-9_]'),
                                      ),
                                      LengthLimitingTextInputFormatter(20),
                                    ],
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (_) => searchById(),
                                    style: const TextStyle(
                                      color: RoyalPalette.cream,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search number ID / Name ID',
                                      hintStyle: const TextStyle(
                                        color: RoyalPalette.muted,
                                      ),
                                      prefixIcon:
                                          const Icon(Icons.search_rounded),
                                      suffixIcon: IconButton(
                                        key: const Key('room-admin-id-search-button'),
                                        onPressed:
                                            searchBusy ? null : searchById,
                                        icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF2A2330),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                searchResultCard(),
                              ],
                              Expanded(
                                child: regularMembers.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No members',
                                          style: TextStyle(
                                            color: RoyalPalette.muted,
                                          ),
                                        ),
                                      )
                                    : ListView(
                                        children: [
                                          for (final member in regularMembers)
                                            memberTile(
                                              member,
                                              admin: false,
                                            ),
                                        ],
                                      ),
                              ),
                            ],
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
      ),
    ).whenComplete(searchController.dispose);
  }


  Future<void> _showReferenceRoomSetup() async {
    if (!_isRoomOwner) {
      _snack('Only the room owner can open Room Setup.');
      return;
    }
    final account = widget.state.auth.current;
    if (account == null) return;

    final nameController = TextEditingController(text: _roomTitle);
    final noticeController =
        TextEditingController(text: _roomAnnouncement);
    var pendingPhoto = _roomPhotoDataUrl;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (pageContext) => StatefulBuilder(
          builder: (pageContext, setPageState) {
            ImageProvider? pendingPhotoProvider;
            if (pendingPhoto != null &&
                pendingPhoto!.startsWith('data:image/')) {
              try {
                pendingPhotoProvider = stableImageProvider(pendingPhoto);
              } catch (_) {
                pendingPhotoProvider = null;
              }
            }

            return Scaffold(
              backgroundColor: const Color(0xFF1D062C),
              appBar: AppBar(
                backgroundColor: const Color(0xFF1D062C),
                title: const Text(
                  'Room Setup',
                  style: TextStyle(
                    color: RoyalPalette.cream,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  Center(
                    child: GestureDetector(
                      key: const Key('reference-room-setup-photo'),
                      onTap: () async {
                        final image = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 68,
                          maxWidth: 900,
                          maxHeight: 900,
                        );
                        if (image == null) return;
                        final bytes = await image.readAsBytes();
                        final mime =
                            image.mimeType?.startsWith('image/') == true
                                ? image.mimeType!
                                : 'image/jpeg';
                        final dataUrl = 'data:' +
                            mime +
                            ';base64,' +
                            base64Encode(bytes);
                        if (dataUrl.length > 450000) {
                          _snack(
                            'Room cover is too large. Choose a smaller image.',
                          );
                          return;
                        }
                        setPageState(() {
                          pendingPhoto = dataUrl;
                        });
                      },
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFF171019),
                        backgroundImage: pendingPhotoProvider,
                        child: pendingPhotoProvider == null
                            ? const Icon(
                                Icons.add_a_photo_rounded,
                                color: RoyalPalette.cream,
                                size: 28,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Room Name',
                    style: TextStyle(
                      color: RoyalPalette.cream,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('reference-room-name-field'),
                    controller: nameController,
                    maxLength: 24,
                    style: const TextStyle(color: RoyalPalette.cream),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF2A2330),
                      counterStyle: TextStyle(color: RoyalPalette.muted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Notice',
                    style: TextStyle(
                      color: RoyalPalette.cream,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('reference-room-notice-field'),
                    controller: noticeController,
                    maxLength: 24,
                    minLines: 5,
                    maxLines: 5,
                    style: const TextStyle(color: RoyalPalette.cream),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF2A2330),
                      counterStyle: TextStyle(color: RoyalPalette.muted),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ListTile(
                    key: const Key('reference-room-block-list'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: const Color(0xFF2A2330),
                    leading: const Icon(
                      Icons.block_rounded,
                      color: RoyalPalette.cream,
                    ),
                    title: const Text(
                      'Block List',
                      style: TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: RoyalPalette.muted,
                    ),
                    onTap: () => _showRoomBlacklist(pageContext),
                  ),
                  const SizedBox(height: 26),
                  FilledButton(
                    key: const Key('reference-room-setup-save'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B08FF),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 15),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final notice = noticeController.text.trim();
                      if (name.isEmpty) {
                        _snack('Room name is required.');
                        return;
                      }

                      try {
                        final photoChanged =
                            pendingPhoto != _roomPhotoDataUrl;
                        final updated =
                            await widget.state.discovery.updateRoomRemote(
                          authToken: account.authToken,
                          roomId: widget.room.id,
                          title: name,
                          announcement: notice,
                          photoDataUrl:
                              photoChanged ? pendingPhoto : null,
                        );
                        _roomTitleOverride = updated.title;
                        _roomPhotoOverride = updated.photoDataUrl;
                        _roomAnnouncementOverride =
                            updated.announcement;

                        if (mounted) setState(() {});
                        if (pageContext.mounted) {
                          Navigator.pop(pageContext);
                        }
                        _snack('Room setup saved.');
                      } catch (error) {
                        _snack(
                          error
                              .toString()
                              .replaceFirst('Bad state: ', ''),
                        );
                      }
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    nameController.dispose();
    noticeController.dispose();
  }

  Future<void> _handleUserSeatTap(int index) async {
    if (index < 0 || index >= controller.seats.length) return;
    final seat = controller.seats[index];

    if (seat.locked) {
      _snack('Seat ' + (index + 1).toString() + ' is locked.');
      return;
    }
    if (seat.occupied) {
      _snack('Seat ' + (index + 1).toString() + ' is occupied.');
      return;
    }
    if (controller.mySeat != null) {
      _snack('Leave your current seat first.');
      return;
    }

    try {
      if (_canModerateSeats || !controller.inviteMode) {
        // Owner/admin always take an empty seat directly. Request mode only
        // applies to normal users.
        await widget.state.roomSession.takeMySeat(index);
        _snack('Joined seat ' + (index + 1).toString() + '.');
        if (mounted) setState(() {});
        return;
      }

      await widget.state.roomSession.requestMySeat(index);
      _snack('Request sent for Seat ' + (index + 1).toString() + '.');
    } catch (error) {
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  // ignore: unused_element
  void _showSeatRequests() {
    if (!_canModerateSeats) {
      _snack('Only the room owner or room admin can review seat requests.');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final requests = widget.state.roomSession.seatRequests;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              child: requests.isEmpty
                  ? const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          'No pending seat requests.',
                          style: TextStyle(color: RoyalPalette.muted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: requests.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final request = requests[index];
                        var displayName = request.userId;
                        for (final member
                            in widget.state.roomSession.liveMembers) {
                          if (member.userId == request.userId) {
                            displayName = member.displayName;
                            break;
                          }
                        }
                        return ListTile(
                          leading: const ShiningIcon(
                            icon: Icons.event_seat_rounded,
                            color: FeaturePalette.family,
                            size: 18,
                            boxSize: 34,
                            glow: 0.30,
                          ),
                          title: Text(displayName),
                          subtitle: Text(
                            'Seat ' +
                                (request.seatIndex + 1).toString() +
                                ' • ID ' +
                                request.userId,
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Reject',
                                onPressed: () async {
                                  try {
                                    await widget.state.roomSession
                                        .resolveSeatRequest(
                                      request.userId,
                                      approved: false,
                                    );
                                    if (sheetContext.mounted) {
                                      setSheetState(() {});
                                    }
                                  } catch (error) {
                                    _snack(
                                      error
                                          .toString()
                                          .replaceFirst('Bad state: ', ''),
                                    );
                                  }
                                },
                                icon: const ShiningIcon(
                                  icon: Icons.close_rounded,
                                  color: FeaturePalette.safety,
                                  size: 16,
                                  boxSize: 30,
                                  glow: 0.28,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Approve',
                                onPressed: () async {
                                  try {
                                    await widget.state.roomSession
                                        .resolveSeatRequest(
                                      request.userId,
                                      approved: true,
                                    );
                                    if (sheetContext.mounted) {
                                      setSheetState(() {});
                                    }
                                    _snack(
                                      displayName +
                                          ' approved for Seat ' +
                                          (request.seatIndex + 1).toString() +
                                          '.',
                                    );
                                  } catch (error) {
                                    _snack(
                                      error
                                          .toString()
                                          .replaceFirst('Bad state: ', ''),
                                    );
                                  }
                                },
                                icon: const ShiningIcon(
                                  icon: Icons.check_rounded,
                                  color: FeaturePalette.family,
                                  size: 16,
                                  boxSize: 30,
                                  glow: 0.28,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }


  Future<void> _showSeatInvitePanel(int seatIndex) async {
    if (!_canModerateSeats) {
      _snack('Only the room owner or room admin can invite users to seats.');
      return;
    }
    if (seatIndex < 0 || seatIndex >= controller.seats.length) return;

    final seat = controller.seats[seatIndex];
    if (seat.occupied) {
      _snack('Seat ' + (seatIndex + 1).toString() + ' is already occupied.');
      return;
    }
    if (seat.locked) {
      _snack('Seat ' + (seatIndex + 1).toString() + ' is locked.');
      return;
    }

    final searchController = TextEditingController();
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final currentUserId = widget.state.auth.current?.userId;
          final normalizedQuery = query.trim().toLowerCase();
          final eligible = widget.state.roomSession.liveMembers
              .where(
                (member) =>
                    member.seatIndex == null &&
                    member.userId != currentUserId &&
                    (normalizedQuery.isEmpty ||
                        member.userId.toLowerCase().contains(normalizedQuery)),
              )
              .toList(growable: false)
            ..sort(
              (a, b) => a.displayName
                  .toLowerCase()
                  .compareTo(b.displayName.toLowerCase()),
            );

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.62,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                    child: Row(
                      children: [
                        const ShiningIcon(
                          icon: Icons.person_add_alt_1_rounded,
                          color: FeaturePalette.family,
                          size: 19,
                          boxSize: 36,
                          glow: 0.30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Invite to Seat No. ' +
                                (seatIndex + 1).toString(),
                            style: const TextStyle(
                              color: RoyalPalette.cream,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: TextField(
                      key: const Key('seat-invite-id-search'),
                      controller: searchController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search room user/admin by ID number',
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setSheetState(() => query = value);
                      },
                    ),
                  ),
                  Expanded(
                    child: eligible.isEmpty
                        ? const Center(
                            child: Text(
                              'No eligible user/admin is available in this room.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: RoyalPalette.muted),
                            ),
                          )
                        : ListView.separated(
                            key: const Key('seat-invite-eligible-list'),
                            padding:
                                const EdgeInsets.fromLTRB(10, 0, 10, 14),
                            itemCount: eligible.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final member = eligible[index];
                              return ListTile(
                                key: Key(
                                  'seat-invite-user-' + member.userId,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: RoyalPalette.panel2,
                                  child: Text(
                                    member.displayName.trim().isEmpty
                                        ? '?'
                                        : member.displayName.characters.first
                                            .toUpperCase(),
                                    style: const TextStyle(
                                      color: FeaturePalette.social,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  member.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('ID ' + member.userId),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: RoyalPalette.gold,
                                ),
                                onTap: () async {
                                  try {
                                    await widget.state.roomSession
                                        .inviteUserToSeat(
                                      member.userId,
                                      seatIndex: seatIndex,
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                    _snack(
                                      'Invite sent to ' +
                                          member.displayName +
                                          ' for Seat No. ' +
                                          (seatIndex + 1).toString() +
                                          '.',
                                    );
                                  } catch (error) {
                                    _snack(
                                      error
                                          .toString()
                                          .replaceFirst('Bad state: ', ''),
                                    );
                                  }
                                },
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

    searchController.dispose();
  }

  void _showSeatControls(int index) {
    if (index < 0 || index >= controller.seats.length) return;
    final seat = controller.seats[index];
    final occupant = _memberOnSeat(index);

    if (occupant != null &&
        _currentRoomRole == RoomRole.admin &&
        !_adminCanControlSeatOccupant(occupant)) {
      final ownerId =
          _roomSnapshot.ownerId ?? widget.room.ownerId ?? widget.room.id;
      _snack(
        occupant.userId == ownerId
            ? 'Admin cannot mute, lock or seat down the room owner.'
            : 'Admin cannot control another admin seat.',
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        key: const Key('reference-seat-control-panel'),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            ListTile(
              title: Text(
                'Seat ' + (index + 1).toString(),
                style: const TextStyle(
                  color: RoyalPalette.cream,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                occupant?.displayName ??
                    (seat.occupied ? (seat.userName ?? 'Occupied') : 'Empty'),
              ),
            ),
            ListTile(
              key: const Key('seat-control-lock'),
              leading: ShiningIcon(
                icon: seat.locked
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
                color: FeaturePalette.wallet,
                size: 18,
                boxSize: 34,
                glow: 0.30,
              ),
              title: Text(seat.locked ? 'Seat Unlock' : 'Seat Lock'),
              onTap: () async {
                Navigator.pop(context);
                final nextLocked = !seat.locked;
                try {
                  await widget.state.roomSession
                      .setSeatLock(index, nextLocked);
                  controller.setSeatLocked(index, nextLocked);
                  _snack(
                    nextLocked
                        ? 'Seat ' + (index + 1).toString() + ' locked.'
                        : 'Seat ' + (index + 1).toString() + ' unlocked.',
                  );
                } catch (error) {
                  _snack(error.toString().replaceFirst('Bad state: ', ''));
                }
              },
            ),
            ListTile(
              key: const Key('seat-control-mute'),
              leading: ShiningIcon(
                icon: seat.roomMuted
                    ? Icons.mic_rounded
                    : Icons.mic_off_rounded,
                color: seat.roomMuted
                    ? FeaturePalette.safety
                    : FeaturePalette.family,
                size: 18,
                boxSize: 34,
                glow: 0.30,
              ),
              title: Text(seat.roomMuted ? 'Seat Unmute' : 'Seat Mute'),
              onTap: () async {
                Navigator.pop(context);
                final nextMuted = !seat.roomMuted;
                try {
                  await widget.state.roomSession
                      .setSeatMute(index, nextMuted);
                  controller.setSeatRoomMuted(index, nextMuted);
                  if (controller.mySeat == index) {
                    await widget.state.roomSession.setMicFromController();
                  }
                  _snack(
                    nextMuted
                        ? 'Seat ' + (index + 1).toString() + ' muted.'
                        : 'Seat ' + (index + 1).toString() + ' unmuted.',
                  );
                } catch (error) {
                  _snack(error.toString().replaceFirst('Bad state: ', ''));
                }
              },
            ),
            if (!seat.occupied)
              ListTile(
                key: const Key('seat-control-invite'),
                leading: const ShiningIcon(
                  icon: Icons.person_add_alt_1_rounded,
                  color: FeaturePalette.social,
                  size: 18,
                  boxSize: 34,
                  glow: 0.30,
                ),
                title: const Text('Invite'),
                subtitle: Text(
                  'Invite an in-room user/admin to Seat No. ' +
                      (index + 1).toString() +
                      '.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  Future<void>.delayed(Duration.zero, () {
                    if (mounted) _showSeatInvitePanel(index);
                  });
                },
              ),
            if (!seat.occupied)
              ListTile(
                key: const Key('seat-control-take'),
                leading: const ShiningIcon(
                  icon: Icons.event_seat_rounded,
                  color: FeaturePalette.family,
                  size: 18,
                  boxSize: 34,
                  glow: 0.30,
                ),
                title: const Text('Take Seat'),
                subtitle: const Text(
                  'Owner/Admin can take this empty seat directly.',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    if (controller.mySeat != null &&
                        controller.mySeat != index) {
                      await _leaveSeatAndMute();
                    }
                    await widget.state.roomSession.takeMySeat(index);
                    _snack('Joined seat ' + (index + 1).toString() + '.');
                    if (mounted) setState(() {});
                  } catch (error) {
                    _snack(error.toString().replaceFirst('Bad state: ', ''));
                  }
                },
              ),
            if (seat.occupied &&
                occupant != null &&
                occupant.userId != widget.state.auth.current?.userId &&
                (_isRoomOwner || _adminCanControlSeatOccupant(occupant)))
              ListTile(
                key: const Key('seat-control-down'),
                leading: const ShiningIcon(
                  icon: Icons.airline_seat_recline_normal_rounded,
                  color: FeaturePalette.safety,
                  size: 18,
                  boxSize: 34,
                  glow: 0.30,
                ),
                title: const Text('Seat Down'),
                subtitle:
                    Text(occupant.displayName + ' ko audience me bheje'),
                onTap: () async {
                  Navigator.pop(context);
                  await _moveMemberSeatDown(occupant);
                },
              ),
            if (controller.mySeat == index)
              ListTile(
                leading: const ShiningIcon(
                  icon: Icons.logout_rounded,
                  color: FeaturePalette.safety,
                  size: 18,
                  boxSize: 34,
                  glow: 0.30,
                ),
                title: const Text('Leave this seat'),
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
    final rowSeatCount = range.$2 - range.$1;
    final seatWidth = (seatDiameter + (seatDiameter < 44 ? 8 : 16))
        .clamp(38.0, 78.0)
        .toDouble();
    return Row(
      key: Key('seat-row-' + row.toString()),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var offset = 0; offset < rowSeatCount; offset++)
          SizedBox(
            width: seatWidth,
            child: _buildSeat(
              index: range.$1 + offset,
              seatDiameter: seatDiameter,
            ),
          ),
      ],
    );
  }

  Widget _buildSeat({
    required int index,
    required double seatDiameter,
  }) {
    final seat = controller.seats[index];
    RoomPresenceMember? presenceMember;
    for (final member in widget.state.roomSession.liveMembers) {
      if (member.seatIndex == index) {
        presenceMember = member;
        break;
      }
    }
    if (presenceMember == null) {
      final mappedUserId = widget.state.roomControls.seatUsers[index];
      final currentUserId = widget.state.auth.current?.userId;
      for (final member in widget.state.roomSession.liveMembers) {
        final idMatch = mappedUserId != null && member.userId == mappedUserId;
        final nameMatch =
            seat.userName != null && member.displayName == seat.userName;
        final selfMatch =
            controller.mySeat == index && member.userId == currentUserId;
        if (idMatch || nameMatch || selfMatch) {
          presenceMember = member;
          break;
        }
      }
    }
    final isMySeat = controller.mySeat == index;
    final account = widget.state.auth.current;
    final occupied = seat.userName != null || presenceMember != null;
    final presenceName = presenceMember?.displayName.trim() ?? '';
    final selfName = isMySeat ? (account?.displayName.trim() ?? '') : '';
    final seatName = seat.userName?.trim() ?? '';
    final displayName = presenceName.isNotEmpty
        ? presenceName
        : selfName.isNotEmpty
            ? selfName
            : (seatName.isNotEmpty && seatName != 'You')
                ? seatName
                : presenceMember?.userId ??
                    (isMySeat ? account?.userId : null) ??
                    'Mic ${index + 1}';
    final emoteUntil = presenceMember?.seatEmoteUntil;
    final seatEmote = presenceMember?.seatEmote != null &&
            emoteUntil != null &&
            emoteUntil.isAfter(DateTime.now())
        ? presenceMember!.seatEmote
        : null;
    final avatarData = (presenceMember?.avatarDataUrl?.trim().isNotEmpty ?? false)
        ? presenceMember!.avatarDataUrl
        : isMySeat
            ? account?.avatarDataUrl
            : null;
    final avatar = _roomAvatarProvider(avatarData);
    final compact = seatDiameter < 44;
    // Widget tests and very short split-screen windows use a 600px-tall
    // viewport. Compact only the label stack there; normal phone portrait
    // keeps the full-size 6x7 seat presentation.
    final micro =
        MediaQuery.sizeOf(context).height < 700 || seatDiameter < 24;
    final moderationMuted =
        seat.roomMuted || (presenceMember?.moderationMuted ?? false);
    final selfMuted = isMySeat && controller.selfMuted;
    final selfMicOff =
        isMySeat && controller.micState != MicState.live;
    final mappedSeatUserId = widget.state.roomControls.seatUsers[index];
    final authoritativeSeatUserId =
        presenceMember?.seatIndex == index
            ? presenceMember!.userId
            : mappedSeatUserId ??
                (isMySeat ? account?.userId : null);
    final showSeatGiftEffect = authoritativeSeatUserId != null &&
        _seatGiftEffectReceiverIds.contains(authoritativeSeatUserId);
    final showLuckySeatEffect = authoritativeSeatUserId != null &&
        _luckyAnimationReceiverIds.contains(authoritativeSeatUserId);
    final isMicBlocked =
        moderationMuted ||
        selfMuted ||
        selfMicOff ||
        (presenceMember?.micMuted ?? false);
    final showMuteIndicator = moderationMuted || selfMuted;
    final speakingUserId =
        presenceMember?.userId ?? (isMySeat ? account?.userId : null);
    final labelWidth = (seatDiameter + (compact ? 8 : 16))
        .clamp(38.0, 78.0)
        .toDouble();

    return SizedBox(
      key: Key('seat-' + index.toString()),
      width: labelWidth,
      child: GestureDetector(
        onTap: () {
          if (isMySeat) {
            _showMySeatLeavePanel();
            return;
          }
          if (_canModerateSeats && !occupied) {
            _showSeatControls(index);
            return;
          }
          if (occupied) {
            RoomPresenceMember? member = presenceMember;
            if (member == null) {
              final mappedUserId = widget.state.roomControls.seatUsers[index];
              for (final item in widget.state.roomSession.liveMembers) {
                final idMatch =
                    mappedUserId != null && item.userId == mappedUserId;
                final nameMatch = item.displayName == seat.userName;
                if (idMatch || nameMatch) {
                  member = item;
                  break;
                }
              }
            }
            if (member != null &&
                member.userId != widget.state.auth.current?.userId) {
              _showUserProfile(member, seatIndexHint: index);
              return;
            }
          }
          if (_canModerateSeats) {
            _showSeatControls(index);
            return;
          }
          _handleUserSeatTap(index);
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
            SizedBox(
              width: seatDiameter,
              height: seatDiameter,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    key: presenceMember == null
                        ? null
                        : Key('room-seat-user-dp-' + presenceMember.userId),
                    behavior: HitTestBehavior.opaque,
                    onTap: isMySeat
                        ? _showMySeatLeavePanel
                        : presenceMember == null
                            ? null
                            : () => _showUserProfile(
                                  presenceMember!,
                                  seatIndexHint: index,
                                ),
                    child: seat.locked && !occupied
                        ? Center(
                            child: Icon(
                              Icons.lock_rounded,
                              color: const Color(0xFFFFD76A),
                              size: seatDiameter * 0.48,
                              shadows: const <Shadow>[
                                Shadow(
                                  color: Color(0x66FFD76A),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          )
                        : RepaintBoundary(
                            child: AnimatedAvatarFrame(
                              size: seatDiameter,
                              frameId: presenceMember?.equippedFrameId,
                              child: Container(
                              width: seatDiameter,
                              height: seatDiameter,
                              padding: EdgeInsets.all(
                                compact ? 2.4 : 3.2,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0x22000000),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  width: compact ? 1.1 : 1.5,
                                ),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x775D39FF),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0x221A0C33),
                                  image: avatar == null
                                      ? null
                                      : DecorationImage(
                                          image: avatar,
                                          fit: BoxFit.cover,
                                        ),
                                  border: Border.all(
                                    color: const Color(0x99D9C8FF),
                                    width: 1,
                                  ),
                                ),
                                child: avatar != null
                                    ? null
                                    : Center(
                                        child: occupied
                                            ? Text(
                                                displayName.characters.first,
                                                style: TextStyle(
                                                  color:
                                                      RoyalPalette.cream,
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  fontSize:
                                                      seatDiameter * 0.32,
                                                ),
                                              )
                                            : Icon(
                                                Icons.weekend_rounded,
                                                color: const Color(
                                                  0xFFF3EAFF,
                                                ),
                                                size:
                                                    seatDiameter * 0.44,
                                              ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ),
                  if (occupied && speakingUserId != null)
                    Positioned(
                      left: compact ? -15 : -19,
                      bottom: compact ? -5 : -4,
                      child: IgnorePointer(
                        child: ValueListenableBuilder<Map<String, double>>(
                          valueListenable:
                              widget.state.roomSession.speakingLevelsListenable,
                          builder: (context, levels, child) {
                            final level = levels[speakingUserId] ?? 0.0;
                            if (isMicBlocked || level <= 0) {
                              return const SizedBox.shrink();
                            }
                            return _LiveMicWaves(
                              level: level,
                              compact: compact,
                            );
                          },
                        ),
                      ),
                    ),
                  if (showMuteIndicator)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        key: Key(
                          'seat-muted-indicator-' + index.toString(),
                        ),
                        width: compact ? 14 : 18,
                        height: compact ? 14 : 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE73D4F),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mic_off_rounded,
                          size: compact ? 9 : 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (seatEmote != null && seatEmote.isNotEmpty)
                    IgnorePointer(
                      child: Text(
                        seatEmote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: seatDiameter * 0.82,
                          height: 1,
                        ),
                      ),
                    ),
                  if (showSeatGiftEffect &&
                      _seatGiftEffect != null)
                    _buildSeatGiftImpactEffect(
                      gift: _seatGiftEffect!,
                      seatDiameter: seatDiameter,
                      receiverId: authoritativeSeatUserId,
                    ),
                  if (showLuckySeatEffect &&
                      _luckySeatEffectGift != null)
                    IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey<String>(
                          'lucky-flight-$_luckyAnimationSequence',
                        ),
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1250),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          final disappear = value <= 0.86
                              ? 1.0
                              : ((1 - value) / 0.14)
                                  .clamp(0.0, 1.0)
                                  .toDouble();
                          final scale = 0.42 +
                              Curves.easeOutBack.transform(value) * 0.74;
                          final arc =
                              math.sin(math.pi * value) * seatDiameter * 0.55;
                          final perspective = Matrix4.identity()
                            ..setEntry(3, 2, 0.0018)
                            ..rotateY((1 - value) * 2.15)
                            ..rotateX((1 - value) * -0.48)
                            ..rotateZ((1 - value) * 0.72)
                            ..scaleByDouble(scale, scale, 1.0, 1.0);
                          final origin =
                              _giftFlightOriginOffset(context);
                          return Transform.translate(
                            offset: Offset(
                              origin.dx * (1 - value),
                              origin.dy * (1 - value) - arc,
                            ),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: perspective,
                              child: Opacity(
                                opacity: disappear,
                                child: Container(
                                  padding: EdgeInsets.all(
                                    math.max(1.0, seatDiameter * 0.03),
                                  ),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: Color(0xAAFFB84D),
                                        blurRadius: 13,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: Color(0x887F55FF),
                                        blurRadius: 18,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          );
                        },
                        child: _luckyArtwork(
                          _luckySeatEffectGift!,
                          size: seatDiameter * 0.86,
                        ),
                      ),
                    ),
                  if (showLuckySeatEffect &&
                      _luckySeatEffectGift != null)
                    _buildLuckyImpactEffect(
                      gift: _luckySeatEffectGift!,
                      seatDiameter: seatDiameter,
                    ),

                ],
              ),
            ),
            SizedBox(height: micro ? 0 : (compact ? 2 : 4)),
            SizedBox(
              key: Key('seat-user-name-' + index.toString()),
              height: micro ? 8 : (compact ? 11 : 14),
              width: labelWidth,
              child: Text(
                occupied ? displayName : 'No.' + (index + 1).toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RoyalPalette.cream,
                  fontSize: micro ? 6.5 : (compact ? 8.5 : 10.0),
                  height: 1.05,
                  fontWeight: occupied ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: micro ? 1 : 2),
            Container(
              key: Key('seat-heart-' + index.toString()),
              height: micro ? 7 : (compact ? 9 : 11),
              constraints: BoxConstraints(
                minWidth: micro ? 20 : (compact ? 28 : 34),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8D72B8).withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💎' +
                    _compactRoomSending(
                      presenceMember?.receivedGiftCoins ?? 0,
                    ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFE9DFFF),
                  fontSize: micro ? 4.5 : (compact ? 5.5 : 7),
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
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
        appBar: AppBar(title: Text(_roomTitle)),
        body: const Center(
          child: CircularProgressIndicator(
            color: FeaturePalette.social,
          ),
        ),
      );
    }

    final config = activeController.config;
    final seatSpec = SeatLayoutSpec.forCount(controller.seats.length);
    final screenSize = MediaQuery.sizeOf(context);
    final compactVertical = screenSize.height < 700;
    final widthSeatDiameter = seatSpec.seatDiameter(screenSize.width - 8);
    // Real phone portrait layouts keep the larger 6x7 seat treatment. Short
    // test/split-screen viewports compact vertically so the bottom controls
    // remain reachable instead of overflowing off-screen.
    final maxSeatAreaHeight =
        screenSize.height * (compactVertical ? 0.42 : 0.55);
    final rowLabelSpace = compactVertical
        ? 30.0
        : (widthSeatDiameter < 48 ? 28.0 : 38.0);
    final heightSeatDiameter =
        (maxSeatAreaHeight / seatSpec.rows) - rowLabelSpace;
    final seatDiameter = (widthSeatDiameter < heightSeatDiameter
            ? widthSeatDiameter
            : heightSeatDiameter)
        .clamp(compactVertical ? 12.0 : 30.0, 68.0)
        .toDouble();

    // The 42-seat (6 x 7) layout is the lowest seat boundary allowed.
    // Smaller seat layouts may finish above it, but never extend below it.
    final reference42SeatSpec = SeatLayoutSpec.forCount(42);
    final reference42WidthDiameter =
        reference42SeatSpec.seatDiameter(screenSize.width - 8);
    final reference42LabelSpace = compactVertical
        ? 30.0
        : (reference42WidthDiameter < 48 ? 28.0 : 38.0);
    final reference42HeightDiameter =
        (maxSeatAreaHeight / reference42SeatSpec.rows) -
            reference42LabelSpace;
    final reference42SeatDiameter =
        (reference42WidthDiameter < reference42HeightDiameter
                ? reference42WidthDiameter
                : reference42HeightDiameter)
            .clamp(compactVertical ? 12.0 : 30.0, 68.0)
            .toDouble();
    final reference42SeatAreaHeight = reference42SeatSpec
        .preferredHeight(reference42SeatDiameter)
        .clamp(120.0, maxSeatAreaHeight)
        .toDouble();
    final seatAreaHeight = seatSpec
        .preferredHeight(seatDiameter)
        .clamp(
          120.0,
          math.min(maxSeatAreaHeight, reference42SeatAreaHeight),
        )
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
          titleSpacing: 8,
          title: InkWell(
            key: const Key('room-title-button'),
            onTap: _showRoomIdentityCard,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              key: const Key('reference-room-title-pill'),
              constraints: const BoxConstraints(maxWidth: 238),
              padding: const EdgeInsets.fromLTRB(5, 4, 12, 4),
              decoration: BoxDecoration(
                color: const Color(0xFF21143A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF100A19),
                      backgroundImage: _roomPhotoProvider,
                      child: _roomPhotoProvider == null
                          ? const Icon(
                              Icons.meeting_room_rounded,
                              color: Color(0xFFD7C7FF),
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _roomTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '🏅 ' + _roomSnapshot.displayId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFD45A),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              key: const Key('room-share-button'),
              tooltip: 'Share room',
              onPressed: _shareRoom,
              icon: const ShiningIcon(
                icon: Icons.share_rounded,
                color: FeaturePalette.social,
                size: 20,
                boxSize: 36,
                glow: 0.34,
              ),
            ),
            IconButton(
              key: const Key('room-power-button'),
              tooltip: 'Room options',
              onPressed: _showRoomPowerMenu,
              icon: const ShiningIcon(
                icon: Icons.power_settings_new_rounded,
                color: FeaturePalette.safety,
                size: 20,
                boxSize: 36,
                glow: 0.34,
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (isEmotionRoomTheme(widget.state.roomControls.themeId))
              Positioned.fill(
                child: RoomEmotionBackdrop(
                  themeId: widget.state.roomControls.themeId,
                ),
              ),
            Positioned.fill(
              child: Container(
          decoration: BoxDecoration(
            color: isEmotionRoomTheme(widget.state.roomControls.themeId)
                ? Colors.transparent
                : _roomBackgroundColor,
            image: _roomThemeImage == null
                ? null
                : DecorationImage(
                    image: _roomThemeImage!,
                    fit: BoxFit.cover,
                  ),
          ),
          child: Column(
            children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
              child: Row(
                children: [
                  InkWell(
                    key: const Key('room-rank-hall-button'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: _showSendingRanking,
                    child: Container(
                      key: const Key('reference-room-rank-pill'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1D3B)
                            .withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFFFFC83D),
                            size: 18,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Ranking',
                            style: TextStyle(
                              color: Color(0xFFFFD45A),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _roomSendingSummaryFuture,
                    builder: (context, snapshot) {
                      final total =
                          (snapshot.data?['lifetime_total'] as num? ?? 0).toInt();
                      return Container(
                        key: const Key('room-lifetime-sending'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17100A)
                              .withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0x66FFD45A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.monetization_on_rounded,
                              color: Color(0xFFFFC83D),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _compactRoomSending(total),
                              style: const TextStyle(
                                color: Color(0xFFFFD45A),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  Builder(
                    builder: (context) {
                      final currentAccount = widget.state.auth.current;
                      final live = widget.state.roomSession.liveMembers;
                      final ordered = <Map<String, String?>>[];

                      if (currentAccount != null) {
                        RoomPresenceMember? currentMember;
                        for (final member in live) {
                          if (member.userId == currentAccount.userId) {
                            currentMember = member;
                            break;
                          }
                        }
                        ordered.add(<String, String?>{
                          'id': currentAccount.userId,
                          'name': currentMember?.displayName ??
                              currentAccount.displayName,
                          'avatar': currentMember?.avatarDataUrl ??
                              currentAccount.avatarDataUrl,
                        });
                      }
                      for (final member in live) {
                        if (member.userId == currentAccount?.userId) continue;
                        ordered.add(<String, String?>{
                          'id': member.userId,
                          'name': member.displayName,
                          'avatar': member.avatarDataUrl,
                        });
                      }

                      final currentAlreadyLive = currentAccount != null &&
                          live.any(
                            (member) => member.userId == currentAccount.userId,
                          );
                      final memberCount = live.length +
                          (currentAccount != null &&
                                  session.hasRoom &&
                                  !currentAlreadyLive
                              ? 1
                              : 0);
                      final visible = ordered.take(3).toList(growable: false);

                      ImageProvider? avatarFor(String? data) {
                        if (data == null ||
                            !data.startsWith('data:image/')) {
                          return null;
                        }
                        try {
                          return stableImageProvider(data);
                        } catch (_) {
                          return null;
                        }
                      }

                      return InkWell(
                        key: const Key('room-online-members-button'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: _showReferenceRoomMembers,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A1D3B)
                                .withValues(alpha: 0.86),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (visible.isNotEmpty)
                                SizedBox(
                                  key: const Key('room-top-member-avatars'),
                                  width: 27.0 +
                                      (visible.length - 1) * 17.0,
                                  height: 28,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      for (var i = 0; i < visible.length; i++)
                                        Positioned(
                                          left: i * 17.0,
                                          top: 1,
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            padding:
                                                const EdgeInsets.all(1.5),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color:
                                                  const Color(0xFFFFD45A),
                                            ),
                                            child: GestureDetector(
                                              key: Key(
                                                'room-live-user-dp-' +
                                                    (visible[i]['id'] ??
                                                        i.toString()),
                                              ),
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () {
                                                final memberId =
                                                    visible[i]['id'];
                                                if (memberId == null) {
                                                  return;
                                                }
                                                for (final member in live) {
                                                  if (member.userId ==
                                                      memberId) {
                                                    _showUserProfile(member);
                                                    break;
                                                  }
                                                }
                                              },
                                              child: CircleAvatar(
                                                key: Key(
                                                  'room-top-member-dp-' +
                                                      (visible[i]['id'] ??
                                                          i.toString()),
                                                ),
                                                radius: 11,
                                                backgroundColor:
                                                    const Color(0xFF171019),
                                                backgroundImage: avatarFor(
                                                  visible[i]['avatar'],
                                                ),
                                                child: avatarFor(
                                                          visible[i]['avatar'],
                                                        ) ==
                                                        null
                                                    ? Text(
                                                        ((visible[i]['name'] ??
                                                                        '?')
                                                                    .trim()
                                                                    .isEmpty
                                                                ? '?'
                                                                : (visible[i][
                                                                            'name'] ??
                                                                        '?')
                                                                    .trim()
                                                                    .characters
                                                                    .first)
                                                            .toUpperCase(),
                                                        style:
                                                            const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.group_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              const SizedBox(width: 5),
                              Text(
                                memberCount.toString(),
                                key: const Key('room-online-member-count'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              key: const Key('tinni-seat-grid'),
              height: seatAreaHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
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
              key: const Key('room-official-announcement'),
              margin: const EdgeInsets.fromLTRB(10, 2, 10, 6),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF203548).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0x335CC8FF),
                ),
              ),
              child: const Text(
                'Official announcement: Tinni Star advocates civilized chatting '
                'and making friends. Room names, covers, content and comments '
                'containing vulgarity, sexual solicitation, political or other '
                'prohibited content may be moderated. Beware of fraudulent '
                'recharge or payment requests, protect your account and property, '
                'and avoid losses. Rooms may be inspected 24 hours a day.',
                style: TextStyle(
                  color: Color(0xFFFFD54A),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const Key('room-message-list'),
                controller: _roomMessageScrollController,
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 4),
                itemCount: controller.messages.length,
                itemBuilder: (_, index) =>
                    _buildRoomComment(controller.messages[index]),
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
                      width: MediaQuery.sizeOf(context).width * 0.22,
                      child: TextField(
                        key: const Key('room-chat-field'),
                        controller: chat,
                        enabled:
                            !widget.state.roomSession.moderationChatBanned &&
                            _canTypeInRoom,
                        decoration: InputDecoration(
                          hintText:
                              widget.state.roomSession.moderationChatBanned
                                  ? 'Chat banned'
                                  : !_canTypeInRoom
                                      ? 'Owner/Admin only'
                                      : 'Chat',
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.fromLTRB(10, 10, 8, 10),
                        ),
                        onSubmitted: (_) async {
                          if (widget.state.roomSession.moderationChatBanned) {
                            _snack('Room owner/admin has chat banned this ID.');
                            return;
                          }
                          if (!_canTypeInRoom) {
                            _snack(
                              'Public Screen is off. Only room owner/admin can type.',
                            );
                            return;
                          }
                          final value = chat.text.trim();
                          if (value.isEmpty) return;
                          try {
                            await widget.state.roomSession.sendRoomComment(
                              value,
                            );
                            chat.clear();
                          } catch (error) {
                            _snack(
                              error
                                  .toString()
                                  .replaceFirst('Bad state: ', ''),
                            );
                          }
                        },
                      ),
                    ),
                    if (controller.mySeat != null)
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
                        icon: const ShiningIcon(
                          icon: Icons.emoji_emotions_rounded,
                          color: FeaturePalette.games,
                          size: 22,
                          boxSize: 38,
                          glow: 0.34,
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
                      icon: ShiningIcon(
                        icon: controller.micState == MicState.live
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        color: controller.mySeat == null ||
                                widget.state.roomSession.moderationMicMuted
                            ? RoyalPalette.muted
                            : controller.micState == MicState.live
                                ? FeaturePalette.family
                                : FeaturePalette.safety,
                        size: 22,
                        boxSize: 38,
                        glow: controller.mySeat == null ? 0.08 : 0.34,
                      ),
                    ),

                    IconButton(
                      key: const Key('room-gift-button'),
                      tooltip: 'Gifts',
                      iconSize: 31,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 46,
                        minHeight: 46,
                      ),
                      onPressed: config.giftsEnabled ? _showGiftSheet : null,
                      icon: _roomActionLogo(
                        label: 'Gift',
                        icon: Icons.card_giftcard_rounded,
                        size: 40,
                      ),
                    ),
                    IconButton(
                      key: const Key('room-message-inbox-button'),
                      tooltip: 'Messages',
                      iconSize: 28,
                      padding: const EdgeInsets.all(7),
                      constraints: const BoxConstraints(
                        minWidth: 46,
                        minHeight: 46,
                      ),
                      onPressed: _openRoomInbox,
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _roomActionLogo(
                            label: 'Message',
                            icon: Icons.mark_chat_unread_rounded,
                            size: 40,
                          ),
                          if (_roomUnreadMessageCount > 0)
                            Positioned(
                              right: -7,
                              top: -7,
                              child: Container(
                                key: const Key('room-message-unread-badge'),
                                constraints: const BoxConstraints(
                                  minWidth: 19,
                                  minHeight: 19,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                decoration: BoxDecoration(
                                  color: FeaturePalette.safety,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: RoyalPalette.nearBlack,
                                    width: 1.4,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66FF334D),
                                      blurRadius: 7,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _roomUnreadMessageCount > 99
                                      ? '99+'
                                      : _roomUnreadMessageCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                      icon: _roomActionLogo(
                        label: '4-Box',
                        icon: Icons.grid_view_rounded,
                        size: 42,
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
                        icon: const ShiningIcon(
                          icon: Icons.event_seat_rounded,
                          color: FeaturePalette.family,
                          size: 22,
                          boxSize: 38,
                          glow: 0.34,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
            ),
            _buildCountryAudienceLandings(),
            Positioned.fill(child: RocketLaunchOverlay(
              completed: _rocketCompleted,
              viewerId: widget.state.auth.current?.userId,
              loadReward: _loadPersonalRocketReward,
              lane: _cinematicLane,
              enabled: widget.state.roomControls.effectsEnabled && widget.state.roomControls.rocketDrawNoticeEnabled,
            )),
            Positioned.fill(child:GiftSceneOverlay(
              queue:_giftScenes,
              lane:_cinematicLane,
              onDelivered:_deliverGiftScene,
              enabled:widget.state.roomControls.effectsEnabled &&
                  widget.state.roomControls.giftEffectsEnabled,
            )),
            for (var ribbonIndex = 0; ribbonIndex < _ribbonQueue.length && ribbonIndex < 2; ribbonIndex++)
              _buildRibbonLane(_ribbonQueue[ribbonIndex], ribbonIndex),
            Positioned.fill(
              child: EffectOverlay(
                queue: widget.state.effects,
                enabled: widget.state.roomControls.effectsEnabled,
                shouldPlay: widget.state.roomControls.shouldPlayEffect,
              ),
            ),
            if (_activeEntrance != null)
              Positioned.fill(
                key: const Key('premium-entrance-layer'),
                child: PremiumEntranceOverlay(
                  entryId: _activeEntrance!.equippedEntryId!,
                  displayName: _activeEntrance!.displayName,
                  avatarDataUrl: _activeEntrance!.avatarDataUrl,
                  onFinished: _finishPremiumEntrance,
                ),
              ),
            Positioned.fill(child: LuckyGiftOverlay(
              queue: _luckyVisuals, lane: _cinematicLane,
              onStarted: _playLuckySeatVisual,
              enabled: widget.state.roomControls.effectsEnabled &&
                  widget.state.roomControls.luckyGiftEffectEnabled,
            )),
            if (_luckyComboTimer.active && _luckyComboGift != null &&
                !_fruitJackpotOpen &&
                !_fruitPartyOpen)
              _buildLuckyComboOverlay(),
            if (!_fruitJackpotOpen && !_fruitPartyOpen)
              Positioned(
                key: const Key('room-game-floating-position'),
                right: 8,
                bottom: 138,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Rocket',
                      child: InkResponse(
                        key: const Key('room-rocket-floating-button'),
                        radius: 24,
                        onTap: _showRocketPanel,
                        child: const _ReferenceRocketLogo(size: 42),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111214),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: const Color(0xFF5D6065),
                          width: 0.8,
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x44FF8A1F),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Semantics(
                      button: true,
                      label: 'Game Center',
                      child: InkResponse(
                        key: const Key('room-game-floating-button'),
                        radius: 26,
                        onTap: _showGamePanel,
                        child: const _ReferenceGameLogo(size: 54),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.state.roomSession.presence.hasConnectionProblem ||
                (!widget.state.roomSession.connected && !widget.state.roomSession.connecting &&
                    widget.state.roomSession.connectionError != null))
              Positioned(
                left: 20,
                right: 20,
                bottom: 94,
                child: _buildRoomConnectionStatus(),
              ),
            if (_fruitJackpotOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: MediaQuery.sizeOf(context).height * 0.50,
                child: FruitJackpotPanel(
                  state: widget.state,
                  onClose: () => setState(
                    () => _fruitJackpotOpen = false,
                  ),
                ),
              ),
            if (_fruitPartyOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: MediaQuery.sizeOf(context).height * 0.50,
                child: FruitPartyPanel(
                  state: widget.state,
                  onClose: () => setState(
                    () => _fruitPartyOpen = false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceGameLogo extends StatelessWidget {
  const _ReferenceGameLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('game-keyboard-logo'),
      width: size,
      height: size * 0.66,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF050505),
          borderRadius: BorderRadius.circular(size * 0.16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.88),
            width: 1.2,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x55FFFFFF),
              blurRadius: 8,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.13),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final whiteKeyWidth = constraints.maxWidth / 6;
              return Stack(
                children: <Widget>[
                  Row(
                    children: List<Widget>.generate(
                      6,
                      (index) => Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F3),
                            border: Border(
                              right: index == 5
                                  ? BorderSide.none
                                  : const BorderSide(
                                      color: Color(0xFF161616),
                                      width: 1,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final index in <int>[0, 1, 3, 4])
                    Positioned(
                      left: whiteKeyWidth * (index + 1) -
                          whiteKeyWidth * 0.19,
                      top: 0,
                      width: whiteKeyWidth * 0.38,
                      height: constraints.maxHeight * 0.60,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF080808),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReferenceRocketLogo extends StatelessWidget {
  const _ReferenceRocketLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('realistic-black-rocket-logo'),
      width: size,
      height: size,
      child: Transform.rotate(
        angle: 0.42,
        child: CustomPaint(
          painter: const _StealthRocketPainter(),
          size: Size.square(size),
        ),
      ),
    );
  }
}

class _StealthRocketPainter extends CustomPainter {
  const _StealthRocketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final flameGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0x99FF8A1F),
          const Color(0x33FF5A1F),
          Colors.transparent,
        ],
        stops: const <double>[0, 0.48, 1],
      ).createShader(
        Rect.fromCircle(
          center: Offset(w * 0.50, h * 0.89),
          radius: w * 0.34,
        ),
      );
    canvas.drawCircle(Offset(w * 0.50, h * 0.89), w * 0.34, flameGlow);

    final outerFlame = Path()
      ..moveTo(w * 0.40, h * 0.78)
      ..cubicTo(
        w * 0.31,
        h * 0.88,
        w * 0.40,
        h * 0.98,
        w * 0.50,
        h,
      )
      ..cubicTo(
        w * 0.60,
        h * 0.98,
        w * 0.69,
        h * 0.88,
        w * 0.60,
        h * 0.78,
      )
      ..close();
    canvas.drawPath(
      outerFlame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFFFF6C8),
            Color(0xFFFFC13B),
            Color(0xFFFF7A1A),
            Color(0xFFFF3B12),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.76, w, h * 0.24)),
    );

    final innerFlame = Path()
      ..moveTo(w * 0.45, h * 0.79)
      ..quadraticBezierTo(w * 0.50, h * 0.95, w * 0.55, h * 0.79)
      ..close();
    canvas.drawPath(
      innerFlame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.white, Color(0xFFFFF2A8), Color(0xFFFFA62B)],
        ).createShader(Rect.fromLTWH(0, h * 0.78, w, h * 0.18)),
    );

    final leftFin = Path()
      ..moveTo(w * 0.36, h * 0.58)
      ..lineTo(w * 0.12, h * 0.79)
      ..lineTo(w * 0.38, h * 0.73)
      ..close();
    final rightFin = Path()
      ..moveTo(w * 0.64, h * 0.58)
      ..lineTo(w * 0.88, h * 0.79)
      ..lineTo(w * 0.62, h * 0.73)
      ..close();

    final finPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF050505), Color(0xFF26282C), Color(0xFF080808)],
      ).createShader(Rect.fromLTWH(0, h * 0.55, w, h * 0.26));
    canvas.drawPath(leftFin, finPaint);
    canvas.drawPath(rightFin, finPaint);

    final redEdge = Paint()
      ..color = const Color(0xFF9E1C16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.15, h * 0.78),
      Offset(w * 0.37, h * 0.62),
      redEdge,
    );
    canvas.drawLine(
      Offset(w * 0.85, h * 0.78),
      Offset(w * 0.63, h * 0.62),
      redEdge,
    );

    final body = Path()
      ..moveTo(w * 0.50, h * 0.04)
      ..cubicTo(
        w * 0.33,
        h * 0.14,
        w * 0.30,
        h * 0.40,
        w * 0.34,
        h * 0.70,
      )
      ..quadraticBezierTo(w * 0.50, h * 0.77, w * 0.66, h * 0.70)
      ..cubicTo(
        w * 0.70,
        h * 0.40,
        w * 0.67,
        h * 0.14,
        w * 0.50,
        h * 0.04,
      )
      ..close();

    final bodyRect = Rect.fromLTWH(w * 0.30, h * 0.03, w * 0.40, h * 0.75);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF050505),
            Color(0xFF15171A),
            Color(0xFF34373C),
            Color(0xFF101113),
            Color(0xFF030303),
          ],
          stops: <double>[0, 0.24, 0.48, 0.72, 1],
        ).createShader(bodyRect),
    );

    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF777B82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025,
    );

    final highlight = Path()
      ..moveTo(w * 0.43, h * 0.12)
      ..cubicTo(
        w * 0.38,
        h * 0.28,
        w * 0.39,
        h * 0.50,
        w * 0.41,
        h * 0.63,
      );
    canvas.drawPath(
      highlight,
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );

    final accentY = h * 0.28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.34, accentY, w * 0.32, h * 0.06),
        Radius.circular(w * 0.025),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFF5C0907), Color(0xFFE33A24), Color(0xFF6C0A08)],
        ).createShader(Rect.fromLTWH(w * 0.34, accentY, w * 0.32, h * 0.06)),
    );

    final panelLine = Paint()
      ..color = const Color(0x665D6065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014;
    canvas.drawLine(
      Offset(w * 0.36, h * 0.47),
      Offset(w * 0.64, h * 0.47),
      panelLine,
    );
    canvas.drawLine(
      Offset(w * 0.37, h * 0.61),
      Offset(w * 0.63, h * 0.61),
      panelLine,
    );

    final windowCenter = Offset(w * 0.50, h * 0.42);
    canvas.drawCircle(
      windowCenter,
      w * 0.135,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0xFFCBD2D7), Color(0xFF606870), Color(0xFF17191C)],
        ).createShader(
          Rect.fromCircle(center: windowCenter, radius: w * 0.135),
        ),
    );
    canvas.drawCircle(
      windowCenter,
      w * 0.095,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.40),
          colors: <Color>[
            Color(0xFFD9FAFF),
            Color(0xFF39CFFF),
            Color(0xFF007AAE),
            Color(0xFF00263A),
          ],
          stops: <double>[0, 0.22, 0.60, 1],
        ).createShader(
          Rect.fromCircle(center: windowCenter, radius: w * 0.095),
        ),
    );
    canvas.drawCircle(
      Offset(windowCenter.dx - w * 0.026, windowCenter.dy - w * 0.032),
      w * 0.022,
      Paint()..color = const Color(0xBBFFFFFF),
    );

    final nozzleRect = Rect.fromLTWH(w * 0.38, h * 0.70, w * 0.24, h * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(nozzleRect, Radius.circular(w * 0.04)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF4A4D50),
            Color(0xFFD0D2D3),
            Color(0xFF666A6E),
            Color(0xFF1E2022),
          ],
        ).createShader(nozzleRect),
    );
    canvas.drawLine(
      Offset(w * 0.39, h * 0.755),
      Offset(w * 0.61, h * 0.755),
      Paint()
        ..color = const Color(0xFF181A1C)
        ..strokeWidth = w * 0.025,
    );
  }

  @override
  bool shouldRepaint(covariant _StealthRocketPainter oldDelegate) => false;
}

class _ReferenceGameTile extends StatelessWidget {
  const _ReferenceGameTile({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: enabled
                      ? const <Color>[
                          Color(0xFF6E38B9),
                          Color(0xFF2B123E),
                        ]
                      : const <Color>[
                          Color(0xFF3A3240),
                          Color(0xFF211C24),
                        ],
                ),
                border: Border.all(
                  color: enabled
                      ? const Color(0xFFC56CFF)
                      : const Color(0xFF5B505F),
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: enabled
                      ? const Color(0xFFFFD45A)
                      : RoyalPalette.muted,
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  enabled ? RoyalPalette.cream : RoyalPalette.muted,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomThemeChoice {
  const _RoomThemeChoice({
    required this.id,
    required this.name,
    this.color,
    this.asset,
    this.expiresAt,
    this.panelFree = false,
  });

  final String id;
  final String name;
  final Color? color;
  final String? asset;
  final DateTime? expiresAt;
  final bool panelFree;
}
class _RoomMemberProfilePage extends StatelessWidget {
  const _RoomMemberProfilePage({required this.member});

  final RoomPresenceMember member;

  ImageProvider? get _avatar {
    final value = member.avatarDataUrl;
    if (value == null || !value.startsWith('data:image/')) return null;
    try {
      return stableImageProvider(value);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatar;
    return Scaffold(
      backgroundColor: RoyalPalette.nearBlack,
      appBar: AppBar(
        title: Text(
          member.displayName,
          style: const TextStyle(
            color: FeaturePalette.social,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
        children: [
          Center(
            child: CircleAvatar(
              key: Key('full-profile-dp-' + member.userId),
              radius: 54,
              backgroundColor: RoyalPalette.panel2,
              backgroundImage: avatar,
              child: avatar == null
                  ? Text(
                      member.displayName.isEmpty
                          ? '?'
                          : member.displayName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: FeaturePalette.social,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            member.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ID ' + member.userId,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RoyalPalette.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
          RoyalPanel(
            accentColor: FeaturePalette.social,
            child: Column(
              children: [
                _ProfileDetailRow(
                  label: 'Country',
                  value: member.countryCode.isEmpty
                      ? member.flagEmoji
                      : member.flagEmoji + ' ' + member.countryCode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: RoyalPalette.muted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: RoyalPalette.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  Color get _color {
    final value = label.toLowerCase();
    if (value.contains('follow')) return FeaturePalette.social;
    if (value.contains('message')) return FeaturePalette.music;
    if (value.contains('gift')) return FeaturePalette.gift;
    if (value.contains('seat')) return FeaturePalette.family;
    if (value.contains('mute')) return FeaturePalette.safety;
    if (value.contains('kick')) return FeaturePalette.safety;
    return FeaturePalette.social;
  }

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
              ShiningIcon(
                icon: icon,
                color: _color,
                size: 20,
                boxSize: 40,
                glow: 0.34,
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


class _PremiumRoomToolLogo extends StatelessWidget {
  const _PremiumRoomToolLogo({required this.label, required this.fallbackIcon, required this.size});
  final String label;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PremiumRoomToolPainter(label),
        child: Semantics(label: label, child: const SizedBox.expand()),
      ),
    );
  }
}

class _PremiumRoomToolPainter extends CustomPainter {
  const _PremiumRoomToolPainter(this.label);
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final lower = label.toLowerCase();
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    final shell = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF3B2A08), Color(0xFF090909), Color(0xFF000000)],
        stops: [0, .62, 1],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r - 1, shell);
    canvas.drawCircle(center, r - 1.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = const Color(0xFFFFD45A));
    canvas.drawCircle(center, r - 4, Paint()..style = PaintingStyle.stroke..strokeWidth = .7..color = const Color(0x88FFF1A8));

    if (lower.contains('gift')) {
      final box = Rect.fromCenter(center: Offset(center.dx, center.dy + 4), width: r * 1.05, height: r * .72);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), Paint()..shader = const LinearGradient(colors:[Color(0xFFFF6FB1),Color(0xFF8A1749)]).createShader(box));
      canvas.drawRect(Rect.fromCenter(center: Offset(center.dx, center.dy + 4), width: 3, height: box.height), Paint()..color=const Color(0xFFFFD45A));
      canvas.drawLine(Offset(box.left, box.top + 5), Offset(box.right, box.top + 5), Paint()..color=const Color(0xFFFFD45A)..strokeWidth=2);
      final bow=Paint()..style=PaintingStyle.stroke..strokeWidth=2.2..color=const Color(0xFFFFD45A);
      canvas.drawOval(Rect.fromCenter(center: Offset(center.dx-5, box.top-3), width: 10, height: 7), bow);
      canvas.drawOval(Rect.fromCenter(center: Offset(center.dx+5, box.top-3), width: 10, height: 7), bow);
    } else if (lower.contains('music') || lower.contains('sound')) {
      final p=Paint()..color=const Color(0xFF5FE7FF)..strokeWidth=3.2..strokeCap=StrokeCap.round;
      canvas.drawLine(Offset(center.dx+4,center.dy-10),Offset(center.dx+4,center.dy+7),p);
      canvas.drawLine(Offset(center.dx+4,center.dy-10),Offset(center.dx+12,center.dy-7),p);
      canvas.drawCircle(Offset(center.dx-1,center.dy+9),5,p);
      canvas.drawCircle(Offset(center.dx+10,center.dy+6),5,p);
      canvas.drawLine(Offset(center.dx-1,center.dy-7),Offset(center.dx-1,center.dy+9),p);
      canvas.drawLine(Offset(center.dx-1,center.dy-7),Offset(center.dx+4,center.dy-10),p);
    } else if (lower.contains('lucky') || lower == 'lp') {
      final pouch=Path()..moveTo(center.dx-11,center.dy-4)..quadraticBezierTo(center.dx-14,center.dy+14,center.dx,center.dy+15)..quadraticBezierTo(center.dx+14,center.dy+14,center.dx+11,center.dy-4)..close();
      canvas.drawPath(pouch,Paint()..shader=const LinearGradient(colors:[Color(0xFFFF304F),Color(0xFF700817)]).createShader(Rect.fromCircle(center:center,radius:r)));
      canvas.drawLine(Offset(center.dx-9,center.dy-3),Offset(center.dx+9,center.dy-3),Paint()..color=const Color(0xFFFFD45A)..strokeWidth=2);
      _text(canvas,'LP',center,const Color(0xFFFFE27A),9);
    } else if (lower.contains('game')) {
      final pad=RRect.fromRectAndRadius(Rect.fromCenter(center:center,width:r*1.25,height:r*.78),const Radius.circular(7));
      canvas.drawRRect(pad,Paint()..shader=const LinearGradient(colors:[Color(0xFF555555),Color(0xFF090909)]).createShader(pad.outerRect));
      final p=Paint()..color=const Color(0xFFFFD45A)..strokeWidth=2;
      canvas.drawLine(Offset(center.dx-8,center.dy),Offset(center.dx-2,center.dy),p);
      canvas.drawLine(Offset(center.dx-5,center.dy-3),Offset(center.dx-5,center.dy+3),p);
      canvas.drawCircle(Offset(center.dx+6,center.dy-2),2.3,Paint()..color=const Color(0xFFFF4FA3));
      canvas.drawCircle(Offset(center.dx+11,center.dy+3),2.3,Paint()..color=const Color(0xFF44C8FF));
    } else if (lower.contains('moderation') || lower.contains('shield')) {
      final shield=Path()..moveTo(center.dx,center.dy-13)..lineTo(center.dx+11,center.dy-8)..lineTo(center.dx+9,center.dy+5)..quadraticBezierTo(center.dx,center.dy+15,center.dx-9,center.dy+5)..lineTo(center.dx-11,center.dy-8)..close();
      canvas.drawPath(shield,Paint()..shader=const LinearGradient(colors:[Color(0xFFFF6A6A),Color(0xFF7A1111)]).createShader(Rect.fromCircle(center:center,radius:r)));
      canvas.drawPath(shield,Paint()..style=PaintingStyle.stroke..strokeWidth=1.5..color=const Color(0xFFFFD45A));
    } else if (lower.contains('setting')) {
      canvas.drawCircle(center,10,Paint()..style=PaintingStyle.stroke..strokeWidth=5..color=const Color(0xFFFFD45A));
      canvas.drawCircle(center,3,Paint()..color=const Color(0xFF050505));
      for(int i=0;i<8;i++){final a=i*3.14159265/4;canvas.drawLine(Offset(center.dx+10*math.cos(a),center.dy+10*math.sin(a)),Offset(center.dx+15*math.cos(a),center.dy+15*math.sin(a)),Paint()..color=const Color(0xFFFFD45A)..strokeWidth=3..strokeCap=StrokeCap.round);}
    } else {
      _text(canvas, label.isEmpty ? '•' : label.substring(0,1).toUpperCase(), center, const Color(0xFFFFD45A), 15);
    }
    canvas.drawArc(Rect.fromCircle(center:center,radius:r-5),3.7,1.2,false,Paint()..style=PaintingStyle.stroke..strokeWidth=1.4..color=const Color(0x88FFFFFF));
  }

  void _text(Canvas canvas,String text,Offset center,Color color,double fontSize){
    final tp=TextPainter(text:TextSpan(text:text,style:TextStyle(color:color,fontSize:fontSize,fontWeight:FontWeight.w900)),textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,center-Offset(tp.width/2,tp.height/2));
  }
  @override bool shouldRepaint(covariant _PremiumRoomToolPainter oldDelegate)=>oldDelegate.label!=label;
}


class _LiveMicWaves extends StatefulWidget {
  const _LiveMicWaves({
    required this.level,
    required this.compact,
  });

  final double level;
  final bool compact;

  @override
  State<_LiveMicWaves> createState() => _LiveMicWavesState();
}

class _LiveMicWavesState extends State<_LiveMicWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact
        ? const Size(28, 20)
        : const Size(36, 24);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          size: size,
          painter: _LiveMicWavePainter(
            level: widget.level,
            phase: _controller.value,
            compact: widget.compact,
          ),
        ),
      ),
    );
  }
}

class _LiveMicWavePainter extends CustomPainter {
  const _LiveMicWavePainter({
    required this.level,
    required this.phase,
    required this.compact,
  });

  final double level;
  final double phase;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final normalized = level.clamp(0.0, 1.0).toDouble();
    final centerY = size.height * 0.50;
    final micX = compact ? 6.0 : 7.0;
    final liveColor = Color.lerp(
      const Color(0xFFFFD76A),
      const Color(0xFF56F2C2),
      (0.35 + normalized * 0.65).clamp(0.0, 1.0),
    )!;

    final glowPaint = Paint()
      ..color = liveColor.withValues(
        alpha: (0.10 + normalized * 0.18).clamp(0.0, 0.30),
      );
    canvas.drawCircle(
      Offset(micX + 1, centerY),
      compact ? 6.5 : 8.0,
      glowPaint,
    );

    final micPaint = Paint()
      ..color = liveColor
      ..style = PaintingStyle.fill;
    final body = Rect.fromCenter(
      center: Offset(micX, centerY - (compact ? 1.8 : 2.2)),
      width: compact ? 3.8 : 4.8,
      height: compact ? 7.2 : 9.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        body,
        Radius.circular(compact ? 2.0 : 2.5),
      ),
      micPaint,
    );

    final linePaint = Paint()
      ..color = liveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 1.15 : 1.45
      ..strokeCap = StrokeCap.round;
    final cradleRect = Rect.fromCenter(
      center: Offset(micX, centerY),
      width: compact ? 8.0 : 10.0,
      height: compact ? 9.0 : 11.0,
    );
    canvas.drawArc(cradleRect, 0, math.pi, false, linePaint);
    canvas.drawLine(
      Offset(micX, centerY + (compact ? 4.4 : 5.4)),
      Offset(micX, centerY + (compact ? 6.0 : 7.0)),
      linePaint,
    );
    canvas.drawLine(
      Offset(micX - (compact ? 2.4 : 3.0), centerY + (compact ? 6.0 : 7.0)),
      Offset(micX + (compact ? 2.4 : 3.0), centerY + (compact ? 6.0 : 7.0)),
      linePaint,
    );

    final waveCenter = Offset(micX + (compact ? 2.0 : 2.5), centerY - 1);
    for (var index = 0; index < 3; index++) {
      final radius =
          (compact ? 5.2 : 6.6) + index * (compact ? 3.0 : 3.9);
      final pulse = math
          .sin((phase * math.pi * 2) - (index * 0.82))
          .abs();
      final opacity =
          (0.28 + normalized * 0.50 + pulse * 0.18).clamp(0.20, 0.96);
      final wavePaint = Paint()
        ..color = liveColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (compact ? 1.05 : 1.35) + normalized * 0.55
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: waveCenter, radius: radius),
        -math.pi / 3,
        math.pi * 2 / 3,
        false,
        wavePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveMicWavePainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.phase != phase ||
        oldDelegate.compact != compact;
  }
}
