const supportedSeatCounts = <int>[
  8,
  10,
  12,
  15,
  18,
  20,
  24,
  28,
  30,
  35,
  36,
  42,
];

bool isSupportedSeatCount(int seatCount) =>
    supportedSeatCounts.contains(seatCount);

int rowsForSeatCount(int seatCount) {
  if (seatCount <= 10) return 2;
  if (seatCount <= 18) return 3;
  if (seatCount <= 28) return 4;
  if (seatCount <= 35) return 5;
  return 6;
}

int normalizeSeatCount(int seatCount) {
  if (isSupportedSeatCount(seatCount)) return seatCount;

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
