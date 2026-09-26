import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/tinni_state.dart';
import '../sharing/share_service.dart';
import '../ui/royal_theme.dart';

class SharingScreen extends StatelessWidget {
  const SharingScreen({
    super.key,
    required this.state,
    this.payload = const SharePayload(
      title: 'Join Tinni Star',
      link: 'https://tinni.star',
    ),
  });

  final TinniState state;
  final SharePayload payload;

  String get text => payload.title + ' ' + payload.link;

  Future<void> _systemShare(BuildContext context) async {
    state.sharing.prepare(ShareTarget.copyLink, payload);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: payload.link));
    state.sharing.prepare(ShareTarget.copyLink, payload);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied.')),
    );
  }

  Future<void> _launchOrShare(
    BuildContext context,
    ShareTarget target,
    Uri uri,
  ) async {
    state.sharing.prepare(target, payload);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    await _systemShare(context);
  }

  @override
  Widget build(BuildContext context) {
    final encodedText = Uri.encodeComponent(text);
    final encodedLink = Uri.encodeComponent(payload.link);
    final actions = <(String, IconData, VoidCallback)>[
      ('Android Share Sheet', Icons.share_rounded, () => _systemShare(context)),
      ('Copy Link', Icons.link_rounded, () => _copy(context)),
      (
        'WhatsApp',
        Icons.chat_rounded,
        () => _launchOrShare(
          context,
          ShareTarget.whatsapp,
          Uri.parse('https://wa.me/?text=' + encodedText),
        ),
      ),
      (
        'Telegram',
        Icons.send_rounded,
        () => _launchOrShare(
          context,
          ShareTarget.telegram,
          Uri.parse(
            'https://t.me/share/url?url=' +
                encodedLink +
                '&text=' +
                Uri.encodeComponent(payload.title),
          ),
        ),
      ),
      (
        'Facebook',
        Icons.facebook_rounded,
        () => _launchOrShare(
          context,
          ShareTarget.facebook,
          Uri.parse(
            'https://www.facebook.com/sharer/sharer.php?u=' + encodedLink,
          ),
        ),
      ),
      (
        'Instagram',
        Icons.camera_alt_rounded,
        () => _systemShare(context),
      ),
      (
        'Snapchat',
        Icons.photo_camera_front_rounded,
        () => _systemShare(context),
      ),
    ];

    return Scaffold(
      key: const Key('sharing-screen'),
      appBar: AppBar(
        title: const Text(
          'Share',
          style: TextStyle(
            color: FeaturePalette.social,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: actions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.15,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (_, index) {
          final item = actions[index];
          return RoyalPanel(
            onTap: item.$3,
            gradient: FeaturePalette.glow(FeaturePalette.social),
            accentColor: FeaturePalette.social,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShiningIcon(
                  icon: item.$2,
                  color: FeaturePalette.social,
                  size: 30,
                  boxSize: 54,
                  glow: 0.36,
                ),
                const SizedBox(height: 8),
                Text(
                  item.$1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
