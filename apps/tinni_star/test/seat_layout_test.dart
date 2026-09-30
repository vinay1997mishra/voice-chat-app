import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/core/seat_policy.dart';
import 'package:tinni_star/room/seat_layout.dart';

void main() {
  test('row count follows final Tinni Star seat ranges', () {
    for (final count in [8, 9, 10]) {
      expect(SeatLayoutSpec.forCount(count).rows, 2);
    }
    for (final count in [11, 12, 13, 14, 15]) {
      expect(SeatLayoutSpec.forCount(count).rows, 3);
    }
    for (final count in [16, 17, 18, 19, 20, 21, 22, 23, 24]) {
      expect(SeatLayoutSpec.forCount(count).rows, 4);
    }
    for (final count in [25, 26, 27, 28, 29, 30]) {
      expect(SeatLayoutSpec.forCount(count).rows, 5);
    }
    for (final count in [31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42]) {
      expect(SeatLayoutSpec.forCount(count).rows, 6);
    }
  });

  test('all seat counts from 8 through 42 are selectable', () {
    for (var count = 8; count <= 42; count++) {
      expect(isSupportedSeatCount(count), true, reason: 'seat count $count');
      expect(normalizeSeatCount(count), count);
    }
  });

  test('seats are balanced top-down across the selected row count', () {
    expect(SeatLayoutSpec.forCount(8).rowLengths, [4, 4]);
    expect(SeatLayoutSpec.forCount(9).rowLengths, [5, 4]);
    expect(SeatLayoutSpec.forCount(10).rowLengths, [5, 5]);

    expect(SeatLayoutSpec.forCount(11).rowLengths, [4, 4, 3]);
    expect(SeatLayoutSpec.forCount(12).rowLengths, [4, 4, 4]);
    expect(SeatLayoutSpec.forCount(15).rowLengths, [5, 5, 5]);

    expect(SeatLayoutSpec.forCount(16).rowLengths, [4, 4, 4, 4]);
    expect(SeatLayoutSpec.forCount(17).rowLengths, [5, 4, 4, 4]);
    expect(SeatLayoutSpec.forCount(18).rowLengths, [5, 5, 4, 4]);
    expect(SeatLayoutSpec.forCount(24).rowLengths, [6, 6, 6, 6]);

    expect(SeatLayoutSpec.forCount(25).rowLengths, [5, 5, 5, 5, 5]);
    expect(SeatLayoutSpec.forCount(30).rowLengths, [6, 6, 6, 6, 6]);

    expect(SeatLayoutSpec.forCount(31).rowLengths, [6, 5, 5, 5, 5, 5]);
    expect(SeatLayoutSpec.forCount(32).rowLengths, [6, 6, 5, 5, 5, 5]);
    expect(SeatLayoutSpec.forCount(36).rowLengths, [6, 6, 6, 6, 6, 6]);
    expect(SeatLayoutSpec.forCount(37).rowLengths, [7, 6, 6, 6, 6, 6]);
    expect(SeatLayoutSpec.forCount(42).rowLengths, [7, 7, 7, 7, 7, 7]);
  });

  test('every supported layout has row difference at most one', () {
    for (var count = 8; count <= 42; count++) {
      final lengths = SeatLayoutSpec.forCount(count).rowLengths;
      expect(lengths.reduce((a, b) => a + b), count);
      final min = lengths.reduce((a, b) => a < b ? a : b);
      final max = lengths.reduce((a, b) => a > b ? a : b);
      expect(max - min, lessThanOrEqualTo(1), reason: 'seat count $count');
    }
  });

  test('more seats produce smaller circles as columns grow', () {
    const width = 390.0;
    final eight = SeatLayoutSpec.forCount(8).seatDiameter(width);
    final twentyFour = SeatLayoutSpec.forCount(24).seatDiameter(width);
    final fortyTwo = SeatLayoutSpec.forCount(42).seatDiameter(width);

    expect(eight, greaterThan(twentyFour));
    expect(twentyFour, greaterThanOrEqualTo(fortyTwo));
  });
}
