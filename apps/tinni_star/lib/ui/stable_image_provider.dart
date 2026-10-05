import 'dart:convert';
import 'package:flutter/painting.dart';

/// Reuses image identity across presence updates, so avatars never reload merely
/// because a parent rebuilds. Both entries and retained source bytes are bounded.
class StableImageProviderCache {
  StableImageProviderCache({this.maxEntries = 128, this.maxSourceBytes = 12 * 1024 * 1024});
  final int maxEntries;
  final int maxSourceBytes;
  final _images = <String, ImageProvider?>{};
  int _sourceBytes = 0;
  int get length => _images.length;
  int get sourceBytes => _sourceBytes;

  ImageProvider? resolve(String? value) {
    final source = value?.trim() ?? '';
    if (source.isEmpty) return null;
    if (_images.containsKey(source)) {
      final provider = _images.remove(source);
      _images[source] = provider;
      return provider;
    }
    ImageProvider? provider;
    try {
      if (source.startsWith('data:image/')) {
        final comma = source.indexOf(',');
        if (comma >= 0 && source.substring(0, comma).endsWith(';base64')) {
          provider = MemoryImage(base64Decode(source.substring(comma + 1)));
        }
      } else if (source.startsWith('https://') || source.startsWith('http://')) {
        provider = NetworkImage(source);
      }
    } catch (_) {}
    final bytes = source.length * 2;
    if (bytes > maxSourceBytes || maxEntries <= 0) return provider;
    while (_images.isNotEmpty &&
        (_images.length >= maxEntries || _sourceBytes + bytes > maxSourceBytes)) {
      final oldest = _images.keys.first;
      _images.remove(oldest);
      _sourceBytes -= oldest.length * 2;
    }
    _images[source] = provider;
    _sourceBytes += bytes;
    return provider;
  }

  void clear() {
    _images.clear();
    _sourceBytes = 0;
  }
}

final stableImages = StableImageProviderCache();
ImageProvider? stableImageProvider(String? source) => stableImages.resolve(source);
