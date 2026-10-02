class OwnerTag {
  const OwnerTag({
    required this.name,
    required this.colorHex,
    this.kind = 'custom',
    this.designation = '',
    this.backgroundColorHex,
  });

  final String name;
  final String colorHex;
  final String kind;
  final String designation;
  final String? backgroundColorHex;

  factory OwnerTag.fromMap(Map<dynamic, dynamic> value) {
    String normalize(dynamic raw, String fallback) {
      final color = raw?.toString().trim() ?? fallback;
      return RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)
          ? color.toUpperCase()
          : fallback;
    }

    return OwnerTag(
      name: value['name']?.toString().trim() ?? '',
      colorHex: normalize(value['color'], '#FFD54F'),
      kind: value['kind']?.toString().trim() ?? 'custom',
      designation: value['designation']?.toString().trim() ?? '',
      backgroundColorHex: value['background_color'] == null
          ? null
          : normalize(value['background_color'], '#69C9FF'),
    );
  }

  Map<String, String> toJson() {
    final result = <String, String>{
      'name': name,
      'color': colorHex,
      'kind': kind,
    };
    if (designation.isNotEmpty) {
      result['designation'] = designation;
    }
    final background = backgroundColorHex;
    if (background != null) {
      result['background_color'] = background;
    }
    return result;
  }
}
