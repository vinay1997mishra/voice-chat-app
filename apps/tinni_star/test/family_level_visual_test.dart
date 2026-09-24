import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/community/family_service.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/screens/family_home_screen.dart';
import 'package:tinni_star/screens/profile_screen.dart';

void main() {
  TinniState makeState() {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    state.auth.loginDemo();
    state.family.create(
      familyName: 'Royal Family',
      familyTag: 'RF',
      head: const FamilyMember(
        userId: '10000000',
        name: 'Tinni User',
        role: FamilyRole.head,
      ),
    );
    return state;
  }

  testWidgets('family tag and level appear on profile and family home',
      (tester) async {
    final state = makeState();
    state.family.addExperience(50000);

    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(state: state)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-family-tag')), findsOneWidget);
    expect(find.textContaining('RF'), findsWidgets);
    expect(find.textContaining(state.family.levelLabel), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(home: FamilyHomeScreen(state: state)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('family-level-shell')), findsOneWidget);
    expect(find.byKey(const Key('family-level-tag')), findsOneWidget);
    expect(find.textContaining('Family Level'), findsOneWidget);
  });
}
