import 'dart:convert';

import 'local_code_doctor.dart';
import 'self_upgrade_system.dart';

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
    final raw = await inference.generate(_repairPrompt(workspace, diagnostics));
    return _decodePatches(raw, workspace);
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
    final seen = <String>{};
    for (final item in decoded['files'] as List) {
      if (item is! Map) throw const FormatException('Invalid generated file.');
      final path = UpgradePolicy.normalizePath(item['path']?.toString() ?? '');
      final fileContent = item['content']?.toString() ?? '';
      if (!_safeFeaturePath(path) || !seen.add(path)) {
        throw FormatException('Unsafe or duplicate generated path: $path');
      }
      result[path] = fileContent;
    }
    return result;
  }

  String _repairPrompt(Map<String, String> workspace, List<CodeDiagnostic> diagnostics) =>
      '''You are Anamika's offline coding engine. Repair the supplied project.
Return ONLY JSON: {"patches":[{"path":"...","beforeHash":"...","replacement":"..."}]}.
beforeHash must equal the supplied file fingerprint.
Never modify security, owner approval, signing, secrets, or workflow controls.
Diagnostics:
\${diagnostics.map((e) => '\${e.kind.name}: \${e.file ?? ''}:\${e.line ?? ''} \${e.message}').join('\\n')}
Files:
\${workspace.entries.map((e) => '--- \${e.key} [fingerprint=\${LocalCodeDoctor.contentFingerprint(e.value)}]\\n\${e.value}').join('\\n')}
''';

  String _featurePrompt(String request, Map<String, String> workspace) =>
      '''You are Anamika's offline coding engine. Implement exactly this owner request:
\$request
Return ONLY JSON: {"files":[{"path":"...","content":"complete file content"}]}.
Only generate apps/mobile/lib or apps/mobile/test files. Do not alter owner approval,
signing, secrets, or protected workflows. Preserve unrelated behavior.
Project:
\${workspace.entries.map((e) => '--- \${e.key}\\n\${e.value}').join('\\n')}
''';

  List<RepairPatch> _decodePatches(String raw, Map<String, String> workspace) {
    final decoded = jsonDecode(_extractJson(raw));
    if (decoded is! Map || decoded['patches'] is! List) {
      throw const FormatException('Local model did not return patches JSON.');
    }
    return (decoded['patches'] as List).map((item) {
      if (item is! Map) throw const FormatException('Invalid patch.');
      final path = UpgradePolicy.normalizePath(item['path']?.toString() ?? '');
      if (!_safeRepairPath(path, workspace)) {
        throw FormatException('Unsafe or unknown repair path: $path');
      }
      final beforeHash = item['beforeHash']?.toString() ?? '';
      if (beforeHash.isEmpty) throw FormatException('Missing beforeHash for $path');
      return RepairPatch(
        path: path,
        beforeHash: beforeHash,
        replacement: item['replacement']?.toString() ?? '',
      );
    }).toList();
  }

  String _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end < start) {
      throw const FormatException('No JSON returned by local model.');
    }
    return raw.substring(start, end + 1);
  }

  bool _safeRepairPath(String path, Map<String, String> workspace) =>
      path.isNotEmpty &&
      workspace.containsKey(path) &&
      !UpgradePolicy.isProtectedPath(path);

  bool _safeFeaturePath(String path) =>
      path.isNotEmpty &&
      (path.startsWith('apps/mobile/lib/') || path.startsWith('apps/mobile/test/')) &&
      !UpgradePolicy.isProtectedPath(path);
}
