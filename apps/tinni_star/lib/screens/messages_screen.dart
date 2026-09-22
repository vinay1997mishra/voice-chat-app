import 'package:flutter/material.dart';

import '../app/tinni_state.dart';

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
      appBar: AppBar(title: const Text('Messages')),
      body: Column(
        children: [
          const ListTile(
            leading: CircleAvatar(child: Text('A')),
            title: Text('Aisha'),
            subtitle: Text('Friend • Demo realtime DM'),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final message = messages[index];
                return Align(
                  alignment: Alignment.centerRight,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(message.text),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: 'Private message…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: send,
                    icon: const Icon(Icons.send_rounded),
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
