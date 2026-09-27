import 'family_service.dart';

class FamilyTask {
  const FamilyTask({
    required this.id,
    required this.title,
    required this.target,
    this.progress = 0,
  });

  final String id;
  final String title;
  final int target;
  final int progress;

  bool get completed => progress >= target;

  FamilyTask addProgress(int value) => FamilyTask(
        id: id,
        title: title,
        target: target,
        progress: progress + value,
      );
}

/// Family features intentionally exclude the retired lottery and gift
/// contribution systems. Daily sign-in remains because it contributes only
/// to family experience.
class FamilyFeatureService {
  FamilyFeatureService(this.family);

  final FamilyService family;
  final Map<String, FamilyTask> tasks = <String, FamilyTask>{
    'signin': const FamilyTask(
      id: 'signin',
      title: 'Daily family sign-in',
      target: 5,
    ),
  };

  final Set<String> signedInToday = <String>{};

  bool signIn(String userId) {
    if (!signedInToday.add(userId)) return false;
    final task = tasks['signin'];
    if (task != null) tasks['signin'] = task.addProgress(1);
    family.addExperience(100);
    return true;
  }

  List<FamilyMember> rankByRole() {
    final members = List<FamilyMember>.from(family.members);
    members.sort((a, b) => a.role.index.compareTo(b.role.index));
    return members;
  }
}
