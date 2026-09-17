import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/main.dart';

void main() {
  testWidgets('demo login opens the home shell', (tester) async {
    await tester.pumpWidget(const VoiceChatApp());

    expect(find.text('Continue in Demo Mode'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-demo')));
    await tester.pumpAndSettle();

    expect(find.text('Discover Rooms'), findsOneWidget);
    expect(find.text('Night Vibes'), findsOneWidget);
  });
}
