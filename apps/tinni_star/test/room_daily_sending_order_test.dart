import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/discovery/discovery_service.dart';

void main() {
 test('daily sending outranks occupancy EXP; equal sending uses current users',() {
  final d=DiscoveryService();
  d.rooms.addAll([
   RoomSummary(id:'crowded',title:'Crowded',country:'IN',online:50,activeUserExp:100000,roomExperience:100000),
   RoomSummary(id:'sender',title:'Sender',country:'IN',online:1,sendingExp:1,activeUserExp:2000,roomExperience:2001),
  ]);
  expect(d.recommend().first.id,'sender');
  d.rooms.clear();
  d.rooms.addAll([
   RoomSummary(id:'one',title:'One',country:'IN',online:1,sendingExp:1000,roomExperience:3000),
   RoomSummary(id:'two',title:'Two',country:'IN',online:2,sendingExp:1000,roomExperience:5000),
  ]);
  expect(d.recommend().first.id,'two');
  d.rooms[1]=d.rooms[1].copyWith(online:1,activeUserExp:2000,roomExperience:3000);
  expect(d.recommend().map((r)=>r.online),everyElement(1));
 });
}
