import 'ktv_service.dart';

enum KtvRepeatMode { queue, singleCycle }

class KtvFeedback {
  const KtvFeedback({
    required this.songId,
    required this.kind,
    required this.details,
  });

  final String songId;
  final String kind;
  final String details;
}

class KtvFeatureService {
  KtvFeatureService(this.ktv);

  final KtvService ktv;
  KtvRepeatMode repeatMode = KtvRepeatMode.queue;
  final List<Song> localSongs = <Song>[];
  final List<KtvFeedback> feedback = <KtvFeedback>[];

  void scanLocalSongs(Iterable<Song> songs) {
    for (final song in songs) {
      if (!localSongs.any((item) => item.id == song.id)) {
        localSongs.add(song);
      }
    }
  }

  void deleteQueuedSong(String songId) {
    ktv.queue.removeWhere((entry) => entry.song.id == songId);
  }

  KtvQueueEntry? cutToNext() => ktv.startNext();

  void reportSong({
    required String songId,
    required String kind,
    required String details,
  }) {
    feedback.add(
      KtvFeedback(songId: songId, kind: kind, details: details),
    );
  }

  void finishCurrent() {
    if (repeatMode == KtvRepeatMode.singleCycle && ktv.current != null) {
      final current = ktv.current!;
      ktv.addToQueue(
        current.song,
        current.userId,
        chorus: current.chorus,
      );
    }
    ktv.startNext();
  }
}
