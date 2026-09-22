enum CustomGiftState {
  draft,
  underReview,
  approved,
  rejected,
  listed,
  expired,
  unused,
  used,
}

class CustomGiftDraft {
  const CustomGiftDraft({
    required this.id,
    required this.name,
    required this.assetType,
    required this.assetPath,
    required this.state,
    this.soundMode = 'original',
  });

  final String id;
  final String name;
  final String assetType;
  final String assetPath;
  final CustomGiftState state;
  final String soundMode;

  CustomGiftDraft copyWith({CustomGiftState? state}) => CustomGiftDraft(
        id: id,
        name: name,
        assetType: assetType,
        assetPath: assetPath,
        state: state ?? this.state,
        soundMode: soundMode,
      );
}

class CustomGiftService {
  final List<CustomGiftDraft> gifts = <CustomGiftDraft>[];

  CustomGiftDraft create({
    required String id,
    required String name,
    required String assetType,
    required String assetPath,
  }) {
    if (!{'image', 'video'}.contains(assetType)) {
      throw StateError('Unsupported custom gift asset type');
    }
    final gift = CustomGiftDraft(
      id: id,
      name: name.trim(),
      assetType: assetType,
      assetPath: assetPath,
      state: CustomGiftState.draft,
    );
    gifts.add(gift);
    return gift;
  }

  void submit(String id) => _set(id, CustomGiftState.underReview);
  void approve(String id) => _set(id, CustomGiftState.approved);
  void reject(String id) => _set(id, CustomGiftState.rejected);
  void list(String id) => _set(id, CustomGiftState.listed);
  void markUsed(String id) => _set(id, CustomGiftState.used);

  void _set(String id, CustomGiftState state) {
    final index = gifts.indexWhere((gift) => gift.id == id);
    if (index < 0) return;
    gifts[index] = gifts[index].copyWith(state: state);
  }
}
