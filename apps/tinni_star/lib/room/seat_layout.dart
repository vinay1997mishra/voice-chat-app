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
    if (rows <= 2) {
      final base = seatCount ~/ rows;
      final extra = seatCount % rows;
      return List<int>.generate(
        rows,
        (row) => base + (row < extra ? 1 : 0),
        growable: false,
      );
    }

    final upperRowCount = rows - 2;
    final seatsPerUpperRow = (seatCount / rows).ceil();
    final remaining = seatCount - (upperRowCount * seatsPerUpperRow);
    final penultimateRow = (remaining / 2).ceil();
    final lastRow = remaining ~/ 2;

    return <int>[
      ...List<int>.filled(upperRowCount, seatsPerUpperRow),
      penultimateRow,
      lastRow,
    ];
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
    final diameter = (availableWidth / columns) * 0.76;
    return diameter.clamp(30.0, 68.0).toDouble();
  }

  double preferredHeight(double seatDiameter) {
    // Keep enough vertical room for the reference seat stack:
    // avatar/lock + No.X/name + heart pill + optional tags/medals.
    final rowLabelSpace = seatDiameter < 48 ? 28.0 : 38.0;
    final rowHeight = seatDiameter + rowLabelSpace;
    return rowHeight * rows;
  }
}
