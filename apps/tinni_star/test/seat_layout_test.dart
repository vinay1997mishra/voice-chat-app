import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/core/seat_policy.dart';
import 'package:tinni_star/room/seat_layout.dart';

void main() {
  test('row count follows requested seat ranges', () {
    for (final count in [8, 9, 10]) {
      expect(SeatLayoutSpec.forCount(count).rows, 2);
    }
    for (final count in [12, 13, 15, 18]) {
      expect(SeatLayoutSpec.forCount(count).rows, 3);
    }
    for (final count in [19, 20, 24, 28]) {
      expect(SeatLayoutSpec.forCount(count).rows, 4);
    }
    for (final count in [29, 30, 33, 35]) {
      expect(SeatLayoutSpec.forCount(count).rows, 5);
    }
    for (final count in [36, 37, 40, 42]) {
      expect(SeatLayoutSpec.forCount(count).rows, 6);
    }
  });

  test('seats are balanced across rows with at most one seat difference', () {
    expect(SeatLayoutSpec.forCount(8).rowLengths, [4, 4]);
    expect(SeatLayoutSpec.forCount(9).rowLengths, [5, 4]);
    expect(SeatLayoutSpec.forCount(10).rowLengths, [5, 5]);

    expect(SeatLayoutSpec.forCount(12).rowLengths, [4, 4, 4]);
    expect(SeatLayoutSpec.forCount(13).rowLengths, [5, 4, 4]);
    expect(SeatLayoutSpec.forCount(18).rowLengths, [6, 6, 6]);

    expect(SeatLayoutSpec.forCount(19).rowLengths, [5, 5, 5, 4]);
    expect(SeatLayoutSpec.forCount(28).rowLengths, [7, 7, 7, 7]);

    expect(SeatLayoutSpec.forCount(29).rowLengths, [6, 6, 6, 6, 5]);
    expect(SeatLayoutSpec.forCount(35).rowLengths, [7, 7, 7, 7, 7]);

    expect(SeatLayoutSpec.forCount(36).rowLengths, [6, 6, 6, 6, 6, 6]);
    expect(SeatLayoutSpec.forCount(42).rowLengths, [7, 7, 7, 7, 7, 7]);
  });

  test('11 seats normalizes to 12 because it is not a selectable layout', () {
    expect(isSupportedSeatCount(11), false);
    expect(normalizeSeatCount(11), 12);
    expect(SeatLayoutSpec.forCount(11).seatCount, 12);
    expect(SeatLayoutSpec.forCount(11).rows, 3);
  });

  test('more seats produce smaller circles as columns grow', () {
    const width = 390.0;
    final eight = SeatLayoutSpec.forCount(8).seatDiameter(width);
    final twentyEight = SeatLayoutSpec.forCount(28).seatDiameter(width);
    final fortyTwo = SeatLayoutSpec.forCount(42).seatDiameter(width);

    expect(eight, greaterThan(twentyEight));
    expect(twentyEight, greaterThanOrEqualTo(fortyTwo));
  });
}
