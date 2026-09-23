import '../core/seat_policy.dart';

class SeatLayoutSpec {
  const SeatLayoutSpec({
    required this.seatCount,
    required this.rows,
  });

  final int seatCount;
  final int rows;

  factory SeatLayoutSpec.forCount(int seatCount) {
    final normalized = normalizeSeatCount(seatCount);
    return SeatLayoutSpec(
      seatCount: normalized,
      rows: rowsForSeatCount(normalized),
    );
  }

  int get columns => (seatCount / rows).ceil();

  List<int> get rowLengths {
    final base = seatCount ~/ rows;
    final extra = seatCount % rows;
    return List<int>.generate(
      rows,
      (row) => base + (row < extra ? 1 : 0),
      growable: false,
    );
  }

  (int, int) rangeForRow(int row) {
    if (row < 0 || row >= rows) return (0, 0);
    final lengths = rowLengths;
    var start = 0;
    for (var index = 0; index < row; index++) {
      start += lengths[index];
    }
    return (start, start + lengths[row]);
  }

  double seatDiameter(double availableWidth) {
    if (columns <= 0) return 30;
    final diameter = (availableWidth / columns) * 0.68;
    return diameter.clamp(28.0, 64.0).toDouble();
  }

  double preferredHeight(double seatDiameter) {
    final rowHeight = seatDiameter + (seatDiameter < 44 ? 16 : 22);
    return rowHeight * rows;
  }
}
