const supportedSeatCounts = <int>[
  8, 9, 10,
  12, 13, 14, 15, 16, 17, 18,
  19, 20, 21, 22, 23, 24, 25, 26, 27, 28,
  29, 30, 31, 32, 33, 34, 35,
  36, 37, 38, 39, 40, 41, 42,
];

bool isSupportedSeatCount(int seatCount) =>
    supportedSeatCounts.contains(seatCount);

int rowsForSeatCount(int seatCount) {
  final normalized = normalizeSeatCount(seatCount);
  if (normalized <= 10) return 2;
  if (normalized <= 18) return 3;
  if (normalized <= 28) return 4;
  if (normalized <= 35) return 5;
  return 6;
}

int normalizeSeatCount(int seatCount) {
  if (isSupportedSeatCount(seatCount)) return seatCount;
  if (seatCount <= 8) return 8;
  if (seatCount >= 42) return 42;
  if (seatCount == 11) return 12;

  var best = supportedSeatCounts.first;
  var bestDistance = (seatCount - best).abs();

  for (final candidate in supportedSeatCounts.skip(1)) {
    final distance = (seatCount - candidate).abs();
    if (distance < bestDistance ||
        (distance == bestDistance && candidate > best)) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best;
}
