import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import 'fruit_party_panel.dart';

class FruitPartyScreen extends StatelessWidget {
  const FruitPartyScreen({super.key, required this.state});

  final TinniState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B1A),
      appBar: AppBar(
        title: const Text('Fruit Party'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: FruitPartyPanel(state: state),
        ),
      ),
    );
  }
}
