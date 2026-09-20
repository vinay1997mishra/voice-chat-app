import 'package:flutter_test/flutter_test.dart';
import '../lib/self_upgrade_system.dart';

void main() {
  UpgradeProposal proposal({List<String>? files}) => UpgradeProposal(
    id: 'upgrade-001',
    title: 'Safe feature update',
    summary: 'Owner-visible proposed change',
    changedFiles: files ?? const ['apps/mobile/lib/main_v05.dart'],
    stage: UpgradeStage.proposed,
  );

  test('valid proposal waits for owner approval', () {
    final c = SelfUpgradeController();
    expect(c.validateProposal(proposal()).stage, UpgradeStage.awaitingOwnerApproval);
  });

  test('cannot approve without owner authentication', () {
    final c = SelfUpgradeController();
    final p = c.validateProposal(proposal());
    expect(() => c.ownerApprove(p, ownerAuthenticated: false), throwsStateError);
  });

  test('cannot build before owner approval', () {
    final c = SelfUpgradeController();
    final p = c.validateProposal(proposal());
    expect(() => c.startBuild(p), throwsStateError);
  });

  test('protected workflow cannot self-modify', () {
    final c = SelfUpgradeController();
    final p = c.validateProposal(proposal(files: const ['.github/workflows/self-upgrade.yml']));
    expect(p.stage, UpgradeStage.failed);
  });

  test('verified requires tests and signature verification', () {
    final c = SelfUpgradeController();
    var p = c.validateProposal(proposal());
    p = c.ownerApprove(p, ownerAuthenticated: true);
    p = c.startBuild(p);
    expect(c.markVerified(p, testsPassed: true, signatureVerified: false).stage, UpgradeStage.failed);
  });
}
