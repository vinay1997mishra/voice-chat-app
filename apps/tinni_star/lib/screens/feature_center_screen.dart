import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../calls/call_service.dart';
import '../community/family_service.dart';
import '../economy/economy.dart';
import '../effects/effect_queue.dart';
import '../games/game_service.dart';
import '../party/party_service.dart';
import '../relationship/cp_service.dart';
import '../rewards/reward_service.dart';
import '../sharing/share_service.dart';

class FeatureCenterScreen extends StatefulWidget {
  const FeatureCenterScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<FeatureCenterScreen> createState() => _FeatureCenterScreenState();
}

class _FeatureCenterScreenState extends State<FeatureCenterScreen> {
  void showText(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final modules = <_FeatureAction>[
      _FeatureAction(
        'Wallet / Recharge',
        Icons.account_balance_wallet_rounded,
        () async {
          final products = await state.billing.products();
          showText('Billing adapter ready: ' + products.length.toString() + ' products');
        },
      ),
      _FeatureAction(
        'Store / Inventory',
        Icons.storefront_rounded,
        () {
          const item = StoreItem(
            id: 'vehicle-star',
            name: 'Star Vehicle',
            price: 5000,
            type: 'vehicle',
          );
          final bought = state.inventory.purchase(item);
          if (bought) state.identity.addVehicle(item.id);
          showText(bought ? 'Star Vehicle purchased.' : 'Already owned.');
        },
      ),
      _FeatureAction(
        'VIP / Noble',
        Icons.workspace_premium_rounded,
        () {
          state.identity.gainVipExperience(1200);
          state.identity.upgradeNoble();
          state.identity.addMedal('founder');
          showText(
            'VIP' +
                state.identity.vip.level.toString() +
                ' • Noble ' +
                state.identity.noble.level.toString(),
          );
        },
      ),
      _FeatureAction(
        'CP / Courting',
        Icons.favorite_rounded,
        () {
          if (state.cp.relationship == null &&
              state.cp.state != CourtingState.pending) {
            state.cp.request(from: '10000000', to: '20000000');
            state.cp.respond(accept: true);
            state.cp.addIntimacy(1250);
            state.cp.selectRing('star-ring');
            state.cp.addMemory('First Tinni Star memory');
          }
          state.cpFeatures.startHeartbeat();
          state.cpFeatures.chooseHeartbeat('star');
          state.cpFeatures.resolveHeartbeat(matched: true);
          showText(
            'CP level ' +
                (state.cp.relationship?.level ?? 0).toString() +
                ' • heartbeat matched',
          );
        },
      ),
      _FeatureAction(
        'CP Disconnect Flow',
        Icons.heart_broken_rounded,
        () {
          state.cpFeatures.requestDisconnect('10000000');
          state.cpFeatures.respondDisconnect(accept: false);
          showText('Disconnect request refused safely.');
        },
      ),
      _FeatureAction(
        'Family',
        Icons.groups_rounded,
        () {
          if (!state.family.exists) {
            state.family.create(
              familyName: 'Tinni Family',
              familyTag: 'TS',
              head: const FamilyMember(
                userId: '10000000',
                name: 'Tinni User',
                role: FamilyRole.head,
              ),
            );
            state.family.join(
              const FamilyMember(
                userId: '20000000',
                name: 'Aisha',
                role: FamilyRole.member,
              ),
            );
            state.family.appoint('20000000', FamilyRole.assistant);
          }
          state.familyFeatures.signIn('10000000');
          state.familyFeatures.recordGiftContribution(1200);
          final reward = state.familyFeatures.draw(2);
          showText((state.family.name ?? 'Family') + ' • lottery ' + reward.label);
        },
      ),
      _FeatureAction(
        'KTV / Music',
        Icons.music_note_rounded,
        () {
          state.ktv.addToQueue(state.ktv.library.first, '10000000');
          final entry = state.ktv.startNext();
          state.ktvFeatures.reportSong(
            songId: entry?.song.id ?? 'none',
            kind: 'demo',
            details: 'KTV feedback pipeline ready',
          );
          showText('Now singing: ' + (entry?.song.title ?? 'none'));
        },
      ),
      _FeatureAction(
        'Games',
        Icons.casino_rounded,
        () {
          if (state.games.active == null) {
            state.games.start(
              GameType.blackjack,
              const ['10000000', '20000000'],
            );
          }
          final result = state.games.finish();
          state.wallet.creditCoins(result.rewardCoins, 'Game reward');
          showText('Blackjack reward +' + result.rewardCoins.toString());
        },
      ),
      _FeatureAction(
        'Lucky Bag / Rocket',
        Icons.rocket_launch_rounded,
        () {
          if (!state.rewards.luckyBags.containsKey('demo')) {
            state.rewards.createLuckyBag(
              id: 'demo',
              senderId: '10000000',
              totalSlots: 10,
              reward: const LuckyBagReward(
                kind: LuckyBagRewardKind.coins,
                label: 'Lucky reward',
                amount: 100,
              ),
            );
          }
          final reward = state.rewards.grab('demo', '10000000');
          if (reward != null) {
            state.wallet.creditCoins(reward.amount, reward.label);
          }
          state.rewards.launchRocket(1000);
          state.rewards.addRebate(50);
          showText(
            'Rocket Lv.' +
                state.rewards.rocket.level.toString() +
                ' • rebate ' +
                state.rewards.rebateCoins.toString(),
          );
        },
      ),
      _FeatureAction(
        'Gift Backpack / Atlas',
        Icons.backpack_rounded,
        () {
          state.backpack.add('rose', 5);
          state.backpack.consume('rose', 1);
          state.giftAtlas.recordObtained('rose');
          showText(
            'Rose backpack ' +
                (state.backpack.items['rose']?.quantity ?? 0).toString() +
                ' • atlas lit',
          );
        },
      ),
      _FeatureAction(
        'Dynamic / Moments',
        Icons.auto_awesome_motion_rounded,
        () {
          final post = state.dynamics.submit(
            authorId: '10000000',
            text: 'Hello from Tinni Star',
            topic: 'Tinni',
          );
          state.dynamics.moderate(post.id, approve: true);
          state.dynamics.like(post.id);
          state.dynamics.comment(post.id, 'Welcome!');
          showText('Dynamic published, liked and commented.');
        },
      ),
      _FeatureAction(
        'Custom Gift Creator',
        Icons.draw_rounded,
        () {
          final id =
              'gift-' + (state.customGifts.gifts.length + 1).toString();
          state.customGifts.create(
            id: id,
            name: 'Custom Star',
            assetType: 'video',
            assetPath: 'local-demo.mp4',
          );
          state.customGifts.submit(id);
          state.customGifts.approve(id);
          state.customGifts.list(id);
          showText('Custom gift approved/listed.');
        },
      ),
      _FeatureAction(
        'Ranks / Hall',
        Icons.leaderboard_rounded,
        () {
          state.activities.addCharm('10000000', 2000);
          state.activities.addGiftScore('10000000', 3000);
          state.ranks.addCp('cp-1', 1500);
          state.ranks.addFamily('tinni-family', 2200);
          state.ranks.addRoom('1524843', 5000);
          state.ranks.addSignIn('10000000', 30);
          state.ranks.promoteHallOfFame('10000000');
          showText(
            'Room rank ' +
                state.ranks.rank(state.ranks.room).first.score.toString(),
          );
        },
      ),
      _FeatureAction(
        'Birthday / Party',
        Icons.cake_rounded,
        () {
          state.activities.join('birthday', '10000000');
          final party = state.parties.parties['birthday-demo'] ??
              state.parties.create(
                id: 'birthday-demo',
                type: PartyType.birthday,
                ownerId: '10000000',
                title: 'Tinni Birthday',
              );
          party.join('10000000');
          party.start();
          state.parties.setDressUp(party.id, 'birthday-premium');
          showText('Birthday party active with premium dress-up.');
        },
      ),
      _FeatureAction(
        'Calls',
        Icons.call_rounded,
        () {
          state.social.addFriend('20000000');
          state.calls.initiate(
            callerId: '10000000',
            receiverId: '20000000',
            media: CallMedia.voice,
            isFriend: true,
          );
          state.calls.accept();
          showText('Friend voice call connected.');
        },
      ),
      _FeatureAction(
        'Room Controls',
        Icons.meeting_room_rounded,
        () {
          state.roomControls.invite('20000000');
          state.roomControls.applyForMic('20000000', 2);
          state.roomControls.approveMic('20000000');
          state.roomControls.setAdmin('20000000', true);
          state.roomControls.setHostSeat(0);
          state.roomControls.setBossSeat(1);
          showText('Invite, mic, admin, host/boss seat controls updated.');
        },
      ),
      _FeatureAction(
        'Moderation',
        Icons.shield_rounded,
        () {
          state.moderation.addAdmin('20000000');
          state.moderation.banMic('30000000');
          state.roomControls.banMic('30000000');
          state.roomControls.blacklist('40000000');
          showText('Admin, mic-ban and room blacklist updated.');
        },
      ),
      _FeatureAction(
        'Effects Queue',
        Icons.animation_rounded,
        () {
          state.effects.enqueue(
            const EffectRequest(
              id: 'vip-entry-demo',
              kind: EffectKind.vip,
              asset: 'vip12-entry',
              priority: 100,
            ),
          );
          final effect = state.effects.takeNext();
          showText('Playing effect: ' + (effect?.asset ?? 'none'));
        },
      ),
      _FeatureAction(
        'Sharing',
        Icons.share_rounded,
        () {
          final value = state.sharing.prepare(
            ShareTarget.whatsapp,
            const SharePayload(
              title: 'Join Tinni Star room',
              link: 'https://tinni.star/room/1524843',
            ),
          );
          showText(value);
        },
      ),
      _FeatureAction(
        'Anamika Diagnostics',
        Icons.health_and_safety_rounded,
        () {
          final data = state.connector.diagnosticSnapshot();
          showText(
            'Schema ' +
                data['schema'].toString() +
                ' • seats ' +
                data['seatCount'].toString() +
                ' • pack ' +
                (data['activePackVersion'] ?? 'base').toString(),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Feature Center')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: modules.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.12,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (_, index) {
          final item = modules[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: item.action,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 34),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeatureAction {
  const _FeatureAction(this.title, this.icon, this.action);
  final String title;
  final IconData icon;
  final VoidCallback action;
}
