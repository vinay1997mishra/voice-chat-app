class CodingIntent {
  const CodingIntent({
    required this.request,
    this.languageHint,
    this.targetFiles = const [],
  });
  final String request;
  final String? languageHint;
  final List<String> targetFiles;
}

class CodingIntentParser {
  CodingIntent parse(String ownerCommand) {
    final text = ownerCommand.trim();
    if (text.isEmpty) throw ArgumentError('Coding request cannot be empty.');
    final lower = text.toLowerCase();
    String? language;
    for (final candidate in const [
      'dart',
      'flutter',
      'kotlin',
      'javascript',
      'java',
      'python',
      'typescript',
      'html',
      'css',
      'c++',
      'c#',
      'go',
      'rust',
      'php',
      'sql',
    ]) {
      if (RegExp(
        '(?<![a-zA-Z0-9_])${RegExp.escape(candidate)}(?![a-zA-Z0-9_])',
      ).hasMatch(lower)) {
        language = candidate;
        break;
      }
    }
    return CodingIntent(request: text, languageHint: language);
  }
}
