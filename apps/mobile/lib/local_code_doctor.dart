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
  LocalCodeDoctor({required this.runner, required this.model, this.maxAttempts = 3});
  final CodeRunner runner;
  final CodingModel model;
  final int maxAttempts;

  Future<RepairSession> repair(Map<String, String> original) async {
    var workspace = Map<String, String>.from(original);
    final attempts = <RepairAttempt>[];

    for (var i = 1; i <= maxAttempts; i++) {
      final diagnostics = await runner.check(workspace);
      if (diagnostics.isEmpty) {
        return RepairSession(original: original, candidate: workspace, attempts: attempts, passed: true);
      }
      final patches = await model.proposeRepair(workspace: workspace, diagnostics: diagnostics);
      if (patches.isEmpty) break;
      for (final patch in patches) {
        if (!_safePath(patch.path) || !workspace.containsKey(patch.path)) {
          throw StateError('Unsafe or unknown repair path: ${patch.path}');
        }
        workspace[patch.path] = patch.replacement;
      }
      attempts.add(RepairAttempt(number: i, diagnostics: diagnostics, patches: patches));
    }

    final remaining = await runner.check(workspace);
    return RepairSession(original: original, candidate: workspace, attempts: attempts, passed: remaining.isEmpty, remaining: remaining);
  }

  bool _safePath(String path) =>
      !path.startsWith('/') &&
      !path.contains('..') &&
      !UpgradePolicy.forbiddenPaths.contains(path);
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

  bool get changed => candidate.toString() != original.toString();
}
