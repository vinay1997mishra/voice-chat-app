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
  final List<Song> library = <Song>[
    const Song(id: 's1', title: 'Tinni Nights', singer: 'Demo Artist'),
    const Song(id: 's2', title: 'Star Voice', singer: 'Demo Artist'),
  ];

  final List<KtvQueueEntry> queue = <KtvQueueEntry>[];
  KtvQueueEntry? current;

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
