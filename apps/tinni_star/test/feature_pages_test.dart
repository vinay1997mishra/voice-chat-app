import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/community/family_service.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/screens/profile_screen.dart';
import 'package:tinni_star/screens/vip_screen.dart';
import 'package:tinni_star/social/social.dart';

import 'test_account.dart';

TinniState makeState() {
  final state = TinniState(
    runtime: FunctionPackRuntime(
      signatureVerifier: const DevelopmentSignatureVerifier(),
    ),
  );
  final account = attachTestAccount(state);
  state.social.friendProfiles.add(
    const SocialUser(id: 'friend-1', name: 'Friend One'),
  );
  state.social.friends.add('friend-1');
  state.family.create(
    familyName: 'Test Family',
    familyTag: 'TF',
    head: FamilyMember(
      userId: account.userId,
      name: account.displayName,
      role: FamilyRole.head,
    ),
  );
  return state;
}

void main() {
  testWidgets('Mine keeps CP in its own personal panel', (tester) async {
    final state = makeState();
    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(state: state)),
    );
    await tester.pumpAndSettle();

    final cpPanel = find.byKey(const Key('mine-cp-panel'));
    expect(cpPanel, findsOneWidget);
    await tester.ensureVisible(cpPanel);
    await tester.tap(cpPanel);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cp-screen')), findsOneWidget);
  });

  testWidgets('VIP monthly top-up opens Recharge page', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final state = makeState();
    await tester.pumpWidget(
      MaterialApp(home: VipScreen(state: state)),
    );
    await tester.pumpAndSettle();

    final topup = find.byKey(const Key('vip-monthly-topup-button'));
    expect(topup, findsOneWidget);
    await tester.tap(topup);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recharge-screen')), findsOneWidget);
  });
}
