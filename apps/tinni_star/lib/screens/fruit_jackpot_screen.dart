import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import 'fruit_jackpot_panel.dart';

class FruitJackpotScreen extends StatelessWidget {
  const FruitJackpotScreen({super.key, required this.state});

  final TinniState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050817),
      body: SafeArea(
        child: FruitJackpotPanel(
          state: state,
          onClose: () => Navigator.maybePop(context),
        ),
      ),
    );
  }
}
