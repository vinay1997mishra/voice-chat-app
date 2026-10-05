import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tinni_star/media/ktv_service.dart';
class _Player implements AudioPlayer {
  final pending=Completer<void>();
  bool playingValue=false;
  int pauses=0,stops=0;
  @override bool get playing=>playingValue;
  @override Stream<PlayerState> get playerStateStream=>const Stream.empty();
  @override Future<Duration?> setFilePath(String path,{Duration? initialPosition, bool preload=true, dynamic tag}) async=>Duration.zero;
  @override Future<void> setVolume(double volume) async {}
  @override Future<void> play(){playingValue=true;return pending.future;}
  @override Future<void> pause() async {pauses++;playingValue=false;}
  @override Future<void> stop() async {stops++;playingValue=false;}
  @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
void main(){
  test('starting and resuming long music does not block pause/stop/seat-down',() async{
    final player=_Player(),ktv=KtvService(audioPlayer:player);
    ktv.current=const KtvQueueEntry(song:Song(id:'song',title:'Song',singer:'Me',
      local:true,sourcePath:'/test/song.mp3'),userId:'me');
    await ktv.playCurrent().timeout(const Duration(seconds:1));
    expect(ktv.isPlaying,true);
    await ktv.togglePlayPause();expect(ktv.isPaused,true);expect(player.pauses,1);
    await ktv.resume().timeout(const Duration(seconds:1));expect(ktv.isPaused,false);
    await ktv.stopForSeatDown('me');expect(player.stops,1);expect(ktv.current,isNull);
    player.pending.complete();
  });
}
