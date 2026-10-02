import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../discovery/discovery_service.dart';
import 'royal_theme.dart';

class RoomDp extends StatelessWidget {
  const RoomDp({
    super.key,
    required this.room,
    this.size = 72,
    this.radius = 14,
    this.fit = BoxFit.contain,
    this.fallbackSize = 30,
  });

  final RoomSummary room;
  final double size;
  final double radius;
  final BoxFit fit;
  final double fallbackSize;

  @override
  Widget build(BuildContext context) {
    final path = room.photoPath;
    final source = room.photoDataUrl?.trim() ?? '';
    final hasData = source.startsWith('data:image/');
    final hasNetwork =
        source.startsWith('https://') || source.startsWith('http://');
    final hasLocal =
        path != null && path.isNotEmpty && File(path).existsSync();

    Widget fallback() => Center(
          child: Text(
            room.title.trim().isEmpty
                ? '?'
                : room.title.trim().characters.first.toUpperCase(),
            style: TextStyle(
              color: RoyalPalette.gold,
              fontSize: fallbackSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        );

    Widget image;
    if (hasData) {
      try {
        image = Image.memory(
          base64Decode(source.split(',').last),
          fit: fit,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        );
      } catch (_) {
        image = fallback();
      }
    } else if (hasNetwork) {
      image = Image.network(
        source,
        fit: fit,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        errorBuilder: (_, error, stackTrace) => fallback(),
      );
    } else if (hasLocal) {
      image = Image.file(
        File(path),
        fit: fit,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        errorBuilder: (_, error, stackTrace) => fallback(),
      );
    } else {
      image = fallback();
    }

    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: RoyalPalette.nearBlack,
            border: Border.all(
              color: RoyalPalette.deepGold.withValues(alpha: .62),
            ),
          ),
          child: Center(
            child: SizedBox.expand(child: image),
          ),
        ),
      ),
    );
  }
}
