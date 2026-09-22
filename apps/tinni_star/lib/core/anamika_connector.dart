import 'dart:convert';

import 'function_pack.dart';
import 'function_pack_codec.dart';

class AnamikaConnector {
  AnamikaConnector({required this.runtime});

  final FunctionPackRuntime runtime;
  final List<Map<String, Object?>> commandHistory =
      <Map<String, Object?>>[];

  FunctionPackResult installValidatedPack(
    FunctionPack pack, {
    required bool ownerApproved,
  }) {
    final result = runtime.apply(pack, ownerApproved: ownerApproved);
    commandHistory.insert(0, {
      'type': 'apply_pack',
      'packId': pack.id,
      'packVersion': pack.version,
      'status': result.status.name,
    });
    return result;
  }

  FunctionPackResult installPayload(
    String payload, {
    required bool ownerApproved,
  }) {
    final pack = FunctionPackCodec.decode(payload);
    return installValidatedPack(pack, ownerApproved: ownerApproved);
  }

  FunctionPackResult rollback({required bool ownerApproved}) {
    final result = runtime.rollback(ownerApproved: ownerApproved);
    commandHistory.insert(0, {
      'type': 'rollback',
      'status': result.status.name,
    });
    return result;
  }

  String handleCommandJson(
    String commandJson, {
    required bool ownerApproved,
  }) {
    final raw = jsonDecode(commandJson);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Anamika command must be a JSON object.');
    }
    final type = raw['type'];
    if (type == 'diagnostics') {
      return jsonEncode({
        'ok': true,
        'type': 'diagnostics',
        'data': diagnosticSnapshot(),
      });
    }
    if (type == 'rollback') {
      final result = rollback(ownerApproved: ownerApproved);
      return jsonEncode({
        'ok': result.status != PackApplyStatus.rejected,
        'type': 'rollback',
        'status': result.status.name,
        'message': result.message,
      });
    }
    if (type == 'apply_pack') {
      final pack = raw['pack'];
      if (pack is! Map<String, dynamic>) {
        throw const FormatException('apply_pack requires pack object.');
      }
      final result = installPayload(
        jsonEncode(pack),
        ownerApproved: ownerApproved,
      );
      return jsonEncode({
        'ok': result.status == PackApplyStatus.applied,
        'type': 'apply_pack',
        'status': result.status.name,
        'message': result.message,
      });
    }
    throw FormatException('Unsupported Anamika command: ' + type.toString());
  }

  Map<String, Object?> diagnosticSnapshot() {
    final config = runtime.config;
    return {
      'app': 'Tinni Star',
      'schema': runtime.appSchema,
      'activePackId': runtime.activePack?.id,
      'activePackVersion': runtime.activePack?.version,
      'previousPackId': runtime.previousPack?.id,
      'previousPackVersion': runtime.previousPack?.version,
      'seatCount': config.seatCount,
      'inviteMode': config.inviteMode,
      'seatLockEnabled': config.seatLockEnabled,
      'roomChatEnabled': config.roomChatEnabled,
      'giftsEnabled': config.giftsEnabled,
      'maxGiftCombo': config.maxGiftCombo,
      'ktvEnabled': config.ktvEnabled,
      'gamesEnabled': config.gamesEnabled,
      'cpEnabled': config.cpEnabled,
      'familyEnabled': config.familyEnabled,
    };
  }
}
