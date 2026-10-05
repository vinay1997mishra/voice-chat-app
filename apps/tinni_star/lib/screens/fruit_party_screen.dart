import 'package:flutter/material.dart';
import '../app/tinni_state.dart';
import 'casino_fruit_panel.dart';
import 'fruit_party_panel.dart';

class FruitPartyScreen extends StatelessWidget {
  const FruitPartyScreen({super.key, required this.state});
  final TinniState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF100C1C),
    body: SafeArea(
      child: CasinoGameDock(
        child: FruitPartyPanel(
          state: state, onClose: () => Navigator.maybePop(context),
        ),
      ),
    ),
  );
}
