import 'package:flutter/material.dart';

import '../auth/app_auth_api.dart';
import '../ui/royal_theme.dart';

class ResetPasswordResult {
  const ResetPasswordResult({required this.email});

  final String email;
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.initialEmail = '',
  });

  final String initialEmail;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final AppAuthApi _api = AppAuthApi();
  late final TextEditingController _emailController;
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _busy = false;
  bool _emailOtpReady = false;
  String? _requestId;
  String? _setupToken;
  String? _setupError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _loadConfig();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await _api.loadConfig();
      if (!mounted) return;
      setState(() {
        _emailOtpReady = config.emailOtpConfigured;
        _setupError = _emailOtpReady
            ? null
            : 'Email OTP service is not configured yet.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _emailOtpReady = false;
        _setupError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _sendOtp() async {
    if (_busy || !_emailOtpReady) return;
    final email = _emailController.text.trim();

    if (!email.contains('@')) {
      _snack('Enter a valid email / Gmail ID.');
      return;
    }

    setState(() => _busy = true);
    try {
      final started = await _api.startEmailOtp(email);
      if (!mounted) return;
      setState(() {
        _requestId = started.requestId;
        _setupToken = null;
        _otpController.clear();
      });
      _snack('OTP sent to ' + started.email);
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_busy) return;
    final requestId = _requestId;
    if (requestId == null || requestId.isEmpty) return;

    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _snack('Enter the 6-digit OTP.');
      return;
    }

    setState(() => _busy = true);
    try {
      final verified = await _api.verifyEmailOtp(
        requestId: requestId,
        otp: otp,
      );

      if (verified.profileRequired) {
        throw StateError(
          'No Tinni account exists for this email. Create a new Email ID first.',
        );
      }

      if (!mounted) return;
      setState(() {
        _emailController.text = verified.email;
        _setupToken = verified.setupToken;
      });
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePassword() async {
    if (_busy) return;
    final setupToken = _setupToken;
    if (setupToken == null || setupToken.isEmpty) return;

    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      _snack('Tinni password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      _snack('Password and confirm password do not match.');
      return;
    }

    setState(() => _busy = true);
    try {
      await _api.completeEmailPassword(
        setupToken: setupToken,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        ResetPasswordResult(email: _emailController.text.trim()),
      );
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otpSent = _requestId != null && _setupToken == null;
    final verified = _setupToken != null;

    return Scaffold(
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        title: const Text('Reset password'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            RoyalPanel(
              gradient: FeaturePalette.glow(FeaturePalette.email),
              accentColor: FeaturePalette.email,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ShiningIcon(
                    icon: Icons.lock_reset_rounded,
                    color: FeaturePalette.email,
                    size: 36,
                    boxSize: 62,
                    glow: 0.44,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Reset Tinni Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RoyalPalette.cream,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    key: const Key('reset-password-email'),
                    controller: _emailController,
                    enabled: !_busy && !otpSent && !verified,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Enter Gmail / Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!otpSent && !verified) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('reset-password-send-otp'),
                        onPressed:
                            _busy || !_emailOtpReady ? null : _sendOtp,
                        style: FilledButton.styleFrom(
                          backgroundColor: FeaturePalette.email,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.mark_email_read_rounded),
                        label: const Text('Send OTP'),
                      ),
                    ),
                    if (_setupError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _setupError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ] else if (otpSent) ...[
                    TextField(
                      key: const Key('reset-password-otp'),
                      controller: _otpController,
                      enabled: !_busy,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Enter 6-digit OTP',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('reset-password-verify-otp'),
                        onPressed: _busy ? null : _verifyOtp,
                        child: const Text('Verify OTP'),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy || !_emailOtpReady ? null : _sendOtp,
                      child: const Text('Resend OTP'),
                    ),
                  ] else ...[
                    const Text(
                      'Gmail OTP verified',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: FeaturePalette.email,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('reset-password-new'),
                      controller: _passwordController,
                      enabled: !_busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'New Tinni Password',
                        helperText: 'Minimum 8 characters',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('reset-password-confirm'),
                      controller: _confirmController,
                      enabled: !_busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('reset-password-save'),
                        onPressed: _busy ? null : _savePassword,
                        child: Text(
                          _busy ? 'Saving…' : 'Save New Password',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
