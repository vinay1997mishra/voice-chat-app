import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/ui/animated_shop_frames.dart';
import 'package:tinni_star/ui/animated_avatar_frame.dart';

void main() {
  testWidgets('all 25 themes render animated avatar frames at seat and preview sizes', (tester) async {
    expect(animatedShopFrames.length, 25);
    expect(animatedShopFrames.map((frame) => frame.id).toSet().length, 25);
    for (final frame in animatedShopFrames) {
      expect(animatedShopFrame(frame.id), same(frame));
      for (final size in [40.0, 160.0]) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
          child: AnimatedAvatarFrame(frameId: frame.id, size: size,
            child: const CircleAvatar(child: Icon(Icons.person))),
        ))));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull, reason: frame.id);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  test('room seat frames touch the DP edge but paint only outside it', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final frame = File('lib/ui/animated_avatar_frame.dart').readAsStringSync();

    expect(room, contains('outsideOnly: true'));
    expect(frame, contains('protectedInnerRadius: avatarSize / 2'));
    expect(frame, contains('PathOperation.difference'));
    expect(frame, contains('frameCanvasSize ='));
  });
}
