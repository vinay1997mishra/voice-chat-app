import 'package:flutter/foundation.dart';

import '../activities/activity_service.dart';
import '../activities/rank_features.dart';
import '../auth/auth_service.dart';
import '../auth/auth_persistence.dart';
import '../background/session_lifecycle.dart';
import '../background/room_foreground_service.dart';
import '../background/room_permission_bridge.dart';
import '../calls/call_service.dart';
import '../community/family_features.dart';
import '../community/family_service.dart';
import '../core/anamika_connector.dart';
import '../core/anamika_link_bridge.dart';
import '../core/function_pack.dart';
import '../custom_gift/custom_gift_service.dart';
import '../custom_gift/custom_gift_validation.dart';
import '../discovery/discovery_service.dart';
import '../dynamic/dynamic_feed.dart';
import '../economy/economy.dart';
import '../economy/entitlement_service.dart';
import '../economy/gift_features.dart';
import '../effects/effect_queue.dart';
import '../effects/effect_players.dart';
import '../games/game_service.dart';
import '../games/fruit_jackpot_game.dart';
import '../games/fruit_jackpot_remote.dart';
import '../games/fruit_party_remote.dart';
import '../identity/identity.dart';
import '../infra/realtime.dart';
import '../infra/app_backend_service.dart';
import '../infra/livekit_rtc.dart';
import '../infra/platform_services.dart';
import '../i18n/tinni_localization.dart';
import '../media/ktv_features.dart';
import '../media/ktv_service.dart';
import '../moderation/moderation_service.dart';
import '../party/party_service.dart';
import '../profile/profile_service.dart';
import '../relationship/cp_features.dart';
import '../relationship/cp_service.dart';
import '../rewards/reward_service.dart';
import '../room/room_control_service.dart';
import '../room/active_room_session.dart';
import '../room/room_presence_service.dart';
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
        customGiftValidator = const CustomGiftValidator(),
        entitlements = EntitlementService(),
        effectRouter = EffectRouter(),
        rewards = RewardService(),
        calls = CallService(),
        profile = ProfileService(),
        lifecycle = SessionLifecycle(),
        roomForegroundService = const RoomForegroundServiceBridge(),
        roomPermissions = const RoomPermissionBridge(),
        sharing = ShareService(),
        cpFeatures = CpFeatureService(),
        parties = PartyService(),
        push = LocalPushAdapter(),
        backend = AppBackendService(),
        realtime = RealtimeCoordinator(
          rtc: LiveKitRtcAdapter(),
          im: BackendImAdapter(),
        ),
        roomPresence = RoomPresenceService() {
    analytics = BackendAnalyticsAdapter(
      tokenProvider: () => auth.current?.authToken,
    );
    crashReporter = BackendCrashReporter(
      tokenProvider: () => auth.current?.authToken,
    );
    remoteConfig = BackendRemoteConfigAdapter();
    gifts = GiftService(wallet);
    inventory = InventoryService(wallet);
    familyFeatures = FamilyFeatureService(family);
    ktvFeatures = KtvFeatureService(ktv);
    fruitJackpot = FruitJackpotGameService(wallet: wallet, autoStart: false);
    fruitJackpotRemote = FruitJackpotRemoteService();
    fruitPartyRemote = FruitPartyRemoteService();
    roomSession = ActiveRoomSession(
      runtime: runtime,
      realtime: realtime,
      foregroundService: roomForegroundService,
      permissions: roomPermissions,
      presence: roomPresence,
      familyTagProvider: () {
        final userId = auth.current?.userId;
        if (userId == null || !family.exists || !family.isMember(userId)) {
          return null;
        }
        return family.tag ?? family.name;
      },
      hostTagProvider: () {
        final userId = auth.current?.userId;
        if (userId == null) return null;
        switch (roomControls.roles[userId]) {
          case RoomRole.owner:
            return 'Owner';
          case RoomRole.admin:
            return 'Admin';
          case RoomRole.host:
            return 'Host';
          default:
            return null;
        }
      },
      agencyNameProvider: () {
        final userId = auth.current?.userId;
        if (userId == null) return null;
        return roomControls.agencyNameFor(userId);
      },
      equippedFrameIdProvider: () => inventory.equippedFrameId,
      equippedEntryIdProvider: () => inventory.equipped('entry'),
      equippedProfileCardIdProvider: () => inventory.equipped('profile_card'),
      onRoomClosed: () => ktv.stopRoomPlayback(),
      onSeatForcedDown: () async {
        final userId = auth.current?.userId ?? '';
        await ktv.stopForSeatDown(userId);
      },
    );
  }

  final ValueNotifier<String> languagePreference =
      ValueNotifier<String>('English');

  bool _refreshingAccountIdentity = false;
  DateTime? _lastAccountIdentityRefreshAt;

  Future<bool> refreshAuthenticatedAccount({bool force = false}) async {
    final account = auth.current;
    if (account == null || _refreshingAccountIdentity) return false;
    final last = _lastAccountIdentityRefreshAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 10)) {
      return false;
    }

    _refreshingAccountIdentity = true;
    try {
      final user = await backend.currentUser(account.authToken);
      final serverUserId = user['user_id']?.toString().trim() ?? '';
      if (serverUserId.isEmpty) return false;

      int readInt(dynamic value, int fallback) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? fallback;
      }

      final refreshed = TinniAccount(
        userId: serverUserId,
        email: user['email']?.toString() ?? account.email,
        displayName: user['display_name']?.toString() ?? account.displayName,
        age: readInt(user['age'], account.age),
        birthday: user['birthday']?.toString() ?? account.birthday,
        signature: user['signature']?.toString() ?? account.signature,
        countryCode: user['country_code']?.toString() ?? account.countryCode,
        countryName: user['country_name']?.toString() ?? account.countryName,
        flagEmoji: user['flag_emoji']?.toString() ?? account.flagEmoji,
        gender: user['gender']?.toString() ?? account.gender,
        avatarDataUrl:
            user['avatar_data_url']?.toString() ?? account.avatarDataUrl,
        providers: account.providers,
        authToken: account.authToken,
      );
      auth.setAuthenticatedAccount(refreshed);
      await authPersistence?.save(refreshed);
      _lastAccountIdentityRefreshAt = DateTime.now();
      return refreshed.userId != account.userId;
    } catch (_) {
      return false;
    } finally {
      _refreshingAccountIdentity = false;
    }
  }

  void setLanguagePreference(String value) {
    final normalized = value.trim();
    languagePreference.value =
        tinniIsSupportedLanguage(normalized) ? normalized : 'English';
  }

  Future<void> refreshAccountPreferences() async {
    await refreshAuthenticatedAccount(force: true);
    final account = auth.current;
    if (account == null) return;
    try {
      final preferences = await backend.accountPreferences(account.authToken);
      setLanguagePreference(
        preferences['language']?.toString() ?? 'English',
      );
    } catch (_) {}
  }

  final FunctionPackRuntime runtime;
  final AnamikaConnector connector;
  AnamikaLinkBridge? connectorBridge;

  void attachConnectorBridge(AnamikaLinkBridge bridge) {
    connectorBridge = bridge;
  }

  Map<String, Object?> remoteConfigValues = <String, Object?>{};

  Future<void> refreshRemoteConfig() async {
    try {
      remoteConfigValues = Map<String, Object?>.from(
        await remoteConfig.fetch(),
      );
    } catch (error, stackTrace) {
      crashReporter.record(error, stackTrace);
    }
  }

  bool remoteFlag(String key, {bool fallback = true}) {
    final value = remoteConfigValues[key];
    return value is bool ? value : fallback;
  }
  final WalletService wallet;
  late final GiftService gifts;
  late final InventoryService inventory;
  final AuthService auth;
  AuthPersistence? authPersistence;

  void attachAuthPersistence(AuthPersistence persistence) {
    authPersistence = persistence;
  }
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
  late final FruitJackpotGameService fruitJackpot;
  late final FruitJackpotRemoteService fruitJackpotRemote;
  late final FruitPartyRemoteService fruitPartyRemote;
  final ActivityService activities;
  final RankFeatureService ranks;
  final EffectQueue effects;
  final ModerationService moderation;
  final RoomControlService roomControls;
  late final ActiveRoomSession roomSession;
  final BackpackService backpack;
  final GiftAtlasService giftAtlas;
  final CustomGiftService customGifts;
  final CustomGiftValidator customGiftValidator;
  final EntitlementService entitlements;
  final EffectRouter effectRouter;
  final RewardService rewards;
  final CallService calls;
  final ProfileService profile;
  final SessionLifecycle lifecycle;
  final RoomForegroundServiceBridge roomForegroundService;
  final RoomPermissionBridge roomPermissions;
  final ShareService sharing;
  final CpFeatureService cpFeatures;
  final PartyService parties;
  final PushAdapter push;
  late final AnalyticsAdapter analytics;
  late final CrashReporter crashReporter;
  late final RemoteConfigAdapter remoteConfig;
  final AppBackendService backend;
  final RealtimeCoordinator realtime;
  final RoomPresenceService roomPresence;
}
