import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/community/family_features.dart';
import 'package:tinni_star/community/family_service.dart';
import 'package:tinni_star/economy/economy.dart';
import 'package:tinni_star/economy/gift_features.dart';
import 'package:tinni_star/media/ktv_features.dart';
import 'package:tinni_star/media/ktv_service.dart';
import 'package:tinni_star/relationship/cp_features.dart';
import 'package:tinni_star/room/room_control_service.dart';

void main() {
  test('room control covers mic approval, ban and room blacklist', () {
    final room = RoomControlService()..setOwner('owner');
    room.applyForMic('u1', 3);
    expect(room.approveMic('u1'), true);
    expect(room.canSpeak('u1'), true);
    room.banMic('u1');
    expect(room.canSpeak('u1'), false);
    room.blacklist('u1');
    expect(room.canJoin('u1'), false);
  });

  test('backpack and gift atlas track inventory and collection', () {
    final backpack = BackpackService()..add('rose', 5);
    expect(backpack.consume('rose', 2), true);
    expect(backpack.items['rose']!.quantity, 3);

    final atlas = GiftAtlasService()..recordObtained('rose', count: 2);
    expect(atlas.entries().first.obtainedCount, 2);

    const gift = GiftDefinition(
      id: 'rose',
      name: 'Rose',
      price: 100,
      effectKind: 'svga',
    );
    final combo = GiftComboSession(gift: gift, receiverId: 'u2')
      ..add(50, maxCombo: 100);
    expect(combo.count, 50);
  });

  test('family detailed features support daily sign in without retired features', () {
    final family = FamilyService()
      ..create(
        familyName: 'Tinni',
        familyTag: 'TS',
        head: const FamilyMember(
          userId: '1',
          name: 'Head',
          role: FamilyRole.head,
        ),
      );
    final features = FamilyFeatureService(family);
    expect(features.signIn('1'), true);
    expect(features.signIn('1'), false);
    expect(features.tasks.keys, contains('signin'));
    expect(features.tasks.keys, isNot(contains('gifts')));
  });

  test('family received coins award EXP only and count once', () {
    final family = FamilyService()
      ..create(
        familyName: 'Tinni',
        familyTag: 'TS',
        head: const FamilyMember(
          userId: '1',
          name: 'Head',
          role: FamilyRole.head,
        ),
      );
    expect(
      family.recordCoinsReceived(
        transactionId: 'rx-5000000',
        receiverUserId: '1',
        coins: 5000000,
      ),
      true,
    );
    expect(family.experience, 5000000);
    expect(family.walletCoins, 0);
    expect(
      family.recordCoinsReceived(
        transactionId: 'rx-5000000',
        receiverUserId: '1',
        coins: 5000000,
      ),
      false,
    );
    expect(family.experience, 5000000);
    expect(family.walletCoins, 0);
  });

  test('family admin permissions stay scoped to own family roles', () {
    final family = FamilyService()
      ..create(
        familyName: 'Tinni',
        familyTag: 'TS',
        head: const FamilyMember(
          userId: 'leader',
          name: 'Leader',
          role: FamilyRole.head,
        ),
      )
      ..join(const FamilyMember(
        userId: 'admin',
        name: 'Admin',
        role: FamilyRole.member,
      ))
      ..join(const FamilyMember(
        userId: 'member',
        name: 'Member',
        role: FamilyRole.member,
      ))
      ..join(const FamilyMember(
        userId: 'admin2',
        name: 'Admin Two',
        role: FamilyRole.member,
      ));
    family.appoint('admin', FamilyRole.deputyHead);
    family.appoint('admin2', FamilyRole.deputyHead);

    expect(
      family.requestToJoin(
        const FamilyJoinRequest(userId: 'new', name: 'New Member'),
      ),
      true,
    );
    expect(
      family.approveJoinRequest(actorUserId: 'admin', userId: 'new'),
      true,
    );
    expect(family.isMember('new'), true);

    expect(
      family.requestToJoin(
        const FamilyJoinRequest(userId: 'reject', name: 'Rejected Member'),
      ),
      true,
    );
    expect(
      family.rejectJoinRequest(actorUserId: 'admin', userId: 'reject'),
      true,
    );
    expect(family.isMember('reject'), false);

    expect(
      family.canRemoveMember(
        actorUserId: 'admin',
        targetUserId: 'leader',
      ),
      false,
    );
    expect(
      family.canRemoveMember(
        actorUserId: 'admin',
        targetUserId: 'admin2',
      ),
      false,
    );
    expect(
      family.removeMemberAs(
        actorUserId: 'admin',
        targetUserId: 'member',
      ),
      true,
    );
    expect(family.isMember('member'), false);
    expect(
      family.removeMemberAs(
        actorUserId: 'outside-family',
        targetUserId: 'new',
      ),
      false,
    );
  });

  test('cp disconnect and heartbeat states work', () {
    final cp = CpFeatureService()
      ..requestDisconnect('1')
      ..respondDisconnect(accept: false)
      ..startHeartbeat()
      ..chooseHeartbeat('A')
      ..resolveHeartbeat(matched: true);
    expect(cp.disconnectState, DisconnectState.refused);
    expect(cp.heartbeatState, HeartbeatState.matched);
  });

  test('ktv detail service supports local scan and repeat', () {
    final ktv = KtvService();
    final features = KtvFeatureService(ktv);
    features.scanLocalSongs(
      const [Song(id: 'local1', title: 'Local', singer: 'Singer', local: true)],
    );
    expect(features.localSongs.length, 1);
    ktv.addToQueue(ktv.library.first, '1');
    ktv.startNext();
    features.repeatMode = KtvRepeatMode.singleCycle;
    features.finishCurrent();
    expect(ktv.current, isNotNull);
  });
}
