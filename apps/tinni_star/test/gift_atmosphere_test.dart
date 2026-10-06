import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/economy/economy.dart';
import 'package:tinni_star/economy/premium_gift_catalog.dart';
import 'package:tinni_star/effects/gift_atmosphere.dart';
import 'package:tinni_star/effects/cinematic_video.dart';
import 'package:tinni_star/screens/gifts_screen.dart';

List<GiftDefinition> get _gifts => [
  ...PremiumGiftCatalog.normal, ...PremiumGiftCatalog.cp, ...GiftService.luckyCatalog,
];

void main() {

  test('gift browser exposes the full room catalog with canonical sendable IDs and prices', () {
    final browser = [
      ...GiftsScreen.catalogFor('Normal'), ...GiftsScreen.catalogFor('CP'),
      ...GiftsScreen.catalogFor('Country'), ...GiftsScreen.catalogFor('Lucky'),
    ];
    final authoritative = [
      ...PremiumGiftCatalog.normal, ...PremiumGiftCatalog.cp,
      ...PremiumGiftCatalog.countries, ...GiftService.luckyCatalog,
    ];
    expect(browser.map((gift) => gift.id).toSet(),
      authoritative.map((gift) => gift.id).toSet());
    for (final gift in browser) {
      final source = authoritative.singleWhere((candidate) => candidate.id == gift.id);
      expect(gift.price, source.price, reason: gift.name);
      if (gift.lucky) {
        expect(gift.artworkAsset, isNotNull);
      } else {
        expect(CinematicAssets.movieFor(gift.id), isNotNull, reason: gift.name);
      }
    }
    expect(browser.any((gift) => gift.id == 'gold-dragon' || gift.id == 'royal-crown'), isFalse);
  });

  test('every saleable gift has a named environment, including every country', () {
    final gifts = [..._gifts, ...PremiumGiftCatalog.countries];
    for (final gift in gifts) {
      expect(GiftAtmosphere.kindFor(gift.id), isNotNull, reason: gift.name);
    }
    expect(GiftAtmosphere.profiles.keys.toSet(), _gifts.map((gift) => gift.id).toSet());
    expect(GiftAtmosphere.kindFor('unknown-custom-gift'), isNull);
  });

  testWidgets('every named atmosphere paints entrance, hold and exit without errors', (tester) async {
    for (final gift in _gifts) {
      for (final progress in [0.0, .08, .48, .93, 1.0]) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GiftAtmosphere(
          giftId: gift.id, progress: progress, child: const SizedBox.expand(),
        ))));
        expect(tester.takeException(), isNull, reason: '${gift.id} at $progress');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion fixes the dragon position and atmosphere across the clock', (tester) async {
    Future<ui.Image> frame(double progress) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(home: RepaintBoundary(
        key: key, child: Scaffold(body: GiftAtmosphere(
          giftId: 'ice-dragon', progress: progress, reducedMotion: true,
          child: const ColoredBox(color: Color(0xFF132B46)),
        )),
      )));
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return tester.runAsync(() => boundary.toImage(pixelRatio: .5)).then((image) => image!);
    }
    final first = await frame(.12);
    final firstBytes = await tester.runAsync(() => first.toByteData());
    final second = await frame(.87);
    final secondBytes = await tester.runAsync(() => second.toByteData());
    expect(secondBytes!.buffer.asUint8List(), firstBytes!.buffer.asUint8List());
    first.dispose();
    second.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('country flags retain their existing presentation without added weather', (tester) async {
    const childKey = Key('national-flag');
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: GiftAtmosphere(
      giftId: 'flag-in', progress: .5, child: SizedBox.expand(key: childKey),
    ))));
    expect(find.byKey(childKey), findsOneWidget);
    expect(find.descendant(of: find.byType(GiftAtmosphere),
      matching: find.byType(CustomPaint)), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('export actual bundled posters with effects for all Normal, CP and Lucky gifts', (tester) async {
    if (!File('assets/cinematic/rose.png').existsSync()) return;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var cache = File(Platform.resolvedExecutable).parent;
    while (!Directory('${cache.path}/artifacts/material_fonts').existsSync() &&
        cache.parent.path != cache.path) {
      cache = cache.parent;
    }
    await tester.runAsync(() async {
      final loader = FontLoader('GiftPreview')..addFont(
        File('${cache.path}/artifacts/material_fonts/Roboto-Regular.ttf').readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    });
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final folder = Directory('build/gift_previews')..createSync(recursive: true);
    final gifts = _gifts;
    for (var batch = 0; batch < gifts.length; batch += 40) {
      final recorder = ui.PictureRecorder();
      final sheet = Canvas(recorder);
      sheet.drawColor(const Color(0xFF09111D), BlendMode.src);
      for (var index = batch; index < gifts.length && index < batch + 40; index++) {
        final gift = gifts[index];
        final poster = gift.lucky ? gift.artworkAsset! : 'assets/cinematic/${gift.id}.png';
        final key = GlobalKey();
        final imageProvider = AssetImage(poster);
        await tester.runAsync(() => precacheImage(imageProvider,
          tester.element(find.byType(Scaffold))));
        await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'GiftPreview'),
          home: RepaintBoundary(key: key, child: Scaffold(
            backgroundColor: const Color(0xFF09111D),
            body: Stack(fit: StackFit.expand, children: [
              GiftAtmosphere(giftId: gift.id, progress: .48,
                child: Center(child: FractionallySizedBox(
                  widthFactor: gift.lucky ? .45 : PremiumGiftCatalog.isFullScreen(gift.id) ? 1 : .72,
                  heightFactor: gift.lucky ? .30 : PremiumGiftCatalog.isFullScreen(gift.id) ? 1 : .62,
                  child: Image(image: imageProvider, fit: BoxFit.contain),
                )),
              ),
              Align(alignment: const Alignment(0, .70), child: Text(gift.name,
                textAlign: TextAlign.center, style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            ]),
          )),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: gift.id);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final frame = await tester.runAsync(() => boundary.toImage(pixelRatio: .5));
        final slot = index - batch;
        sheet.drawImage(frame!, Offset((slot % 5) * 180.0, (slot ~/ 5) * 320.0), Paint());
        frame.dispose();
      }
      await tester.runAsync(() async {
        final picture = recorder.endRecording();
        final sheetImage = await picture.toImage(900, 2560);
        final bytes = await sheetImage.toByteData(format: ui.ImageByteFormat.png);
        File('${folder.path}/all-gifts-${batch ~/ 40}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        sheetImage.dispose();
        picture.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 90)));
}
