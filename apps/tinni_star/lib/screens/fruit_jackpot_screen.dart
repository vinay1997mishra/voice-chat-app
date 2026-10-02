import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import 'fruit_jackpot_panel.dart';

class FruitJackpotScreen extends StatefulWidget {
  const FruitJackpotScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<FruitJackpotScreen> createState() => _FruitJackpotScreenState();
}

class _FruitJackpotScreenState extends State<FruitJackpotScreen> {
  Future<void> _refresh() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    await widget.state.fruitJackpotRemote.sync(account.authToken);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050817),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: FruitJackpotPanel(
                  state: widget.state,
                  onClose: () => Navigator.maybePop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
