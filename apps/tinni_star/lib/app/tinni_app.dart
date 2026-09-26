import 'package:flutter/material.dart';

import '../screens/discover_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/room_screen.dart';
import '../ui/royal_theme.dart';
import 'tinni_state.dart';

class TinniStarApp extends StatelessWidget {
  const TinniStarApp({super.key, required this.state});

  final TinniState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tinni Star',
      theme: buildRoyalTheme(),
      home: state.auth.isLoggedIn
          ? TinniShell(state: state)
          : LoginScreen(state: state),
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

  @override
  Widget build(BuildContext context) {
    final pages = [
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
              Expanded(child: IndexedStack(index: index, children: pages)),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_rounded, color: FeaturePalette.family),
            selectedIcon: ShiningIcon(
              icon: Icons.groups_rounded,
              color: FeaturePalette.family,
              size: 20,
              boxSize: 36,
              glow: 0.34,
            ),
            label: 'Party',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_rounded, color: FeaturePalette.discover),
            selectedIcon: ShiningIcon(
              icon: Icons.explore_rounded,
              color: FeaturePalette.discover,
              size: 20,
              boxSize: 36,
              glow: 0.34,
            ),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_rounded, color: FeaturePalette.message),
            selectedIcon: ShiningIcon(
              icon: Icons.mail_rounded,
              color: FeaturePalette.message,
              size: 20,
              boxSize: 36,
              glow: 0.34,
            ),
            label: 'Message',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded, color: FeaturePalette.social),
            selectedIcon: ShiningIcon(
              icon: Icons.person_rounded,
              color: FeaturePalette.social,
              size: 20,
              boxSize: 36,
              glow: 0.34,
            ),
            label: 'Mine',
          ),
        ],
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
              const ShiningIcon(
                icon: Icons.graphic_eq_rounded,
                color: FeaturePalette.family,
                size: 21,
                boxSize: 40,
                glow: 0.36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room.title,
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
