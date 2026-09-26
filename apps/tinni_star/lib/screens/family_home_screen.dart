import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../community/family_service.dart';
import '../moderation/user_safety_menu.dart';
import '../ui/royal_theme.dart';
import 'room_screen.dart';

class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({
    super.key,
    required this.state,
    this.previewName,
    this.previewTag,
  });

  final TinniState state;
  final String? previewName;
  final String? previewTag;

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  int _tab = 0;

  String get _name => widget.state.family.name ?? widget.previewName ?? 'Family';
  String get _tag => widget.state.family.tag ?? widget.previewTag ?? 'FM';

  List<Color> get _familyLevelColors {
    switch (widget.state.family.visualTier) {
      case FamilyVisualTier.emerald:
        return const [Color(0xFF082F24), Color(0xFF0E8A62)];
      case FamilyVisualTier.sapphire:
        return const [Color(0xFF071D38), Color(0xFF155FA8)];
      case FamilyVisualTier.amethyst:
        return const [Color(0xFF241036), Color(0xFF833FB0)];
      case FamilyVisualTier.royalGold:
        return const [Color(0xFF3C2400), Color(0xFFD49B14)];
      case FamilyVisualTier.bronze:
        return const [Color(0xFF2B1A0A), Color(0xFF7A5515)];
    }
  }

  Color get _familyTagColor => _familyLevelColors.last;

  List<FamilyMember> _members() {
    if (widget.state.family.members.isNotEmpty) {
      return widget.state.family.members;
    }
    return const [
      FamilyMember(
        userId: 'f-1001',
        name: 'Royal Leader',
        role: FamilyRole.head,
      ),
      FamilyMember(
        userId: 'f-1002',
        name: 'Destiny',
        role: FamilyRole.deputyHead,
      ),
      FamilyMember(
        userId: 'f-1003',
        name: 'Qureshi',
        role: FamilyRole.assistant,
      ),
      FamilyMember(
        userId: 'f-1004',
        name: 'Sanvi',
        role: FamilyRole.member,
      ),
      FamilyMember(
        userId: 'f-1005',
        name: 'Anvi',
        role: FamilyRole.member,
      ),
    ];
  }

  Future<void> _joinPreviewFamily() async {
    if (widget.state.family.exists) return;
    final userId = widget.state.auth.current?.userId ?? '10000000';
    widget.state.family.joinExisting(
      familyName: _name,
      familyTag: _tag,
      member: FamilyMember(
        userId: userId,
        name: 'Tinni User',
        role: FamilyRole.member,
      ),
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Joined ' + _name)),
    );
  }

  void _openFamilyRoom() {
    final rooms = widget.state.discovery.recommend(country: 'IN');
    if (rooms.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(
          state: widget.state,
          room: rooms.first,
        ),
      ),
    );
  }

  Future<void> _editAnnouncement() async {
    if (!widget.state.family.exists) return;
    final controller = TextEditingController(
      text: widget.state.family.notice,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Family announcement'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Write family announcement',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    widget.state.family.updateNotice(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final members = _members();
    return Scaffold(
      key: const Key('family-home-screen'),
      appBar: AppBar(
        title: Text(
          _name,
          style: const TextStyle(
            color: FeaturePalette.family,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('family-member-manage-button'),
            tooltip: 'Member Manage',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyMemberManageScreen(
                    state: widget.state,
                    familyName: _name,
                    members: members,
                  ),
                ),
              ).then((_) {
                if (mounted) setState(() {});
              });
            },
            icon: const ShiningIcon(
              icon: Icons.manage_accounts_rounded,
              color: FeaturePalette.family,
              size: 18,
              boxSize: 34,
              glow: 0.30,
            ),
          ),
        ],
      ),
      body: Container(
        key: const Key('family-level-shell'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _familyLevelColors.first,
              RoyalPalette.black,
              RoyalPalette.black,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  Container(
                    key: const Key('family-level-tag'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _familyTagColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _familyTagColor),
                      boxShadow: [
                        BoxShadow(
                          color: _familyTagColor.withValues(alpha: 0.38),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      _tag + ' • ' + widget.state.family.levelLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Family Level ' + widget.state.family.level.toString(),
                    style: const TextStyle(
                      color: FeaturePalette.family,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Row(
            children: [
              Expanded(
                child: _FamilyTab(
                  key: const Key('family-home-tab'),
                  label: 'Home',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
              ),
              Expanded(
                child: _FamilyTab(
                  key: const Key('family-trends-tab'),
                  label: 'Trends',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ),
            ],
          ),
          Expanded(
            child: _tab == 0
                ? _buildHome(members)
                : _buildTrends(),
          ),
        ],
      ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: widget.state.family.exists
            ? FilledButton.icon(
                key: const Key('family-open-room-button'),
                onPressed: _openFamilyRoom,
                icon: const Icon(Icons.meeting_room_rounded),
                label: const Text('Open family room'),
              )
            : FilledButton.icon(
                key: const Key('family-join-button'),
                onPressed: _joinPreviewFamily,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Join'),
              ),
      ),
    );
  }

  Widget _buildHome(List<FamilyMember> members) {
    final notice = widget.state.family.notice.trim().isNotEmpty
        ? widget.state.family.notice
        : 'welcome ' + _name + ' members ❤️';

    return ListView(
      key: const Key('family-home-content'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        const Text(
          'family announcement',
          style: TextStyle(
            color: RoyalPalette.cream,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        RoyalPanel(
          key: const Key('family-announcement'),
          onTap: widget.state.family.exists ? _editAnnouncement : null,
          padding: const EdgeInsets.all(11),
          gradient: FeaturePalette.glow(FeaturePalette.family),
          accentColor: FeaturePalette.family,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  notice,
                  style: const TextStyle(
                    color: RoyalPalette.muted,
                    fontSize: 12,
                  ),
                ),
              ),
              if (widget.state.family.exists)
                const ShiningIcon(
                  icon: Icons.edit_rounded,
                  color: FeaturePalette.family,
                  size: 15,
                  boxSize: 28,
                  glow: 0.28,
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const GoldSectionTitle('Top members of the family'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StarCard(
                title: 'Charm Star',
                icon: Icons.favorite_rounded,
                member: members.isEmpty ? null : members.first,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StarCard(
                title: 'Wealth Star',
                icon: Icons.diamond_rounded,
                member: members.length > 1 ? members[1] : members.firstOrNull,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StarCard(
                title: 'Active star',
                icon: Icons.local_fire_department_rounded,
                member: members.length > 2 ? members[2] : members.firstOrNull,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GoldSectionTitle(
          'Member list',
          trailing: IconButton(
            key: const Key('family-member-list-chevron'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyMemberManageScreen(
                    state: widget.state,
                    familyName: _name,
                    members: members,
                  ),
                ),
              ).then((_) {
                if (mounted) setState(() {});
              });
            },
            icon: const ShiningIcon(
              icon: Icons.chevron_right_rounded,
              color: FeaturePalette.family,
              size: 16,
              boxSize: 30,
              glow: 0.26,
            ),
          ),
        ),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (context, index) => const SizedBox(width: 9),
            itemBuilder: (context, index) => Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FeaturePalette.family.withValues(alpha: 0.16),
                    border: Border.all(color: FeaturePalette.family),
                    boxShadow: [
                      BoxShadow(
                        color: FeaturePalette.family.withValues(alpha: 0.34),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Text(
                    members[index].name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: FeaturePalette.family,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 58,
                  child: Text(
                    members[index].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: RoyalPalette.muted,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const GoldSectionTitle('Family room'),
        const SizedBox(height: 8),
        RoyalPanel(
          key: const Key('family-room-card'),
          onTap: _openFamilyRoom,
          padding: const EdgeInsets.all(10),
          gradient: FeaturePalette.glow(FeaturePalette.family),
          accentColor: FeaturePalette.family,
          child: Row(
            children: [
              const ShiningIcon(
                icon: Icons.mic_rounded,
                color: FeaturePalette.family,
                size: 28,
                boxSize: 58,
                glow: 0.42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name + ' room',
                      style: const TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _tag + ' • family voice room',
                      style: const TextStyle(
                        color: RoyalPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: FeaturePalette.family,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrends() {
    final records = widget.state.family.records;
    return ListView(
      key: const Key('family-trends-content'),
      padding: const EdgeInsets.all(14),
      children: [
        const GoldSectionTitle('Family trends'),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const RoyalPanel(
            child: Text(
              'No family activity yet.',
              style: TextStyle(color: RoyalPalette.muted),
            ),
          )
        else
          for (final record in records.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RoyalPanel(
                padding: const EdgeInsets.all(10),
                gradient: FeaturePalette.glow(FeaturePalette.moments),
                accentColor: FeaturePalette.moments,
                child: Row(
                  children: [
                    const ShiningIcon(
                      icon: Icons.auto_awesome_rounded,
                      color: FeaturePalette.moments,
                      size: 17,
                      boxSize: 32,
                      glow: 0.28,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        record,
                        style: const TextStyle(
                          color: RoyalPalette.cream,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class FamilyMemberManageScreen extends StatefulWidget {
  const FamilyMemberManageScreen({
    super.key,
    required this.state,
    required this.familyName,
    required this.members,
  });

  final TinniState state;
  final String familyName;
  final List<FamilyMember> members;

  @override
  State<FamilyMemberManageScreen> createState() =>
      _FamilyMemberManageScreenState();
}

class _FamilyMemberManageScreenState extends State<FamilyMemberManageScreen> {
  int _tab = 0;

  List<FamilyMember> get _members => widget.state.family.members.isNotEmpty
      ? widget.state.family.members
      : widget.members;

  Future<void> _appointDeputy() async {
    if (!widget.state.family.exists) return;
    final candidate = widget.state.family.members.where(
      (member) =>
          member.role != FamilyRole.head &&
          member.role != FamilyRole.deputyHead,
    ).firstOrNull;
    if (candidate == null) return;
    widget.state.family.appoint(candidate.userId, FamilyRole.deputyHead);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('family-member-manage-screen'),
      appBar: AppBar(
        title: const Text(
          'Member Manage',
          style: TextStyle(
            color: FeaturePalette.family,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FamilyTab(
                  key: const Key('family-member-tab'),
                  label: 'Member',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
              ),
              Expanded(
                child: _FamilyTab(
                  key: const Key('family-admin-tab'),
                  label: 'Admin',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ),
            ],
          ),
          Expanded(
            child: _tab == 0 ? _memberList() : _adminView(),
          ),
        ],
      ),
    );
  }

  Widget _memberList() {
    final members = _members;
    return ListView.separated(
      key: const Key('family-member-list'),
      padding: const EdgeInsets.all(14),
      itemCount: members.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = members[index];
        final score = (members.length - index) * 1180000;
        return RoyalPanel(
          padding: const EdgeInsets.all(9),
          gradient: FeaturePalette.glow(FeaturePalette.family),
          accentColor: FeaturePalette.family,
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FeaturePalette.family.withValues(alpha: 0.16),
                  border: Border.all(color: FeaturePalette.family),
                  boxShadow: [
                    BoxShadow(
                      color: FeaturePalette.family.withValues(alpha: 0.34),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  member.name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: FeaturePalette.family,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        color: RoyalPalette.cream,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'ID ' + member.userId,
                      style: const TextStyle(
                        color: RoyalPalette.muted,
                        fontSize: 9,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _roleLabel(member.role),
                          style: const TextStyle(
                            color: FeaturePalette.family,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: widget.state.family.visualTier ==
                                    FamilyVisualTier.royalGold
                                ? const Color(0xFFD49B14)
                                : FeaturePalette.family,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            (widget.state.family.tag ?? 'FM') +
                                ' ' +
                                widget.state.family.levelLabel,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '🪙 ' + score.toString(),
                      style: const TextStyle(
                        color: RoyalPalette.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  UserSafetyMenuButton(
                    state: widget.state,
                    targetUserId: member.userId,
                    targetDisplayName: member.name,
                    onBlockChanged: () {
                      if (mounted) setState(() {});
                    },
                  ),
                  Text(
                    index < 5 ? 'Today' : 'Logged in 1 days ago',
                    style: const TextStyle(
                      color: RoyalPalette.muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _adminView() {
    final members = _members;
    final leader = members.where(
      (member) => member.role == FamilyRole.head,
    ).firstOrNull;
    final deputies = members.where(
      (member) => member.role == FamilyRole.deputyHead,
    ).toList();

    return ListView(
      key: const Key('family-admin-content'),
      padding: const EdgeInsets.all(14),
      children: [
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Family Leader',
            style: TextStyle(
              color: FeaturePalette.family,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: _RoleAvatar(
            member: leader,
            label: leader?.name ?? 'Leader',
            large: true,
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'Deputy Family Leader',
            style: TextStyle(
              color: RoyalPalette.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (var i = 0; i < 6; i++)
              if (i < deputies.length)
                _RoleAvatar(
                  member: deputies[i],
                  label: deputies[i].name,
                )
              else if (i < 3)
                InkWell(
                  key: Key('family-add-deputy-' + i.toString()),
                  onTap: _appointDeputy,
                  borderRadius: BorderRadius.circular(50),
                  child: const _EmptyRoleSlot(locked: false),
                )
              else
                const _EmptyRoleSlot(locked: true),
          ],
        ),
      ],
    );
  }

  String _roleLabel(FamilyRole role) {
    switch (role) {
      case FamilyRole.head:
        return 'Family Leader';
      case FamilyRole.deputyHead:
        return 'Deputy';
      case FamilyRole.assistant:
        return 'Assistant';
      case FamilyRole.member:
        return 'Member';
    }
  }
}

class _FamilyTab extends StatelessWidget {
  const _FamilyTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    Color(0xFF5BE0B1),
                    Color(0xFF178C67),
                  ],
                )
              : null,
          color: selected ? null : RoyalPalette.nearBlack,
          border: Border.all(color: RoyalPalette.bronze),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : RoyalPalette.muted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StarCard extends StatelessWidget {
  const _StarCard({
    required this.title,
    required this.icon,
    required this.member,
  });

  final String title;
  final IconData icon;
  final FamilyMember? member;

  @override
  Widget build(BuildContext context) {
    final accent = icon == Icons.favorite_rounded
        ? FeaturePalette.cp
        : icon == Icons.diamond_rounded
            ? FeaturePalette.diamond
            : FeaturePalette.games;
    return RoyalPanel(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      gradient: FeaturePalette.glow(accent),
      accentColor: accent,
      child: Column(
        children: [
          ShiningIcon(
            icon: icon,
            color: accent,
            size: 26,
            boxSize: 46,
            glow: 0.34,
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RoyalPalette.cream,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
              border: Border.all(color: accent),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Text(
              member?.name.characters.first.toUpperCase() ?? '?',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleAvatar extends StatelessWidget {
  const _RoleAvatar({
    required this.member,
    required this.label,
    this.large = false,
  });

  final FamilyMember? member;
  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: large ? 42 : 31,
          backgroundColor: FeaturePalette.family,
          child: CircleAvatar(
            radius: large ? 37 : 27,
            backgroundColor: RoyalPalette.panel,
            child: Text(
              member?.name.characters.first.toUpperCase() ?? '?',
              style: TextStyle(
                color: FeaturePalette.family,
                fontWeight: FontWeight.w900,
                fontSize: large ? 28 : 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: RoyalPalette.cream,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EmptyRoleSlot extends StatelessWidget {
  const _EmptyRoleSlot({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 31,
          backgroundColor: RoyalPalette.panel2,
          child: Icon(
            locked ? Icons.lock_rounded : Icons.add_rounded,
            color: FeaturePalette.family,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          locked ? 'Locked' : 'No',
          style: const TextStyle(
            color: RoyalPalette.muted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
