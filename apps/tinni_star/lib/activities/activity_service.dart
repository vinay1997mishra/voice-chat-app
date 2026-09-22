class ActivityDefinition {
  const ActivityDefinition({
    required this.id,
    required this.title,
    required this.stage,
    required this.reward,
  });

  final String id;
  final String title;
  final int stage;
  final String reward;
}

class RankEntry {
  const RankEntry({
    required this.userId,
    required this.score,
  });

  final String userId;
  final int score;
}

class ActivityService {
  final List<ActivityDefinition> activities = const [
    ActivityDefinition(
      id: 'birthday',
      title: 'Birthday Party',
      stage: 1,
      reward: 'Birthday gift box',
    ),
    ActivityDefinition(
      id: 'dating',
      title: 'Dating Party',
      stage: 1,
      reward: 'Party reward',
    ),
  ];

  final Map<String, Set<String>> participants = <String, Set<String>>{};
  final Map<String, int> charmScores = <String, int>{};
  final Map<String, int> giftScores = <String, int>{};

  void join(String activityId, String userId) {
    participants.putIfAbsent(activityId, () => <String>{}).add(userId);
  }

  void addCharm(String userId, int score) {
    charmScores[userId] = (charmScores[userId] ?? 0) + score;
  }

  void addGiftScore(String userId, int score) {
    giftScores[userId] = (giftScores[userId] ?? 0) + score;
  }

  List<RankEntry> charmRank() => _rank(charmScores);
  List<RankEntry> giftRank() => _rank(giftScores);

  List<RankEntry> _rank(Map<String, int> source) {
    final entries = source.entries
        .map((entry) => RankEntry(userId: entry.key, score: entry.value))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }
}
