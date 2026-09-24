import 'dart:convert';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/tinni_app.dart';
import '../app/tinni_state.dart';
import '../auth/app_auth_api.dart';
import '../auth/auth_service.dart';
import '../ui/royal_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AppAuthApi _api = AppAuthApi();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController signatureController = TextEditingController();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController emailPasswordController = TextEditingController();
  final TextEditingController emailOtpController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool busy = false;
  bool googleReady = false;
  bool facebookReady = false;
  bool emailReady = false;
  bool waitingFacebook = false;
  bool emailMode = false;

  String? googleSetupError;
  String? facebookSetupError;
  String? emailSetupError;

  String? pendingProvider;
  String? pendingGoogleIdToken;
  String? pendingFacebookRequestId;
  String? pendingAccountLabel;

  String? emailOtpRequestId;
  String? emailSetupToken;
  bool emailProfileRequired = false;
  String? pendingEmailPassword;

  int _facebookAttempt = 0;

  Country? selectedCountry;
  String? selectedGender;
  String? avatarDataUrl;

  @override
  void initState() {
    super.initState();
    signatureController.addListener(_refresh);
    _prepareAuth();
  }

  @override
  void dispose() {
    _facebookAttempt += 1;
    signatureController.removeListener(_refresh);
    nameController.dispose();
    ageController.dispose();
    signatureController.dispose();
    emailController.dispose();
    emailPasswordController.dispose();
    emailOtpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    _api.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int get signatureWords {
    final value = signatureController.text.trim();
    if (value.isEmpty) return 0;
    return value.split(RegExp(r'\s+')).length;
  }

  Future<void> _prepareAuth() async {
    try {
      final config = await _api.loadConfig();

      if (config.googleServerClientId != null) {
        await GoogleSignIn.instance.initialize(
          serverClientId: config.googleServerClientId,
        );
      }

      if (!mounted) return;
      setState(() {
        googleReady = config.googleServerClientId != null;
        facebookReady = config.facebookConfigured;
        emailReady = config.emailOtpConfigured;
        googleSetupError = googleReady
            ? null
            : 'Google login setup is not configured yet.';
        facebookSetupError = facebookReady
            ? null
            : 'Facebook login setup is not configured yet.';
        emailSetupError = emailReady
            ? null
            : 'Email OTP service is not configured yet.';
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '');
      setState(() {
        googleReady = false;
        facebookReady = false;
        emailReady = false;
        googleSetupError = message;
        facebookSetupError = message;
        emailSetupError = message;
      });
    }
  }

  Future<void> _googleLogin() async {
    if (busy || waitingFacebook || !googleReady) return;
    setState(() => busy = true);

    try {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw StateError('Google sign-in is not supported on this device.');
      }

      final googleAccount = await GoogleSignIn.instance.authenticate();
      final token = googleAccount.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw StateError('Google did not return a valid ID token.');
      }

      final result = await _api.googleLogin(idToken: token);
      if (!mounted) return;

      if (!result.profileRequired) {
        await _finishLogin(result);
        return;
      }

      pendingProvider = 'google';
      pendingGoogleIdToken = token;
      pendingFacebookRequestId = null;
      _applyDraft(
        result.draft,
        fallbackName: googleAccount.displayName ?? '',
        fallbackLabel: googleAccount.email,
      );
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _facebookLogin() async {
    if (busy || waitingFacebook || !facebookReady) return;

    setState(() => busy = true);
    try {
      final start = await _api.startFacebookLogin();
      final opened = await launchUrl(
        start.authUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw StateError('Unable to open Facebook login.');
      }

      if (!mounted) return;
      final attempt = ++_facebookAttempt;
      setState(() {
        busy = false;
        waitingFacebook = true;
      });
      await _pollFacebook(start.requestId, attempt);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        busy = false;
        waitingFacebook = false;
      });
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _pollFacebook(String requestId, int attempt) async {
    try {
      for (var index = 0; index < 90; index += 1) {
        if (!mounted || attempt != _facebookAttempt) return;

        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted || attempt != _facebookAttempt) return;

        final poll = await _api.pollFacebookLogin(requestId);
        if (poll.pending) continue;

        final result = poll.login;
        if (result == null) {
          throw StateError('Facebook login did not return an account.');
        }

        if (!result.profileRequired) {
          setState(() => waitingFacebook = false);
          await _finishLogin(result);
          return;
        }

        pendingProvider = 'facebook';
        pendingGoogleIdToken = null;
        pendingFacebookRequestId = poll.requestId ?? requestId;
        _applyDraft(
          result.draft,
          fallbackName: 'Facebook User',
          fallbackLabel: 'Facebook account',
        );

        if (!mounted) return;
        setState(() => waitingFacebook = false);
        return;
      }

      throw StateError('Facebook login timed out. Please try again.');
    } catch (error) {
      if (!mounted || attempt != _facebookAttempt) return;
      setState(() => waitingFacebook = false);
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _cancelFacebookWait() {
    _facebookAttempt += 1;
    setState(() => waitingFacebook = false);
  }

  void _openEmailMode() {
    setState(() => emailMode = true);
  }

  void _closeEmailMode() {
    setState(() {
      emailMode = false;
      emailOtpRequestId = null;
      emailSetupToken = null;
      emailProfileRequired = false;
      pendingEmailPassword = null;
      emailOtpController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
    });
  }

  Future<void> _emailPasswordLogin() async {
    if (busy) return;
    final email = emailController.text.trim();
    final password = emailPasswordController.text;

    if (!email.contains('@')) {
      _snack('Enter a valid email / Gmail ID.');
      return;
    }
    if (password.isEmpty) {
      _snack('Enter your Tinni password.');
      return;
    }

    setState(() => busy = true);
    try {
      final result = await _api.emailPasswordLogin(
        email: email,
        password: password,
      );
      if (!mounted) return;
      await _finishLogin(result);
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sendEmailOtp() async {
    if (busy) return;
    if (!emailReady) {
      _snack(emailSetupError ?? 'Email OTP service is not configured yet.');
      return;
    }
    final email = emailController.text.trim();

    if (!email.contains('@')) {
      _snack('Enter a valid email / Gmail ID.');
      return;
    }

    setState(() => busy = true);
    try {
      final started = await _api.startEmailOtp(email);
      if (!mounted) return;
      setState(() {
        emailOtpRequestId = started.requestId;
        emailSetupToken = null;
        emailProfileRequired = false;
      });
      _snack('OTP sent to ' + started.email);
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verifyEmailOtp() async {
    if (busy) return;
    final requestId = emailOtpRequestId;
    if (requestId == null || requestId.isEmpty) return;

    final otp = emailOtpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _snack('Enter the 6-digit OTP.');
      return;
    }

    setState(() => busy = true);
    try {
      final verified = await _api.verifyEmailOtp(
        requestId: requestId,
        otp: otp,
      );
      if (!mounted) return;
      setState(() {
        emailSetupToken = verified.setupToken;
        emailProfileRequired = verified.profileRequired;
        emailController.text = verified.email;
      });
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _saveEmailPassword() async {
    if (busy) return;
    final setupToken = emailSetupToken;
    if (setupToken == null || setupToken.isEmpty) return;

    final password = newPasswordController.text;
    final confirm = confirmPasswordController.text;
    if (password.length < 8) {
      _snack('Tinni password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      _snack('Password and confirm password do not match.');
      return;
    }

    if (emailProfileRequired) {
      setState(() {
        pendingProvider = 'email';
        pendingAccountLabel = emailController.text.trim();
        pendingEmailPassword = password;
      });
      return;
    }

    setState(() => busy = true);
    try {
      final result = await _api.completeEmailPassword(
        setupToken: setupToken,
        password: password,
      );
      if (!mounted) return;
      await _finishLogin(result);
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _applyDraft(
    AuthProfileDraft? draft, {
    required String fallbackName,
    required String fallbackLabel,
  }) {
    final name = draft?.displayName.trim();
    if (nameController.text.trim().isEmpty) {
      nameController.text =
          name != null && name.isNotEmpty ? name : fallbackName;
    }

    final email = draft?.email.trim();
    pendingAccountLabel =
        email != null && email.isNotEmpty ? email : fallbackLabel;

    if (mounted) setState(() {});
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: RoyalPalette.gold,
              ),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: RoyalPalette.gold,
              ),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 65,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (bytes.length > 320000) {
      _snack('Please select a smaller profile photo.');
      return;
    }

    if (!mounted) return;
    setState(() {
      avatarDataUrl = 'data:image/jpeg;base64,' + base64Encode(bytes);
    });
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      useSafeArea: true,
      onSelect: (country) {
        setState(() => selectedCountry = country);
      },
    );
  }

  Future<void> _createId() async {
    final provider = pendingProvider;
    if (busy || provider == null) return;

    final name = nameController.text.trim();
    final age = int.tryParse(ageController.text.trim());

    if (name.isEmpty) {
      _snack('Enter your name.');
      return;
    }
    if (age == null || age < 1 || age > 120) {
      _snack('Enter a valid age.');
      return;
    }
    if (selectedCountry == null) {
      _snack('Select your country and flag.');
      return;
    }
    if (selectedGender == null) {
      _snack('Select male or female.');
      return;
    }
    if (signatureWords > 150) {
      _snack('Signature can contain maximum 150 words.');
      return;
    }

    final country = selectedCountry!;
    final profile = <String, dynamic>{
      'display_name': name,
      'age': age,
      'signature': signatureController.text.trim(),
      'country_code': country.countryCode,
      'country_name': country.name,
      'flag_emoji': country.flagEmoji,
      'gender': selectedGender,
      'avatar_data_url': avatarDataUrl,
    };

    setState(() => busy = true);
    try {
      late final AppLoginResult result;

      if (provider == 'google') {
        final token = pendingGoogleIdToken;
        if (token == null || token.isEmpty) {
          throw StateError(
            'Google login session expired. Please sign in again.',
          );
        }
        result = await _api.googleLogin(
          idToken: token,
          profile: profile,
        );
      } else if (provider == 'facebook') {
        final requestId = pendingFacebookRequestId;
        if (requestId == null || requestId.isEmpty) {
          throw StateError(
            'Facebook login session expired. Please sign in again.',
          );
        }
        result = await _api.completeFacebookLogin(
          requestId: requestId,
          profile: profile,
        );
      } else if (provider == 'email') {
        final setupToken = emailSetupToken;
        final password = pendingEmailPassword;
        if (setupToken == null ||
            setupToken.isEmpty ||
            password == null ||
            password.isEmpty) {
          throw StateError(
            'Email verification session expired. Please verify again.',
          );
        }
        result = await _api.completeEmailPassword(
          setupToken: setupToken,
          password: password,
          profile: profile,
        );
      } else {
        throw StateError('Unsupported login provider.');
      }

      if (!mounted) return;
      await _finishLogin(result);
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _finishLogin(AppLoginResult result) async {
    final token = result.token;
    final user = result.user;
    if (token == null || token.isEmpty || user == null || user.isEmpty) {
      throw StateError('Server did not return a valid user account.');
    }

    final account = TinniAccount.fromServer(user, token: token);
    widget.state.auth.setAuthenticatedAccount(account);
    await widget.state.authPersistence?.save(account);
    widget.state.profile.loadFromAccount(account);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TinniShell(state: widget.state),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildEmailPanel() {
    final waitingForOtp =
        emailOtpRequestId != null && emailSetupToken == null;
    final waitingForPassword = emailSetupToken != null;

    return RoyalPanel(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: busy ? null : _closeEmailMode,
                icon: const Icon(Icons.arrow_back_rounded),
                color: RoyalPalette.gold,
              ),
              const Expanded(
                child: Text(
                  'Email / Gmail Login',
                  style: TextStyle(
                    color: RoyalPalette.cream,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('email-login-address'),
            controller: emailController,
            enabled: !busy && !waitingForOtp && !waitingForPassword,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email / Gmail ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (!waitingForOtp && !waitingForPassword) ...[
            TextField(
              key: const Key('email-login-password'),
              controller: emailPasswordController,
              enabled: !busy,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Tinni Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('email-password-login-button'),
                onPressed: busy ? null : _emailPasswordLogin,
                child: const Text('Login with Tinni Password'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'New user or forgot password?',
              style: TextStyle(
                color: RoyalPalette.muted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('email-send-otp-button'),
                onPressed: busy || !emailReady ? null : _sendEmailOtp,
                icon: const Icon(Icons.mark_email_read_rounded),
                label: const Text('Send OTP to Email'),
              ),
            ),
          ] else if (waitingForOtp) ...[
            TextField(
              key: const Key('email-otp-field'),
              controller: emailOtpController,
              enabled: !busy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '6-digit OTP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('email-verify-otp-button'),
                onPressed: busy ? null : _verifyEmailOtp,
                child: const Text('Verify OTP'),
              ),
            ),
          ] else ...[
            const Text(
              'OTP verified. Create your Tinni password.',
              style: TextStyle(
                color: RoyalPalette.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('email-new-password'),
              controller: newPasswordController,
              enabled: !busy,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Tinni Password',
                helperText: 'Minimum 8 characters',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('email-confirm-password'),
              controller: confirmPasswordController,
              enabled: !busy,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Tinni Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('email-save-password-button'),
                onPressed: busy ? null : _saveEmailPassword,
                child: const Text('Save Tinni Password'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your Gmail password is never requested or stored.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: RoyalPalette.muted,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderPanel() {
    return RoyalPanel(
      child: Column(
        children: [
          const Icon(
            Icons.account_circle_rounded,
            color: RoyalPalette.gold,
            size: 56,
          ),
          const SizedBox(height: 12),
          const Text(
            'Sign in with Google, Facebook, or Email / Gmail.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('google-login-button'),
              onPressed: googleReady && !busy && !waitingFacebook
                  ? _googleLogin
                  : null,
              icon: const Icon(Icons.g_mobiledata_rounded),
              label: Text(
                busy ? 'Connecting…' : 'Continue with Google',
              ),
            ),
          ),
          if (googleSetupError != null) ...[
            const SizedBox(height: 7),
            Text(
              googleSetupError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 10,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'OR',
            style: TextStyle(
              color: RoyalPalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('facebook-login-button'),
              onPressed: facebookReady && !busy && !waitingFacebook
                  ? _facebookLogin
                  : null,
              icon: const Icon(Icons.facebook),
              label: Text(
                waitingFacebook
                    ? 'Waiting for Facebook…'
                    : 'Continue with Facebook',
              ),
            ),
          ),
          if (waitingFacebook) ...[
            const SizedBox(height: 7),
            const Text(
              'Complete Facebook login in your browser, then return here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: RoyalPalette.cream,
                fontSize: 10,
              ),
            ),
            TextButton(
              onPressed: _cancelFacebookWait,
              child: const Text('Cancel'),
            ),
          ] else if (facebookSetupError != null) ...[
            const SizedBox(height: 7),
            Text(
              facebookSetupError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 10,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'OR',
            style: TextStyle(
              color: RoyalPalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('email-login-button'),
              onPressed: !busy && !waitingFacebook ? _openEmailMode : null,
              icon: const Icon(Icons.email_rounded),
              label: const Text('Login with Email / Gmail'),
            ),
          ),
          if (emailSetupError != null) ...[
            const SizedBox(height: 7),
            Text(
              emailSetupError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileSetup = pendingProvider != null;
    final country = selectedCountry;

    return Scaffold(
      backgroundColor: RoyalPalette.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'Tinni Star',
                style: TextStyle(
                  color: RoyalPalette.gold,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Create your new ID',
                style: TextStyle(color: RoyalPalette.cream),
              ),
            ),
            const SizedBox(height: 24),
            if (!profileSetup) ...[
              emailMode ? _buildEmailPanel() : _buildProviderPanel(),
            ] else ...[
              Text(
                pendingAccountLabel ??
                    (pendingProvider == 'facebook'
                        ? 'Facebook account'
                        : pendingProvider == 'email'
                            ? 'Email account'
                            : 'Google account'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RoyalPalette.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: InkWell(
                  onTap: busy ? null : _pickAvatar,
                  borderRadius: BorderRadius.circular(60),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: RoyalPalette.panel2,
                    backgroundImage: avatarDataUrl == null
                        ? null
                        : MemoryImage(
                            base64Decode(avatarDataUrl!.split(',').last),
                          ),
                    child: avatarDataUrl == null
                        ? const Icon(
                            Icons.add_a_photo_rounded,
                            color: RoyalPalette.gold,
                            size: 36,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Tap to select DP',
                  style: TextStyle(color: RoyalPalette.muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                enabled: !busy,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ageController,
                enabled: !busy,
                keyboardType: TextInputType.number,
                maxLength: 3,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                key: const Key('country-picker-button'),
                onTap: busy ? null : _pickCountry,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Country / flag',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    country == null
                        ? 'Select country'
                        : country.flagEmoji + ' ' + country.name,
                    style: TextStyle(
                      color: country == null
                          ? RoyalPalette.muted
                          : RoyalPalette.cream,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Gender',
                style: TextStyle(
                  color: RoyalPalette.cream,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Male'),
                      selected: selectedGender == 'male',
                      onSelected: busy
                          ? null
                          : (_) => setState(() => selectedGender = 'male'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Female'),
                      selected: selectedGender == 'female',
                      onSelected: busy
                          ? null
                          : (_) => setState(() => selectedGender = 'female'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: signatureController,
                enabled: !busy,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Signature',
                  hintText: 'Write up to 150 words',
                  helperText: '$signatureWords / 150 words',
                  errorText: signatureWords > 150
                      ? 'Maximum 150 words allowed'
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('create-real-id-button'),
                  onPressed:
                      busy || signatureWords > 150 ? null : _createId,
                  icon: const Icon(Icons.verified_user_rounded),
                  label: Text(busy ? 'Creating ID…' : 'Create Tinni ID'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
