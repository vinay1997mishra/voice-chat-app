import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/room/room_presence_service.dart';
class _RealHttp extends HttpOverrides {}
void main() {
  testWidgets('late HTTP snapshot from an old room cannot replace the current seat',(tester) async {
    await tester.runAsync(()=>HttpOverrides.runWithHttpOverrides(() async {
      final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);
      final held=Completer<HttpRequest>();
      Map<String,dynamic> snapshot(String label,int seat,int time)=> {
        'ok':true,'server_time':time,'mic_mode':'free','seat_count':12,
        'self_seat_forced':false,'members':[{'user_id':'me','display_name':label,
          'seat_index':seat,'mic_enabled':false,'joined_at':time,'last_seen':time}],
      };
      server.listen((request) async {
        if(request.uri.path.endsWith('/state')) {held.complete(request);return;}
        final body=jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        final room=body['room_id'];
        request.response.headers.contentType=ContentType.json;
        request.response.write(jsonEncode(snapshot(room.toString(),room=='B'?1:0,room=='B'?2000:1000)));
        await request.response.close();
      });
      final presence=RoomPresenceService(apiBase:Uri.parse('http://127.0.0.1:'+server.port.toString()));
      try {
        await presence.join(roomId:'A',authToken:'token');
        final oldRefresh=presence.refresh(roomId:'A',authToken:'token');
        final oldRequest=await held.future;
        await presence.disconnectLive();
        await presence.join(roomId:'B',authToken:'token');
        oldRequest.response.headers.contentType=ContentType.json;
        oldRequest.response.write(jsonEncode(snapshot('OLD A',2,3000)));
        await oldRequest.response.close();await oldRefresh;
        expect(presence.members.single.displayName,'B');
        expect(presence.members.single.seatIndex,1);
        expect(presence.hasConnectionProblem,false);
      } finally {presence.dispose();await server.close(force:true);}
    },_RealHttp()));
  });
}
