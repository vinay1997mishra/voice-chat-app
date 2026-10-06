import 'package:flutter/material.dart';

import '../i18n/tinni_localization.dart';
import '../screens/discover_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/room_screen.dart';
import '../ui/room_dp.dart';
import '../ui/royal_theme.dart';
import 'tinni_state.dart';

class TinniStarApp extends StatelessWidget {
  const TinniStarApp({super.key, required this.state});

  final TinniState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state.auth,
      builder: (context, _) => MaterialApp(
      key: ValueKey(state.auth.current?.authToken),
      debugShowCheckedModeBanner: false,
      title: const String.fromEnvironment('TINNI_APP_NAME', defaultValue: 'Tinni Star'),
      theme: buildRoyalTheme(),
      home: state.auth.isLoggedIn
          ? TinniShell(state: state)
          : LoginScreen(state: state),
      ),
    );
  }
}

class TinniShell extends StatefulWidget {
  const TinniShell({super.key, required this.state});

  final TinniState state;

  @override
  State<TinniShell> createState() => _TinniShellState();
}

class _TinniShellState extends State<TinniShell> {
  int index = 0;
  final _visited = <int>{0};

  @override
  void initState() {
    super.initState();
    widget.state.refreshAccountPreferences();
    widget.state.gameResults.addListener(_showGameResults);
    if (widget.state.gameResults.value.isNotEmpty) _showGameResults();
    widget.state.social.retainMessageEvents();
    final token = widget.state.auth.current?.authToken;
    if (token != null) widget.state.social.connectMessageEvents(token);
  }

  @override
  void dispose() {
    widget.state.gameResults.removeListener(_showGameResults);
    widget.state.social.releaseMessageEvents();
    super.dispose();
  }

  void _showGameResults() {
    final results = List<Map<String, dynamic>>.from(widget.state.gameResults.value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      for (final result in results) {
        final title = result['game_key'] == 'fruit_party' ? 'Fruit Party' : 'Fruit Jackpot';
        final won = (result['winning_coins'] as num?)?.toInt() ?? 0;
        final bet = (result['bet_coins'] as num?)?.toInt() ?? 0;
        final credited = result['wallet_type'] == 'main' ? 'main wallet' : 'game wallet';
        final message = won > 0
            ? '$title: Won $won coins • Bet $bet • Added to your $credited'
            : '$title: Lost • Bet $bet coins';
        messenger.showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        )).closed.then((_) {
          if (mounted) widget.state.social.acknowledgeGameResult(result);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(state: widget.state),
      DiscoverScreen(state: widget.state),
      MessagesScreen(state: widget.state),
      ProfileScreen(state: widget.state),
    ];

    return Scaffold(
      backgroundColor: RoyalPalette.black,
      body: AnimatedBuilder(
        animation: widget.state.roomSession,
        builder: (context, _) {
          final session = widget.state.roomSession;
          return Column(
            children: [
              Expanded(child: IndexedStack(index: index, children: [
                for (var page = 0; page < pages.length; page++)
                  _visited.contains(page) ? pages[page] : const SizedBox.shrink(),
              ])),
              if (session.hasRoom && session.minimized)
                _MiniRoomBar(
                  state: widget.state,
                  onResume: () {
                    session.resume();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomScreen(
                          state: widget.state,
                          room: session.room!,
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF17130D),
              RoyalPalette.nearBlack,
              RoyalPalette.black,
            ],
          ),
          border: Border(
            top: BorderSide(
              color: RoyalPalette.gold.withValues(alpha: .42),
              width: .8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: RoyalPalette.gold.withValues(alpha: .08),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ValueListenableBuilder<String>(
          valueListenable: widget.state.languagePreference,
          builder: (context, language, _) => NavigationBar(
            height: 70,
            backgroundColor: Colors.transparent,
            indicatorColor: RoyalPalette.gold.withValues(alpha: .12),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: index,
            onDestinationSelected: (value) {
              const labels = <String>['party', 'discover', 'message', 'mine'];
              widget.state.analytics.event('navigation_tab', <String, Object?>{
                'tab': labels[value],
              });
              if (index == value) return;
              setState(() { index = value; _visited.add(value); });
              widget.state.pageEntries.value = value;
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(
                  Icons.groups_rounded,
                  color: RoyalPalette.muted,
                ),
                selectedIcon: const ShiningIcon(
                  icon: Icons.groups_rounded,
                  color: RoyalPalette.gold,
                  size: 20,
                  boxSize: 36,
                  glow: 0.18,
                ),
                label: tinniText(language, 'party'),
              ),
              NavigationDestination(
                icon: const Icon(
                  Icons.explore_rounded,
                  color: RoyalPalette.muted,
                ),
                selectedIcon: const ShiningIcon(
                  icon: Icons.explore_rounded,
                  color: RoyalPalette.gold,
                  size: 20,
                  boxSize: 36,
                  glow: 0.18,
                ),
                label: tinniText(language, 'discover'),
              ),
              NavigationDestination(
                icon: const Icon(
                  Icons.mail_rounded,
                  color: RoyalPalette.muted,
                ),
                selectedIcon: const ShiningIcon(
                  icon: Icons.mail_rounded,
                  color: RoyalPalette.gold,
                  size: 20,
                  boxSize: 36,
                  glow: 0.18,
                ),
                label: tinniText(language, 'message'),
              ),
              NavigationDestination(
                icon: const Icon(
                  Icons.person_rounded,
                  color: RoyalPalette.muted,
                ),
                selectedIcon: const ShiningIcon(
                  icon: Icons.person_rounded,
                  color: RoyalPalette.gold,
                  size: 20,
                  boxSize: 36,
                  glow: 0.18,
                ),
                label: tinniText(language, 'mine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniRoomBar extends StatelessWidget {
  const _MiniRoomBar({required this.state, required this.onResume});
  final TinniState state;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final session = state.roomSession;
    final room = session.room;
    if (room == null) return const SizedBox.shrink();

    var displayRoom = room;
    for (final candidate in state.discovery.rooms) {
      if (candidate.id == room.id) {
        displayRoom = candidate;
        break;
      }
    }

    final roomName = displayRoom.title.trim().isNotEmpty
        ? displayRoom.title.trim()
        : (displayRoom.ownerName?.trim().isNotEmpty == true
            ? displayRoom.ownerName!.trim()
            : 'Voice room');

    return Material(
      color: RoyalPalette.nearBlack,
      child: InkWell(
        key: const Key('mini-room-bar'),
        onTap: onResume,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: RoyalPalette.deepGold)),
          ),
          child: Row(
            children: [
              RoomDp(
                key: const Key('mini-room-dp'),
                room: displayRoom,
                size: 42,
                radius: 21,
                fit: BoxFit.cover,
                fallbackSize: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      session.connected
                          ? 'Voice room active • Tap to return'
                          : session.connectionError ?? 'Connecting…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: RoyalPalette.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close voice room',
                onPressed: () => session.close(),
                icon: const ShiningIcon(
                  icon: Icons.close_rounded,
                  color: FeaturePalette.safety,
                  size: 18,
                  boxSize: 34,
                  glow: 0.30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
