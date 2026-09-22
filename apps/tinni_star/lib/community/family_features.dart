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

class FamilyLotteryReward {
  const FamilyLotteryReward(this.label, this.coins);
  final String label;
  final int coins;
}

class FamilyFeatureService {
  FamilyFeatureService(this.family);

  final FamilyService family;
  final Map<String, FamilyTask> tasks = <String, FamilyTask>{
    'signin': const FamilyTask(
      id: 'signin',
      title: 'Daily family sign-in',
      target: 5,
    ),
    'gifts': const FamilyTask(
      id: 'gifts',
      title: 'Family gift contribution',
      target: 1000,
    ),
  };

  final Set<String> signedInToday = <String>{};
  final List<String> lotteryHistory = <String>[];

  bool signIn(String userId) {
    if (!signedInToday.add(userId)) return false;
    final task = tasks['signin'];
    if (task != null) tasks['signin'] = task.addProgress(1);
    family.addExperience(100);
    return true;
  }

  void recordGiftContribution(int value) {
    if (value <= 0) return;
    final task = tasks['gifts'];
    if (task != null) tasks['gifts'] = task.addProgress(value);
    family.addExperience(value);
  }

  FamilyLotteryReward draw(int ticketNumber) {
    final reward = ticketNumber.isEven
        ? const FamilyLotteryReward('Family Lucky Star', 500)
        : const FamilyLotteryReward('Family Gift Box', 100);
    lotteryHistory.insert(0, reward.label);
    family.deposit(reward.coins);
    return reward;
  }

  List<FamilyMember> rankByRole() {
    final members = List<FamilyMember>.from(family.members);
    members.sort((a, b) => a.role.index.compareTo(b.role.index));
    return members;
  }
}
