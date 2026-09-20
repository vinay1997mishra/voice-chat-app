import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/anamika_repair_page.dart';

void main() {
  testWidgets('repair page describes approval and rejects an empty request', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AnamikaRepairPage()));
    expect(find.text('Anamika · Code Doctor'), findsOneWidget);
    await tester.tap(find.text('Request copy करो और repair खोलो'));
    await tester.pump();
    expect(find.text('पहले बताओ क्या ठीक करना है।'), findsOneWidget);
  });
}
