import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../relationship/cp_features.dart';
import '../ui/royal_theme.dart';

class CpDisconnectScreen extends StatefulWidget {
  const CpDisconnectScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<CpDisconnectScreen> createState() => _CpDisconnectScreenState();
}

class _CpDisconnectScreenState extends State<CpDisconnectScreen> {
  void _request() {
    final account = widget.state.auth.current;
    if (account == null || widget.state.cp.relationship == null) return;
    widget.state.cpFeatures.requestDisconnect(account.userId);
    setState(() {});
  }

  void _cancel() {
    widget.state.cpFeatures.respondDisconnect(accept: false);
    setState(() {});
  }

  void _confirm() {
    widget.state.cpFeatures.respondDisconnect(accept: true);
    widget.state.cp.disconnect();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cp = widget.state.cp.relationship;
    final pending =
        widget.state.cpFeatures.disconnectState == DisconnectState.requested;

    return Scaffold(
      key: const Key('cp-disconnect-screen'),
      appBar: AppBar(
        title: const Text(
          'CP Disconnect',
          style: TextStyle(
            color: FeaturePalette.cp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: cp == null
            ? const Center(
                child: Text(
                  'No active CP relationship.',
                  style: TextStyle(color: RoyalPalette.muted),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RoyalPanel(
                    gradient: FeaturePalette.glow(FeaturePalette.cp),
                    accentColor: FeaturePalette.cp,
                    child: Column(
                      children: [
                        const ShiningIcon(
                          icon: Icons.heart_broken_rounded,
                          color: FeaturePalette.cp,
                          size: 32,
                          boxSize: 60,
                          glow: 0.38,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'CP Level ' + cp.level.toString(),
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Disconnecting removes the active CP relationship. This action requires confirmation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: RoyalPalette.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!pending)
                    FilledButton.icon(
                      onPressed: _request,
                      icon: const Icon(Icons.heart_broken_rounded),
                      label: const Text('Request Disconnect'),
                    )
                  else ...[
                    OutlinedButton(
                      onPressed: _cancel,
                      child: const Text('Cancel Request'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('cp-disconnect-confirm'),
                      onPressed: _confirm,
                      child: const Text('Confirm Disconnect'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
