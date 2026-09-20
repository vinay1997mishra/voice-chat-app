import 'dart:convert';
import 'local_code_doctor.dart';

/// Adapter for Anamika's already-installed on-device model.
///
/// NativeLocalInference is implemented by the Android/local inference layer.
/// No GitHub or network API is required by this class.
abstract interface class NativeLocalInference {
  Future<String> generate(String prompt);
}

class AnamikaLocalCodingModel implements CodingModel {
  AnamikaLocalCodingModel(this.inference);
  final NativeLocalInference inference;

  @override
  Future<List<RepairPatch>> proposeRepair({
    required Map<String, String> workspace,
    required List<CodeDiagnostic> diagnostics,
  }) async {
    final prompt = _repairPrompt(workspace, diagnostics);
    final raw = await inference.generate(prompt);
    return _decodePatches(raw);
  }

  Future<Map<String, String>> writeFeature({
    required String request,
    required Map<String, String> workspace,
  }) async {
    final raw = await inference.generate(_featurePrompt(request, workspace));
    final decoded = jsonDecode(_extractJson(raw));
    if (decoded is! Map || decoded['files'] is! List) {
      throw const FormatException('Local model did not return files JSON.');
    }
    final result = Map<String, String>.from(workspace);
    for (final item in decoded['files'] as List) {
      if (item is! Map) continue;
      final path = item['path']?.toString() ?? '';
      final content = item['content']?.toString() ?? '';
      if (!_safe(path)) throw FormatException('Unsafe generated path: $path');
      result[path] = content;
    }
    return result;
  }

  String _repairPrompt(Map<String, String> workspace, List<CodeDiagnostic> d) =>
      '''You are Anamika's offline coding engine. Repair the supplied project.
Return ONLY JSON: {"patches":[{"path":"...","replacement":"..."}]}.
Never modify security/owner approval/signing/workflow controls.
Diagnostics:
${d.map((e) => '${e.kind.name}: ${e.file ?? ''}:${e.line ?? ''} ${e.message}').join('\n')}
Files:
${workspace.entries.map((e) => '--- ${e.key}\n${e.value}').join('\n')}
''';

  String _featurePrompt(String request, Map<String, String> workspace) =>
      '''You are Anamika's offline coding engine. Implement exactly this owner request:
$request
Return ONLY JSON: {"files":[{"path":"...","content":"complete file content"}]}.
Preserve unrelated behavior. Do not alter owner approval, signing, secrets or protected workflows.
Project:
${workspace.entries.map((e) => '--- ${e.key}\n${e.value}').join('\n')}
''';

  List<RepairPatch> _decodePatches(String raw) {
    final decoded = jsonDecode(_extractJson(raw));
    if (decoded is! Map || decoded['patches'] is! List) {
      throw const FormatException('Local model did not return patches JSON.');
    }
    return (decoded['patches'] as List).map((item) {
      if (item is! Map) throw const FormatException('Invalid patch.');
      final path = item['path']?.toString() ?? '';
      if (!_safe(path)) throw FormatException('Unsafe repair path: $path');
      return RepairPatch(path: path, beforeHash: '', replacement: item['replacement']?.toString() ?? '');
    }).toList();
  }

  String _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end < start) throw const FormatException('No JSON returned by local model.');
    return raw.substring(start, end + 1);
  }

  bool _safe(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains('..') &&
      !path.startsWith('.github/') &&
      path != 'android/key.properties' &&
      !path.endsWith('upload-keystore.jks');
}
