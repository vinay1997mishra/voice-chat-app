import 'package:flutter/material.dart';

enum GiftCategoryV08 { normal, couple, flag, ultraRide }

enum GiftAnimationTierV08 {
  none,
  light3d,
  fullscreen3d,
  premium3d,
  cinematic3d,
  ultraRide3d,
}

class GiftV08 {
  const GiftV08({
    required this.name,
    required this.emoji,
    required this.coins,
    this.category = GiftCategoryV08.normal,
    this.countryCode,
    this.isHumanRide = false,
    this.theme = 'royal',
  });

  final String name;
  final String emoji;
  final int coins;
  final GiftCategoryV08 category;
  final String? countryCode;
  final bool isHumanRide;
  final String theme;

  GiftAnimationTierV08 get animationTier {
    if (category == GiftCategoryV08.ultraRide) {
      return GiftAnimationTierV08.ultraRide3d;
    }
    if (coins < 10000) return GiftAnimationTierV08.none;
    if (coins <= 20000) return GiftAnimationTierV08.light3d;
    if (coins < 500000) return GiftAnimationTierV08.fullscreen3d;
    if (coins < 1000000) return GiftAnimationTierV08.premium3d;
    if (coins < 20000000) return GiftAnimationTierV08.cinematic3d;
    return GiftAnimationTierV08.ultraRide3d;
  }

  bool get isFullscreen3d => coins > 20000;
}

