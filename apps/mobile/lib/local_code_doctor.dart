import 'self_upgrade_system.dart';

enum LocalCheckKind { syntax, analyzer, test, build, policy }

class CodeDiagnostic {
  const CodeDiagnostic({required this.kind, required this.message, this.file, this.line});
  final LocalCheckKind kind;
  final String message;
  final String? file;
  final int? line;
}

class RepairPatch {
  const RepairPatch({required this.path, required this.beforeHash, required this.replacement});
  final String path;
  final String beforeHash;
  final String replacement;
}

class RepairAttempt {
  const RepairAttempt({required this.number, required this.diagnostics, required this.patches});
  final int number;
  final List<CodeDiagnostic> diagnostics;
  final List<RepairPatch> patches;
}

abstract interface class CodeRunner {
  Future<List<CodeDiagnostic>> check(Map<String, String> workspace);
}

abstract interface class CodingModel {
  Future<List<RepairPatch>> proposeRepair({
    required Map<String, String> workspace,
    required List<CodeDiagnostic> diagnostics,
  });
}

class LocalCodeDoctor {
  LocalCodeDoctor({required this.runner, required this.model, this.maxAttempts = 3})
      : assert(maxAttempts > 0);

  final CodeRunner runner;
  final CodingModel model;
  final int maxAttempts;

  Future<RepairSession> repair(Map<String, String> original) async {
    final originalSnapshot = Map<String, String>.unmodifiable(original);
    var workspace = Map<String, String>.from(originalSnapshot);
    final attempts = <RepairAttempt>[];

    for (var i = 1; i <= maxAttempts; i++) {
      final diagnostics = await runner.check(Map<String, String>.unmodifiable(workspace));
      if (diagnostics.isEmpty) {
        return RepairSession(
          original: originalSnapshot,
          candidate: Map<String, String>.unmodifiable(workspace),
          attempts: attempts,
          passed: true,
        );
      }

      final patches = await model.proposeRepair(
        workspace: Map<String, String>.unmodifiable(workspace),
        diagnostics: List<CodeDiagnostic>.unmodifiable(diagnostics),
      );
      if (patches.isEmpty) break;

      final paths = <String>{};
      for (final patch in patches) {
        final path = UpgradePolicy.normalizePath(patch.path);
        if (!_safePath(path) || !workspace.containsKey(path)) {
          throw StateError('Unsafe or unknown repair path: $path');
        }
        if (!paths.add(path)) {
          throw StateError('Duplicate repair path: $path');
        }
        final expectedHash = contentFingerprint(workspace[path]!);
        if (patch.beforeHash != expectedHash) {
          throw StateError('Stale repair patch for $path');
        }
        workspace[path] = patch.replacement;
      }
      attempts.add(RepairAttempt(number: i, diagnostics: diagnostics, patches: patches));
    }

    final remaining = await runner.check(Map<String, String>.unmodifiable(workspace));
    return RepairSession(
      original: originalSnapshot,
      candidate: Map<String, String>.unmodifiable(workspace),
      attempts: attempts,
      passed: remaining.isEmpty,
      remaining: List<CodeDiagnostic>.unmodifiable(remaining),
    );
  }

  bool _safePath(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains('..') &&
      !UpgradePolicy.isProtectedPath(path);

  static String contentFingerprint(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class RepairSession {
  const RepairSession({
    required this.original,
    required this.candidate,
    required this.attempts,
    required this.passed,
    this.remaining = const [],
  });
  final Map<String, String> original;
  final Map<String, String> candidate;
  final List<RepairAttempt> attempts;
  final bool passed;
  final List<CodeDiagnostic> remaining;

  bool get changed => !_sameWorkspace(original, candidate);

  static bool _sameWorkspace(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }
}
