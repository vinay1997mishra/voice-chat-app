import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/ui/stable_image_provider.dart';
import 'package:tinni_star/ui/room_dp.dart';
import 'package:tinni_star/discovery/discovery_service.dart';
import 'package:tinni_star/infra/request_budget.dart';

const pixel = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  test('unchanged DP retains its provider across rebuilt server snapshots', () {
    final cache = StableImageProviderCache();
    final first = cache.resolve(pixel);
    for (var i = 0; i < 100; i++) {
      final copied = utf8.decode(utf8.encode(pixel));
      expect(identical(first, cache.resolve(copied)), isTrue);
    }
    final network = cache.resolve('https://example.test/avatar.png');
    expect(identical(network, cache.resolve('https://example.test/avatar.png')), isTrue);
    expect(identical(network, cache.resolve('https://example.test/avatar-new.png')), isFalse);
    expect(cache.resolve('data:image/png;base64,invalid%%%'), isNull);
  });

  test('image cache evicts least-recently-used entries and bounds memory', () {
    final cache = StableImageProviderCache(maxEntries: 2, maxSourceBytes: 180);
    final first = cache.resolve('https://test/a');
    cache.resolve('https://test/b');
    cache.resolve('https://test/a');
    cache.resolve('https://test/c');
    expect(identical(first, cache.resolve('https://test/a')), isTrue);
    for (var i = 0; i < 100; i++) {
      cache.resolve('https://test/' + i.toString());
      expect(cache.length, lessThanOrEqualTo(2));
      expect(cache.sourceBytes, lessThanOrEqualTo(180));
    }
    cache.clear();
    expect(cache.length, 0);
    expect(cache.sourceBytes, 0);
  });

  testWidgets('room DP retains the same decoded image during repeated room updates', (tester) async {
    stableImages.clear();
    ImageProvider? first;
    for (var i = 0; i < 8; i++) {
      await tester.pumpWidget(MaterialApp(home: RoomDp(room: RoomSummary(
        id: '1000', title: 'Room', country: 'IN', online: i,
        photoDataUrl: utf8.decode(utf8.encode(pixel)),
      ))));
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      first ??= image.image;
      expect(identical(first, image.image), isTrue);
      expect(image.gaplessPlayback, isTrue);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    stableImages.clear();
  });

  test('automatic request budget cannot recreate the per-second polling storm', () {
    expect(const Duration(days: 1).inSeconds ~/ RequestBudget.homeRefresh.inSeconds, 720);
    expect(const Duration(days: 1).inSeconds ~/ RequestBudget.ribbonFallback.inSeconds, 1440);
    expect(RequestBudget.reconnectDelay(20).inSeconds, 120);
    expect(RequestBudget.presenceFallback(seated: false, failures: 0).inSeconds, 30);
    expect(RequestBudget.presenceFallback(seated: true, failures: 0).inSeconds, 5);
    expect(RequestBudget.presenceFallback(seated: true, failures: 10).inSeconds, 120);
  });
}
