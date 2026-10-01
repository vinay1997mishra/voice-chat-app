import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import 'fruit_party_panel.dart';

class FruitPartyScreen extends StatefulWidget {
  const FruitPartyScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<FruitPartyScreen> createState() => _FruitPartyScreenState();
}

class _FruitPartyScreenState extends State<FruitPartyScreen> {
  Future<void> _refresh() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    await widget.state.fruitPartyRemote.sync(account.authToken);
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
                child: FruitPartyPanel(
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
