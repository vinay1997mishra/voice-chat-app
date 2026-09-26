class OwnerTag {
  const OwnerTag({
    required this.name,
    required this.colorHex,
  });

  final String name;
  final String colorHex;

  factory OwnerTag.fromMap(Map<dynamic, dynamic> value) {
    final rawColor = value['color']?.toString().trim() ?? '#FFD54F';
    final normalizedColor =
        RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(rawColor)
            ? rawColor.toUpperCase()
            : '#FFD54F';
    return OwnerTag(
      name: value['name']?.toString().trim() ?? '',
      colorHex: normalizedColor,
    );
  }

  Map<String, String> toJson() => <String, String>{
        'name': name,
        'color': colorHex,
      };
}
