
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/discovery/discovery_service.dart';
void main() {
  test('active higher rocket outranks experience and expires exactly at midnight', () {
    final discovery=DiscoveryService();
    final now=DateTime.utc(2026,10,5,18,29);
    final expiry=DateTime.utc(2026,10,5,18,30).millisecondsSinceEpoch;
    discovery.rooms.addAll([
      RoomSummary(id:'rich',title:'Experience',country:'IN',online:10,roomExperience:999999999),
      RoomSummary(id:'r4',title:'Rocket 4',country:'IN',online:1,rocketLaunchLevel:4,rocketLaunchedAt:100,rocketPriorityUntil:expiry),
      RoomSummary(id:'r9',title:'Rocket 9',country:'IN',online:1,rocketLaunchLevel:9,rocketLaunchedAt:100,rocketPriorityUntil:expiry),
      RoomSummary(id:'r9-new',title:'Recent Rocket 9',country:'IN',online:1,rocketLaunchLevel:9,rocketLaunchedAt:200,rocketPriorityUntil:expiry),
    ]);
    expect(discovery.recommend(now:now).map((r)=>r.id).toList(),['r9-new','r9','r4','rich']);
    expect(discovery.recommend(now:DateTime.fromMillisecondsSinceEpoch(expiry)).first.id,'rich');
    final copied=discovery.rooms.last.copyWith(title:'Updated');
    expect(copied.rocketLaunchLevel,9);
    expect(copied.rocketPriorityUntil,expiry);
  });
}
