import 'dart:convert';
import 'package:crypto/crypto.dart';

String sourceHash(String source) =>
    sha256.convert(utf8.encode(source)).toString();
String workspaceHash(Map<String, String> files) {
  final keys = files.keys.toList()..sort();
  return sourceHash(jsonEncode({for (final key in keys) key: files[key]}));
}

enum UpgradeStage {
  proposed,
  validated,
  awaitingOwnerApproval,
  approved,
  rejected,
  building,
  verified,
  failed,
}

class UpgradeProposal {
  UpgradeProposal({
    required this.id,
    required this.title,
    required this.summary,
    required List<String> changedFiles,
    this.candidateHash = '',
    required this.stage,
    List<String> validationNotes = const [],
  }) : changedFiles = List.unmodifiable(changedFiles),
       validationNotes = List.unmodifiable(validationNotes);

  final String candidateHash;
  final String id;
  final String title;
  final String summary;
  final List<String> changedFiles;
  final UpgradeStage stage;
  final List<String> validationNotes;

  UpgradeProposal copyWith({
    UpgradeStage? stage,
    List<String>? validationNotes,
  }) => UpgradeProposal(
    id: id,
    candidateHash: candidateHash,
    title: title,
    summary: summary,
    changedFiles: changedFiles,
    stage: stage ?? this.stage,
    validationNotes: validationNotes ?? this.validationNotes,
  );
}

class UpgradePolicy {
  static const forbiddenPaths = <String>[
    '.github/workflows/self-upgrade.yml',
    'android/key.properties',
    'android/app/upload-keystore.jks',
  ];

  static bool allows(String path) {
    if (!RegExp(r'^apps/mobile/lib/[a-zA-Z0-9_/-]+\.dart$').hasMatch(path))
      return false;
    if (path
        .split('/')
        .any((part) => part.isEmpty || part == '.' || part == '..'))
      return false;
    return !const {
      'self_upgrade_system.dart',
      'local_code_doctor.dart',
      'anamika_local_coding_model.dart',
      'anamika_upgrade_orchestrator.dart',
      'coding_intent.dart',
      'anamika_repair_page.dart',
      'main_anamika.dart',
    }.contains(path.split('/').last);
  }

  static List<String> validate(UpgradeProposal proposal) {
    final errors = <String>[];
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(proposal.candidateHash))
      errors.add('Candidate digest is required.');
    if (proposal.id.trim().isEmpty) errors.add('Proposal id is required.');
    if (proposal.title.trim().isEmpty)
      errors.add('Proposal title is required.');
    if (proposal.summary.trim().isEmpty)
      errors.add('Proposal summary is required.');
    if (proposal.changedFiles.isEmpty)
      errors.add('At least one changed file is required.');
    for (final path in proposal.changedFiles) {
      if (path.contains('..') || path.startsWith('/')) {
        errors.add('Unsafe path: $path');
      }
      if (!allows(path)) {
        errors.add('Protected path cannot be self-updated: $path');
      }
    }
    return errors;
  }
}

class SelfUpgradeController {
  UpgradeProposal validateProposal(UpgradeProposal proposal) {
    if (proposal.stage != UpgradeStage.proposed) {
      throw StateError('Only proposed upgrades can be validated.');
    }
    final errors = UpgradePolicy.validate(proposal);
    return proposal.copyWith(
      stage: errors.isEmpty
          ? UpgradeStage.awaitingOwnerApproval
          : UpgradeStage.failed,
      validationNotes: errors.isEmpty
          ? const ['Static policy validation passed.']
          : errors,
    );
  }

  UpgradeProposal ownerApprove(
    UpgradeProposal proposal, {
    required bool ownerAuthenticated,
  }) {
    if (!ownerAuthenticated)
      throw StateError('Owner authentication is required.');
    if (proposal.stage != UpgradeStage.awaitingOwnerApproval) {
      throw StateError('Upgrade is not awaiting owner approval.');
    }
    return proposal.copyWith(stage: UpgradeStage.approved);
  }

  UpgradeProposal ownerReject(
    UpgradeProposal proposal, {
    required bool ownerAuthenticated,
  }) {
    if (!ownerAuthenticated)
      throw StateError('Owner authentication is required.');
    if (proposal.stage != UpgradeStage.awaitingOwnerApproval) {
      throw StateError('Upgrade is not awaiting owner approval.');
    }
    return proposal.copyWith(stage: UpgradeStage.rejected);
  }

  UpgradeProposal startBuild(UpgradeProposal proposal) {
    if (proposal.stage != UpgradeStage.approved) {
      throw StateError('Unapproved upgrade cannot be built.');
    }
    return proposal.copyWith(stage: UpgradeStage.building);
  }

  UpgradeProposal markVerified(
    UpgradeProposal proposal, {
    required bool testsPassed,
    required bool signatureVerified,
  }) {
    if (proposal.stage != UpgradeStage.building)
      throw StateError('Upgrade is not building.');
    if (!testsPassed || !signatureVerified) {
      return proposal.copyWith(stage: UpgradeStage.failed);
    }
    return proposal.copyWith(stage: UpgradeStage.verified);
  }
}
