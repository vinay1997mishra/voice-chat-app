import 'seat_policy.dart';

enum PackApplyStatus { applied, rejected, rolledBack }

class TinniFunctionConfig {
  const TinniFunctionConfig({
    this.seatCount = 12,
    this.inviteMode = true,
    this.seatLockEnabled = true,
    this.roomChatEnabled = true,
    this.giftsEnabled = true,
    this.maxGiftCombo = 100,
    this.ktvEnabled = false,
    this.gamesEnabled = false,
    this.cpEnabled = false,
    this.familyEnabled = false,
  });

  final int seatCount;
  final bool inviteMode;
  final bool seatLockEnabled;
  final bool roomChatEnabled;
  final bool giftsEnabled;
  final int maxGiftCombo;
  final bool ktvEnabled;
  final bool gamesEnabled;
  final bool cpEnabled;
  final bool familyEnabled;
}

class FunctionPack {
  const FunctionPack({
    required this.id,
    required this.version,
    required this.minSchema,
    required this.maxSchema,
    required this.summary,
    required this.signature,
    required this.config,
  });

  final String id;
  final int version;
  final int minSchema;
  final int maxSchema;
  final String summary;
  final String signature;
  final TinniFunctionConfig config;

  FunctionPack withSignature(String value) => FunctionPack(
        id: id,
        version: version,
        minSchema: minSchema,
        maxSchema: maxSchema,
        summary: summary,
        signature: value,
        config: config,
      );
}

abstract interface class FunctionPackSignatureVerifier {
  bool verify(FunctionPack pack);
}

class DevelopmentSignatureVerifier implements FunctionPackSignatureVerifier {
  const DevelopmentSignatureVerifier();

  @override
  bool verify(FunctionPack pack) => pack.signature == 'TINNI_DEV_SIGNED';
}

class FunctionPackResult {
  const FunctionPackResult(this.status, this.message);
  final PackApplyStatus status;
  final String message;
}

class FunctionPackRuntime {
  FunctionPackRuntime({
    required this.signatureVerifier,
    this.appSchema = 1,
    TinniFunctionConfig initialConfig = const TinniFunctionConfig(),
  }) : _activeConfig = initialConfig;

  final FunctionPackSignatureVerifier signatureVerifier;
  final int appSchema;

  TinniFunctionConfig _activeConfig;
  TinniFunctionConfig? _previousConfig;
  FunctionPack? _activePack;
  FunctionPack? _previousPack;

  TinniFunctionConfig get config => _activeConfig;
  FunctionPack? get activePack => _activePack;
  FunctionPack? get previousPack => _previousPack;

  FunctionPackResult apply(FunctionPack pack, {required bool ownerApproved}) {
    if (!ownerApproved) {
      return const FunctionPackResult(
        PackApplyStatus.rejected,
        'Owner approval is required.',
      );
    }
    if (pack.id.trim().isEmpty || pack.version <= 0) {
      return const FunctionPackResult(
        PackApplyStatus.rejected,
        'Invalid pack identity/version.',
      );
    }
    if (appSchema < pack.minSchema || appSchema > pack.maxSchema) {
      return const FunctionPackResult(
        PackApplyStatus.rejected,
        'Pack is incompatible with this app schema.',
      );
    }
    if (!signatureVerifier.verify(pack)) {
      return const FunctionPackResult(
        PackApplyStatus.rejected,
        'Pack signature verification failed.',
      );
    }
    if (_activePack != null &&
        pack.id == _activePack!.id &&
        pack.version <= _activePack!.version) {
      return const FunctionPackResult(
        PackApplyStatus.rejected,
        'Pack version must be newer than the active version.',
      );
    }

    final error = _validateConfig(pack.config);
    if (error != null) {
      return FunctionPackResult(PackApplyStatus.rejected, error);
    }

    _previousConfig = _activeConfig;
    _previousPack = _activePack;
    _activeConfig = pack.config;
    _activePack = pack;
    return FunctionPackResult(
      PackApplyStatus.applied,
      'Applied ' + pack.id + ' v' + pack.version.toString() + '.',
    );
  }

  FunctionPackResult rollback({required bool ownerApproved}) {
    if (!ownerApproved) {
      return const FunctionPackResult(
        PackApplyStatus.rejected,
        'Owner approval is required.',
      );
    }
    if (_previousConfig == null) {
      return const FunctionPackResult(
        PackApplyStatus.rejected,
        'No previous Function Pack is available.',
      );
    }

    final currentConfig = _activeConfig;
    final currentPack = _activePack;
    _activeConfig = _previousConfig!;
    _activePack = _previousPack;
    _previousConfig = currentConfig;
    _previousPack = currentPack;
    return const FunctionPackResult(
      PackApplyStatus.rolledBack,
      'Rolled back to the previous Function Pack state.',
    );
  }

  String? _validateConfig(TinniFunctionConfig config) {
    if (!isSupportedSeatCount(config.seatCount)) {
      return 'seatCount must be one of: ' +
          supportedSeatCounts.join(', ') +
          '.';
    }
    if (config.maxGiftCombo < 1 || config.maxGiftCombo > 10000) {
      return 'maxGiftCombo must be between 1 and 10000.';
    }
    return null;
  }
}
