import '../activities/activity_service.dart';
import '../auth/auth_service.dart';
import '../community/family_service.dart';
import '../core/anamika_connector.dart';
import '../core/function_pack.dart';
import '../custom_gift/custom_gift_service.dart';
import '../discovery/discovery_service.dart';
import '../dynamic/dynamic_feed.dart';
import '../economy/economy.dart';
import '../effects/effect_queue.dart';
import '../games/game_service.dart';
import '../identity/identity.dart';
import '../infra/realtime.dart';
import '../media/ktv_service.dart';
import '../moderation/moderation_service.dart';
import '../relationship/cp_service.dart';
import '../social/social.dart';

class TinniState {
  TinniState({
    required this.runtime,
  })  : connector = AnamikaConnector(runtime: runtime),
        wallet = WalletService(),
        auth = AuthService(),
        discovery = DiscoveryService(),
        social = SocialService(),
        dynamics = DynamicFeedService(),
        identity = IdentityService(),
        cp = CpService(),
        family = FamilyService(),
        ktv = KtvService(),
        games = GameService(),
        activities = ActivityService(),
        effects = EffectQueue(),
        moderation = ModerationService(),
        customGifts = CustomGiftService(),
        realtime = RealtimeCoordinator(
          rtc: LocalRtcAdapter(),
          im: LocalImAdapter(),
        ) {
    gifts = GiftService(wallet);
    inventory = InventoryService(wallet);
    auth.loginDemo();
  }

  final FunctionPackRuntime runtime;
  final AnamikaConnector connector;
  final WalletService wallet;
  late final GiftService gifts;
  late final InventoryService inventory;
  final AuthService auth;
  final DiscoveryService discovery;
  final SocialService social;
  final DynamicFeedService dynamics;
  final IdentityService identity;
  final CpService cp;
  final FamilyService family;
  final KtvService ktv;
  final GameService games;
  final ActivityService activities;
  final EffectQueue effects;
  final ModerationService moderation;
  final CustomGiftService customGifts;
  final RealtimeCoordinator realtime;
}
