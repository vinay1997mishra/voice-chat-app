class SeatLayoutSpec {
  const SeatLayoutSpec({
    required this.seatCount,
    required this.rows,
  });

  final int seatCount;
  final int rows;

  factory SeatLayoutSpec.forCount(int seatCount) {
    if (seatCount <= 0) {
      return const SeatLayoutSpec(seatCount: 0, rows: 1);
    }
    if (seatCount <= 10) {
      return SeatLayoutSpec(seatCount: seatCount, rows: 2);
    }
    if (seatCount <= 18) {
      return SeatLayoutSpec(seatCount: seatCount, rows: 3);
    }
    if (seatCount <= 20) {
      return SeatLayoutSpec(seatCount: seatCount, rows: 4);
    }
    return SeatLayoutSpec(seatCount: seatCount, rows: 5);
  }

  int get columns => (seatCount / rows).ceil();

  List<int> get rowLengths {
    if (seatCount == 0) return const [0];
    final base = seatCount ~/ rows;
    final remainder = seatCount % rows;
    return List<int>.generate(
      rows,
      (index) => base + (index < remainder ? 1 : 0),
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
    return diameter.clamp(30.0, 64.0).toDouble();
  }

  double preferredHeight(double seatDiameter) {
    final rowHeight = seatDiameter + (seatDiameter < 44 ? 16 : 22);
    return rowHeight * rows;
  }
}
