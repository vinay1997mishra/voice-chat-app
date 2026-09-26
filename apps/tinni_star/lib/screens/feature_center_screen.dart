import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import 'vip_screen.dart';
import '../ui/royal_theme.dart';
import '../calls/call_service.dart';
import '../community/family_service.dart';
import '../economy/economy.dart';
import '../party/party_service.dart';
import '../relationship/cp_service.dart';
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

  Color _featureColor(String title) {
    final value = title.toLowerCase();
    if (value.contains('cp')) return FeaturePalette.cp;
    if (value.contains('vip') || value.contains('noble')) {
      return FeaturePalette.vip;
    }
    if (value.contains('gift')) return FeaturePalette.gift;
    if (value.contains('family')) return FeaturePalette.family;
    if (value.contains('wallet') || value.contains('recharge')) {
      return FeaturePalette.wallet;
    }
    if (value.contains('store') || value.contains('inventory')) {
      return FeaturePalette.store;
    }
    if (value.contains('ktv') || value.contains('music')) {
      return FeaturePalette.music;
    }
    if (value.contains('rocket') || value.contains('lucky')) {
      return FeaturePalette.rocket;
    }
    if (value.contains('backpack') || value.contains('atlas')) {
      return FeaturePalette.backpack;
    }
    if (value.contains('dynamic') || value.contains('moment')) {
      return FeaturePalette.moments;
    }
    if (value.contains('rank') || value.contains('hall')) {
      return FeaturePalette.rank;
    }
    if (value.contains('custom')) return FeaturePalette.customGift;
    return FeaturePalette.social;
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VipScreen(state: state)),
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
    ];

    return Scaffold(
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        title: const Text(
          'Feature Center',
          style: TextStyle(
            color: FeaturePalette.discover,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
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
          final color = _featureColor(item.title);
          return Container(
            decoration: BoxDecoration(
              gradient: FeaturePalette.glow(color),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: 0.72),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 14,
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: item.action,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShiningIcon(
                      icon: item.icon,
                      color: color,
                      size: 30,
                      boxSize: 50,
                      glow: 0.36,
                    ),
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
