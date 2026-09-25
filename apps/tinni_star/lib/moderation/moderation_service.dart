import 'dart:convert';
import 'dart:io';

class ReportReason {
  const ReportReason(this.key, this.label);

  final String key;
  final String label;
}

const List<ReportReason> reportReasons = <ReportReason>[
  ReportReason(
    'sexual_nude_exploitation',
    'Sexual / Nude Content & Sexual Exploitation',
  ),
  ReportReason(
    'child_safety_minor_exploitation',
    'Child Safety / Minor Exploitation',
  ),
  ReportReason(
    'harassment_bullying_hate',
    'Harassment / Bullying / Hate Speech',
  ),
  ReportReason(
    'threats_violence_weapons',
    'Threats / Violence / Weapons',
  ),
  ReportReason(
    'terrorism_extremism_drugs',
    'Terrorism / Extremism / Drugs / Illegal Substances',
  ),
  ReportReason(
    'self_harm_suicide',
    'Self-harm / Suicide Encouragement',
  ),
  ReportReason(
    'fraud_scam_payment_abuse',
    'Fraud / Scam / Fake Coins / Payment Abuse',
  ),
  ReportReason(
    'account_theft_phishing_impersonation',
    'Account Theft / Phishing / Impersonation',
  ),
  ReportReason(
    'privacy_doxxing',
    'Privacy / Personal Information / Doxxing',
  ),
  ReportReason(
    'illegal_gambling_betting',
    'Illegal Gambling / Betting',
  ),
  ReportReason(
    'spam_advertising',
    'Spam / Advertising',
  ),
  ReportReason(
    'copyright_stolen_content',
    'Copyright / Stolen Content',
  ),
  ReportReason(
    'room_abuse',
    'Room Abuse / Prohibited Room Activity',
  ),
  ReportReason('other', 'Other'),
];

class UserReport {
  const UserReport({
    required this.reporterId,
    required this.targetId,
    required this.categories,
    required this.otherDetails,
    required this.screenshotCount,
    this.roomId,
  });

  final String reporterId;
  final String targetId;
  final List<String> categories;
  final String otherDetails;
  final int screenshotCount;
  final String? roomId;
}

class ModerationService {
  ModerationService({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

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

  Future<String> submitUserReport({
    required String authToken,
    required String reporterId,
    required String targetUserId,
    required String targetDisplayName,
    required List<String> categories,
    required String otherDetails,
    required List<String> screenshots,
    String? roomId,
  }) async {
    final selected = categories
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    if (selected.isEmpty) {
      throw StateError('Select at least one report reason.');
    }
    if (selected.contains('other') && otherDetails.trim().length < 3) {
      throw StateError('Write details for Other.');
    }
    if (screenshots.length > 5) {
      throw StateError('Maximum 5 screenshots are allowed.');
    }

    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/app/complaints'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, Object?>{
        'target_user_id': targetUserId,
        'target_display_name': targetDisplayName,
        'room_id': roomId,
        'categories': selected,
        'other_details': otherDetails.trim(),
        'screenshots': screenshots,
      }),
    );

    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    Map<String, dynamic> data = <String, dynamic>{};
    if (body.trim().isNotEmpty) {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        data = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to submit report.',
      );
    }

    reports.add(
      UserReport(
        reporterId: reporterId,
        targetId: targetUserId,
        categories: List<String>.unmodifiable(selected),
        otherDetails: otherDetails.trim(),
        screenshotCount: screenshots.length,
        roomId: roomId,
      ),
    );

    return data['report_id']?.toString() ?? '';
  }

  void dispose() => _httpClient.close(force: true);
}
