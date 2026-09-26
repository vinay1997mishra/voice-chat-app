import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';

class CallVerificationScreen extends StatefulWidget {
  const CallVerificationScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<CallVerificationScreen> createState() =>
      _CallVerificationScreenState();
}

class _CallVerificationScreenState extends State<CallVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  late final FaceDetector _detector;

  final List<String?> _photos = List<String?>.filled(3, null);
  final List<double?> _yaw = List<double?>.filled(3, null);
  final List<bool> _faceOk = List<bool>.filled(3, false);

  bool loading = true;
  bool submitting = false;
  String? errorText;
  String statusText = 'Checking verification status…';
  bool alreadyVerified = false;

  static const _instructions = <String>[
    'Look straight at the camera',
    'Turn your head to one side',
    'Turn your head to the opposite side',
  ];

  @override
  void initState() {
    super.initState();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableClassification: true,
      ),
    );
    _loadStatus();
  }

  @override
  void dispose() {
    _detector.close();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final account = widget.state.auth.current;
    if (account == null) {
      setState(() {
        loading = false;
        errorText = 'Login session is required.';
      });
      return;
    }

    try {
      final status = await widget.state.calls.verificationStatus(
        authToken: account.authToken,
      );
      if (!mounted) return;
      setState(() {
        loading = false;
        alreadyVerified = status.verified;
        statusText = status.verified
            ? 'Your Call ID is already Verified. Verification will not be asked again unless Owner removes Verified status.'
            : status.status == 'pending_owner'
                ? 'Your 3 photos are already waiting for Owner final review.'
                : status.status == 'rejected'
                    ? 'Verification was rejected. Please contact the Official Manager.'
                    : status.status == 'revoked'
                        ? 'Owner removed Verified status. Complete verification again.'
                        : 'Complete the one-time 3-step live camera check.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _capture(int index) async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 45,
      maxWidth: 720,
      maxHeight: 720,
    );
    if (file == null || !mounted) return;

    double? yaw;
    bool oneFace = false;
    try {
      final input = InputImage.fromFilePath(file.path);
      final faces = await _detector.processImage(input);
      oneFace = faces.length == 1;
      if (oneFace) yaw = faces.first.headEulerAngleY;
    } catch (_) {
      oneFace = false;
    }

    final bytes = await file.readAsBytes();
    final photo = 'data:image/jpeg;base64,' + base64Encode(bytes);
    if (!mounted) return;

    setState(() {
      _photos[index] = photo;
      _yaw[index] = yaw;
      _faceOk[index] = oneFace;
      errorText = null;
    });
  }

  bool get _systemPassed {
    if (_photos.any((photo) => photo == null)) return false;
    if (_faceOk.any((ok) => !ok)) return false;

    final front = _yaw[0];
    final sideA = _yaw[1];
    final sideB = _yaw[2];
    if (front == null || sideA == null || sideB == null) return false;

    final frontOk = front.abs() <= 15;
    final sideAOk = sideA.abs() >= 12;
    final sideBOk = sideB.abs() >= 12;
    final oppositeSides = sideA * sideB < 0;
    return frontOk && sideAOk && sideBOk && oppositeSides;
  }

  Future<void> _submit() async {
    if (submitting || _photos.any((photo) => photo == null)) return;
    final account = widget.state.auth.current;
    if (account == null) return;

    setState(() => submitting = true);
    try {
      final result = await widget.state.calls.submitVerification(
        authToken: account.authToken,
        photos: _photos.cast<String>(),
        systemPassed: _systemPassed,
        systemDetails: <String, Object?>{
          'challenge': 'front-opposite-head-turns',
          'front_yaw': _yaw[0],
          'side_a_yaw': _yaw[1],
          'side_b_yaw': _yaw[2],
          'one_face_each_photo': _faceOk.every((ok) => ok),
        },
      );
      if (!mounted) return;

      final already = result['already_verified'] == true;
      final systemPassed = result['system_passed'] == true;
      setState(() {
        alreadyVerified = already;
        statusText = already
            ? 'Your Call ID is already Verified.'
            : systemPassed
                ? 'System pre-check passed. Your 3 photos were sent to Owner Main Panel for final verification.'
                : 'System pre-check could not verify the challenge. Your 3 photos were sent for final review. Please contact the Official Manager.';
        errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('call-verification-screen'),
      appBar: AppBar(
        title: const Text(
          'Verify Call ID',
          style: TextStyle(
            color: FeaturePalette.social,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                RoyalPanel(
                  gradient: FeaturePalette.glow(FeaturePalette.social),
                  accentColor: FeaturePalette.social,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'One-time verification',
                        style: TextStyle(
                          color: RoyalPalette.cream,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusText,
                        style: const TextStyle(color: RoyalPalette.muted),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This is a basic face/pose liveness pre-check. Owner Main Panel makes the final verification decision.',
                        style: TextStyle(
                          color: RoyalPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                if (!alreadyVerified) ...[
                  const SizedBox(height: 14),
                  for (var index = 0; index < 3; index++) ...[
                    RoyalPanel(
                      key: Key('call-verification-step-' + index.toString()),
                      child: Row(
                        children: [
                          ShiningIcon(
                            icon: _photos[index] == null
                                ? Icons.face_rounded
                                : Icons.check_circle_rounded,
                            color: _photos[index] == null
                                ? FeaturePalette.message
                                : FeaturePalette.social,
                            size: 22,
                            boxSize: 42,
                            glow: 0.32,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Step ' +
                                      (index + 1).toString() +
                                      ': ' +
                                      _instructions[index],
                                  style: const TextStyle(
                                    color: RoyalPalette.cream,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (_photos[index] != null)
                                  Text(
                                    _faceOk[index]
                                        ? 'Face detected'
                                        : 'Face check needs review',
                                    style: const TextStyle(
                                      color: RoyalPalette.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => _capture(index),
                            child: Text(
                              _photos[index] == null ? 'Camera' : 'Retake',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 6),
                  FilledButton.icon(
                    key: const Key('call-verification-submit'),
                    onPressed: submitting ||
                            _photos.any((photo) => photo == null)
                        ? null
                        : _submit,
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user_rounded),
                    label: const Text('Submit 3 Photos'),
                  ),
                ],
              ],
            ),
    );
  }
}
