import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room keeps seats directly under ranking and uses compact member summary', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(source, contains("Key('room-top-member-avatars')"));
    expect(source, contains("Key('room-online-member-count')"));
    expect(source, isNot(contains("Key('room-live-users')")));
    expect(source, isNot(contains("Key('room-self-mute-button')")));

    final ranking = source.indexOf("Key('reference-room-rank-pill')");
    final seats = source.indexOf("Key('tinni-seat-grid')");
    expect(ranking, greaterThanOrEqualTo(0));
    expect(seats, greaterThan(ranking));
  });
}
