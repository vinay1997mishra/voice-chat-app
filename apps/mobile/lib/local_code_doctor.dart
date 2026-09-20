import 'self_upgrade_system.dart';

enum LocalCheckKind { syntax, analyzer, test, build, policy }

class CodeDiagnostic {
  const CodeDiagnostic({
    required this.kind,
    required this.message,
    this.file,
    this.line,
  });
  final LocalCheckKind kind;
  final String message;
  final String? file;
  final int? line;
}

class RepairPatch {
  const RepairPatch({
    required this.path,
    required this.beforeHash,
    required this.replacement,
  });
  final String path;
  final String beforeHash;
  final String replacement;
}

class RepairAttempt {
  const RepairAttempt({
    required this.number,
    required this.diagnostics,
    required this.patches,
  });
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
  LocalCodeDoctor({
    required this.runner,
    required this.model,
    this.maxAttempts = 3,
    this.timeout = const Duration(seconds: 90),
  }) {
    if (maxAttempts < 1 || maxAttempts > 5)
      throw ArgumentError('Attempts must be between 1 and 5.');
  }
  final Duration timeout;
  final CodeRunner runner;
  final CodingModel model;
  final int maxAttempts;

  Future<RepairSession> repair(Map<String, String> original) async {
    original = Map<String, String>.unmodifiable(original);
    var workspace = Map<String, String>.from(original);
    final attempts = <RepairAttempt>[];

    for (var i = 1; i <= maxAttempts; i++) {
      final diagnostics =
          await runner.check(Map.unmodifiable(workspace)).timeout(timeout);
      if (diagnostics.isEmpty) {
        return RepairSession(
          original: original,
          candidate: workspace,
          attempts: attempts,
          passed: true,
        );
      }
      final patches = await model
          .proposeRepair(
            workspace: Map.unmodifiable(workspace),
            diagnostics: diagnostics,
          )
          .timeout(timeout);
      if (patches.isEmpty) break;
      final paths = <String>{};
      for (final patch in patches) {
        if (!_safePath(patch.path) || !workspace.containsKey(patch.path)) {
          throw StateError('Unsafe or unknown repair path: ${patch.path}');
        }
        if (!paths.add(patch.path) ||
            sourceHash(workspace[patch.path]!) != patch.beforeHash) {
          throw StateError('Duplicate or stale repair patch: ${patch.path}');
        }
      }
      for (final patch in patches) {
        workspace[patch.path] = patch.replacement;
      }
      attempts.add(
        RepairAttempt(number: i, diagnostics: diagnostics, patches: patches),
      );
    }

    final remaining =
        await runner.check(Map.unmodifiable(workspace)).timeout(timeout);
    return RepairSession(
      original: original,
      candidate: workspace,
      attempts: attempts,
      passed: remaining.isEmpty,
      remaining: remaining,
    );
  }

  bool _safePath(String path) => UpgradePolicy.allows(path);
}

class RepairSession {
  RepairSession({
    required Map<String, String> original,
    required Map<String, String> candidate,
    required List<RepairAttempt> attempts,
    required this.passed,
    List<CodeDiagnostic> remaining = const [],
  })  : original = Map.unmodifiable(original),
        candidate = Map.unmodifiable(candidate),
        attempts = List.unmodifiable(attempts),
        remaining = List.unmodifiable(remaining);
  final Map<String, String> original;
  final Map<String, String> candidate;
  final List<RepairAttempt> attempts;
  final bool passed;
  final List<CodeDiagnostic> remaining;

  bool get changed => workspaceHash(candidate) != workspaceHash(original);
}
