import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../auth/auth_service.dart';
import '../app/tinni_app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nameController = TextEditingController(text: 'Tinni User');
  String country = 'IN';
  bool busy = false;

  static const countries = <String, String>{
    'IN': '🇮🇳 India',
    'US': '🇺🇸 United States',
    'VN': '🇻🇳 Vietnam',
    'SG': '🇸🇬 Singapore',
    'MY': '🇲🇾 Malaysia',
    'TW': '🇹🇼 Taiwan',
    'HK': '🇭🇰 Hong Kong',
  };

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> login(LoginProvider provider) async {
    final name = nameController.text.trim();
    if (name.isEmpty || busy) return;
    setState(() => busy = true);

    final account = widget.state.auth.loginDemo(
      displayName: name,
      countryCode: country,
      provider: provider,
    );
    await widget.state.authPersistence?.save(account);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TinniShell(state: widget.state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 56),
            Container(
              width: 94,
              height: 94,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFFB85CFF), Color(0xFF5A1A84)],
                ),
              ),
              child: const Icon(Icons.graphic_eq_rounded, size: 52),
            ),
            const SizedBox(height: 26),
            const Text(
              'Tinni Star',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Voice rooms, friends, gifts, KTV, games, CP and family.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: country,
              decoration: const InputDecoration(
                labelText: 'Country / region',
                border: OutlineInputBorder(),
              ),
              items: countries.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => country = value);
                    },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : () => login(LoginProvider.phone),
              icon: const Icon(Icons.phone_android_rounded),
              label: const Text('Continue with Phone'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : () => login(LoginProvider.google),
              icon: const Icon(Icons.g_mobiledata_rounded),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : () => login(LoginProvider.facebook),
              icon: const Icon(Icons.facebook_rounded),
              label: const Text('Continue with Facebook'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Provider buttons currently use the Tinni identity adapter. Production OAuth credentials can plug into the same AuthService contract.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
