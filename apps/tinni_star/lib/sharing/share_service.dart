import 'package:share_plus/share_plus.dart';

enum ShareTarget {
  whatsapp,
  telegram,
  facebook,
  instagram,
  snapchat,
  zalo,
  messenger,
  copyLink,
}

class SharePayload {
  const SharePayload({required this.title, required this.link});
  final String title;
  final String link;

  String get text => '${title.trim()} ${link.trim()}'.trim();
}

abstract interface class NativeShareAdapter {
  Future<void> share(String text);
}

class SharePlusAdapter implements NativeShareAdapter {
  const SharePlusAdapter();

  @override
  Future<void> share(String text) async {
    final value = text.trim();
    if (value.isEmpty) throw StateError('Share content is empty');
    await SharePlus.instance.share(ShareParams(text: value));
  }
}

class ShareService {
  ShareService({NativeShareAdapter? native})
      : native = native ?? const SharePlusAdapter();

  final NativeShareAdapter native;
  final List<String> history = <String>[];

  String prepare(ShareTarget target, SharePayload payload) {
    final value = '${target.name}: ${payload.text}';
    history.insert(0, value);
    return value;
  }

  Future<void> share(ShareTarget target, SharePayload payload) async {
    prepare(target, payload);
    // Android's native share sheet is used deliberately instead of brittle
    // undocumented deep links. Installed supported apps appear as targets.
    await native.share(payload.text);
  }
}
