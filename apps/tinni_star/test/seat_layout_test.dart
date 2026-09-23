import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/room/seat_layout.dart';

void main() {
  test('seat row count grows from 2 to 5 as capacity increases', () {
    expect(SeatLayoutSpec.forCount(8).rows, 2);
    expect(SeatLayoutSpec.forCount(10).rows, 2);

    expect(SeatLayoutSpec.forCount(12).rows, 3);
    expect(SeatLayoutSpec.forCount(15).rows, 3);
    expect(SeatLayoutSpec.forCount(18).rows, 3);

    expect(SeatLayoutSpec.forCount(20).rows, 4);

    expect(SeatLayoutSpec.forCount(30).rows, 5);
    expect(SeatLayoutSpec.forCount(40).rows, 5);
  });

  test('supported seat counts fill rows evenly', () {
    expect(SeatLayoutSpec.forCount(8).rowLengths, [4, 4]);
    expect(SeatLayoutSpec.forCount(10).rowLengths, [5, 5]);
    expect(SeatLayoutSpec.forCount(12).rowLengths, [4, 4, 4]);
    expect(SeatLayoutSpec.forCount(15).rowLengths, [5, 5, 5]);
    expect(SeatLayoutSpec.forCount(18).rowLengths, [6, 6, 6]);
    expect(SeatLayoutSpec.forCount(20).rowLengths, [5, 5, 5, 5]);
    expect(SeatLayoutSpec.forCount(30).rowLengths, [6, 6, 6, 6, 6]);
    expect(SeatLayoutSpec.forCount(40).rowLengths, [8, 8, 8, 8, 8]);
  });

  test('more seats produce smaller seat circles', () {
    const width = 390.0;
    final eight = SeatLayoutSpec.forCount(8).seatDiameter(width);
    final twenty = SeatLayoutSpec.forCount(20).seatDiameter(width);
    final forty = SeatLayoutSpec.forCount(40).seatDiameter(width);

    expect(eight, greaterThan(twenty));
    expect(twenty, greaterThan(forty));
  });
}
