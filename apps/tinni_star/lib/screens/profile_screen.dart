import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import 'feature_center_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = widget.state.profile.profile;
    final identity = widget.state.identity;
    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFF4F1C70), Color(0xFF1F1126)],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  child: Text(profile.nick.characters.first),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nick,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('ID ' + profile.userId + ' 🇮🇳'),
                      Text(
                        'VIP' +
                            identity.vip.level.toString() +
                            ' • Noble ' +
                            identity.noble.level.toString(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Coins',
                  value: widget.state.wallet.coins.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Diamonds',
                  value: widget.state.wallet.diamonds.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FeatureCenterScreen(state: widget.state),
              ),
            ).then((_) => setState(() {})),
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Open Feature Center'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              widget.state.profile.editNick('Tinni Star User');
              widget.state.profile.editSignature('Welcome to Tinni Star');
              setState(() {});
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Demo profile edit'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}
