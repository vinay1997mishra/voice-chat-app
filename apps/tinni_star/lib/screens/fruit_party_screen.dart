import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import 'fruit_party_panel.dart';

class FruitPartyScreen extends StatelessWidget {
  const FruitPartyScreen({super.key, required this.state});

  final TinniState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050817),
      body: SafeArea(
        child: FruitPartyPanel(
          state: state,
          onClose: () => Navigator.maybePop(context),
        ),
      ),
    );
  }
}
