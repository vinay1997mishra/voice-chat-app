import 'package:flutter_test/flutter_test.dart';
import '../lib/anamika_local_coding_model.dart';
import '../lib/anamika_upgrade_orchestrator.dart';
import '../lib/coding_intent.dart';
import '../lib/local_code_doctor.dart';
import '../lib/self_upgrade_system.dart';

class Reply implements NativeLocalInference {
  Reply(this.text);
  final String text;
  @override
  Future<String> generate(String prompt) async => text;
}

class CleanRunner implements CodeRunner {
  @override
  Future<List<CodeDiagnostic>> check(Map<String, String> w) async => [];
}

class BrokenRunner implements CodeRunner {
  int calls = 0;
  @override
  Future<List<CodeDiagnostic>> check(Map<String, String> w) async {
    calls++;
    return const [CodeDiagnostic(kind: LocalCheckKind.test, message: 'failed')];
  }
}

class PatchModel implements CodingModel {
  PatchModel({this.stale = false});
  final bool stale;
  @override
  Future<List<RepairPatch>> proposeRepair({
    required Map<String, String> workspace,
    required List<CodeDiagnostic> diagnostics,
  }) async =>
      [
        RepairPatch(
          path: 'apps/mobile/lib/x.dart',
          beforeHash:
              stale ? 'bad' : sourceHash(workspace['apps/mobile/lib/x.dart']!),
          replacement: 'new',
        ),
      ];
}

void main() {
  test('language names are whole tokens, javascript is not java', () {
    expect(
      CodingIntentParser().parse('javascript me likho').languageHint,
      'javascript',
    );
    expect(CodingIntentParser().parse('good morning').languageHint, isNull);
    expect(CodingIntentParser().parse('C++ code').languageHint, 'c++');
  });
  test(
    'protected approval source, tests, signing and path aliases rejected',
    () {
      for (final p in [
        'apps/mobile/lib/self_upgrade_system.dart',
        'apps/mobile/lib/../x.dart',
        'apps/mobile/lib//x.dart',
        'apps/mobile/test/test.dart',
        'apps/mobile/android/key.properties',
        '.github/CODEOWNERS',
      ]) {
        expect(UpgradePolicy.allows(p), false, reason: p);
      }
    },
  );
  test('missing replacement does not silently erase source', () async {
    final model = AnamikaLocalCodingModel(
      Reply('{"patches":[{"path":"apps/mobile/lib/x.dart"}]}'),
    );
    await expectLater(
      model.proposeRepair(
        workspace: {'apps/mobile/lib/x.dart': 'old'},
        diagnostics: [],
      ),
      throwsFormatException,
    );
  });
  test('stale patch rejected', () async {
    final doctor = LocalCodeDoctor(
      runner: BrokenRunner(),
      model: PatchModel(stale: true),
    );
    await expectLater(
      doctor.repair({'apps/mobile/lib/x.dart': 'old'}),
      throwsStateError,
    );
  });
  test('attempt limit reports failure', () async {
    final runner = BrokenRunner();
    final result = await LocalCodeDoctor(
      runner: runner,
      model: PatchModel(),
      maxAttempts: 2,
    ).repair({'apps/mobile/lib/x.dart': 'old'});
    expect(result.passed, false);
    expect(result.attempts.length, 2);
    expect(runner.calls, 3);
  });
  test(
    'generated feature keeps original diff and immutable candidate',
    () async {
      final o = AnamikaUpgradeOrchestrator(
        doctor: LocalCodeDoctor(runner: CleanRunner(), model: PatchModel()),
      );
      final c = await o.prepare(
        id: '1',
        title: 'Feature',
        summary: 'Owner request',
        workspace: {'apps/mobile/lib/x.dart': 'old'},
        generated: {'apps/mobile/lib/x.dart': 'new'},
      );
      expect(c.proposal.stage, UpgradeStage.awaitingOwnerApproval);
      expect(c.proposal.changedFiles, ['apps/mobile/lib/x.dart']);
      expect(
        () => c.repair.candidate['apps/mobile/lib/x.dart'] = 'changed',
        throwsUnsupportedError,
      );
      expect(
        () => o.approveAndBuild(
          c.proposal,
          ownerAuthenticated: true,
          candidate: {'apps/mobile/lib/x.dart': 'changed'},
        ),
        throwsStateError,
      );
      expect(
        o
            .approveAndBuild(
              c.proposal,
              ownerAuthenticated: true,
              candidate: c.repair.candidate,
            )
            .stage,
        UpgradeStage.building,
      );
    },
  );
}
