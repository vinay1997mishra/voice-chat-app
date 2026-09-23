import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void send() {
    if (widget.state.social.sendDirectMessage(
      from: '10000000',
      to: '20000000',
      text: controller.text,
    )) {
      controller.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.state.social.directMessages;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message', style: TextStyle(color: RoyalPalette.gold, fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: RoyalPanel(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: RoyalPalette.deepGold,
                    child: Text('A', style: TextStyle(color: Colors.black)),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Aisha', style: TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w900)),
                        Text('Friend • Online', style: TextStyle(color: RoyalPalette.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.circle, color: Colors.green, size: 10),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final message = messages[index];
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: RoyalPalette.panel2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RoyalPalette.deepGold),
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: RoyalPalette.nearBlack,
                border: Border(top: BorderSide(color: RoyalPalette.deepGold)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(hintText: 'Private message…'),
                    ),
                  ),
                  IconButton(
                    onPressed: send,
                    icon: const Icon(Icons.send_rounded, color: RoyalPalette.gold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
