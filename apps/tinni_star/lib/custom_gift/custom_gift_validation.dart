class CustomGiftPolicy {
  const CustomGiftPolicy({
    this.maxBytes = 20 * 1024 * 1024,
    this.maxVideoSeconds = 30,
    this.minDimension = 128,
  });

  final int maxBytes;
  final int maxVideoSeconds;
  final int minDimension;
}

class CustomGiftAssetMetadata {
  const CustomGiftAssetMetadata({
    required this.assetType,
    required this.bytes,
    required this.width,
    required this.height,
    this.durationSeconds,
    this.hasOriginalSound = false,
  });

  final String assetType;
  final int bytes;
  final int width;
  final int height;
  final int? durationSeconds;
  final bool hasOriginalSound;
}

class CustomGiftValidationResult {
  const CustomGiftValidationResult({
    required this.valid,
    this.errors = const [],
  });

  final bool valid;
  final List<String> errors;
}

class CustomGiftValidator {
  const CustomGiftValidator({this.policy = const CustomGiftPolicy()});

  final CustomGiftPolicy policy;

  CustomGiftValidationResult validate(CustomGiftAssetMetadata metadata) {
    final errors = <String>[];
    if (!{'image', 'video'}.contains(metadata.assetType)) {
      errors.add('Unsupported custom gift asset type.');
    }
    if (metadata.bytes <= 0 || metadata.bytes > policy.maxBytes) {
      errors.add('Custom gift file size is outside the allowed policy.');
    }
    if (metadata.width < policy.minDimension ||
        metadata.height < policy.minDimension) {
      errors.add('Custom gift dimensions are too small.');
    }
    if (metadata.assetType == 'video') {
      final duration = metadata.durationSeconds;
      if (duration == null ||
          duration <= 0 ||
          duration > policy.maxVideoSeconds) {
        errors.add('Custom gift video duration is outside the allowed policy.');
      }
    }
    return CustomGiftValidationResult(
      valid: errors.isEmpty,
      errors: List<String>.unmodifiable(errors),
    );
  }
}
