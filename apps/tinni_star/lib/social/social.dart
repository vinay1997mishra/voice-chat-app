class SocialUser {
  const SocialUser({
    required this.id,
    required this.name,
    this.inRoomId,
  });

  final String id;
  final String name;
  final String? inRoomId;
}

class ChatMessage {
  const ChatMessage({
    required this.from,
    required this.to,
    required this.text,
  });

  final String from;
  final String to;
  final String text;
}

class SocialService {
  final Set<String> following = <String>{};
  final Set<String> friends = <String>{};
  final Set<String> blocked = <String>{};
  final List<ChatMessage> directMessages = <ChatMessage>[];

  void follow(String userId) => following.add(userId);
  void unfollow(String userId) => following.remove(userId);

  void addFriend(String userId) {
    if (!blocked.contains(userId)) friends.add(userId);
  }

  void block(String userId) {
    blocked.add(userId);
    following.remove(userId);
    friends.remove(userId);
  }

  void unblock(String userId) => blocked.remove(userId);

  bool sendDirectMessage({
    required String from,
    required String to,
    required String text,
  }) {
    final value = text.trim();
    if (value.isEmpty || blocked.contains(to)) return false;
    directMessages.add(ChatMessage(from: from, to: to, text: value));
    return true;
  }
}
