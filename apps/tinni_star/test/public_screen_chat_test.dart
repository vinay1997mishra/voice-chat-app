import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/room/room_control_service.dart';

void main() {
  test('Public Screen controls room typing permissions', () {
    final controls = RoomControlService();
    controls.configureForRoom('owner');
    controls.setAdmin('admin', true);
    controls.roles['user'] = RoomRole.audience;

    expect(controls.publicScreenEnabled, isFalse);
    expect(controls.canTypeInRoom('owner'), isTrue);
    expect(controls.canTypeInRoom('admin'), isTrue);
    expect(controls.canTypeInRoom('user'), isFalse);

    expect(controls.togglePublicScreen(), isTrue);
    expect(controls.canTypeInRoom('owner'), isTrue);
    expect(controls.canTypeInRoom('admin'), isTrue);
    expect(controls.canTypeInRoom('user'), isTrue);

    expect(controls.togglePublicScreen(), isFalse);
    expect(controls.canTypeInRoom('user'), isFalse);
  });
}
