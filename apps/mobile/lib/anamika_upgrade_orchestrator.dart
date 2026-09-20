import 'self_upgrade_system.dart';
import 'local_code_doctor.dart';

class UpgradeCandidate {
  const UpgradeCandidate({required this.proposal, required this.repair});
  final UpgradeProposal proposal;
  final RepairSession repair;
}

class AnamikaUpgradeOrchestrator {
  AnamikaUpgradeOrchestrator({required this.doctor, SelfUpgradeController? controller})
      : controller = controller ?? SelfUpgradeController();

  final LocalCodeDoctor doctor;
  final SelfUpgradeController controller;

  Future<UpgradeCandidate> prepare({
    required String id,
    required String title,
    required String summary,
    required Map<String, String> workspace,
  }) async {
    final repair = await doctor.repair(workspace);
    final proposal = UpgradeProposal(
      id: id,
      title: title,
      summary: summary,
      changedFiles: repair.candidate.keys.where((k) => repair.original[k] != repair.candidate[k]).toList(),
      stage: UpgradeStage.proposed,
    );
    if (!repair.passed || !repair.changed) {
      return UpgradeCandidate(proposal: proposal.copyWith(stage: UpgradeStage.failed), repair: repair);
    }
    return UpgradeCandidate(proposal: controller.validateProposal(proposal), repair: repair);
  }

  UpgradeProposal approveAndBuild(UpgradeProposal proposal, {required bool ownerAuthenticated}) {
    final approved = controller.ownerApprove(proposal, ownerAuthenticated: ownerAuthenticated);
    return controller.startBuild(approved);
  }
}
