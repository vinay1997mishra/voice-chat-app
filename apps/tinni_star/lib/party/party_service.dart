enum PartyType { birthday, exclusiveBirthday, dating, memorial }

class PartySession {
  PartySession({
    required this.id,
    required this.type,
    required this.ownerId,
    required this.title,
  });

  final String id;
  final PartyType type;
  final String ownerId;
  String title;
  String dressUp = 'default';
  bool active = false;
  final Set<String> users = <String>{};

  void start() => active = true;
  void end() => active = false;
  void join(String userId) => users.add(userId);
}

class PartyService {
  final Map<String, PartySession> parties = <String, PartySession>{};

  PartySession create({
    required String id,
    required PartyType type,
    required String ownerId,
    required String title,
  }) {
    final party = PartySession(
      id: id,
      type: type,
      ownerId: ownerId,
      title: title,
    );
    parties[id] = party;
    return party;
  }

  void setDressUp(String partyId, String dressUp) {
    final party = parties[partyId];
    if (party != null) party.dressUp = dressUp;
  }

  List<PartySession> activeParties() =>
      parties.values.where((party) => party.active).toList();
}
