import 'package:flutter_test/flutter_test.dart';
import '../lib/self_upgrade_system.dart';
import '../lib/local_code_doctor.dart';
import '../lib/anamika_upgrade_orchestrator.dart';

class FakeRunner implements CodeRunner {
  @override
  Future<List<CodeDiagnostic>> check(Map<String, String> w) async =>
      w.values.any((v) => v.contains('BROKEN'))
          ? const [CodeDiagnostic(kind: LocalCheckKind.syntax, message: 'broken code')]
          : const [];
}
class FakeModel implements CodingModel {
  @override
  Future<List<RepairPatch>> proposeRepair({required Map<String, String> workspace, required List<CodeDiagnostic> diagnostics}) async =>
      [RepairPatch(path: 'apps/mobile/lib/x.dart', beforeHash: 'test', replacement: 'fixed code')];
}
void main() {
  test('repairs then waits for owner approval', () async {
    final o = AnamikaUpgradeOrchestrator(doctor: LocalCodeDoctor(runner: FakeRunner(), model: FakeModel()));
    final c = await o.prepare(id: '1', title: 'repair', summary: 'fix error',
      workspace: {'apps/mobile/lib/x.dart': 'BROKEN'});
    expect(c.repair.passed, true);
    expect(c.proposal.stage, UpgradeStage.awaitingOwnerApproval);
  });
  test('owner approval is still mandatory', () async {
    final o = AnamikaUpgradeOrchestrator(doctor: LocalCodeDoctor(runner: FakeRunner(), model: FakeModel()));
    final c = await o.prepare(id: '1', title: 'repair', summary: 'fix error',
      workspace: {'apps/mobile/lib/x.dart': 'BROKEN'});
    expect(() => o.approveAndBuild(c.proposal, ownerAuthenticated: false), throwsStateError);
  });
}
