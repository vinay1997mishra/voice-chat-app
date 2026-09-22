import 'dart:convert';

import 'function_pack.dart';

class FunctionPackCodec {
  static FunctionPack decode(String payload) {
    final raw = jsonDecode(payload);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Function Pack must be a JSON object.');
    }
    final configRaw = raw['config'];
    if (configRaw is! Map<String, dynamic>) {
      throw const FormatException('Function Pack config is required.');
    }

    return FunctionPack(
      id: _string(raw, 'id'),
      version: _int(raw, 'version'),
      minSchema: _int(raw, 'minSchema'),
      maxSchema: _int(raw, 'maxSchema'),
      summary: _string(raw, 'summary'),
      signature: _string(raw, 'signature'),
      config: TinniFunctionConfig(
        seatCount: _optionalInt(configRaw, 'seatCount', 12),
        inviteMode: _optionalBool(configRaw, 'inviteMode', true),
        seatLockEnabled:
            _optionalBool(configRaw, 'seatLockEnabled', true),
        roomChatEnabled:
            _optionalBool(configRaw, 'roomChatEnabled', true),
        giftsEnabled: _optionalBool(configRaw, 'giftsEnabled', true),
        maxGiftCombo: _optionalInt(configRaw, 'maxGiftCombo', 100),
        ktvEnabled: _optionalBool(configRaw, 'ktvEnabled', false),
        gamesEnabled: _optionalBool(configRaw, 'gamesEnabled', false),
        cpEnabled: _optionalBool(configRaw, 'cpEnabled', false),
        familyEnabled: _optionalBool(configRaw, 'familyEnabled', false),
      ),
    );
  }

  static String encode(FunctionPack pack) {
    return jsonEncode({
      'id': pack.id,
      'version': pack.version,
      'minSchema': pack.minSchema,
      'maxSchema': pack.maxSchema,
      'summary': pack.summary,
      'signature': pack.signature,
      'config': {
        'seatCount': pack.config.seatCount,
        'inviteMode': pack.config.inviteMode,
        'seatLockEnabled': pack.config.seatLockEnabled,
        'roomChatEnabled': pack.config.roomChatEnabled,
        'giftsEnabled': pack.config.giftsEnabled,
        'maxGiftCombo': pack.config.maxGiftCombo,
        'ktvEnabled': pack.config.ktvEnabled,
        'gamesEnabled': pack.config.gamesEnabled,
        'cpEnabled': pack.config.cpEnabled,
        'familyEnabled': pack.config.familyEnabled,
      },
    });
  }

  static String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(key + ' must be a non-empty string.');
    }
    return value;
  }

  static int _int(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int) throw FormatException(key + ' must be an integer.');
    return value;
  }

  static int _optionalInt(
    Map<String, dynamic> map,
    String key,
    int fallback,
  ) {
    final value = map[key];
    return value is int ? value : fallback;
  }

  static bool _optionalBool(
    Map<String, dynamic> map,
    String key,
    bool fallback,
  ) {
    final value = map[key];
    return value is bool ? value : fallback;
  }
}
