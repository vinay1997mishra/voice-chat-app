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

  int get columns => seatCount ~/ rows;

  List<int> get rowLengths =>
      List<int>.filled(rows, columns, growable: false);

  (int, int) rangeForRow(int row) {
    if (row < 0 || row >= rows) return (0, 0);
    final start = row * columns;
    return (start, start + columns);
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
