import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/community/family_service.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/screens/feature_center_screen.dart';
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
  testWidgets('Mine CP opens the CP page', (tester) async {
    final state = makeState();
    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(state: state)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('CP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CP'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cp-screen')), findsOneWidget);
  });

  testWidgets('More routes store CP disconnect family and sharing to pages',
      (tester) async {
    final state = makeState();
    await tester.pumpWidget(
      MaterialApp(home: FeatureCenterScreen(state: state)),
    );
    await tester.pumpAndSettle();

    Future<void> openFeature(String label, Key destinationKey) async {
      final finder = find.text(label);
      await tester.scrollUntilVisible(
        finder,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(find.byKey(destinationKey), findsOneWidget);
    }

    await openFeature(
      'Store / Inventory',
      const Key('store-screen'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openFeature(
      'CP / Courting',
      const Key('cp-screen'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openFeature(
      'CP Disconnect Flow',
      const Key('cp-disconnect-screen'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openFeature(
      'Family',
      const Key('family-home-screen'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openFeature(
      'Sharing',
      const Key('sharing-screen'),
    );
  });

  testWidgets('VIP monthly top-up opens Recharge page', (tester) async {
    final state = makeState();
    await tester.pumpWidget(
      MaterialApp(home: VipScreen(state: state)),
    );
    await tester.pumpAndSettle();

    final topup = find.byKey(const Key('vip-monthly-topup-button'));
    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(topup, findsOneWidget);
    await tester.ensureVisible(topup);
    await tester.pumpAndSettle();
    await tester.tap(topup);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recharge-screen')), findsOneWidget);
  });
}
