import 'dart:convert';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _prefsKey = 'tinni_ktv_local_songs_v1';
  bool _localLibraryLoaded = false;
  // Continuous playback: completed songs advance through the room queue.

  AudioPlayer? _player;
  bool _completionListenerAttached = false;
  AudioPlayer get _audio {
    final player = _player ??= AudioPlayer();
    if (!_completionListenerAttached) {
      _completionListenerAttached = true;
      player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _playNextAfterCompletion();
        }
      });
    }
    return player;
  }

  Future<void> _playNextAfterCompletion() async {
    final next = startNext();
    if (next != null) await playCurrent();
  }
  bool get isPlaying => _player?.playing ?? false;

  Future<void> playCurrent() async {
    final song = current?.song;
    final path = song?.sourcePath;
    if (song == null || !song.local || path == null || path.isEmpty) return;
    await _audio.setFilePath(path);
    await _audio.play();
  }

  Future<void> pause() => _audio.pause();
  Future<void> resume() => _audio.play();

  Future<void> stopPlayback() async {
    await _audio.stop();
  }

  Future<KtvQueueEntry?> playNext() async {
    await _audio.stop();
    final next = startNext();
    if (next != null) await playCurrent();
    return next;
  }

  Future<void> dispose() async {
    final player = _player;
    _player = null;
    _completionListenerAttached = false;
    if (player != null) await player.dispose();
  }

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

  Future<void> loadLocalSongs() async {
    if (_localLibraryLoaded) return;
    _localLibraryLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      library.removeWhere((song) => song.local);
      for (final item in decoded.whereType<Map>()) {
        final path = item['source_path']?.toString() ?? '';
        if (path.isEmpty || !await File(path).exists()) continue;
        library.add(
          Song(
            id: item['id']?.toString() ?? '',
            title: item['title']?.toString() ?? 'Phone Music',
            singer: item['singer']?.toString() ?? 'From phone',
            local: true,
            sourcePath: path,
          ),
        );
      }
      await _persistLocalSongs();
    } catch (_) {
      // Corrupt local metadata is ignored; files remain inside app storage.
    }
  }

  Future<void> _persistLocalSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = library
        .where((song) => song.local && song.sourcePath != null)
        .map(
          (song) => <String, Object?>{
            'id': song.id,
            'title': song.title,
            'singer': song.singer,
            'source_path': song.sourcePath,
          },
        )
        .toList(growable: false);
    await prefs.setString(_prefsKey, jsonEncode(rows));
  }

  Future<Song> importLocalSong({
    required String fileName,
    required String sourcePath,
  }) async {
    await loadLocalSongs();
    if (!canAddLocalSong) {
      throw StateError('Maximum 300 phone songs can be added.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) throw StateError('Selected audio file is unavailable.');

    final base = await getApplicationSupportDirectory();
    final musicDir = Directory(base.path + Platform.pathSeparator + 'music');
    if (!await musicDir.exists()) await musicDir.create(recursive: true);

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final id = 'local-' + DateTime.now().microsecondsSinceEpoch.toString();
    final targetPath = musicDir.path +
        Platform.pathSeparator +
        id +
        '-' +
        (safeName.trim().isEmpty ? 'music' : safeName);
    await source.copy(targetPath);

    final dot = fileName.lastIndexOf('.');
    final title = dot > 0 ? fileName.substring(0, dot) : fileName;
    final song = Song(
      id: id,
      title: title.trim().isEmpty ? 'Phone Music' : title.trim(),
      singer: 'From phone',
      local: true,
      sourcePath: targetPath,
    );
    library.insert(0, song);
    await _persistLocalSongs();
    return song;
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

  Future<bool> removeLocalSongAndFile(String songId) async {
    final song = library.where((item) => item.local && item.id == songId).firstOrNull;
    if (song == null) return false;
    final removed = removeLocalSong(songId);
    if (!removed) return false;
    final path = song.sourcePath;
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await _persistLocalSongs();
    return true;
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
