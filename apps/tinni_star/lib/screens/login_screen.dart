import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../auth/auth_service.dart';
import '../app/tinni_app.dart';
import '../ui/royal_theme.dart';

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
      backgroundColor: RoyalPalette.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Center(
              child: Container(
                width: 104,
                height: 104,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFFFFE99A),
                      RoyalPalette.gold,
                      RoyalPalette.deepGold,
                      Color(0xFF1A1204),
                    ],
                  ),
                  border: Border.all(color: RoyalPalette.gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: RoyalPalette.gold.withValues(alpha: 0.28),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  size: 54,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 26),
            const Center(
              child: Text(
                'Tinni Star',
                style: TextStyle(
                  color: RoyalPalette.gold,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'ROYAL VOICE COMMUNITY',
                style: TextStyle(
                  color: RoyalPalette.muted,
                  fontSize: 12,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Voice rooms, friends, gifts, KTV, games, CP and family.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RoyalPalette.cream),
              ),
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
            const RoyalPanel(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: RoyalPalette.gold,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Secure Tinni identity session. Production OAuth providers can plug into the same account system.',
                      style: TextStyle(
                        fontSize: 11,
                        color: RoyalPalette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
