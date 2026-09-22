enum ReportCategory {
  harassment,
  spam,
  fraud,
  sexualContent,
  hate,
  impersonation,
  other,
}

class UserReport {
  const UserReport({
    required this.reporterId,
    required this.targetId,
    required this.category,
    required this.details,
  });

  final String reporterId;
  final String targetId;
  final ReportCategory category;
  final String details;
}

class ModerationService {
  final Set<String> roomBlacklist = <String>{};
  final Set<String> accountBlacklist = <String>{};
  final Set<String> micBans = <String>{};
  final Set<String> admins = <String>{};
  final List<UserReport> reports = <UserReport>[];

  void addAdmin(String userId) => admins.add(userId);
  void removeAdmin(String userId) => admins.remove(userId);
  void banMic(String userId) => micBans.add(userId);
  void unbanMic(String userId) => micBans.remove(userId);
  void banFromRoom(String userId) => roomBlacklist.add(userId);
  void unbanFromRoom(String userId) => roomBlacklist.remove(userId);

  void report(UserReport report) => reports.add(report);
}