const normalGiftsV08 = <GiftV08>[
  GiftV08(name: 'Tiny Rose', emoji: '🌹', coins: 100, theme: 'rose'),
  GiftV08(name: 'Sweet Candy', emoji: '🍬', coins: 100, theme: 'candy'),
  GiftV08(name: 'Love Heart', emoji: '💜', coins: 500, theme: 'heart'),
  GiftV08(name: 'Coffee Cup', emoji: '☕', coins: 500, theme: 'coffee'),

  GiftV08(name: 'Golden Star', emoji: '⭐', coins: 10000, theme: 'star'),
  GiftV08(name: 'Teddy Bear', emoji: '🧸', coins: 10000, theme: 'teddy'),
  GiftV08(name: 'Magic Lamp', emoji: '🪔', coins: 10000, theme: 'lamp'),
  GiftV08(name: 'Crystal Flower', emoji: '🌺', coins: 12000, theme: 'crystal'),
  GiftV08(name: 'Moon Balloon', emoji: '🎈', coins: 15000, theme: 'moon'),

  GiftV08(name: 'Royal Crown', emoji: '👑', coins: 25999, theme: 'royal'),
  GiftV08(name: 'Neon Wings', emoji: '🪽', coins: 25999, theme: 'neon'),
  GiftV08(name: 'Silver Wolf', emoji: '🐺', coins: 25999, theme: 'wolf'),
  GiftV08(name: 'Magic Carpet', emoji: '🪄', coins: 25999, theme: 'magic'),
  GiftV08(name: 'Golden Eagle', emoji: '🦅', coins: 29999, theme: 'gold'),
  GiftV08(name: 'Crystal Horse', emoji: '🐎', coins: 32999, theme: 'crystal'),

  GiftV08(name: 'Royal Bike', emoji: '🏍️', coins: 79999, theme: 'speed'),
  GiftV08(name: 'Thunder Lion', emoji: '🦁', coins: 79999, theme: 'thunder'),
  GiftV08(name: 'Diamond Ring', emoji: '💍', coins: 79999, theme: 'diamond'),
  GiftV08(name: 'Golden Falcon', emoji: '🦅', coins: 79999, theme: 'gold'),
  GiftV08(name: 'Neon Panther', emoji: '🐆', coins: 89999, theme: 'neon'),
  GiftV08(name: 'Fire Stallion', emoji: '🐴', coins: 99999, theme: 'fire'),

  GiftV08(name: 'Luxury Car', emoji: '🏎️', coins: 500000, theme: 'luxury'),
  GiftV08(name: 'Royal Yacht', emoji: '🛥️', coins: 500000, theme: 'ocean'),
  GiftV08(name: 'Ice Dragon', emoji: '🐉', coins: 500000, theme: 'ice'),
  GiftV08(name: 'Diamond Throne', emoji: '👑', coins: 500000, theme: 'diamond'),
  GiftV08(name: 'Golden Chariot', emoji: '🏆', coins: 599000, theme: 'gold'),
  GiftV08(name: 'Sky Palace', emoji: '🏰', coins: 649000, theme: 'sky'),
  GiftV08(name: 'Thunder Jet', emoji: '✈️', coins: 699000, theme: 'thunder'),
  GiftV08(name: 'Royal Phoenix', emoji: '🔥', coins: 799000, theme: 'phoenix'),

  GiftV08(name: 'Supercar', emoji: '🏎️', coins: 1000000, theme: 'speed'),
  GiftV08(name: 'Fire Phoenix', emoji: '🔥', coins: 1000000, theme: 'phoenix'),
  GiftV08(name: 'Golden Castle', emoji: '🏰', coins: 1000000, theme: 'gold'),
  GiftV08(name: 'Royal Elephant', emoji: '🐘', coins: 1000000, theme: 'royal'),
  GiftV08(name: 'Diamond Crown', emoji: '👑', coins: 1000000, theme: 'diamond'),
  GiftV08(name: 'Lunar Rover', emoji: '🌕', coins: 1199000, theme: 'lunar'),
  GiftV08(name: 'Ocean Palace', emoji: '🌊', coins: 1299000, theme: 'ocean'),
  GiftV08(name: 'Thunder Dragon', emoji: '🐉', coins: 1499000, theme: 'thunder'),
  GiftV08(name: 'Royal Airship', emoji: '🛩️', coins: 1699000, theme: 'royal'),
  GiftV08(name: 'Star Cruiser', emoji: '🚀', coins: 1999000, theme: 'space'),

  GiftV08(name: 'Private Jet', emoji: '✈️', coins: 2599000, theme: 'luxury'),
  GiftV08(name: 'Dragon King', emoji: '🐉', coins: 2599000, theme: 'dragon'),
  GiftV08(name: 'Crystal Palace', emoji: '🏰', coins: 2599000, theme: 'crystal'),
  GiftV08(name: 'Golden Phoenix', emoji: '🔥', coins: 2599000, theme: 'phoenix'),
  GiftV08(name: 'Mystic Tiger', emoji: '🐯', coins: 2599000, theme: 'mystic'),
  GiftV08(name: 'Moon Castle', emoji: '🌙', coins: 2799000, theme: 'moon'),
  GiftV08(name: 'Royal Spaceship', emoji: '🚀', coins: 2999000, theme: 'space'),
  GiftV08(name: 'Celestial Lion', emoji: '🦁', coins: 3299000, theme: 'celestial'),
  GiftV08(name: 'Diamond Kingdom', emoji: '💎', coins: 3599000, theme: 'diamond'),

  GiftV08(name: 'Galaxy Dragon', emoji: '🐉', coins: 7999000, theme: 'galaxy'),
  GiftV08(name: 'Cosmic Palace', emoji: '🏰', coins: 7999000, theme: 'cosmic'),
  GiftV08(name: 'Celestial Throne', emoji: '👑', coins: 7999000, theme: 'celestial'),
  GiftV08(name: 'Royal Galaxy', emoji: '🌌', coins: 7999000, theme: 'galaxy'),
  GiftV08(name: 'Solar Phoenix', emoji: '🔥', coins: 8299000, theme: 'solar'),
  GiftV08(name: 'Star Emperor', emoji: '⭐', coins: 8599000, theme: 'star'),
  GiftV08(name: 'Cosmic Supercar', emoji: '🏎️', coins: 8999000, theme: 'cosmic'),
  GiftV08(name: 'Moon Kingdom', emoji: '🌙', coins: 9499000, theme: 'moon'),

  GiftV08(name: 'Universe Gate', emoji: '🌌', coins: 10999000, theme: 'universe'),
  GiftV08(name: 'Emperor Dragon', emoji: '🐉', coins: 10999000, theme: 'dragon'),
  GiftV08(name: 'Celestial Castle', emoji: '🏰', coins: 10999000, theme: 'celestial'),
  GiftV08(name: 'Galaxy Emperor', emoji: '👑', coins: 11999000, theme: 'galaxy'),
  GiftV08(name: 'Cosmic Whale', emoji: '🐋', coins: 12999000, theme: 'cosmic'),
  GiftV08(name: 'Infinity Palace', emoji: '🏰', coins: 13999000, theme: 'infinity'),
  GiftV08(name: 'Star Dominion', emoji: '⭐', coins: 14999000, theme: 'star'),

  GiftV08(name: 'Infinity Crown', emoji: '👑', coins: 17999000, theme: 'infinity'),
  GiftV08(name: 'Cosmic Kingdom', emoji: '🌌', coins: 18499000, theme: 'cosmic'),
  GiftV08(name: 'Emperor Galaxy', emoji: '🌠', coins: 18999000, theme: 'galaxy'),
  GiftV08(name: 'Celestial Universe', emoji: '✨', coins: 19499000, theme: 'celestial'),
  GiftV08(name: 'Ultimate Star Palace', emoji: '🏰', coins: 19999000, theme: 'star'),
  GiftV08(name: 'Eternal Dragon', emoji: '🐉', coins: 20000000, theme: 'dragon'),
  GiftV08(name: 'Universe Throne', emoji: '👑', coins: 20000000, theme: 'universe'),

  GiftV08(name: 'Eagles King', emoji: '🦅', coins: 22999000, category: GiftCategoryV08.ultraRide, isHumanRide: true, theme: 'black-eagle-storm'),
  GiftV08(name: 'Phoenix King', emoji: '🔥', coins: 25999000, category: GiftCategoryV08.ultraRide, isHumanRide: true, theme: 'fire-phoenix-sky'),
  GiftV08(name: 'Dragon King', emoji: '🐉', coins: 29999000, category: GiftCategoryV08.ultraRide, isHumanRide: true, theme: 'dragon-fire-flight'),
];

