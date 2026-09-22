import '../activities/activity_service.dart';
import '../activities/rank_features.dart';
import '../auth/auth_service.dart';
import '../background/session_lifecycle.dart';
import '../billing/billing_adapter.dart';
import '../calls/call_service.dart';
import '../community/family_features.dart';
import '../community/family_service.dart';
import '../core/anamika_connector.dart';
import '../core/anamika_link_bridge.dart';
import '../core/function_pack.dart';
import '../custom_gift/custom_gift_service.dart';
import '../discovery/discovery_service.dart';
import '../dynamic/dynamic_feed.dart';
import '../economy/economy.dart';
import '../economy/gift_features.dart';
import '../effects/effect_queue.dart';
import '../games/game_service.dart';
import '../identity/identity.dart';
import '../infra/realtime.dart';
import '../media/ktv_features.dart';
import '../media/ktv_service.dart';
import '../moderation/moderation_service.dart';
import '../party/party_service.dart';
import '../profile/profile_service.dart';
import '../relationship/cp_features.dart';
import '../relationship/cp_service.dart';
import '../rewards/reward_service.dart';
import '../room/room_control_service.dart';
import '../sharing/share_service.dart';
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
        ranks = RankFeatureService(),
        effects = EffectQueue(),
        moderation = ModerationService(),
        roomControls = RoomControlService(),
        backpack = BackpackService(),
        giftAtlas = GiftAtlasService(),
        customGifts = CustomGiftService(),
        rewards = RewardService(),
        calls = CallService(),
        profile = ProfileService(),
        lifecycle = SessionLifecycle(),
        sharing = ShareService(),
        billing = LocalBillingAdapter(),
        cpFeatures = CpFeatureService(),
        parties = PartyService(),
        realtime = RealtimeCoordinator(
          rtc: LocalRtcAdapter(),
          im: LocalImAdapter(),
        ) {
    gifts = GiftService(wallet);
    inventory = InventoryService(wallet);
    familyFeatures = FamilyFeatureService(family);
    ktvFeatures = KtvFeatureService(ktv);
    auth.loginDemo();
    roomControls.setOwner('10000000');
  }

  final FunctionPackRuntime runtime;
  final AnamikaConnector connector;
  AnamikaLinkBridge? connectorBridge;

  void attachConnectorBridge(AnamikaLinkBridge bridge) {
    connectorBridge = bridge;
  }
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
  late final FamilyFeatureService familyFeatures;
  final KtvService ktv;
  late final KtvFeatureService ktvFeatures;
  final GameService games;
  final ActivityService activities;
  final RankFeatureService ranks;
  final EffectQueue effects;
  final ModerationService moderation;
  final RoomControlService roomControls;
  final BackpackService backpack;
  final GiftAtlasService giftAtlas;
  final CustomGiftService customGifts;
  final RewardService rewards;
  final CallService calls;
  final ProfileService profile;
  final SessionLifecycle lifecycle;
  final ShareService sharing;
  final BillingAdapter billing;
  final CpFeatureService cpFeatures;
  final PartyService parties;
  final RealtimeCoordinator realtime;
}
