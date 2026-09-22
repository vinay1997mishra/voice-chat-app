class NamedRankEntry {
  const NamedRankEntry({
    required this.id,
    required this.score,
  });

  final String id;
  final int score;
}

class RankFeatureService {
  final Map<String, int> cp = <String, int>{};
  final Map<String, int> family = <String, int>{};
  final Map<String, int> room = <String, int>{};
  final Map<String, int> signIn = <String, int>{};
  final Set<String> hallOfFame = <String>{};

  void addCp(String id, int value) => _add(cp, id, value);
  void addFamily(String id, int value) => _add(family, id, value);
  void addRoom(String id, int value) => _add(room, id, value);
  void addSignIn(String id, int value) => _add(signIn, id, value);

  List<NamedRankEntry> rank(Map<String, int> source) {
    final result = source.entries
        .map((entry) => NamedRankEntry(id: entry.key, score: entry.value))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  void promoteHallOfFame(String id) => hallOfFame.add(id);

  void _add(Map<String, int> source, String id, int value) {
    if (value <= 0) return;
    source[id] = (source[id] ?? 0) + value;
  }
}
