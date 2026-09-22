import 'package:flutter/material.dart';

import '../screens/discover_screen.dart';
import '../screens/home_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/profile_screen.dart';
import 'tinni_state.dart';

class TinniStarApp extends StatelessWidget {
  const TinniStarApp({super.key, required this.state});

  final TinniState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tinni Star',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFB35CFF),
        scaffoldBackgroundColor: const Color(0xFF100615),
      ),
      home: TinniShell(state: state),
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
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_rounded),
            label: 'Messages',
          ),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}
