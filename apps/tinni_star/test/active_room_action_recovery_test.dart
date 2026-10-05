import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/background/room_foreground_service.dart';
import 'package:tinni_star/background/room_permission_bridge.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/discovery/discovery_service.dart';
import 'package:tinni_star/infra/realtime.dart';
import 'package:tinni_star/room/active_room_session.dart';
import 'package:tinni_star/room/room_models.dart';
import 'package:tinni_star/room/room_presence_service.dart';

class _Rtc implements RtcAdapter {
  int failures = 0, joins = 0;
  Completer<void>? micGate;
  @override RtcConnectionState state = RtcConnectionState.idle;
  @override bool publishingMic = false;
  final _levels = ValueNotifier<Map<String,double>>({});
  @override ValueListenable<Map<String,double>> get speakingLevelsListenable => _levels;
  @override Future<void> join(String roomId,String userId,{String? authToken}) async {
    joins++;
    if (failures>0) { failures--; state=RtcConnectionState.failed; throw StateError('transport failed'); }
    state=RtcConnectionState.joined;
  }
  @override Future<void> leave() async { state=RtcConnectionState.idle;publishingMic=false; }
  @override Future<void> setMicPublished(bool enabled) async {
    if(state!=RtcConnectionState.joined) throw StateError('offline');
    if (enabled && micGate != null) await micGate!.future;
    publishingMic=enabled;
  }
  @override Future<void> setRemoteAudioEnabled(bool enabled) async {}
}
class _Presence extends RoomPresenceService {
  int heartbeats=0;
  @override bool get liveConnected => false;
  void snapshot(int? seat,bool mic) {
    connected=true; seatCount=12;
    members..clear()..add(RoomPresenceMember(userId:'me',displayName:'Me',
      seatIndex:seat,micMuted:!mic,joinedAt:DateTime(2026),lastSeen:DateTime(2026)));
    notifyListeners();
  }
  @override Future<void> join({required String roomId,required String authToken,int? seatIndex,
    bool micEnabled=false,String? familyTag,String? hostTag,String? agencyName,
    String? equippedFrameId,String? equippedEntryId,String? equippedProfileCardId}) async {
    snapshot(seatIndex,micEnabled);
  }
  @override Future<void> heartbeat({required String roomId,required String authToken,int? seatIndex,
    bool micEnabled=false,String? familyTag,String? hostTag,String? agencyName,
    String? equippedFrameId,String? equippedEntryId,String? equippedProfileCardId}) async {
    heartbeats++; selfSeatForced=false;selfForcedSeatIndex=null;snapshot(seatIndex,micEnabled);
  }
  @override Future<void> connectLive({required String roomId,required String authToken}) async {
    liveReconnecting=true;lastError='WebSocket blocked';notifyListeners();
  }
  @override Future<void> refresh({required String roomId,required String authToken}) async {}
  @override Future<void> disconnectLive() async {}
  @override Future<void> takeSeat({required String roomId,required String authToken,required int seatIndex}) async {
    selfSeatForced=true;selfForcedSeatIndex=seatIndex;snapshot(seatIndex,false);
  }
  @override Future<void> leaveSeat({required String roomId,required String authToken}) async {snapshot(null,false);}
  @override Future<void> leave({required String roomId,required String authToken}) async {}
}
class _Permissions extends RoomPermissionBridge {
  bool granted = true;
  @override Future<bool> requestVoiceRoomPermissions() async => granted;
  @override Future<bool> hasVoiceRoomPermissions() async => granted;
}
class _Foreground extends RoomForegroundServiceBridge {
  @override Future<bool> start() async => true;
  @override Future<bool> stop() async => true;
}
late _Permissions _permissions;
const _room=RoomSummary(id:'room',title:'Test',country:'IN',online:1,ownerId:'me');
ActiveRoomSession _session(_Rtc rtc,_Presence presence,{DateTime Function()? now})=>ActiveRoomSession(
  runtime:FunctionPackRuntime(signatureVerifier:const DevelopmentSignatureVerifier()),
  realtime:RealtimeCoordinator(rtc:rtc,im:LocalImAdapter()),
  foregroundService:_Foreground(),
  permissions:_permissions,presence:presence,nowProvider:now??DateTime.now);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() { _permissions = _Permissions(); });
  testWidgets('HTTP-only seat and mic work, repeated force preserves mic, leave allows rejoin',(tester) async {
    final rtc=_Rtc(), presence=_Presence(), session=_session(rtc,presence);
    print('Recovery test: opening room');
    await session.open(_room,userId:'me',authToken:'token');
    print('Recovery test: room opened');
    expect(presence.hasConnectionProblem,false);
    await session.takeMySeat(0);
    print('Recovery test: seat confirmed');
    expect(session.controller!.mySeat,0);
    await session.toggleMyMic();
    print('Recovery test: microphone published');
    expect(rtc.publishingMic,true);
    expect(presence.members.single.micMuted,false);
    presence.selfSeatForced=true;presence.selfForcedSeatIndex=0;presence.notifyListeners();
    await tester.pump();
    expect(rtc.publishingMic,true);
    expect(session.controller!.micState,MicState.live);
    await session.leaveMySeat();
    expect(session.controller!.mySeat,isNull);
    expect(presence.members.single.seatIndex,isNull);
    expect(rtc.publishingMic,false);
    await session.takeMySeat(1);
    expect(session.controller!.mySeat,1);
    await session.close();session.dispose();presence.dispose();
  });
  testWidgets('seat moderation mute/unmute restores a live microphone',(tester) async {
    final rtc=_Rtc(), presence=_Presence(), session=_session(rtc,presence);
    await session.open(_room,userId:'me',authToken:'token');
    await session.takeMySeat(0);await session.toggleMyMic();
    presence.mutedSeats.add(0);presence.notifyListeners();await tester.pump();
    expect(rtc.publishingMic,false);
    expect(session.controller!.micState,MicState.muted);
    presence.mutedSeats.clear();presence.notifyListeners();await tester.pump();
    expect(rtc.publishingMic,true);
    expect(session.controller!.micState,MicState.live);
    await session.close();session.dispose();presence.dispose();
  });
  testWidgets('failed voice connects automatically without leaving the room',(tester) async {
    final rtc=_Rtc()..failures=1;
    final presence=_Presence(),session=_session(rtc,presence,now:tester.binding.clock.now);
    await session.open(_room,userId:'me',authToken:'token');
    expect(session.connected,false);expect(session.backendSessionActive,true);
    await tester.pump(const Duration(seconds:3));await tester.pump();
    expect(rtc.joins,2);expect(session.connected,true);
    await session.close();session.dispose();presence.dispose();
  });
  testWidgets('permission-denied room can retry voice when reopened after permission grant',(tester) async {
    _permissions.granted = false;
    final rtc=_Rtc(),presence=_Presence(),session=_session(rtc,presence);
    await session.open(_room,userId:'me',authToken:'token');
    expect(session.connected,false);expect(presence.connected,true);
    _permissions.granted = true;
    await session.open(_room,userId:'me',authToken:'token');
    expect(session.connected,true);expect(rtc.joins,1);
    await session.close();session.dispose();presence.dispose();
  });
  testWidgets('moderation during microphone creation cannot publish a late unmuted track',(tester) async{
    final rtc=_Rtc(),presence=_Presence(),session=_session(rtc,presence);
    await session.open(_room,userId:'me',authToken:'token');
    await session.takeMySeat(0);
    rtc.micGate=Completer<void>();
    final enabling=session.toggleMyMic();
    await tester.pump();
    presence.mutedSeats.add(0);presence.notifyListeners();await tester.pump();
    rtc.micGate!.complete();await enabling;await tester.pump();
    expect(rtc.publishingMic,false);expect(session.controller!.micState,MicState.muted);
    await session.close();session.dispose();presence.dispose();
  });

}
