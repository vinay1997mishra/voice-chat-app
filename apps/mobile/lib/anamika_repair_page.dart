import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Owner tools are excluded from normal builds. GitHub enforces authorization;
/// this flag only controls visibility and is never treated as authentication.
const anamikaOwnerTools = bool.fromEnvironment('ANAMIKA_OWNER_TOOLS');

class AnamikaRepairPage extends StatefulWidget {
  const AnamikaRepairPage({super.key});
  @override
  State<AnamikaRepairPage> createState() => _AnamikaRepairPageState();
}

class _AnamikaRepairPageState extends State<AnamikaRepairPage> {
  final request = TextEditingController();
  String? error;
  static const repo = 'https://github.com/vinay1997mishra/voice-chat-app';

  @override
  void dispose() {
    request.dispose();
    super.dispose();
  }

  Future<void> open(String path) async {
    try {
      if (!await launchUrl(
        Uri.parse('$repo/$path'),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Browser could not open.');
      }
    } catch (_) {
      if (mounted)
        setState(() => error = 'Link नहीं खुला। Internet और browser जाँचें।');
    }
  }

  Future<void> start() async {
    if (request.text.trim().isEmpty) {
      setState(() => error = 'पहले बताओ क्या ठीक करना है।');
      return;
    }
    await Clipboard.setData(ClipboardData(text: request.text.trim()));
    if (!mounted) return;
    setState(() => error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Request copied. GitHub में Run workflow खोलकर request paste करो।',
        ),
      ),
    );
    await open('actions/workflows/anamika-repair.yml');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Anamika · Code Doctor')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'अपना बदलाव बताओ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Online repair: Anamika अधिकतम 3 प्रयास करेगी। Checks पास होने पर बदलाव review के लिए मिलेंगे। Upgrade के लिए तुम्हारी अलग मंज़ूरी चाहिए।',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: request,
          minLines: 3,
          maxLines: 7,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Hindi या English में request',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: start,
          icon: const Icon(Icons.build_circle_outlined),
          label: const Text('Request copy करो और repair खोलो'),
        ),
        if (error != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(error!)),
        OutlinedButton(
          onPressed: () => open('pulls'),
          child: const Text('बदलाव और checks देखो'),
        ),
        OutlinedButton(
          onPressed: () => open('actions/workflows/self-upgrade.yml'),
          child: const Text('Reviewed upgrade की मंज़ूरी दो'),
        ),
        const SizedBox(height: 16),
        const Text(
          'GitHub में owner account से sign in ज़रूरी है। Coding model की setup पूरी न हो तो repair स्पष्ट error के साथ रुकेगी। APK install Android की confirmation के बाद होगा।',
        ),
      ],
    ),
  );
}