const coupleGiftsV08 = <GiftV08>[
  GiftV08(name: 'First Love', emoji: '💞', coins: 1000000, category: GiftCategoryV08.couple, theme: 'love'),
  GiftV08(name: 'Couple Hearts', emoji: '💕', coins: 1500000, category: GiftCategoryV08.couple, theme: 'love'),
  GiftV08(name: 'Forever Ring', emoji: '💍', coins: 2000000, category: GiftCategoryV08.couple, theme: 'ring'),
  GiftV08(name: 'Love Swing', emoji: '💗', coins: 2800000, category: GiftCategoryV08.couple, theme: 'swing'),
  GiftV08(name: 'Romantic Carriage', emoji: '💝', coins: 3800000, category: GiftCategoryV08.couple, theme: 'carriage'),
  GiftV08(name: 'Promise Castle', emoji: '🏰', coins: 4800000, category: GiftCategoryV08.couple, theme: 'castle'),
  GiftV08(name: 'Eternal Couple', emoji: '💖', coins: 5500000, category: GiftCategoryV08.couple, theme: 'eternal'),
  GiftV08(name: 'Moonlight Love', emoji: '🌙', coins: 6500000, category: GiftCategoryV08.couple, theme: 'moon'),
  GiftV08(name: 'Royal Wedding', emoji: '💒', coins: 7800000, category: GiftCategoryV08.couple, theme: 'wedding'),
  GiftV08(name: 'Love Paradise', emoji: '🌹', coins: 9000000, category: GiftCategoryV08.couple, theme: 'paradise'),
  GiftV08(name: 'Couple Galaxy', emoji: '🌌', coins: 11000000, category: GiftCategoryV08.couple, theme: 'galaxy'),
  GiftV08(name: 'Forever Kingdom', emoji: '👑', coins: 13000000, category: GiftCategoryV08.couple, theme: 'kingdom'),
  GiftV08(name: 'Celestial Romance', emoji: '✨', coins: 15000000, category: GiftCategoryV08.couple, theme: 'celestial'),
  GiftV08(name: 'Eternal Promise', emoji: '💎', coins: 17000000, category: GiftCategoryV08.couple, theme: 'promise'),
  GiftV08(name: 'Love Universe', emoji: '💫', coins: 20000000, category: GiftCategoryV08.couple, theme: 'universe'),
];

