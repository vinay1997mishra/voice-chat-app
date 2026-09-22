import 'function_pack.dart';

class AnamikaConnector {
  AnamikaConnector({required this.runtime});

  final FunctionPackRuntime runtime;

  FunctionPackResult installValidatedPack(
    FunctionPack pack, {
    required bool ownerApproved,
  }) {
    return runtime.apply(pack, ownerApproved: ownerApproved);
  }

  FunctionPackResult rollback({required bool ownerApproved}) {
    return runtime.rollback(ownerApproved: ownerApproved);
  }

  Map<String, Object?> diagnosticSnapshot() {
    final config = runtime.config;
    return {
      'app': 'Tinni Star',
      'schema': runtime.appSchema,
      'activePackId': runtime.activePack?.id,
      'activePackVersion': runtime.activePack?.version,
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
