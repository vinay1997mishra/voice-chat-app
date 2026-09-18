import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/gift_catalog_v08.dart';

void main() {
  group('v0.8 gift catalog', () {
    test('contains requested catalog sizes', () {
      expect(normalGiftsV08.length, 73);
      expect(coupleGiftsV08.length, 15);
      expect(flagGiftsV08.length, 195);
      expect(allGiftsV08.length, 283);
    });

    test('animation rules scale with coin price', () {
      expect(
        normalGiftsV08.firstWhere((g) => g.coins == 100).animationTier,
        GiftAnimationTierV08.none,
      );
      expect(
        normalGiftsV08.firstWhere((g) => g.coins == 10000).animationTier,
        GiftAnimationTierV08.light3d,
      );
      expect(
        flagGiftsV08.first.animationTier,
        GiftAnimationTierV08.fullscreen3d,
      );
      expect(flagGiftsV08.first.isFullscreen3d, isTrue);
    });

    test('ultra ride kings are over 20M with human rider', () {
      for (final name in ['Eagles King', 'Phoenix King', 'Dragon King']) {
        final gift = normalGiftsV08.firstWhere((g) => g.name == name);
        expect(gift.coins, greaterThan(20000000));
        expect(gift.isHumanRide, isTrue);
        expect(gift.animationTier, GiftAnimationTierV08.ultraRide3d);
      }
      expect(
        normalGiftsV08.firstWhere((g) => g.name == 'Eagles King').theme,
        'black-eagle-storm',
      );
    });
  });
}
