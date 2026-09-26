enum ShareTarget { whatsapp, telegram, facebook, instagram, snapchat, zalo, messenger, copyLink }

class SharePayload {
  const SharePayload({
    required this.title,
    required this.link,
  });

  final String title;
  final String link;
}

class ShareService {
  final List<String> history = <String>[];

  String prepare(ShareTarget target, SharePayload payload) {
    final value = target.name + ': ' + payload.title + ' ' + payload.link;
    history.insert(0, value);
    return value;
  }
}
