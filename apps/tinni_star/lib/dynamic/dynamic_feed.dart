enum DynamicState { draft, underReview, published, rejected }

class DynamicPost {
  const DynamicPost({
    required this.id,
    required this.authorId,
    required this.text,
    required this.state,
    this.topic,
    this.likes = 0,
    this.comments = const [],
  });

  final String id;
  final String authorId;
  final String text;
  final DynamicState state;
  final String? topic;
  final int likes;
  final List<String> comments;

  DynamicPost copyWith({
    DynamicState? state,
    int? likes,
    List<String>? comments,
  }) {
    return DynamicPost(
      id: id,
      authorId: authorId,
      text: text,
      state: state ?? this.state,
      topic: topic,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
    );
  }
}

class DynamicFeedService {
  final List<DynamicPost> posts = <DynamicPost>[];
  int _nextId = 1;

  DynamicPost submit({
    required String authorId,
    required String text,
    String? topic,
  }) {
    final post = DynamicPost(
      id: (_nextId++).toString(),
      authorId: authorId,
      text: text.trim(),
      topic: topic,
      state: DynamicState.underReview,
    );
    posts.insert(0, post);
    return post;
  }

  void moderate(String id, {required bool approve}) {
    final index = posts.indexWhere((post) => post.id == id);
    if (index < 0) return;
    posts[index] = posts[index].copyWith(
      state: approve ? DynamicState.published : DynamicState.rejected,
    );
  }

  void like(String id) {
    final index = posts.indexWhere((post) => post.id == id);
    if (index < 0) return;
    posts[index] = posts[index].copyWith(likes: posts[index].likes + 1);
  }

  void comment(String id, String text) {
    final index = posts.indexWhere((post) => post.id == id);
    final value = text.trim();
    if (index < 0 || value.isEmpty) return;
    posts[index] = posts[index].copyWith(
      comments: [...posts[index].comments, value],
    );
  }
}
