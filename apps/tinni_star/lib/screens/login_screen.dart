import 'dart:convert';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

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

  bool busy = false;
  bool googleReady = false;
  String? googleSetupError;
  String? googleIdToken;
  String? googleEmail;
  Country? selectedCountry;
  String? selectedGender;
  String? avatarDataUrl;

  @override
  void initState() {
    super.initState();
    signatureController.addListener(_refresh);
    _prepareGoogle();
  }

  @override
  void dispose() {
    signatureController.removeListener(_refresh);
    nameController.dispose();
    ageController.dispose();
    signatureController.dispose();
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

  Future<void> _prepareGoogle() async {
    try {
      final serverClientId = await _api.loadGoogleServerClientId();
      if (serverClientId == null) {
        throw StateError('Google OAuth client ID is not configured yet.');
      }
      await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
      if (!mounted) return;
      setState(() {
        googleReady = true;
        googleSetupError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        googleReady = false;
        googleSetupError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _googleLogin() async {
    if (busy || !googleReady) return;
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

      googleIdToken = token;
      googleEmail = result.googleDraft?.email ?? googleAccount.email;
      if (nameController.text.trim().isEmpty) {
        nameController.text =
            result.googleDraft?.displayName.isNotEmpty == true
                ? result.googleDraft!.displayName
                : (googleAccount.displayName ?? '');
      }
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
      avatarDataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
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
    final token = googleIdToken;
    if (busy || token == null) return;

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

    setState(() => busy = true);
    try {
      final country = selectedCountry!;
      final result = await _api.googleLogin(
        idToken: token,
        profile: <String, dynamic>{
          'display_name': name,
          'age': age,
          'signature': signatureController.text.trim(),
          'country_code': country.countryCode,
          'country_name': country.name,
          'flag_emoji': country.flagEmoji,
          'gender': selectedGender,
          'avatar_data_url': avatarDataUrl,
        },
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

  @override
  Widget build(BuildContext context) {
    final profileSetup = googleIdToken != null;
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
                'Create your real Tinni ID',
                style: TextStyle(color: RoyalPalette.cream),
              ),
            ),
            const SizedBox(height: 24),
            if (!profileSetup) ...[
              RoyalPanel(
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_circle_rounded,
                      color: RoyalPalette.gold,
                      size: 56,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in with your Google / Gmail account first.',
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
                        onPressed:
                            googleReady && !busy ? _googleLogin : null,
                        icon: const Icon(Icons.g_mobiledata_rounded),
                        label: Text(
                          busy ? 'Connecting…' : 'Continue with Google',
                        ),
                      ),
                    ),
                    if (googleSetupError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        googleSetupError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Text(
                googleEmail ?? '',
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
                        : '${country.flagEmoji} ${country.name}',
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
