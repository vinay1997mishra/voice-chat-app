import 'self_upgrade_system.dart';
import 'local_code_doctor.dart';

class UpgradeCandidate {
  const UpgradeCandidate({required this.proposal, required this.repair});
  final UpgradeProposal proposal;
  final RepairSession repair;
}

class AnamikaUpgradeOrchestrator {
  AnamikaUpgradeOrchestrator({
    required this.doctor,
    SelfUpgradeController? controller,
  }) : controller = controller ?? SelfUpgradeController();

  final LocalCodeDoctor doctor;
  final SelfUpgradeController controller;

  Future<UpgradeCandidate> prepare({
    required String id,
    required String title,
    required String summary,
    required Map<String, String> workspace,
    Map<String, String>? generated,
  }) async {
    final original = Map<String, String>.unmodifiable(workspace);
    if (generated != null) {
      for (final path in {...original.keys, ...generated.keys}) {
        if (original[path] != generated[path] && !UpgradePolicy.allows(path)) {
          throw StateError('Protected generated path: $path');
        }
        if (!generated.containsKey(path))
          throw StateError('File deletion is not supported.');
      }
    }
    final checked = await doctor.repair(generated ?? original);
    final repair = RepairSession(
      original: original,
      candidate: checked.candidate,
      attempts: checked.attempts,
      passed: checked.passed,
      remaining: checked.remaining,
    );
    final proposal = UpgradeProposal(
      id: id,
      candidateHash: workspaceHash(repair.candidate),
      title: title,
      summary: summary,
      changedFiles: repair.candidate.keys
          .where((k) => repair.original[k] != repair.candidate[k])
          .toList(),
      stage: UpgradeStage.proposed,
    );
    if (!repair.passed || !repair.changed) {
      return UpgradeCandidate(
        proposal: proposal.copyWith(stage: UpgradeStage.failed),
        repair: repair,
      );
    }
    return UpgradeCandidate(
      proposal: controller.validateProposal(proposal),
      repair: repair,
    );
  }

  UpgradeProposal approveAndBuild(
    UpgradeProposal proposal, {
    required bool ownerAuthenticated,
    required Map<String, String> candidate,
  }) {
    if (workspaceHash(candidate) != proposal.candidateHash)
      throw StateError('Candidate changed after review.');
    final approved = controller.ownerApprove(
      proposal,
      ownerAuthenticated: ownerAuthenticated,
    );
    return controller.startBuild(approved);
  }
}
