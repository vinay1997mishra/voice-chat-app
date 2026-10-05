import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/economy/premium_gift_catalog.dart';
void main() {
  test('normal catalog has four affordable gifts and 46 premium gifts',(){
    final gifts=PremiumGiftCatalog.normal;
    expect(gifts.length,50);
    expect(gifts.where((g)=>g.price<=100000).length,4);
    expect(gifts.where((g)=>g.price>100000).length,46);
    expect(gifts.map((g)=>g.price).reduce((a,b)=>a>b?a:b),10000000);
    expect(gifts.map((g)=>g.id).toSet().length,50);
  });
  test('CP and ISO country gifts all have scenes and correct hold times',(){
    expect(PremiumGiftCatalog.cp.length,20);
    expect(PremiumGiftCatalog.countries.length,249);
    expect(PremiumGiftCatalog.countries.map((g)=>g.id).toSet().length,249);
    for(final gift in [...PremiumGiftCatalog.normal,...PremiumGiftCatalog.cp,...PremiumGiftCatalog.countries]) {
      expect(PremiumGiftCatalog.scenes.containsKey(gift.id),true);
      expect(PremiumGiftCatalog.isFullScreen(gift.id),gift.price>=200000);
      expect(PremiumGiftCatalog.holdSeconds(gift.id),gift.id.startsWith('flag-')?2:gift.price>=5000000?8:gift.price>=1000000?7:gift.price>=200000?6:5);
    }
  });
}
