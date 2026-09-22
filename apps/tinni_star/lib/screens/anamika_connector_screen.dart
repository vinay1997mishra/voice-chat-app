import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/tinni_state.dart';

class AnamikaConnectorScreen extends StatefulWidget {
  const AnamikaConnectorScreen({
    super.key,
    required this.state,
  });

  final TinniState state;

  @override
  State<AnamikaConnectorScreen> createState() =>
      _AnamikaConnectorScreenState();
}

class _AnamikaConnectorScreenState extends State<AnamikaConnectorScreen> {
  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _snack(label + ' copied.');
  }

  String _diagnosticsJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(widget.state.connector.diagnosticSnapshot());
  }

  String? _diagnosticLink() {
    final token = widget.state.connectorBridge?.pairingToken;
    if (token == null || token.isEmpty) return null;
    return Uri(
      scheme: 'tinnistar',
      host: 'anamika',
      queryParameters: {
        'token': token,
        'command': '{"type":"diagnostics"}',
      },
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = widget.state.runtime;
    final token = widget.state.connectorBridge?.pairingToken;
    final history = widget.state.connector.commandHistory;
    final activePack = runtime.activePack;
    final previousPack = runtime.previousPack;

    return Scaffold(
      appBar: AppBar(title: const Text('Anamika Connector')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.link_rounded),
                      SizedBox(width: 8),
                      Text(
                        'Local pairing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tinni Star accepts Anamika commands only when the per-install pairing token and Function Pack signature are valid.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    token ?? 'Connector is not ready yet.',
                    key: const Key('anamika-pairing-token'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: token == null
                            ? null
                            : () => _copy(token, 'Pairing token'),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy token'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _diagnosticLink() == null
                            ? null
                            : () => _copy(
                                  _diagnosticLink()!,
                                  'Diagnostic link',
                                ),
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Copy diagnostic link'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.extension_rounded),
              title: Text(
                activePack == null
                    ? 'Base Function Pack'
                    : activePack.id + ' v' + activePack.version.toString(),
              ),
              subtitle: Text(
                previousPack == null
                    ? 'No previous pack retained'
                    : 'Previous: ' +
                        previousPack.id +
                        ' v' +
                        previousPack.version.toString(),
              ),
              trailing: Chip(
                label: Text('Schema ' + runtime.appSchema.toString()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Diagnostics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1022),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(
              _diagnosticsJson(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _copy(_diagnosticsJson(), 'Diagnostics'),
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Copy diagnostics'),
          ),
          const SizedBox(height: 18),
          const Text(
            'Command history',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No connector commands received yet.'),
              ),
            ),
          ...history.take(20).map(
                (item) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.terminal_rounded),
                    title: Text(item['type']?.toString() ?? 'command'),
                    subtitle: Text(item.toString()),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