const _countryCodesV08 = <String>[
  'AF','AL','DZ','AD','AO','AG','AR','AM','AU','AT','AZ','BS','BH','BD','BB','BY','BE','BZ','BJ','BT','BO','BA','BW','BR','BN','BG','BF','BI','CV','KH','CM','CA','CF','TD','CL','CN','CO','KM','CG','CD','CR','CI','HR','CU','CY','CZ','DK','DJ','DM','DO','EC','EG','SV','GQ','ER','EE','SZ','ET','FJ','FI','FR','GA','GM','GE','DE','GH','GR','GD','GT','GN','GW','GY','HT','HN','HU','IS','IN','ID','IR','IQ','IE','IL','IT','JM','JP','JO','KZ','KE','KI','KP','KR','KW','KG','LA','LV','LB','LS','LR','LY','LI','LT','LU','MG','MW','MY','MV','ML','MT','MH','MR','MU','MX','FM','MD','MC','MN','ME','MA','MZ','MM','NA','NR','NP','NL','NZ','NI','NE','NG','MK','NO','OM','PK','PW','PS','PA','PG','PY','PE','PH','PL','PT','QA','RO','RU','RW','KN','LC','VC','WS','SM','ST','SA','SN','RS','SC','SL','SG','SK','SI','SB','SO','ZA','SS','ES','LK','SD','SR','SE','CH','SY','TJ','TZ','TH','TL','TG','TO','TT','TN','TR','TM','TV','UG','UA','AE','GB','US','UY','UZ','VU','VA','VE','VN','YE','ZM','ZW'
];

List<GiftV08> buildFlagGiftsV08() {
  return _countryCodesV08
      .map(
        (code) => GiftV08(
          name: '$code Flag',
          emoji: '🏳️',
          coins: 21000,
          category: GiftCategoryV08.flag,
          countryCode: code,
          theme: 'flag-wave',
        ),
      )
      .toList(growable: false);
}

final flagGiftsV08 = buildFlagGiftsV08();

List<GiftV08> get allGiftsV08 => <GiftV08>[
      ...normalGiftsV08,
      ...coupleGiftsV08,
      ...flagGiftsV08,
    ];

String formatGiftCoinsV08(int coins) {
  if (coins >= 1000000) {
    final value = coins / 1000000;
    return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 3)}M';
  }
  if (coins >= 1000) {
    final value = coins / 1000;
    return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}K';
  }
  return coins.toString();
}

IconData iconForGiftTierV08(GiftAnimationTierV08 tier) {
  switch (tier) {
    case GiftAnimationTierV08.none:
      return Icons.card_giftcard_rounded;
    case GiftAnimationTierV08.light3d:
      return Icons.auto_awesome_rounded;
    case GiftAnimationTierV08.fullscreen3d:
      return Icons.fullscreen_rounded;
    case GiftAnimationTierV08.premium3d:
      return Icons.diamond_rounded;
    case GiftAnimationTierV08.cinematic3d:
      return Icons.movie_filter_rounded;
    case GiftAnimationTierV08.ultraRide3d:
      return Icons.flight_takeoff_rounded;
  }
}
