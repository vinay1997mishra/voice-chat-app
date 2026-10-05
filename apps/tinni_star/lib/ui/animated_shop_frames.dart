import 'package:flutter/material.dart';

class ShopFrameTheme {
  const ShopFrameTheme(this.id, this.name, this.category, this.motif, this.primary, this.accent, this.variant);
  final String id, name, category, motif;
  final Color primary, accent;
  final int variant;
}
const animatedShopFrames = <ShopFrameTheme>[
  ShopFrameTheme('shop-frame-mint-orbit', 'Mint Orbit', 'simple', '✦', Color(0xFF58E0BF), Color(0xFFC9FFF1), 0),
  ShopFrameTheme('shop-frame-sky-halo', 'Sky Halo', 'simple', '✧', Color(0xFF5CBFFF), Color(0xFFE2F7FF), 1),
  ShopFrameTheme('shop-frame-pearl-glow', 'Pearl Glow', 'simple', '●', Color(0xFFE3E1EE), Color(0xFFFFF8D8), 2),
  ShopFrameTheme('shop-frame-neon-pulse', 'Neon Pulse', 'simple', '⚡', Color(0xFFAD79FF), Color(0xFF64FFF1), 3),
  ShopFrameTheme('shop-frame-mono-arc', 'Mono Arc', 'simple', '◆', Color(0xFFAEBBCD), Color(0xFFFFFFFF), 4),
  ShopFrameTheme('shop-frame-laughing-smile', 'Laughing Smile', 'funny', '😂', Color(0xFFFFC94A), Color(0xFFFFE9A7), 5),
  ShopFrameTheme('shop-frame-cool-glasses', 'Cool Glasses', 'funny', '😎', Color(0xFF4FD8FF), Color(0xFFAEF5FF), 6),
  ShopFrameTheme('shop-frame-cheeky-monkey', 'Cheeky Monkey', 'funny', '🙈', Color(0xFFF6A16B), Color(0xFFFFE1B5), 7),
  ShopFrameTheme('shop-frame-party-panda', 'Party Panda', 'funny', '🐼', Color(0xFF9AE08C), Color(0xFFE0FFE7), 8),
  ShopFrameTheme('shop-frame-confetti-pop', 'Confetti Pop', 'funny', '🎉', Color(0xFFFF74C4), Color(0xFFFFE66D), 9),
  ShopFrameTheme('shop-frame-blush-heart', 'Blush Heart', 'love', '💗', Color(0xFFFF70AE), Color(0xFFFFCBE0), 10),
  ShopFrameTheme('shop-frame-scarlet-rose', 'Scarlet Rose', 'love', '🌹', Color(0xFFFF375F), Color(0xFFFFB9C8), 11),
  ShopFrameTheme('shop-frame-love-rings', 'Love Rings', 'love', '💍', Color(0xFFFFD47A), Color(0xFFFFF3C4), 12),
  ShopFrameTheme('shop-frame-love-wings', 'Love Wings', 'love', '🕊️', Color(0xFFC3B2FF), Color(0xFFFFD5F0), 13),
  ShopFrameTheme('shop-frame-couple-kiss', 'Couple Kiss', 'love', '💋', Color(0xFFFF4F93), Color(0xFFFFBDD6), 14),
  ShopFrameTheme('shop-frame-wedding-bells', 'Wedding Bells', 'love', '🔔', Color(0xFFFFCB62), Color(0xFFFFEDB4), 15),
  ShopFrameTheme('shop-frame-butterfly-love', 'Butterfly Love', 'love', '🦋', Color(0xFFAA7CF7), Color(0xFFFFB2DC), 16),
  ShopFrameTheme('shop-frame-forever-heart', 'Forever Heart', 'love', '💕', Color(0xFFFF6695), Color(0xFFFFDEED), 17),
  ShopFrameTheme('shop-frame-gold-crown', 'Gold Crown', 'royal', '👑', Color(0xFFFFD057), Color(0xFFFFF0B2), 18),
  ShopFrameTheme('shop-frame-diamond-ice', 'Diamond Ice', 'royal', '💎', Color(0xFF4BDCF9), Color(0xFFE1FAFF), 19),
  ShopFrameTheme('shop-frame-phoenix-fire', 'Phoenix Fire', 'royal', '🔥', Color(0xFFFF713F), Color(0xFFFFD763), 20),
  ShopFrameTheme('shop-frame-galaxy-orbit', 'Galaxy Orbit', 'royal', '🌟', Color(0xFF9984FF), Color(0xFF77E8FF), 21),
  ShopFrameTheme('shop-frame-ocean-waves', 'Ocean Waves', 'nature', '🌊', Color(0xFF42C6ED), Color(0xFFB1F5E9), 22),
  ShopFrameTheme('shop-frame-nature-bloom', 'Nature Bloom', 'nature', '🌸', Color(0xFF6EDFA1), Color(0xFFFFB4DE), 23),
  ShopFrameTheme('shop-frame-india-pride', 'India Pride', 'royal', '🇮🇳', Color(0xFFFFA458), Color(0xFF71D891), 24),
];
ShopFrameTheme? animatedShopFrame(String id) {
  for (final frame in animatedShopFrames) {
    if (frame.id == id) return frame;
  }
  return null;
}
