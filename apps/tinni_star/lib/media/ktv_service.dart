class Song {
  const Song({
    required this.id,
    required this.title,
    required this.singer,
    this.local = false,
    this.sourcePath,
  });

  final String id;
  final String title;
  final String singer;
  final bool local;
  final String? sourcePath;
}

class KtvQueueEntry {
  const KtvQueueEntry({
    required this.song,
    required this.userId,
    this.chorus = false,
  });

  final Song song;
  final String userId;
  final bool chorus;
}

class KtvService {
  static const int maxLocalSongs = 300;

  final List<Song> library = <Song>[
    const Song(id: 's1', title: 'Tinni Nights', singer: 'Demo Artist'),
    const Song(id: 's2', title: 'Star Voice', singer: 'Demo Artist'),
  ];

  final List<KtvQueueEntry> queue = <KtvQueueEntry>[];
  KtvQueueEntry? current;

  int get localSongCount => library.where((song) => song.local).length;
  bool get canAddLocalSong => localSongCount < maxLocalSongs;

  List<Song> search(String text) {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) return library;
    return library
        .where(
          (song) =>
              song.title.toLowerCase().contains(query) ||
              song.singer.toLowerCase().contains(query),
        )
        .toList();
  }

  Song addLocalSong({
    required String fileName,
    required String sourcePath,
  }) {
    if (!canAddLocalSong) {
      throw StateError('Maximum 300 phone songs can be added.');
    }
    final dot = fileName.lastIndexOf('.');
    final title = dot > 0 ? fileName.substring(0, dot) : fileName;
    final song = Song(
      id: 'local-' + DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Phone Music' : title.trim(),
      singer: 'From phone',
      local: true,
      sourcePath: sourcePath,
    );
    library.insert(0, song);
    return song;
  }

  bool removeLocalSong(String songId) {
    final index = library.indexWhere(
      (song) => song.local && song.id == songId,
    );
    if (index < 0) return false;

    library.removeAt(index);
    queue.removeWhere((entry) => entry.song.id == songId);

    if (current?.song.id == songId) {
      current = null;
      startNext();
    }
    return true;
  }

  void addToQueue(Song song, String userId, {bool chorus = false}) {
    queue.add(KtvQueueEntry(song: song, userId: userId, chorus: chorus));
  }

  KtvQueueEntry? startNext() {
    if (queue.isEmpty) {
      current = null;
      return null;
    }
    current = queue.removeAt(0);
    return current;
  }

  void giveUp() {
    current = null;
    startNext();
  }
}
